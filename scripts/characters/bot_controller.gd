class_name BotController
extends CharacterBody3D

signal actor_died(actor: Node, info: DamageInfo)
signal feedback(event_name: StringName, data: Dictionary)

const STATE_SEARCH: StringName = &"SEARCH"
const STATE_APPROACH: StringName = &"APPROACH"
const STATE_RANGED: StringName = &"RANGED_COMBAT"
const STATE_MELEE: StringName = &"MELEE_COMBAT"
const STATE_FLANK: StringName = &"FLANK"
const STATE_RETREAT: StringName = &"RETREAT"
const STATE_REPOSITION: StringName = &"REPOSITION"
const STATE_RECOVER: StringName = &"RECOVER"
const STATE_STUCK: StringName = &"STUCK_RECOVERY"

@export_group("Personality")
@export_range(0.0, 1.0) var aggression: float = 0.65
@export_range(0.0, 1.0) var mobility: float = 0.75
@export_range(0.0, 1.0) var accuracy: float = 0.55
@export_range(0.0, 1.0) var risk_tolerance: float = 0.60

@export_group("Perception And Aim")
@export var reaction_time_min: float = 0.18
@export var reaction_time_max: float = 0.45
@export var aim_reaction_delay: float = 0.26
@export var aim_smoothing: float = 4.2
@export var aim_error_close: float = 0.17
@export var aim_error_medium: float = 0.42
@export var aim_error_long: float = 0.88
@export var memory_duration: float = 3.2
@export var sight_check_interval: float = 0.10

@export_group("Combat Decisions")
@export var melee_range: float = 8.0
@export var melee_attack_range: float = 2.75
@export var sniper_range: float = 14.0
@export var weapon_switch_cooldown: float = 1.15
@export var retreat_health_threshold: float = 30.0
@export_range(0.0, 1.0) var block_probability: float = 0.22
@export_range(0.0, 1.0) var perfect_deflect_probability: float = 0.16
@export_range(0.0, 1.0) var heavy_attack_probability: float = 0.27
@export var sniper_aim_time_min: float = 0.38
@export var sniper_aim_time_max: float = 0.78
@export var sniper_relocate_shots_min: int = 2
@export var sniper_relocate_shots_max: int = 3

@export_group("Movement Decisions")
@export_range(0.0, 1.0) var jump_probability: float = 0.10
@export_range(0.0, 1.0) var bhop_probability: float = 0.18
@export var bhop_chain_min: int = 2
@export var bhop_chain_max: int = 4
@export_range(0.0, 1.0) var slide_probability: float = 0.20
@export var min_slide_speed: float = 7.4
@export_range(0.0, 1.0) var dash_engage_probability: float = 0.32
@export_range(0.0, 1.0) var dash_escape_probability: float = 0.58
@export_range(0.0, 1.0) var dash_dodge_probability: float = 0.36

@export_group("Tactics")
@export_range(0.0, 1.0) var flank_probability: float = 0.28
@export var flank_distance_threshold: float = 13.0
@export var stuck_detection_time: float = 0.72
@export var stuck_min_displacement: float = 0.012

@onready var health: HealthComponent = $HealthComponent
@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var head_hurtbox: Hurtbox3D = $HeadHurtbox
@onready var visual_body: MeshInstance3D = $VisualBody
@onready var aim_pivot: Node3D = $AimPivot
@onready var weapon_mount: Node3D = $AimPivot/WeaponMount
@onready var dash_skill: DashSkill = $DashSkill
@onready var movement: BotMovementController = $MovementController

var weapons: Array[WeaponBase] = []
var current_weapon: WeaponBase
var current_weapon_index: int = -1
var target: Node3D
var is_dead: bool = false
var spawn_transform: Transform3D

var ai_state: StringName = &"SPAWNING"
var has_line_of_sight: bool = false
var time_since_player_seen: float = 999.0
var last_known_player_position: Vector3 = Vector3.ZERO
var observed_player_position: Vector3 = Vector3.ZERO
var player_disappeared_direction: Vector3 = Vector3.ZERO
var desired_aim_direction: Vector3 = Vector3.FORWARD
var aim_direction: Vector3 = Vector3.FORWARD
var move_direction: Vector3 = Vector3.ZERO

var decision_remaining: float = 0.0
var sight_check_remaining: float = 0.0
var observation_refresh_remaining: float = 0.0
var aim_reaction_remaining: float = 0.0
var state_lock_remaining: float = 0.0
var state_time: float = 0.0
var action_remaining: float = 0.0
var weapon_switch_remaining: float = 0.0
var block_remaining: float = 0.0
var crouch_remaining: float = 0.0
var recent_damage_timer: float = 0.0
var stagger_remaining: float = 0.0
var mobility_decision_remaining: float = 0.0
var pending_slide_remaining: float = 0.0
var bhop_jump_guard: float = 0.0
var pending_dodge_remaining: float = 0.0
var pending_dodge_direction: Vector3 = Vector3.ZERO

var strafe_sign: float = 1.0
var strafe_change_remaining: float = 0.0
var tactical_target: Vector3 = Vector3.ZERO
var search_target: Vector3 = Vector3.ZERO
var recovery_direction: Vector3 = Vector3.ZERO
var last_cover_position: Vector3 = Vector3(10000.0, 10000.0, 10000.0)
var sniper_shots_from_position: int = 0
var sniper_relocate_after: int = 2
var bhop_chain_remaining: int = 0
var stuck_timer: float = 0.0
var stuck_recovery_count: int = 0

var wants_sprint: bool = false
var wants_crouch: bool = false
var wants_slide: bool = false
var wants_jump: bool = false
var wants_dash: bool = false
var requested_dash_direction: Vector3 = Vector3.ZERO

var debug_jump_count: int = 0
var debug_dash_count: int = 0
var debug_slide_count: int = 0
var debug_bhop_count: int = 0
var debug_sniper_shots: int = 0
var debug_melee_swings: int = 0
var debug_reload_count: int = 0
var debug_block_count: int = 0

var random := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("bot")
	spawn_transform = global_transform
	random.randomize()
	for child in weapon_mount.get_children():
		if child is WeaponBase:
			var weapon := child as WeaponBase
			weapons.append(weapon)
			weapon.setup(self)
			weapon.unequip()
	movement.setup(self, body_collision, visual_body, head_hurtbox, aim_pivot, dash_skill)
	movement.slide_min_speed = min_slide_speed
	movement.movement_event.connect(_on_movement_event)
	health.died.connect(_on_health_died)
	health.damage_resolved.connect(_on_damage_resolved)
	equip_weapon(1)
	aim_direction = -global_basis.z
	desired_aim_direction = aim_direction
	decision_remaining = random.randf_range(reaction_time_min, reaction_time_max)
	observation_refresh_remaining = decision_remaining
	_choose_search_target()


func set_target(new_target: Node3D) -> void:
	target = new_target
	has_line_of_sight = false
	time_since_player_seen = 999.0
	if is_instance_valid(target):
		last_known_player_position = target.global_position
		observed_player_position = last_known_player_position
		aim_reaction_remaining = maxf(aim_reaction_delay, random.randf_range(reaction_time_min, reaction_time_max))


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if is_dead:
		velocity = Vector3.ZERO
		return

	_reset_frame_requests()
	if not is_instance_valid(target) or bool(target.get("is_dead")):
		has_line_of_sight = false
		_set_state(STATE_SEARCH, 0.5)
		_execute_search()
		_run_movement(delta)
		return

	_update_perception(delta)
	_update_aim(delta)
	if decision_remaining <= 0.0:
		decision_remaining = random.randf_range(reaction_time_min, reaction_time_max)
		_evaluate_state()
		_consider_incidental_movement()
	_update_strafe(delta)
	_execute_current_state()
	_handle_defense()
	_handle_mobility_opportunity()
	_run_movement(delta)


func _tick_timers(delta: float) -> void:
	decision_remaining -= delta
	sight_check_remaining -= delta
	observation_refresh_remaining -= delta
	aim_reaction_remaining = maxf(0.0, aim_reaction_remaining - delta)
	state_lock_remaining = maxf(0.0, state_lock_remaining - delta)
	state_time += delta
	action_remaining = maxf(0.0, action_remaining - delta)
	weapon_switch_remaining = maxf(0.0, weapon_switch_remaining - delta)
	block_remaining = maxf(0.0, block_remaining - delta)
	crouch_remaining = maxf(0.0, crouch_remaining - delta)
	recent_damage_timer = maxf(0.0, recent_damage_timer - delta)
	stagger_remaining = maxf(0.0, stagger_remaining - delta)
	mobility_decision_remaining = maxf(0.0, mobility_decision_remaining - delta)
	pending_slide_remaining = maxf(0.0, pending_slide_remaining - delta)
	bhop_jump_guard = maxf(0.0, bhop_jump_guard - delta)
	pending_dodge_remaining = maxf(0.0, pending_dodge_remaining - delta)


func _reset_frame_requests() -> void:
	wants_sprint = false
	wants_crouch = false
	wants_slide = false
	wants_jump = false
	wants_dash = false
	requested_dash_direction = Vector3.ZERO


func _update_perception(delta: float) -> void:
	if sight_check_remaining > 0.0:
		if not has_line_of_sight:
			time_since_player_seen += delta
		return
	sight_check_remaining = sight_check_interval
	var previous_los := has_line_of_sight
	has_line_of_sight = _can_see_target()
	if has_line_of_sight:
		if not previous_los:
			aim_reaction_remaining = maxf(aim_reaction_delay, random.randf_range(reaction_time_min, reaction_time_max))
		last_known_player_position = target.global_position
		time_since_player_seen = 0.0
		if observation_refresh_remaining <= 0.0:
			_refresh_observation()
	else:
		if previous_los:
			player_disappeared_direction = target.global_position - last_known_player_position
		time_since_player_seen += sight_check_interval


func _can_see_target() -> bool:
	if not is_instance_valid(target):
		return false
	var origin := get_aim_origin()
	var destination := target.global_position + Vector3.UP * 1.12
	var visibility_variant: Variant = target.get("visibility_factor")
	if visibility_variant is float and float(visibility_variant) < 0.5 and global_position.distance_to(target.global_position) > 4.0:
		return false
	for smoke_node: Node in get_tree().get_nodes_in_group("smoke_veil"):
		if smoke_node.has_method("blocks_segment") and bool(smoke_node.blocks_segment(origin, destination)):
			return false
	var query := PhysicsRayQueryParameters3D.create(origin, destination, 1, get_aim_exclusions())
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _refresh_observation() -> void:
	observation_refresh_remaining = random.randf_range(reaction_time_min, reaction_time_max)
	if not has_line_of_sight or not is_instance_valid(target):
		return
	observed_player_position = target.global_position
	var target_velocity_variant: Variant = target.get("velocity")
	if target_velocity_variant is Vector3:
		var lead_time := lerpf(0.02, 0.13, accuracy)
		observed_player_position += (target_velocity_variant as Vector3) * lead_time
	last_known_player_position = target.global_position
	_update_desired_aim()


func _update_desired_aim() -> void:
	var distance := global_position.distance_to(observed_player_position)
	var base_error := aim_error_close
	if distance >= 22.0:
		base_error = aim_error_long
	elif distance >= 9.0:
		base_error = aim_error_medium
	var movement_penalty := 1.0 + movement.horizontal_speed() / maxf(movement.sprint_speed, 0.1) * 0.28
	if not is_on_floor():
		movement_penalty += 0.18
	var accuracy_scale := lerpf(1.38, 0.62, accuracy)
	var error_size := base_error * movement_penalty * accuracy_scale
	var aim_height := 1.10
	if random.randf() < 0.10 * accuracy:
		aim_height = 1.45
	var error := Vector3(
		random.randf_range(-error_size, error_size),
		random.randf_range(-error_size * 0.52, error_size * 0.52),
		random.randf_range(-error_size, error_size)
	)
	desired_aim_direction = (observed_player_position + Vector3.UP * aim_height + error - get_aim_origin()).normalized()


func _update_aim(delta: float) -> void:
	if not has_line_of_sight and time_since_player_seen <= memory_duration:
		desired_aim_direction = (last_known_player_position + Vector3.UP * 1.05 - get_aim_origin()).normalized()
	var smoothing := aim_smoothing * lerpf(0.72, 1.18, accuracy)
	aim_direction = aim_direction.slerp(desired_aim_direction, clampf(delta * smoothing, 0.0, 1.0)).normalized()
	var horizontal_aim := Vector3(aim_direction.x, 0.0, aim_direction.z)
	if horizontal_aim.length_squared() > 0.01:
		look_at(global_position + horizontal_aim, Vector3.UP)
	var flat_length := Vector2(aim_direction.x, aim_direction.z).length()
	aim_pivot.rotation.x = -atan2(aim_direction.y, flat_length)


func _evaluate_state() -> void:
	var distance := global_position.distance_to(target.global_position)
	var health_ratio := health.current_health / maxf(health.max_health, 1.0)
	if health.current_health <= retreat_health_threshold:
		if ai_state != STATE_RETREAT:
			_set_state(STATE_RETREAT, random.randf_range(1.2, 2.2))
		elif state_time > 2.4 and random.randf() < risk_tolerance * 0.18:
			_set_state(STATE_REPOSITION, random.randf_range(0.8, 1.25))
		return
	if ai_state == STATE_STUCK and state_lock_remaining > 0.0:
		return
	if not has_line_of_sight:
		if time_since_player_seen <= memory_duration:
			if global_position.distance_to(last_known_player_position) >= flank_distance_threshold and random.randf() < flank_probability * aggression:
				_set_state(STATE_FLANK, random.randf_range(1.4, 2.6))
			else:
				_set_state(STATE_SEARCH, random.randf_range(0.7, 1.3))
		else:
			_set_state(STATE_SEARCH, random.randf_range(0.8, 1.7))
		return
	if recent_damage_timer > 0.0 and health_ratio < 0.65 and state_lock_remaining <= 0.0:
		_set_state(STATE_REPOSITION, random.randf_range(0.8, 1.45))
		return
	var vertical_difference := target.global_position.y - global_position.y
	if vertical_difference > 2.5 and state_lock_remaining <= 0.0:
		_set_state(STATE_FLANK, random.randf_range(1.6, 2.8))
		tactical_target = _select_vertical_route()
		return
	_choose_weapon_for_distance(distance)
	if state_lock_remaining > 0.0:
		return
	if distance <= melee_range:
		_set_state(STATE_MELEE, random.randf_range(0.8, 1.45))
	elif distance >= sniper_range:
		var flank_chance := flank_probability * (0.6 + aggression * 0.4)
		if distance >= flank_distance_threshold and random.randf() < flank_chance:
			_set_state(STATE_FLANK, random.randf_range(1.4, 2.5))
		elif sniper_shots_from_position >= sniper_relocate_after:
			_set_state(STATE_REPOSITION, random.randf_range(1.1, 2.0))
		else:
			_set_state(STATE_RANGED, random.randf_range(0.8, 1.6))
	else:
		var commit_to_melee := aggression * (0.55 + health_ratio * 0.25)
		if random.randf() < commit_to_melee:
			_set_state(STATE_APPROACH, random.randf_range(0.8, 1.5))
		else:
			_set_state(STATE_REPOSITION, random.randf_range(0.8, 1.5))


func _choose_weapon_for_distance(distance: float) -> void:
	if weapon_switch_remaining > 0.0:
		return
	var desired_index := current_weapon_index
	if distance <= melee_range:
		desired_index = 0
	elif distance >= sniper_range:
		desired_index = 1
	elif current_weapon_index == 1 and distance < melee_range + 1.4 and aggression > 0.5:
		desired_index = 0
	elif current_weapon_index == 0 and distance > sniper_range - 1.4 and risk_tolerance < 0.8:
		desired_index = 1
	if desired_index != current_weapon_index:
		equip_weapon(desired_index)
		weapon_switch_remaining = weapon_switch_cooldown
		action_remaining = maxf(action_remaining, 0.25)


func _set_state(new_state: StringName, lock_duration: float = 0.0) -> void:
	if ai_state == new_state:
		state_lock_remaining = maxf(state_lock_remaining, lock_duration * 0.35)
		return
	ai_state = new_state
	state_time = 0.0
	state_lock_remaining = lock_duration
	if current_weapon is SniperWeapon and new_state != STATE_RANGED:
		(current_weapon as SniperWeapon).secondary_released()
	match new_state:
		STATE_FLANK:
			tactical_target = _select_flank_point()
			_plan_traversal_mobility(true)
		STATE_RETREAT:
			tactical_target = _select_cover_point(true)
			_plan_escape_dash()
		STATE_REPOSITION:
			tactical_target = _select_cover_point(false)
			_plan_traversal_mobility(false)
		STATE_RECOVER:
			tactical_target = _select_cover_point(true)
			crouch_remaining = random.randf_range(0.45, 1.0)
		STATE_STUCK:
			_begin_stuck_recovery()
		STATE_RANGED:
			action_remaining = maxf(action_remaining, random.randf_range(sniper_aim_time_min, sniper_aim_time_max))
			if sniper_shots_from_position == 0:
				sniper_relocate_after = random.randi_range(sniper_relocate_shots_min, sniper_relocate_shots_max)
		STATE_MELEE:
			_plan_engage_dash()


func _execute_current_state() -> void:
	match ai_state:
		STATE_SEARCH:
			_execute_search()
		STATE_APPROACH:
			_execute_approach()
		STATE_RANGED:
			_execute_ranged_combat()
		STATE_MELEE:
			_execute_melee_combat()
		STATE_FLANK:
			_execute_flank()
		STATE_RETREAT:
			_execute_retreat()
		STATE_REPOSITION:
			_execute_reposition()
		STATE_RECOVER:
			_execute_recover()
		STATE_STUCK:
			_execute_stuck_recovery()
		_:
			_execute_search()


func _execute_search() -> void:
	var destination := search_target
	if time_since_player_seen <= memory_duration:
		destination = last_known_player_position + player_disappeared_direction * 0.35
	if _flat_distance_to(destination) < 1.5:
		_choose_search_target()
		destination = search_target
	move_direction = _flat_direction_to(destination)
	wants_sprint = time_since_player_seen <= memory_duration


func _execute_approach() -> void:
	var toward := _flat_direction_to(last_known_player_position)
	var strafe := Vector3(-toward.z, 0.0, toward.x) * strafe_sign
	move_direction = (toward * 0.88 + strafe * 0.28).normalized()
	wants_sprint = true
	if absf(target.global_position.y - global_position.y) > 1.15 and is_on_floor() and random.randf() < 0.035:
		wants_jump = true


func _execute_ranged_combat() -> void:
	if current_weapon_index != 1:
		_execute_approach()
		return
	var toward := _flat_direction_to(last_known_player_position)
	var distance := global_position.distance_to(last_known_player_position)
	var strafe := Vector3(-toward.z, 0.0, toward.x) * strafe_sign
	var range_correction := Vector3.ZERO
	if distance < sniper_range - 2.0:
		range_correction = -toward * 0.72
	elif distance > sniper_range + 12.0:
		range_correction = toward * 0.32
	move_direction = (strafe * 0.88 + range_correction).normalized()
	if crouch_remaining > 0.0:
		wants_crouch = true
	_try_sniper_action(distance)


func _try_sniper_action(distance: float) -> void:
	var sniper := current_weapon as SniperWeapon
	if sniper == null:
		return
	if sniper.ammo <= 0:
		sniper.request_reload()
		_set_state(STATE_RECOVER, random.randf_range(1.0, 1.8))
		return
	if sniper.is_reloading:
		return
	if not has_line_of_sight:
		sniper.secondary_released()
		return
	if not sniper.is_ads:
		sniper.secondary_pressed()
	if aim_reaction_remaining > 0.0 or action_remaining > 0.0:
		return
	if sniper.fire_cooldown_remaining > 0.0:
		return
	var true_direction := (target.global_position + Vector3.UP * 1.08 - get_aim_origin()).normalized()
	var aim_requirement := 0.955 if distance >= 24.0 else 0.925
	aim_requirement = lerpf(aim_requirement - 0.018, aim_requirement + 0.014, 1.0 - accuracy)
	if aim_direction.dot(true_direction) >= aim_requirement:
		sniper.request_primary()
		action_remaining = random.randf_range(sniper_aim_time_min, sniper_aim_time_max)


func _execute_melee_combat() -> void:
	if current_weapon_index != 0:
		return
	var toward := _flat_direction_to(last_known_player_position)
	var distance := global_position.distance_to(last_known_player_position)
	var strafe := Vector3(-toward.z, 0.0, toward.x) * strafe_sign
	if distance > melee_attack_range * 0.88:
		move_direction = (toward * 0.84 + strafe * 0.46).normalized()
		wants_sprint = distance > 4.0
	else:
		var retreat_weight := 0.42 if action_remaining > 0.0 else -0.05
		move_direction = (strafe - toward * retreat_weight).normalized()
	if action_remaining <= 0.0 and block_remaining <= 0.0 and distance <= melee_attack_range:
		var katana := current_weapon as KatanaWeapon
		if random.randf() < block_probability * (0.65 + risk_tolerance * 0.35):
			katana.secondary_pressed()
			block_remaining = random.randf_range(0.17, 0.25) if random.randf() < perfect_deflect_probability else random.randf_range(0.38, 0.78)
			action_remaining = block_remaining + random.randf_range(0.08, 0.28)
		elif random.randf() < heavy_attack_probability:
			katana.request_heavy()
			action_remaining = random.randf_range(0.82, 1.12)
		else:
			katana.request_primary()
			action_remaining = random.randf_range(0.38, 0.62)


func _execute_flank() -> void:
	move_direction = _flat_direction_to(tactical_target)
	wants_sprint = true
	if _flat_distance_to(tactical_target) < 1.8 or state_time > 3.2:
		sniper_shots_from_position = 0
		_set_state(STATE_RANGED if has_line_of_sight else STATE_SEARCH, 0.6)


func _execute_retreat() -> void:
	var away := -_flat_direction_to(last_known_player_position)
	var cover_direction := _flat_direction_to(tactical_target)
	move_direction = (cover_direction * 0.78 + away * 0.5).normalized()
	wants_sprint = true
	if _flat_distance_to(tactical_target) < 1.5:
		wants_crouch = true
		if current_weapon_index == 1:
			var sniper := current_weapon as SniperWeapon
			if sniper.ammo < sniper.magazine_size:
				sniper.request_reload()
		elif current_weapon is KatanaWeapon and block_remaining <= 0.0:
			current_weapon.secondary_pressed()
			block_remaining = random.randf_range(0.35, 0.85)


func _execute_reposition() -> void:
	move_direction = _flat_direction_to(tactical_target)
	wants_sprint = true
	if _flat_distance_to(tactical_target) < 1.6 or state_time > 2.8:
		sniper_shots_from_position = 0
		_set_state(STATE_RANGED if has_line_of_sight else STATE_SEARCH, 0.55)


func _execute_recover() -> void:
	var distance_to_cover := _flat_distance_to(tactical_target)
	if distance_to_cover > 1.4:
		move_direction = _flat_direction_to(tactical_target)
		wants_sprint = true
	else:
		move_direction = Vector3.ZERO
		wants_crouch = true
	if current_weapon is SniperWeapon:
		var sniper := current_weapon as SniperWeapon
		if not sniper.is_reloading and sniper.ammo < sniper.magazine_size:
			sniper.request_reload()
		if not sniper.is_reloading and sniper.ammo > 0 and state_time > 0.45:
			_set_state(STATE_RANGED if has_line_of_sight else STATE_SEARCH, 0.45)


func _execute_stuck_recovery() -> void:
	move_direction = recovery_direction
	wants_sprint = true
	if state_time < 0.16 and is_on_floor():
		wants_jump = true
	if state_lock_remaining <= 0.0:
		tactical_target = _select_flank_point()
		_set_state(STATE_REPOSITION, 0.8)


func _handle_defense() -> void:
	if current_weapon is KatanaWeapon:
		var katana := current_weapon as KatanaWeapon
		if block_remaining <= 0.0:
			katana.secondary_released()
		elif not katana.is_blocking:
			katana.secondary_pressed()


func _handle_mobility_opportunity() -> void:
	if pending_dodge_remaining > 0.0 and dash_skill.cooldown_remaining <= 0.0:
		wants_dash = true
		requested_dash_direction = pending_dodge_direction
		pending_dodge_remaining = 0.0
	if pending_slide_remaining > 0.0:
		wants_slide = true
		wants_sprint = true
		if movement.is_sliding:
			wants_crouch = true
	if bhop_chain_remaining > 0 and bhop_jump_guard <= 0.0 and is_on_floor() and not movement.is_sliding:
		wants_jump = true
		bhop_jump_guard = 0.22
		bhop_chain_remaining -= 1
		debug_bhop_count += 1


func _consider_incidental_movement() -> void:
	if mobility_decision_remaining > 0.0 or not is_on_floor() or movement.is_sliding:
		return
	if ai_state in [STATE_APPROACH, STATE_MELEE, STATE_RANGED] and random.randf() < jump_probability * mobility:
		wants_jump = true
		mobility_decision_remaining = random.randf_range(1.2, 2.3)
	elif ai_state == STATE_RANGED and crouch_remaining <= 0.0 and random.randf() < 0.12 * mobility:
		crouch_remaining = random.randf_range(0.35, 0.75)
		mobility_decision_remaining = random.randf_range(0.9, 1.7)


func _plan_traversal_mobility(high_commitment: bool) -> void:
	if mobility_decision_remaining > 0.0:
		return
	mobility_decision_remaining = random.randf_range(1.5, 2.8)
	var distance := _flat_distance_to(tactical_target)
	if distance > 10.0 and random.randf() < bhop_probability * mobility:
		bhop_chain_remaining = random.randi_range(bhop_chain_min, bhop_chain_max)
	elif random.randf() < slide_probability * mobility:
		pending_slide_remaining = 0.9
	elif random.randf() < dash_engage_probability * mobility * (1.0 if high_commitment else 0.28):
		wants_dash = true
		requested_dash_direction = _flat_direction_to(tactical_target)


func _plan_engage_dash() -> void:
	if mobility_decision_remaining <= 0.0 and random.randf() < dash_engage_probability * mobility:
		wants_dash = true
		requested_dash_direction = _flat_direction_to(last_known_player_position)
		mobility_decision_remaining = random.randf_range(1.4, 2.4)


func _plan_escape_dash() -> void:
	if random.randf() < dash_escape_probability * mobility:
		wants_dash = true
		requested_dash_direction = _flat_direction_to(tactical_target)
		mobility_decision_remaining = random.randf_range(1.6, 2.8)


func _run_movement(delta: float) -> void:
	var previous_position := global_position
	movement.physics_step(
		delta,
		move_direction,
		wants_sprint,
		wants_crouch,
		wants_slide,
		wants_jump,
		wants_dash,
		requested_dash_direction,
		stagger_remaining
	)
	_update_stuck_detection(delta, global_position.distance_to(previous_position))


func _update_stuck_detection(delta: float, displacement: float) -> void:
	var trying_to_move := move_direction.length_squared() > 0.10 and is_on_floor()
	var exempt := movement.is_sliding or dash_skill.is_active() or ai_state == STATE_STUCK or stagger_remaining > 0.0
	if trying_to_move and not exempt and displacement < stuck_min_displacement:
		stuck_timer += delta
	else:
		stuck_timer = maxf(0.0, stuck_timer - delta * 2.5)
	if stuck_timer >= stuck_detection_time:
		_set_state(STATE_STUCK, random.randf_range(0.75, 1.05))


func _begin_stuck_recovery() -> void:
	stuck_timer = 0.0
	stuck_recovery_count += 1
	var reverse := -move_direction
	if reverse.length_squared() < 0.01:
		reverse = global_basis.z
	var side := Vector3(-reverse.z, 0.0, reverse.x) * (-1.0 if random.randf() < 0.5 else 1.0)
	recovery_direction = (reverse * 0.72 + side * 0.9).normalized()
	tactical_target = global_position + recovery_direction * random.randf_range(4.0, 7.0)
	if dash_skill.cooldown_remaining <= 0.0 and random.randf() < 0.35 * mobility:
		wants_dash = true
		requested_dash_direction = recovery_direction


func _update_strafe(delta: float) -> void:
	strafe_change_remaining -= delta
	if strafe_change_remaining <= 0.0:
		strafe_change_remaining = random.randf_range(0.65, 1.65)
		if random.randf() < 0.72:
			strafe_sign *= -1.0


func _select_cover_point(prefer_hidden: bool) -> Vector3:
	var points := get_tree().get_nodes_in_group("bot_cover_point")
	var best_point := global_position - _flat_direction_to(last_known_player_position) * 7.0
	var best_score := INF
	for point_node: Node in points:
		var point := point_node as Node3D
		if point == null:
			continue
		var candidate := point.global_position
		var travel_distance := _flat_distance_to(candidate)
		if travel_distance < 2.0 or travel_distance > 25.0:
			continue
		if absf(candidate.y - global_position.y) > 2.2:
			continue
		var hidden := _is_position_hidden(candidate, last_known_player_position)
		var score := travel_distance
		if hidden:
			score -= 8.0 if prefer_hidden else 3.0
		elif prefer_hidden:
			score += 10.0
		if candidate.distance_to(last_cover_position) < 2.5:
			score += 7.0
		if score < best_score:
			best_score = score
			best_point = candidate
	last_cover_position = best_point
	return best_point


func _select_flank_point() -> Vector3:
	var points := get_tree().get_nodes_in_group("bot_flank_point")
	var toward := _flat_direction_to(last_known_player_position)
	var side := Vector3(-toward.z, 0.0, toward.x) * strafe_sign
	var best_point := global_position + side * 10.0 + toward * 4.0
	var best_score := INF
	for point_node: Node in points:
		var point := point_node as Node3D
		if point == null:
			continue
		var candidate := point.global_position
		var travel_distance := _flat_distance_to(candidate)
		if travel_distance < 3.0 or travel_distance > 32.0:
			continue
		if absf(candidate.y - global_position.y) > 2.2:
			continue
		var route_direction := _flat_direction_to(candidate)
		var side_value := absf(route_direction.dot(side))
		var score := travel_distance - side_value * 7.0
		if _is_position_hidden(candidate, last_known_player_position):
			score -= 2.5
		if score < best_score:
			best_score = score
			best_point = candidate
	return best_point


func _select_vertical_route() -> Vector3:
	var points := get_tree().get_nodes_in_group("bot_vertical_route")
	var best_point := global_position + _flat_direction_to(last_known_player_position) * 6.0
	var best_distance := INF
	for point_node: Node in points:
		var point := point_node as Node3D
		if point == null:
			continue
		var travel_distance := _flat_distance_to(point.global_position)
		if travel_distance < best_distance:
			best_distance = travel_distance
			best_point = point.global_position
	return best_point


func _is_position_hidden(candidate: Vector3, threat_position: Vector3) -> bool:
	var origin := candidate + Vector3.UP * 1.05
	var destination := threat_position + Vector3.UP * 1.1
	var query := PhysicsRayQueryParameters3D.create(origin, destination, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _choose_search_target() -> void:
	var angle := random.randf_range(-PI, PI)
	var distance := random.randf_range(6.0, 15.0)
	search_target = global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
	search_target.x = clampf(search_target.x, -25.0, 25.0)
	search_target.z = clampf(search_target.z, -25.0, 25.0)


func _flat_direction_to(destination: Vector3) -> Vector3:
	var direction := destination - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO


func _flat_distance_to(destination: Vector3) -> float:
	return Vector2(destination.x - global_position.x, destination.z - global_position.z).length()


func equip_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or (index == current_weapon_index and current_weapon != null):
		return
	if current_weapon != null:
		current_weapon.unequip()
	current_weapon_index = index
	current_weapon = weapons[index]
	current_weapon.equip()


func get_aim_origin() -> Vector3:
	return global_position + Vector3.UP * (movement.current_height * 0.80)


func get_melee_origin() -> Vector3:
	return global_position + Vector3.UP * (movement.current_height * 0.62)


func get_aim_direction() -> Vector3:
	return aim_direction.normalized()


func get_aim_exclusions() -> Array[RID]:
	return [get_rid(), head_hurtbox.get_rid()]


func is_headshot_position(hit_position: Vector3) -> bool:
	return hit_position.y - global_position.y >= movement.get_head_threshold_y()


func modify_incoming_damage(info: DamageInfo) -> Dictionary:
	if current_weapon is KatanaWeapon:
		return (current_weapon as KatanaWeapon).get_damage_response(info)
	return {}


func receive_damage(info: DamageInfo) -> Dictionary:
	return health.apply_damage(info)


func get_total_armor() -> float:
	return 0.0


func on_damage_response(response_type: StringName, _info: DamageInfo, _applied: float) -> void:
	if response_type == &"deflect":
		feedback.emit(&"deflect", {})
	elif response_type == &"block":
		feedback.emit(&"block", {})


func apply_knockback(force: Vector3) -> void:
	velocity += force


func apply_stagger(duration: float) -> void:
	stagger_remaining = maxf(stagger_remaining, duration)
	action_remaining = maxf(action_remaining, duration)


func apply_launch(launch_velocity: Vector3) -> void:
	movement.apply_external_launch(launch_velocity)


func force_kill() -> void:
	health.kill(null, &"fall")


func on_sniper_fired(_ads: bool) -> void:
	debug_sniper_shots += 1
	sniper_shots_from_position += 1
	action_remaining = random.randf_range(sniper_aim_time_min, sniper_aim_time_max)
	if sniper_shots_from_position >= sniper_relocate_after:
		state_lock_remaining = 0.0


func on_melee_swing(_heavy: bool) -> void:
	debug_melee_swings += 1


func on_block_started() -> void:
	debug_block_count += 1


func on_reload_started() -> void:
	debug_reload_count += 1
	if ai_state != STATE_RETREAT:
		_set_state(STATE_RECOVER, random.randf_range(1.0, 1.7))


func on_empty_weapon() -> void:
	if current_weapon is SniperWeapon:
		(current_weapon as SniperWeapon).request_reload()


func get_debug_snapshot() -> Dictionary:
	return {
		"state": ai_state,
		"weapon": current_weapon.weapon_display_name if current_weapon != null else "None",
		"los": has_line_of_sight,
		"memory": maxf(0.0, memory_duration - time_since_player_seen),
		"stuck": stuck_timer,
		"recoveries": stuck_recovery_count,
		"movement": movement.movement_state,
		"speed": movement.horizontal_speed(),
		"shots": debug_sniper_shots,
		"swings": debug_melee_swings,
		"reloads": debug_reload_count,
		"blocks": debug_block_count,
	}


func _on_damage_resolved(_info: DamageInfo, applied_amount: float, _response: Dictionary) -> void:
	if applied_amount <= 0.0:
		return
	recent_damage_timer = 1.4
	if ai_state != STATE_RETREAT and dash_skill.cooldown_remaining <= 0.0 and random.randf() < dash_dodge_probability * mobility:
		var away := -_flat_direction_to(last_known_player_position)
		var side := Vector3(-away.z, 0.0, away.x) * (-1.0 if random.randf() < 0.5 else 1.0)
		pending_dodge_direction = (away * 0.45 + side).normalized()
		pending_dodge_remaining = 0.45
	if health.current_health <= retreat_health_threshold:
		state_lock_remaining = 0.0
		_set_state(STATE_RETREAT, random.randf_range(1.2, 2.1))


func _on_movement_event(event_name: StringName) -> void:
	match event_name:
		&"jump":
			debug_jump_count += 1
		&"dash":
			debug_dash_count += 1
		&"slide":
			debug_slide_count += 1
		&"launch":
			feedback.emit(&"launch", {})


func _on_health_died(info: DamageInfo) -> void:
	is_dead = true
	ai_state = &"DEAD"
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	body_collision.disabled = true
	head_hurtbox.set_deferred("monitorable", false)
	visual_body.visible = false
	weapon_mount.visible = false
	if current_weapon != null:
		current_weapon.secondary_released()
	actor_died.emit(self, info)


func respawn() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	is_dead = false
	stagger_remaining = 0.0
	block_remaining = 0.0
	action_remaining = 0.0
	weapon_switch_remaining = 0.0
	crouch_remaining = 0.0
	recent_damage_timer = 0.0
	mobility_decision_remaining = 0.0
	stuck_timer = 0.0
	time_since_player_seen = 999.0
	has_line_of_sight = false
	sight_check_remaining = 0.0
	observation_refresh_remaining = 0.0
	state_lock_remaining = 0.0
	state_time = 0.0
	sniper_shots_from_position = 0
	bhop_chain_remaining = 0
	bhop_jump_guard = 0.0
	pending_slide_remaining = 0.0
	pending_dodge_remaining = 0.0
	pending_dodge_direction = Vector3.ZERO
	move_direction = Vector3.ZERO
	player_disappeared_direction = Vector3.ZERO
	($StatusEffects as StatusEffectComponent).effects.clear()
	collision_layer = 2
	collision_mask = 1
	body_collision.disabled = false
	head_hurtbox.set_deferred("monitorable", true)
	visual_body.visible = true
	weapon_mount.visible = true
	movement.reset_state()
	for weapon in weapons:
		weapon.reset_weapon()
	health.reset()
	equip_weapon(1)
	aim_direction = -global_basis.z
	desired_aim_direction = aim_direction
	_choose_search_target()
	ai_state = &"RESPAWN"
	decision_remaining = random.randf_range(reaction_time_min, reaction_time_max)
	aim_reaction_remaining = maxf(aim_reaction_delay, decision_remaining)
