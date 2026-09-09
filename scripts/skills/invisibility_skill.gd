class_name InvisibilitySkill
extends SkillBase

@export var duration: float = 4.0

var active_remaining: float = 0.0
var active_actor: CharacterBody3D


func _init() -> void:
	skill_id = &"invisibility"
	skill_display_name = "Invisibility"
	power_cost = 120
	cooldown = 20.0


func tick(delta: float) -> void:
	super.tick(delta)
	if active_remaining <= 0.0:
		return
	active_remaining = maxf(0.0, active_remaining - delta)
	if active_remaining <= 0.0:
		_end_effect()


func request_activate(actor: CharacterBody3D) -> bool:
	if not can_activate() or not is_instance_valid(actor):
		return false
	active_actor = actor
	active_remaining = duration
	cooldown_remaining = cooldown
	actor.set_invisibility(true)
	state_changed.emit()
	return true


func on_owner_attack(_actor: CharacterBody3D) -> void:
	if active_remaining > 0.0:
		active_remaining = 0.0
		_end_effect()


func _end_effect() -> void:
	if is_instance_valid(active_actor):
		active_actor.set_invisibility(false)
	active_actor = null
	state_changed.emit()


func get_status_text() -> String:
	return "HIDDEN %.1fs" % active_remaining if active_remaining > 0.0 else super.get_status_text()


func reset() -> void:
	_end_effect()
	super.reset()
	active_remaining = 0.0
