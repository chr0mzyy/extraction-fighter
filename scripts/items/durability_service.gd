class_name DurabilityService
extends RefCounted

const SHOT_WEAR := 0.20
const MELEE_HIT_WEAR := 0.35
const BLOCK_WEAR := 0.20
const PERFECT_BLOCK_WEAR := 0.10
const GEAR_DAMAGE_FACTOR := 0.012
const ACCESSORY_DAMAGE_FACTOR := 0.004
const DEATH_PENALTY_RATIO := 0.075


static func apply_weapon_use(instance: ItemInstance, amount: float) -> float:
	return instance.lose_durability(amount) if instance != null else 0.0


static func apply_equipped_gear_damage(profile: Node, incoming_damage: float) -> float:
	var total := 0.0
	for slot_key: String in profile.GEAR_KEYS:
		var instance: ItemInstance = profile.get_gear_instance(slot_key)
		var factor := GEAR_DAMAGE_FACTOR if slot_key in ["helmet", "chest", "gloves", "boots"] else ACCESSORY_DAMAGE_FACTOR
		if instance != null:
			total += instance.lose_durability(incoming_damage * factor)
	return total


static func apply_death_penalty(profile: Node) -> float:
	var total := 0.0
	var visited: Dictionary = {}
	for slot: int in profile.weapon_instance_slots.size():
		var weapon: ItemInstance = profile.get_weapon_instance(slot)
		if weapon != null and not visited.has(weapon.instance_id):
			visited[weapon.instance_id] = true
			total += weapon.lose_durability(weapon.max_durability * DEATH_PENALTY_RATIO)
	for slot_key: String in profile.GEAR_KEYS:
		var gear: ItemInstance = profile.get_gear_instance(slot_key)
		if gear != null and not visited.has(gear.instance_id):
			visited[gear.instance_id] = true
			total += gear.lose_durability(gear.max_durability * DEATH_PENALTY_RATIO)
	return total


static func repair_cost(instance: ItemInstance, definition: ItemDefinition) -> int:
	if instance == null or definition == null or instance.max_durability <= 0.0:
		return 0
	var missing := maxf(0.0, instance.max_durability - instance.current_durability)
	var rarity_multiplier: float = [0.7, 0.9, 1.15, 1.5, 2.0, 2.7, 3.2][clampi(definition.rarity, 0, 6)]
	return ceili(missing * rarity_multiplier)
