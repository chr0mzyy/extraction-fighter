extends Node

signal event_emitted(event_name: StringName, world_position: Vector3, context: Dictionary)

const SUPPORTED_EVENTS: Array[StringName] = [
	&"footstep", &"jump", &"land", &"sprint", &"slide", &"dash", &"grapple",
	&"gunshot", &"reload", &"empty", &"melee_swing", &"melee_hit", &"block",
	&"parry", &"hit", &"headshot", &"kill", &"pickup", &"chest", &"extraction", &"ui_click", &"boss_phase",
]

var emitted_count: int = 0


func play(event_name: StringName, world_position: Vector3 = Vector3.ZERO, context: Dictionary = {}) -> void:
	if event_name not in SUPPORTED_EVENTS:
		return
	emitted_count += 1
	event_emitted.emit(event_name, world_position, context)
