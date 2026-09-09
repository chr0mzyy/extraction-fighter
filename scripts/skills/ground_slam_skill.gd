class_name GroundSlamSkill
extends SkillBase

@export var slam_speed: float = 28.0
@export var impact_radius: float = 4.0
@export var impact_damage: float = 36.0
@export var knockback_strength: float = 12.0

var slamming: bool = false


func _init() -> void:
	skill_id = &"ground_slam"
	skill_display_name = "Ground Slam"
	power_cost = 90
	cooldown = 11.0


func request_activate(actor: CharacterBody3D) -> bool:
	if not can_activate() or not is_instance_valid(actor) or actor.is_on_floor():
		return false
	slamming = true
	cooldown_remaining = cooldown
	actor.velocity.y = -slam_speed
	actor.emit_skill_feedback(&"ground_slam", {})
	state_changed.emit()
	return true


func physics_tick(actor: CharacterBody3D, _delta: float) -> void:
	if not slamming:
		return
	if actor.is_on_floor():
		slamming = false
		_impact(actor)
		state_changed.emit()
	else:
		actor.velocity.y = minf(actor.velocity.y, -slam_speed)


func _impact(actor: CharacterBody3D) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = impact_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, actor.global_position)
	query.collision_mask = 2
	query.exclude = actor.get_aim_exclusions()
	var hit_ids: Dictionary = {}
	for result: Dictionary in actor.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var target := result.get("collider") as Node3D
		if target == null or target == actor or not target.has_method("receive_damage") or hit_ids.has(target.get_instance_id()):
			continue
		hit_ids[target.get_instance_id()] = true
		var direction := target.global_position - actor.global_position
		direction.y = 0.35
		var info := DamageInfo.new(impact_damage, actor, &"ground_slam", false, false, target.global_position, direction.normalized() * knockback_strength)
		var response: Dictionary = target.receive_damage(info)
		if float(response.get("applied", 0.0)) > 0.0:
			actor.on_weapon_hit_confirmed(false)
	actor.emit_skill_feedback(&"ground_slam_impact", {})


func get_status_text() -> String:
	return "SLAMMING" if slamming else super.get_status_text()


func reset() -> void:
	super.reset()
	slamming = false
