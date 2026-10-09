class_name ArenaBotRewardFactory
extends RefCounted


static func create_inventory(owner_id: String, display_name: String, result_id: String, item_count: int = 8) -> ArenaTradeInventory:
	var data := _namespace_profile(PlayerProfile.to_save_data(), owner_id, result_id)
	var inventory: Array[String] = []
	inventory.resize(PlayerProfile.INVENTORY_SIZE)
	inventory.fill("")
	data["main_inventory"] = inventory
	var owned: Array = (data.get("owned_item_instances", []) as Array).duplicate(true)
	var candidates: Array[ItemDefinition] = []
	for definition: ItemDefinition in ItemDatabase.DEFINITIONS:
		if definition.is_arena_trade_eligible() and definition.rarity <= ItemDefinition.Rarity.RARE:
			candidates.append(definition)
	candidates.sort_custom(func(a: ItemDefinition, b: ItemDefinition) -> bool: return String(a.id) < String(b.id))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s" % [result_id, owner_id])
	for slot: int in mini(item_count, inventory.size()):
		if candidates.is_empty():
			break
		var definition := candidates[rng.randi_range(0, candidates.size() - 1)]
		var instance := ItemInstance.create(definition, "bot:%s:%s:%02d" % [result_id, owner_id, slot])
		owned.append(instance.to_dictionary())
		inventory[slot] = instance.instance_id
	data["owned_item_instances"] = owned
	data["main_inventory"] = inventory
	data["arena_completed_transaction_ids"] = []
	data["arena_processed_result_ids"] = []
	var ledger := ArenaTradeInventory.new(owner_id, display_name, data, true)
	ledger._rebuild_owned_definition_ids()
	return ledger


static func _namespace_profile(source: Dictionary, owner_id: String, result_id: String) -> Dictionary:
	var data := source.duplicate(true)
	var replacements: Dictionary = {}
	for group_name: String in ["owned_item_instances", "pending_reward_instances"]:
		var renamed: Array = []
		for entry: Variant in data.get(group_name, []):
			var item := (entry as Dictionary).duplicate(true)
			var old_id := String(item.get("instance_id", ""))
			var new_id := "botbase:%s:%s:%s" % [result_id, owner_id, old_id]
			replacements[old_id] = new_id
			item["instance_id"] = new_id
			renamed.append(item)
		data[group_name] = renamed
	var weapon_refs: Array = data.get("weapon_instance_slots", []) as Array
	for index: int in weapon_refs.size():
		weapon_refs[index] = String(replacements.get(String(weapon_refs[index]), String(weapon_refs[index])))
	data["weapon_instance_slots"] = weapon_refs
	var gear_refs: Dictionary = data.get("equipped_gear_instances", {}) as Dictionary
	for key: Variant in gear_refs.keys():
		gear_refs[key] = String(replacements.get(String(gear_refs[key]), String(gear_refs[key])))
	data["equipped_gear_instances"] = gear_refs
	return data
