class_name WallrunSkill
extends SkillBase

@export var active_duration: float = 2.4
@export var wall_check_distance: float = 1.05
@export var wallrun_speed: float = 11.5
@export var vertical_hold_speed: float = 1.4

var active_remaining: float = 0.0
var wall_lost_remaining: float = 0.0


func _init() -> void:
	skill_id = &"wallrun"
	skill_display_name = "Wallrun"
	power_cost = 70
	cooldown = 7.0


func tick(delta: float) -> void:
	super.tick(delta)
	active_remaining = maxf(0.0, active_remaining - delta)


func request_activate(actor: CharacterBody3D) -> bool:
	if not can_activate() or not is_instance_valid(actor):
		return false
	active_remaining = active_duration
	wall_lost_remaining = 0.18
	cooldown_remaining = cooldown
	actor.emit_skill_feedback(&"wallrun", {})
	state_changed.emit()
	return true


func physics_tick(actor: CharacterBody3D, delta: float) -> void:
	if active_remaining <= 0.0 or actor.is_on_floor():
		return
	var wall_normal := _find_wall_normal(actor)
	if wall_normal == Vector3.ZERO:
		wall_lost_remaining -= delta
		if wall_lost_remaining <= 0.0:
			active_remaining = 0.0
			state_changed.emit()
		return
	wall_lost_remaining = 0.18
	var along_wall := wall_normal.cross(Vector3.UP).normalized()
	var desired: Vector3 = actor.get_skill_move_direction()
	if along_wall.dot(desired) < 0.0:
		along_wall = -along_wall
	if Input.is_action_just_pressed("jump"):
		actor.velocity = along_wall * maxf(Vector3(actor.velocity.x, 0.0, actor.velocity.z).length(), wallrun_speed * 0.7) + wall_normal * 5.8 + Vector3.UP * 7.0
		active_remaining = 0.0
		actor.emit_skill_feedback(&"wallrun_jump", {})
		state_changed.emit()
		return
	var horizontal := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
	var target_speed := maxf(horizontal.length(), wallrun_speed)
	horizontal = horizontal.lerp(along_wall * target_speed, clampf(delta * 8.0, 0.0, 1.0))
	actor.velocity.x = horizontal.x
	actor.velocity.z = horizontal.z
	actor.velocity.y = maxf(actor.velocity.y, vertical_hold_speed)


func _find_wall_normal(actor: CharacterBody3D) -> Vector3:
	var origin := actor.global_position + Vector3.UP
	for direction: Vector3 in [actor.global_basis.x, -actor.global_basis.x]:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * wall_check_distance, 1, actor.get_aim_exclusions())
		var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var normal: Vector3 = hit.get("normal", Vector3.ZERO)
			if absf(normal.dot(Vector3.UP)) < 0.25:
				return normal
	return Vector3.ZERO


func get_status_text() -> String:
	return "ACTIVE" if active_remaining > 0.0 else super.get_status_text()


func reset() -> void:
	super.reset()
	active_remaining = 0.0
	wall_lost_remaining = 0.0
