class_name DungeonHUD
extends CanvasLayer

var timer_label: Label
var objective_label: Label
var prompt_label: Label
var inventory_label: Label
var weapon_label: Label
var health_label: Label
var skill_label: Label
var hitmarker_label: Label
var crosshair_label: Label
var status_label: Label
var damage_number_root: Control
var debug_label: Label
var summary_panel: PanelContainer
var summary_label: Label
var debug_visible: bool = false
var hitmarker_remaining: float = 0.0


func bind(player: PlayerController) -> void:
	player.feedback.connect(_on_player_feedback)


func _ready() -> void:
	layer = 25
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		debug_visible = not debug_visible
		debug_label.visible = debug_visible


func update_run(seconds_left: float, inventory: RunInventory, player: PlayerController, prompt: String, debug_data: Dictionary) -> void:
	var minutes := floori(seconds_left / 60.0)
	var seconds := floori(seconds_left) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	timer_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25) if seconds_left <= 60.0 else Color(0.9, 0.93, 0.95))
	inventory_label.text = "RUN PACK  %02d / 24     GOLD  %d%s" % [inventory.item_count(), inventory.run_gold, "     KEY" if inventory.has_definition(&"extraction_key") else ""]
	prompt_label.text = prompt
	var weapon := player.current_weapon
	weapon_label.text = "%s  %s\nDUR  %s" % [weapon.weapon_display_name.to_upper(), weapon.get_ammo_text(), weapon.get_durability_text()] if weapon != null else "UNARMED"
	health_label.text = "HP  %03d" % ceili(player.health.current_health)
	health_label.add_theme_color_override("font_color", Color(1.0, 0.34, 0.25) if player.health.current_health <= 30.0 else Color(0.9, 0.93, 0.95))
	var skill_lines: Array[String] = []
	for index: int in player.equipped_skills.size():
		var skill := player.equipped_skills[index]
		skill_lines.append("%s  %s  %s" % [skill.get_input_hint(), skill.skill_display_name.to_upper(), skill.get_status_text()])
	skill_label.text = "\n".join(skill_lines)
	crosshair_label.visible = GameSettings.crosshair_enabled
	var crosshair_spread := player.get_crosshair_spread()
	crosshair_label.add_theme_font_size_override("font_size", 18 + roundi(crosshair_spread * 0.45))
	crosshair_label.modulate.a = 0.4 if weapon != null and weapon.is_aiming_down_sights() else 0.9
	var statuses: Array[String] = []
	var status := player.get_node_or_null("StatusEffects") as StatusEffectComponent
	if status != null:
		for key: Variant in status.effects:
			var data: Dictionary = status.effects[key]
			statuses.append("%s %.1fs" % [String(key).to_upper(), float(data.get("remaining", 0.0))])
	if player.is_invisible: statuses.append("INVISIBLE")
	if player.damage_immunity_remaining > 0.0: statuses.append("PROTECTED %.1fs" % player.damage_immunity_remaining)
	status_label.text = "  •  ".join(statuses)
	if hitmarker_remaining > 0.0:
		hitmarker_remaining = maxf(0.0, hitmarker_remaining - get_process_delta_time())
		hitmarker_label.visible = hitmarker_remaining > 0.0
	if debug_visible:
		debug_label.text = "DUNGEON TELEMETRY\nSEED  %s\nNORMAL EXTRACTS  %s\nHIDDEN EXTRACTS  %s\nKEY SPAWNED  %s\nKEY HELD  %s\nENEMIES ALIVE  %s\nENEMIES WAKING  %s\nSPAWN PROTECTION  %.2fs\nRUN ITEMS  %s" % [debug_data.get("seed", 0), debug_data.get("normal", 0), debug_data.get("hidden", 0), debug_data.get("key_spawned", false), inventory.has_definition(&"extraction_key"), debug_data.get("enemies", 0), debug_data.get("waking", 0), debug_data.get("protection", 0.0), inventory.item_count()]


func show_summary(title: String, detail: String) -> void:
	summary_panel.visible = true
	summary_label.text = "%s\n\n%s\n\nReturning to lobby..." % [title, detail]


func show_notice(message: String) -> void:
	prompt_label.text = message


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	timer_label = _label(root, "15:00", 28, Color(0.9, 0.93, 0.95))
	timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_label.position = Vector2(-52, 20)
	timer_label.size = Vector2(104, 42)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label = _label(root, "THE ARMORY  /  FIND LOOT  /  EXTRACT", 12, Color(0.47, 0.77, 0.72))
	objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_label.position = Vector2(-155, 62)
	objective_label.size = Vector2(310, 24)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_label = _label(root, "RUN PACK  00 / 24", 14, Color(0.88, 0.9, 0.92))
	inventory_label.position = Vector2(24, 24)
	inventory_label.size = Vector2(380, 32)
	prompt_label = _label(root, "", 17, Color(0.95, 0.82, 0.45))
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-240, -104)
	prompt_label.size = Vector2(480, 40)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_label = _label(root, "", 13, Color(0.85, 0.89, 0.91))
	weapon_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_label.position = Vector2(-220, -92)
	weapon_label.size = Vector2(195, 58)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_label = _label(root, "HP  100", 22, Color(0.9, 0.93, 0.95))
	health_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	health_label.position = Vector2(24, -74)
	health_label.size = Vector2(180, 42)
	skill_label = _label(root, "", 12, Color(0.58, 0.82, 0.88))
	skill_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skill_label.position = Vector2(-330, -152)
	skill_label.size = Vector2(305, 54)
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	crosshair_label = _label(root, "+", 22, Color(0.92, 0.94, 0.95, 0.9))
	crosshair_label.set_anchors_preset(Control.PRESET_CENTER)
	crosshair_label.position = Vector2(-12, -15)
	crosshair_label.size = Vector2(24, 30)
	crosshair_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hitmarker_label = _label(root, "X", 26, Color.WHITE)
	hitmarker_label.set_anchors_preset(Control.PRESET_CENTER)
	hitmarker_label.position = Vector2(-18, -20)
	hitmarker_label.size = Vector2(36, 40)
	hitmarker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hitmarker_label.visible = false
	damage_number_root = Control.new()
	damage_number_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_number_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_number_root)
	debug_label = _label(root, "", 12, Color(0.73, 0.82, 0.82))
	debug_label.position = Vector2(20, 86)
	debug_label.size = Vector2(300, 240)
	debug_label.visible = false
	status_label = _label(root, "", 11, Color(0.55, 0.84, 0.88))
	status_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status_label.position = Vector2(-430, 62)
	status_label.size = Vector2(405, 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	summary_panel = PanelContainer.new()
	summary_panel.set_anchors_preset(Control.PRESET_CENTER)
	summary_panel.position = Vector2(-240, -135)
	summary_panel.size = Vector2(480, 270)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.028, 0.038, 0.97)
	style.border_color = Color(0.3, 0.68, 0.62)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	summary_panel.add_theme_stylebox_override("panel", style)
	root.add_child(summary_panel)
	summary_label = _label(summary_panel, "", 20, Color(0.92, 0.94, 0.95))
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary_panel.visible = false


func _label(parent: Control, text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _on_player_feedback(event_name: StringName, data: Dictionary) -> void:
	match event_name:
		&"hitmarker", &"headshot":
			hitmarker_label.visible = true
			hitmarker_label.add_theme_color_override("font_color", Color(1.0, 0.34, 0.22) if event_name == &"headshot" else Color.WHITE)
			hitmarker_remaining = 0.22
		&"damage_dealt":
			var blocked := bool(data.get("blocked", false))
			var killed := bool(data.get("killed", false))
			var elite := bool(data.get("elite", false))
			_spawn_damage_number(data)
			if blocked:
				show_notice("BLOCKED HIT")
			elif killed:
				show_notice("WARDEN ELIMINATED" if elite else "ENEMY ELIMINATED")
		&"broken_weapon":
			show_notice("%s IS BROKEN" % String(data.get("name", "WEAPON")).to_upper())


func _spawn_damage_number(data: Dictionary) -> void:
	if not GameSettings.damage_numbers or damage_number_root == null:
		return
	var amount := roundi(float(data.get("amount", 0.0)))
	if amount <= 0:
		return
	var headshot := bool(data.get("headshot", false))
	var blocked := bool(data.get("blocked", false))
	var label := _label(damage_number_root, str(amount), 20 if headshot else 16, Color(1.0, 0.42, 0.24) if headshot else Color(0.94, 0.95, 0.9))
	if blocked:
		label.text = "%d  BLOCK" % amount
		label.add_theme_color_override("font_color", Color(0.45, 0.8, 1.0))
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position = Vector2(randf_range(28.0, 62.0), randf_range(-62.0, -30.0))
	label.size = Vector2(110, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 42.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.12)
	tween.chain().tween_callback(label.queue_free)
