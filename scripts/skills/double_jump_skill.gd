class_name DoubleJumpSkill
extends Node

@export var jump_velocity: float = 6.5
@export var cooldown: float = 4.0

var cooldown_remaining: float = 0.0
var used_this_airborne_sequence: bool = false


func tick(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)


func try_activate() -> bool:
	if used_this_airborne_sequence or cooldown_remaining > 0.0:
		return false
	used_this_airborne_sequence = true
	cooldown_remaining = cooldown
	return true


func on_landed() -> void:
	used_this_airborne_sequence = false


func reset() -> void:
	cooldown_remaining = 0.0
	used_this_airborne_sequence = false
