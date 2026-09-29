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
var durability_label: Label
var slot_one_label: Label
var slot_two_label: Label
var dash_panel: PanelContainer
var dash_state_label: Label
var jump_panel: PanelContainer
var jump_state_label: Label
var skill_panels: Array[PanelContainer] = []
var skill_name_labels: Array[Label] = []
var skill_key_labels: Array[Label] = []
var skill_state_labels: Array[Label] = []
var skill_ready_states: Array[bool] = [true, true]
var score_label: Label
var camera_label: Label
var status_label: Label
var headshot_label: Label
var debug_panel: PanelContainer
var debug_label: Label
var hitmarker: Label
var crosshair_root: Control
var damage_edges: Array[ColorRect] = []
var status_effect_label: Label
var damage_number_root: Control
var damage_number_pool: Array[Label] = []
var damage_number_cursor: int = 0
var damage_edge_values: Array[float] = [0.0, 0.0, 0.0, 0.0]

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
	_update_crosshair(delta)
	_update_status_effects()
	_update_damage_numbers(delta)
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

	var vignette := 0.025 * GameSettings.hit_effects_intensity * clampf(damage_flash_remaining / 0.34, 0.0, 1.0)
	for index: int in damage_edges.size():
		damage_edge_values[index] = move_toward(damage_edge_values[index], 0.0, delta * 2.8)
		var edge := damage_edges[index]
		var edge_color := edge.color
		edge_color.a = (vignette + damage_edge_values[index] * 0.19) * GameSettings.hit_effects_intensity
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
	durability_label.text = "DURABILITY  " + weapon.get_durability_text() if weapon != null and not weapon.get_durability_text().is_empty() else ""
	durability_label.add_theme_color_override("font_color", COLOR_WARNING if weapon != null and weapon.is_broken() else COLOR_MUTED)
	if weapon != null and weapon.uses_ammunition():
		ammo_label.text = weapon.get_ammo_text()
		var weapon_status := weapon.get_weapon_status()
		var mythic_hint := weapon.effects.get_status_hint()
		reload_label.text = mythic_hint if not mythic_hint.is_empty() else (weapon_status if weapon_status.begins_with("RELOADING") else "R  RELOAD  /  RMB  ADS")
		reload_label.add_theme_color_override("font_color", COLOR_WARNING if weapon.get_ammo_text().begins_with("0 ") else COLOR_MUTED)
	else:
		ammo_label.text = "MELEE"
		var mythic_hint := weapon.effects.get_status_hint() if weapon != null else ""
		reload_label.text = mythic_hint if not mythic_hint.is_empty() else ("RMB  BLOCK / DEFLECT" if weapon is KatanaWeapon and not weapon is KnightSwordWeapon else "RMB  BLOCK")
		reload_label.add_theme_color_override("font_color", COLOR_MUTED)

	var slot_one_active := player.current_weapon_index == 0
	slot_one_label.text = "[1]  %s" % _weapon_slot_name(0)
	slot_two_label.text = "[2]  %s" % _weapon_slot_name(1)
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
	for index: int in skill_panels.size():
		var skill: SkillBase = player.equipped_skills[index] if index < player.equipped_skills.size() else null
		if skill == null:
			skill_name_labels[index].text = "EMPTY"
			skill_key_labels[index].text = GameSettings.get_binding_text(&"skill_slot_1" if index == 0 else &"skill_slot_2")
			skill_state_labels[index].text = "--"
			skill_panels[index].add_theme_stylebox_override("panel", cooling_skill_style)
			continue
		var state_text := skill.get_status_text()
		var ready := state_text == "READY"
		skill_name_labels[index].text = skill.skill_display_name.to_upper()
		skill_key_labels[index].text = skill.get_input_hint()
		skill_state_labels[index].text = state_text
		skill_state_labels[index].add_theme_color_override("font_color", COLOR_READY if ready else COLOR_TEXT)
		if ready != skill_ready_states[index]:
			skill_ready_states[index] = ready
			skill_panels[index].add_theme_stylebox_override("panel", ready_skill_style if ready else cooling_skill_style)


func _update_header() -> void:
	score_label.text = "PLAYER   %02d     -     %02d   BOT" % [game_manager.player_kills, game_manager.bot_kills]
	camera_label.text = player.get_camera_mode_name()
	if player.is_cursor_free:
		camera_label.text += "  /  CURSOR"
	if player.current_weapon is KatanaWeapon and (player.current_weapon as KatanaWeapon).is_blocking:
		var katana := player.current_weapon as KatanaWeapon
		camera_label.text += "  /  DEFLECT" if katana.deflect_remaining > 0.0 else "  /  BLOCK"


func _update_crosshair(delta: float) -> void:
	crosshair_root.visible = GameSettings.crosshair_enabled and not player.should_hide_crosshair()
	var target_scale := 1.0 + player.get_crosshair_spread() * 0.055
	crosshair_root.scale = crosshair_root.scale.lerp(Vector2.ONE * target_scale, minf(1.0, delta * 18.0))
	crosshair_root.modulate.a = 0.30 if player.current_weapon != null and player.current_weapon.is_aiming_down_sights() else (0.72 if player.uses_simple_crosshair() else 1.0)
	for index: int in crosshair_root.get_child_count():
		var part := crosshair_root.get_child(index) as CanvasItem
		if part != null:
			part.visible = not player.uses_simple_crosshair() or index == crosshair_root.get_child_count() - 1


func _update_status_effects() -> void:
	var lines: Array[String] = []
	var status := player.get_node_or_null("StatusEffects") as StatusEffectComponent
	if status != null:
		for status_id: StringName in status.effects:
			var data: Dictionary = status.effects[status_id]
			lines.append("%s  %.1fs" % [String(status_id).replace("_", " ").to_upper(), float(data.get("remaining", 0.0))])
	if player.is_invisible:
		lines.append("INVISIBLE")
	if player.movement_buff_remaining > 0.0:
		lines.append("SPEED  %.1fs" % player.movement_buff_remaining)
	if player.damage_immunity_remaining > 0.0:
		lines.append("PROTECTED  %.1fs" % player.damage_immunity_remaining)
	status_effect_label.text = "\n".join(lines)


func _update_debug_overlay() -> void:
	var movement := player.movement as PlayerMovementController
	var bot_distance := player.global_position.distance_to(bot.global_position) if is_instance_valid(bot) else 0.0
	var bot_data: Dictionary = bot.get_debug_snapshot() if is_instance_valid(bot) else {}
	var skill_one: SkillBase = player.equipped_skills[0] if player.equipped_skills.size() > 0 else null
	var skill_two: SkillBase = player.equipped_skills[1] if player.equipped_skills.size() > 1 else null
	var player_vfx := player.get_node_or_null("VisualEffects")
	var active_vfx := int(player_vfx.call("get_active_vfx_count")) if player_vfx != null and player_vfx.has_method("get_active_vfx_count") else 0
	debug_label.text = "DEVELOPER TELEMETRY\n\nFPS             %d\nSCENE           ARENA\nPLAYER SPEED    %.2f m/s\nPLAYER VELOCITY %s\nMOVEMENT        %s\nGROUNDED        %s\nCROUCH / SLIDE  %s / %s\nAIR CONTROL     %s\nCOYOTE / BUFFER %.3f / %.3f\nBHOP CAP        %.2f m/s\nSKILL 1         %s\nSKILL 2         %s\nCAMERA          %s\nACTIVE VFX      %d\nAUDIO EVENTS    %d\n\nBOT STATE       %s\nBOT MOVEMENT    %s\nBOT WEAPON      %s\nBOT DISTANCE    %.1f m\nBOT HP          %.0f\nBOT LOS         %s\nMEMORY LEFT     %.2fs\nSTUCK TIMER     %.2fs\nRECOVERIES      %d\nSHOTS / SWINGS  %d / %d\nRELOADS / BLOCKS %d / %d" % [
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
		"%s / %s" % [skill_one.skill_display_name, skill_one.get_status_text()] if skill_one != null else "EMPTY",
		"%s / %s" % [skill_two.skill_display_name, skill_two.get_status_text()] if skill_two != null else "EMPTY",
		player.get_camera_mode_name(),
		active_vfx,
		AudioEvents.emitted_count,
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
			_show_hitmarker_kind(&"normal")
		&"headshot":
			_show_hitmarker_kind(&"headshot")
		&"damage_dealt":
			_show_damage_feedback(_data)
		&"damage_taken":
			_show_directional_damage(_data)
		&"block":
			_show_status("BLOCKED", Color(0.38, 0.78, 1.0), 0.34)
		&"deflect":
			_show_status("PERFECT DEFLECT", Color(0.25, 1.0, 0.86), 0.76)
			_show_hitmarker_kind(&"deflect")
		&"affix_proc", &"affix_impact":
			_show_hitmarker_kind(&"proc")
		&"mythic_ready", &"mythic_proc":
			var mythic_name := String(_data.get("mythic", "mythic")).replace("_", " ").to_upper()
			_show_status("%s  %s" % [mythic_name, "READY" if event_name == &"mythic_ready" else "ACTIVE"], Color(0.76, 0.48, 1.0), 0.62)
		&"launch":
			_show_status("LAUNCHED", Color(0.35, 0.86, 1.0), 0.50)
		&"double_jump":
			_show_status("DOUBLE JUMP", Color(0.55, 0.82, 1.0), 0.38)
		&"dash":
			_show_status("DASH", Color(0.72, 0.66, 1.0), 0.28)
		&"grapple":
			_show_status("GRAPPLE", Color(0.40, 0.88, 1.0), 0.42)
		&"grapple_miss":
			_show_status("NO GRAPPLE TARGET", COLOR_MUTED, 0.42)
		&"blink":
			_show_status("BLINK", Color(0.74, 0.58, 1.0), 0.34)
		&"slide":
			_show_status("SLIDE", Color(0.62, 0.80, 1.0), 0.24)
		&"slide_jump":
			_show_status("SLIDE JUMP", Color(0.72, 0.90, 1.0), 0.32)
		&"empty":
			_show_status("EMPTY  /  PRESS R", COLOR_WARNING, 0.72)
		&"broken_weapon":
			_show_status("WEAPON BROKEN  /  REPAIR IN STASH", COLOR_WARNING, 1.2)
		&"death":
			_show_status("YOU DIED", COLOR_WARNING, 2.0)
		&"respawn":
			_show_status("FIGHT", COLOR_TEXT, 0.62)


func _show_damage_feedback(data: Dictionary) -> void:
	var amount := float(data.get("amount", 0.0))
	var blocked := bool(data.get("blocked", false))
	var parried := bool(data.get("parried", false))
	var headshot := bool(data.get("headshot", false))
	var killed := bool(data.get("killed", false))
	var elite := bool(data.get("elite", false))
	var armor_hit := bool(data.get("armor_hit", false))
	var critical := bool(data.get("critical", false))
	var proc := bool(data.get("proc", false))
	var dot := bool(data.get("dot", false))
	var marker_kind: StringName = &"parry" if parried else (&"blocked" if blocked else (&"armor" if armor_hit else (&"kill" if killed else (&"headshot" if headshot else (&"critical" if critical else (&"proc" if proc else (&"dot" if dot else &"normal")))))))
	_show_hitmarker_kind(marker_kind)
	if parried:
		_show_status("PARRIED", Color(0.25, 1.0, 0.86), 0.6)
	elif blocked:
		_show_status("BLOCKED HIT", Color(0.38, 0.78, 1.0), 0.42)
	elif armor_hit:
		_show_status("ARMOR HIT", Color(0.42, 0.76, 1.0), 0.30)
	elif elite:
		_show_status("WARDEN HIT" if killed else "ELITE HIT", Color(0.94, 0.63, 0.28), 0.34)
	if GameSettings.damage_numbers and amount > 0.0:
		_spawn_damage_number(amount, marker_kind)


func _spawn_damage_number(amount: float, kind: StringName) -> void:
	if damage_number_pool.is_empty():
		return
	var label := damage_number_pool[damage_number_cursor]
	damage_number_cursor = (damage_number_cursor + 1) % damage_number_pool.size()
	var colors := {
		&"normal": Color(0.95, 0.94, 0.82), &"headshot": Color(1.0, 0.34, 0.18),
		&"blocked": Color(0.40, 0.78, 1.0), &"armor": Color(0.34, 0.68, 1.0),
		&"dot": Color(0.74, 0.58, 1.0), &"critical": Color(1.0, 0.82, 0.22),
		&"proc": Color(0.86, 0.42, 1.0), &"kill": Color(1.0, 0.22, 0.14),
		&"parry": Color(0.28, 1.0, 0.86),
	}
	label.text = ("+" if kind in [&"critical", &"proc"] else "") + str(roundi(amount))
	label.add_theme_color_override("font_color", colors.get(kind, colors[&"normal"]))
	label.add_theme_font_size_override("font_size", 20 if kind in [&"headshot", &"critical", &"kill"] else 15)
	var lane := damage_number_cursor % 5
	label.position = Vector2(-45.0 + lane * 19.0, -48.0 - (damage_number_cursor % 3) * 8.0)
	label.modulate.a = 1.0
	label.visible = true
	label.set_meta("remaining", 0.62)
	label.set_meta("duration", 0.62)
	label.set_meta("drift", Vector2((lane - 2) * 7.0, -58.0))


func _update_damage_numbers(delta: float) -> void:
	for label: Label in damage_number_pool:
		if not label.visible:
			continue
		var remaining := maxf(0.0, float(label.get_meta("remaining", 0.0)) - delta)
		label.set_meta("remaining", remaining)
		var drift: Vector2 = label.get_meta("drift", Vector2(0.0, -55.0))
		label.position += drift * delta
		var duration := maxf(0.01, float(label.get_meta("duration", 0.62)))
		label.modulate.a = clampf(remaining / duration * 1.55, 0.0, 1.0)
		if remaining <= 0.0:
			label.visible = false


func _show_hitmarker_kind(kind: StringName) -> void:
	var styles := {
		&"normal": ["X", Color.WHITE, 24, 0.17, ""],
		&"headshot": ["><", Color(1.0, 0.30, 0.16), 29, 0.28, "HEADSHOT"],
		&"armor": ["[]", Color(0.34, 0.72, 1.0), 23, 0.20, "ARMOR"],
		&"blocked": ["/\\", Color(0.42, 0.82, 1.0), 22, 0.20, "BLOCKED"],
		&"parry": ["<>", Color(0.25, 1.0, 0.86), 27, 0.28, "PARRIED"],
		&"deflect": ["<>", Color(0.22, 1.0, 0.82), 29, 0.30, "DEFLECT"],
		&"critical": ["*", Color(1.0, 0.82, 0.18), 32, 0.27, "CRITICAL"],
		&"proc": ["+", Color(0.84, 0.42, 1.0), 28, 0.22, "PROC"],
		&"dot": [".", Color(0.72, 0.54, 1.0), 30, 0.14, ""],
		&"kill": ["#", Color(1.0, 0.20, 0.12), 31, 0.34, "KILL"],
	}
	var style: Array = styles.get(kind, styles[&"normal"])
	hitmarker.text = String(style[0])
	hitmarker.add_theme_color_override("font_color", style[1] as Color)
	hitmarker.add_theme_font_size_override("font_size", int(style[2]))
	hitmarker_duration = float(style[3])
	hitmarker_remaining = hitmarker_duration
	hitmarker.visible = true
	hitmarker.modulate.a = 1.0
	headshot_label.text = String(style[4])
	if not headshot_label.text.is_empty():
		headshot_label.visible = true
		headshot_label.modulate.a = 1.0


func _show_hitmarker(headshot: bool) -> void:
	_show_hitmarker_kind(&"headshot" if headshot else &"normal")


func _show_directional_damage(data: Dictionary) -> void:
	damage_flash_remaining = 0.34
	var source: Variant = data.get("source_position", null)
	if not source is Vector3 or not is_instance_valid(player):
		for index: int in damage_edge_values.size():
			damage_edge_values[index] = maxf(damage_edge_values[index], 0.45)
		return
	var to_source := (source as Vector3) - player.global_position
	to_source.y = 0.0
	if to_source.length_squared() < 0.01:
		return
	to_source = to_source.normalized()
	var forward := -player.global_basis.z
	var right := player.global_basis.x
	var forward_amount := forward.dot(to_source)
	var right_amount := right.dot(to_source)
	var edge_index := 0 if forward_amount >= 0.0 else 1
	if absf(right_amount) > absf(forward_amount):
		edge_index = 3 if right_amount > 0.0 else 2
	damage_edge_values[edge_index] = 1.0
	for index: int in damage_edge_values.size():
		if index != edge_index:
			damage_edge_values[index] = maxf(damage_edge_values[index], 0.12)


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
	weapon_panel.offset_left = -380
	weapon_panel.offset_right = -20
	weapon_panel.offset_top = -146
	weapon_panel.offset_bottom = -20
	var margin := _make_margin(weapon_panel, 14, 10, 14, 9)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	weapon_name_label = _make_label(header, "KATANA", 18, COLOR_TEXT)
	weapon_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_label = _make_label(header, "MELEE", 18, COLOR_ACCENT)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reload_label = _make_label(column, "RMB  BLOCK / DEFLECT", 11, COLOR_MUTED)
	durability_label = _make_label(column, "DURABILITY  100 / 100", 10, COLOR_MUTED)
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(separator)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 18)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(slots)
	slot_one_label = _make_label(slots, "[1]  KATANA", 11, COLOR_ACCENT)
	slot_one_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_two_label = _make_label(slots, "[2]  SNIPER", 11, COLOR_MUTED)


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
	dash_panel = _make_skill_card(skills, GameSettings.get_binding_text(&"skill_slot_1"), "DASH")
	dash_state_label = dash_panel.get_node("Margin/VBox/State") as Label
	jump_panel = _make_skill_card(skills, GameSettings.get_binding_text(&"skill_slot_2"), "DOUBLE JUMP")
	jump_state_label = jump_panel.get_node("Margin/VBox/State") as Label
	skill_panels = [dash_panel, jump_panel]
	skill_state_labels = [dash_state_label, jump_state_label]
	for panel: PanelContainer in skill_panels:
		skill_key_labels.append(panel.get_node("Margin/VBox/Heading/Key") as Label)
		skill_name_labels.append(panel.get_node("Margin/VBox/Heading/Name") as Label)


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
	heading.name = "Heading"
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)
	var key_label := _make_label(heading, key_text, 11, COLOR_ACCENT)
	key_label.name = "Key"
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := _make_label(heading, skill_name, 11, COLOR_MUTED)
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var state_label := _make_label(column, "READY", 16, COLOR_READY)
	state_label.name = "State"
	return panel


func _weapon_slot_name(index: int) -> String:
	if index < 0 or index >= player.weapons.size():
		return "EMPTY"
	return player.weapons[index].weapon_display_name.to_upper()


func _build_crosshair() -> void:
	crosshair_root = Control.new()
	crosshair_root.name = "Crosshair"
	crosshair_root.set_anchors_preset(Control.PRESET_CENTER)
	crosshair_root.offset_left = -14
	crosshair_root.offset_right = 14
	crosshair_root.offset_top = -14
	crosshair_root.offset_bottom = 14
	crosshair_root.pivot_offset = Vector2(14, 14)
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
	status_effect_label = _make_label(ui_root, "", 11, Color(0.62, 0.84, 0.91))
	status_effect_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status_effect_label.offset_left = -230
	status_effect_label.offset_right = -20
	status_effect_label.offset_top = 62
	status_effect_label.offset_bottom = 150
	status_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	damage_number_root = Control.new()
	damage_number_root.name = "DamageNumbers"
	damage_number_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_number_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(damage_number_root)
	for index: int in 14:
		var damage_label := _make_label(damage_number_root, "", 15, COLOR_TEXT)
		damage_label.name = "DamageNumber%02d" % index
		damage_label.set_anchors_preset(Control.PRESET_CENTER)
		damage_label.size = Vector2(90, 32)
		damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		damage_label.visible = false
		damage_number_pool.append(damage_label)


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
