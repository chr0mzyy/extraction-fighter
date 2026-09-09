class_name AirDashSkill
extends SkillBase

@export var dash_speed: float = 23.0
@export var lift: float = 1.2


func _init() -> void:
	skill_id = &"air_dash"
	skill_display_name = "Air Dash"
	power_cost = 80
	cooldown = 8.0


func request_activate(actor: CharacterBody3D) -> bool:
	if not can_activate() or not is_instance_valid(actor) or actor.is_on_floor():
		return false
	var direction: Vector3 = actor.get_skill_move_direction()
	var existing := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
	var result := direction * dash_speed + existing * 0.3
	actor.velocity.x = result.x
	actor.velocity.z = result.z
	actor.velocity.y = maxf(actor.velocity.y, lift)
	cooldown_remaining = cooldown
	actor.emit_skill_feedback(&"air_dash", {})
	state_changed.emit()
	return true
