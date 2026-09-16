class_name GameManager
extends Node3D

signal score_changed(player_score: int, bot_score: int)
signal kill_feed(message: String)

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MouseModeService.capture_gameplay(player)
	AudioManager.play_music(&"arena")
	player.spawn_transform = player.global_transform
	bot.spawn_transform = bot.global_transform
	bot.set_target(player)
	player.actor_died.connect(_on_actor_died)
	player.pause_requested.connect(_toggle_pause)
	bot.actor_died.connect(_on_actor_died)
	hud.bind(player, bot, self)
	score_changed.emit(player_kills, bot_kills)
	_build_pause_menu()
	if "--self-test" in OS.get_cmdline_user_args():
		_run_self_test.call_deferred()
	elif "--ai-soak-test" in OS.get_cmdline_user_args():
		_run_ai_soak_test.call_deferred()
	elif "--hud-layout-test" in OS.get_cmdline_user_args():
		_run_hud_layout_test.call_deferred()
	elif "--capture-frame" in OS.get_cmdline_user_args():
		_capture_validation_frame.call_deferred()
	elif "--capture-tpp" in OS.get_cmdline_user_args():
		_capture_validation_frame.bind(true).call_deferred()
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
	elif "--scene-flow-test" in OS.get_cmdline_user_args():
		_run_scene_flow_arena_leg.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused and event.is_action_pressed("menu_toggle"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _on_actor_died(actor: Node, info: DamageInfo) -> void:
	AudioEvents.play(&"kill", (actor as Node3D).global_position if actor is Node3D else Vector3.ZERO)
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
	shade.color = Color(0.01, 0.015, 0.022, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_layer.add_child(shade)
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -190
	pause_panel.offset_right = 190
	pause_panel.offset_top = -235
	pause_panel.offset_bottom = 235
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.046, 0.061, 0.98)
	style.border_color = Color(0.28, 0.58, 0.64)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	pause_panel.add_theme_stylebox_override("panel", style)
	pause_layer.add_child(pause_panel)
	pause_menu_column = VBoxContainer.new()
	pause_menu_column.add_theme_constant_override("separation", 12)
	pause_panel.add_child(pause_menu_column)
	var title := Label.new()
	title.text = "ARENA PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.91, 0.93, 0.95))
	pause_menu_column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Your selected loadout remains saved"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.54, 0.62, 0.68))
	pause_menu_column.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	pause_menu_column.add_child(spacer)
	_add_pause_button(pause_menu_column, "RESUME", _toggle_pause)
	_add_pause_button(pause_menu_column, "SETTINGS", _show_pause_settings)
	_add_pause_button(pause_menu_column, "RETURN TO LOBBY", _return_to_lobby)
	_add_pause_button(pause_menu_column, "QUIT", _quit_game)
	_build_pause_settings()
	pause_layer.visible = false


func _build_pause_settings() -> void:
	pause_settings_column = VBoxContainer.new()
	pause_settings_column.add_theme_constant_override("separation", 9)
	pause_panel.add_child(pause_settings_column)
	var title := Label.new()
	title.text = "GAMEPLAY SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	pause_settings_column.add_child(title)
	_add_pause_slider("FOV", GameSettings.base_fov, 70.0, 110.0, 1.0, &"base_fov")
	_add_pause_slider("CAMERA SHAKE", GameSettings.camera_shake_strength, 0.0, 1.0, 0.05, &"camera_shake_strength")
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
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 15)
	button.mouse_entered.connect(func() -> void: AudioEvents.play(&"ui_hover"))
	button.pressed.connect(func() -> void: AudioEvents.play(&"ui_click"))
	button.pressed.connect(callback)
	parent.add_child(button)


func _toggle_pause() -> void:
	var should_pause := not get_tree().paused
	get_tree().paused = should_pause
	pause_layer.visible = should_pause
	if should_pause:
		_hide_pause_settings()
	else:
		MouseModeService.capture_gameplay(player)


func _return_to_lobby() -> void:
	get_tree().paused = false
	MouseModeService.enter_lobby()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()


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
		if not rifle.automatic_fire or rifle.fire_delay >= 0.111:
			failures.append("Vanguard Rifle base fire rate and rolled Rapid affix were not applied")
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
		if not is_equal_approx(sword.light_damage, 34.0) or not is_equal_approx(sword.heavy_damage, 55.0):
			failures.append("Knight Sword attack tuning did not initialize")
		sword.secondary_pressed()
		var response := sword.get_damage_response(DamageInfo.new(100.0, bot, &"test", false, false))
		if not is_equal_approx(float(response.get("damage_multiplier", 1.0)), 0.2) or bool(response.get("reflect", false)):
			failures.append("Knight Sword block identity is invalid")
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
	var settings_snapshot := GameSettings.to_dictionary()
	GameSettings.set_value(&"base_fov", 101.0, false)
	GameSettings.set_value(&"mouse_sensitivity", 0.0031, false)
	if not is_equal_approx(player.first_person_fov, 101.0) or not is_equal_approx(player.mouse_sensitivity, 0.0031):
		failures.append("Player did not consume live FOV/sensitivity settings")
	player.crosshair_impulse = 6.0
	if player.get_crosshair_spread() < 5.0:
		failures.append("Dynamic crosshair did not respond to weapon impulse")
	hud._show_damage_feedback({"amount": 42.0, "headshot": true, "blocked": false, "killed": false})
	if hud.damage_number_root.get_child_count() != 1:
		failures.append("Damage number feedback did not instantiate")
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
	if bot.movement == null:
		failures.append("Bot movement component did not initialize")
	failures.append_array(hud.get_layout_validation_errors())
	if get_tree().get_nodes_in_group("player").size() != 1 or get_tree().get_nodes_in_group("bot").size() != 1:
		failures.append("Character groups are invalid")
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "crouch", "jump", "skill_slot_1", "skill_slot_2", "toggle_camera", "weapon_1", "weapon_2", "primary_attack", "secondary_attack", "heavy_attack", "reload", "menu_toggle", "debug_toggle"]:
		if not InputMap.has_action(action):
			failures.append("Missing input action: " + action)

	print("SELF_TEST_SECTION: locomotion")
	# Real player physics: compare walk/sprint movement, then trigger jump and dash.
	player.global_position = Vector3(-25, 0.15, 24)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var movement_start := player.global_position
	Input.action_press("move_forward")
	for frame in range(12):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	var walk_distance := movement_start.distance_to(player.global_position)
	player.global_position = movement_start
	player.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for frame in range(12):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var sprint_distance := movement_start.distance_to(player.global_position)
	if walk_distance < 0.35 or sprint_distance <= walk_distance * 1.18:
		failures.append("Walk/sprint physics response failed (walk %.2f, sprint %.2f)" % [walk_distance, sprint_distance])
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
	Input.action_press("sprint")
	for frame in range(30):
		await get_tree().physics_frame
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var release_speed := player.movement.get_horizontal_speed()
	for frame in range(12):
		await get_tree().physics_frame
	var preserved_air_speed := player.movement.get_horizontal_speed()
	if release_speed < 7.0 or preserved_air_speed < release_speed * 0.98:
		failures.append("Air momentum was not preserved after releasing W (%.2f -> %.2f)" % [release_speed, preserved_air_speed])

	# Air strafing must curve velocity without an instant reversal or uncapped growth.
	player.global_position = Vector3(-25, 8, 20)
	player.velocity = Vector3(0, 0, -10)
	await get_tree().physics_frame
	Input.action_press("move_right")
	for frame in range(16):
		await get_tree().physics_frame
	Input.action_release("move_right")
	if player.velocity.x < 1.0 or player.velocity.z > -7.0:
		failures.append("Air strafe did not curve while preserving forward travel (%s)" % str(player.velocity))
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
		failures.append("Coyote jump failed or incorrectly consumed double jump")
	var speed_before_double_jump := player.movement.get_horizontal_speed()
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	if not player.double_jump_skill.used_this_airborne_sequence or absf(player.movement.get_horizontal_speed() - speed_before_double_jump) > 0.1:
		failures.append("Double jump did not preserve horizontal momentum")

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
	for frame in range(72):
		await get_tree().physics_frame
	if not player.movement.is_sliding:
		failures.append("Sprint-entry slide ended before the 1.2 second target")
	if player.movement.get_horizontal_speed() >= 10.9:
		failures.append("Extended slide did not naturally lose horizontal speed")
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	Input.action_release("crouch")
	if player.movement.is_sliding or player.velocity.y <= 0.0 or player.movement.get_horizontal_speed() < 7.0:
		failures.append("Slide jump failed to preserve useful momentum (%s)" % str(player.velocity))

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
	if not is_equal_approx(bot.health.current_health, 40.0):
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
	if not bot.health.is_dead or player_kills != 1:
		var collider_name := "none"
		var hit_position := Vector3.ZERO
		if not test_hit.is_empty():
			collider_name = str((test_hit.get("collider") as Node).name)
			hit_position = test_hit.get("position", Vector3.ZERO)
		failures.append("ADS headshot hitscan failed (bot HP %.1f, collider %s at %s, aim %s)" % [bot.health.current_health, collider_name, str(hit_position), str(player.get_aim_direction())])
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
		print("SELF_TEST_OK: movement, runtime, arena, combat, skills, HUD, death, score and respawn passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("SELF_TEST_FAILURE: " + failure)
		get_tree().quit(1)


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
