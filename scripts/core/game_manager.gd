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


func _ready() -> void:
	player.spawn_transform = player.global_transform
	bot.spawn_transform = bot.global_transform
	bot.set_target(player)
	player.actor_died.connect(_on_actor_died)
	bot.actor_died.connect(_on_actor_died)
	hud.bind(player, bot, self)
	score_changed.emit(player_kills, bot_kills)
	if "--self-test" in OS.get_cmdline_user_args():
		_run_self_test.call_deferred()
	elif "--capture-frame" in OS.get_cmdline_user_args():
		_capture_validation_frame.call_deferred()
	elif "--capture-tpp" in OS.get_cmdline_user_args():
		_capture_validation_frame.bind(true).call_deferred()


func _on_actor_died(actor: Node, info: DamageInfo) -> void:
	if actor == bot:
		player_kills += 1
		kill_feed.emit("BOT DOWN  +1")
	else:
		bot_kills += 1
		kill_feed.emit("PLAYER DOWN  —  BOT +1")
	score_changed.emit(player_kills, bot_kills)
	_respawn_actor(actor, info)


func _respawn_actor(actor: Node, _info: DamageInfo) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	if is_instance_valid(actor) and actor.has_method("respawn"):
		actor.respawn()


func _run_self_test() -> void:
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
	if get_tree().get_nodes_in_group("player").size() != 1 or get_tree().get_nodes_in_group("bot").size() != 1:
		failures.append("Character groups are invalid")
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "crouch", "jump", "dash", "toggle_camera", "weapon_1", "weapon_2", "primary_attack", "secondary_attack", "heavy_attack", "reload", "menu_toggle", "debug_toggle"]:
		if not InputMap.has_action(action):
			failures.append("Missing input action: " + action)

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
	Input.action_press("dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("dash")
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
	if player.velocity != preserved_velocity or not player.third_person_camera.current:
		failures.append("TPP switch altered velocity or failed to activate camera")
	player.global_position = Vector3(0, 0.05, 27.75)
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	if player.spring_arm.get_hit_length() >= player.spring_arm.spring_length - 0.2:
		failures.append("Third-person SpringArm did not shorten against the south wall")
	var before_fpp_switch := player.velocity
	player.set_camera_mode(true)
	if player.velocity != before_fpp_switch or not player.first_person_camera.current:
		failures.append("FPP switch altered velocity or failed to activate camera")
	player.velocity = Vector3.ZERO
	($Arena/LaunchPadSouth as LaunchPad)._on_body_entered(player)
	if player.velocity.y < 10.0:
		failures.append("Launch pad did not apply upward velocity")
	player.set_physics_process(false)
	player.movement.reset()

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
		print("SELF_TEST_OK: movement 0.1.1, runtime, arena, combat, skills, death, score and respawn passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("SELF_TEST_FAILURE: " + failure)
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
