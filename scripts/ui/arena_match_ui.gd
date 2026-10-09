class_name ArenaMatchUI
extends CanvasLayer

signal play_again_requested
signal return_to_lobby_requested

var manager: ArenaMatchManager
var local_participant: ArenaParticipantState
var intro_label: Label
var cue_label: Label
var spectator_label: Label
var results_panel: PanelContainer
var result_title: Label
var result_score: Label
var result_stats: Label
var play_again_button: Button


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func bind(p_manager: ArenaMatchManager, p_local: ArenaParticipantState) -> void:
	manager = p_manager
	local_participant = p_local
	manager.intro_updated.connect(_on_intro_updated)
	manager.round_ended.connect(_on_round_ended)
	manager.sudden_death_started.connect(_on_sudden_death)
	manager.round_started.connect(_on_round_started)
	manager.results_ready.connect(_on_results_ready)
	manager.spectator_requested.connect(_on_spectator_requested)
	manager.round_reset_requested.connect(_on_round_reset)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center.position = Vector2(-260, 145)
	center.size = Vector2(520, 180)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	intro_label = Label.new()
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.add_theme_font_size_override("font_size", 30)
	intro_label.add_theme_color_override("font_color", Color(0.92, 0.96, 0.98))
	center.add_child(intro_label)
	cue_label = Label.new()
	cue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cue_label.add_theme_font_size_override("font_size", 58)
	cue_label.add_theme_color_override("font_color", Color(0.02, 0.78, 0.95))
	center.add_child(cue_label)
	spectator_label = Label.new()
	spectator_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	spectator_label.position = Vector2(-310, -130)
	spectator_label.size = Vector2(620, 80)
	spectator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spectator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spectator_label.add_theme_font_size_override("font_size", 18)
	spectator_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.08))
	spectator_label.visible = false
	root.add_child(spectator_label)
	results_panel = PanelContainer.new()
	results_panel.set_anchors_preset(Control.PRESET_CENTER)
	results_panel.position = Vector2(-290, -225)
	results_panel.size = Vector2(580, 450)
	results_panel.visible = false
	results_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.018, 0.022, 0.98)
	style.border_color = Color(0.02, 0.74, 0.90)
	style.set_border_width_all(2)
	style.set_content_margin_all(28)
	results_panel.add_theme_stylebox_override("panel", style)
	root.add_child(results_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	results_panel.add_child(column)
	result_title = Label.new()
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 42)
	column.add_child(result_title)
	result_score = Label.new()
	result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_score.add_theme_font_size_override("font_size", 26)
	column.add_child(result_score)
	result_stats = Label.new()
	result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_stats.add_theme_color_override("font_color", Color(0.72, 0.80, 0.82))
	column.add_child(result_stats)
	play_again_button = Button.new()
	play_again_button.text = "PLAY AGAIN"
	play_again_button.custom_minimum_size.y = 52
	play_again_button.pressed.connect(func() -> void: play_again_requested.emit())
	column.add_child(play_again_button)
	var lobby_button := Button.new()
	lobby_button.text = "RETURN TO LOBBY"
	lobby_button.custom_minimum_size.y = 52
	lobby_button.pressed.connect(func() -> void: return_to_lobby_requested.emit())
	column.add_child(lobby_button)


func _on_intro_updated(title: String, cue: String, match_point: bool) -> void:
	intro_label.text = ("MATCH POINT  //  " if match_point else "") + title
	cue_label.text = cue
	if cue == "FIGHT":
		AudioEvents.play(&"fight")
	elif match_point and cue == "3":
		AudioEvents.play(&"match_point")
	else:
		AudioEvents.play(&"round_countdown")
	_fade_center()


func _on_round_started(_round_number: int) -> void:
	get_tree().create_timer(0.75).timeout.connect(func() -> void:
		intro_label.text = ""
		cue_label.text = ""
	)


func _on_round_ended(winner_team: int, _team_a: int, _team_b: int) -> void:
	var won := local_participant != null and local_participant.team_id == winner_team
	intro_label.text = "ROUND WON" if won else "ROUND LOST"
	cue_label.text = ""
	AudioEvents.play(&"round_won" if won else &"round_lost")
	_fade_center()


func _on_sudden_death() -> void:
	intro_label.text = "SUDDEN DEATH"
	cue_label.text = "NO HEALING"
	_fade_center()


func _on_spectator_requested(_local: ArenaParticipantState, teammates: Array[ArenaParticipantState]) -> void:
	spectator_label.visible = true
	spectator_label.text = "SPECTATING %s  //  A/D OR ARROWS TO CYCLE" % (teammates[0].display_name if not teammates.is_empty() else "TEAM")


func _on_round_reset(_round: int, _swap: bool) -> void:
	spectator_label.visible = false
	results_panel.visible = false


func _on_results_ready(result: ArenaMatchResult) -> void:
	var won := result.local_player_won()
	result_title.text = "VICTORY" if won else "DEFEAT"
	result_title.add_theme_color_override("font_color", Color(0.02, 0.78, 0.95) if won else Color(0.95, 0.25, 0.20))
	result_score.text = "BLUE  %d  —  %d  RED" % [result.team_a_score, result.team_b_score]
	var stats := result.local_player_stats()
	result_stats.text = "%s\n\nKILLS  %d     DEATHS  %d\nDAMAGE  %d     HEADSHOTS  %d\nBEST ROUND DAMAGE  %d\nROUNDS PLAYED  %d" % [String(result.mode_display_name), int(stats.get("kills", 0)), int(stats.get("deaths", 0)), int(stats.get("damage_dealt", 0)), int(stats.get("headshots", 0)), int(stats.get("highest_damage_round", 0)), result.rounds_played]
	results_panel.visible = true
	play_again_button.grab_focus()
	AudioEvents.play(&"victory" if won else &"defeat")


func _fade_center() -> void:
	intro_label.modulate.a = 0.0
	cue_label.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(intro_label, "modulate:a", 1.0, 0.12)
	tween.tween_property(cue_label, "modulate:a", 1.0, 0.12)
