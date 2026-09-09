class_name GameHUD
extends CanvasLayer

var player: Node
var bot: Node
var game_manager: Node
var ui_root: Control
var stats_label: Label
var abilities_label: Label
var score_label: Label
var camera_label: Label
var status_label: Label
var debug_label: Label
var hitmarker: Label
var damage_flash: ColorRect
var crosshair_parts: Array[ColorRect] = []
var hitmarker_remaining: float = 0.0
var status_remaining: float = 0.0
var damage_flash_remaining: float = 0.0
var debug_visible: bool = false


func _ready() -> void:
	layer = 20
	_build_interface()


func bind(new_player: Node, new_bot: Node, manager: Node) -> void:
	player = new_player
	bot = new_bot
	game_manager = manager
	player.feedback.connect(_on_player_feedback)
	game_manager.score_changed.connect(_on_score_changed)
	game_manager.kill_feed.connect(_on_kill_feed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		debug_visible = not debug_visible
		debug_label.visible = debug_visible


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	hitmarker_remaining = maxf(0.0, hitmarker_remaining - delta)
	status_remaining = maxf(0.0, status_remaining - delta)
	damage_flash_remaining = maxf(0.0, damage_flash_remaining - delta)
	hitmarker.visible = hitmarker_remaining > 0.0
	if status_remaining <= 0.0:
		status_label.text = ""
	var flash_color := damage_flash.color
	flash_color.a = 0.18 * clampf(damage_flash_remaining / 0.3, 0.0, 1.0)
	damage_flash.color = flash_color

	var hp: float = float(player.health.current_health)
	var maximum: float = float(player.health.max_health)
	var weapon_name: String = str(player.current_weapon.weapon_display_name) if player.current_weapon != null else "None"
	var ammo_text := ""
	if player.current_weapon is SniperWeapon:
		var sniper := player.current_weapon as SniperWeapon
		ammo_text = "  |  AMMO %d / %d%s" % [sniper.ammo, sniper.magazine_size, "  RELOADING" if sniper.is_reloading else ""]
	stats_label.text = "HP %03d / %03d  |  %s%s" % [ceili(hp), ceili(maximum), weapon_name.to_upper(), ammo_text]
	abilities_label.text = "DASH %s   •   DOUBLE JUMP %s" % [
		_cooldown_text(player.dash_skill.cooldown_remaining),
		_cooldown_text(player.double_jump_skill.cooldown_remaining)
	]
	score_label.text = "PLAYER  %d    —    %d  BOT" % [game_manager.player_kills, game_manager.bot_kills]
	camera_label.text = "%s  |  %s" % [player.get_camera_mode_name(), "CURSOR FREE" if player.is_cursor_free else "MOUSE CAPTURED"]
	if player.current_weapon is KatanaWeapon and (player.current_weapon as KatanaWeapon).is_blocking:
		var katana := player.current_weapon as KatanaWeapon
		camera_label.text += "  |  %s" % ("PERFECT DEFLECT" if katana.deflect_remaining > 0.0 else "BLOCKING 70%")

	if debug_visible:
		var bot_distance: float = player.global_position.distance_to(bot.global_position) if is_instance_valid(bot) else 0.0
		var movement := player.movement as PlayerMovementController
		debug_label.text = "FPS %d\nHorizontal %.2f m/s\nVelocity %s\nGrounded %s\nCrouching %s\nSliding %s\nAir control %s\nCoyote %.3f\nJump buffer %.3f\nBhop %.2f / %.2f\nMovement %s\nDash %.2f\nDouble jump %s\nWeapon %s\nCamera %s\nBot state %s\nBot distance %.1f m" % [
			Engine.get_frames_per_second(),
			movement.get_horizontal_speed(),
			str(player.velocity),
			str(player.is_on_floor()),
			str(movement.is_crouching),
			str(movement.is_sliding),
			str(movement.air_control_active),
			movement.coyote_remaining,
			movement.jump_buffer_remaining,
			movement.get_horizontal_speed(),
			movement.bhop_speed_cap,
			movement.movement_state,
			player.dash_skill.cooldown_remaining,
			"READY" if player.double_jump_skill.cooldown_remaining <= 0.0 and not player.double_jump_skill.used_this_airborne_sequence else "%.2f" % player.double_jump_skill.cooldown_remaining,
			weapon_name,
			player.get_camera_mode_name(),
			bot.ai_state if is_instance_valid(bot) else "N/A",
			bot_distance
		]


func _cooldown_text(value: float) -> String:
	return "READY" if value <= 0.0 else "%.1fs" % value


func _on_score_changed(_player_score: int, _bot_score: int) -> void:
	pass


func _on_kill_feed(message: String) -> void:
	_show_status(message, Color(1.0, 0.8, 0.38), 1.8)


func _on_player_feedback(event_name: StringName, _data: Dictionary) -> void:
	match event_name:
		&"hitmarker":
			_show_hitmarker(false)
		&"headshot":
			_show_hitmarker(true)
		&"damage_taken":
			damage_flash_remaining = 0.3
		&"block":
			_show_status("BLOCK", Color(0.35, 0.75, 1.0), 0.32)
		&"deflect":
			_show_status("PERFECT DEFLECT", Color(0.25, 1.0, 0.92), 0.75)
		&"launch":
			_show_status("LAUNCH!", Color(0.2, 0.9, 1.0), 0.55)
		&"double_jump":
			_show_status("DOUBLE JUMP", Color(0.55, 0.82, 1.0), 0.4)
		&"dash":
			_show_status("DASH", Color(0.7, 0.65, 1.0), 0.3)
		&"slide":
			_show_status("SLIDE", Color(0.62, 0.8, 1.0), 0.25)
		&"slide_jump":
			_show_status("SLIDE JUMP", Color(0.72, 0.9, 1.0), 0.35)
		&"empty":
			_show_status("EMPTY — PRESS R", Color(1.0, 0.45, 0.35), 0.7)
		&"death":
			_show_status("YOU DIED — RESPAWNING", Color(1.0, 0.2, 0.2), 2.0)
		&"respawn":
			_show_status("FIGHT", Color(0.92, 0.92, 1.0), 0.65)


func _show_hitmarker(headshot: bool) -> void:
	hitmarker.text = "◆" if headshot else "×"
	hitmarker.add_theme_color_override("font_color", Color(1.0, 0.28, 0.18) if headshot else Color.WHITE)
	hitmarker.add_theme_font_size_override("font_size", 34 if headshot else 28)
	hitmarker_remaining = 0.28 if headshot else 0.16


func _show_status(message: String, color: Color, duration: float) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", color)
	status_remaining = duration


func _build_interface() -> void:
	ui_root = Control.new()
	ui_root.name = "UIRoot"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	damage_flash = ColorRect.new()
	damage_flash.name = "DamageFlash"
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.color = Color(0.8, 0.02, 0.02, 0.0)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(damage_flash)

	var top_panel := ColorRect.new()
	top_panel.position = Vector2(14, 14)
	top_panel.size = Vector2(520, 82)
	top_panel.color = Color(0.025, 0.03, 0.045, 0.8)
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(top_panel)

	stats_label = _make_label(Vector2(28, 25), Vector2(640, 28), 20)
	abilities_label = _make_label(Vector2(28, 57), Vector2(640, 24), 16)
	abilities_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))

	score_label = _make_label(Vector2.ZERO, Vector2(420, 34), 22)
	score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	score_label.offset_left = -210
	score_label.offset_right = 210
	score_label.offset_top = 20
	score_label.offset_bottom = 54
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	camera_label = _make_label(Vector2.ZERO, Vector2(420, 24), 13)
	camera_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	camera_label.offset_left = -438
	camera_label.offset_right = -18
	camera_label.offset_top = 20
	camera_label.offset_bottom = 44
	camera_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	camera_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))

	status_label = _make_label(Vector2.ZERO, Vector2(600, 42), 25)
	status_label.set_anchors_preset(Control.PRESET_CENTER)
	status_label.offset_left = -300
	status_label.offset_right = 300
	status_label.offset_top = 62
	status_label.offset_bottom = 104
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	hitmarker = _make_label(Vector2.ZERO, Vector2(80, 60), 28)
	hitmarker.set_anchors_preset(Control.PRESET_CENTER)
	hitmarker.offset_left = -40
	hitmarker.offset_right = 40
	hitmarker.offset_top = -30
	hitmarker.offset_bottom = 30
	hitmarker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hitmarker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hitmarker.visible = false

	_make_crosshair_bar(Vector2(-1, -10), Vector2(2, 7))
	_make_crosshair_bar(Vector2(-1, 4), Vector2(2, 7))
	_make_crosshair_bar(Vector2(-10, -1), Vector2(7, 2))
	_make_crosshair_bar(Vector2(4, -1), Vector2(7, 2))

	debug_label = _make_label(Vector2(18, 108), Vector2(330, 430), 14)
	debug_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.58))
	debug_label.visible = false

	var controls := _make_label(Vector2.ZERO, Vector2(580, 26), 13)
	controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 18
	controls.offset_right = 598
	controls.offset_top = -40
	controls.offset_bottom = -14
	controls.text = "WASD Move  •  Shift Sprint  •  Ctrl Crouch/Slide  •  Space Jump  •  Q Dash  •  V Camera  •  1/2 Weapons  •  F3 Debug"
	controls.add_theme_color_override("font_color", Color(0.58, 0.62, 0.7))


func _make_label(position: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	ui_root.add_child(label)
	return label


func _make_crosshair_bar(offset: Vector2, bar_size: Vector2) -> void:
	var bar := ColorRect.new()
	bar.set_anchors_preset(Control.PRESET_CENTER)
	bar.offset_left = offset.x
	bar.offset_right = offset.x + bar_size.x
	bar.offset_top = offset.y
	bar.offset_bottom = offset.y + bar_size.y
	bar.color = Color(0.95, 0.98, 1.0, 0.9)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(bar)
	crosshair_parts.append(bar)
