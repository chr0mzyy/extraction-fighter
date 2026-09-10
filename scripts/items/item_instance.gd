class_name ItemInstance
extends Resource

var instance_id: String = ""
var definition_id: StringName
var affix_ids: Array[StringName] = []
var affix_tiers: Array[int] = []
var durability: float = 0.0


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
	item.durability = float(definition.durability_max)
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
	item.durability = float(data.get("durability", 0.0))
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
		"durability": durability,
	}


func get_affix_tier(affix_id: StringName) -> int:
	var index := affix_ids.find(affix_id)
	return affix_tiers[index] if index >= 0 and index < affix_tiers.size() else 0
