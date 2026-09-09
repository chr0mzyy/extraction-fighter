class_name DashSkill
extends SkillBase

@export var dash_speed: float = 24.0
@export var dash_duration: float = 0.2

var active_remaining: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO


func tick(delta: float) -> void:
	super.tick(delta)
	active_remaining = maxf(0.0, active_remaining - delta)


func request_activate(actor: CharacterBody3D) -> bool:
	if not is_instance_valid(actor) or not actor.has_method("get_skill_move_direction"):
		return false
	var direction: Vector3 = actor.get_skill_move_direction()
	if not try_activate(direction):
		return false
	if actor.has_method("start_equipped_dash"):
		actor.start_equipped_dash(self)
	return true


func try_activate(direction: Vector3) -> bool:
	if cooldown_remaining > 0.0 or active_remaining > 0.0:
		return false
	dash_direction = direction.normalized()
	if dash_direction.length_squared() < 0.01:
		dash_direction = Vector3.FORWARD
	active_remaining = dash_duration
	cooldown_remaining = cooldown
	return true


func is_active() -> bool:
	return active_remaining > 0.0


func reset() -> void:
	super.reset()
	active_remaining = 0.0
	dash_direction = Vector3.ZERO


func _init() -> void:
	skill_id = &"dash"
	skill_display_name = "Dash"
	power_cost = 60
	cooldown = 6.0
