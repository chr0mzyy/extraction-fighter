class_name BotMovementController
extends Node

signal movement_event(event_name: StringName)

@export_group("Locomotion")
@export var walk_speed: float = 6.0
@export var sprint_speed: float = 9.5
@export var crouch_speed: float = 3.8
@export var ground_acceleration: float = 24.0
@export var ground_deceleration: float = 21.0
@export var air_acceleration: float = 10.0
@export var air_speed_cap: float = 10.5
@export var gravity: float = 18.0
@export var jump_velocity: float = 6.5

@export_group("Crouch And Slide")
@export var standing_height: float = 1.8
@export var crouching_height: float = 1.08
@export var crouch_transition_speed: float = 9.0
@export var slide_min_speed: float = 7.4
@export var slide_friction: float = 2.5
@export var slide_duration_cap: float = 1.4
@export var slide_steer_strength: float = 2.1

var actor: CharacterBody3D
var body_collision: CollisionShape3D
var visual_body: MeshInstance3D
var head_hurtbox: Area3D
var aim_pivot: Node3D
var dash_skill: DashSkill

var movement_state: StringName = &"AIRBORNE"
var is_crouching: bool = false
var is_sliding: bool = false
var slide_time: float = 0.0
var slide_direction: Vector3 = Vector3.ZERO
var current_height: float = 1.8
var _base_visual_height: float = 0.9
var _base_head_height: float = 1.34
var _base_aim_height: float = 1.42


func setup(
	owner_actor: CharacterBody3D,
	collision: CollisionShape3D,
	visual: MeshInstance3D,
	head: Area3D,
	pivot: Node3D,
	dash: DashSkill
) -> void:
	actor = owner_actor
	body_collision = collision
	visual_body = visual
	head_hurtbox = head
	aim_pivot = pivot
	dash_skill = dash
	if body_collision != null and body_collision.shape is CapsuleShape3D:
		standing_height = (body_collision.shape as CapsuleShape3D).height
	current_height = standing_height
	if visual_body != null:
		_base_visual_height = visual_body.position.y
	if head_hurtbox != null:
		_base_head_height = head_hurtbox.position.y
	if aim_pivot != null:
		_base_aim_height = aim_pivot.position.y


func physics_step(
	delta: float,
	desired_direction: Vector3,
	wants_sprint: bool,
	wants_crouch: bool,
	wants_slide: bool,
	wants_jump: bool,
	wants_dash: bool,
	dash_direction: Vector3,
	stagger_remaining: float
) -> void:
	if actor == null:
		return

	dash_skill.tick(delta)
	var grounded := actor.is_on_floor()
	var horizontal_velocity := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
	var wish_direction := desired_direction
	wish_direction.y = 0.0
	if wish_direction.length_squared() > 0.001:
		wish_direction = wish_direction.normalized()

	if wants_dash and not dash_skill.is_active():
		var resolved_dash := dash_direction
		resolved_dash.y = 0.0
		if resolved_dash.length_squared() < 0.001:
			resolved_dash = wish_direction if wish_direction.length_squared() > 0.001 else -actor.global_basis.z
		if dash_skill.try_activate(resolved_dash.normalized()):
			movement_event.emit(&"dash")

	if wants_slide and grounded and not is_sliding and horizontal_velocity.length() >= slide_min_speed:
		_start_slide(horizontal_velocity)

	if wants_jump and grounded:
		actor.velocity.y = jump_velocity
		grounded = false
		if is_sliding:
			_end_slide()
		movement_event.emit(&"jump")

	if dash_skill.is_active():
		var dash_velocity := dash_skill.dash_direction * dash_skill.dash_speed
		actor.velocity.x = dash_velocity.x
		actor.velocity.z = dash_velocity.z
		movement_state = &"DASH"
	elif stagger_remaining > 0.0:
		actor.velocity.x = move_toward(actor.velocity.x, 0.0, ground_deceleration * 0.55 * delta)
		actor.velocity.z = move_toward(actor.velocity.z, 0.0, ground_deceleration * 0.55 * delta)
		movement_state = &"STAGGERED"
	elif is_sliding:
		_update_slide(delta, wish_direction, wants_crouch or wants_slide)
	else:
		_update_regular_movement(delta, wish_direction, wants_sprint, wants_crouch, grounded)

	if not grounded:
		actor.velocity.y -= gravity * delta
	elif actor.velocity.y < 0.0:
		actor.velocity.y = -0.5

	_update_stance(delta, wants_crouch or is_sliding)
	actor.move_and_slide()


func reset_state() -> void:
	is_crouching = false
	is_sliding = false
	slide_time = 0.0
	slide_direction = Vector3.ZERO
	current_height = standing_height
	movement_state = &"AIRBORNE"
	if dash_skill != null:
		dash_skill.reset()
	_apply_stance(standing_height)


func apply_external_launch(launch_velocity: Vector3) -> void:
	if actor == null:
		return
	actor.velocity.x = lerpf(actor.velocity.x, launch_velocity.x, 0.65)
	actor.velocity.z = lerpf(actor.velocity.z, launch_velocity.z, 0.65)
	actor.velocity.y = maxf(actor.velocity.y, launch_velocity.y)
	if is_sliding:
		_end_slide()
	movement_state = &"LAUNCHED"
	movement_event.emit(&"launch")


func horizontal_speed() -> float:
	if actor == null:
		return 0.0
	return Vector2(actor.velocity.x, actor.velocity.z).length()


func get_head_threshold_y() -> float:
	return current_height * 0.78


func _update_regular_movement(
	delta: float,
	wish_direction: Vector3,
	wants_sprint: bool,
	wants_crouch: bool,
	grounded: bool
) -> void:
	is_crouching = wants_crouch
	var target_speed := walk_speed
	if wants_crouch:
		target_speed = crouch_speed
	elif wants_sprint:
		target_speed = sprint_speed

	var target_velocity := wish_direction * target_speed
	if grounded:
		var rate := ground_acceleration if wish_direction.length_squared() > 0.001 else ground_deceleration
		actor.velocity.x = move_toward(actor.velocity.x, target_velocity.x, rate * delta)
		actor.velocity.z = move_toward(actor.velocity.z, target_velocity.z, rate * delta)
		if wants_crouch:
			movement_state = &"CROUCH"
		elif wants_sprint and wish_direction.length_squared() > 0.001:
			movement_state = &"SPRINT"
		else:
			movement_state = &"RUN"
	else:
		if wish_direction.length_squared() > 0.001:
			var air_velocity := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
			air_velocity += wish_direction * air_acceleration * delta
			if air_velocity.length() > air_speed_cap:
				air_velocity = air_velocity.normalized() * air_speed_cap
			actor.velocity.x = air_velocity.x
			actor.velocity.z = air_velocity.z
		movement_state = &"AIRBORNE"


func _start_slide(horizontal_velocity: Vector3) -> void:
	is_sliding = true
	is_crouching = true
	slide_time = 0.0
	slide_direction = horizontal_velocity.normalized()
	movement_state = &"SLIDE"
	movement_event.emit(&"slide")


func _update_slide(delta: float, wish_direction: Vector3, wants_crouch: bool) -> void:
	slide_time += delta
	var speed := horizontal_speed()
	if wish_direction.length_squared() > 0.001:
		slide_direction = slide_direction.slerp(wish_direction, clampf(slide_steer_strength * delta, 0.0, 1.0)).normalized()
	speed = move_toward(speed, 0.0, slide_friction * delta)
	actor.velocity.x = slide_direction.x * speed
	actor.velocity.z = slide_direction.z * speed
	movement_state = &"SLIDE"
	if speed < walk_speed * 0.78 or slide_time >= slide_duration_cap or not wants_crouch:
		_end_slide()


func _end_slide() -> void:
	is_sliding = false
	slide_time = 0.0


func _update_stance(delta: float, wants_low_stance: bool) -> void:
	var target_height := crouching_height if wants_low_stance else standing_height
	current_height = move_toward(current_height, target_height, crouch_transition_speed * delta)
	_apply_stance(current_height)


func _apply_stance(height: float) -> void:
	if body_collision != null and body_collision.shape is CapsuleShape3D:
		var capsule := body_collision.shape as CapsuleShape3D
		capsule.height = height
		body_collision.position.y = height * 0.5
	var height_ratio := height / maxf(standing_height, 0.01)
	if visual_body != null:
		visual_body.position.y = _base_visual_height * height_ratio
		visual_body.scale.y = height_ratio
	if head_hurtbox != null:
		head_hurtbox.position.y = _base_head_height * height_ratio
	if aim_pivot != null:
		aim_pivot.position.y = _base_aim_height * height_ratio
