class_name GameHUD
extends CanvasLayer

const COLOR_TEXT := Color(0.91, 0.93, 0.96)
const COLOR_MUTED := Color(0.53, 0.59, 0.67)
const COLOR_ACCENT := Color(0.30, 0.78, 0.91)
const COLOR_READY := Color(0.30, 0.86, 0.69)
const COLOR_WARNING := Color(1.0, 0.34, 0.26)
const COLOR_PANEL := Color(0.025, 0.032, 0.045, 0.88)
const COLOR_PANEL_LIGHT := Color(0.052, 0.066, 0.086, 0.92)

var player: PlayerController
var bot: BotController
var game_manager: GameManager
var ui_root: Control

var health_panel: PanelContainer
var health_value_label: Label
var health_bar: ProgressBar
var health_warning_label: Label
var weapon_panel: PanelContainer
var weapon_name_label: Label
var ammo_label: Label
var reload_label: Label
var slot_one_label: Label
var slot_two_label: Label
var dash_panel: PanelContainer
var dash_state_label: Label
var jump_panel: PanelContainer
var jump_state_label: Label
var score_label: Label
var camera_label: Label
var status_label: Label
var headshot_label: Label
var debug_panel: PanelContainer
var debug_label: Label
var hitmarker: Label
var crosshair_root: Control
var damage_edges: Array[ColorRect] = []

var hitmarker_remaining: float = 0.0
var hitmarker_duration: float = 0.16
var status_remaining: float = 0.0
var status_duration: float = 1.0
var damage_flash_remaining: float = 0.0
var weapon_pulse_remaining: float = 0.0
var displayed_health: float = 100.0
var last_health: float = 100.0
var debug_visible: bool = false
var last_dash_ready: bool = true
var last_jump_ready: bool = true
var last_weapon_index: int = -1

var ready_skill_style: StyleBoxFlat
var cooling_skill_style: StyleBoxFlat
var normal_health_fill: StyleBoxFlat
var low_health_fill: StyleBoxFlat


func _ready() -> void:
	layer = 20
	_build_styles()
	_build_interface()


func bind(new_player: Node, new_bot: Node, manager: Node) -> void:
	player = new_player as PlayerController
	bot = new_bot as BotController
	game_manager = manager as GameManager
	player.feedback.connect(_on_player_feedback)
	game_manager.score_changed.connect(_on_score_changed)
	game_manager.kill_feed.connect(_on_kill_feed)
	displayed_health = player.health.current_health
	last_health = displayed_health


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		debug_visible = not debug_visible
		debug_panel.visible = debug_visible


func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(game_manager):
		return
	_update_feedback_animation(delta)
	_update_health(delta)
	_update_weapon_panel()
	_update_skills()
	_update_header()
	if debug_visible:
		_update_debug_overlay()


func _update_feedback_animation(delta: float) -> void:
	hitmarker_remaining = maxf(0.0, hitmarker_remaining - delta)
	status_remaining = maxf(0.0, status_remaining - delta)
	damage_flash_remaining = maxf(0.0, damage_flash_remaining - delta)
	weapon_pulse_remaining = maxf(0.0, weapon_pulse_remaining - delta)

	if hitmarker_remaining > 0.0:
		var hit_ratio := hitmarker_remaining / maxf(hitmarker_duration, 0.01)
		hitmarker.visible = true
		hitmarker.modulate.a = clampf(hit_ratio * 1.8, 0.0, 1.0)
		var marker_scale := lerpf(1.0, 1.32, hit_ratio)
		hitmarker.scale = Vector2.ONE * marker_scale
		headshot_label.modulate.a = clampf(hit_ratio * 1.5, 0.0, 1.0) if headshot_label.visible else 0.0
	else:
		hitmarker.visible = false
		headshot_label.visible = false

	if status_remaining > 0.0:
		var status_ratio := status_remaining / maxf(status_duration, 0.01)
		status_label.modulate.a = clampf(status_ratio * 2.0, 0.0, 1.0)
	else:
		status_label.text = ""

	var damage_alpha := 0.16 * clampf(damage_flash_remaining / 0.34, 0.0, 1.0)
	for edge in damage_edges:
		var edge_color := edge.color
		edge_color.a = damage_alpha
		edge.color = edge_color


func _update_health(delta: float) -> void:
	var hp := player.health.current_health
	var maximum := player.health.max_health
	displayed_health = move_toward(displayed_health, hp, maxf(30.0, absf(displayed_health - hp) * 6.0) * delta)
	health_bar.max_value = maximum
	health_bar.value = displayed_health
	health_value_label.text = "%03d" % ceili(hp)
	var health_ratio := hp / maxf(maximum, 1.0)
	var low_health := health_ratio <= 0.30
	health_warning_label.visible = low_health
	health_value_label.add_theme_color_override("font_color", COLOR_WARNING if low_health else COLOR_TEXT)
	health_bar.add_theme_stylebox_override("fill", low_health_fill if low_health else normal_health_fill)
	if low_health:
		var pulse := 0.72 + sin(Time.get_ticks_msec() * 0.008) * 0.16
		health_panel.modulate = Color(1.0, 0.72, 0.72, pulse + 0.18)
	else:
		health_panel.modulate = Color.WHITE
	if hp < last_health:
		damage_flash_remaining = maxf(damage_flash_remaining, 0.34)
	last_health = hp


func _update_weapon_panel() -> void:
	var weapon := player.current_weapon
	var weapon_name := weapon.weapon_display_name.to_upper() if weapon != null else "UNARMED"
	weapon_name_label.text = weapon_name
	if weapon is SniperWeapon:
		var sniper := weapon as SniperWeapon
		ammo_label.text = "%d / %d" % [sniper.ammo, sniper.magazine_size]
		reload_label.text = "RELOADING  %.1fs" % sniper.reload_remaining if sniper.is_reloading else "R  RELOAD"
		reload_label.add_theme_color_override("font_color", COLOR_WARNING if sniper.ammo == 0 else COLOR_MUTED)
	else:
		ammo_label.text = "MELEE"
		reload_label.text = "RMB  BLOCK / DEFLECT"
		reload_label.add_theme_color_override("font_color", COLOR_MUTED)

	var slot_one_active := player.current_weapon_index == 0
	slot_one_label.text = "[1]  KATANA"
	slot_two_label.text = "[2]  SNIPER"
	slot_one_label.add_theme_color_override("font_color", COLOR_ACCENT if slot_one_active else COLOR_MUTED)
	slot_two_label.add_theme_color_override("font_color", COLOR_ACCENT if not slot_one_active else COLOR_MUTED)
	if last_weapon_index != player.current_weapon_index:
		last_weapon_index = player.current_weapon_index
		weapon_pulse_remaining = 0.24
		weapon_panel.modulate = Color(0.76, 0.94, 1.0)
	elif weapon_pulse_remaining > 0.0:
		var pulse_ratio := weapon_pulse_remaining / 0.24
		weapon_panel.modulate = Color(1.0 - pulse_ratio * 0.24, 1.0 - pulse_ratio * 0.06, 1.0)
	else:
		weapon_panel.modulate = Color.WHITE


func _update_skills() -> void:
	var dash_cooldown := player.dash_skill.cooldown_remaining
	var dash_ready := dash_cooldown <= 0.0
	dash_state_label.text = "READY" if dash_ready else "%.1fs" % dash_cooldown
	dash_state_label.add_theme_color_override("font_color", COLOR_READY if dash_ready else COLOR_TEXT)
	if dash_ready != last_dash_ready:
		last_dash_ready = dash_ready
		dash_panel.add_theme_stylebox_override("panel", ready_skill_style if dash_ready else cooling_skill_style)

	var jump_cooldown := player.double_jump_skill.cooldown_remaining
	var jump_ready := jump_cooldown <= 0.0 and not player.double_jump_skill.used_this_airborne_sequence
	if jump_ready:
		jump_state_label.text = "READY"
	elif jump_cooldown > 0.0:
		jump_state_label.text = "%.1fs" % jump_cooldown
	else:
		jump_state_label.text = "SPENT"
	jump_state_label.add_theme_color_override("font_color", COLOR_READY if jump_ready else COLOR_TEXT)
	if jump_ready != last_jump_ready:
		last_jump_ready = jump_ready
		jump_panel.add_theme_stylebox_override("panel", ready_skill_style if jump_ready else cooling_skill_style)


func _update_header() -> void:
	score_label.text = "PLAYER   %02d     -     %02d   BOT" % [game_manager.player_kills, game_manager.bot_kills]
	camera_label.text = player.get_camera_mode_name()
	if player.is_cursor_free:
		camera_label.text += "  /  CURSOR"
	if player.current_weapon is KatanaWeapon and (player.current_weapon as KatanaWeapon).is_blocking:
		var katana := player.current_weapon as KatanaWeapon
		camera_label.text += "  /  DEFLECT" if katana.deflect_remaining > 0.0 else "  /  BLOCK"


func _update_debug_overlay() -> void:
	var movement := player.movement as PlayerMovementController
	var bot_distance := player.global_position.distance_to(bot.global_position) if is_instance_valid(bot) else 0.0
	var bot_data: Dictionary = bot.get_debug_snapshot() if is_instance_valid(bot) else {}
	debug_label.text = "DEVELOPER TELEMETRY\n\nFPS             %d\nPLAYER SPEED    %.2f m/s\nPLAYER VELOCITY %s\nMOVEMENT        %s\nGROUNDED        %s\nCROUCH / SLIDE  %s / %s\nAIR CONTROL     %s\nCOYOTE / BUFFER %.3f / %.3f\nBHOP CAP        %.2f m/s\nDASH            %.2fs\nDOUBLE JUMP     %s\nCAMERA          %s\n\nBOT STATE       %s\nBOT MOVEMENT    %s\nBOT WEAPON      %s\nBOT DISTANCE    %.1f m\nBOT HP          %.0f\nBOT LOS         %s\nMEMORY LEFT     %.2fs\nSTUCK TIMER     %.2fs\nRECOVERIES      %d\nSHOTS / SWINGS  %d / %d\nRELOADS / BLOCKS %d / %d" % [
		Engine.get_frames_per_second(),
		movement.get_horizontal_speed(),
		str(player.velocity),
		movement.movement_state,
		str(player.is_on_floor()),
		str(movement.is_crouching),
		str(movement.is_sliding),
		str(movement.air_control_active),
		movement.coyote_remaining,
		movement.jump_buffer_remaining,
		movement.bhop_speed_cap,
		player.dash_skill.cooldown_remaining,
		_cooldown_text(player.double_jump_skill.cooldown_remaining),
		player.get_camera_mode_name(),
		bot_data.get("state", "N/A"),
		bot_data.get("movement", "N/A"),
		bot_data.get("weapon", "N/A"),
		bot_distance,
		bot.health.current_health if is_instance_valid(bot) else 0.0,
		str(bot_data.get("los", false)),
		float(bot_data.get("memory", 0.0)),
		float(bot_data.get("stuck", 0.0)),
		int(bot_data.get("recoveries", 0)),
		int(bot_data.get("shots", 0)),
		int(bot_data.get("swings", 0)),
		int(bot_data.get("reloads", 0)),
		int(bot_data.get("blocks", 0)),
	]


func _cooldown_text(value: float) -> String:
	return "READY" if value <= 0.0 else "%.1fs" % value


func get_layout_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var viewport_size := ui_root.get_viewport_rect().size
	for control in [health_panel, weapon_panel, dash_panel, jump_panel, score_label, camera_label]:
		if control == null:
			errors.append("HUD control failed to instantiate")
			continue
		var rect: Rect2 = (control as Control).get_global_rect()
		if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > viewport_size.x + 1.0 or rect.end.y > viewport_size.y + 1.0:
			errors.append("HUD control outside viewport: %s at %s within %s" % [control.name, str(rect), str(viewport_size)])
	var crosshair_center := crosshair_root.get_global_rect().get_center()
	if crosshair_center.distance_to(viewport_size * 0.5) > 2.0:
		errors.append("Crosshair is not centered: %s versus %s" % [str(crosshair_center), str(viewport_size * 0.5)])
	if debug_panel.visible:
		errors.append("Debug panel is visible in normal HUD mode")
	return errors


func _on_score_changed(player_score: int, bot_score: int) -> void:
	score_label.text = "PLAYER   %02d     -     %02d   BOT" % [player_score, bot_score]


func _on_kill_feed(message: String) -> void:
	var color := COLOR_ACCENT if message.contains("ELIMINATED") else COLOR_WARNING
	_show_status(message, color, 1.8)


func _on_player_feedback(event_name: StringName, _data: Dictionary) -> void:
	match event_name:
		&"hitmarker":
			_show_hitmarker(false)
		&"headshot":
			_show_hitmarker(true)
		&"damage_taken":
			damage_flash_remaining = 0.34
		&"block":
			_show_status("BLOCKED", Color(0.38, 0.78, 1.0), 0.34)
		&"deflect":
			_show_status("PERFECT DEFLECT", Color(0.25, 1.0, 0.86), 0.76)
		&"launch":
			_show_status("LAUNCHED", Color(0.35, 0.86, 1.0), 0.50)
		&"double_jump":
			_show_status("DOUBLE JUMP", Color(0.55, 0.82, 1.0), 0.38)
		&"dash":
			_show_status("DASH", Color(0.72, 0.66, 1.0), 0.28)
		&"slide":
			_show_status("SLIDE", Color(0.62, 0.80, 1.0), 0.24)
		&"slide_jump":
			_show_status("SLIDE JUMP", Color(0.72, 0.90, 1.0), 0.32)
		&"empty":
			_show_status("EMPTY  /  PRESS R", COLOR_WARNING, 0.72)
		&"death":
			_show_status("YOU DIED", COLOR_WARNING, 2.0)
		&"respawn":
			_show_status("FIGHT", COLOR_TEXT, 0.62)


func _show_hitmarker(headshot: bool) -> void:
	hitmarker.text = "X"
	hitmarker.add_theme_color_override("font_color", Color(1.0, 0.32, 0.20) if headshot else Color.WHITE)
	hitmarker.add_theme_font_size_override("font_size", 30 if headshot else 24)
	hitmarker_duration = 0.30 if headshot else 0.17
	hitmarker_remaining = hitmarker_duration
	hitmarker.visible = true
	hitmarker.modulate.a = 1.0
	if headshot:
		headshot_label.visible = true
		headshot_label.modulate.a = 1.0


func _show_status(message: String, color: Color, duration: float) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", color)
	status_label.modulate.a = 1.0
	status_remaining = duration
	status_duration = duration


func _build_styles() -> void:
	ready_skill_style = _make_style(Color(0.03, 0.12, 0.12, 0.92), COLOR_READY, 2, 5)
	cooling_skill_style = _make_style(COLOR_PANEL_LIGHT, Color(0.20, 0.25, 0.31), 1, 5)
	normal_health_fill = _make_style(COLOR_ACCENT, COLOR_ACCENT, 0, 3)
	low_health_fill = _make_style(COLOR_WARNING, COLOR_WARNING, 0, 3)


func _build_interface() -> void:
	ui_root = Control.new()
	ui_root.name = "UIRoot"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	_build_damage_edges()
	_build_score_panel()
	_build_camera_chip()
	_build_health_panel()
	_build_weapon_panel()
	_build_skill_panel()
	_build_crosshair()
	_build_notifications()
	_build_debug_panel()


func _build_score_panel() -> void:
	var panel := _make_panel("ScorePanel", _make_style(COLOR_PANEL, Color(0.19, 0.25, 0.32), 1, 5))
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -190
	panel.offset_right = 190
	panel.offset_top = 16
	panel.offset_bottom = 58
	score_label = _make_label(panel, "PLAYER   00     -     00   BOT", 18, COLOR_TEXT)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_camera_chip() -> void:
	var panel := _make_panel("CameraChip", _make_style(COLOR_PANEL, Color(0.18, 0.23, 0.29), 1, 4))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -198
	panel.offset_right = -18
	panel.offset_top = 18
	panel.offset_bottom = 50
	camera_label = _make_label(panel, "FPP", 13, COLOR_MUTED)
	camera_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	camera_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_health_panel() -> void:
	health_panel = _make_panel("HealthPanel", _make_style(COLOR_PANEL, Color(0.18, 0.25, 0.32), 1, 6))
	health_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	health_panel.offset_left = 20
	health_panel.offset_right = 286
	health_panel.offset_top = -118
	health_panel.offset_bottom = -20
	var margin := _make_margin(health_panel, 14, 10, 14, 10)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)
	var hp_caption := _make_label(heading, "HEALTH", 12, COLOR_MUTED)
	hp_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_warning_label = _make_label(heading, "CRITICAL", 11, COLOR_WARNING)
	health_warning_label.visible = false
	health_value_label = _make_label(column, "100", 29, COLOR_TEXT)
	health_value_label.custom_minimum_size.y = 35
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(0, 9)
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.add_theme_stylebox_override("background", _make_style(Color(0.08, 0.10, 0.13), Color.TRANSPARENT, 0, 3))
	health_bar.add_theme_stylebox_override("fill", normal_health_fill)
	column.add_child(health_bar)


func _build_weapon_panel() -> void:
	weapon_panel = _make_panel("WeaponPanel", _make_style(COLOR_PANEL, Color(0.18, 0.25, 0.32), 1, 6))
	weapon_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_panel.offset_left = -326
	weapon_panel.offset_right = -20
	weapon_panel.offset_top = -146
	weapon_panel.offset_bottom = -20
	var margin := _make_margin(weapon_panel, 14, 10, 14, 9)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	weapon_name_label = _make_label(header, "KATANA", 20, COLOR_TEXT)
	weapon_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_label = _make_label(header, "MELEE", 22, COLOR_ACCENT)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reload_label = _make_label(column, "RMB  BLOCK / DEFLECT", 11, COLOR_MUTED)
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(separator)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 18)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(slots)
	slot_one_label = _make_label(slots, "[1]  KATANA", 12, COLOR_ACCENT)
	slot_one_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_two_label = _make_label(slots, "[2]  SNIPER", 12, COLOR_MUTED)


func _build_skill_panel() -> void:
	var skills := HBoxContainer.new()
	skills.name = "SkillPanel"
	skills.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skills.offset_left = -174
	skills.offset_right = 174
	skills.offset_top = -102
	skills.offset_bottom = -28
	skills.add_theme_constant_override("separation", 10)
	skills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(skills)
	dash_panel = _make_skill_card(skills, "Q", "DASH")
	dash_state_label = dash_panel.get_node("Margin/VBox/State") as Label
	jump_panel = _make_skill_card(skills, "SPACE x2", "DOUBLE JUMP")
	jump_state_label = jump_panel.get_node("Margin/VBox/State") as Label


func _make_skill_card(parent: Control, key_text: String, skill_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(169, 74)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", ready_skill_style)
	parent.add_child(panel)
	var margin := _make_margin(panel, 10, 7, 10, 6)
	margin.name = "Margin"
	var column := VBoxContainer.new()
	column.name = "VBox"
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)
	var key_label := _make_label(heading, key_text, 11, COLOR_ACCENT)
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := _make_label(heading, skill_name, 11, COLOR_MUTED)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var state_label := _make_label(column, "READY", 16, COLOR_READY)
	state_label.name = "State"
	return panel


func _build_crosshair() -> void:
	crosshair_root = Control.new()
	crosshair_root.name = "Crosshair"
	crosshair_root.set_anchors_preset(Control.PRESET_CENTER)
	crosshair_root.offset_left = -14
	crosshair_root.offset_right = 14
	crosshair_root.offset_top = -14
	crosshair_root.offset_bottom = 14
	crosshair_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(crosshair_root)
	_make_crosshair_bar(Vector2(13, 1), Vector2(2, 7))
	_make_crosshair_bar(Vector2(13, 20), Vector2(2, 7))
	_make_crosshair_bar(Vector2(1, 13), Vector2(7, 2))
	_make_crosshair_bar(Vector2(20, 13), Vector2(7, 2))
	_make_crosshair_bar(Vector2(13, 13), Vector2(2, 2))


func _build_notifications() -> void:
	hitmarker = _make_label(ui_root, "X", 24, Color.WHITE)
	hitmarker.name = "Hitmarker"
	hitmarker.set_anchors_preset(Control.PRESET_CENTER)
	hitmarker.offset_left = -28
	hitmarker.offset_right = 28
	hitmarker.offset_top = -28
	hitmarker.offset_bottom = 28
	hitmarker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hitmarker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hitmarker.pivot_offset = Vector2(28, 28)
	hitmarker.visible = false
	headshot_label = _make_label(ui_root, "HEADSHOT", 11, Color(1.0, 0.38, 0.22))
	headshot_label.set_anchors_preset(Control.PRESET_CENTER)
	headshot_label.offset_left = -70
	headshot_label.offset_right = 70
	headshot_label.offset_top = 32
	headshot_label.offset_bottom = 52
	headshot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headshot_label.visible = false
	status_label = _make_label(ui_root, "", 21, COLOR_TEXT)
	status_label.set_anchors_preset(Control.PRESET_CENTER)
	status_label.offset_left = -280
	status_label.offset_right = 280
	status_label.offset_top = 64
	status_label.offset_bottom = 100
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_debug_panel() -> void:
	debug_panel = _make_panel("DebugPanel", _make_style(Color(0.015, 0.025, 0.025, 0.93), Color(0.20, 0.68, 0.48), 1, 4))
	debug_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	debug_panel.offset_left = 16
	debug_panel.offset_right = 356
	debug_panel.offset_top = 16
	debug_panel.offset_bottom = 520
	var margin := _make_margin(debug_panel, 12, 10, 12, 10)
	debug_label = _make_label(margin, "", 12, Color(0.48, 0.96, 0.66))
	debug_panel.visible = false


func _build_damage_edges() -> void:
	_make_damage_edge(Control.PRESET_TOP_WIDE, 0, 0, 0, 54)
	_make_damage_edge(Control.PRESET_BOTTOM_WIDE, 0, -54, 0, 0)
	_make_damage_edge(Control.PRESET_LEFT_WIDE, 0, 0, 48, 0)
	_make_damage_edge(Control.PRESET_RIGHT_WIDE, -48, 0, 0, 0)


func _make_damage_edge(preset: int, left: float, top: float, right: float, bottom: float) -> void:
	var edge := ColorRect.new()
	edge.set_anchors_preset(preset)
	edge.offset_left = left
	edge.offset_top = top
	edge.offset_right = right
	edge.offset_bottom = bottom
	edge.color = Color(0.88, 0.02, 0.02, 0.0)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(edge)
	damage_edges.append(edge)


func _make_panel(panel_name: String, style: StyleBoxFlat) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	ui_root.add_child(panel)
	return panel


func _make_margin(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(margin)
	return margin


func _make_label(parent: Control, text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)
	return label


func _make_crosshair_bar(position: Vector2, bar_size: Vector2) -> void:
	var bar := ColorRect.new()
	bar.position = position
	bar.size = bar_size
	bar.color = Color(0.94, 0.97, 1.0, 0.88)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_root.add_child(bar)


func _make_style(background: Color, border: Color, border_width: int, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style
