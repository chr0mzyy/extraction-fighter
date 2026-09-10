class_name AffixRoller
extends RefCounted


static func roll_item(definition: ItemDefinition, seed_value: int, instance_id: String = "") -> ItemInstance:
	var resolved_id := instance_id if not instance_id.is_empty() else "roll:%s:%d" % [definition.id, seed_value]
	var instance := ItemInstance.create(definition, resolved_id)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var count_range := _count_range(definition.rarity)
	var count := random.randi_range(count_range.x, count_range.y)
	var compatible: Array[AffixDefinition] = []
	for affix: AffixDefinition in AffixDatabase.all():
		if affix.is_compatible(definition):
			compatible.append(affix)
	instance.affix_ids.clear()
	instance.affix_tiers.clear()
	while instance.affix_ids.size() < count and not compatible.is_empty():
		var selected_index := _pick_weighted_index(random, compatible)
		var selected := compatible[selected_index]
		compatible.remove_at(selected_index)
		instance.affix_ids.append(selected.id)
		instance.affix_tiers.append(_roll_tier(random, definition.rarity))
	return instance


static func _pick_weighted_index(random: RandomNumberGenerator, compatible: Array[AffixDefinition]) -> int:
	var total_weight := 0.0
	for affix: AffixDefinition in compatible:
		total_weight += 0.12 if affix.category == &"ultra" else 1.0
	var roll := random.randf() * total_weight
	for index: int in compatible.size():
		roll -= 0.12 if compatible[index].category == &"ultra" else 1.0
		if roll <= 0.0:
			return index
	return compatible.size() - 1


static func validate_instance(instance: ItemInstance, definition: ItemDefinition) -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for index: int in instance.affix_ids.size():
		var affix_id := instance.affix_ids[index]
		var affix := AffixDatabase.get_definition(affix_id)
		if affix == null:
			errors.append("Unknown affix: " + String(affix_id))
		elif seen.has(affix_id):
			errors.append("Duplicate affix: " + String(affix_id))
		elif not affix.is_compatible(definition):
			errors.append("Incompatible affix: " + String(affix_id))
		seen[affix_id] = true
		if index >= instance.affix_tiers.size() or instance.affix_tiers[index] < 1 or instance.affix_tiers[index] > 3:
			errors.append("Invalid affix tier: " + String(affix_id))
	return errors


static func _count_range(rarity: ItemDefinition.Rarity) -> Vector2i:
	match rarity:
		ItemDefinition.Rarity.COMMON, ItemDefinition.Rarity.UNCOMMON: return Vector2i(0, 1)
		ItemDefinition.Rarity.RARE: return Vector2i(1, 2)
		ItemDefinition.Rarity.EPIC, ItemDefinition.Rarity.LEGENDARY, ItemDefinition.Rarity.MYTHIC: return Vector2i(2, 3)
		ItemDefinition.Rarity.UNIQUE: return Vector2i(0, 1)
	return Vector2i.ZERO


static func _roll_tier(random: RandomNumberGenerator, rarity: ItemDefinition.Rarity) -> int:
	var roll := random.randf()
	var tier_three_chance := 0.08 + float(rarity) * 0.035
	var tier_two_chance := 0.34 + float(rarity) * 0.025
	if roll < tier_three_chance:
		return 3
	if roll < tier_three_chance + tier_two_chance:
		return 2
	return 1
