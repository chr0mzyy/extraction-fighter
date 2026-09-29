extends Node

signal changed

const SAVE_VERSION := 1
const SAVE_PATH := "user://game_settings.json"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const REBINDABLE_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"crouch", &"jump",
	&"peek_left", &"peek_right", &"skill_slot_1", &"skill_slot_2", &"toggle_camera", &"weapon_1", &"weapon_2",
	&"primary_attack", &"secondary_attack", &"heavy_attack", &"reload", &"interact",
]
const ACTION_LABELS := {
	&"move_forward": "Move Forward", &"move_back": "Move Back", &"move_left": "Move Left", &"move_right": "Move Right",
	&"sprint": "Crouch / Slide", &"crouch": "Alternate Crouch", &"jump": "Jump / Bhop",
	&"peek_left": "Peek Left", &"peek_right": "Peek Right",
	&"skill_slot_1": "Skill 1", &"skill_slot_2": "Skill 2", &"toggle_camera": "Toggle Camera",
	&"weapon_1": "Weapon 1", &"weapon_2": "Weapon 2", &"primary_attack": "Primary Attack",
	&"secondary_attack": "Secondary Attack / ADS", &"heavy_attack": "Heavy Attack", &"reload": "Reload", &"interact": "Interact",
}

var resolution: Vector2i = Vector2i(1280, 720)
var fullscreen: bool = false
var vsync: bool = true
var base_fov: float = 90.0
var fps_cap: int = 144
var shadow_quality: int = 1
var render_scale: float = 1.0
var effects_quality: int = 1
var mouse_sensitivity: float = 0.0022
var invert_y: bool = false
var damage_numbers: bool = true
var camera_shake_strength: float = 0.55
var hit_effects_intensity: float = 0.75
var headbob_strength: float = 0.45
var tpp_camera_smoothing: float = 18.0
var crosshair_enabled: bool = true
var master_volume: float = 0.80
var music_volume: float = 0.65
var sfx_volume: float = 0.85
var ui_volume: float = 0.8
var keybinds: Dictionary = {}
var _default_keybinds: Dictionary = {}
var _save_pending: bool = false
var _save_delay_remaining: float = 0.0


func _ready() -> void:
	_default_keybinds = _capture_project_keybinds()
	keybinds = _default_keybinds.duplicate(true)
	load_settings()


func _process(delta: float) -> void:
	if not _save_pending:
		return
	_save_delay_remaining -= delta
	if _save_delay_remaining <= 0.0:
		save_settings()


func reset_defaults(apply_now: bool = true) -> void:
	resolution = Vector2i(1280, 720)
	fullscreen = false
	vsync = true
	base_fov = 90.0
	fps_cap = 144
	shadow_quality = 1
	render_scale = 1.0
	effects_quality = 1
	mouse_sensitivity = 0.0022
	invert_y = false
	damage_numbers = true
	camera_shake_strength = 0.55
	hit_effects_intensity = 0.75
	headbob_strength = 0.45
	tpp_camera_smoothing = 18.0
	crosshair_enabled = true
	master_volume = 0.80
	music_volume = 0.65
	sfx_volume = 0.85
	ui_volume = 0.8
	keybinds = _default_keybinds.duplicate(true)
	if apply_now:
		apply_settings()


func set_value(key: StringName, value: Variant, persist: bool = true) -> void:
	match key:
		&"resolution": resolution = value as Vector2i
		&"fullscreen": fullscreen = bool(value)
		&"vsync": vsync = bool(value)
		&"base_fov": base_fov = clampf(float(value), 70.0, 110.0)
		&"fps_cap": fps_cap = clampi(int(value), 30, 360)
		&"shadow_quality": shadow_quality = clampi(int(value), 0, 2)
		&"render_scale": render_scale = clampf(float(value), 0.5, 1.0)
		&"effects_quality": effects_quality = clampi(int(value), 0, 2)
		&"mouse_sensitivity": mouse_sensitivity = clampf(float(value), 0.0005, 0.006)
		&"invert_y": invert_y = bool(value)
		&"damage_numbers": damage_numbers = bool(value)
		&"camera_shake_strength": camera_shake_strength = clampf(float(value), 0.0, 1.0)
		&"hit_effects_intensity": hit_effects_intensity = clampf(float(value), 0.0, 1.0)
		&"headbob_strength": headbob_strength = clampf(float(value), 0.0, 1.0)
		&"tpp_camera_smoothing": tpp_camera_smoothing = clampf(float(value), 6.0, 30.0)
		&"crosshair_enabled": crosshair_enabled = bool(value)
		&"master_volume": master_volume = clampf(float(value), 0.0, 1.0)
		&"music_volume": music_volume = clampf(float(value), 0.0, 1.0)
		&"sfx_volume": sfx_volume = clampf(float(value), 0.0, 1.0)
		&"ui_volume": ui_volume = clampf(float(value), 0.0, 1.0)
		_: return
	apply_settings()
	if persist:
		_save_pending = true
		_save_delay_remaining = 0.25


func apply_settings() -> void:
	_apply_keybinds()
	Engine.max_fps = fps_cap
	get_viewport().scaling_3d_scale = render_scale
	RenderingServer.directional_shadow_atlas_set_size([0, 2048, 4096][shadow_quality], true)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not fullscreen:
			DisplayServer.window_set_size(resolution)
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.0001)))
	_apply_optional_audio_bus("Music", music_volume)
	_apply_optional_audio_bus("SFX", sfx_volume)
	_apply_optional_audio_bus("UI", ui_volume)
	changed.emit()


func _apply_optional_audio_bus(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))


func to_dictionary() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"resolution": [resolution.x, resolution.y],
		"fullscreen": fullscreen,
		"vsync": vsync,
		"base_fov": base_fov,
		"fps_cap": fps_cap,
		"shadow_quality": shadow_quality,
		"render_scale": render_scale,
		"effects_quality": effects_quality,
		"mouse_sensitivity": mouse_sensitivity,
		"invert_y": invert_y,
		"damage_numbers": damage_numbers,
		"camera_shake_strength": camera_shake_strength,
		"hit_effects_intensity": hit_effects_intensity,
		"headbob_strength": headbob_strength,
		"tpp_camera_smoothing": tpp_camera_smoothing,
		"crosshair_enabled": crosshair_enabled,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ui_volume": ui_volume,
		"keybinds": keybinds,
	}


func apply_dictionary(data: Dictionary, apply_now: bool = true) -> bool:
	if int(data.get("save_version", -1)) != SAVE_VERSION:
		return false
	var saved_resolution: Array = data.get("resolution", [1280, 720])
	if saved_resolution.size() != 2:
		return false
	resolution = Vector2i(clampi(int(saved_resolution[0]), 640, 7680), clampi(int(saved_resolution[1]), 360, 4320))
	fullscreen = bool(data.get("fullscreen", false))
	vsync = bool(data.get("vsync", true))
	base_fov = clampf(float(data.get("base_fov", 90.0)), 70.0, 110.0)
	fps_cap = clampi(int(data.get("fps_cap", 144)), 30, 360)
	shadow_quality = clampi(int(data.get("shadow_quality", 1)), 0, 2)
	render_scale = clampf(float(data.get("render_scale", 1.0)), 0.5, 1.0)
	effects_quality = clampi(int(data.get("effects_quality", 1)), 0, 2)
	mouse_sensitivity = clampf(float(data.get("mouse_sensitivity", 0.0022)), 0.0005, 0.006)
	invert_y = bool(data.get("invert_y", false))
	damage_numbers = bool(data.get("damage_numbers", true))
	camera_shake_strength = clampf(float(data.get("camera_shake_strength", 0.55)), 0.0, 1.0)
	hit_effects_intensity = clampf(float(data.get("hit_effects_intensity", 0.75)), 0.0, 1.0)
	headbob_strength = clampf(float(data.get("headbob_strength", 0.45)), 0.0, 1.0)
	tpp_camera_smoothing = clampf(float(data.get("tpp_camera_smoothing", 18.0)), 6.0, 30.0)
	crosshair_enabled = bool(data.get("crosshair_enabled", true))
	master_volume = clampf(float(data.get("master_volume", 0.80)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", 0.65)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 0.85)), 0.0, 1.0)
	ui_volume = clampf(float(data.get("ui_volume", 0.8)), 0.0, 1.0)
	keybinds = _default_keybinds.duplicate(true)
	var saved_keybinds: Variant = data.get("keybinds", {})
	if saved_keybinds is Dictionary:
		for action: StringName in REBINDABLE_ACTIONS:
			var action_key := String(action)
			var entries: Variant = (saved_keybinds as Dictionary).get(action_key, null)
			if entries is Array and not (entries as Array).is_empty():
				keybinds[action_key] = (entries as Array).duplicate(true)
		_migrate_legacy_peek_bindings(saved_keybinds as Dictionary)
	if apply_now:
		apply_settings()
	return true


func _migrate_legacy_peek_bindings(saved_keybinds: Dictionary) -> void:
	# Older saves used Q/E for skills. Only migrate that exact legacy layout; custom
	# bindings are kept, and all four actions remain rebindable in the options menu.
	if saved_keybinds.has("peek_left") or saved_keybinds.has("peek_right"):
		return
	if _serialized_binding_uses_key(keybinds.get("skill_slot_1", []), KEY_Q):
		keybinds["skill_slot_1"] = _default_keybinds.get("skill_slot_1", []).duplicate(true)
	if _serialized_binding_uses_key(keybinds.get("skill_slot_2", []), KEY_E):
		keybinds["skill_slot_2"] = _default_keybinds.get("skill_slot_2", []).duplicate(true)


func _serialized_binding_uses_key(entries: Variant, key: Key) -> bool:
	if not entries is Array:
		return false
	for entry: Variant in entries:
		if entry is Dictionary and String(entry.get("type", "")) == "key":
			if int(entry.get("physical_keycode", 0)) == int(key) or int(entry.get("keycode", 0)) == int(key):
				return true
	return false


func get_action_label(action: StringName) -> String:
	return String(ACTION_LABELS.get(action, String(action).capitalize()))


func get_binding_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	return "UNBOUND" if events.is_empty() else _event_display_name(events[0])


func find_binding_conflict(action: StringName, event: InputEvent) -> StringName:
	var signature := _event_signature(event)
	for other_action: StringName in REBINDABLE_ACTIONS:
		if other_action == action:
			continue
		for other_event: InputEvent in InputMap.action_get_events(other_action):
			if _event_signature(other_event) == signature:
				return other_action
	return &""


func set_binding(action: StringName, event: InputEvent, persist: bool = true) -> bool:
	if action not in REBINDABLE_ACTIONS or not (event is InputEventKey or event is InputEventMouseButton):
		return false
	keybinds[String(action)] = [_serialize_input_event(event)]
	_apply_keybinds()
	changed.emit()
	if persist:
		_save_pending = true
		_save_delay_remaining = 0.25
	return true


func reset_keybinds(persist: bool = true) -> void:
	keybinds = _default_keybinds.duplicate(true)
	_apply_keybinds()
	changed.emit()
	if persist:
		save_settings()


func _capture_project_keybinds() -> Dictionary:
	var result := {}
	for action: StringName in REBINDABLE_ACTIONS:
		var serialized: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey or event is InputEventMouseButton:
				serialized.append(_serialize_input_event(event))
		result[String(action)] = serialized
	return result


func _apply_keybinds() -> void:
	for action: StringName in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		var entries: Variant = keybinds.get(String(action), [])
		if not entries is Array:
			continue
		for entry: Variant in entries:
			if entry is Dictionary:
				var event := _deserialize_input_event(entry as Dictionary)
				if event != null:
					InputMap.action_add_event(action, event)


func _serialize_input_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return {"type": "key", "physical_keycode": int(key_event.physical_keycode), "keycode": int(key_event.keycode), "shift": key_event.shift_pressed, "ctrl": key_event.ctrl_pressed, "alt": key_event.alt_pressed, "meta": key_event.meta_pressed}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button_index": int((event as InputEventMouseButton).button_index)}
	return {}


func _deserialize_input_event(data: Dictionary) -> InputEvent:
	match String(data.get("type", "")):
		"key":
			var key_event := InputEventKey.new()
			key_event.physical_keycode = int(data.get("physical_keycode", 0)) as Key
			key_event.keycode = int(data.get("keycode", 0)) as Key
			key_event.shift_pressed = bool(data.get("shift", false))
			key_event.ctrl_pressed = bool(data.get("ctrl", false))
			key_event.alt_pressed = bool(data.get("alt", false))
			key_event.meta_pressed = bool(data.get("meta", false))
			return key_event
		"mouse":
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = int(data.get("button_index", 0)) as MouseButton
			return mouse_event
	return null


func _event_signature(event: InputEvent) -> String:
	return JSON.stringify(_serialize_input_event(event))


func _event_display_name(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "MOUSE LEFT"
			MOUSE_BUTTON_RIGHT: return "MOUSE RIGHT"
			MOUSE_BUTTON_MIDDLE: return "MOUSE MIDDLE"
			MOUSE_BUTTON_XBUTTON1: return "MOUSE 4"
			MOUSE_BUTTON_XBUTTON2: return "MOUSE 5"
		return "MOUSE %d" % int((event as InputEventMouseButton).button_index)
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var display := key_event.as_text_physical_keycode()
		return display.to_upper() if not display.is_empty() else key_event.as_text().to_upper()
	return "UNBOUND"


func save_settings(path: String = SAVE_PATH) -> bool:
	_save_pending = false
	_save_delay_remaining = 0.0
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dictionary(), "\t"))
	return true


func load_settings(path: String = SAVE_PATH, create_default: bool = true) -> bool:
	if not FileAccess.file_exists(path):
		reset_defaults()
		if create_default:
			save_settings(path)
		return create_default
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	var parsed: Variant = parser.data
	if parse_error != OK or not parsed is Dictionary or not apply_dictionary(parsed as Dictionary):
		reset_defaults()
		if create_default:
			save_settings(path)
		return false
	return true
