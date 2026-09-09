class_name GrappleSkill
extends SkillBase

@export var max_range: float = 34.0
@export var pull_speed: float = 21.0
@export var pull_acceleration: float = 38.0
@export var max_pull_duration: float = 1.35
@export var release_distance: float = 1.7

var grapple_point: Vector3 = Vector3.ZERO
var active_remaining: float = 0.0
var attached: bool = false


func _init() -> void:
	skill_id = &"grapple"
	skill_display_name = "Grapple"
	power_cost = 90
	cooldown = 9.0


func tick(delta: float) -> void:
	super.tick(delta)
	if attached:
		active_remaining = maxf(0.0, active_remaining - delta)
		if active_remaining <= 0.0:
			attached = false
			state_changed.emit()


func request_activate(actor: CharacterBody3D) -> bool:
	if not can_activate() or not is_instance_valid(actor) or not actor.has_method("get_aim_origin"):
		return false
	var origin: Vector3 = actor.get_aim_origin()
	var direction: Vector3 = actor.get_aim_direction().normalized()
	var exclusions: Array[RID] = actor.get_aim_exclusions() if actor.has_method("get_aim_exclusions") else []
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_range, 1, exclusions)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		if actor.has_method("emit_skill_feedback"):
			actor.emit_skill_feedback(&"grapple_miss", {})
		return false
	grapple_point = hit.get("position", origin)
	active_remaining = max_pull_duration
	attached = true
	cooldown_remaining = cooldown
	if actor.has_method("emit_skill_feedback"):
		actor.emit_skill_feedback(&"grapple", {"point": grapple_point})
	state_changed.emit()
	return true


func request_release(_actor: CharacterBody3D) -> void:
	if attached:
		attached = false
		active_remaining = 0.0
		state_changed.emit()


func physics_tick(actor: CharacterBody3D, delta: float) -> void:
	if not attached or not is_instance_valid(actor):
		return
	var shoulder := actor.global_position + Vector3.UP * 0.9
	var offset := grapple_point - shoulder
	if offset.length() <= release_distance:
		attached = false
		active_remaining = 0.0
		state_changed.emit()
		return
	var target_velocity := offset.normalized() * pull_speed
	actor.velocity = actor.velocity.move_toward(target_velocity, pull_acceleration * delta)


func get_status_text() -> String:
	return "PULLING" if attached else super.get_status_text()


func reset() -> void:
	super.reset()
	attached = false
	active_remaining = 0.0
	grapple_point = Vector3.ZERO
