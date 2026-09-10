class_name StatusEffectComponent
extends Node

signal status_applied(status_id: StringName)

var effects: Dictionary = {}


func _physics_process(delta: float) -> void:
	var expired: Array[StringName] = []
	for key: Variant in effects.keys():
		var status_id := StringName(String(key))
		var data: Dictionary = effects[key]
		data["remaining"] = float(data.get("remaining", 0.0)) - delta
		data["tick"] = float(data.get("tick", 0.0)) - delta
		if status_id in [&"burning", &"poisoned", &"bleeding"] and float(data.tick) <= 0.0:
			_apply_dot(status_id, data)
			data["tick"] = 0.5
		effects[key] = data
		if float(data.remaining) <= 0.0:
			expired.append(status_id)
	for status_id: StringName in expired:
		effects.erase(status_id)


func apply_status(status_id: StringName, duration: float, strength: float, source: Node) -> void:
	var previous: Dictionary = effects.get(status_id, {})
	effects[status_id] = {
		"remaining": maxf(duration, float(previous.get("remaining", 0.0))),
		"strength": maxf(strength, float(previous.get("strength", 0.0))),
		"source": source,
		"tick": minf(0.2, float(previous.get("tick", 0.2))),
	}
	status_applied.emit(status_id)


func has_status(status_id: StringName) -> bool:
	return effects.has(status_id)


func get_handling_multiplier() -> float:
	var frost: Dictionary = effects.get(&"frost", {})
	return clampf(1.0 - float(frost.get("strength", 0.0)) / 100.0, 0.7, 1.0)


func get_healing_multiplier() -> float:
	var void_effect: Dictionary = effects.get(&"void", {})
	return clampf(1.0 - float(void_effect.get("strength", 0.0)) / 100.0, 0.55, 1.0)


func get_elemental_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for status_id: StringName in [&"burning", &"frost", &"poisoned", &"bleeding", &"void"]:
		if effects.has(status_id):
			result[status_id] = (effects[status_id] as Dictionary).duplicate()
	return result


func clear() -> void:
	effects.clear()


func _apply_dot(status_id: StringName, data: Dictionary) -> void:
	var actor := get_parent()
	if actor == null or not actor.has_method("receive_damage"):
		return
	var strength := float(data.get("strength", 0.0))
	var amount := 0.8 + strength * 0.035
	if status_id == &"burning":
		amount = 1.2 + strength * 0.045
	elif status_id == &"bleeding":
		var velocity_variant: Variant = actor.get("velocity")
		var speed := (velocity_variant as Vector3).length() if velocity_variant is Vector3 else 0.0
		amount *= 1.0 + clampf(speed / 12.0, 0.0, 1.0)
	var info := DamageInfo.new(amount, data.get("source") as Node, status_id, false, false, (actor as Node3D).global_position, Vector3.ZERO, false, true)
	var result: Dictionary = actor.receive_damage(info)
	if bool(result.get("killed", false)) and is_instance_valid(info.attacker) and info.attacker.has_method("on_affix_dot_kill"):
		info.attacker.on_affix_dot_kill(actor, self)
