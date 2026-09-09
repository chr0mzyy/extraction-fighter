class_name PlayerMovementController
extends Node

signal movement_event(event_name: StringName)

@export_group("Ground Movement")
@export var walk_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var ground_acceleration: float = 55.0
@export var ground_deceleration: float = 55.0
@export var ground_friction: float = 5.2
@export var landing_friction_delay: float = 0.1
@export var bhop_speed_cap: float = 16.0

@export_group("Jump")
@export var jump_velocity: float = 6.5
@export var gravity: float = 18.0
@export var jump_buffer_time: float = 0.12
@export var coyote_time: float = 0.1

@export_group("Air Movement")
@export var air_acceleration: float = 20.0
@export var air_control: float = 3.0
@export var air_speed_cap: float = 14.0
@export var air_drag: float = 0.0
@export_range(0.0, 1.0) var air_reverse_acceleration_scale: float = 0.35

@export_group("Crouch")
@export var crouch_speed: float = 4.0
@export var crouch_height: float = 1.15
@export var crouch_transition_speed: float = 4.5

@export_group("Slide")
@export var slide_min_speed: float = 8.0
@export var slide_initial_boost: float = 1.0
@export var slide_friction: float = 2.5
@export var slide_steering: float = 1.7
@export var slide_duration_cap: float = 1.4

@export_group("Dash Integration")
@export var dash_momentum_speed_cap: float = 30.0

var actor: CharacterBody3D
var body_collision: CollisionShape3D
var body_shape: CapsuleShape3D
var visual_body: MeshInstance3D
var pitch_pivot: Node3D
var head_hurtbox: Area3D
var dash_skill: DashSkill
var double_jump_skill: DoubleJumpSkill

var standing_height: float = 1.8
var standing_camera_height: float = 1.58
var current_collision_height: float = 1.8
var jump_buffer_remaining: float = 0.0
var coyote_remaining: float = 0.0
var landing_grace_remaining: float = 0.0
var slide_elapsed: float = 0.0
var is_crouching: bool = false
var is_sliding: bool = false
var air_control_active: bool = false
var movement_state: String = "GROUND"
var was_on_floor: bool = false
var normal_jump_available: bool = true
var dash_horizontal_velocity: Vector3 = Vector3.ZERO


func setup(
		p_actor: CharacterBody3D,
		p_body_collision: CollisionShape3D,
		p_visual_body: MeshInstance3D,
		p_pitch_pivot: Node3D,
		p_head_hurtbox: Area3D,
		p_dash_skill: DashSkill = null,
		p_double_jump_skill: DoubleJumpSkill = null
) -> void:
	actor = p_actor
	body_collision = p_body_collision
	body_shape = body_collision.shape as CapsuleShape3D
	visual_body = p_visual_body
	pitch_pivot = p_pitch_pivot
	head_hurtbox = p_head_hurtbox
	dash_skill = p_dash_skill
	double_jump_skill = p_double_jump_skill
	standing_height = body_shape.height
	current_collision_height = standing_height
	standing_camera_height = pitch_pivot.position.y
	was_on_floor = actor.is_on_floor()


func configure_skills(p_dash_skill: DashSkill, p_double_jump_skill: DoubleJumpSkill) -> void:
	dash_skill = p_dash_skill
	double_jump_skill = p_double_jump_skill


func physics_step(delta: float, stagger_remaining: float = 0.0) -> void:
	if actor == null:
		return
	jump_buffer_remaining = maxf(0.0, jump_buffer_remaining - delta)
	landing_grace_remaining = maxf(0.0, landing_grace_remaining - delta)

	var grounded := actor.is_on_floor()
	if grounded and actor.velocity.y <= 0.0:
		coyote_remaining = coyote_time
		normal_jump_available = true
	elif was_on_floor and normal_jump_available:
		coyote_remaining = coyote_time
	else:
		coyote_remaining = maxf(0.0, coyote_remaining - delta)

	var jump_pressed := Input.is_action_just_pressed("jump")
	if jump_pressed:
		jump_buffer_remaining = jump_buffer_time

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_direction := actor.global_basis.x * input_vector.x + actor.global_basis.z * input_vector.y
	wish_direction.y = 0.0
	wish_direction = wish_direction.normalized()
	air_control_active = not grounded and wish_direction.length_squared() > 0.01

	var crouch_held := Input.is_action_pressed("crouch")
	if Input.is_action_just_pressed("crouch") and grounded and get_horizontal_speed() >= slide_min_speed:
		_start_slide()

	var jumped := false
	if jump_buffer_remaining > 0.0:
		if normal_jump_available and (grounded or coyote_remaining > 0.0):
			_perform_ground_jump(is_sliding)
			jumped = true
			grounded = false
		elif jump_pressed and not grounded and not _is_near_landing() and double_jump_skill != null and double_jump_skill.try_activate():
			actor.velocity.y = double_jump_skill.jump_velocity
			jump_buffer_remaining = 0.0
			movement_event.emit(&"double_jump")
			jumped = true

	_update_stance(delta, crouch_held or is_sliding)

	if dash_skill != null and dash_skill.is_active():
		_set_horizontal_velocity(dash_horizontal_velocity)
		movement_state = "DASH"
	elif is_sliding and grounded:
		_update_slide(delta, wish_direction, crouch_held)
	elif grounded and not jumped:
		_update_ground_movement(delta, wish_direction, stagger_remaining)
	else:
		_update_air_movement(delta, wish_direction, stagger_remaining)

	if not grounded:
		actor.velocity.y -= gravity * delta
	elif actor.velocity.y < 0.0:
		actor.velocity.y = -0.2

	actor.move_and_slide()
	var grounded_after_move := actor.is_on_floor()
	if grounded_after_move and not was_on_floor:
		_on_landed()
		if jump_buffer_remaining > 0.0 and normal_jump_available:
			_perform_ground_jump(is_sliding)
	was_on_floor = actor.is_on_floor()


func _update_ground_movement(delta: float, wish_direction: Vector3, stagger_remaining: float) -> void:
	if landing_grace_remaining <= 0.0:
		_apply_ground_friction(delta, wish_direction.length_squared() < 0.01)
	var speed_before_acceleration := get_horizontal_speed()
	var speed := crouch_speed if is_crouching else (sprint_speed if Input.is_action_pressed("sprint") else walk_speed)
	if stagger_remaining > 0.0:
		speed *= 0.25
	if wish_direction.length_squared() > 0.01:
		_accelerate(wish_direction, speed, ground_acceleration, delta)
		_limit_horizontal_growth(bhop_speed_cap, speed_before_acceleration)
	movement_state = "CROUCH" if is_crouching else ("SPRINT" if Input.is_action_pressed("sprint") else "GROUND")


func _update_air_movement(delta: float, wish_direction: Vector3, stagger_remaining: float) -> void:
	var previous_speed := get_horizontal_speed()
	if wish_direction.length_squared() > 0.01:
		var wish_speed := minf(air_speed_cap, sprint_speed if Input.is_action_pressed("sprint") else walk_speed)
		if stagger_remaining > 0.0:
			wish_speed *= 0.35
		var horizontal := get_horizontal_velocity()
		var current_direction := horizontal.normalized() if horizontal.length_squared() > 0.01 else wish_direction
		var alignment := current_direction.dot(wish_direction)
		var acceleration_scale := air_reverse_acceleration_scale if alignment < 0.0 else 1.0
		_accelerate(wish_direction, wish_speed, air_acceleration * acceleration_scale, delta)
		_apply_air_control(wish_direction, delta)
		_limit_air_growth(previous_speed)
	if air_drag > 0.0:
		var retained_speed := maxf(0.0, get_horizontal_speed() - air_drag * delta)
		_set_horizontal_velocity(get_horizontal_velocity().normalized() * retained_speed)
	movement_state = "AIR_CONTROL" if air_control_active else "AIRBORNE"


func _accelerate(wish_direction: Vector3, wish_speed: float, acceleration_value: float, delta: float) -> void:
	var horizontal := get_horizontal_velocity()
	var speed_along_wish := horizontal.dot(wish_direction)
	var speed_to_add := wish_speed - speed_along_wish
	if speed_to_add <= 0.0:
		return
	var acceleration_step := minf(speed_to_add, acceleration_value * delta)
	_set_horizontal_velocity(horizontal + wish_direction * acceleration_step)


func _apply_air_control(wish_direction: Vector3, delta: float) -> void:
	var horizontal := get_horizontal_velocity()
	var speed := horizontal.length()
	if speed < 0.01:
		return
	var current_direction := horizontal / speed
	var alignment := current_direction.dot(wish_direction)
	if alignment <= 0.0:
		return
	var turn_amount := clampf(air_control * alignment * alignment * delta, 0.0, 1.0)
	var controlled_direction := current_direction.slerp(wish_direction, turn_amount).normalized()
	_set_horizontal_velocity(controlled_direction * speed)


func _apply_ground_friction(delta: float, no_input: bool) -> void:
	var horizontal := get_horizontal_velocity()
	var speed := horizontal.length()
	if speed <= 0.001:
		_set_horizontal_velocity(Vector3.ZERO)
		return
	var friction_drop := speed * ground_friction * delta
	if no_input:
		friction_drop = maxf(friction_drop, ground_deceleration * delta)
	var new_speed := maxf(0.0, speed - friction_drop)
	_set_horizontal_velocity(horizontal * (new_speed / speed))


func _start_slide() -> void:
	is_sliding = true
	slide_elapsed = 0.0
	var horizontal := get_horizontal_velocity()
	var direction := horizontal.normalized() if horizontal.length_squared() > 0.01 else -actor.global_basis.z
	var boosted_speed := minf(bhop_speed_cap, horizontal.length() + slide_initial_boost)
	_set_horizontal_velocity(direction * boosted_speed)
	movement_event.emit(&"slide")


func _update_slide(delta: float, wish_direction: Vector3, crouch_held: bool) -> void:
	slide_elapsed += delta
	var horizontal := get_horizontal_velocity()
	var speed := horizontal.length()
	if not crouch_held or speed < slide_min_speed * 0.55 or slide_elapsed >= slide_duration_cap:
		_end_slide()
		movement_state = "CROUCH" if crouch_held else "GROUND"
		return
	if wish_direction.length_squared() > 0.01 and speed > 0.01:
		var direction := horizontal.normalized().slerp(wish_direction, clampf(slide_steering * delta, 0.0, 1.0)).normalized()
		horizontal = direction * speed
	var floor_normal := actor.get_floor_normal()
	if floor_normal.dot(Vector3.UP) < 0.995:
		var downhill := Vector3.DOWN.slide(floor_normal)
		horizontal += Vector3(downhill.x, 0.0, downhill.z) * gravity * delta * 0.42
		speed = horizontal.length()
	speed = maxf(0.0, speed - slide_friction * delta)
	_set_horizontal_velocity(horizontal.normalized() * speed)
	movement_state = "SLIDE"


func _perform_ground_jump(from_slide: bool) -> void:
	if from_slide:
		_end_slide()
		var carried_speed := minf(get_horizontal_speed() * 1.02, bhop_speed_cap)
		if get_horizontal_speed() > 0.01:
			_set_horizontal_velocity(get_horizontal_velocity().normalized() * carried_speed)
		movement_event.emit(&"slide_jump")
	actor.velocity.y = jump_velocity
	jump_buffer_remaining = 0.0
	coyote_remaining = 0.0
	normal_jump_available = false
	landing_grace_remaining = landing_friction_delay


func _on_landed() -> void:
	landing_grace_remaining = landing_friction_delay
	coyote_remaining = coyote_time
	normal_jump_available = true
	if double_jump_skill != null:
		double_jump_skill.on_landed()
	movement_event.emit(&"landed")


func _prepare_dash_velocity(direction: Vector3) -> void:
	var incoming := get_horizontal_velocity()
	var forward_component := maxf(0.0, incoming.dot(direction))
	var added_speed := maxf(dash_skill.dash_speed - forward_component, dash_skill.dash_speed * 0.65)
	dash_horizontal_velocity = incoming + direction * added_speed
	if dash_horizontal_velocity.length() > dash_momentum_speed_cap:
		dash_horizontal_velocity = dash_horizontal_velocity.normalized() * dash_momentum_speed_cap
	if is_sliding:
		_end_slide()


func start_equipped_dash(skill: DashSkill) -> void:
	dash_skill = skill
	_prepare_dash_velocity(skill.dash_direction)
	movement_event.emit(&"dash")


func _update_stance(delta: float, wants_crouch: bool) -> void:
	var can_expand := wants_crouch or _can_stand()
	var target_height := crouch_height if wants_crouch or not can_expand else standing_height
	current_collision_height = move_toward(current_collision_height, target_height, crouch_transition_speed * delta)
	body_shape.height = current_collision_height
	body_collision.position.y = current_collision_height * 0.5
	is_crouching = current_collision_height < standing_height - 0.02
	var crouched_camera_height := maxf(crouch_height - 0.18, crouch_height * 0.78)
	var camera_target := crouched_camera_height if target_height < standing_height else standing_camera_height
	pitch_pivot.position.y = move_toward(pitch_pivot.position.y, camera_target, crouch_transition_speed * delta)
	head_hurtbox.position.y = minf(pitch_pivot.position.y, current_collision_height - 0.18)
	visual_body.position.y = current_collision_height * 0.5
	visual_body.scale.y = current_collision_height / standing_height


func _can_stand() -> bool:
	if current_collision_height >= standing_height - 0.02:
		return true
	var test_shape := CapsuleShape3D.new()
	test_shape.radius = body_shape.radius
	test_shape.height = standing_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = test_shape
	query.transform = Transform3D(actor.global_basis, actor.global_position + Vector3.UP * (standing_height * 0.5 + 0.025))
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [actor.get_rid()]
	query.margin = 0.015
	return actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _is_near_landing() -> bool:
	if actor.velocity.y >= 0.0:
		return false
	var check_distance := maxf(0.18, -actor.velocity.y * jump_buffer_time + 0.08)
	var query := PhysicsRayQueryParameters3D.create(
		actor.global_position + Vector3.UP * 0.06,
		actor.global_position - Vector3.UP * check_distance,
		1,
		[actor.get_rid()]
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return not actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _limit_air_growth(previous_speed: float) -> void:
	var current_speed := get_horizontal_speed()
	var allowed_speed := bhop_speed_cap
	if previous_speed > allowed_speed:
		allowed_speed = previous_speed
	if current_speed > allowed_speed and current_speed > 0.01:
		_set_horizontal_velocity(get_horizontal_velocity() * (allowed_speed / current_speed))


func _limit_horizontal_growth(cap: float, previous_speed: float) -> void:
	var speed := get_horizontal_speed()
	var allowed_speed := maxf(cap, previous_speed)
	if speed > allowed_speed and speed > 0.01:
		_set_horizontal_velocity(get_horizontal_velocity() * (allowed_speed / speed))


func _set_horizontal_velocity(horizontal: Vector3) -> void:
	actor.velocity.x = horizontal.x
	actor.velocity.z = horizontal.z


func get_horizontal_velocity() -> Vector3:
	return Vector3(actor.velocity.x, 0.0, actor.velocity.z)


func get_horizontal_speed() -> float:
	return get_horizontal_velocity().length()


func _end_slide() -> void:
	is_sliding = false
	slide_elapsed = 0.0


func on_external_launch() -> void:
	_end_slide()
	was_on_floor = false
	coyote_remaining = 0.0
	movement_state = "LAUNCHED"


func on_death() -> void:
	_end_slide()
	jump_buffer_remaining = 0.0
	coyote_remaining = 0.0
	air_control_active = false
	movement_state = "DEAD"


func reset() -> void:
	_end_slide()
	jump_buffer_remaining = 0.0
	coyote_remaining = 0.0
	landing_grace_remaining = 0.0
	air_control_active = false
	normal_jump_available = true
	was_on_floor = false
	movement_state = "GROUND"
	current_collision_height = standing_height
	body_shape.height = standing_height
	body_collision.position.y = standing_height * 0.5
	pitch_pivot.position.y = standing_camera_height
	head_hurtbox.position.y = standing_camera_height
	visual_body.position.y = standing_height * 0.5
	visual_body.scale = Vector3.ONE
