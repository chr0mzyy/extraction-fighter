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

@onready var health: HealthComponent = $HealthComponent
@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var head_hurtbox: Hurtbox3D = $HeadHurtbox
@onready var visual_body: MeshInstance3D = $VisualBody
@onready var pitch_pivot: Node3D = $PitchPivot
@onready var first_person_camera: Camera3D = $PitchPivot/FirstPersonCamera
@onready var spring_arm: SpringArm3D = $PitchPivot/ThirdPersonSpringArm
@onready var third_person_camera: Camera3D = $PitchPivot/ThirdPersonSpringArm/ThirdPersonCamera
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


func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")
	spawn_transform = global_transform
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
	equip_weapon(0)
	set_camera_mode(true)
	_apply_gameplay_settings()
	if not GameSettings.changed.is_connected(_apply_gameplay_settings):
		GameSettings.changed.connect(_apply_gameplay_settings)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_toggle"):
		pause_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if is_cursor_free:
		if event is InputEventMouseButton and event.pressed:
			MouseModeService.capture_gameplay(self)
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
	first_person_camera.position = first_person_camera.position.lerp(Vector3(bob.x, bob.y + camera_vertical_impulse * shake, 0.0), minf(1.0, delta * 12.0))
	third_person_camera.position = third_person_camera.position.lerp(Vector3(bob.x * 0.35, (bob.y + camera_vertical_impulse) * 0.35, 0.0), minf(1.0, delta * 10.0))
	first_person_camera.rotation.z = lerpf(first_person_camera.rotation.z, camera_roll_impulse * shake, minf(1.0, delta * 12.0))
	third_person_camera.rotation.z = lerpf(third_person_camera.rotation.z, camera_roll_impulse * shake * 0.45, minf(1.0, delta * 10.0))


func _apply_gameplay_settings() -> void:
	mouse_sensitivity = GameSettings.mouse_sensitivity
	first_person_fov = GameSettings.base_fov
	third_person_fov = clampf(GameSettings.base_fov - 12.0, 65.0, 98.0)


func get_crosshair_spread() -> float:
	if current_weapon != null and current_weapon.is_aiming_down_sights():
		return 0.0
	var speed_factor := clampf(movement.get_horizontal_speed() / maxf(movement.sprint_speed, 0.1), 0.0, 1.5)
	var stance_factor := 4.0 if movement.is_sliding else (1.5 if not is_on_floor() else 0.0)
	return clampf(speed_factor * 3.0 + stance_factor + crosshair_impulse, 0.0, 10.0)


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
	if previous_hit_recent and _has_active_affix(&"linked"):
		linked_bonus_multiplier = 1.0 + _max_affix_value(&"linked") / 100.0
		linked_bonus_remaining = 1.5
	feedback.emit(&"weapon_switched", {"name": current_weapon.weapon_display_name})


func set_camera_mode(first_person: bool) -> void:
	is_first_person = first_person
	first_person_camera.current = first_person
	third_person_camera.current = not first_person
	visual_body.visible = not first_person and not is_dead and not is_invisible
	feedback.emit(&"camera_switched", {"mode": get_camera_mode_name()})


func get_camera_mode_name() -> String:
	return "FPP" if is_first_person else "TPP"


func get_aim_origin() -> Vector3:
	return first_person_camera.global_position if is_first_person else third_person_camera.global_position


func get_melee_origin() -> Vector3:
	return global_position + Vector3.UP * minf(1.15, pitch_pivot.position.y - 0.2)


func get_aim_direction() -> Vector3:
	var camera := first_person_camera if is_first_person else third_person_camera
	return -camera.global_basis.z.normalized()


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
			feedback.emit(&"deflect", {"damage": info.amount})
			AudioEvents.play(&"parry", global_position)
		&"block":
			feedback.emit(&"block", {"damage": applied})
			AudioEvents.play(&"block", global_position)
		_:
			feedback.emit(&"damage_taken", {"damage": applied, "headshot": info.headshot})


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
		"killed": bool(result.get("killed", false)),
		"elite": elite,
		"position": info.hit_position,
		"damage_type": info.damage_type,
	})
	AudioEvents.play(&"melee_hit" if info.is_melee else (&"headshot" if info.headshot else &"hit"), info.hit_position)


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
	var kick := (0.018 if ads else 0.028) * (current_weapon.effects.get_recoil_multiplier() if current_weapon != null else 1.0)
	pitch_pivot.rotation.x = clampf(pitch_pivot.rotation.x - kick, deg_to_rad(-84.0), deg_to_rad(84.0))
	camera_kick += kick
	crosshair_impulse = maxf(crosshair_impulse, 8.0 if not ads else 2.5)
	camera_roll_impulse += randf_range(-0.012, 0.012)
	feedback.emit(&"sniper_fired", {"ads": ads})
	AudioEvents.play(&"gunshot", global_position, {"weapon": current_weapon.weapon_display_name if current_weapon != null else ""})


func on_rifle_fired(ads: bool) -> void:
	var kick := (0.006 if ads else 0.01) * (current_weapon.effects.get_recoil_multiplier() if current_weapon != null else 1.0)
	pitch_pivot.rotation.x = clampf(pitch_pivot.rotation.x - kick, deg_to_rad(-84.0), deg_to_rad(84.0))
	camera_kick += kick
	crosshair_impulse = maxf(crosshair_impulse, 4.0 if not ads else 1.4)
	camera_roll_impulse += randf_range(-0.006, 0.006)
	feedback.emit(&"rifle_fired", {"ads": ads})
	AudioEvents.play(&"gunshot", global_position, {"weapon": current_weapon.weapon_display_name if current_weapon != null else ""})


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
	AudioEvents.play(&"empty", global_position)


func _on_weapon_hit(headshot: bool) -> void:
	feedback.emit(&"headshot" if headshot else &"hitmarker", {})


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
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	visual_body.visible = false
	movement.on_death()
	if current_weapon != null:
		current_weapon.secondary_released()
	feedback.emit(&"death", {})
	actor_died.emit(self, info)


func respawn() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	is_dead = false
	stagger_remaining = 0.0
	damage_immunity_remaining = 0.0
	invisibility_sources.clear()
	set_invisibility(false)
	_reset_affix_state()
	collision_layer = 2
	collision_mask = 1
	for skill: SkillBase in equipped_skills:
		skill.reset()
	movement.reset()
	for weapon in weapons:
		weapon.reset_weapon()
	health.reset()
	set_camera_mode(is_first_person)
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
