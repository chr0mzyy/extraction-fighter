class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal damage_resolved(info: DamageInfo, applied_amount: float, response: Dictionary)
signal healed(amount: float)
signal died(info: DamageInfo)

@export var max_health: float = 100.0

var current_health: float = 100.0
var is_dead: bool = false
var last_attacker: Node


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func apply_damage(info: DamageInfo) -> Dictionary:
	if is_dead or info == null or info.amount <= 0.0:
		return {"applied": 0.0, "negated": true}

	var actor := get_parent()
	var response: Dictionary = {}
	if not info.bypass_defense and actor != null and actor.has_method("modify_incoming_damage"):
		response = actor.modify_incoming_damage(info)

	if bool(response.get("negate", false)):
		if actor != null and actor.has_method("on_damage_response"):
			actor.on_damage_response(&"deflect", info, 0.0)
		if bool(response.get("stagger_attacker", false)) and is_instance_valid(info.attacker):
			if info.attacker.has_method("apply_stagger"):
				info.attacker.apply_stagger(float(response.get("stagger_duration", 0.65)))
		if bool(response.get("reflect", false)) and info.can_reflect and is_instance_valid(info.attacker):
			if info.attacker.has_method("receive_damage"):
				info.attacker.receive_damage(info.make_reflection(actor))
		damage_resolved.emit(info, 0.0, response)
		return {"applied": 0.0, "negated": true, "deflected": true, "blocked": false}

	var multiplier := float(response.get("damage_multiplier", 1.0))
	var applied := maxf(0.0, info.amount * multiplier)
	current_health = maxf(0.0, current_health - applied)
	if is_instance_valid(info.attacker):
		last_attacker = info.attacker
	if actor != null and actor.has_method("on_damage_response"):
		actor.on_damage_response(&"block" if multiplier < 1.0 else &"hit", info, applied)
	if info.knockback.length_squared() > 0.0 and actor != null and actor.has_method("apply_knockback"):
		actor.apply_knockback(info.knockback * multiplier)
	health_changed.emit(current_health, max_health)
	damage_resolved.emit(info, applied, response)

	if current_health <= 0.0:
		is_dead = true
		died.emit(info)
	return {"applied": applied, "negated": false, "killed": is_dead, "blocked": multiplier < 0.999}


func heal(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var status := get_parent().get_node_or_null("StatusEffects") as StatusEffectComponent
	if status != null:
		amount *= status.get_healing_multiplier()
	var before := current_health
	current_health = minf(max_health, current_health + amount)
	var actual := current_health - before
	if actual > 0.0:
		healed.emit(actual)
		health_changed.emit(current_health, max_health)
	return actual


func kill(attacker: Node = null, damage_type: StringName = &"fall") -> void:
	if is_dead:
		return
	apply_damage(DamageInfo.new(max_health * 10.0, attacker, damage_type, false, false, Vector3.ZERO, Vector3.ZERO, false, true))


func reset() -> void:
	is_dead = false
	last_attacker = null
	current_health = max_health
	health_changed.emit(current_health, max_health)
