class_name PlayerMovementController
extends Node

signal movement_event(event_name: StringName)

## Original Kour-style arena controller: constant run speed, CS acceleration,
## bunny hops, air strafing and momentum-preserving slide hops.
@export_group("Kour Run")
@export var run_speed := 10.5
@export var ground_acceleration := 85.0
@export var ground_friction := 7.0
@export var stop_speed := 6.0
@export_group("Kour Jump")
@export var jump_velocity := 7.4
@export var gravity := 20.0
@export var auto_bunny_hop := true
@export var jump_buffer_time := 0.11
@export var coyote_time := 0.09
@export var landing_friction_delay := 0.055
@export_group("Kour Air Strafe")
@export var air_acceleration := 24.0
@export var air_wish_speed := 10.5
@export var air_camera_follow := 11.5
@export var bunny_hop_speed_cap := 22.0
@export var bunny_hop_speed_gain := 0.8
@export_range(0.0, 1.0) var reverse_air_acceleration := 0.28
@export_group("Kour Crouch And Slide")
@export var crouch_speed := 5.2
@export var crouch_height := 1.15
@export var crouch_transition_speed := 7.5
@export var slide_min_speed := 7.2
@export var slide_entry_boost := 1.25
@export var slide_friction := 2.1
@export var slide_steering := 2.0
@export var slide_duration := 1.15
@export var slide_reentry_delay := 0.16
@export_group("Skill Integration")
@export var dash_momentum_speed_cap := 30.0

var walk_speed: float:
	get: return run_speed
var sprint_speed: float:
	get: return run_speed
var bhop_speed_cap: float:
	get: return bunny_hop_speed_cap

var actor: CharacterBody3D
var body_collision: CollisionShape3D
var body_shape: CapsuleShape3D
var visual_body: MeshInstance3D
var pitch_pivot: Node3D
var head_hurtbox: Area3D
var dash_skill: DashSkill
var double_jump_skill: DoubleJumpSkill
var standing_height := 1.8
var standing_camera_height := 1.58
var current_collision_height := 1.8
var jump_buffer_remaining := 0.0
var coyote_remaining := 0.0
var landing_friction_remaining := 0.0
var slide_elapsed := 0.0
var slide_reentry_remaining := 0.0
var is_crouching := false
var is_sliding := false
var air_control_active := false
var movement_state := "GROUND"
var was_on_floor := false
var normal_jump_available := true
var jump_was_held := false
var dash_horizontal_velocity := Vector3.ZERO
var previous_actor_yaw := 0.0
var bhop_chain_count := 0
var air_strafe_qualified := false
var bhop_landing_qualified := false
var bhop_airborne_sequence := false


func setup(p_actor: CharacterBody3D, p_body_collision: CollisionShape3D, p_visual_body: MeshInstance3D, p_pitch_pivot: Node3D, p_head_hurtbox: Area3D, p_dash_skill: DashSkill, p_double_jump_skill: DoubleJumpSkill) -> void:
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
	previous_actor_yaw = actor.rotation.y


func physics_step(delta: float, stagger_remaining: float = 0.0) -> void:
	if actor == null: return
	jump_buffer_remaining = maxf(0.0, jump_buffer_remaining - delta)
	landing_friction_remaining = maxf(0.0, landing_friction_remaining - delta)
	slide_reentry_remaining = maxf(0.0, slide_reentry_remaining - delta)
	var grounded := actor.is_on_floor() and (normal_jump_available or actor.velocity.y <= 0.0)
	var yaw_delta := wrapf(actor.rotation.y - previous_actor_yaw, -PI, PI)
	previous_actor_yaw = actor.rotation.y
	if grounded:
		coyote_remaining = coyote_time
		normal_jump_available = true
	elif was_on_floor and normal_jump_available:
		coyote_remaining = coyote_time
	else:
		coyote_remaining = maxf(0.0, coyote_remaining - delta)

	var jump_held := Input.is_action_pressed("jump")
	var jump_pressed := jump_held and not jump_was_held
	jump_was_held = jump_held
	if jump_pressed or (auto_bunny_hop and jump_held): jump_buffer_remaining = jump_buffer_time
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := actor.global_basis.x * input.x + actor.global_basis.z * input.y
	wish.y = 0.0
	wish = wish.normalized()
	air_control_active = false

	# Shift/C are the Kour bindings; the previous Ctrl binding remains accepted.
	var crouch_held := Input.is_action_pressed("crouch") or Input.is_action_pressed("sprint")
	var crouch_pressed := Input.is_action_just_pressed("crouch") or Input.is_action_just_pressed("sprint")
	if crouch_pressed and grounded and not is_sliding and slide_reentry_remaining <= 0.0 and get_horizontal_speed() >= slide_min_speed:
		_start_slide()

	var jumped := false
	if jump_buffer_remaining > 0.0:
		if normal_jump_available and (grounded or coyote_remaining > 0.0):
			_perform_ground_jump(is_sliding)
			jumped = true
			grounded = false
		elif jump_pressed and not grounded and double_jump_skill != null and not _is_near_landing() and double_jump_skill.try_activate():
			actor.velocity.y = double_jump_skill.jump_velocity * _multiplier(&"get_jump_multiplier")
			jump_buffer_remaining = 0.0
			normal_jump_available = false
			coyote_remaining = 0.0
			movement_event.emit(&"double_jump")
			bhop_airborne_sequence = false
			air_strafe_qualified = false
			jumped = true

	_update_stance(delta, crouch_held or is_sliding)
	if dash_skill != null and dash_skill.is_active():
		_set_horizontal(dash_horizontal_velocity)
		movement_state = "DASH"
	elif is_sliding and grounded:
		_update_slide(delta, wish, crouch_held)
	elif grounded and not jumped:
		_update_ground(delta, wish, crouch_held, stagger_remaining)
	else:
		_update_air(delta, input.x, yaw_delta, jump_held, stagger_remaining)
	if not grounded: actor.velocity.y -= gravity * delta
	elif actor.velocity.y < 0.0: actor.velocity.y = -0.2
	actor.move_and_slide()
	var landed := actor.is_on_floor()
	if landed and not grounded:
		_on_landed()
		if jump_buffer_remaining > 0.0 and normal_jump_available: _perform_ground_jump(is_sliding)
	if is_sliding and not landed: _end_slide()
	was_on_floor = landed and (normal_jump_available or actor.velocity.y <= 0.0)


func _update_ground(delta: float, wish: Vector3, crouched: bool, stagger: float) -> void:
	# Remaining on the ground or releasing Space breaks the speed-building chain.
	if not Input.is_action_pressed("jump") or landing_friction_remaining <= 0.0:
		_reset_bhop_chain()
	var speed := (crouch_speed if crouched else run_speed) * _multiplier(&"get_movement_speed_multiplier")
	if stagger > 0.0: speed *= 0.25
	if landing_friction_remaining <= 0.0: _apply_friction(delta)
	if wish.length_squared() > 0.001:
		_accelerate(wish, speed, ground_acceleration, delta)
		if landing_friction_remaining <= 0.0: _limit_speed(speed)
	movement_state = "CROUCH" if crouched else ("SPRINT" if wish.length_squared() > 0.001 else "GROUND")


func _update_air(delta: float, strafe_input: float, yaw_delta: float, jump_held: bool, stagger: float) -> void:
	# W/S never change airborne velocity. A/D only engage when Space is held and
	# mouse yaw turns in the matching direction: mouse-left+A, mouse-right+D.
	var synchronized_strafe := jump_held and absf(strafe_input) > 0.1 and absf(yaw_delta) > 0.00001 and strafe_input * yaw_delta < 0.0
	air_control_active = synchronized_strafe
	if synchronized_strafe:
		air_strafe_qualified = true
		var previous := get_horizontal_speed()
		var handling := _multiplier(&"get_air_control_multiplier")
		var side_direction := actor.global_basis.x * signf(strafe_input)
		side_direction.y = 0.0
		side_direction = side_direction.normalized()
		var wish_speed := air_wish_speed * _multiplier(&"get_movement_speed_multiplier")
		if stagger > 0.0: wish_speed *= 0.35
		_accelerate(side_direction, wish_speed, air_acceleration * handling, delta)
		var camera_forward := -actor.global_basis.z
		camera_forward.y = 0.0
		_apply_air_turn(camera_forward.normalized(), handling, delta)
		_limit_speed(maxf(bunny_hop_speed_cap, previous))
	movement_state = "AIR_CONTROL" if air_control_active else "AIRBORNE"


func _accelerate(wish: Vector3, wish_speed: float, acceleration: float, delta: float) -> void:
	var horizontal := get_horizontal_velocity()
	var add := wish_speed - horizontal.dot(wish)
	if add > 0.0: _set_horizontal(horizontal + wish * minf(add, acceleration * delta))


func _apply_friction(delta: float) -> void:
	var horizontal := get_horizontal_velocity()
	var speed := horizontal.length()
	if speed <= 0.001:
		_set_horizontal(Vector3.ZERO)
		return
	var next := maxf(0.0, speed - maxf(speed, stop_speed) * ground_friction * delta)
	_set_horizontal(horizontal * (next / speed))


func _apply_air_turn(wish: Vector3, handling: float, delta: float) -> void:
	var horizontal := get_horizontal_velocity()
	var speed := horizontal.length()
	if speed <= 0.01: return
	var direction := horizontal / speed
	var alignment := direction.dot(wish)
	# The actor yaw follows the FPS camera. While movement input is held, rotate the
	# velocity toward that camera-relative wish direction and preserve its magnitude.
	var response := air_camera_follow * handling
	if alignment < 0.0:
		response *= reverse_air_acceleration
	var turn := 1.0 - exp(-response * delta)
	_set_horizontal(direction.slerp(wish, clampf(turn, 0.0, 1.0)).normalized() * speed)


func _limit_speed(limit: float) -> void:
	var horizontal := get_horizontal_velocity()
	if horizontal.length() > limit and horizontal.length() > 0.01: _set_horizontal(horizontal.normalized() * limit)


func _start_slide() -> void:
	is_sliding = true
	slide_elapsed = 0.0
	var horizontal := get_horizontal_velocity()
	var direction := horizontal.normalized() if horizontal.length_squared() > 0.001 else -actor.global_basis.z
	_set_horizontal(direction * minf(maxf(bunny_hop_speed_cap, horizontal.length()), horizontal.length() + slide_entry_boost))
	movement_event.emit(&"slide")


func _update_slide(delta: float, wish: Vector3, held: bool) -> void:
	slide_elapsed += delta
	var horizontal := get_horizontal_velocity()
	var speed := horizontal.length()
	if not held or speed < crouch_speed or slide_elapsed >= slide_duration:
		_end_slide()
		movement_state = "CROUCH" if held else "GROUND"
		return
	if wish.length_squared() > 0.001 and speed > 0.01:
		horizontal = horizontal.normalized().slerp(wish, clampf(slide_steering * delta, 0.0, 1.0)).normalized() * speed
	var floor_normal := actor.get_floor_normal()
	if floor_normal.dot(Vector3.UP) < 0.995:
		var downhill := Vector3.DOWN.slide(floor_normal)
		horizontal += Vector3(downhill.x, 0.0, downhill.z) * gravity * delta * 0.45
		speed = horizontal.length()
	speed = maxf(0.0, speed - slide_friction / maxf(_multiplier(&"get_slide_affix_multiplier"), 0.1) * delta)
	_set_horizontal(horizontal.normalized() * speed if speed > 0.001 else Vector3.ZERO)
	movement_state = "SLIDE"


func _perform_ground_jump(from_slide: bool) -> void:
	if from_slide:
		var speed := get_horizontal_speed()
		_end_slide()
		if speed > 0.01: _set_horizontal(get_horizontal_velocity().normalized() * minf(speed * 1.035, maxf(bunny_hop_speed_cap, speed)))
		movement_event.emit(&"slide_jump")
	_apply_bhop_chain_boost()
	actor.velocity.y = jump_velocity * _multiplier(&"get_jump_multiplier")
	jump_buffer_remaining = 0.0
	coyote_remaining = 0.0
	normal_jump_available = false
	landing_friction_remaining = landing_friction_delay
	bhop_airborne_sequence = true
	air_strafe_qualified = false
	movement_event.emit(&"jump")


func _on_landed() -> void:
	bhop_landing_qualified = bhop_airborne_sequence and air_strafe_qualified
	bhop_airborne_sequence = false
	air_strafe_qualified = false
	landing_friction_remaining = landing_friction_delay
	coyote_remaining = coyote_time
	normal_jump_available = true
	if double_jump_skill != null: double_jump_skill.on_landed()
	movement_event.emit(&"landed")


func _apply_bhop_chain_boost() -> void:
	var valid_chain_hop := bhop_landing_qualified and jump_was_held
	bhop_landing_qualified = false
	if not valid_chain_hop:
		bhop_chain_count = 0
		return
	var horizontal := get_horizontal_velocity()
	var speed := horizontal.length()
	if speed < run_speed * 0.65:
		bhop_chain_count = 0
		return
	bhop_chain_count += 1
	var maximum := maxf(bunny_hop_speed_cap, speed)
	var boosted_speed := minf(speed + bunny_hop_speed_gain, maximum)
	if speed > 0.001:
		_set_horizontal(horizontal * (boosted_speed / speed))


func _reset_bhop_chain() -> void:
	bhop_chain_count = 0
	bhop_landing_qualified = false
	bhop_airborne_sequence = false
	air_strafe_qualified = false


func _update_stance(delta: float, wants_crouch: bool) -> void:
	var target := crouch_height if wants_crouch or not _can_stand() else standing_height
	current_collision_height = move_toward(current_collision_height, target, crouch_transition_speed * delta)
	body_shape.height = current_collision_height
	body_collision.position.y = current_collision_height * 0.5
	is_crouching = current_collision_height < standing_height - 0.02
	var low_camera := maxf(crouch_height - 0.18, crouch_height * 0.78)
	pitch_pivot.position.y = move_toward(pitch_pivot.position.y, low_camera if target < standing_height else standing_camera_height, crouch_transition_speed * delta)
	head_hurtbox.position.y = minf(pitch_pivot.position.y, current_collision_height - 0.18)
	visual_body.position.y = current_collision_height * 0.5
	visual_body.scale.y = current_collision_height / standing_height


func _can_stand() -> bool:
	if current_collision_height >= standing_height - 0.02: return true
	var shape := CapsuleShape3D.new()
	shape.radius = body_shape.radius
	shape.height = standing_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(actor.global_basis, actor.global_position + Vector3.UP * (standing_height * 0.5 + 0.025))
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.exclude = [actor.get_rid()]
	query.margin = 0.015
	return actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _is_near_landing() -> bool:
	if actor.velocity.y >= 0.0: return false
	var distance := maxf(0.18, -actor.velocity.y * jump_buffer_time + 0.08)
	var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 0.06, actor.global_position - Vector3.UP * distance, 1, [actor.get_rid()])
	return not actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func start_equipped_dash(skill: DashSkill) -> void:
	if skill == null or skill != dash_skill or not skill.is_active(): return
	var direction := skill.dash_direction.normalized()
	var incoming := get_horizontal_velocity()
	var added := maxf(skill.dash_speed - maxf(0.0, incoming.dot(direction)), skill.dash_speed * 0.65)
	dash_horizontal_velocity = incoming + direction * added
	if dash_horizontal_velocity.length() > dash_momentum_speed_cap: dash_horizontal_velocity = dash_horizontal_velocity.normalized() * dash_momentum_speed_cap
	if is_sliding: _end_slide()
	movement_event.emit(&"dash")


func _multiplier(method: StringName) -> float:
	return maxf(0.0, float(actor.call(method))) if actor.has_method(method) else 1.0
func _set_horizontal(value: Vector3) -> void:
	actor.velocity.x = value.x
	actor.velocity.z = value.z
func get_horizontal_velocity() -> Vector3:
	return Vector3(actor.velocity.x, 0.0, actor.velocity.z)
func get_horizontal_speed() -> float:
	return get_horizontal_velocity().length()
func _end_slide() -> void:
	if is_sliding: slide_reentry_remaining = slide_reentry_delay
	is_sliding = false
	slide_elapsed = 0.0
func on_external_launch() -> void:
	_end_slide(); _reset_bhop_chain(); was_on_floor = false; coyote_remaining = 0.0; normal_jump_available = false; movement_state = "LAUNCHED"
func on_death() -> void:
	_end_slide(); _reset_bhop_chain(); jump_buffer_remaining = 0.0; coyote_remaining = 0.0; air_control_active = false; movement_state = "DEAD"


func reset() -> void:
	_end_slide()
	_reset_bhop_chain()
	jump_buffer_remaining = 0.0
	coyote_remaining = 0.0
	landing_friction_remaining = 0.0
	slide_reentry_remaining = 0.0
	dash_horizontal_velocity = Vector3.ZERO
	is_crouching = false
	jump_was_held = Input.is_action_pressed("jump")
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
	previous_actor_yaw = actor.rotation.y
