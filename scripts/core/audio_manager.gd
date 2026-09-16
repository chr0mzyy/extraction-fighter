extends Node

const MUSIC_FADE_DURATION := 0.9
const MIX_RATE := 11025
const WORLD_POOL_SIZE := 16
const UI_POOL_SIZE := 6

const MUSIC_STATES: Array[StringName] = [&"lobby", &"arena", &"dungeon", &"boss"]
const UI_EVENTS: Array[StringName] = [&"ui_hover", &"ui_click", &"ui_back", &"ui_invalid", &"hit", &"headshot", &"kill"]

var current_music_state: StringName = &""
var current_music_index: int = 0
var fading_from_index: int = -1
var music_fade_elapsed: float = MUSIC_FADE_DURATION
var music_players: Array[AudioStreamPlayer] = []
var world_players: Array[AudioStreamPlayer3D] = []
var ui_players: Array[AudioStreamPlayer] = []
var event_streams: Dictionary = {}
var music_streams: Dictionary = {}
var event_last_played: Dictionary = {}
var next_world_player: int = 0
var next_ui_player: int = 0
var played_event_count: int = 0
var suppressed_event_count: int = 0
var random := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	random.seed = 0xEF4020
	_create_players()
	_build_stream_library()
	AudioEvents.event_emitted.connect(_on_audio_event)


func _process(delta: float) -> void:
	if music_fade_elapsed >= MUSIC_FADE_DURATION:
		return
	music_fade_elapsed = minf(MUSIC_FADE_DURATION, music_fade_elapsed + delta)
	var blend := smoothstep(0.0, 1.0, music_fade_elapsed / MUSIC_FADE_DURATION)
	if current_music_index >= 0 and current_music_index < music_players.size():
		music_players[current_music_index].volume_db = linear_to_db(maxf(blend, 0.001))
	if fading_from_index >= 0 and fading_from_index < music_players.size():
		var old_player := music_players[fading_from_index]
		old_player.volume_db = linear_to_db(maxf(1.0 - blend, 0.001))
		if music_fade_elapsed >= MUSIC_FADE_DURATION:
			old_player.stop()
			fading_from_index = -1


func play_music(state: StringName) -> void:
	if state not in MUSIC_STATES or not music_streams.has(state):
		return
	if state == current_music_state and music_players[current_music_index].playing:
		return
	var old_index := current_music_index
	var next_index := 1 - current_music_index
	var next_player := music_players[next_index]
	next_player.stop()
	next_player.stream = music_streams[state]
	next_player.volume_db = -60.0
	next_player.play()
	fading_from_index = old_index if music_players[old_index].playing else -1
	current_music_index = next_index
	current_music_state = state
	music_fade_elapsed = 0.0


func stop_music() -> void:
	for player: AudioStreamPlayer in music_players:
		player.stop()
	current_music_state = &""
	fading_from_index = -1
	music_fade_elapsed = MUSIC_FADE_DURATION


func get_active_music_count() -> int:
	var count := 0
	for player: AudioStreamPlayer in music_players:
		if player.playing:
			count += 1
	return count


func has_event_stream(event_name: StringName) -> bool:
	return event_streams.has(event_name)


func _create_players() -> void:
	for index: int in 2:
		var music_player := AudioStreamPlayer.new()
		music_player.name = "MusicPlayer%d" % index
		music_player.bus = &"Music"
		add_child(music_player)
		music_players.append(music_player)
	for index: int in WORLD_POOL_SIZE:
		var world_player := AudioStreamPlayer3D.new()
		world_player.name = "WorldSFX%02d" % index
		world_player.bus = &"SFX"
		world_player.max_distance = 65.0
		world_player.unit_size = 7.0
		world_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(world_player)
		world_players.append(world_player)
	for index: int in UI_POOL_SIZE:
		var ui_player := AudioStreamPlayer.new()
		ui_player.name = "UISFX%02d" % index
		ui_player.bus = &"UI"
		add_child(ui_player)
		ui_players.append(ui_player)


func _build_stream_library() -> void:
	var recipes := {
		&"footstep": [82.0, 0.09, 0.62, -110.0],
		&"jump": [230.0, 0.14, 0.12, 520.0],
		&"land": [68.0, 0.17, 0.72, -60.0],
		&"sprint": [145.0, 0.11, 0.45, 220.0],
		&"slide": [105.0, 0.24, 0.78, -180.0],
		&"dash": [175.0, 0.2, 0.54, 900.0],
		&"grapple": [330.0, 0.22, 0.18, 780.0],
		&"blink": [520.0, 0.22, 0.12, 1300.0],
		&"gunshot": [105.0, 0.13, 0.86, -170.0],
		&"reload": [410.0, 0.15, 0.28, -240.0],
		&"empty": [760.0, 0.065, 0.12, -100.0],
		&"melee_swing": [165.0, 0.17, 0.72, 720.0],
		&"melee_hit": [92.0, 0.14, 0.68, -120.0],
		&"heavy_hit": [58.0, 0.22, 0.72, -80.0],
		&"block": [490.0, 0.15, 0.42, -300.0],
		&"parry": [980.0, 0.24, 0.16, -900.0],
		&"hit": [610.0, 0.075, 0.05, 160.0],
		&"headshot": [930.0, 0.14, 0.05, 420.0],
		&"kill": [280.0, 0.28, 0.12, 530.0],
		&"player_damage": [72.0, 0.18, 0.58, -80.0],
		&"enemy_damage": [125.0, 0.1, 0.42, -50.0],
		&"armor_hit": [360.0, 0.16, 0.48, -280.0],
		&"pickup": [620.0, 0.16, 0.08, 620.0],
		&"key_pickup": [740.0, 0.3, 0.06, 820.0],
		&"chest": [118.0, 0.3, 0.54, -80.0],
		&"extraction_start": [190.0, 0.28, 0.12, 420.0],
		&"extraction_success": [360.0, 0.5, 0.08, 560.0],
		&"extraction_failure": [95.0, 0.45, 0.25, -120.0],
		&"boss_phase": [52.0, 0.5, 0.46, 180.0],
		&"ui_hover": [640.0, 0.045, 0.02, 80.0],
		&"ui_click": [430.0, 0.075, 0.04, -70.0],
		&"ui_back": [310.0, 0.09, 0.05, -120.0],
		&"ui_invalid": [135.0, 0.15, 0.16, -90.0],
	}
	for event_name: StringName in recipes:
		var recipe: Array = recipes[event_name]
		event_streams[event_name] = _make_effect_stream(float(recipe[0]), float(recipe[1]), float(recipe[2]), float(recipe[3]))
	music_streams[&"lobby"] = _make_music_stream(55.0, 0.08, 0.0)
	music_streams[&"arena"] = _make_music_stream(73.0, 0.13, 2.0)
	music_streams[&"dungeon"] = _make_music_stream(46.0, 0.09, 0.5)
	music_streams[&"boss"] = _make_music_stream(41.0, 0.16, 3.0)


func _on_audio_event(event_name: StringName, world_position: Vector3, context: Dictionary) -> void:
	if not event_streams.has(event_name):
		return
	var now := Time.get_ticks_msec() * 0.001
	var cooldown := _event_cooldown(event_name)
	if now - float(event_last_played.get(event_name, -100.0)) < cooldown:
		suppressed_event_count += 1
		return
	event_last_played[event_name] = now
	played_event_count += 1
	var stream := event_streams[event_name] as AudioStream
	if event_name in UI_EVENTS:
		_play_ui(stream, event_name)
	else:
		_play_world(stream, event_name, world_position, context)


func _play_world(stream: AudioStream, event_name: StringName, world_position: Vector3, context: Dictionary) -> void:
	var player := _next_available_world_player()
	player.stream = stream
	player.global_position = world_position
	player.pitch_scale = _event_pitch(event_name, context)
	player.volume_db = _event_volume(event_name)
	player.play()


func _play_ui(stream: AudioStream, event_name: StringName) -> void:
	var player := _next_available_ui_player()
	player.stream = stream
	player.pitch_scale = random.randf_range(0.97, 1.03)
	player.volume_db = _event_volume(event_name)
	player.play()


func _next_available_world_player() -> AudioStreamPlayer3D:
	for player: AudioStreamPlayer3D in world_players:
		if not player.playing:
			return player
	var player := world_players[next_world_player]
	next_world_player = (next_world_player + 1) % world_players.size()
	player.stop()
	return player


func _next_available_ui_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in ui_players:
		if not player.playing:
			return player
	var player := ui_players[next_ui_player]
	next_ui_player = (next_ui_player + 1) % ui_players.size()
	player.stop()
	return player


func _event_cooldown(event_name: StringName) -> float:
	match event_name:
		&"footstep": return 0.1
		&"gunshot": return 0.035
		&"hit", &"enemy_damage", &"armor_hit": return 0.025
		&"ui_hover": return 0.075
		&"ui_click", &"ui_back", &"ui_invalid": return 0.045
		_: return 0.0


func _event_volume(event_name: StringName) -> float:
	match event_name:
		&"footstep": return -10.0
		&"sprint", &"jump", &"reload": return -7.0
		&"ui_hover": return -13.0
		&"ui_click", &"ui_back": return -9.0
		&"hit", &"headshot": return -6.0
		&"gunshot", &"heavy_hit", &"parry", &"boss_phase": return -2.0
		_: return -5.0


func _event_pitch(event_name: StringName, context: Dictionary) -> float:
	var base := 1.0
	if event_name == &"footstep":
		base = clampf(float(context.get("speed", 6.0)) / 8.0, 0.82, 1.18)
	return base * random.randf_range(0.96, 1.04)


func _make_effect_stream(frequency: float, duration: float, noise_mix: float, sweep: float) -> AudioStreamWAV:
	var sample_count := maxi(1, roundi(duration * MIX_RATE))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for sample_index: int in sample_count:
		var time := float(sample_index) / MIX_RATE
		var progress := float(sample_index) / sample_count
		var envelope := pow(1.0 - progress, 2.2)
		var phase := TAU * (frequency * time + sweep * time * time * 0.5)
		var tonal := sin(phase) * 0.72 + sin(phase * 1.97) * 0.28
		var noise := random.randf_range(-1.0, 1.0)
		var sample := lerpf(tonal, noise, noise_mix) * envelope * 0.62
		_write_sample(bytes, sample_index, sample)
	return _wav_from_bytes(bytes, false)


func _make_music_stream(root_frequency: float, intensity: float, pulse_rate: float) -> AudioStreamWAV:
	var duration := 4.0
	var sample_count := roundi(duration * MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for sample_index: int in sample_count:
		var time := float(sample_index) / MIX_RATE
		var drone := sin(TAU * root_frequency * time) * 0.52
		drone += sin(TAU * root_frequency * 1.5 * time) * 0.25
		drone += sin(TAU * root_frequency * 0.5 * time) * 0.23
		var pulse := 1.0
		if pulse_rate > 0.0:
			pulse = 0.64 + maxf(0.0, sin(TAU * pulse_rate * time)) * 0.36
		var sample := drone * intensity * pulse
		_write_sample(bytes, sample_index, sample)
	return _wav_from_bytes(bytes, true)


func _write_sample(bytes: PackedByteArray, sample_index: int, sample: float) -> void:
	var signed_value := clampi(roundi(clampf(sample, -1.0, 1.0) * 32767.0), -32768, 32767)
	var unsigned_value := signed_value if signed_value >= 0 else signed_value + 65536
	bytes[sample_index * 2] = unsigned_value & 0xff
	bytes[sample_index * 2 + 1] = (unsigned_value >> 8) & 0xff


func _wav_from_bytes(bytes: PackedByteArray, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = bytes.size() / 2
	return stream
