class_name PlayerController
extends CharacterBody3D

signal actor_died(actor: Node, info: DamageInfo)
signal feedback(event_name: StringName, data: Dictionary)
signal pause_requested

@export_group("Camera")
@export var mouse_sensitivity: float = 0.0022
@export var first_person_fov: float = 90.0
@export var third_person_fov: float = 78.0
@export var ads_fov: float = 45.0
@export var sprint_fov_bonus: float = 4.0
@export var dash_fov_bonus: float = 7.0
@export var camera_effect_recovery: float = 8.0
@export var headbob_frequency: float = 9.0
@export var headbob_amplitude: float = 0.018
@export var landing_camera_impulse: float = 0.055
@export var tpp_follow_smoothing: float = 18.0
@export var tpp_rotation_smoothing: float = 22.0
@export var tpp_collision_smoothing: float = 11.0
@export var tpp_distance: float = 3.8
@export var camera_transition_duration: float = 0.16
@export var peek_distance: float = 0.42
@export var peek_roll_degrees: float = 13.0
@export var peek_speed: float = 11.5
@export var peek_collision_margin: float = 0.08

@onready var health: HealthComponent = $HealthComponent
@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var head_hurtbox: Hurtbox3D = $HeadHurtbox
@onready var visual_body: MeshInstance3D = $VisualBody
@onready var pitch_pivot: Node3D = $PitchPivot
@onready var first_person_camera: Camera3D = $PitchPivot/FirstPersonCamera
@onready var third_person_pivot: Node3D = $ThirdPersonPivot
@onready var spring_arm: SpringArm3D = $ThirdPersonPivot/ThirdPersonSpringArm
@onready var third_person_camera: Camera3D = $ThirdPersonPivot/ThirdPersonCamera
@onready var view_camera: Camera3D = $ViewCamera
@onready var weapon_mount: Node3D = $PitchPivot/WeaponMount
@onready var skill_mount: Node = $SkillMount
@onready var movement: PlayerMovementController = $MovementController

var weapons: Array[WeaponBase] = []
var weapon_definition_ids: Array[String] = []
var equipped_skills: Array[SkillBase] = []
var skill_definition_ids: Array[String] = []
var dash_skill: DashSkill
var double_jump_skill: DoubleJumpSkill
var current_weapon: WeaponBase
var current_weapon_index: int = 0
var is_first_person: bool = true
var is_dead: bool = false
var is_cursor_free: bool = false
var spawn_transform: Transform3D
var stagger_remaining: float = 0.0
var camera_kick: float = 0.0
var is_invisible: bool = false
var visibility_factor: float = 1.0
var gear_effects: Array[WeaponEffectRuntime] = []
var movement_buff_multiplier: float = 1.0
var movement_buff_remaining: float = 0.0
var jump_buff_multiplier: float = 1.0
var jump_buff_remaining: float = 0.0
var air_control_buff_multiplier: float = 1.0
var air_control_buff_remaining: float = 0.0
var overclock_remaining: float = 0.0
var linked_bonus_remaining: float = 0.0
var linked_bonus_multiplier: float = 1.0
var reversal_attacker: Node
var reversal_remaining: float = 0.0
var phase_check_remaining: float = 0.0
var phase_ready: bool = false
var recent_skill: SkillBase
var recent_skill_time: float = -100.0
var invisibility_sources: Dictionary = {}
var dungeon_durability_enabled: bool = false
var damage_immunity_remaining: float = 0.0
var camera_fov_impulse: float = 0.0
var camera_vertical_impulse: float = 0.0
var camera_roll_impulse: float = 0.0
var headbob_time: float = 0.0
var crosshair_impulse: float = 0.0
var footstep_remaining: float = 0.0
var was_sprinting_audio: bool = false
var tpp_collision_distance: float = 3.8
var camera_transition_remaining: float = 0.0
var camera_transition_from: Transform3D
var camera_view_initialized: bool = false
var peek_amount: float = 0.0
var first_person_camera_base_position: Vector3
var weapon_mount_base_position: Vector3
var weapon_mount_base_rotation: Vector3
var spring_arm_base_position: Vector3
var weapon_fire_offset: float = 0.0
var weapon_fire_pitch: float = 0.0
var weapon_fire_roll: float = 0.0
var weapon_swap_remaining: float = 0.0
var weapon_swap_total: float = 0.18
var weapon_sway_time: float = 0.0
var hit_stop_until_msec: int = 0
var hit_stop_active: bool = false


func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")
	spawn_transform = global_transform
	first_person_camera_base_position = first_person_camera.position
	weapon_mount_base_position = weapon_mount.position
	weapon_mount_base_rotation = weapon_mount.rotation
	spring_arm_base_position = spring_arm.position
	_instantiate_profile_loadout()
	for index: int in weapon_mount.get_child_count():
		var child := weapon_mount.get_child(index)
		if child is WeaponBase:
			var weapon := child as WeaponBase
			weapons.append(weapon)
			weapon.setup(self)
			weapon.configure_from_item(PlayerProfile.get_definition(weapon_definition_ids[index]), PlayerProfile.get_weapon_instance(index))
			weapon.hit_confirmed.connect(_on_weapon_hit)
			weapon.unequip()
	health.died.connect(_on_health_died)
	movement.setup(self, body_collision, visual_body, pitch_pivot, head_hurtbox, dash_skill, double_jump_skill)
	_build_gear_effects()
	movement.movement_event.connect(_on_movement_event)
	spring_arm.add_excluded_object(get_rid())
	spring_arm.add_excluded_object(head_hurtbox.get_rid())
	spring_arm.spring_length = tpp_distance
	equip_weapon(0)
	_apply_gameplay_settings()
	view_camera.set_as_top_level(true)
	set_camera_mode(true, false)
	if not GameSettings.changed.is_connected(_apply_gameplay_settings):
		GameSettings.changed.connect(_apply_gameplay_settings)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_toggle"):
		if not get_tree().paused and MouseModeService.current_mode == MouseModeService.Mode.SETTINGS:
			return
		pause_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused or not MouseModeService.is_gameplay_active():
		return
	if is_cursor_free:
		if event is InputEventMouseButton and event.pressed:
			if MouseModeService.capture_gameplay(self):
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and not is_dead:
		rotate_y(-event.relative.x * mouse_sensitivity)
		var pitch_sign := -1.0 if not GameSettings.invert_y else 1.0
		pitch_pivot.rotate_x(event.relative.y * mouse_sensitivity * pitch_sign)
		pitch_pivot.rotation.x = clampf(pitch_pivot.rotation.x, deg_to_rad(-84.0), deg_to_rad(84.0))
	if is_dead:
		return
	if event.is_action_pressed("toggle_camera"):
		set_camera_mode(not is_first_person)
	elif event.is_action_pressed("weapon_1"):
		equip_weapon(0)
	elif event.is_action_pressed("weapon_2"):
		equip_weapon(1)
	elif event.is_action_pressed("primary_attack") and current_weapon != null:
		_notify_skills_of_attack()
		current_weapon.request_primary()
		current_weapon.set_primary_held(true)
	elif event.is_action_released("primary_attack") and current_weapon != null:
		current_weapon.set_primary_held(false)
	elif event.is_action_pressed("secondary_attack") and current_weapon != null:
		current_weapon.secondary_pressed()
	elif event.is_action_released("secondary_attack") and current_weapon != null:
		current_weapon.secondary_released()
	elif event.is_action_pressed("heavy_attack") and current_weapon != null:
		_notify_skills_of_attack()
		current_weapon.request_heavy()
	elif event.is_action_pressed("reload") and current_weapon != null:
		current_weapon.request_reload()


func _process(delta: float) -> void:
	_update_hit_stop()
	_tick_affix_state(delta)
	crosshair_impulse = move_toward(crosshair_impulse, 0.0, delta * 22.0)
	camera_fov_impulse = move_toward(camera_fov_impulse, 0.0, delta * camera_effect_recovery)
	camera_vertical_impulse = move_toward(camera_vertical_impulse, 0.0, delta * camera_effect_recovery * 0.025)
	camera_roll_impulse = move_toward(camera_roll_impulse, 0.0, delta * camera_effect_recovery * 0.02)
	if camera_kick > 0.0001:
		var recovery := minf(camera_kick, delta * 0.8)
		pitch_pivot.rotation.x += recovery
		camera_kick -= recovery
	var movement_speed := movement.get_horizontal_speed() if movement.actor != null else 0.0
	weapon_sway_time += delta * (2.1 + clampf(movement_speed, 0.0, 12.0) * 0.34)
	_update_peek(delta)
	var sprinting := movement.movement_state == "SPRINT"
	var desired_fpp_fov := first_person_fov + (sprint_fov_bonus if sprinting else 0.0) + camera_fov_impulse
	var desired_tpp_fov := third_person_fov + (sprint_fov_bonus * 0.7 if sprinting else 0.0) + camera_fov_impulse * 0.7
	if current_weapon != null and current_weapon.is_aiming_down_sights():
		desired_fpp_fov = ads_fov
		desired_tpp_fov = ads_fov + 7.0
	first_person_camera.fov = lerpf(first_person_camera.fov, desired_fpp_fov, minf(1.0, delta * 14.0))
	third_person_camera.fov = lerpf(third_person_camera.fov, desired_tpp_fov, minf(1.0, delta * 14.0))
	var moving_on_floor := is_on_floor() and movement_speed > 1.0 and not is_dead
	if moving_on_floor:
		headbob_time += delta * headbob_frequency * clampf(movement_speed / movement.sprint_speed, 0.35, 1.25)
		footstep_remaining -= delta
		if footstep_remaining <= 0.0:
			AudioEvents.play(&"footstep", global_position, {"speed": movement_speed})
			footstep_remaining = 0.27 if sprinting else 0.38
	else:
		footstep_remaining = 0.0
	if sprinting and not was_sprinting_audio:
		AudioEvents.play(&"sprint", global_position)
	was_sprinting_audio = sprinting
	var bob_strength := GameSettings.headbob_strength * (0.35 if current_weapon != null and current_weapon.is_aiming_down_sights() else 1.0)
	var bob := Vector2(cos(headbob_time * 0.5), sin(headbob_time)) * headbob_amplitude * bob_strength if moving_on_floor else Vector2.ZERO
	var shake := GameSettings.camera_shake_strength
	var peek_offset := peek_amount * peek_distance
	var first_person_target := first_person_camera_base_position + Vector3(bob.x + peek_offset, bob.y + camera_vertical_impulse * shake, 0.0)
	first_person_camera.position = first_person_camera.position.lerp(first_person_target, minf(1.0, delta * 12.0))
	var peek_roll := deg_to_rad(-peek_roll_degrees) * peek_amount
	first_person_camera.rotation.z = lerp_angle(first_person_camera.rotation.z, camera_roll_impulse * shake + peek_roll, minf(1.0, delta * 12.0))
	_update_weapon_presentation(delta, movement_speed, sprinting, peek_offset, peek_roll)
	_update_third_person_target(delta, bob, shake)
	_update_view_camera(delta)


func _update_weapon_presentation(delta: float, movement_speed: float, sprinting: bool, peek_offset: float, peek_roll: float) -> void:
	var profile := current_weapon.get_presentation_profile() if current_weapon != null else WeaponPresentationLibrary.for_family(&"generic")
	weapon_fire_offset = move_toward(weapon_fire_offset, 0.0, delta * profile.fire_recovery)
	weapon_fire_pitch = move_toward(weapon_fire_pitch, 0.0, delta * profile.fire_recovery * 0.13)
	weapon_fire_roll = move_toward(weapon_fire_roll, 0.0, delta * profile.fire_recovery * 0.12)
	weapon_swap_remaining = maxf(0.0, weapon_swap_remaining - delta)
	var aiming := current_weapon != null and current_weapon.is_aiming_down_sights()
	var target_position := profile.hip_position
	var target_rotation := profile.hip_rotation
	var transition_speed := profile.pose_transition_speed
	if not is_first_person:
		target_position = profile.tpp_position
		target_rotation = profile.tpp_rotation
		transition_speed = profile.pose_transition_speed * 1.25
	elif aiming:
		target_position = profile.ads_position
		target_rotation = profile.ads_rotation
		transition_speed = profile.ads_transition_speed
	elif sprinting:
		target_position = profile.sprint_position
		target_rotation = profile.sprint_rotation
	var movement_ratio := clampf(movement_speed / maxf(movement.sprint_speed, 0.1), 0.0, 1.25)
	var ads_scale := 0.20 if aiming else (0.55 if not is_first_person else 1.0)
	var idle_wave := Vector3(sin(weapon_sway_time * 0.51), cos(weapon_sway_time * 0.73), sin(weapon_sway_time * 0.39))
	var move_wave := Vector3(cos(weapon_sway_time * 1.7), absf(sin(weapon_sway_time * 1.7)), sin(weapon_sway_time * 0.92))
	target_position += Vector3(
		idle_wave.x * profile.idle_sway_position.x,
		idle_wave.y * profile.idle_sway_position.y,
		idle_wave.z * profile.idle_sway_position.z
	) * ads_scale
	target_position += Vector3(
		move_wave.x * profile.movement_sway_position.x,
		-move_wave.y * profile.movement_sway_position.y,
		move_wave.z * profile.movement_sway_position.z
	) * movement_ratio * ads_scale
	target_rotation += Vector3(
		idle_wave.y * profile.idle_sway_rotation.x,
		idle_wave.x * profile.idle_sway_rotation.y,
		idle_wave.z * profile.idle_sway_rotation.z
	) * ads_scale
	target_rotation += Vector3(
		move_wave.y * profile.movement_sway_rotation.x,
		move_wave.x * profile.movement_sway_rotation.y,
		move_wave.x * profile.movement_sway_rotation.z
	) * movement_ratio * ads_scale
	var reloading := current_weapon != null and current_weapon.get("is_reloading") != null and bool(current_weapon.get("is_reloading"))
	if reloading:
		target_position.y -= profile.reload_drop
		target_rotation.x += profile.reload_tilt_radians
	if weapon_swap_remaining > 0.0:
		var swap_progress := 1.0 - weapon_swap_remaining / maxf(weapon_swap_total, 0.001)
		target_position.y -= sin(swap_progress * PI) * 0.14
		target_rotation.z += sin(swap_progress * PI) * 0.13
	target_position += Vector3(peek_offset * 0.72, -absf(peek_amount) * 0.018, weapon_fire_offset)
	target_rotation += Vector3(weapon_fire_pitch, 0.0, weapon_fire_roll + peek_roll * 0.72)
	var alpha := 1.0 - exp(-transition_speed * delta)
	weapon_mount.position = weapon_mount.position.lerp(target_position, alpha)
	weapon_mount.rotation.x = lerp_angle(weapon_mount.rotation.x, target_rotation.x, alpha)
	weapon_mount.rotation.y = lerp_angle(weapon_mount.rotation.y, target_rotation.y, alpha)
	weapon_mount.rotation.z = lerp_angle(weapon_mount.rotation.z, target_rotation.z, alpha)


func _update_peek(delta: float) -> void:
	var requested := 0.0
	if not is_dead and not is_cursor_free and MouseModeService.is_gameplay_active():
		requested = Input.get_action_strength("peek_right") - Input.get_action_strength("peek_left")
	requested = _collision_safe_peek(clampf(requested, -1.0, 1.0))
	var alpha := 1.0 - exp(-peek_speed * delta)
	peek_amount = lerpf(peek_amount, requested, alpha)
	if absf(peek_amount) < 0.001 and is_zero_approx(requested):
		peek_amount = 0.0


func _collision_safe_peek(requested: float) -> float:
	if is_zero_approx(requested) or not is_inside_tree():
		return 0.0
	var direction := global_basis.x * signf(requested)
	var origin := pitch_pivot.global_position
	var distance := peek_distance * absf(requested)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * distance, 1, [get_rid(), head_hurtbox.get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return requested
	var available := maxf(0.0, origin.distance_to(hit.get("position", origin)) - peek_collision_margin)
	return signf(requested) * minf(absf(requested), available / maxf(peek_distance, 0.001))


func get_peek_amount() -> float:
	return peek_amount


func _apply_gameplay_settings() -> void:
	mouse_sensitivity = GameSettings.mouse_sensitivity
	first_person_fov = GameSettings.base_fov
	third_person_fov = clampf(GameSettings.base_fov - 12.0, 65.0, 98.0)
	tpp_follow_smoothing = GameSettings.tpp_camera_smoothing


func _update_third_person_target(delta: float, bob: Vector2, shake: float) -> void:
	var follow_alpha := 1.0 - exp(-tpp_follow_smoothing * delta)
	var rotation_alpha := 1.0 - exp(-tpp_rotation_smoothing * delta)
	third_person_pivot.position.y = lerpf(third_person_pivot.position.y, pitch_pivot.position.y, follow_alpha)
	third_person_pivot.rotation.x = lerp_angle(third_person_pivot.rotation.x, pitch_pivot.rotation.x, rotation_alpha)
	spring_arm.spring_length = tpp_distance
	var hit_length := spring_arm.get_hit_length()
	if hit_length <= 0.01:
		hit_length = tpp_distance
	if hit_length < tpp_collision_distance:
		# Collision contraction is immediate so smoothing can never carry the camera through a wall.
		tpp_collision_distance = hit_length
	else:
		var collision_alpha := 1.0 - exp(-tpp_collision_smoothing * delta)
		tpp_collision_distance = lerpf(tpp_collision_distance, minf(hit_length, tpp_distance), collision_alpha)
	third_person_camera.position = Vector3(
		spring_arm_base_position.x + peek_amount * peek_distance * 0.72 + bob.x * 0.35,
		spring_arm.position.y + (bob.y + camera_vertical_impulse) * 0.35,
		tpp_collision_distance
	)
	var tpp_peek_roll := deg_to_rad(-peek_roll_degrees * 0.72) * peek_amount
	third_person_camera.rotation.z = lerp_angle(third_person_camera.rotation.z, camera_roll_impulse * shake * 0.45 + tpp_peek_roll, minf(1.0, delta * 10.0))


func _update_view_camera(delta: float) -> void:
	var target := first_person_camera if is_first_person else third_person_camera
	var target_transform := target.global_transform
	if camera_transition_remaining > 0.0:
		camera_transition_remaining = maxf(0.0, camera_transition_remaining - delta)
		var progress := 1.0 - camera_transition_remaining / maxf(camera_transition_duration, 0.001)
		var eased := smoothstep(0.0, 1.0, progress)
		view_camera.global_transform = camera_transition_from.interpolate_with(target_transform, eased)
	elif is_first_person:
		view_camera.global_transform = target_transform
	else:
		var position_alpha := 1.0 - exp(-tpp_follow_smoothing * delta)
		var rotation_alpha := 1.0 - exp(-tpp_rotation_smoothing * delta)
		view_camera.global_position = view_camera.global_position.lerp(target_transform.origin, position_alpha)
		view_camera.global_basis = view_camera.global_basis.slerp(target_transform.basis, rotation_alpha).orthonormalized()
	view_camera.fov = lerpf(view_camera.fov, target.fov, minf(1.0, delta * 14.0))


func get_crosshair_spread() -> float:
	var profile := current_weapon.get_presentation_profile() if current_weapon != null else WeaponPresentationLibrary.for_family(&"generic")
	if current_weapon != null and current_weapon.is_aiming_down_sights():
		return 0.0
	var speed_factor := clampf(movement.get_horizontal_speed() / maxf(movement.sprint_speed, 0.1), 0.0, 1.5)
	var stance_factor := 4.0 if movement.is_sliding else (1.5 if not is_on_floor() else 0.0)
	if movement.movement_state == "SPRINT":
		stance_factor += 2.2
	var weapon_spread := 0.0
	if current_weapon != null and current_weapon.get("hipfire_spread_degrees") != null:
		weapon_spread = clampf(float(current_weapon.get("hipfire_spread_degrees")) * 1.25, 0.0, 3.0)
	return clampf((speed_factor * 3.0 + stance_factor + crosshair_impulse + weapon_spread) * profile.crosshair_multiplier, 0.0, 13.0)


func should_hide_crosshair() -> bool:
	if current_weapon == null:
		return false
	var profile := current_weapon.get_presentation_profile()
	return current_weapon.is_aiming_down_sights() and profile.hide_crosshair_in_ads


func uses_simple_crosshair() -> bool:
	return current_weapon != null and current_weapon.get_presentation_profile().simple_melee_reticle


func _physics_process(delta: float) -> void:
	damage_immunity_remaining = maxf(0.0, damage_immunity_remaining - delta)
	stagger_remaining = maxf(0.0, stagger_remaining - delta)
	if is_dead:
		velocity = Vector3.ZERO
		return
	if Input.is_action_just_pressed("skill_slot_1"):
		_activate_skill_slot(0)
	if Input.is_action_just_released("skill_slot_1"):
		_release_skill_slot(0)
	if Input.is_action_just_pressed("skill_slot_2"):
		_activate_skill_slot(1)
	if Input.is_action_just_released("skill_slot_2"):
		_release_skill_slot(1)
	for skill: SkillBase in equipped_skills:
		skill.tick(delta)
		skill.physics_tick(self, delta)
	movement.physics_step(delta, stagger_remaining)


func equip_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == current_weapon_index and current_weapon != null:
		return
	var previous_hit_recent := false
	if current_weapon != null:
		previous_hit_recent = Time.get_ticks_msec() / 1000.0 - current_weapon.effects.last_damage_time < 2.0
		current_weapon.set_primary_held(false)
		current_weapon.unequip()
	current_weapon_index = index
	current_weapon = weapons[index]
	current_weapon.equip()
	current_weapon.effects.on_weapon_swap()
	weapon_swap_total = current_weapon.get_presentation_profile().swap_duration
	weapon_swap_remaining = weapon_swap_total
	if previous_hit_recent and _has_active_affix(&"linked"):
		linked_bonus_multiplier = 1.0 + _max_affix_value(&"linked") / 100.0
		linked_bonus_remaining = 1.5
	feedback.emit(&"weapon_switched", {"name": current_weapon.weapon_display_name})


func set_camera_mode(first_person: bool, animate: bool = true) -> void:
	if animate and camera_view_initialized:
		camera_transition_from = view_camera.global_transform
		camera_transition_remaining = camera_transition_duration
	is_first_person = first_person
	first_person_camera.current = false
	third_person_camera.current = false
	view_camera.current = true
	visual_body.visible = not first_person and not is_dead and not is_invisible
	if not animate or not camera_view_initialized:
		var target := first_person_camera if first_person else third_person_camera
		view_camera.global_transform = target.global_transform
		view_camera.fov = target.fov
		camera_transition_remaining = 0.0
	camera_view_initialized = true
	feedback.emit(&"camera_switched", {"mode": get_camera_mode_name()})


func get_camera_mode_name() -> String:
	return "FPP" if is_first_person else "TPP"


func get_aim_origin() -> Vector3:
	return view_camera.global_position


func get_melee_origin() -> Vector3:
	return global_position + Vector3.UP * minf(1.15, pitch_pivot.position.y - 0.2)


func get_aim_direction() -> Vector3:
	return -view_camera.global_basis.z.normalized()


func get_aim_exclusions() -> Array[RID]:
	return [get_rid(), head_hurtbox.get_rid()]


func is_headshot_position(hit_position: Vector3) -> bool:
	return hit_position.y - global_position.y >= head_hurtbox.position.y - 0.24


func modify_incoming_damage(info: DamageInfo) -> Dictionary:
	var multiplier := get_incoming_affix_multiplier()
	reversal_attacker = info.attacker
	reversal_remaining = 2.5
	phase_check_remaining = 0.0
	phase_ready = false
	if current_weapon != null:
		var response := current_weapon.get_damage_response(info)
		response["damage_multiplier"] = float(response.get("damage_multiplier", 1.0)) * multiplier
		if bool(response.get("negate", false)) or float(response.get("damage_multiplier", 1.0)) < multiplier:
			if dungeon_durability_enabled and current_weapon.item_instance != null:
				var wear := DurabilityService.PERFECT_BLOCK_WEAR if bool(response.get("negate", false)) else DurabilityService.BLOCK_WEAR
				DurabilityService.apply_weapon_use(current_weapon.item_instance, wear)
			for runtime: WeaponEffectRuntime in gear_effects:
				runtime.on_block(bool(response.get("negate", false)))
		return response
	return {"damage_multiplier": multiplier}


func receive_damage(info: DamageInfo) -> Dictionary:
	if damage_immunity_remaining > 0.0 and info != null and not info.bypass_defense:
		feedback.emit(&"spawn_protected", {"remaining": damage_immunity_remaining})
		return {"applied": 0.0, "negated": true, "protected": true}
	return health.apply_damage(info)


func grant_damage_immunity(duration: float) -> void:
	damage_immunity_remaining = maxf(damage_immunity_remaining, duration)


func on_damage_response(response_type: StringName, info: DamageInfo, applied: float) -> void:
	if dungeon_durability_enabled and applied > 0.0:
		DurabilityService.apply_equipped_gear_damage(PlayerProfile, applied)
	match response_type:
		&"deflect":
			feedback.emit(&"deflect", {"damage": info.amount, "source_position": _damage_source_position(info)})
			AudioEvents.play(&"deflect", global_position)
		&"block":
			feedback.emit(&"block", {"damage": applied, "source_position": _damage_source_position(info)})
			AudioEvents.play(&"block", global_position)
		_:
			feedback.emit(&"damage_taken", {"damage": applied, "headshot": info.headshot, "source_position": _damage_source_position(info)})
			if applied > 0.0:
				AudioEvents.play(&"player_damage", global_position, {"amount": applied})


func uses_dungeon_durability() -> bool:
	return dungeon_durability_enabled


func apply_knockback(force: Vector3) -> void:
	velocity += force


func apply_stagger(duration: float) -> void:
	stagger_remaining = maxf(stagger_remaining, duration)
	feedback.emit(&"stagger", {})


func apply_launch(launch_velocity: Vector3) -> void:
	velocity.x = lerpf(velocity.x, launch_velocity.x, 0.65)
	velocity.z = lerpf(velocity.z, launch_velocity.z, 0.65)
	velocity.y = maxf(velocity.y, launch_velocity.y)
	movement.on_external_launch()
	feedback.emit(&"launch", {})


func apply_weapon_lunge(strength: float) -> void:
	var forward := -global_basis.z
	forward.y = 0.0
	velocity += forward.normalized() * strength


func on_weapon_hit_confirmed(headshot: bool) -> void:
	_on_weapon_hit(headshot)


func on_damage_dealt_feedback(target: Node, info: DamageInfo, result: Dictionary) -> void:
	var elite := is_instance_valid(target) and (target.name == "Warden" or target.name.to_lower().contains("elite"))
	feedback.emit(&"damage_dealt", {
		"amount": float(result.get("applied", 0.0)),
		"headshot": info.headshot,
		"blocked": float(result.get("applied", 0.0)) < info.amount and not bool(result.get("deflected", false)),
		"parried": bool(result.get("deflected", false)),
		"armor_hit": bool(result.get("armor_hit", false)),
		"critical": bool(result.get("critical", false)),
		"proc": bool(result.get("proc", false)),
		"heavy": bool(result.get("heavy_attack", false)),
		"dot": info.damage_type in [&"burning", &"poisoned", &"bleeding", &"echo"],
		"killed": bool(result.get("killed", false)),
		"elite": elite,
		"position": info.hit_position,
		"damage_type": info.damage_type,
	})
	if bool(result.get("armor_hit", false)) or bool(result.get("blocked", false)) or float(result.get("applied", 0.0)) < info.amount:
		AudioEvents.play(&"armor_hit", info.hit_position)
	elif info.is_melee and String(info.damage_type).contains("heavy"):
		AudioEvents.play(&"heavy_hit", info.hit_position)
	else:
		AudioEvents.play(&"melee_hit" if info.is_melee else &"enemy_damage", info.hit_position)


func set_invisibility(active: bool, source: StringName = &"skill") -> void:
	if active:
		invisibility_sources[source] = true
	else:
		invisibility_sources.erase(source)
	is_invisible = not invisibility_sources.is_empty()
	visibility_factor = 0.15 if is_invisible else 1.0
	visual_body.visible = not is_first_person and not is_dead and not is_invisible
	feedback.emit(&"invisibility" if active else &"invisibility_end", {})


func force_kill() -> void:
	health.kill(null, &"fall")


func on_sniper_fired(ads: bool) -> void:
	on_weapon_fired(&"sniper", ads)


func on_rifle_fired(ads: bool) -> void:
	on_weapon_fired(current_weapon.get_presentation_profile().family if current_weapon != null else &"assault_rifle", ads)


func on_weapon_fired(family: StringName, ads: bool) -> void:
	var profile := current_weapon.get_presentation_profile() if current_weapon != null else WeaponPresentationLibrary.for_family(family)
	var recoil_multiplier := current_weapon.effects.get_recoil_multiplier() if current_weapon != null else 1.0
	var ads_multiplier := 0.58 if ads else 1.0
	var kick := profile.fire_pitch_radians * recoil_multiplier * ads_multiplier
	pitch_pivot.rotation.x = clampf(pitch_pivot.rotation.x - kick, deg_to_rad(-84.0), deg_to_rad(84.0))
	camera_kick += kick
	weapon_fire_offset = maxf(weapon_fire_offset, profile.fire_kick_distance * recoil_multiplier * ads_multiplier)
	weapon_fire_pitch -= profile.fire_pitch_radians * 0.75 * recoil_multiplier
	weapon_fire_roll += randf_range(-profile.fire_roll_radians, profile.fire_roll_radians) * recoil_multiplier
	crosshair_impulse = maxf(crosshair_impulse, profile.fire_crosshair_impulse * (0.35 if ads else 1.0))
	camera_roll_impulse += randf_range(-profile.fire_roll_radians, profile.fire_roll_radians) * 0.72
	feedback.emit(&"weapon_fired", {"ads": ads, "family": family})
	AudioEvents.play(_shot_audio_event(family), global_position, {"weapon": current_weapon.weapon_display_name if current_weapon != null else ""})


func on_melee_swing(heavy: bool) -> void:
	crosshair_impulse = maxf(crosshair_impulse, 7.0 if heavy else 4.0)
	camera_roll_impulse += -0.018 if heavy else -0.009
	feedback.emit(&"heavy_swing" if heavy else &"light_swing", {})
	AudioEvents.play(&"melee_swing", global_position, {"heavy": heavy})


func on_block_started() -> void:
	feedback.emit(&"block_started", {})
	AudioEvents.play(&"block", global_position)


func on_reload_started() -> void:
	feedback.emit(&"reload", {})
	AudioEvents.play(&"reload", global_position)


func on_empty_weapon() -> void:
	feedback.emit(&"empty", {})
	weapon_fire_offset = maxf(weapon_fire_offset, 0.018)
	AudioEvents.play(&"dry_fire", global_position)


func emit_combat_feedback(event_name: StringName, data: Dictionary = {}) -> void:
	feedback.emit(event_name, data)


func on_status_damage_feedback(target: Node, info: DamageInfo, result: Dictionary) -> void:
	on_damage_dealt_feedback(target, info, result)


func request_combat_hit_stop(duration: float) -> void:
	if is_dead or duration <= 0.0:
		return
	hit_stop_until_msec = maxi(hit_stop_until_msec, Time.get_ticks_msec() + roundi(duration * 1000.0))
	hit_stop_active = true
	Engine.time_scale = 0.18


func _update_hit_stop() -> void:
	if hit_stop_active and Time.get_ticks_msec() >= hit_stop_until_msec:
		hit_stop_active = false
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	if hit_stop_active:
		Engine.time_scale = 1.0


func _damage_source_position(info: DamageInfo) -> Vector3:
	if info != null and is_instance_valid(info.attacker) and info.attacker is Node3D:
		return (info.attacker as Node3D).global_position
	return info.hit_position if info != null else global_position


func _shot_audio_event(family: StringName) -> StringName:
	match family:
		&"sniper": return &"sniper_shot"
		&"battle_rifle": return &"battle_shot"
		&"burst_rifle": return &"burst_shot"
		&"pistol": return &"pistol_shot"
		&"akimbo_pistols": return &"akimbo_shot"
		&"magic": return &"magic_shot"
		_: return &"ar_shot"


func _on_weapon_hit(headshot: bool) -> void:
	AudioEvents.play(&"headshot" if headshot else &"hit")


func _on_movement_event(event_name: StringName) -> void:
	if event_name == &"landed":
		camera_vertical_impulse = -landing_camera_impulse * clampf(absf(velocity.y) / 6.0, 0.35, 1.0)
	elif event_name == &"dash":
		camera_fov_impulse = dash_fov_bonus
		camera_roll_impulse += 0.012
	if event_name == &"dash" and _has_active_affix(&"phase"):
		phase_check_remaining = 0.35
	for runtime: WeaponEffectRuntime in _active_effects():
		runtime.on_traversal(event_name)
	feedback.emit(event_name, {})
	match event_name:
		&"jump", &"landed", &"slide", &"dash", &"grapple":
			AudioEvents.play(&"land" if event_name == &"landed" else event_name, global_position)


func _on_health_died(info: DamageInfo) -> void:
	is_dead = true
	if hit_stop_active:
		hit_stop_active = false
		Engine.time_scale = 1.0
	peek_amount = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	body_collision.set_deferred("disabled", true)
	head_hurtbox.set_deferred("monitorable", false)
	visual_body.visible = false
	movement.on_death()
	if current_weapon != null:
		current_weapon.cancel_combat()
	feedback.emit(&"death", {})
	actor_died.emit(self, info)


func respawn() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	is_dead = false
	peek_amount = 0.0
	stagger_remaining = 0.0
	damage_immunity_remaining = 0.0
	invisibility_sources.clear()
	set_invisibility(false)
	_reset_affix_state()
	collision_layer = 2
	collision_mask = 1
	body_collision.set_deferred("disabled", false)
	head_hurtbox.set_deferred("monitorable", true)
	for skill: SkillBase in equipped_skills:
		skill.reset()
	movement.reset()
	for weapon in weapons:
		weapon.reset_weapon()
	health.reset()
	set_camera_mode(is_first_person, false)
	feedback.emit(&"respawn", {})


func get_skill_move_direction() -> Vector3:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := global_basis.x * input_vector.x + global_basis.z * input_vector.y
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = -global_basis.z
		direction.y = 0.0
	return direction.normalized()


func start_equipped_dash(skill: DashSkill) -> void:
	if stagger_remaining > 0.0:
		skill.active_remaining = 0.0
		skill.cooldown_remaining = 0.0
		return
	movement.start_equipped_dash(skill)


func emit_skill_feedback(event_name: StringName, data: Dictionary) -> void:
	feedback.emit(event_name, data)
	if event_name == &"grapple":
		AudioEvents.play(&"grapple", global_position, data)
	elif event_name == &"blink":
		AudioEvents.play(&"blink", global_position, data)


func perform_collision_safe_blink(distance: float) -> bool:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := global_basis.x * input_vector.x + global_basis.z * input_vector.y
	if direction.length_squared() < 0.01:
		direction = get_aim_direction()
		direction.y = clampf(direction.y, -0.38, 0.48)
	direction = direction.normalized()
	var capsule := body_collision.shape as CapsuleShape3D
	var center_offset := Vector3.UP * capsule.height * 0.5
	var origin := global_position + center_offset
	var target := origin + direction * distance
	var ray := PhysicsRayQueryParameters3D.create(origin, target, 1, [get_rid()])
	ray.collide_with_bodies = true
	ray.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		target = hit.get("position", target) - direction * (capsule.radius + 0.12)
	var candidate := target - center_offset
	var travel := candidate - global_position
	while travel.length() > 0.7:
		var shape_query := PhysicsShapeQueryParameters3D.new()
		shape_query.shape = capsule
		shape_query.transform = Transform3D(global_basis, candidate + center_offset)
		shape_query.collision_mask = 1
		shape_query.collide_with_bodies = true
		shape_query.collide_with_areas = false
		shape_query.exclude = [get_rid()]
		shape_query.margin = 0.03
		if get_world_3d().direct_space_state.intersect_shape(shape_query, 1).is_empty():
			global_position = candidate
			return true
		candidate -= direction * 0.25
		travel = candidate - global_position
	return false


func _activate_skill_slot(index: int) -> void:
	if index >= 0 and index < equipped_skills.size():
		var skill := equipped_skills[index]
		if skill.request_activate(self):
			recent_skill = skill
			recent_skill_time = Time.get_ticks_msec() / 1000.0
			if _has_active_affix(&"overclocked"):
				overclock_remaining = 1.5


func _release_skill_slot(index: int) -> void:
	if index >= 0 and index < equipped_skills.size():
		equipped_skills[index].request_release(self)


func _notify_skills_of_attack() -> void:
	damage_immunity_remaining = 0.0
	for skill: SkillBase in equipped_skills:
		skill.on_owner_attack(self)
	if invisibility_sources.has(&"phantom"):
		set_invisibility(false, &"phantom")


func notify_affix_attack() -> void:
	_notify_skills_of_attack()


func apply_temporary_movement_buff(multiplier: float, duration: float) -> void:
	movement_buff_multiplier = maxf(movement_buff_multiplier, multiplier)
	movement_buff_remaining = maxf(movement_buff_remaining, duration)


func apply_temporary_jump_buff(multiplier: float, duration: float) -> void:
	jump_buff_multiplier = maxf(jump_buff_multiplier, multiplier)
	jump_buff_remaining = maxf(jump_buff_remaining, duration)


func apply_temporary_air_control_buff(multiplier: float, duration: float) -> void:
	air_control_buff_multiplier = maxf(air_control_buff_multiplier, multiplier)
	air_control_buff_remaining = maxf(air_control_buff_remaining, duration)


func activate_phantom_state(duration: float) -> void:
	set_invisibility(true, &"phantom")
	apply_temporary_movement_buff(1.3, duration)
	apply_temporary_jump_buff(1.25, duration)
	feedback.emit(&"phantom_ready", {})


func apply_special_dash(speed: float) -> void:
	var direction := get_skill_move_direction()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed


func teleport_to_safe_point(point: Vector3) -> bool:
	var capsule := body_collision.shape as CapsuleShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(global_basis, point + Vector3.UP * capsule.height * 0.5)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	query.margin = 0.05
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	global_position = point
	return true


func reduce_skill_cooldowns(fraction: float) -> void:
	for skill: SkillBase in equipped_skills:
		skill.cooldown_remaining *= 1.0 - clampf(fraction, 0.0, 0.5)


func reduce_movement_skill_cooldowns(fraction: float) -> void:
	for skill: SkillBase in equipped_skills:
		if skill.skill_id in [&"dash", &"air_dash", &"launch", &"wallrun", &"grapple", &"blink"]:
			skill.cooldown_remaining *= 1.0 - clampf(fraction, 0.0, 0.4)


func refund_recent_skill(fraction: float) -> void:
	if is_instance_valid(recent_skill) and Time.get_ticks_msec() / 1000.0 - recent_skill_time < 1.5:
		recent_skill.cooldown_remaining *= 1.0 - clampf(fraction, 0.0, 0.35)


func notify_gear_kill(target: Node, info: DamageInfo) -> void:
	for runtime: WeaponEffectRuntime in gear_effects:
		runtime.on_kill(target, info)


func notify_gear_damage_dealt(target: Node, info: DamageInfo, result: Dictionary, heavy_attack: bool = false) -> void:
	for runtime: WeaponEffectRuntime in gear_effects:
		runtime.on_damage_dealt(target, info, result, heavy_attack)


func on_affix_dot_kill(target: Node, _status: StatusEffectComponent) -> void:
	var info := DamageInfo.new(0.0, self, &"elemental", false, false)
	if current_weapon != null:
		current_weapon.effects.on_kill(target, info)
	notify_gear_kill(target, info)


func get_affix_damage_multiplier(target: Node, headshot: bool = false, is_melee: bool = false) -> float:
	var multiplier := linked_bonus_multiplier if linked_bonus_remaining > 0.0 else 1.0
	if reversal_remaining > 0.0 and target == reversal_attacker and _has_active_affix(&"reversal"):
		multiplier *= 1.0 + _max_affix_value(&"reversal") / 100.0
	for runtime: WeaponEffectRuntime in gear_effects:
		multiplier *= runtime.modify_damage(1.0, target, headshot, is_melee)
	return multiplier


func consume_phase_penetration() -> float:
	if not phase_ready:
		return 0.0
	phase_ready = false
	return _max_affix_value(&"phase") / 100.0


func get_affix_rate_multiplier() -> float:
	var multiplier := 1.0
	if overclock_remaining > 0.0:
		multiplier *= 1.0 + _max_affix_value(&"overclocked") / 100.0
	if health.current_health / health.max_health < 0.2 and _has_active_affix(&"last_stand"):
		multiplier *= 1.0 + _max_affix_value(&"last_stand") / 100.0
	for runtime: WeaponEffectRuntime in gear_effects:
		multiplier *= runtime.get_rate_multiplier()
	return multiplier


func get_movement_speed_multiplier() -> float:
	var multiplier := movement_buff_multiplier if movement_buff_remaining > 0.0 else 1.0
	for runtime: WeaponEffectRuntime in _active_effects():
		multiplier *= runtime.movement_multiplier()
	return multiplier * ($StatusEffects as StatusEffectComponent).get_handling_multiplier()


func get_jump_multiplier() -> float:
	return jump_buff_multiplier if jump_buff_remaining > 0.0 else 1.0


func get_air_control_multiplier() -> float:
	var multiplier := air_control_buff_multiplier if air_control_buff_remaining > 0.0 else 1.0
	for runtime: WeaponEffectRuntime in _active_effects():
		multiplier *= runtime.air_control_multiplier()
	return multiplier * ($StatusEffects as StatusEffectComponent).get_handling_multiplier()


func get_slide_affix_multiplier() -> float:
	var multiplier := 1.0
	for runtime: WeaponEffectRuntime in _active_effects():
		multiplier *= runtime.slide_multiplier()
	return multiplier


func get_incoming_affix_multiplier() -> float:
	var multiplier := 1.0
	for runtime: WeaponEffectRuntime in _active_effects():
		multiplier *= runtime.incoming_damage_multiplier()
	return multiplier


func get_total_armor() -> float:
	var total := 0.0
	for key: String in PlayerProfile.GEAR_KEYS:
		var definition := PlayerProfile.get_definition(String(PlayerProfile.equipped_gear.get(key, "")))
		if definition != null:
			total += definition.armor_value
	return total


func _build_gear_effects() -> void:
	gear_effects.clear()
	for key: String in PlayerProfile.GEAR_KEYS:
		var instance := PlayerProfile.get_gear_instance(key)
		var definition := PlayerProfile.get_definition(String(PlayerProfile.equipped_gear.get(key, "")))
		if instance == null or definition == null:
			continue
		var runtime := WeaponEffectRuntime.new()
		runtime.configure(null, self, definition, instance)
		gear_effects.append(runtime)


func _active_effects() -> Array[WeaponEffectRuntime]:
	var result: Array[WeaponEffectRuntime] = gear_effects.duplicate()
	if current_weapon != null:
		result.append(current_weapon.effects)
	return result


func _has_active_affix(affix_id: StringName) -> bool:
	for runtime: WeaponEffectRuntime in _active_effects():
		if runtime.has(affix_id):
			return true
	return false


func _max_affix_value(affix_id: StringName) -> float:
	var result := 0.0
	for runtime: WeaponEffectRuntime in _active_effects():
		result = maxf(result, runtime.value(affix_id))
	return result


func _tick_affix_state(delta: float) -> void:
	for runtime: WeaponEffectRuntime in gear_effects:
		runtime.tick(delta)
	movement_buff_remaining = maxf(0.0, movement_buff_remaining - delta)
	jump_buff_remaining = maxf(0.0, jump_buff_remaining - delta)
	air_control_buff_remaining = maxf(0.0, air_control_buff_remaining - delta)
	overclock_remaining = maxf(0.0, overclock_remaining - delta)
	linked_bonus_remaining = maxf(0.0, linked_bonus_remaining - delta)
	reversal_remaining = maxf(0.0, reversal_remaining - delta)
	if phase_check_remaining > 0.0:
		phase_check_remaining = maxf(0.0, phase_check_remaining - delta)
		if phase_check_remaining <= 0.0:
			phase_ready = true
	if movement_buff_remaining <= 0.0:
		movement_buff_multiplier = 1.0
	if jump_buff_remaining <= 0.0:
		jump_buff_multiplier = 1.0
	if air_control_buff_remaining <= 0.0:
		air_control_buff_multiplier = 1.0


func _reset_affix_state() -> void:
	movement_buff_remaining = 0.0
	jump_buff_remaining = 0.0
	air_control_buff_remaining = 0.0
	overclock_remaining = 0.0
	linked_bonus_remaining = 0.0
	reversal_remaining = 0.0
	phase_check_remaining = 0.0
	phase_ready = false
	($StatusEffects as StatusEffectComponent).effects.clear()


func _instantiate_profile_loadout() -> void:
	weapons.clear()
	equipped_skills.clear()
	weapon_definition_ids = PlayerProfile.weapon_slots.duplicate()
	skill_definition_ids = PlayerProfile.skill_slots.duplicate()
	for item_id: String in weapon_definition_ids:
		var definition := PlayerProfile.get_definition(item_id)
		if definition == null or definition.gameplay_scene == null:
			continue
		var weapon := definition.gameplay_scene.instantiate() as WeaponBase
		if weapon == null:
			continue
		weapon_mount.add_child(weapon)
	for slot: int in skill_definition_ids.size():
		var definition := PlayerProfile.get_definition(skill_definition_ids[slot])
		if definition == null or definition.gameplay_scene == null:
			continue
		var skill := definition.gameplay_scene.instantiate() as SkillBase
		if skill == null:
			continue
		skill_mount.add_child(skill)
		skill.setup(self, definition, slot)
		equipped_skills.append(skill)
		if skill is DashSkill:
			dash_skill = skill as DashSkill
		elif skill is DoubleJumpSkill:
			double_jump_skill = skill as DoubleJumpSkill
