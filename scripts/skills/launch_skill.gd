class_name LaunchSkill
extends SkillBase

@export var upward_speed: float = 13.5
@export var forward_speed: float = 7.0


func _init() -> void:
	skill_id = &"launch"
	skill_display_name = "Launch"
	power_cost = 85
	cooldown = 10.0


func request_activate(actor: CharacterBody3D) -> bool:
	if not can_activate() or not is_instance_valid(actor):
		return false
	var direction: Vector3 = actor.get_skill_move_direction()
	actor.apply_launch(direction * forward_speed + Vector3.UP * upward_speed)
	cooldown_remaining = cooldown
	actor.emit_skill_feedback(&"skill_launch", {})
	state_changed.emit()
	return true
