class_name SmokeVeilSkill
extends SkillBase

@export var throw_distance: float = 6.0
@export var smoke_radius: float = 4.5
@export var smoke_duration: float = 6.0


func _init() -> void:
	skill_id = &"smoke_veil"
	skill_display_name = "Smoke Veil"
	power_cost = 70
	cooldown = 13.0


func request_activate(actor: CharacterBody3D) -> bool:
	if not can_activate() or not is_instance_valid(actor):
		return false
	var direction: Vector3 = actor.get_aim_direction()
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = -actor.global_basis.z
	var smoke := SmokeVeilArea.new()
	actor.get_tree().current_scene.add_child(smoke)
	smoke.setup(actor.global_position + direction.normalized() * throw_distance + Vector3.UP * 1.4, smoke_radius, smoke_duration)
	cooldown_remaining = cooldown
	actor.emit_skill_feedback(&"smoke_veil", {})
	state_changed.emit()
	return true
