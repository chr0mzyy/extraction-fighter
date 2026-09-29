extends Node

signal event_emitted(event_name: StringName, world_position: Vector3, context: Dictionary)

const SUPPORTED_EVENTS: Array[StringName] = [
	&"footstep", &"jump", &"land", &"sprint", &"slide", &"dash", &"grapple",
	&"blink", &"gunshot", &"sniper_shot", &"ar_shot", &"burst_shot", &"battle_shot", &"pistol_shot", &"akimbo_shot", &"magic_shot",
	&"reload", &"empty", &"dry_fire", &"melee_swing", &"melee_hit", &"heavy_hit", &"block", &"parry", &"deflect",
	&"hit", &"headshot", &"critical", &"proc", &"kill", &"player_damage", &"enemy_damage", &"armor_hit", &"impact",
	&"pickup", &"key_pickup", &"chest", &"extraction_start", &"extraction_success", &"extraction_failure", &"boss_phase",
	&"ui_hover", &"ui_click", &"ui_back", &"ui_invalid",
]

var emitted_count: int = 0


func play(event_name: StringName, world_position: Vector3 = Vector3.ZERO, context: Dictionary = {}) -> void:
	if event_name not in SUPPORTED_EVENTS:
		return
	emitted_count += 1
	event_emitted.emit(event_name, world_position, context)
