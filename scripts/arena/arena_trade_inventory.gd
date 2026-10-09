class_name ArenaTradeInventory
extends RefCounted

const INVENTORY_SIZE := 24

var owner_id: String = ""
var display_name: String = ""
var profile_data: Dictionary = {}
var synthetic: bool = false


func _init(p_owner_id: String = "", p_display_name: String = "", p_data: Dictionary = {}, p_synthetic: bool = false) -> void:
	owner_id = p_owner_id
	display_name = p_display_name
	profile_data = p_data.duplicate(true)
	synthetic = p_synthetic


func snapshot() -> Dictionary:
	return profile_data.duplicate(true)


func restore(data: Dictionary) -> void:
	profile_data = data.duplicate(true)


func inventory_count() -> int:
	var count := 0
	for reference: Variant in profile_data.get("main_inventory", []):
		if not String(reference).is_empty():
			count += 1
	return count


func find_inventory_slot(instance_id: String) -> int:
	var inventory: Array = profile_data.get("main_inventory", []) as Array
	for slot: int in inventory.size():
		if String(inventory[slot]) == instance_id:
			return slot
	return -1


func get_instance_data(instance_id: String) -> Dictionary:
	for entry: Variant in profile_data.get("owned_item_instances", []):
		if entry is Dictionary and String((entry as Dictionary).get("instance_id", "")) == instance_id:
			return (entry as Dictionary).duplicate(true)
	return {}


func get_instance(instance_id: String) -> ItemInstance:
	var instance_data := get_instance_data(instance_id)
	return ItemInstance.from_dictionary(instance_data) if not instance_data.is_empty() else null


func eligibility(instance_id: String, item_index: Dictionary) -> Dictionary:
	if find_inventory_slot(instance_id) < 0:
		return {"ok": false, "reason": "ITEM IS NOT IN THIS OWNER'S MAIN INVENTORY"}
	var instance_data := get_instance_data(instance_id)
	if instance_data.is_empty():
		return {"ok": false, "reason": "STALE ITEM REFERENCE"}
	if _is_equipped(instance_id):
		return {"ok": false, "reason": "EQUIPPED ITEMS ARE PROTECTED"}
	var definition := item_index.get(String(instance_data.get("definition_id", ""))) as ItemDefinition
	if definition == null:
		return {"ok": false, "reason": "UNKNOWN ITEM DEFINITION"}
	if not definition.is_arena_trade_eligible():
		return {"ok": false, "reason": "ITEM IS PROTECTED OR NON-TRADABLE"}
	return {"ok": true, "reason": ""}


func eligible_items(item_index: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var inventory: Array = profile_data.get("main_inventory", []) as Array
	for slot: int in inventory.size():
		var instance_id := String(inventory[slot])
		if instance_id.is_empty() or not bool(eligibility(instance_id, item_index).get("ok", false)):
			continue
		var instance_data := get_instance_data(instance_id)
		result.append({
			"owner_id": owner_id,
			"owner_name": display_name,
			"slot": slot,
			"instance_id": instance_id,
			"instance": ItemInstance.from_dictionary(instance_data),
			"definition": item_index.get(String(instance_data.get("definition_id", ""))) as ItemDefinition,
		})
	return result


func swap_inventory_instance(outgoing_id: String, incoming_data: Dictionary) -> Dictionary:
	var slot := find_inventory_slot(outgoing_id)
	var outgoing_data := get_instance_data(outgoing_id)
	if slot < 0 or outgoing_data.is_empty() or incoming_data.is_empty():
		return {}
	var owned: Array = (profile_data.get("owned_item_instances", []) as Array).duplicate(true)
	var outgoing_index := -1
	for index: int in owned.size():
		if owned[index] is Dictionary and String((owned[index] as Dictionary).get("instance_id", "")) == outgoing_id:
			outgoing_index = index
			break
	if outgoing_index < 0:
		return {}
	owned.remove_at(outgoing_index)
	owned.append(incoming_data.duplicate(true))
	var inventory: Array = (profile_data.get("main_inventory", []) as Array).duplicate()
	inventory[slot] = String(incoming_data.get("instance_id", ""))
	profile_data["owned_item_instances"] = owned
	profile_data["main_inventory"] = inventory
	_rebuild_owned_definition_ids()
	return outgoing_data


func has_any_instance_id(instance_id: String) -> bool:
	for group_name: String in ["owned_item_instances", "pending_reward_instances"]:
		for entry: Variant in profile_data.get(group_name, []):
			if entry is Dictionary and String((entry as Dictionary).get("instance_id", "")) == instance_id:
				return true
	return false


func validate_integrity() -> Dictionary:
	var inventory: Variant = profile_data.get("main_inventory", [])
	if not inventory is Array or (inventory as Array).size() != INVENTORY_SIZE:
		return {"ok": false, "reason": "INVALID INVENTORY SHAPE"}
	var known: Dictionary = {}
	for group_name: String in ["owned_item_instances", "pending_reward_instances"]:
		var group: Variant = profile_data.get(group_name, [])
		if not group is Array:
			return {"ok": false, "reason": "INVALID ITEM LIST"}
		for entry: Variant in group:
			if not entry is Dictionary:
				return {"ok": false, "reason": "INVALID ITEM INSTANCE"}
			var instance_id := String((entry as Dictionary).get("instance_id", ""))
			if instance_id.is_empty() or known.has(instance_id):
				return {"ok": false, "reason": "DUPLICATE ITEM INSTANCE"}
			known[instance_id] = true
	var inventory_seen: Dictionary = {}
	for reference: Variant in inventory:
		var instance_id := String(reference)
		if instance_id.is_empty():
			continue
		if not known.has(instance_id) or inventory_seen.has(instance_id):
			return {"ok": false, "reason": "STALE OR DUPLICATE INVENTORY REFERENCE"}
		inventory_seen[instance_id] = true
	return {"ok": true, "reason": ""}


func add_completed_transaction(transaction_id: String) -> void:
	var ids: Array = (profile_data.get("arena_completed_transaction_ids", []) as Array).duplicate()
	if not ids.has(transaction_id):
		ids.append(transaction_id)
	while ids.size() > 256:
		ids.pop_front()
	profile_data["arena_completed_transaction_ids"] = ids


func has_completed_transaction(transaction_id: String) -> bool:
	return (profile_data.get("arena_completed_transaction_ids", []) as Array).has(transaction_id)


func add_processed_result(result_id: String) -> void:
	var ids: Array = (profile_data.get("arena_processed_result_ids", []) as Array).duplicate()
	if not ids.has(result_id):
		ids.append(result_id)
	while ids.size() > 128:
		ids.pop_front()
	profile_data["arena_processed_result_ids"] = ids


func has_processed_result(result_id: String) -> bool:
	return (profile_data.get("arena_processed_result_ids", []) as Array).has(result_id)


func _is_equipped(instance_id: String) -> bool:
	if (profile_data.get("weapon_instance_slots", []) as Array).has(instance_id):
		return true
	var gear: Variant = profile_data.get("equipped_gear_instances", {})
	return gear is Dictionary and (gear as Dictionary).values().has(instance_id)


func _rebuild_owned_definition_ids() -> void:
	var ids: Array[String] = []
	for entry: Variant in profile_data.get("owned_item_instances", []):
		if not entry is Dictionary:
			continue
		var definition_id := String((entry as Dictionary).get("definition_id", ""))
		if not definition_id.is_empty() and not ids.has(definition_id):
			ids.append(definition_id)
	profile_data["owned_item_ids"] = ids
