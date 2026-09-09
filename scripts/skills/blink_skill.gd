class_name BlinkSkill
extends SkillBase

@export var blink_distance: float = 6.5


func _init() -> void:
	skill_id = &"blink"
	skill_display_name = "Blink"
	power_cost = 110
	cooldown = 11.0


func request_activate(actor: CharacterBody3D) -> bool:
	if not can_activate() or not is_instance_valid(actor) or not actor.has_method("perform_collision_safe_blink"):
		return false
	if not bool(actor.perform_collision_safe_blink(blink_distance)):
		return false
	cooldown_remaining = cooldown
	if actor.has_method("emit_skill_feedback"):
		actor.emit_skill_feedback(&"blink", {})
	state_changed.emit()
	return true
