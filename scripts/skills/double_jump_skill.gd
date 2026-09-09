class_name DoubleJumpSkill
extends SkillBase

@export var jump_velocity: float = 6.5

var used_this_airborne_sequence: bool = false


func try_activate() -> bool:
	if used_this_airborne_sequence or cooldown_remaining > 0.0:
		return false
	used_this_airborne_sequence = true
	cooldown_remaining = cooldown
	return true


func on_landed() -> void:
	used_this_airborne_sequence = false


func reset() -> void:
	super.reset()
	used_this_airborne_sequence = false


func get_input_hint() -> String:
	return "SPACE x2"


func get_status_text() -> String:
	if cooldown_remaining > 0.0:
		return "%.1fs" % cooldown_remaining
	return "SPENT" if used_this_airborne_sequence else "READY"


func _init() -> void:
	skill_id = &"double_jump"
	skill_display_name = "Double Jump"
	power_cost = 70
	cooldown = 4.0
