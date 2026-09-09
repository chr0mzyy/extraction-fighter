class_name DashSkill
extends Node

@export var dash_speed: float = 24.0
@export var dash_duration: float = 0.2
@export var cooldown: float = 6.0

var cooldown_remaining: float = 0.0
var active_remaining: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO


func tick(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	active_remaining = maxf(0.0, active_remaining - delta)


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
	cooldown_remaining = 0.0
	active_remaining = 0.0
	dash_direction = Vector3.ZERO

