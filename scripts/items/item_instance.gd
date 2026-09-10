class_name ItemInstance
extends Resource

var instance_id: String = ""
var definition_id: StringName
var affix_ids: Array[StringName] = []
var affix_tiers: Array[int] = []
var current_durability: float = 0.0
var max_durability: float = 0.0


static func create(definition: ItemDefinition, p_instance_id: String = "") -> ItemInstance:
	var item := ItemInstance.new()
	item.definition_id = definition.id
	item.instance_id = p_instance_id if not p_instance_id.is_empty() else "dev:%s" % definition.id
	item.affix_ids = definition.affix_ids.duplicate()
	item.affix_tiers = definition.affix_tiers.duplicate()
	while item.affix_tiers.size() < item.affix_ids.size():
		item.affix_tiers.append(1)
	while item.affix_tiers.size() > item.affix_ids.size():
		item.affix_tiers.pop_back()
	item.max_durability = get_default_max_durability(definition)
	item.current_durability = item.max_durability
	return item


static func from_dictionary(data: Dictionary) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = String(data.get("instance_id", ""))
	item.definition_id = StringName(String(data.get("definition_id", "")))
	for affix_id: Variant in data.get("affix_ids", []):
		item.affix_ids.append(StringName(String(affix_id)))
	for tier: Variant in data.get("affix_tiers", []):
		item.affix_tiers.append(clampi(int(tier), 1, 3))
	while item.affix_tiers.size() < item.affix_ids.size():
		item.affix_tiers.append(1)
	while item.affix_tiers.size() > item.affix_ids.size():
		item.affix_tiers.pop_back()
	item.max_durability = maxf(0.0, float(data.get("max_durability", 0.0)))
	item.current_durability = maxf(0.0, float(data.get("current_durability", data.get("durability", item.max_durability))))
	if item.max_durability > 0.0:
		item.current_durability = minf(item.current_durability, item.max_durability)
	return item


func to_dictionary() -> Dictionary:
	var ids: Array[String] = []
	for affix_id: StringName in affix_ids:
		ids.append(String(affix_id))
	return {
		"instance_id": instance_id,
		"definition_id": String(definition_id),
		"affix_ids": ids,
		"affix_tiers": affix_tiers.duplicate(),
		"current_durability": current_durability,
		"max_durability": max_durability,
	}


func get_affix_tier(affix_id: StringName) -> int:
	var index := affix_ids.find(affix_id)
	return affix_tiers[index] if index >= 0 and index < affix_tiers.size() else 0


func is_broken() -> bool:
	return max_durability > 0.0 and current_durability <= 0.0


func lose_durability(amount: float) -> float:
	if amount <= 0.0 or max_durability <= 0.0:
		return 0.0
	var before := current_durability
	current_durability = maxf(0.0, current_durability - amount)
	return before - current_durability


func repair_full() -> float:
	var restored := maxf(0.0, max_durability - current_durability)
	current_durability = max_durability
	return restored


static func get_default_max_durability(definition: ItemDefinition) -> float:
	if definition == null:
		return 0.0
	if definition.durability_max > 0:
		return float(definition.durability_max)
	if definition.item_type == ItemDefinition.ItemType.WEAPON:
		return 100.0
	if definition.item_type == ItemDefinition.ItemType.GEAR:
		return 80.0
	return 0.0
