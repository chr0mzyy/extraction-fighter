class_name ArenaMatchUI
extends CanvasLayer

signal play_again_requested
signal return_to_lobby_requested

const ACCENT := Color(0.02, 0.74, 0.90)
const GOLD := Color(1.0, 0.78, 0.08)
const PANEL := Color(0.012, 0.018, 0.022, 0.985)

var manager: ArenaMatchManager
var local_participant: ArenaParticipantState
var root: Control
var intro_label: Label
var cue_label: Label
var spectator_label: Label
var results_panel: PanelContainer
var result_title: Label
var result_score: Label
var result_stats: Label
var progression_text: Label
var account_progress: ProgressBar
var result_continue_button: Button
var rematch_button: Button
var current_result: ArenaMatchResult
var current_grant: Dictionary = {}


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
	manager.spectator_requested.connect(_on_spectator_requested)
	manager.round_reset_requested.connect(_on_round_reset)


func present_results(result: ArenaMatchResult, progression_grant: Dictionary = {}) -> void:
	current_result = result
	current_grant = progression_grant.duplicate(true)
	_show_results()


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center.position = Vector2(-260, 118)
	center.size = Vector2(520, 180)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	intro_label = _label(30, Color(0.92, 0.96, 0.98), HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(intro_label)
	cue_label = _label(58, ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(cue_label)
	spectator_label = _label(18, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	spectator_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	spectator_label.position = Vector2(-310, -130)
	spectator_label.size = Vector2(620, 80)
	spectator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spectator_label.visible = false
	root.add_child(spectator_label)
	_build_results_panel()


func _build_results_panel() -> void:
	results_panel = PanelContainer.new()
	results_panel.name = "ArenaProgressionResults"
	results_panel.set_anchors_preset(Control.PRESET_CENTER)
	results_panel.position = Vector2(-350, -290)
	results_panel.size = Vector2(700, 580)
	results_panel.visible = false
	results_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	results_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, ACCENT, 2, 28))
	root.add_child(results_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	results_panel.add_child(column)
	result_title = _label(42, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(result_title)
	result_score = _label(26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(result_score)
	result_stats = _label(15, Color(0.78, 0.84, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	result_stats.custom_minimum_size.y = 112
	column.add_child(result_stats)
	var rule := HSeparator.new()
	rule.modulate = ACCENT
	column.add_child(rule)
	progression_text = _label(16, Color(0.90, 0.93, 0.92), HORIZONTAL_ALIGNMENT_CENTER)
	progression_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progression_text.custom_minimum_size.y = 105
	column.add_child(progression_text)
	account_progress = ProgressBar.new()
	account_progress.name = "AccountXPProgress"
	account_progress.show_percentage = false
	account_progress.custom_minimum_size.y = 18
	column.add_child(account_progress)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)
	rematch_button = _action_button("REMATCH")
	rematch_button.pressed.connect(func() -> void: play_again_requested.emit())
	actions.add_child(rematch_button)
	result_continue_button = _action_button("RETURN TO LOBBY")
	result_continue_button.pressed.connect(func() -> void: return_to_lobby_requested.emit())
	actions.add_child(result_continue_button)


func _show_results() -> void:
	if current_result == null:
		return
	var won := current_result.local_player_won()
	result_title.text = "VICTORY" if won else "DEFEAT"
	result_title.add_theme_color_override("font_color", ACCENT if won else Color(0.95, 0.25, 0.20))
	result_score.text = "BLUE  %d  —  %d  RED" % [current_result.team_a_score, current_result.team_b_score]
	var stats := current_result.local_player_stats()
	result_stats.text = "%s  //  CASUAL LOCAL\n\nKILLS  %d     DEATHS  %d\nDAMAGE  %d     HEADSHOTS  %d\nBEST ROUND DAMAGE  %d     ROUNDS  %d" % [String(current_result.mode_display_name), int(stats.get("kills", 0)), int(stats.get("deaths", 0)), int(stats.get("damage_dealt", 0)), int(stats.get("headshots", 0)), int(stats.get("highest_damage_round", 0)), current_result.rounds_played]
	if current_result.abandoned:
		progression_text.text = "MATCH ABANDONED\nNo account XP, mastery or Style Tokens awarded."
		account_progress.visible = false
	else:
		var mastery_lines: Array[String] = []
		var mastery: Dictionary = current_grant.get("mastery", {}) as Dictionary
		for family: Variant in mastery.keys():
			mastery_lines.append("%s MASTERY  +%d" % [String(family).replace("_", " ").to_upper(), int(mastery[family])])
		if mastery_lines.is_empty():
			mastery_lines.append("MASTERY  +0")
		var unlocked: Array = current_grant.get("unlocked_cosmetics", []) as Array
		if not unlocked.is_empty():
			mastery_lines.append("COSMETIC UNLOCK  //  %s" % ", ".join(unlocked))
		progression_text.text = "ACCOUNT XP  +%d     STYLE TOKENS  +%d\n%s%s" % [int(current_grant.get("account_xp", 0)), int(current_grant.get("style_tokens", 0)), "\n".join(mastery_lines), "\nREWARD ALREADY CLAIMED" if bool(current_grant.get("duplicate", false)) else ""]
		var level := PlayerProfile.account_level
		var level_start := ArenaProgressionService.xp_required_for_level(level)
		var level_end := ArenaProgressionService.xp_required_for_level(level + 1)
		account_progress.min_value = level_start
		account_progress.max_value = max(level_start + 1, level_end)
		account_progress.value = PlayerProfile.account_xp
		account_progress.tooltip_text = "LEVEL %d  //  %d / %d XP" % [level, PlayerProfile.account_xp, level_end]
		account_progress.visible = true
	results_panel.visible = true
	result_continue_button.grab_focus()
	AudioEvents.play(&"victory" if won else &"defeat")


func _on_intro_updated(title: String, cue: String, match_point: bool) -> void:
	intro_label.text = ("MATCH POINT  //  " if match_point else "") + title
	cue_label.text = cue
	AudioEvents.play(&"fight" if cue == "FIGHT" else (&"match_point" if match_point and cue == "3" else &"round_countdown"))
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


func _action_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(210, 50)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.045, 0.055, 0.058), Color(0.28, 0.34, 0.35), 1, 8))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.06, 0.13, 0.15), ACCENT, 2, 8))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.11, 0.12, 0.07), GOLD, 2, 8))
	button.mouse_entered.connect(func() -> void: AudioEvents.play(&"ui_hover"))
	return button


func _label(font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result := Label.new()
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.horizontal_alignment = alignment
	return result


func _panel_style(background: Color, border: Color, width: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(margin)
	return style


func _fade_center() -> void:
	intro_label.modulate.a = 0.0
	cue_label.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(intro_label, "modulate:a", 1.0, 0.12)
	tween.tween_property(cue_label, "modulate:a", 1.0, 0.12)
