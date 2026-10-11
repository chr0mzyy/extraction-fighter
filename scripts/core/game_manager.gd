class_name GameManager
extends Node3D

signal score_changed(player_score: int, bot_score: int)
signal kill_feed(message: String)
signal arena_match_result_ready(result: ArenaMatchResult)

const BOT_SCENE := preload("res://scenes/characters/bot.tscn")
const MODE_1V1 := preload("res://resources/arena/mode_1v1.tres")
const MODE_2V2 := preload("res://resources/arena/mode_2v2.tres")

@export var respawn_delay: float = 2.0

@onready var player: PlayerController = $Player
@onready var bot: BotController = $Bot
@onready var hud: GameHUD = $HUD

var player_kills: int = 0
var bot_kills: int = 0
var pause_layer: CanvasLayer
var pause_panel: PanelContainer
var pause_menu_column: VBoxContainer
var pause_settings_column: VBoxContainer
var pause_health_label: Label
var pause_armor_label: Label
var pause_weapon_labels: Array[Label] = []
var arena_match: ArenaMatchManager
var arena_ui: ArenaMatchUI
var arena_participants: Array[ArenaParticipantState] = []
var arena_bots: Array[BotController] = []
var legacy_test_mode: bool = false
var abandon_dialog: ConfirmationDialog
var target_refresh_remaining: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MouseModeService.capture_gameplay(player)
	AudioManager.play_music(&"arena")
	var args := OS.get_cmdline_user_args()
	legacy_test_mode = _is_legacy_test_mode(args)
	_setup_arena_match()
	player.actor_died.connect(_on_actor_died)
	player.pause_requested.connect(_toggle_pause)
	player.spectator_cycle_requested.connect(_cycle_spectator_target)
	hud.bind(player, bot, self)
	score_changed.emit(player_kills, bot_kills)
	_build_pause_menu()
	if "--arena-round-test" in args:
		_run_arena_round_test.call_deferred()
	elif "--arena-reward-test" in args:
		_run_arena_reward_test.call_deferred()
	elif "--self-test" in args:
		_run_self_test.call_deferred()
	elif "--ai-soak-test" in OS.get_cmdline_user_args():
		_run_ai_soak_test.call_deferred()
	elif "--hud-layout-test" in OS.get_cmdline_user_args():
		_run_hud_layout_test.call_deferred()
	elif "--capture-frame" in OS.get_cmdline_user_args():
		_capture_validation_frame.call_deferred()
	elif "--capture-tpp" in OS.get_cmdline_user_args():
		_capture_validation_frame.bind(true).call_deferred()
	elif "--capture-pause" in OS.get_cmdline_user_args():
		_capture_pause_menu.call_deferred()
	elif "--capture-ads" in OS.get_cmdline_user_args():
		_capture_ads_frame.call_deferred()
	elif "--loadout-integration-test" in OS.get_cmdline_user_args():
		_run_loadout_integration_test.call_deferred()
	elif "--content-arena-test" in OS.get_cmdline_user_args():
		_run_content_arena_test.call_deferred()
	elif "--effect-self-test" in OS.get_cmdline_user_args():
		_run_effect_self_test.call_deferred()
	elif "--pause-flow-test" in OS.get_cmdline_user_args():
		_run_pause_flow_test.call_deferred()
	elif "--polish-self-test" in OS.get_cmdline_user_args():
		_run_polish_self_test.call_deferred()
	elif "--combat-feel-test" in OS.get_cmdline_user_args():
		_run_combat_feel_test.call_deferred()
	elif "--scene-flow-test" in OS.get_cmdline_user_args():
		_run_scene_flow_arena_leg.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused and event.is_action_pressed("menu_toggle"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _on_actor_died(actor: Node, info: DamageInfo) -> void:
	AudioEvents.play(&"kill", (actor as Node3D).global_position if actor is Node3D else Vector3.ZERO)
	if not legacy_test_mode and arena_match != null:
		arena_match.report_death(actor, info)
		return
	if actor == bot:
		player_kills += 1
		kill_feed.emit("ELIMINATED BOT")
	else:
		bot_kills += 1
		kill_feed.emit("YOU DIED")
	score_changed.emit(player_kills, bot_kills)
	_respawn_actor(actor, info)


func _respawn_actor(actor: Node, _info: DamageInfo) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	if is_instance_valid(actor) and actor.has_method("respawn"):
		actor.respawn()


func _build_pause_menu() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 80
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.008, 0.01, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_layer.add_child(shade)
	var cyan_band := ColorRect.new()
	cyan_band.color = Color(0.02, 0.72, 0.88, 0.18)
	cyan_band.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	cyan_band.offset_right = 260
	cyan_band.rotation = -0.04
	cyan_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_layer.add_child(cyan_band)
	var yellow_band := ColorRect.new()
	yellow_band.color = Color(1.0, 0.76, 0.08, 0.18)
	yellow_band.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	yellow_band.offset_left = -420
	yellow_band.offset_top = -120
	yellow_band.rotation = 0.08
	yellow_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_layer.add_child(yellow_band)
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -470
	pause_panel.offset_right = 470
	pause_panel.offset_top = -280
	pause_panel.offset_bottom = 280
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.024, 0.027, 0.99)
	style.border_color = Color(0.98, 0.76, 0.08)
	style.set_border_width_all(2)
	style.set_content_margin_all(22)
	pause_panel.add_theme_stylebox_override("panel", style)
	pause_layer.add_child(pause_panel)
	var pause_root := VBoxContainer.new()
	pause_root.add_theme_constant_override("separation", 10)
	pause_panel.add_child(pause_root)
	pause_menu_column = VBoxContainer.new()
	pause_menu_column.add_theme_constant_override("separation", 14)
	pause_menu_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pause_root.add_child(pause_menu_column)
	var header := HBoxContainer.new()
	pause_menu_column.add_child(header)
	var title := Label.new()
	title.text = "[ TACTICAL PAUSE ]"
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color(0.96, 0.97, 0.95))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "MATCH 01  //  LOCAL 1V1\nINPUT RELEASED"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	subtitle.add_theme_color_override("font_color", Color(0.02, 0.74, 0.90))
	header.add_child(subtitle)
	var separator := ColorRect.new()
	separator.color = Color(0.98, 0.76, 0.08)
	separator.custom_minimum_size.y = 3
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_menu_column.add_child(separator)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pause_menu_column.add_child(body)
	var navigation_panel := PanelContainer.new()
	navigation_panel.custom_minimum_size.x = 310
	navigation_panel.add_theme_stylebox_override("panel", _pause_style(Color(0.03, 0.038, 0.041), Color(0.18, 0.22, 0.23), 1))
	body.add_child(navigation_panel)
	var navigation_margin := MarginContainer.new()
	navigation_margin.add_theme_constant_override("margin_left", 14)
	navigation_margin.add_theme_constant_override("margin_top", 14)
	navigation_margin.add_theme_constant_override("margin_right", 14)
	navigation_margin.add_theme_constant_override("margin_bottom", 14)
	navigation_panel.add_child(navigation_margin)
	var navigation := VBoxContainer.new()
	navigation.add_theme_constant_override("separation", 9)
	navigation_margin.add_child(navigation)
	var navigation_title := Label.new()
	navigation_title.text = "// MATCH CONTROL"
	navigation_title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.08))
	navigation_title.add_theme_font_size_override("font_size", 12)
	navigation.add_child(navigation_title)
	_add_pause_button(navigation, "RESUME", _toggle_pause)
	_add_pause_button(navigation, "SETTINGS", _show_pause_settings)
	_add_pause_button(navigation, "RETURN TO LOBBY", _return_to_lobby)
	var nav_fill := Control.new()
	nav_fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation.add_child(nav_fill)
	_add_pause_button(navigation, "QUIT", _quit_game)

	var tactical_column := VBoxContainer.new()
	tactical_column.add_theme_constant_override("separation", 12)
	tactical_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(tactical_column)
	var loadout_panel := PanelContainer.new()
	loadout_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loadout_panel.add_theme_stylebox_override("panel", _pause_style(Color(0.025, 0.032, 0.034), Color(0.24, 0.30, 0.31), 1))
	tactical_column.add_child(loadout_panel)
	var loadout_margin := MarginContainer.new()
	loadout_margin.add_theme_constant_override("margin_left", 16)
	loadout_margin.add_theme_constant_override("margin_top", 14)
	loadout_margin.add_theme_constant_override("margin_right", 16)
	loadout_margin.add_theme_constant_override("margin_bottom", 14)
	loadout_panel.add_child(loadout_margin)
	var loadout := VBoxContainer.new()
	loadout.add_theme_constant_override("separation", 10)
	loadout_margin.add_child(loadout)
	var loadout_header := HBoxContainer.new()
	loadout.add_child(loadout_header)
	var loadout_title := Label.new()
	loadout_title.text = "ACTIVE LOADOUT"
	loadout_title.add_theme_color_override("font_color", Color(0.02, 0.74, 0.90))
	loadout_title.add_theme_font_size_override("font_size", 13)
	loadout_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_header.add_child(loadout_title)
	var power := Label.new()
	power.text = "%03d/%03d POWER" % [PlayerProfile.get_skill_power(), PlayerProfile.POWER_LIMIT]
	power.add_theme_color_override("font_color", Color(0.35, 0.92, 0.64))
	loadout_header.add_child(power)
	var weapon_grid := GridContainer.new()
	weapon_grid.columns = 2
	weapon_grid.add_theme_constant_override("h_separation", 10)
	loadout.add_child(weapon_grid)
	pause_weapon_labels.clear()
	for index: int in range(2):
		var weapon_card := PanelContainer.new()
		weapon_card.custom_minimum_size = Vector2(270, 92)
		weapon_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weapon_card.add_theme_stylebox_override("panel", _pause_style(Color(0.045, 0.055, 0.058), Color(0.26, 0.31, 0.32), 1))
		weapon_grid.add_child(weapon_card)
		var weapon_label := Label.new()
		var arena_weapon := PlayerProfile.get_arena_weapon_definition(index)
		weapon_label.text = "[%d]  %s\n%s" % [index + 1, arena_weapon.display_name.to_upper() if arena_weapon != null else "EMPTY", "PRIMARY" if index == 0 else "SECONDARY"]
		weapon_label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.95))
		weapon_label.add_theme_font_size_override("font_size", 14)
		weapon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_card.add_child(weapon_label)
		pause_weapon_labels.append(weapon_label)
	var skill_line := Label.new()
	skill_line.text = "SKILLS   %s  %s   //   %s  %s" % [GameSettings.get_binding_text(&"skill_slot_1"), _pause_definition_name(PlayerProfile.skill_slots[0]).to_upper(), GameSettings.get_binding_text(&"skill_slot_2"), _pause_definition_name(PlayerProfile.skill_slots[1]).to_upper()]
	skill_line.add_theme_color_override("font_color", Color(0.68, 0.72, 0.72))
	loadout.add_child(skill_line)
	var briefing_spacer := Control.new()
	briefing_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loadout.add_child(briefing_spacer)
	var briefing_rule := ColorRect.new()
	briefing_rule.color = Color(0.02, 0.74, 0.90, 0.55)
	briefing_rule.custom_minimum_size.y = 1
	loadout.add_child(briefing_rule)
	var briefing := Label.new()
	briefing.text = "MOVEMENT BRIEF  //  HOLD SPACE + A/D TO CHAIN BHOPS\nLEAN  %s / %s   •   FOLLOW THE CAMERA IN AIR" % [GameSettings.get_binding_text(&"peek_left"), GameSettings.get_binding_text(&"peek_right")]
	briefing.add_theme_color_override("font_color", Color(0.63, 0.67, 0.67))
	briefing.add_theme_font_size_override("font_size", 11)
	loadout.add_child(briefing)

	var status_panel := PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel", _pause_style(Color(0.025, 0.032, 0.034), Color(0.24, 0.30, 0.31), 1))
	tactical_column.add_child(status_panel)
	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 16)
	status_margin.add_theme_constant_override("margin_top", 12)
	status_margin.add_theme_constant_override("margin_right", 16)
	status_margin.add_theme_constant_override("margin_bottom", 12)
	status_panel.add_child(status_margin)
	var status_grid := GridContainer.new()
	status_grid.columns = 2
	status_grid.add_theme_constant_override("h_separation", 28)
	status_margin.add_child(status_grid)
	pause_health_label = Label.new()
	pause_health_label.add_theme_color_override("font_color", Color(0.35, 0.92, 0.64))
	pause_health_label.add_theme_font_size_override("font_size", 17)
	status_grid.add_child(pause_health_label)
	pause_armor_label = Label.new()
	pause_armor_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.08))
	pause_armor_label.add_theme_font_size_override("font_size", 17)
	status_grid.add_child(pause_armor_label)
	_build_pause_settings(pause_root)
	_refresh_pause_status()
	pause_layer.visible = false


func _build_pause_settings(parent: Control) -> void:
	pause_settings_column = VBoxContainer.new()
	pause_settings_column.add_theme_constant_override("separation", 8)
	parent.add_child(pause_settings_column)
	var title := Label.new()
	title.text = "[ GAMEPLAY SETTINGS ]"
	title.add_theme_color_override("font_color", Color(0.96, 0.97, 0.95))
	title.add_theme_font_size_override("font_size", 28)
	pause_settings_column.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(0.02, 0.74, 0.90)
	rule.custom_minimum_size.y = 3
	pause_settings_column.add_child(rule)
	_add_pause_slider("FOV", GameSettings.base_fov, 70.0, 110.0, 1.0, &"base_fov")
	_add_pause_slider("CAMERA SHAKE", GameSettings.camera_shake_strength, 0.0, 1.0, 0.05, &"camera_shake_strength")
	_add_pause_slider("HIT EFFECTS", GameSettings.hit_effects_intensity, 0.0, 1.0, 0.05, &"hit_effects_intensity")
	_add_pause_slider("HEADBOB", GameSettings.headbob_strength, 0.0, 1.0, 0.05, &"headbob_strength")
	_add_pause_slider("TPP SMOOTHING", GameSettings.tpp_camera_smoothing, 6.0, 30.0, 1.0, &"tpp_camera_smoothing")
	var damage_numbers := CheckButton.new()
	damage_numbers.text = "DAMAGE NUMBERS"
	damage_numbers.button_pressed = GameSettings.damage_numbers
	damage_numbers.toggled.connect(func(value: bool) -> void: GameSettings.set_value(&"damage_numbers", value))
	pause_settings_column.add_child(damage_numbers)
	var crosshair := CheckButton.new()
	crosshair.text = "CROSSHAIR"
	crosshair.button_pressed = GameSettings.crosshair_enabled
	crosshair.toggled.connect(func(value: bool) -> void: GameSettings.set_value(&"crosshair_enabled", value))
	pause_settings_column.add_child(crosshair)
	_add_pause_button(pause_settings_column, "BACK", _hide_pause_settings)
	pause_settings_column.visible = false


func _add_pause_slider(caption: String, value: float, minimum: float, maximum: float, step: float, key: StringName) -> void:
	var label := Label.new()
	label.text = "%s  %.2f" % [caption, value]
	pause_settings_column.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.value_changed.connect(func(new_value: float) -> void:
		label.text = "%s  %.2f" % [caption, new_value]
		GameSettings.set_value(key, new_value)
	)
	pause_settings_column.add_child(slider)


func _show_pause_settings() -> void:
	pause_menu_column.visible = false
	pause_settings_column.visible = true
	MouseModeService.enter_settings(player)


func _hide_pause_settings() -> void:
	pause_settings_column.visible = false
	pause_menu_column.visible = true
	if get_tree().paused:
		MouseModeService.enter_pause(player)


func _add_pause_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = "//  " + text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.94, 0.95, 0.93))
	button.add_theme_color_override("font_hover_color", Color(0.01, 0.02, 0.02))
	button.add_theme_stylebox_override("normal", _pause_style(Color(0.055, 0.064, 0.067), Color(0.24, 0.29, 0.30), 1))
	button.add_theme_stylebox_override("hover", _pause_style(Color(1.0, 0.78, 0.08), Color(1.0, 0.78, 0.08), 2))
	button.add_theme_stylebox_override("pressed", _pause_style(Color(0.02, 0.74, 0.90), Color(0.02, 0.74, 0.90), 2))
	button.mouse_entered.connect(func() -> void: AudioEvents.play(&"ui_hover"))
	button.pressed.connect(func() -> void: AudioEvents.play(&"ui_click"))
	button.pressed.connect(callback)
	parent.add_child(button)


func _toggle_pause() -> void:
	var should_pause := not get_tree().paused
	get_tree().paused = should_pause
	pause_layer.visible = should_pause
	if should_pause:
		_refresh_pause_status()
		_hide_pause_settings()
	else:
		MouseModeService.capture_gameplay(player)


func _return_to_lobby() -> void:
	if not legacy_test_mode and arena_match != null and arena_match.state not in [ArenaMatchManager.STATE_MATCH_END, ArenaMatchManager.STATE_RESULTS]:
		_show_abandon_confirmation()
		return
	_return_to_lobby_immediate()


func _return_to_lobby_immediate() -> void:
	get_tree().paused = false
	MouseModeService.enter_lobby()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _process(delta: float) -> void:
	if legacy_test_mode or arena_match == null or arena_match.state not in [ArenaMatchManager.STATE_ROUND_ACTIVE, ArenaMatchManager.STATE_SUDDEN_DEATH]:
		return
	target_refresh_remaining -= delta
	if target_refresh_remaining <= 0.0:
		target_refresh_remaining = 0.45
		_assign_bot_targets()


func _is_legacy_test_mode(args: PackedStringArray) -> bool:
	for flag: String in ["--self-test", "--ai-soak-test", "--hud-layout-test", "--capture-frame", "--capture-tpp", "--capture-pause", "--capture-ads", "--loadout-integration-test", "--content-arena-test", "--effect-self-test", "--pause-flow-test", "--polish-self-test", "--combat-feel-test", "--scene-flow-test", "--arena-reward-test"]:
		if flag in args:
			return true
	return false


func _setup_arena_match() -> void:
	arena_match = ArenaMatchManager.new()
	arena_match.name = "ArenaMatchManager"
	add_child(arena_match)
	var mode := MODE_2V2 if ArenaSessionRequest.mode_id == &"2v2" else MODE_1V1
	arena_match.configure(mode)
	arena_bots = [bot]
	if mode.team_size == 2 and not legacy_test_mode:
		var ally := BOT_SCENE.instantiate() as BotController
		ally.name = "AllyBot"
		add_child(ally)
		var enemy_two := BOT_SCENE.instantiate() as BotController
		enemy_two.name = "EnemyBot2"
		add_child(enemy_two)
		arena_bots.append(ally)
		arena_bots.append(enemy_two)
	player.configure_arena(ArenaMatchManager.TEAM_A)
	_register_participant(player, &"local_player", "YOU", ArenaMatchManager.TEAM_A, 0, true)
	bot.configure_arena(ArenaMatchManager.TEAM_B)
	_register_participant(bot, &"enemy_1", "RED ONE", ArenaMatchManager.TEAM_B, 0, false)
	if mode.team_size == 2 and not legacy_test_mode:
		var ally_bot := arena_bots[1]
		var enemy_bot_two := arena_bots[2]
		ally_bot.configure_arena(ArenaMatchManager.TEAM_A)
		enemy_bot_two.configure_arena(ArenaMatchManager.TEAM_B)
		_register_participant(ally_bot, &"ally_1", "BLUE TWO", ArenaMatchManager.TEAM_A, 1, false)
		_register_participant(enemy_bot_two, &"enemy_2", "RED TWO", ArenaMatchManager.TEAM_B, 1, false)
	for arena_bot: BotController in arena_bots:
		arena_bot.apply_arena_difficulty(StringName(String(ArenaSessionRequest.bot_difficulty).to_lower()))
		arena_bot.actor_died.connect(_on_actor_died)
	_connect_arena_signals()
	if legacy_test_mode:
		player.spawn_transform = player.global_transform
		bot.spawn_transform = bot.global_transform
		bot.set_target(player)
		return
	arena_ui = ArenaMatchUI.new()
	add_child(arena_ui)
	arena_ui.bind(arena_match, arena_participants[0])
	arena_ui.play_again_requested.connect(_on_play_again)
	arena_ui.return_to_lobby_requested.connect(_return_to_lobby_immediate)
	arena_match.begin_match(false)


func _register_participant(actor: Node3D, participant_id: StringName, display_name: String, team_id: int, slot: int, local: bool) -> void:
	var participant := ArenaParticipantState.new(participant_id, display_name, team_id, slot, actor, local)
	participant.inventory_owner_id = "local_profile" if local else String(participant_id)
	if local:
		for inventory_slot: int in PlayerProfile.main_inventory.size():
			var item := PlayerProfile.get_inventory_instance(inventory_slot)
			if item != null:
				participant.inventory_item_ids.append(item.instance_id)
	arena_participants.append(participant)
	arena_match.register_participant(participant)
	var actor_health := actor.get_node_or_null("HealthComponent") as HealthComponent
	if actor_health != null:
		actor_health.damage_resolved.connect(_on_arena_damage_resolved)


func _connect_arena_signals() -> void:
	arena_match.round_reset_requested.connect(_on_round_reset_requested)
	arena_match.combat_lock_changed.connect(_on_combat_lock_changed)
	arena_match.healing_lock_changed.connect(_on_healing_lock_changed)
	arena_match.spectator_requested.connect(_on_spectator_requested)
	arena_match.pressure_tick.connect(_on_pressure_tick)
	arena_match.round_ended.connect(_on_arena_score_changed)
	arena_match.results_ready.connect(_on_arena_results_ready)


func _on_round_reset_requested(round_number: int, swap_sides: bool) -> void:
	_clear_arena_transients()
	player.set_spectator_target(null)
	for participant: ArenaParticipantState in arena_participants:
		var marker := _spawn_marker(participant.team_id, participant.team_slot, swap_sides)
		if marker == null:
			continue
		participant.actor.set("spawn_transform", marker.global_transform)
		if participant.actor.has_method("respawn"):
			participant.actor.respawn()
	_assign_bot_targets()
	kill_feed.emit("ROUND %d  //  SIDES SWAPPED" % round_number if swap_sides else "ROUND %d" % round_number)


func _spawn_marker(team_id: int, slot: int, swap_sides: bool) -> Marker3D:
	var physical_team := 1 - team_id if swap_sides else team_id
	var prefix := "A" if physical_team == ArenaMatchManager.TEAM_A else "B"
	return get_node_or_null("ArenaSpawns/%s%d" % [prefix, slot + 1]) as Marker3D


func _on_combat_lock_changed(locked: bool) -> void:
	for participant: ArenaParticipantState in arena_participants:
		if is_instance_valid(participant.actor) and participant.actor.has_method("set_arena_combat_enabled"):
			participant.actor.set_arena_combat_enabled(not locked)


func _on_healing_lock_changed(locked: bool) -> void:
	for participant: ArenaParticipantState in arena_participants:
		if is_instance_valid(participant.actor) and participant.actor.has_method("set_arena_healing_enabled"):
			participant.actor.set_arena_healing_enabled(not locked)


func _on_spectator_requested(_local_participant: ArenaParticipantState, teammates: Array[ArenaParticipantState]) -> void:
	player.set_spectator_target(teammates[0].actor if not teammates.is_empty() else null)


func _cycle_spectator_target(direction: int) -> void:
	if not player.is_dead or arena_match == null:
		return
	var teammates := arena_match.living_participants(ArenaMatchManager.TEAM_A)
	if teammates.is_empty():
		return
	var current_index := 0
	for index: int in teammates.size():
		if teammates[index].actor == player.spectator_target:
			current_index = index
			break
	current_index = posmod(current_index + direction, teammates.size())
	player.set_spectator_target(teammates[current_index].actor)


func _on_pressure_tick(amount: float) -> void:
	for participant: ArenaParticipantState in arena_match.participants:
		if participant.alive and is_instance_valid(participant.actor):
			var actor_health := participant.actor.get_node_or_null("HealthComponent") as HealthComponent
			if actor_health != null:
				actor_health.apply_damage(DamageInfo.new(amount, null, &"sudden_death_pressure", false, false, participant.actor.global_position, Vector3.ZERO, false, true))


func _on_arena_damage_resolved(info: DamageInfo, applied_amount: float, _response: Dictionary) -> void:
	arena_match.record_damage(info, applied_amount)


func _on_arena_score_changed(_winner_team: int, team_a_score: int, team_b_score: int) -> void:
	_clear_arena_transients()
	player_kills = team_a_score
	bot_kills = team_b_score
	score_changed.emit(player_kills, bot_kills)


func _on_arena_results_ready(result: ArenaMatchResult) -> void:
	arena_match_result_ready.emit(result)
	MouseModeService.enter_pause(player)
	if arena_ui == null:
		return
	result.progression_grant = ArenaProgressionService.grant_once(result)
	if bool(result.progression_grant.get("granted", false)):
		PlayerProfile.save_profile()
	arena_ui.present_results(result, result.progression_grant)


func _assign_bot_targets() -> void:
	for arena_bot: BotController in arena_bots:
		if not is_instance_valid(arena_bot) or arena_bot.is_dead:
			continue
		var best_target: Node3D
		var best_distance := INF
		for participant: ArenaParticipantState in arena_participants:
			if participant.team_id == arena_bot.arena_team_id or not participant.alive or participant.actor == arena_bot:
				continue
			var distance := arena_bot.global_position.distance_squared_to(participant.actor.global_position)
			if distance < best_distance:
				best_distance = distance
				best_target = participant.actor
		arena_bot.set_target(best_target)


func _clear_arena_transients() -> void:
	for transient: Node in get_tree().get_nodes_in_group("arena_transient"):
		if is_instance_valid(transient):
			transient.queue_free()


func _on_play_again() -> void:
	MouseModeService.capture_gameplay(player)
	if arena_ui != null:
		arena_ui.results_panel.visible = false
	arena_match.rematch(false)


func _show_abandon_confirmation() -> void:
	if abandon_dialog == null:
		abandon_dialog = ConfirmationDialog.new()
		abandon_dialog.title = "ABANDON MATCH?"
		abandon_dialog.dialog_text = "Leaving now counts as a defeat."
		abandon_dialog.ok_button_text = "ABANDON"
		abandon_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
		abandon_dialog.confirmed.connect(_confirm_abandon)
		add_child(abandon_dialog)
	abandon_dialog.popup_centered(Vector2i(440, 180))


func _confirm_abandon() -> void:
	arena_match.abandon(ArenaMatchManager.TEAM_A)
	_return_to_lobby_immediate()


func get_arena_debug_snapshot() -> Dictionary:
	var snapshot := arena_match.get_debug_snapshot() if arena_match != null else {}
	snapshot["bot_difficulty"] = String(ArenaSessionRequest.bot_difficulty)
	return snapshot


func _run_arena_round_test() -> void:
	var failures: Array[String] = []
	arena_match.set_process(false)
	player.set_arena_combat_enabled(true)
	bot.set_arena_combat_enabled(true)
	if arena_participants.size() != (4 if ArenaSessionRequest.mode_id == &"2v2" else 2):
		failures.append("Runtime participant count does not match selected mode")
	if player.can_receive_damage_from(player):
		failures.append("Friendly fire was not blocked")
	if not player.can_receive_damage_from(bot):
		failures.append("Enemy damage was blocked")
	player.health.current_health = 19.0
	if not player.equipped_skills.is_empty():
		player.equipped_skills[0].cooldown_remaining = 9.0
	var player_status := player.get_node_or_null("StatusEffects") as StatusEffectComponent
	if player_status != null:
		player_status.effects[&"arena_test"] = {"remaining": 5.0}
	if not player.weapons.is_empty() and player.weapons[0].effects != null:
		player.weapons[0].effects.special_counter = 4
	_on_round_reset_requested(1, false)
	if not is_equal_approx(player.health.current_health, player.health.max_health):
		failures.append("Round reset did not restore HP")
	if not player.equipped_skills.is_empty() and player.equipped_skills[0].cooldown_remaining > 0.0:
		failures.append("Round reset did not restore skills")
	if player_status != null and not player_status.effects.is_empty():
		failures.append("Round reset did not clear statuses")
	if not player.weapons.is_empty() and player.weapons[0].effects != null and player.weapons[0].effects.special_counter != 0:
		failures.append("Round reset did not clear affix runtime state")
	var manager_1v1 := _make_test_match(MODE_1V1, 2)
	if not manager_1v1.begin_match(true) or manager_1v1.state != ArenaMatchManager.STATE_ROUND_ACTIVE:
		failures.append("1v1 did not enter ROUND_ACTIVE")
	var signal_state := {"reset_count": 0, "spectator": false}
	manager_1v1.round_reset_requested.connect(func(_round: int, _swap: bool) -> void: signal_state.reset_count = int(signal_state.reset_count) + 1)
	manager_1v1.round_time_remaining = 0.0
	manager_1v1.resolve_timeout_now()
	if manager_1v1.state != ArenaMatchManager.STATE_SUDDEN_DEATH:
		failures.append("Equal timeout did not enter sudden death")
	var duel_kill := DamageInfo.new(100.0, manager_1v1.participants[0].actor)
	manager_1v1.report_death(manager_1v1.participants[1].actor, duel_kill)
	if manager_1v1.team_a_score != 1 or manager_1v1.participants[0].kills != 1:
		failures.append("1v1 elimination did not increment score and kill stats")
	for _round: int in 3:
		manager_1v1.finish_transition_now()
		manager_1v1.force_round_winner(ArenaMatchManager.TEAM_A)
	manager_1v1.finish_transition_now()
	manager_1v1.finish_transition_now()
	if manager_1v1.state != ArenaMatchManager.STATE_RESULTS or manager_1v1.latest_result == null or manager_1v1.team_a_score != 4:
		failures.append("1v1 best-of-seven result flow failed")
	if int(signal_state.reset_count) < 3:
		failures.append("Round reset signal did not fire between rounds")
	if not manager_1v1.rematch(true) or manager_1v1.state != ArenaMatchManager.STATE_ROUND_ACTIVE or manager_1v1.team_a_score != 0:
		failures.append("Play-again rematch did not create a clean match")
	var timeout_manager := _make_test_match(MODE_1V1, 2)
	timeout_manager.begin_match(true)
	(timeout_manager.participants[0].actor.get_node("HealthComponent") as HealthComponent).current_health = 75.0
	(timeout_manager.participants[1].actor.get_node("HealthComponent") as HealthComponent).current_health = 30.0
	timeout_manager.resolve_timeout_now()
	if timeout_manager.state != ArenaMatchManager.STATE_ROUND_END or timeout_manager.team_a_score != 1:
		failures.append("Timeout remaining-HP tiebreak failed")
	var manager_2v2 := _make_test_match(MODE_2V2, 4)
	manager_2v2.begin_match(true)
	manager_2v2.spectator_requested.connect(func(_local: ArenaParticipantState, teammates: Array[ArenaParticipantState]) -> void: signal_state.spectator = not teammates.is_empty())
	manager_2v2.report_death(manager_2v2.participants[0].actor)
	if manager_2v2.state != ArenaMatchManager.STATE_ROUND_ACTIVE:
		failures.append("2v2 round ended after the first death")
	if not bool(signal_state.spectator):
		failures.append("2v2 local death did not activate spectator foundation")
	manager_2v2.report_death(manager_2v2.participants[2].actor)
	if manager_2v2.state != ArenaMatchManager.STATE_ROUND_END or manager_2v2.team_b_score != 1:
		failures.append("2v2 round did not end after full team elimination")
	for _round: int in 2:
		manager_2v2.finish_transition_now()
		manager_2v2.force_round_winner(ArenaMatchManager.TEAM_B)
	manager_2v2.finish_transition_now()
	manager_2v2.finish_transition_now()
	if manager_2v2.state != ArenaMatchManager.STATE_RESULTS or manager_2v2.team_b_score != 3 or manager_2v2.participants.size() != 4:
		failures.append("2v2 best-of-five result flow failed")
	manager_1v1.queue_free()
	manager_2v2.queue_free()
	timeout_manager.queue_free()
	if failures.is_empty():
		print("ARENA_ROUND_OK: 1v1/2v2 setup, elimination, spectator, timer/HP tiebreak, sudden death, scoring, reset, rematch and friendly-fire rules passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("ARENA_ROUND_FAILURE: " + failure)
		get_tree().quit(1)


func _run_arena_reward_test() -> void:
	var failures: Array[String] = []
	MouseModeService.enter_pause(player)
	if not player.is_cursor_free or not MouseModeService.is_ui_active():
		failures.append("Post-match results did not retain a free cursor mode")
	if MODE_1V1.max_reward_exchanges != 0 or MODE_2V2.max_reward_exchanges != 0:
		failures.append("Legacy item exchange remains enabled on an active Arena mode")
	var ui_participants: Array[ArenaParticipantState] = []
	var ui_winner := ArenaParticipantState.new(&"ui_winner", "UI WINNER", 0, 0, player, true)
	ui_winner.inventory_owner_id = "ui_winner"
	ui_participants.append(ui_winner)
	var ui_loser := ArenaParticipantState.new(&"ui_loser", "UI BOT", 1, 0, bot, false)
	ui_loser.inventory_owner_id = "ui_loser"
	ui_participants.append(ui_loser)
	var ui_result := ArenaMatchResult.new().configure(MODE_1V1, 0, 4, 1, 5, ui_participants, false, "result:ui")
	ui_winner.kills = 4
	ui_winner.damage_dealt = 520.0
	ui_winner.weapon_damage_by_family["katana"] = 520.0
	var test_ui := ArenaMatchUI.new()
	add_child(test_ui)
	var calculated := ArenaProgressionService.calculate(ui_result)
	test_ui.present_results(ui_result, calculated)
	if not test_ui.results_panel.visible or test_ui.result_continue_button.text != "RETURN TO LOBBY":
		failures.append("Progression results controls were not usable")
	var original_size: Vector2i = get_viewport().size
	for test_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		get_viewport().size = test_size
		await get_tree().process_frame
		var results_rect := test_ui.results_panel.get_global_rect()
		var minimum := test_ui.results_panel.get_combined_minimum_size()
		if results_rect.position.x < 0.0 or results_rect.position.y < 0.0 or results_rect.end.x > test_size.x or results_rect.end.y > test_size.y or minimum.x > results_rect.size.x or minimum.y > results_rect.size.y:
			failures.append("Progression results overflowed at %dx%d (rect=%s minimum=%s)" % [test_size.x, test_size.y, str(results_rect), str(minimum)])
	get_viewport().size = original_size
	test_ui.free()
	if failures.is_empty():
		print("ARENA_REWARD_OK: legacy item swap is inactive; cosmetic progression results, responsive layout and free cursor passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("ARENA_REWARD_FAILURE: " + failure)
		get_tree().quit(1)


func _make_test_match(test_mode: ArenaModeDefinition, count: int) -> ArenaMatchManager:
	var result := ArenaMatchManager.new()
	result.configure(test_mode)
	add_child(result)
	result.set_process(false)
	for index: int in count:
		var actor := Node3D.new()
		actor.name = "ArenaTestActor%d" % index
		var actor_health := HealthComponent.new()
		actor_health.name = "HealthComponent"
		actor.add_child(actor_health)
		result.add_child(actor)
		result.register_participant(ArenaParticipantState.new(StringName("test_%d" % index), "TEST %d" % index, index % 2, index / 2, actor, index == 0))
	return result


func _quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()


func _pause_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = background
	result.border_color = border
	result.set_border_width_all(width)
	result.content_margin_left = 13
	result.content_margin_right = 13
	result.content_margin_top = 9
	result.content_margin_bottom = 9
	return result


func _pause_definition_name(item_id: String) -> String:
	var definition := PlayerProfile.get_definition(item_id)
	return definition.display_name if definition != null else "EMPTY"


func _refresh_pause_status() -> void:
	if pause_health_label != null:
		pause_health_label.text = "HEALTH   %03d / %03d" % [roundi(player.health.current_health), roundi(player.health.max_health)]
	if pause_armor_label != null:
		pause_armor_label.text = "ARENA HP   100  //  NORMALIZED"
	for index: int in mini(2, pause_weapon_labels.size()):
		var arena_weapon := PlayerProfile.get_arena_weapon_definition(index)
		pause_weapon_labels[index].text = "[%d]  %s\n%s" % [index + 1, arena_weapon.display_name.to_upper() if arena_weapon != null else "EMPTY", "PRIMARY" if index == 0 else "SECONDARY"]


func _capture_pause_menu() -> void:
	_toggle_pause()
	for frame: int in 20:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("res://validation_pause.png")
	print("PAUSE_CAPTURE_OK: res://validation_pause.png" if error == OK else "PAUSE_CAPTURE_FAILED")
	get_tree().paused = false
	get_tree().quit(0 if error == OK else 1)


func _run_loadout_integration_test() -> void:
	print("LOADOUT_INTEGRATION_START")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var failures: Array[String] = []
	if player.weapon_definition_ids != ["vanguard_rifle", "knight_sword"]:
		failures.append("Arena did not consume the selected weapon slot IDs")
	if player.skill_definition_ids != ["grapple", "blink"]:
		failures.append("Arena did not consume the selected skill slot IDs")
	if player.weapons.size() != 2 or not player.weapons[0] is VanguardRifleWeapon or not player.weapons[1] is KnightSwordWeapon:
		failures.append("Alternate weapon scenes did not instantiate in slot order")
	if player.equipped_skills.size() != 2 or not player.equipped_skills[0] is GrappleSkill or not player.equipped_skills[1] is BlinkSkill:
		failures.append("Alternate skill scenes did not instantiate in slot order")
	if player.dash_skill != null or player.double_jump_skill != null or player.movement.dash_skill != null or player.movement.double_jump_skill != null:
		failures.append("Unequipped Dash or Double Jump remained active")
	if PlayerProfile.get_skill_power() != 200:
		failures.append("Alternate arena loadout did not retain 200 Power")
	hud._update_weapon_panel()
	hud._update_skills()
	if hud.skill_name_labels.size() != 2 or hud.skill_name_labels[0].text != "GRAPPLE" or hud.skill_name_labels[1].text != "BLINK":
		failures.append("Arena HUD did not replace Dash/Double Jump with selected skills (%s / %s)" % [hud.skill_name_labels[0].text, hud.skill_name_labels[1].text])
	if not hud.slot_one_label.text.contains("VANGUARD RIFLE") or not hud.slot_two_label.text.contains("KNIGHT SWORD"):
		failures.append("Arena HUD did not show the selected weapon slots (%s / %s)" % [hud.slot_one_label.text, hud.slot_two_label.text])
	if player.weapons.size() == 2:
		player.equip_weapon(0)
		var rifle := player.current_weapon as VanguardRifleWeapon
		var ammo_before := rifle.ammo
		rifle.request_primary()
		if rifle.ammo != ammo_before - 1:
			failures.append("Vanguard Rifle did not fire from the selected slot")
		if not rifle.automatic_fire or not is_equal_approx(rifle.fire_delay, 1.0 / 8.5) or rifle.effects.has(&"rapid"):
			failures.append("Assault Rifle did not use normalized family fire rate without the legacy Rapid affix")
		rifle.ammo = 0
		rifle.request_reload()
		if not rifle.is_reloading:
			failures.append("Vanguard Rifle did not enter reload state")
		rifle.reload_remaining = 0.001
		await get_tree().process_frame
		await get_tree().process_frame
		if rifle.ammo != rifle.magazine_size or rifle.is_reloading:
			failures.append("Vanguard Rifle did not complete its reload")
		player.equip_weapon(1)
		var sword := player.current_weapon as KnightSwordWeapon
		if not is_equal_approx(sword.light_damage, 32.0) or not is_equal_approx(sword.heavy_damage, 50.0):
			failures.append("Knight Sword did not use normalized Sword-family tuning")
		sword.secondary_pressed()
		var response := sword.get_damage_response(DamageInfo.new(100.0, bot, &"test", false, false))
		if not is_equal_approx(float(response.get("damage_multiplier", 1.0)), 0.22) or bool(response.get("reflect", false)) or sword.effects.has(&"crusher"):
			failures.append("Knight Sword block or legacy-affix normalization is invalid")
		sword.secondary_released()
	var grapple := player.equipped_skills[0] as GrappleSkill
	Input.action_press("skill_slot_1")
	await get_tree().physics_frame
	Input.action_release("skill_slot_1")
	await get_tree().physics_frame
	if grapple.cooldown_remaining <= 0.0:
		failures.append("Q did not activate Grapple against arena geometry")
	player.respawn()
	player.global_position = Vector3(-20.0, 0.15, 22.0)
	player.rotation = Vector3.ZERO
	player.pitch_pivot.rotation = Vector3.ZERO
	var blink_start := player.global_position
	var blink := player.equipped_skills[1] as BlinkSkill
	Input.action_press("skill_slot_2")
	await get_tree().physics_frame
	Input.action_release("skill_slot_2")
	await get_tree().physics_frame
	if blink.cooldown_remaining <= 0.0 or player.global_position.distance_to(blink_start) < 0.7:
		failures.append("E did not activate collision-safe Blink (cooldown %.2f, travel %.2f)" % [blink.cooldown_remaining, player.global_position.distance_to(blink_start)])
	player.respawn()
	if grapple.cooldown_remaining > 0.0 or blink.cooldown_remaining > 0.0:
		failures.append("Respawn did not reset equipped skill cooldowns")
	if failures.is_empty():
		print("LOADOUT_INTEGRATION_OK: exact weapons/skills, no unequipped movement skills, rifle, sword, Blink and Grapple passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("LOADOUT_INTEGRATION_FAILURE: " + failure)
		get_tree().quit(1)


func _run_content_arena_test() -> void:
	print("CONTENT_ARENA_TEST_START")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var failures: Array[String] = []
	if player.weapon_definition_ids != ["war_nodachi", "arcane_wand"] or player.skill_definition_ids != ["wallrun", "smoke_veil"]:
		failures.append("Arena did not consume expanded content IDs")
	if player.weapons.size() != 2 or not player.weapons[0] is WarNodachiWeapon or not player.weapons[1] is ArcaneWandWeapon:
		failures.append("Expanded weapon scenes did not instantiate in slot order")
	if player.equipped_skills.size() != 2 or not player.equipped_skills[0] is WallrunSkill or not player.equipped_skills[1] is SmokeVeilSkill:
		failures.append("Expanded skill scenes did not instantiate in slot order")
	if PlayerProfile.get_skill_power() != 140:
		failures.append("Wallrun + Smoke Veil arena loadout should total 140 Power")
	if player.dash_skill != null or player.double_jump_skill != null:
		failures.append("Unequipped base movement skills leaked into expanded loadout")
	if player.weapons.size() == 2:
		player.equip_weapon(0)
		var nodachi := player.current_weapon as WarNodachiWeapon
		var speed_before := player.velocity.length()
		nodachi.request_primary()
		if nodachi.recovery_remaining <= 0.0 or player.velocity.length() <= speed_before:
			failures.append("War Nodachi did not begin a lunging attack")
		player.equip_weapon(1)
		var wand := player.current_weapon as ArcaneWandWeapon
		wand.request_primary()
		if wand.fire_cooldown_remaining <= 0.0:
			failures.append("Arcane Wand did not enter shot cooldown")
		var projectile_found := false
		for child: Node in get_children():
			if child is MagicProjectile:
				projectile_found = true
				break
		if not projectile_found:
			failures.append("Arcane Wand did not spawn its projectile")
	var wallrun := player.equipped_skills[0] as WallrunSkill
	var smoke := player.equipped_skills[1] as SmokeVeilSkill
	if not wallrun.request_activate(player) or wallrun.cooldown_remaining <= 0.0:
		failures.append("Wallrun did not activate through SkillBase")
	if not smoke.request_activate(player) or get_tree().get_nodes_in_group("smoke_veil").is_empty():
		failures.append("Smoke Veil did not spawn a LOS-blocking area")
	var runtime_weapon_ids: Array[String] = ["falcon_burst", "ironclad_rifle", "service_glock", "twin_glock"]
	for item_id: String in runtime_weapon_ids:
		var definition := PlayerProfile.get_definition(item_id)
		var weapon := definition.gameplay_scene.instantiate() as WeaponBase
		player.weapon_mount.add_child(weapon)
		weapon.setup(player)
		weapon.equip()
		var ammo_before := int(weapon.get("ammo"))
		weapon.request_primary()
		if int(weapon.get("ammo")) >= ammo_before:
			failures.append("Expanded firearm did not fire: " + item_id)
		weapon.unequip()
		weapon.queue_free()
	var launch_definition := PlayerProfile.get_definition("launch")
	var launch_skill := launch_definition.gameplay_scene.instantiate() as SkillBase
	player.skill_mount.add_child(launch_skill)
	launch_skill.setup(player, launch_definition, 0)
	var launch_before := player.velocity.y
	if not launch_skill.request_activate(player) or player.velocity.y <= launch_before:
		failures.append("Launch skill did not apply upward velocity")
	launch_skill.queue_free()
	var invis_definition := PlayerProfile.get_definition("invisibility")
	var invis_skill := invis_definition.gameplay_scene.instantiate() as SkillBase
	player.skill_mount.add_child(invis_skill)
	invis_skill.setup(player, invis_definition, 0)
	if not invis_skill.request_activate(player) or not player.is_invisible:
		failures.append("Invisibility did not hide its owner")
	invis_skill.on_owner_attack(player)
	if player.is_invisible:
		failures.append("Attacking did not end Invisibility")
	invis_skill.queue_free()
	player.global_position += Vector3.UP * 3.0
	await get_tree().physics_frame
	var air_definition := PlayerProfile.get_definition("air_dash")
	var air_skill := air_definition.gameplay_scene.instantiate() as SkillBase
	player.skill_mount.add_child(air_skill)
	air_skill.setup(player, air_definition, 0)
	if not air_skill.request_activate(player) or air_skill.cooldown_remaining <= 0.0:
		failures.append("Air Dash did not activate while airborne")
	air_skill.queue_free()
	var slam_definition := PlayerProfile.get_definition("ground_slam")
	var slam_skill := slam_definition.gameplay_scene.instantiate() as GroundSlamSkill
	player.skill_mount.add_child(slam_skill)
	slam_skill.setup(player, slam_definition, 0)
	if not slam_skill.request_activate(player) or not slam_skill.slamming or player.velocity.y > -slam_skill.slam_speed:
		failures.append("Ground Slam did not begin its downward impact state")
	slam_skill.queue_free()
	hud._update_weapon_panel()
	hud._update_skills()
	if hud.skill_name_labels[0].text != "WALLRUN" or hud.skill_name_labels[1].text != "SMOKE VEIL":
		failures.append("Dynamic arena HUD did not show expanded skills")
	if failures.is_empty():
		print("CONTENT_ARENA_TEST_OK: expanded weapons, skills, power, HUD and runtime effects instantiated from profile")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("CONTENT_ARENA_TEST_FAILURE: " + failure)
		get_tree().quit(1)


func _run_effect_self_test() -> void:
	print("EFFECT_TEST_START")
	await get_tree().physics_frame
	await get_tree().physics_frame
	# This regression test deliberately exercises the archived non-competitive
	# affix runtime. Standard Arena keeps the same code disabled through the
	# authoritative ArenaEquipmentResolver and has separate fairness coverage.
	player.standard_arena_ruleset = false
	bot.set_physics_process(false)
	player.set_physics_process(false)
	hud.set_process(false)
	var failures: Array[String] = []
	var original_weapon := player.current_weapon

	# Static and conditional affix execution.
	var rifle := _create_effect_test_weapon("vanguard_rifle", [&"heavy", &"rapid", &"stable", &"fast_reload"], [3, 3, 3, 3]) as VanguardRifleWeapon
	if rifle == null:
		failures.append("Could not instantiate affix test rifle")
	else:
		if rifle.body_damage <= 18.0 or rifle.fire_delay >= 0.111 or rifle.hipfire_spread_degrees >= 0.9 or rifle.reload_duration >= 2.0:
			failures.append("Heavy/Rapid/Stable/Fast Reload did not alter live weapon stats")
		rifle.free()
	var sniper := _create_effect_test_weapon("huntsman_rifle", [&"deadeye", &"fresh_mag", &"ricochet"], [3, 3, 3]) as SniperWeapon
	if sniper == null:
		failures.append("Could not instantiate affix test sniper")
	else:
		if sniper.headshot_damage <= 110.0 or sniper.effects.modify_damage(60.0, bot, false, false) <= 60.0 or not sniper.effects.should_ricochet():
			failures.append("Deadeye/Fresh Mag/Ricochet did not execute")
		sniper.free()

	var conditional := _create_effect_test_weapon("ronin_katana", [&"executioner", &"lightweight", &"airborne", &"glass_cannon", &"berserker", &"vampiric", &"duelist"], [3, 3, 3, 3, 3, 3, 3])
	if conditional == null:
		failures.append("Could not instantiate conditional affix weapon")
	else:
		player.current_weapon = conditional
		player.health.current_health = 25.0
		bot.health.current_health = 20.0
		var empowered := conditional.effects.modify_damage(20.0, bot, false, true)
		if empowered <= 30.0 or conditional.effects.movement_multiplier() <= 1.0 or conditional.effects.air_control_multiplier() <= 1.0 or conditional.effects.incoming_damage_multiplier() <= 1.0:
			failures.append("Executioner/Lightweight/Airborne/Glass Cannon/Berserker did not execute")
		conditional.effects.on_block(true)
		if conditional.effects.modify_damage(20.0, bot, false, true) <= 20.0:
			failures.append("Duelist perfect-parry empowerment did not execute")
		var health_before := player.health.current_health
		conditional.effects.on_damage_dealt(bot, DamageInfo.new(20.0, player, &"test", false, true), {"applied": 20.0})
		if player.health.current_health <= health_before:
			failures.append("Vampiric melee healing did not execute")
		player.current_weapon = original_weapon
		conditional.free()

	# Status effects and delayed echo execute on the reusable health/status path.
	bot.health.reset()
	var elemental := _create_effect_test_weapon("vanguard_rifle", [&"burning", &"frost", &"poisoned", &"bleeding", &"void", &"echo"], [3, 3, 3, 3, 3, 3])
	if elemental != null:
		for affix_id: StringName in [&"burning", &"frost", &"poisoned", &"bleeding", &"void"]:
			elemental.effects.force_apply_elemental_for_test(bot, affix_id)
		var statuses := ($Bot/StatusEffects as StatusEffectComponent).get_elemental_snapshot()
		if statuses.size() != 5 or ($Bot/StatusEffects as StatusEffectComponent).get_handling_multiplier() >= 1.0 or ($Bot/StatusEffects as StatusEffectComponent).get_healing_multiplier() >= 1.0:
			failures.append("Burning/Frost/Poison/Bleeding/Void status execution failed")
		var bot_hp_before := bot.health.current_health
		elemental.effects.force_echo_for_test(bot, 6.0)
		await get_tree().create_timer(0.45).timeout
		if bot.health.current_health >= bot_hp_before:
			failures.append("Echo delayed repeat damage did not execute")
		elemental.free()
	else:
		failures.append("Could not instantiate elemental affix weapon")

	# Ten Mythic mechanics are stateful, testable, and wired to their shared runtime.
	var phantom := _create_effect_test_weapon("phantom_katana")
	phantom.effects.on_kill(bot, DamageInfo.new(1.0, player, &"test", false, true))
	if not phantom.effects.request_special() or not player.is_invisible:
		failures.append("Phantom Katana kill-to-Phantom Step failed")
	player.notify_affix_attack()
	if player.is_invisible: failures.append("Phantom Step did not cancel on attack")
	phantom.free()
	var bloodrush := _create_effect_test_weapon("bloodrush_nodachi")
	bloodrush.effects.on_damage_dealt(bot, DamageInfo.new(1.0, player, &"test", false, true), {"applied": 1.0}, true)
	if bloodrush.effects.get_lunge_multiplier() <= 1.25: failures.append("Bloodrush heavy-hit lunge charge failed")
	bloodrush.free()
	var skybreaker := _create_effect_test_weapon("skybreaker")
	skybreaker.effects.on_damage_dealt(bot, DamageInfo.new(1.0, player, &"test", true, false), {"applied": 1.0})
	if not skybreaker.effects.request_special() or player.movement_buff_remaining <= 0.0: failures.append("Skybreaker headshot dash window failed")
	skybreaker.free()
	var rushfang := _create_effect_test_weapon("rushfang")
	for index: int in 5: rushfang.effects.on_damage_dealt(bot, DamageInfo.new(1.0, player), {"applied": 1.0})
	if rushfang.effects.special_buff_remaining <= 0.0: failures.append("Rushfang five-hit tempo failed")
	rushfang.free()
	var trident := _create_effect_test_weapon("trident")
	for index: int in 3: trident.effects.on_damage_dealt(bot, DamageInfo.new(1.0, player), {"applied": 1.0})
	if trident.effects.empowered_attacks != 3 or trident.effects.get_rate_multiplier() <= 1.0: failures.append("Trident perfect-burst empowerment failed")
	trident.free()
	var kingslayer := _create_effect_test_weapon("kingslayer")
	kingslayer.effects.on_damage_dealt(bot, DamageInfo.new(1.0, player, &"test", true), {"applied": 1.0})
	if not kingslayer.effects.request_special(): failures.append("Kingslayer headshot lunge window failed")
	kingslayer.free()
	var oathbreaker := _create_effect_test_weapon("oathbreaker")
	oathbreaker.effects.on_block(true)
	if oathbreaker.effects.get_heavy_windup_multiplier() >= 1.0: failures.append("Oathbreaker perfect-parry heavy counter failed")
	oathbreaker.free()
	var rift := _create_effect_test_weapon("rift_wand")
	var orb := Node3D.new()
	add_child(orb)
	orb.global_position = player.global_position + Vector3.UP * 3.0
	rift.effects.track_projectile(orb)
	if not rift.effects.request_special() or rift.effects.rift_cooldown <= 0.0: failures.append("Rift Wand collision-safe orb teleport failed")
	rift.free()
	var quickfang := _create_effect_test_weapon("quickfang")
	for index: int in 3: quickfang.effects.on_damage_dealt(bot, DamageInfo.new(1.0, player), {"applied": 1.0})
	if quickfang.effects.special_buff_remaining <= 0.0 or quickfang.effects.get_reload_multiplier() <= 2.0: failures.append("Quickfang three-hit reload/mobility proc failed")
	quickfang.free()
	var hell_twins := _create_effect_test_weapon("hell_twins")
	hell_twins.effects.on_kill(bot, DamageInfo.new(1.0, player))
	if hell_twins.effects.get_spread_multiplier(false) > 0.05 or player.air_control_buff_remaining <= 0.0: failures.append("Hell Twins kill accuracy/air-control proc failed")
	hell_twins.free()

	player.current_weapon = original_weapon
	player.health.reset()
	bot.health.reset()
	($Bot/StatusEffects as StatusEffectComponent).effects.clear()
	if failures.is_empty():
		print("EFFECT_TEST_OK: static, conditional, status, echo and all ten Mythic runtime mechanics passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("EFFECT_TEST_FAILURE: " + failure)
		get_tree().quit(1)


func _create_effect_test_weapon(item_id: String, affix_ids: Array[StringName] = [], affix_tiers: Array[int] = []) -> WeaponBase:
	var definition := PlayerProfile.get_definition(item_id)
	if definition == null or definition.gameplay_scene == null:
		return null
	var weapon := definition.gameplay_scene.instantiate() as WeaponBase
	if weapon == null:
		return null
	player.weapon_mount.add_child(weapon)
	weapon.setup(player)
	var instance := ItemInstance.create(definition, "effect-test:" + item_id)
	if not affix_ids.is_empty():
		instance.affix_ids = affix_ids.duplicate()
		instance.affix_tiers = affix_tiers.duplicate()
	weapon.configure_from_item(definition, instance)
	weapon.equip()
	return weapon


func _run_pause_flow_test() -> void:
	print("PAUSE_FLOW_START")
	await get_tree().process_frame
	var failures: Array[String] = []
	_toggle_pause()
	if not get_tree().paused or not pause_layer.visible or not player.is_cursor_free or MouseModeService.current_mode != MouseModeService.Mode.PAUSE:
		failures.append("Arena pause did not expose the free-cursor menu")
	_show_pause_settings()
	if not pause_settings_column.visible or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or MouseModeService.current_mode != MouseModeService.Mode.SETTINGS:
		failures.append("Arena pause settings did not retain UI cursor ownership")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._input(click)
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or not player.is_cursor_free:
		failures.append("Clicking Arena pause settings recaptured gameplay input")
	_hide_pause_settings()
	if not pause_menu_column.visible or MouseModeService.current_mode != MouseModeService.Mode.PAUSE:
		failures.append("Returning from Arena settings did not restore pause ownership")
	_toggle_pause()
	if get_tree().paused or pause_layer.visible or player.is_cursor_free or MouseModeService.current_mode != MouseModeService.Mode.GAMEPLAY:
		failures.append("Arena resume did not restore gameplay input")
	if not ResourceLoader.exists("res://scenes/lobby.tscn"):
		failures.append("Return-to-lobby destination is missing")
	if failures.is_empty():
		print("PAUSE_FLOW_OK: pause/settings clicks, resume, cursor ownership and lobby destination passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("PAUSE_FLOW_FAILURE: " + failure)
		get_tree().quit(1)


func _run_polish_self_test() -> void:
	var failures: Array[String] = []
	if player.visual_body.get_child_count() < 30 or bot.visual_body.get_child_count() < 30:
		failures.append("Tactical character models did not generate their detail layers")
	var settings_snapshot := GameSettings.to_dictionary()
	GameSettings.set_value(&"base_fov", 101.0, false)
	GameSettings.set_value(&"mouse_sensitivity", 0.0031, false)
	if not is_equal_approx(player.first_person_fov, 101.0) or not is_equal_approx(player.mouse_sensitivity, 0.0031):
		failures.append("Player did not consume live FOV/sensitivity settings")
	player.crosshair_impulse = 6.0
	if player.get_crosshair_spread() < 5.0:
		failures.append("Dynamic crosshair did not respond to weapon impulse")
	hud._show_damage_feedback({"amount": 42.0, "headshot": true, "blocked": false, "killed": false})
	var visible_damage_numbers := 0
	for label: Label in hud.damage_number_pool:
		visible_damage_numbers += int(label.visible)
	if hud.damage_number_pool.size() != 14 or visible_damage_numbers != 1:
		failures.append("Pooled damage number feedback did not activate exactly one slot")
	var audio_before := AudioEvents.emitted_count
	player.on_empty_weapon()
	if AudioEvents.emitted_count != audio_before + 1:
		failures.append("Audio event foundation did not receive gameplay events")
	bot.on_melee_swing(true)
	if float(bot.visual_body.get("telegraph_remaining")) <= 0.0:
		failures.append("Enemy heavy attack telegraph did not activate")
	player.equip_weapon(1)
	await get_tree().process_frame
	var placeholder := player.current_weapon.get_node_or_null("PlaceholderModel")
	if placeholder == null:
		failures.append("Weapon placeholder feedback node is missing")
	else:
		player.current_weapon.request_primary()
		placeholder.set("previous_ammo", int(player.current_weapon.get("ammo")) + 1)
		placeholder.call("_process", 0.001)
		if float(placeholder.get("flash_time")) <= 0.0:
			failures.append("Muzzle flash hook did not react to ammo consumption")
	GameSettings.apply_dictionary(settings_snapshot)
	if failures.is_empty():
		print("POLISH_TEST_OK: live settings, crosshair, damage numbers, audio hooks, telegraphs and muzzle feedback passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("POLISH_TEST_FAILURE: " + failure)
		get_tree().quit(1)


func _run_combat_feel_test() -> void:
	print("COMBAT_FEEL_TEST_START")
	await get_tree().physics_frame
	await get_tree().process_frame
	bot.set_physics_process(false)
	player.set_physics_process(false)
	var failures: Array[String] = []
	var families: Array[StringName] = [&"katana", &"nodachi", &"sniper", &"assault_rifle", &"burst_rifle", &"battle_rifle", &"sword", &"magic", &"pistol", &"akimbo_pistols"]
	var profile_signatures: Dictionary = {}
	for family: StringName in families:
		var profile := WeaponPresentationLibrary.for_family(family)
		if not profile.is_valid():
			failures.append("Invalid presentation profile: %s" % family)
		profile_signatures["%s:%s:%s" % [family, profile.hip_position, profile.fire_kick_distance]] = true
		if profile.hip_position == profile.tpp_position:
			failures.append("FPP and TPP offsets are identical: %s" % family)
	if profile_signatures.size() != families.size():
		failures.append("Weapon family presentation profiles are not distinct")
	var configured_families: Dictionary = {}
	for definition: ItemDefinition in ItemDatabase.DEFINITIONS:
		if definition.item_type != ItemDefinition.ItemType.WEAPON:
			continue
		var weapon := definition.gameplay_scene.instantiate() as WeaponBase
		if weapon == null:
			failures.append("Weapon scene failed to instantiate for combat feel: %s" % definition.id)
			continue
		weapon.setup(player)
		weapon.configure_from_item(definition, ItemInstance.create(definition, "combat-feel:%s" % definition.id))
		configured_families[weapon.get_presentation_profile().family] = true
		weapon.free()
	for family: StringName in families:
		if not configured_families.has(family):
			failures.append("No configured weapon covered family: %s" % family)

	var original_weapon := player.current_weapon
	var original_index := player.current_weapon_index
	var test_sniper_definition := PlayerProfile.get_definition("huntsman_rifle")
	var test_sniper := test_sniper_definition.gameplay_scene.instantiate() as SniperWeapon
	player.weapon_mount.add_child(test_sniper)
	test_sniper.setup(player)
	test_sniper.configure_from_item(test_sniper_definition, ItemInstance.create(test_sniper_definition, "combat-sniper"))
	test_sniper.equip()
	player.current_weapon = test_sniper
	test_sniper.secondary_pressed()
	if not test_sniper.is_aiming_down_sights() or not player.should_hide_crosshair():
		failures.append("Sniper ADS did not activate its precise hidden-crosshair state")
	var sniper_placeholder := test_sniper.get_node_or_null("PlaceholderModel")
	if sniper_placeholder == null:
		failures.append("Sniper presentation model was unavailable for ADS validation")
	else:
		sniper_placeholder.call("_process", 0.0)
		if not bool(sniper_placeholder.call("is_scope_tunnel_open")):
			failures.append("Sniper scope tunnel remained capped")
		if int(sniper_placeholder.call("get_visible_ads_occluder_count")) != 0:
			failures.append("Sniper lens or model reticle still occluded FPP ADS")
	hud._update_crosshair(0.0)
	if not hud.ads_reticle_root.visible or hud.crosshair_root.visible:
		failures.append("Precise HUD reticle did not replace the hip-fire crosshair in sniper ADS")
	var audio_before := AudioEvents.emitted_count
	var recoil_before := player.weapon_fire_offset
	player.on_weapon_fired(&"sniper", true)
	if player.weapon_fire_offset <= recoil_before or AudioEvents.emitted_count <= audio_before:
		failures.append("Sniper firing feedback did not produce recoil and audio")
	test_sniper.secondary_released()
	if sniper_placeholder != null:
		sniper_placeholder.call("_process", 0.0)
		if int(sniper_placeholder.call("get_visible_ads_occluder_count")) != 11:
			failures.append("Sniper lens presentation did not return after leaving ADS")
	test_sniper.ammo = 0
	test_sniper.fire_cooldown_remaining = 0.0
	audio_before = AudioEvents.emitted_count
	test_sniper.request_primary()
	if AudioEvents.emitted_count <= audio_before:
		failures.append("Dry-fire feedback did not emit audio")
	test_sniper.request_reload()
	if not test_sniper.is_reloading or test_sniper.reload_remaining <= 0.0:
		failures.append("Reload state did not begin")

	var katana_definition := PlayerProfile.get_definition("ronin_katana")
	var test_katana := katana_definition.gameplay_scene.instantiate() as KatanaWeapon
	player.weapon_mount.add_child(test_katana)
	test_katana.setup(player)
	test_katana.configure_from_item(katana_definition, ItemInstance.create(katana_definition, "combat-katana"))
	test_katana.equip()
	player.current_weapon = test_katana
	test_katana.request_primary()
	if test_katana.recovery_remaining <= 0.0 or test_katana.swing_remaining <= 0.0:
		failures.append("Melee light attack did not enter swing/recovery")
	test_katana.reset_weapon()
	test_katana.request_heavy()
	if test_katana.windup_remaining <= 0.0 or test_katana.recovery_remaining <= 0.0:
		failures.append("Melee heavy attack did not enter windup/recovery")
	test_katana.reset_weapon()
	test_katana.secondary_pressed()
	var parry_response := test_katana.get_damage_response(DamageInfo.new(20.0, bot, &"test_projectile", false, false))
	if not bool(parry_response.get("negate", false)) or not bool(parry_response.get("reflect", false)):
		failures.append("Perfect deflect window did not negate and reflect")
	test_katana.deflect_remaining = 0.0
	var block_response := test_katana.get_damage_response(DamageInfo.new(20.0, bot, &"test_melee", false, true))
	if float(block_response.get("damage_multiplier", 1.0)) >= 1.0:
		failures.append("Melee block did not reduce damage")
	player.request_combat_hit_stop(0.04)
	if not player.hit_stop_active or Engine.time_scale >= 1.0:
		failures.append("Strong melee hit-stop did not activate")
	player.hit_stop_until_msec = Time.get_ticks_msec() - 1
	player._update_hit_stop()
	if player.hit_stop_active or not is_equal_approx(Engine.time_scale, 1.0):
		failures.append("Hit-stop did not restore normal time")

	var marker_cases := [
		{"amount": 20.0, "headshot": false, "blocked": false, "killed": false},
		{"amount": 30.0, "headshot": true, "blocked": false, "killed": false},
		{"amount": 10.0, "armor_hit": true, "blocked": false, "killed": false},
		{"amount": 4.0, "blocked": true, "killed": false},
		{"amount": 38.0, "critical": true, "killed": false},
		{"amount": 3.0, "dot": true, "killed": false},
		{"amount": 60.0, "killed": true},
	]
	for marker_data: Dictionary in marker_cases:
		hud._show_damage_feedback(marker_data)
	if hud.damage_number_pool.size() != 14 or hud.damage_number_root.get_child_count() != 14:
		failures.append("Damage number pool is not fixed at 14 reusable labels")
	hud._on_player_feedback(&"damage_taken", {"damage": 12.0, "source_position": player.global_position - player.global_basis.z * 4.0})
	var direction_visible := false
	for edge_value: float in hud.damage_edge_values:
		direction_visible = direction_visible or edge_value > 0.0
	if not direction_visible:
		failures.append("Directional player damage indicator did not activate")

	bot._on_damage_resolved(DamageInfo.new(60.0, player, &"sniper"), 60.0, {})
	if bot.hit_reaction_strength < 0.20 or bot.hit_reaction_remaining <= 0.0:
		failures.append("Strong enemy hit reaction did not activate")
	player.current_weapon = original_weapon
	player.current_weapon_index = original_index
	if original_weapon != null:
		original_weapon.equip()
	test_sniper.queue_free()
	test_katana.queue_free()
	player.set_camera_mode(true, false)
	player._update_weapon_presentation(0.08, 0.0, false, 0.0, 0.0)
	var fpp_position := player.weapon_mount.position
	player.set_camera_mode(false, false)
	player._update_weapon_presentation(0.12, 0.0, false, 0.0, 0.0)
	var tpp_position := player.weapon_mount.position
	if fpp_position.distance_to(tpp_position) < 0.03 or tpp_position.length() > 1.5:
		failures.append("FPP/TPP weapon positions did not transition to bounded distinct offsets")
	bot.health.kill(player, &"combat_feel_test")
	await get_tree().process_frame
	var dead_weapon_held: Variant = bot.current_weapon.get("primary_held") if bot.current_weapon != null else false
	if not bot.is_dead or bot.collision_layer != 0 or bot.weapon_mount.visible or bot.current_weapon == null or dead_weapon_held == true:
		failures.append("Enemy death did not immediately disable combat/collision")
	if failures.is_empty():
		print("COMBAT_FEEL_TEST_OK: 10 families, firing, recoil, ADS, reload, dry fire, melee, block/deflect, hit types, pooled numbers, directional damage, reactions, death and FPP/TPP passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("COMBAT_FEEL_TEST_FAILURE: " + failure)
		get_tree().quit(1)


func _run_scene_flow_arena_leg() -> void:
	await get_tree().process_frame
	if player.weapon_definition_ids != ["ronin_katana", "huntsman_rifle"] or player.skill_definition_ids != ["dash", "double_jump"]:
		PlayerProfile.set_meta("scene_flow_failure", "Arena did not instantiate the profile during scene transition")
	PlayerProfile.set_meta("scene_flow_stage", "returned")
	_return_to_lobby()


func _run_self_test() -> void:
	print("SELF_TEST_START")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var failures: Array[String] = []
	bot.set_physics_process(false)
	respawn_delay = 0.05
	if player.weapons.size() != 2:
		failures.append("Player weapon loadout did not initialize")
	if bot.weapons.size() != 2:
		failures.append("Bot weapon loadout did not initialize")
	if player.health.current_health != 100.0 or bot.health.current_health != 100.0:
		failures.append("Health components did not initialize to 100")
	if $Arena.get_child_count() < 35:
		failures.append("Arena geometry did not generate")
	if get_tree().get_nodes_in_group("bot_cover_point").size() < 12 or get_tree().get_nodes_in_group("bot_flank_point").size() < 6:
		failures.append("Bot tactical arena hints did not generate")
	if get_tree().get_nodes_in_group("bot_vertical_route").size() < 3:
		failures.append("Bot vertical route hints did not generate")
	if get_tree().get_nodes_in_group("peek_training_spot").size() < 12:
		failures.append("1v1 peek training spots did not generate")
	if bot.movement == null:
		failures.append("Bot movement component did not initialize")
	failures.append_array(hud.get_layout_validation_errors())
	if get_tree().get_nodes_in_group("player").size() != 1 or get_tree().get_nodes_in_group("bot").size() != 1:
		failures.append("Character groups are invalid")
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "crouch", "jump", "peek_left", "peek_right", "skill_slot_1", "skill_slot_2", "toggle_camera", "weapon_1", "weapon_2", "primary_attack", "secondary_attack", "heavy_attack", "reload", "menu_toggle", "debug_toggle"]:
		if not InputMap.has_action(action):
			failures.append("Missing input action: " + action)
	# The known-open movement lane lets this validate both lean directions without
	# intentionally triggering the camera's wall clamp at the spawn cover.
	player.global_position = Vector3(-25.0, 0.15, 24.0)
	await get_tree().physics_frame
	Input.action_press("peek_right")
	for frame: int in range(24):
		await get_tree().process_frame
	Input.action_release("peek_right")
	if player.get_peek_amount() < 0.45:
		failures.append("Right peek did not shift and roll the camera")
	for frame: int in range(24):
		await get_tree().process_frame
	Input.action_press("peek_left")
	for frame: int in range(24):
		await get_tree().process_frame
	Input.action_release("peek_left")
	if player.get_peek_amount() > -0.35:
		failures.append("Left peek did not shift and roll the camera")
	for frame: int in range(24):
		await get_tree().process_frame

	print("SELF_TEST_SECTION: locomotion")
	# Real player physics: compare constant Kour run with crouch movement, then jump and dash.
	player.global_position = Vector3(-25, 0.15, 24)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var movement_start := player.global_position
	Input.action_press("move_forward")
	for frame in range(12):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	var run_distance := movement_start.distance_to(player.global_position)
	player.global_position = movement_start
	player.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for frame in range(12):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var crouch_distance := movement_start.distance_to(player.global_position)
	if run_distance < 0.35 or not player.movement.is_crouching:
		failures.append("Kour run/crouch response failed (run %.2f, crouch %.2f, lowered %s)" % [run_distance, crouch_distance, player.movement.is_crouching])
	player.global_position = movement_start
	player.velocity = Vector3.ZERO
	for frame in range(4):
		await get_tree().physics_frame
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	if player.velocity.y <= 0.0:
		failures.append("Ground jump did not create upward velocity")
	player.global_position = movement_start
	player.velocity = Vector3.ZERO
	player.dash_skill.reset()
	Input.action_press("skill_slot_1")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("skill_slot_1")
	if Vector2(player.velocity.x, player.velocity.z).length() < 20.0:
		failures.append("Dash input did not create expected collision-safe velocity")

	# Critical 0.1.1 contract: releasing W in the air preserves forward momentum.
	player.movement.reset()
	player.dash_skill.reset()
	player.double_jump_skill.reset()
	player.global_position = Vector3(-25, 0.05, 24)
	player.velocity = Vector3.ZERO
	for frame in range(4):
		await get_tree().physics_frame
	Input.action_press("move_forward")
	for frame in range(30):
		await get_tree().physics_frame
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	Input.action_release("move_forward")
	var release_speed := player.movement.get_horizontal_speed()
	for frame in range(12):
		await get_tree().physics_frame
	var preserved_air_speed := player.movement.get_horizontal_speed()
	if release_speed < 7.0 or preserved_air_speed < release_speed * 0.98:
		failures.append("Air momentum was not preserved after releasing W (%.2f -> %.2f)" % [release_speed, preserved_air_speed])

	# A/D without matching mouse movement must not alter airborne momentum.
	player.global_position = Vector3(-25, 8, 20)
	player.velocity = Vector3(0, 0, -10)
	await get_tree().physics_frame
	Input.action_press("move_right")
	for frame in range(16):
		await get_tree().physics_frame
	Input.action_release("move_right")
	if absf(player.velocity.x) > 0.1 or absf(player.velocity.z + 10.0) > 0.1:
		failures.append("Unsynchronized airborne A/D altered momentum (%s)" % str(player.velocity))
	player.global_position = Vector3(-25, 12, 20)
	player.velocity = Vector3(0, 0, -15.8)
	Input.action_press("move_right")
	for frame in range(45):
		await get_tree().physics_frame
	Input.action_release("move_right")
	if player.movement.get_horizontal_speed() > player.movement.bhop_speed_cap + 0.05:
		failures.append("Air-strafe speed exceeded bunny-hop cap (%.2f)" % player.movement.get_horizontal_speed())

	# Coyote jump is a normal jump and leaves the double jump available.
	player.global_position = Vector3(-25, 6, 20)
	player.velocity = Vector3(0, -1, -6)
	player.movement.was_on_floor = false
	player.movement.normal_jump_available = true
	player.movement.coyote_remaining = player.movement.coyote_time
	player.double_jump_skill.reset()
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	if player.velocity.y <= 0.0 or player.double_jump_skill.used_this_airborne_sequence:
		failures.append("Coyote jump failed or incorrectly consumed double jump (velocity %s, double %s, coyote %.3f)" % [player.velocity, player.double_jump_skill.used_this_airborne_sequence, player.movement.coyote_remaining])
	# Let one full physics tick observe the key release before the next press.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var speed_before_double_jump := player.movement.get_horizontal_speed()
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	if not player.double_jump_skill.used_this_airborne_sequence or absf(player.movement.get_horizontal_speed() - speed_before_double_jump) > 0.1:
		failures.append("Double jump failed (used %s, speed %.3f -> %.3f, velocity %s, held %s)" % [player.double_jump_skill.used_this_airborne_sequence, speed_before_double_jump, player.movement.get_horizontal_speed(), player.velocity, player.movement.jump_was_held])
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Jump buffer must fire a normal jump as soon as a descending player lands.
	player.movement.normal_jump_available = false
	player.movement.coyote_remaining = 0.0
	player.double_jump_skill.used_this_airborne_sequence = true
	player.global_position = Vector3(-25, 0.18, 20)
	player.velocity = Vector3(0, -2.5, -5)
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	for frame in range(7):
		await get_tree().physics_frame
	if player.velocity.y <= 0.0 or player.movement.normal_jump_available:
		failures.append("Buffered jump did not trigger immediately after landing")

	print("SELF_TEST_SECTION: crouch_slide")
	# Physical crouch transitions, blocked stand-up, slide, and slide jump.
	player.movement.reset()
	player.double_jump_skill.reset()
	player.global_position = Vector3(-25, 0.05, 24)
	player.velocity = Vector3.ZERO
	for frame in range(5):
		await get_tree().physics_frame
	Input.action_press("crouch")
	for frame in range(12):
		await get_tree().physics_frame
	if not player.movement.is_crouching or player.movement.body_shape.height > player.movement.crouch_height + 0.03:
		failures.append("Crouch did not reduce the physical capsule height")
	if player.pitch_pivot.position.y > player.movement.standing_camera_height - 0.35:
		failures.append("Crouch did not lower the shared FPP/TPP camera pivot")
	var ceiling := StaticBody3D.new()
	ceiling.collision_layer = 1
	ceiling.collision_mask = 2
	ceiling.position = Vector3(player.global_position.x, 1.38, player.global_position.z)
	var ceiling_collision := CollisionShape3D.new()
	var ceiling_shape := BoxShape3D.new()
	ceiling_shape.size = Vector3(3, 0.2, 3)
	ceiling_collision.shape = ceiling_shape
	ceiling.add_child(ceiling_collision)
	add_child(ceiling)
	await get_tree().physics_frame
	Input.action_release("crouch")
	for frame in range(8):
		await get_tree().physics_frame
	if player.movement.body_shape.height > player.movement.crouch_height + 0.05:
		failures.append("Player stood up despite blocked ceiling clearance")
	ceiling.queue_free()
	await get_tree().physics_frame
	for frame in range(12):
		await get_tree().physics_frame
	if player.movement.is_crouching:
		failures.append("Player did not stand after ceiling clearance returned")

	player.global_position = Vector3(-25, 0.05, 24)
	player.velocity = Vector3.ZERO
	for frame in range(3):
		await get_tree().physics_frame
	player.velocity = Vector3(0, 0, -10)
	Input.action_press("crouch")
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not player.movement.is_sliding:
		failures.append("Fast grounded crouch did not start a slide")
	for frame in range(48):
		await get_tree().physics_frame
	if not player.movement.is_sliding:
		failures.append("Kour slide ended before the 0.8 second slide-hop window")
	if player.movement.get_horizontal_speed() >= 10.9:
		failures.append("Extended slide did not naturally lose horizontal speed")
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	Input.action_release("crouch")
	if player.movement.is_sliding or player.velocity.y <= 0.0 or player.movement.get_horizontal_speed() < 7.0:
		failures.append("Slide jump failed to preserve useful momentum (%s)" % str(player.velocity))

	await _check_arena_movement_profile(failures)

	var preserved_velocity := Vector3(2, 3, 4)
	player.velocity = preserved_velocity
	player.set_camera_mode(false)
	if player.velocity != preserved_velocity or player.is_first_person or not player.view_camera.current:
		failures.append("TPP switch altered velocity or failed to activate camera")
	player.global_position = Vector3(0, 0.05, 27.75)
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	if player.spring_arm.get_hit_length() >= player.spring_arm.spring_length - 0.2:
		failures.append("Third-person SpringArm did not shorten against the south wall")
	var before_fpp_switch := player.velocity
	player.set_camera_mode(true)
	if player.velocity != before_fpp_switch or not player.is_first_person or not player.view_camera.current:
		failures.append("FPP switch altered velocity or failed to activate camera")
	player.velocity = Vector3.ZERO
	($Arena/LaunchPadSouth as LaunchPad)._on_body_entered(player)
	if player.velocity.y < 10.0:
		failures.append("Launch pad did not apply upward velocity")
	player.set_physics_process(false)
	player.movement.reset()

	print("SELF_TEST_SECTION: combat")
	# Skills: activation, anti-repeat, persistent cooldown, and reset contracts.
	player.dash_skill.reset()
	if not player.dash_skill.try_activate(Vector3.FORWARD) or not player.dash_skill.is_active():
		failures.append("Dash activation failed")
	if player.dash_skill.try_activate(Vector3.RIGHT):
		failures.append("Dash activated again during cooldown")
	player.double_jump_skill.reset()
	if not player.double_jump_skill.try_activate():
		failures.append("Double jump activation failed")
	if player.double_jump_skill.try_activate():
		failures.append("Double jump repeated in one airborne sequence")
	player.double_jump_skill.on_landed()
	if player.double_jump_skill.try_activate():
		failures.append("Landing bypassed double jump cooldown")

	# Melee hit query must resolve exactly one 28-damage hit.
	player.global_position = Vector3(0, 0.15, 3.0)
	player.rotation = Vector3.ZERO
	player.pitch_pivot.rotation = Vector3.ZERO
	bot.global_position = Vector3(0, 0.15, 1.1)
	bot.health.reset()
	player.equip_weapon(0)
	var katana := player.current_weapon as KatanaWeapon
	katana.reset_weapon()
	await get_tree().physics_frame
	katana.request_primary()
	await get_tree().physics_frame
	if not is_equal_approx(bot.health.current_health, 72.0):
		failures.append("Katana light attack did not apply one 28-damage hit (HP %.1f)" % bot.health.current_health)
	bot.health.reset()
	katana.reset_weapon()
	katana.request_heavy()
	await get_tree().create_timer(katana.heavy_windup + 0.05).timeout
	if not is_equal_approx(bot.health.current_health, 55.0):
		failures.append("Katana heavy attack did not apply one 45-damage hit (HP %.1f)" % bot.health.current_health)

	# Perfect ranged deflect negates and reflects; expired window becomes 70% block.
	player.health.reset()
	bot.health.reset()
	katana.reset_weapon()
	katana.secondary_pressed()
	bot.stagger_remaining = 0.0
	player.receive_damage(DamageInfo.new(30.0, bot, &"katana_light", false, true))
	if not is_equal_approx(player.health.current_health, 100.0) or bot.stagger_remaining <= 0.0:
		failures.append("Perfect melee deflect did not negate damage and stagger attacker")
	katana.secondary_released()
	katana.secondary_pressed()
	player.receive_damage(DamageInfo.new(20.0, bot, &"sniper", false, false))
	if not is_equal_approx(player.health.current_health, 100.0) or not is_equal_approx(bot.health.current_health, 80.0):
		failures.append("Perfect deflect did not negate and reflect ranged damage")
	katana.deflect_remaining = 0.0
	player.receive_damage(DamageInfo.new(100.0, bot, &"sniper", false, false))
	if not is_equal_approx(player.health.current_health, 70.0):
		failures.append("Normal katana block did not reduce damage by 70 percent")
	katana.secondary_released()

	# ADS hitscan crosses the world and classifies the target's head.
	player.health.reset()
	bot.health.reset()
	player.global_position = Vector3(-25, 0.15, 0.0)
	bot.global_position = Vector3(-25, 0.15, -6.0)
	bot.set_physics_process(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	bot.set_physics_process(false)
	bot.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.pitch_pivot.rotation = Vector3.ZERO
	player.camera_kick = 0.0
	player.equip_weapon(1)
	var sniper := player.current_weapon as SniperWeapon
	sniper.reset_weapon()
	player.pitch_pivot.rotation.x = -0.105
	await get_tree().physics_frame
	var body_test_ray := PhysicsRayQueryParameters3D.create(player.get_aim_origin(), player.get_aim_origin() + player.get_aim_direction() * 250.0, 1 | 2 | 4, player.get_aim_exclusions())
	body_test_ray.collide_with_areas = true
	body_test_ray.collide_with_bodies = true
	var body_test_hit := get_world_3d().direct_space_state.intersect_ray(body_test_ray)
	var center_origin := Vector3(player.global_position.x, bot.global_position.y + 0.92, player.global_position.z)
	var center_ray := PhysicsRayQueryParameters3D.create(center_origin, bot.global_position + Vector3.UP * 0.92, 2, player.get_aim_exclusions())
	var center_hit := get_world_3d().direct_space_state.intersect_ray(center_ray)
	sniper.request_primary()
	await get_tree().physics_frame
	if not is_equal_approx(bot.health.current_health, 42.0):
		var body_collider := "none"
		var body_hit_position := Vector3.ZERO
		if not body_test_hit.is_empty():
			body_collider = str((body_test_hit.get("collider") as Node).name)
			body_hit_position = body_test_hit.get("position", Vector3.ZERO)
		var center_collider := "none" if center_hit.is_empty() else str((center_hit.get("collider") as Node).name)
		failures.append("Sniper hipfire body shot failed (HP %.1f, collider %s at %s, center ray %s, aim %s, bot %s layer %d dead %s)" % [bot.health.current_health, body_collider, str(body_hit_position), center_collider, str(player.get_aim_direction()), str(bot.global_position), bot.collision_layer, str(bot.is_dead)])
	bot.health.reset()
	sniper.reset_weapon()
	sniper.ammo = 0
	sniper.request_primary()
	if not is_equal_approx(bot.health.current_health, 100.0):
		failures.append("Empty sniper fired a damaging shot")
	sniper.request_reload()
	sniper.reload_remaining = 0.001
	await get_tree().process_frame
	await get_tree().process_frame
	if sniper.ammo != sniper.magazine_size or sniper.is_reloading:
		failures.append("Sniper reload did not restore magazine")
	bot.health.reset()
	sniper.reset_weapon()
	player.pitch_pivot.rotation = Vector3.ZERO
	(bot.weapons[1] as SniperWeapon).ammo = 0
	await get_tree().physics_frame
	var test_ray := PhysicsRayQueryParameters3D.create(player.get_aim_origin(), player.get_aim_origin() + player.get_aim_direction() * 250.0, 1 | 2 | 4, player.get_aim_exclusions())
	test_ray.collide_with_areas = true
	test_ray.collide_with_bodies = true
	var test_hit := get_world_3d().direct_space_state.intersect_ray(test_ray)
	sniper.secondary_pressed()
	sniper.request_primary()
	sniper.secondary_released()
	await get_tree().physics_frame
	if bot.health.is_dead or not is_equal_approx(bot.health.current_health, 10.0):
		var collider_name := "none"
		var hit_position := Vector3.ZERO
		if not test_hit.is_empty():
			collider_name = str((test_hit.get("collider") as Node).name)
			hit_position = test_hit.get("position", Vector3.ZERO)
		failures.append("Normalized sniper headshot should leave a full-health target at 10 HP (bot HP %.1f, collider %s at %s, aim %s)" % [bot.health.current_health, collider_name, str(hit_position), str(player.get_aim_direction())])
	bot.receive_damage(DamageInfo.new(20.0, player, &"test_follow_up"))
	if not bot.health.is_dead or player_kills != 1:
		failures.append("Follow-up damage after a sniper headshot did not complete the elimination")
	await get_tree().create_timer(0.1).timeout
	if bot.health.is_dead or not is_equal_approx(bot.health.current_health, 100.0):
		failures.append("Bot did not respawn at full health")
	if (bot.weapons[1] as SniperWeapon).ammo != (bot.weapons[1] as SniperWeapon).magazine_size:
		failures.append("Bot sniper ammo did not reset on respawn")

	# Player death resets health, movement, loadout state and skill cooldowns.
	player.dash_skill.cooldown_remaining = 5.0
	player.double_jump_skill.cooldown_remaining = 3.0
	player.force_kill()
	if bot_kills != 1:
		failures.append("Player death did not increment bot score")
	await get_tree().create_timer(0.1).timeout
	if player.health.is_dead or not is_equal_approx(player.health.current_health, 100.0):
		failures.append("Player did not respawn at full health")
	if player.dash_skill.cooldown_remaining > 0.0 or player.double_jump_skill.cooldown_remaining > 0.0:
		failures.append("Player skill cooldowns did not reset on respawn")
	if (player.weapons[1] as SniperWeapon).ammo != (player.weapons[1] as SniperWeapon).magazine_size:
		failures.append("Player sniper ammo did not reset on respawn")
	if failures.is_empty():
		print("SELF_TEST_OK: movement, peeking, 1v1 training arena, combat, skills, HUD, death, score and respawn passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("SELF_TEST_FAILURE: " + failure)
		get_tree().quit(1)


func _check_arena_movement_profile(failures: Array[String]) -> void:
	print("SELF_TEST_SECTION: arena_movement_profile")
	player.movement.reset()
	player.dash_skill.reset()
	player.double_jump_skill.reset()
	player.global_position = Vector3(-25, 0.05, 24)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for frame in range(5):
		await get_tree().physics_frame
	Input.action_press("move_forward")
	Input.action_press("move_right")
	for frame in range(20):
		await get_tree().physics_frame
	if absf(player.movement.get_horizontal_speed() - player.movement.walk_speed) > 0.05:
		failures.append("Diagonal movement did not respect walk speed")
	Input.action_release("move_forward")
	Input.action_release("move_right")
	for frame in range(15):
		await get_tree().physics_frame
	if player.movement.get_horizontal_speed() > 0.05:
		failures.append("Ground movement did not stop promptly after release")

	var events: Array[StringName] = []
	var record_event := func(event_name: StringName) -> void: events.append(event_name)
	player.movement.movement_event.connect(record_event)
	Input.action_press("move_forward")
	for frame in range(20):
		await get_tree().physics_frame
	Input.action_press("jump")
	for frame in range(100):
		await get_tree().physics_frame
	Input.action_release("jump")
	Input.action_release("move_forward")
	player.movement.movement_event.disconnect(record_event)
	if events.count(&"jump") < 3 or events.has(&"double_jump") or player.double_jump_skill.used_this_airborne_sequence:
		failures.append("Held jump did not chain ground hops independently of Double Jump")
	if player.movement.get_horizontal_speed() > player.movement.bhop_speed_cap + 0.05:
		failures.append("Unsteered held jumps exceeded the bhop speed cap")

	# Each qualified landing adds speed, while an invalid hop breaks the chain.
	player.movement.reset()
	player.velocity = Vector3(0, 0, -player.movement.run_speed)
	player.movement.jump_was_held = true
	player.movement.bhop_landing_qualified = true
	player.movement._perform_ground_jump(false)
	var first_chain_speed := player.movement.get_horizontal_speed()
	player.movement.bhop_landing_qualified = true
	player.movement._perform_ground_jump(false)
	var second_chain_speed := player.movement.get_horizontal_speed()
	if first_chain_speed <= player.movement.run_speed or second_chain_speed <= first_chain_speed or player.movement.bhop_chain_count != 2:
		failures.append("Qualified consecutive bhops did not build speed (%.2f -> %.2f, chain %d)" % [first_chain_speed, second_chain_speed, player.movement.bhop_chain_count])
	player.velocity = Vector3(0, 0, -(player.movement.bhop_speed_cap - 0.2))
	player.movement.bhop_landing_qualified = true
	player.movement._perform_ground_jump(false)
	if player.movement.get_horizontal_speed() > player.movement.bhop_speed_cap + 0.01:
		failures.append("Bhop chain boost exceeded its speed cap")
	player.movement.bhop_landing_qualified = false
	player.movement._perform_ground_jump(false)
	if player.movement.bhop_chain_count != 0:
		failures.append("Invalid bhop did not reset the speed chain")

	# Bhop steering requires Space plus matching mouse-right and D input.
	player.movement.reset()
	player.global_position = Vector3(-25, 10, 20)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3(0, 0, -10)
	Input.action_press("jump")
	Input.action_press("move_right")
	for frame in range(12):
		player.rotate_y(deg_to_rad(-7.5))
		await get_tree().physics_frame
	Input.action_release("move_right")
	Input.action_release("jump")
	var camera_forward := -player.global_basis.z
	camera_forward.y = 0.0
	var flight_direction := player.movement.get_horizontal_velocity().normalized()
	if flight_direction.dot(camera_forward.normalized()) < 0.72:
		failures.append("Space + mouse-right + D did not steer bhop (%s vs %s)" % [flight_direction, camera_forward])
	if not player.movement.air_control_active:
		# Input is released above; state should clear on the next physics frame.
		pass
	player.rotation = Vector3.ZERO

	# Skills must tick once per physics frame, owned by PlayerController.
	player.dash_skill.cooldown_remaining = 3.0
	player.double_jump_skill.cooldown_remaining = 3.0
	for frame in range(12):
		await get_tree().physics_frame
	if player.dash_skill.cooldown_remaining < 2.7 or player.double_jump_skill.cooldown_remaining < 2.7:
		failures.append("Movement ticked equipped skill cooldowns twice")
	player.dash_skill.reset()
	player.double_jump_skill.reset()

	# Locomotion and landing also work for loadouts without these contextual skills.
	player.movement.dash_skill = null
	player.movement.double_jump_skill = null
	player.global_position = Vector3(-25, 0.2, 24)
	player.velocity = Vector3(0, -2, 0)
	player.movement.reset()
	for frame in range(10):
		await get_tree().physics_frame
	Input.action_press("jump")
	for frame in range(3):
		await get_tree().physics_frame
	Input.action_release("jump")
	if player.velocity.y <= 0.0:
		failures.append("Base jump required an equipped movement skill")
	player.movement.dash_skill = player.dash_skill
	player.movement.double_jump_skill = player.double_jump_skill

	player.velocity = Vector3(0, 0, -24)
	player.movement._start_slide()
	player.movement._perform_ground_jump(true)
	if player.movement.get_horizontal_speed() < 23.99:
		failures.append("Slide entry/jump erased incoming dash momentum")
	player.movement.reset()
	player.velocity = Vector3.ZERO


func _run_ai_soak_test() -> void:
	print("AI_SOAK_START")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var failures: Array[String] = []
	player.set_physics_process(false)
	bot.set_physics_process(false)
	player.health.max_health = 5000.0
	player.health.reset()
	bot.random.seed = 12012

	# Perception is geometry-gated, remembers only the last visible location, and
	# restores a reaction delay when the player reappears.
	bot.global_position = Vector3(-9.2, 0.15, 13.0)
	player.global_position = Vector3(-10.8, 0.15, 13.0)
	bot.set_target(player)
	await get_tree().physics_frame
	bot.sight_check_remaining = 0.0
	bot._update_perception(0.1)
	if not bot.has_line_of_sight:
		failures.append("Bot failed to see an unobstructed nearby player")
	var last_visible_position := bot.last_known_player_position
	player.global_position = Vector3(-5.0, 0.15, 13.0)
	await get_tree().physics_frame
	bot.sight_check_remaining = 0.0
	bot._update_perception(0.1)
	if bot.has_line_of_sight:
		failures.append("Bot retained line of sight through the keep wall")
	if bot.last_known_player_position.distance_to(last_visible_position) > 0.05:
		failures.append("Bot updated exact player knowledge while line of sight was blocked")
	player.global_position = last_visible_position
	await get_tree().physics_frame
	bot.sight_check_remaining = 0.0
	bot._update_perception(0.1)
	if bot.aim_reaction_remaining < bot.aim_reaction_delay - 0.02:
		failures.append("Bot reacquired the player without reaction delay")

	# Range hysteresis selects the expected weapon without per-frame switching.
	bot.weapon_switch_remaining = 0.0
	bot._choose_weapon_for_distance(bot.sniper_range + 5.0)
	if bot.current_weapon_index != 1:
		failures.append("Bot did not prefer sniper at range")
	bot.weapon_switch_remaining = 0.0
	bot._choose_weapon_for_distance(bot.melee_range - 1.0)
	if bot.current_weapon_index != 0:
		failures.append("Bot did not switch to katana nearby")
	if bot.weapon_switch_remaining <= 0.0:
		failures.append("Bot weapon switching did not apply hysteresis cooldown")
	bot.health.current_health = bot.retreat_health_threshold - 1.0
	bot.ai_state = BotController.STATE_APPROACH
	bot.state_lock_remaining = 0.0
	bot.has_line_of_sight = true
	bot._evaluate_state()
	if bot.ai_state != BotController.STATE_RETREAT:
		failures.append("Bot did not retreat below its health threshold")
	bot.health.reset()
	bot.ai_state = BotController.STATE_SEARCH
	bot._set_state(BotController.STATE_FLANK, 1.0)
	if bot.ai_state != BotController.STATE_FLANK or bot.tactical_target.distance_to(bot.global_position) < 2.0:
		failures.append("Bot did not select an alternate flank destination")
	bot.global_position = Vector3(0.0, 0.15, 0.0)
	player.global_position = Vector3(0.0, 5.5, -10.0)
	bot.last_known_player_position = player.global_position
	bot.has_line_of_sight = true
	bot.recent_damage_timer = 0.0
	bot.state_lock_remaining = 0.0
	bot._evaluate_state()
	var nearest_vertical_hint := INF
	for route_node: Node in get_tree().get_nodes_in_group("bot_vertical_route"):
		nearest_vertical_hint = minf(nearest_vertical_hint, bot.tactical_target.distance_to((route_node as Node3D).global_position))
	if bot.ai_state != BotController.STATE_FLANK or nearest_vertical_hint > 0.1:
		failures.append("Bot did not choose a launch-pad route for elevated pressure")

	# Let the full controller fight from an open long sightline.
	bot.health.reset()
	bot.movement.reset_state()
	bot.global_position = Vector3(20.0, 0.15, 25.0)
	player.global_position = Vector3(-20.0, 0.15, 25.0)
	bot.velocity = Vector3.ZERO
	bot.set_target(player)
	bot.weapon_switch_remaining = 0.0
	bot.decision_remaining = 0.0
	bot.state_lock_remaining = 0.0
	bot.debug_sniper_shots = 0
	bot.debug_reload_count = 0
	bot.flank_probability = 0.0
	bot.equip_weapon(1)
	bot.ai_state = BotController.STATE_SEARCH
	bot._set_state(BotController.STATE_RANGED, 0.5)
	bot.decision_remaining = 999.0
	bot.set_physics_process(true)
	for frame in range(480):
		await get_tree().physics_frame
	if bot.debug_sniper_shots <= 0:
		var aim_to_player := (player.global_position + Vector3.UP * 1.08 - bot.get_aim_origin()).normalized()
		failures.append("Bot did not aim and fire the sniper during ranged soak (%s, distance %.1f, aim dot %.3f, ammo %d)" % [str(bot.get_debug_snapshot()), bot.global_position.distance_to(player.global_position), bot.aim_direction.dot(aim_to_player), (bot.weapons[1] as SniperWeapon).ammo])
	if bot.debug_sniper_shots >= 5 and bot.debug_reload_count <= 0:
		failures.append("Bot fired through a full magazine without reloading")

	# Close-range soak verifies katana selection, orbiting pressure, and attacks.
	bot.global_position = Vector3(0.0, 0.15, 0.0)
	player.global_position = Vector3(0.0, 0.15, -2.2)
	bot.velocity = Vector3.ZERO
	bot.health.reset()
	bot.set_target(player)
	bot.weapon_switch_remaining = 0.0
	bot.decision_remaining = 0.0
	bot.state_lock_remaining = 0.0
	var melee_before := bot.debug_melee_swings
	for frame in range(240):
		await get_tree().physics_frame
	if bot.current_weapon_index != 0:
		failures.append("Bot did not retain katana in close combat")
	if bot.debug_melee_swings <= melee_before:
		failures.append("Bot did not attack during melee soak")
	bot.action_remaining = 0.0
	bot.block_remaining = 0.0
	(bot.current_weapon as KatanaWeapon).reset_weapon()
	bot.block_probability = 1.0
	bot.risk_tolerance = 1.0
	bot.global_position = Vector3(0.0, 0.15, 0.0)
	player.global_position = Vector3(0.0, 0.15, -2.0)
	bot.last_known_player_position = player.global_position
	var blocks_before := bot.debug_block_count
	bot._execute_melee_combat()
	if bot.debug_block_count <= blocks_before or not (bot.current_weapon as KatanaWeapon).is_blocking:
		failures.append("Bot did not enter its block/perfect-deflect response")
	(bot.current_weapon as KatanaWeapon).secondary_released()
	bot.block_remaining = 0.0

	# Force representative contextual mobility opportunities while using the same
	# physics executor as live AI.
	bot.global_position = Vector3(-20.0, 0.15, 22.0)
	bot.velocity = Vector3.ZERO
	player.global_position = Vector3(20.0, 0.15, 22.0)
	bot.set_target(player)
	bot.movement.reset_state()
	for frame in range(4):
		await get_tree().physics_frame
	var dash_before := bot.debug_dash_count
	bot.dash_skill.reset()
	bot.pending_dodge_direction = Vector3.RIGHT
	bot.pending_dodge_remaining = 0.4
	for frame in range(4):
		await get_tree().physics_frame
	if bot.debug_dash_count <= dash_before:
		failures.append("Bot contextual dodge dash did not activate")

	bot.global_position = Vector3(-20.0, 0.15, 22.0)
	bot.velocity = Vector3.ZERO
	bot.movement.reset_state()
	for frame in range(4):
		await get_tree().physics_frame
	var jump_before := bot.debug_jump_count
	bot.bhop_chain_remaining = 2
	for frame in range(150):
		await get_tree().physics_frame
	if bot.debug_jump_count <= jump_before or bot.debug_bhop_count <= 0:
		failures.append("Bot bunny-hop traversal did not activate")

	bot.global_position = Vector3(-20.0, 0.15, 22.0)
	bot.velocity = Vector3.ZERO
	bot.movement.reset_state()
	for frame in range(5):
		await get_tree().physics_frame
	bot.velocity = Vector3(0.0, 0.0, -9.2)
	bot.pending_slide_remaining = 0.8
	var slide_before := bot.debug_slide_count
	for frame in range(8):
		await get_tree().physics_frame
	if bot.debug_slide_count <= slide_before:
		failures.append("Bot contextual slide did not activate")

	# Drive into a boundary long enough to require recovery, then ensure the bot
	# exits that recovery rather than permanently pressing the wall.
	bot.global_position = Vector3(0.0, 0.15, 27.7)
	bot.velocity = Vector3.ZERO
	player.global_position = Vector3(0.0, 0.15, 35.0)
	bot.set_target(player)
	bot.has_line_of_sight = false
	bot.time_since_player_seen = 999.0
	bot.search_target = Vector3(0.0, 0.15, 40.0)
	bot.ai_state = BotController.STATE_SEARCH
	bot.decision_remaining = 999.0
	bot.state_lock_remaining = 0.0
	var recoveries_before := bot.stuck_recovery_count
	for frame in range(180):
		await get_tree().physics_frame
	if bot.stuck_recovery_count <= recoveries_before:
		failures.append("Bot stuck detector did not enter recovery at a blocked boundary")
	if bot.ai_state == BotController.STATE_STUCK and bot.state_time > 1.3:
		failures.append("Bot remained in stuck recovery permanently")

	# A controlled accuracy phase proves the complete bot-to-player kill path. Live
	# defaults remain imperfect; the override only removes randomness from this check.
	player.health.max_health = 100.0
	player.health.reset()
	player.global_position = Vector3(-5.0, 0.15, 26.5)
	bot.global_position = Vector3(5.0, 0.15, 26.5)
	bot.velocity = Vector3.ZERO
	bot.health.reset()
	bot.movement.reset_state()
	bot.equip_weapon(1)
	var kill_test_sniper := bot.current_weapon as SniperWeapon
	kill_test_sniper.reset_weapon()
	bot.set_target(player)
	bot.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	bot.aim_direction = (player.global_position + Vector3.UP * 0.92 - bot.get_aim_origin()).normalized()
	var kills_before := bot_kills
	kill_test_sniper.secondary_pressed()
	kill_test_sniper.request_primary()
	kill_test_sniper.fire_cooldown_remaining = 0.0
	kill_test_sniper.request_primary()
	kill_test_sniper.secondary_released()
	await get_tree().physics_frame
	if bot_kills <= kills_before:
		failures.append("Bot did not complete the player damage/death path (HP %.1f)" % player.health.current_health)

	if failures.is_empty():
		print("AI_SOAK_OK: perception, reaction, weapon choice, ranged/melee combat, mobility, stuck recovery and bot kill path passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("AI_SOAK_FAILURE: " + failure)
		get_tree().quit(1)


func _run_hud_layout_test() -> void:
	print("HUD_LAYOUT_START")
	await get_tree().process_frame
	await get_tree().process_frame
	var failures: Array[String] = []
	for test_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		get_window().size = test_size
		await get_tree().process_frame
		await get_tree().process_frame
		var layout_errors := hud.get_layout_validation_errors()
		for layout_error in layout_errors:
			failures.append("%dx%d: %s" % [test_size.x, test_size.y, layout_error])

	player.health.current_health = 24.0
	player.dash_skill.cooldown_remaining = 2.1
	player.double_jump_skill.cooldown_remaining = 1.6
	player.equip_weapon(1)
	var hud_sniper := player.current_weapon as SniperWeapon
	hud_sniper.ammo = 3
	hud_sniper.is_reloading = true
	hud_sniper.reload_remaining = 1.2
	await get_tree().process_frame
	if not hud.health_warning_label.visible or hud.health_value_label.text != "024":
		failures.append("Low-health HUD state did not become readable")
	if hud.ammo_label.text != "3 / 4" or not hud.reload_label.text.contains("RELOADING"):
		failures.append("Sniper ammo/reload HUD state did not update")
	if not hud.dash_state_label.text.contains("2.1") or not hud.jump_state_label.text.contains("1.6"):
		failures.append("Skill cooldown HUD state did not update")
	hud._show_hitmarker(true)
	if not hud.hitmarker.visible or not hud.headshot_label.visible:
		failures.append("Headshot marker did not instantiate")
	hud._on_player_feedback(&"damage_taken", {})
	await get_tree().process_frame
	if hud.damage_edges.is_empty() or hud.damage_edges[0].color.a <= 0.0:
		failures.append("Damage edge feedback did not animate")
	hud._on_kill_feed("ELIMINATED BOT")
	if hud.status_label.text != "ELIMINATED BOT":
		failures.append("Kill notification did not update")
	player.set_camera_mode(false)
	await get_tree().process_frame
	if not hud.camera_label.text.begins_with("TPP"):
		failures.append("Camera mode indicator did not update")
	hud.debug_visible = true
	hud.debug_panel.visible = true
	await get_tree().process_frame
	if not hud.debug_label.text.contains("BOT LOS"):
		failures.append("F3 telemetry remained mixed or unavailable")
	if failures.is_empty():
		print("HUD_LAYOUT_OK: anchored layouts and health, weapon, skill, damage, hit, kill, camera and debug states passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("HUD_LAYOUT_FAILURE: " + failure)
		get_tree().quit(1)


func _capture_validation_frame(third_person: bool = false) -> void:
	if third_person:
		player.set_camera_mode(false)
	for frame in range(30):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var capture_path := "res://validation_capture_tpp.png" if third_person else "res://validation_capture.png"
	var error := image.save_png(capture_path)
	if error == OK:
		print("CAPTURE_OK: " + capture_path)
		get_tree().quit(0)
	else:
		push_error("CAPTURE_FAILED: %s" % error_string(error))
		get_tree().quit(1)


func _capture_ads_frame() -> void:
	player.set_camera_mode(true, false)
	if player.weapons.size() > 1:
		player.equip_weapon(1)
	if player.current_weapon != null:
		player.current_weapon.secondary_pressed()
	for frame: int in 30:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var capture_path := "res://validation_capture_ads.png"
	var error := image.save_png(capture_path)
	print("ADS_CAPTURE_OK: " + capture_path if error == OK else "ADS_CAPTURE_FAILED: %s" % error_string(error))
	get_tree().quit(0 if error == OK else 1)
