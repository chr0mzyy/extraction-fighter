class_name SkillBase
extends Node

signal state_changed

@export var skill_id: StringName
@export var skill_display_name: String = "Skill"
@export var power_cost: int = 0
@export var cooldown: float = 1.0

var cooldown_remaining: float = 0.0
var equipped: bool = false
var slot_index: int = -1


func setup(_actor: CharacterBody3D, definition: ItemDefinition, assigned_slot: int) -> void:
	slot_index = assigned_slot
	if definition != null:
		skill_id = definition.id
		skill_display_name = definition.display_name
		power_cost = definition.power_cost
	equipped = true
	state_changed.emit()

func tick(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)


func physics_tick(_actor: CharacterBody3D, _delta: float) -> void:
	pass


func request_activate(_actor: CharacterBody3D) -> bool:
	return false


func request_release(_actor: CharacterBody3D) -> void:
	pass


func can_activate() -> bool:
	return equipped and cooldown_remaining <= 0.0


func get_input_hint() -> String:
	return "Q" if slot_index == 0 else "E"


func get_status_text() -> String:
	return "READY" if cooldown_remaining <= 0.0 else "%.1fs" % cooldown_remaining


func reset() -> void:
	cooldown_remaining = 0.0
	state_changed.emit()
