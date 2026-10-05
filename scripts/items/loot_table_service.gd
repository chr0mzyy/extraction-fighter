class_name LootTableService
extends RefCounted

const BASE_RARITY_WEIGHTS: Array[float] = [55.0, 25.0, 13.0, 5.0, 1.5, 0.5]
const SOURCE_RARITY_WEIGHTS := {
	"ordinary": [55.0, 25.0, 13.0, 5.0, 1.5, 0.5],
	"wooden": [62.0, 24.0, 9.5, 3.2, 1.0, 0.3],
	"reinforced": [42.0, 28.0, 18.0, 8.0, 3.0, 1.0],
	"elite": [25.0, 28.0, 25.0, 14.0, 6.0, 2.0],
	"vault": [20.0, 25.0, 27.0, 17.0, 8.0, 3.0],
	"boss": [0.0, 0.0, 55.0, 25.0, 15.0, 5.0],
	"secure_vault": [0.0, 0.0, 45.0, 30.0, 18.0, 7.0],
}
const CATEGORY_WEIGHTS := {
	ItemDefinition.ItemType.WEAPON: 42.0,
	ItemDefinition.ItemType.GEAR: 34.0,
	ItemDefinition.ItemType.CONSUMABLE: 14.0,
	ItemDefinition.ItemType.JUNK: 10.0,
}
const ROOM_CATEGORY_BIAS := {
	"arsenal": {ItemDefinition.ItemType.WEAPON: 2.0},
	"forge": {ItemDefinition.ItemType.WEAPON: 1.45, ItemDefinition.ItemType.GEAR: 1.35},
	"barracks": {ItemDefinition.ItemType.GEAR: 1.7},
	"quarters": {ItemDefinition.ItemType.CONSUMABLE: 1.8},
	"chapel": {ItemDefinition.ItemType.CONSUMABLE: 1.8, ItemDefinition.ItemType.GEAR: 1.25},
	"vault": {ItemDefinition.ItemType.GEAR: 1.8, ItemDefinition.ItemType.WEAPON: 1.35},
	"watch": {ItemDefinition.ItemType.WEAPON: 1.45},
}
# Unique items never enter the ordinary rarity pool. Add future source-exclusive
# definition IDs here; the Extraction Key is placed by its dedicated run rule.
const UNIQUE_SOURCE_ITEMS := {"extraction_key": ["key_chest"]}


static func roll_instance(rng: RandomNumberGenerator, source_type: String = "ordinary", room_type: String = "", enemy_tier: int = 0, depth: int = 0, instance_id: String = "") -> ItemInstance:
	var rarity := roll_rarity(rng, source_type, enemy_tier, depth)
	var candidates := _candidates_for_rarity(rarity)
	if candidates.is_empty():
		return null
	var definition := _pick_category_weighted(rng, candidates, room_type)
	if definition == null:
		return null
	var resolved_id := instance_id if not instance_id.is_empty() else "loot:%d:%d" % [Time.get_ticks_usec(), rng.randi()]
	return AffixRoller.roll_item(definition, rng.randi(), resolved_id)


static func roll_instance_for_rarity(rng: RandomNumberGenerator, rarity: ItemDefinition.Rarity, room_type: String = "", instance_id: String = "") -> ItemInstance:
	var candidates := _candidates_for_rarity(rarity)
	if candidates.is_empty():
		return null
	var definition := _pick_category_weighted(rng, candidates, room_type)
	var resolved_id := instance_id if not instance_id.is_empty() else "debug:%d:%d" % [Time.get_ticks_usec(), rng.randi()]
	return AffixRoller.roll_item(definition, rng.randi(), resolved_id)


static func roll_rarity(rng: RandomNumberGenerator, source_type: String = "ordinary", enemy_tier: int = 0, depth: int = 0) -> ItemDefinition.Rarity:
	var source_weights: Variant = SOURCE_RARITY_WEIGHTS.get(source_type, SOURCE_RARITY_WEIGHTS.ordinary)
	var weights: Array[float] = []
	for value: Variant in source_weights:
		weights.append(float(value))
	var progression := maxf(0.0, float(enemy_tier) * 0.06 + float(depth) * 0.025)
	for index: int in weights.size():
		if index <= ItemDefinition.Rarity.UNCOMMON:
			weights[index] *= maxf(0.35, 1.0 - progression)
		else:
			weights[index] *= 1.0 + progression * float(index - 1)
	var total := 0.0
	for weight: float in weights:
		total += weight
	var roll := rng.randf() * total
	for index: int in weights.size():
		roll -= weights[index]
		if roll <= 0.0:
			return index as ItemDefinition.Rarity
	return ItemDefinition.Rarity.MYTHIC


static func source_for_chest(room_type: String, serial: int) -> String:
	if room_type == "vault":
		return "vault"
	if room_type in ["arsenal", "forge"]:
		return "elite" if serial % 4 == 3 else "reinforced"
	return "reinforced" if serial % 3 == 2 else "wooden"


static func _candidates_for_rarity(rarity: ItemDefinition.Rarity) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for definition: ItemDefinition in ItemDatabase.DEFINITIONS:
		if definition.rarity != rarity or definition.rarity == ItemDefinition.Rarity.UNIQUE:
			continue
		if definition.item_type not in CATEGORY_WEIGHTS:
			continue
		result.append(definition)
	return result


static func _pick_category_weighted(rng: RandomNumberGenerator, candidates: Array[ItemDefinition], room_type: String) -> ItemDefinition:
	var available_types: Dictionary = {}
	for definition: ItemDefinition in candidates:
		available_types[definition.item_type] = true
	var bias: Dictionary = ROOM_CATEGORY_BIAS.get(room_type, {})
	var total := 0.0
	for type_value: Variant in available_types.keys():
		total += float(CATEGORY_WEIGHTS.get(type_value, 1.0)) * float(bias.get(type_value, 1.0))
	var roll := rng.randf() * total
	var selected_type := int(available_types.keys()[0])
	for type_value: Variant in available_types.keys():
		roll -= float(CATEGORY_WEIGHTS.get(type_value, 1.0)) * float(bias.get(type_value, 1.0))
		if roll <= 0.0:
			selected_type = int(type_value)
			break
	var filtered: Array[ItemDefinition] = []
	for definition: ItemDefinition in candidates:
		if definition.item_type == selected_type:
			filtered.append(definition)
	return filtered[rng.randi_range(0, filtered.size() - 1)] if not filtered.is_empty() else candidates[0]
