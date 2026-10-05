extends Node

signal profile_changed
signal loadout_changed
signal validation_failed(message: String)

const SAVE_VERSION := 5
const SAVE_PATH := "user://player_profile.json"
const BACKUP_SAVE_PATH := "user://player_profile.backup.json"
const INVENTORY_SIZE := 24
const STASH_CAPACITY := 200
const POWER_LIMIT := 200
const DEVELOPMENT_STASH_EXCLUDED: Array[String] = ["extraction_key", "armory_scrap", "field_tonic"]
const STARTER_ITEM_IDS: Array[String] = [
	"rusty_katana", "worn_assault_rifle", "dash", "double_jump",
	"training_helmet", "training_chest", "training_gloves", "training_boots",
	"simple_necklace", "simple_ring", "basic_charm",
]
const GEAR_KEYS: Array[String] = [
	"helmet", "chest", "gloves", "boots", "necklace", "ring_1", "ring_2", "charm"
]

var item_index: Dictionary = {}
var instance_index: Dictionary = {}
var owned_item_ids: Array[String] = []
var owned_item_instances: Array[ItemInstance] = []
var pending_reward_instances: Array[ItemInstance] = []
var pending_instance_index: Dictionary = {}
var weapon_slots: Array[String] = ["", ""]
var weapon_instance_slots: Array[String] = ["", ""]
var skill_slots: Array[String] = ["", ""]
var equipped_gear: Dictionary = {}
var equipped_gear_instances: Dictionary = {}
var main_inventory: Array[String] = []
var last_load_used_defaults: bool = false
var last_error: String = ""
var catalog_migrated_last_load: bool = false
var last_load_recovered_backup: bool = false
var development_session: bool = false
var gold: int = 120
var scrap: int = 0
var training_best_time_ms: int = 0
var new_instance_ids: Dictionary = {}


func _ready() -> void:
	item_index = ItemDatabase.build_index()
	load_profile()


func reset_to_defaults(save_after: bool = true) -> void:
	owned_item_ids.clear()
	owned_item_instances.clear()
	instance_index.clear()
	pending_reward_instances.clear()
	pending_instance_index.clear()
	new_instance_ids.clear()
	for definition_id: String in STARTER_ITEM_IDS:
		var definition := get_definition(definition_id)
		if definition == null:
			continue
		owned_item_ids.append(definition_id)
		var instance := ItemInstance.create(definition)
		owned_item_instances.append(instance)
		instance_index[instance.instance_id] = instance
	var second_ring := ItemInstance.create(get_definition("simple_ring"), "dev:simple_ring:2")
	owned_item_instances.append(second_ring)
	instance_index[second_ring.instance_id] = second_ring
	weapon_slots = ["rusty_katana", "worn_assault_rifle"]
	weapon_instance_slots = ["dev:rusty_katana", "dev:worn_assault_rifle"]
	skill_slots = ["dash", "double_jump"]
	equipped_gear = {
		"helmet": "training_helmet",
		"chest": "training_chest",
		"gloves": "training_gloves",
		"boots": "training_boots",
		"necklace": "simple_necklace",
		"ring_1": "simple_ring",
		"ring_2": "simple_ring",
		"charm": "basic_charm",
	}
	equipped_gear_instances = {}
	for key: String in GEAR_KEYS:
		equipped_gear_instances[key] = "dev:%s" % String(equipped_gear[key])
	equipped_gear_instances["ring_2"] = "dev:simple_ring:2"
	main_inventory.clear()
	main_inventory.resize(INVENTORY_SIZE)
	main_inventory.fill("")
	gold = 120
	scrap = 0
	training_best_time_ms = 0
	development_session = false
	last_load_used_defaults = true
	catalog_migrated_last_load = false
	last_load_recovered_backup = false
	last_error = ""
	profile_changed.emit()
	loadout_changed.emit()
	if save_after:
		save_profile()


func get_definition(item_id: String) -> ItemDefinition:
	return item_index.get(item_id) as ItemDefinition


func get_instance(instance_id: String) -> ItemInstance:
	var owned := instance_index.get(instance_id) as ItemInstance
	return owned if owned != null else pending_instance_index.get(instance_id) as ItemInstance


func get_pending_instances() -> Array[ItemInstance]:
	return pending_reward_instances.duplicate()


func get_stash_count() -> int:
	return get_stash_instances().size()


func has_stash_space() -> bool:
	return get_stash_count() < STASH_CAPACITY


func get_instance_for_definition(definition_id: String) -> ItemInstance:
	for instance: ItemInstance in owned_item_instances:
		if String(instance.definition_id) == definition_id:
			return instance
	return null


func get_weapon_instance(slot: int) -> ItemInstance:
	return get_instance(weapon_instance_slots[slot]) if slot >= 0 and slot < weapon_instance_slots.size() else null


func get_gear_instance(slot_key: String) -> ItemInstance:
	return get_instance(String(equipped_gear_instances.get(slot_key, "")))


func get_owned_definitions(type_filter: int = -1) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item_id: String in owned_item_ids:
		var definition := get_definition(item_id)
		if definition != null and (type_filter < 0 or definition.item_type == type_filter):
			result.append(definition)
	return result


func get_owned_instances(type_filter: int = -1) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for instance: ItemInstance in owned_item_instances:
		var definition := get_definition(String(instance.definition_id))
		if definition != null and (type_filter < 0 or definition.item_type == type_filter):
			result.append(instance)
	return result


func get_inventory_instance(slot: int) -> ItemInstance:
	if slot < 0 or slot >= main_inventory.size():
		return null
	var reference := main_inventory[slot]
	if reference.is_empty():
		return null
	var instance := get_instance(reference)
	return instance if instance != null else get_instance_for_definition(reference)


func get_inventory_definition(slot: int) -> ItemDefinition:
	var instance := get_inventory_instance(slot)
	return get_definition(String(instance.definition_id)) if instance != null else null


func find_inventory_slot(instance_id: String) -> int:
	for slot: int in main_inventory.size():
		var instance := get_inventory_instance(slot)
		if instance != null and instance.instance_id == instance_id:
			return slot
	return -1


func get_first_free_inventory_slot() -> int:
	for slot: int in main_inventory.size():
		if main_inventory[slot].is_empty():
			return slot
	return -1


func is_instance_equipped(instance_id: String) -> bool:
	return weapon_instance_slots.has(instance_id) or equipped_gear_instances.values().has(instance_id)


func get_stash_instances(type_filter: int = -1) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for instance: ItemInstance in get_owned_instances(type_filter):
		if find_inventory_slot(instance.instance_id) >= 0 or is_instance_equipped(instance.instance_id):
			continue
		var definition_id := String(instance.definition_id)
		if definition_id in skill_slots:
			continue
		result.append(instance)
	return result


func get_comparison_instance(definition: ItemDefinition) -> ItemInstance:
	if definition == null:
		return null
	if definition.item_type == ItemDefinition.ItemType.WEAPON:
		for slot: int in weapon_slots.size():
			var equipped_definition := get_definition(weapon_slots[slot])
			if equipped_definition != null and equipped_definition.weapon_family == definition.weapon_family:
				return get_weapon_instance(slot)
	elif definition.item_type == ItemDefinition.ItemType.GEAR:
		for key: String in GEAR_KEYS:
			var equipped_definition := get_definition(String(equipped_gear.get(key, "")))
			if equipped_definition != null and equipped_definition.gear_slot == definition.gear_slot:
				return get_gear_instance(key)
	elif definition.item_type == ItemDefinition.ItemType.SKILL:
		for item_id: String in skill_slots:
			var equipped_definition := get_definition(item_id)
			if equipped_definition != null:
				return get_instance_for_definition(item_id)
	return null


func get_skill_power() -> int:
	var total := 0
	for item_id: String in skill_slots:
		var definition := get_definition(item_id)
		if definition != null and definition.item_type == ItemDefinition.ItemType.SKILL:
			total += definition.power_cost
	return total


func can_afford_skill_costs(costs: Array[int]) -> bool:
	var total := 0
	for cost: int in costs:
		total += maxi(0, cost)
	return total <= POWER_LIMIT


func equip_weapon(slot: int, item_id: String, save_after: bool = true) -> bool:
	if slot < 0 or slot >= weapon_slots.size():
		return _fail("Invalid weapon slot")
	var definition := get_definition(item_id)
	if definition == null or definition.item_type != ItemDefinition.ItemType.WEAPON or not owned_item_ids.has(item_id):
		return _fail("That weapon is not owned")
	var other_slot := 1 - slot
	if weapon_slots[other_slot] == item_id:
		return _fail("A weapon cannot occupy both slots")
	var instance := get_instance_for_definition(item_id)
	return equip_weapon_instance(slot, instance.instance_id if instance != null else "", save_after)


func equip_weapon_instance(slot: int, instance_id: String, save_after: bool = true) -> bool:
	if slot < 0 or slot >= weapon_slots.size():
		return _fail("Invalid weapon slot")
	var instance := get_instance(instance_id)
	var definition := get_definition(String(instance.definition_id)) if instance != null else null
	if instance == null or definition == null or definition.item_type != ItemDefinition.ItemType.WEAPON:
		return _fail("That weapon instance is not owned")
	if instance.is_broken():
		return _fail("Repair this weapon before equipping it")
	if weapon_instance_slots[1 - slot] == instance_id:
		return _fail("A weapon cannot occupy both slots")
	weapon_slots[slot] = String(instance.definition_id)
	weapon_instance_slots[slot] = instance_id
	_commit_loadout_change(save_after)
	return true


func equip_skill(slot: int, item_id: String, save_after: bool = true) -> bool:
	if slot < 0 or slot >= skill_slots.size():
		return _fail("Invalid skill slot")
	var definition := get_definition(item_id)
	if definition == null or definition.item_type != ItemDefinition.ItemType.SKILL or not owned_item_ids.has(item_id):
		return _fail("That skill is not owned")
	var candidate := skill_slots.duplicate()
	candidate[slot] = item_id
	if candidate[1 - slot] == item_id:
		return _fail("A skill cannot occupy both slots")
	var costs: Array[int] = []
	for candidate_id: String in candidate:
		var candidate_definition := get_definition(candidate_id)
		if candidate_definition != null:
			costs.append(candidate_definition.power_cost)
	if not can_afford_skill_costs(costs):
		return _fail("POWER LIMIT EXCEEDED")
	skill_slots = candidate
	_commit_loadout_change(save_after)
	return true


func equip_gear(slot_key: String, item_id: String, save_after: bool = true) -> bool:
	if not GEAR_KEYS.has(slot_key):
		return _fail("Invalid gear slot")
	var definition := get_definition(item_id)
	if definition == null or definition.item_type != ItemDefinition.ItemType.GEAR or not owned_item_ids.has(item_id):
		return _fail("That gear item is not owned")
	if not _gear_fits(slot_key, definition.gear_slot):
		return _fail("That item does not fit this gear slot")
	var instance := get_instance_for_definition(item_id)
	return equip_gear_instance(slot_key, instance.instance_id if instance != null else "", save_after)


func equip_gear_instance(slot_key: String, instance_id: String, save_after: bool = true) -> bool:
	if not GEAR_KEYS.has(slot_key):
		return _fail("Invalid gear slot")
	var instance := get_instance(instance_id)
	var definition := get_definition(String(instance.definition_id)) if instance != null else null
	if instance == null or definition == null or definition.item_type != ItemDefinition.ItemType.GEAR:
		return _fail("That gear instance is not owned")
	if not _gear_fits(slot_key, definition.gear_slot):
		return _fail("That item does not fit this gear slot")
	if instance.is_broken():
		return _fail("Repair this gear before equipping it")
	equipped_gear[slot_key] = String(instance.definition_id)
	equipped_gear_instances[slot_key] = instance_id
	_commit_loadout_change(save_after)
	return true


func set_inventory_item(slot: int, item_id: String, save_after: bool = true) -> bool:
	if slot < 0 or slot >= main_inventory.size():
		return _fail("Invalid inventory slot")
	if not item_id.is_empty() and get_definition(item_id) == null and get_instance(item_id) == null:
		return _fail("Unknown inventory item")
	var resolved_reference := item_id
	if get_definition(item_id) != null:
		var resolved_instance := get_instance_for_definition(item_id)
		if resolved_instance == null:
			return _fail("No owned instance for inventory item")
		resolved_reference = resolved_instance.instance_id
	if not resolved_reference.is_empty() and main_inventory[slot] != resolved_reference and _instance_reference_count(resolved_reference) > 0:
		return _fail("Item is already assigned to another slot")
	main_inventory[slot] = resolved_reference
	profile_changed.emit()
	if save_after:
		save_profile()
	return true


func can_transfer_item(payload: Dictionary, target_kind: String, target_key: Variant) -> Dictionary:
	var instance := get_instance(String(payload.get("instance_id", "")))
	if instance == null:
		return {"ok": false, "reason": "ITEM NOT FOUND"}
	var origin_kind := String(payload.get("origin_kind", "stash"))
	var origin_key: Variant = payload.get("origin_key", "")
	if not _source_matches_instance(origin_kind, origin_key, instance):
		return {"ok": false, "reason": "ITEM MOVED"}
	if target_kind == origin_kind and str(target_key) == str(origin_key):
		return {"ok": true, "reason": ""}
	match target_kind:
		"stash":
			if origin_kind != "stash" and not has_stash_space():
				return {"ok": false, "reason": "STASH FULL — USE EXTRACTION OVERFLOW"}
			return {"ok": true, "reason": ""}
		"inventory":
			var target_slot := int(target_key)
			if target_slot < 0 or target_slot >= main_inventory.size():
				return {"ok": false, "reason": "INCOMPATIBLE SLOT"}
			if origin_kind.begins_with("loadout_") and get_inventory_instance(target_slot) != null:
				return {"ok": false, "reason": "NO FREE SLOT"}
			if origin_kind not in ["stash", "inventory"] and get_inventory_instance(target_slot) != null and not has_stash_space():
				return {"ok": false, "reason": "STASH FULL — TARGET MUST BE EMPTY"}
			return {"ok": true, "reason": ""}
		"loadout_weapon":
			var result := _can_equip_to_weapon(instance, int(target_key), origin_kind, origin_key)
			return _with_displacement_capacity(result, origin_kind, "loadout_weapon", get_weapon_instance(int(target_key)))
		"loadout_skill":
			var result := _can_equip_to_skill(instance, int(target_key), origin_kind, origin_key)
			return _with_displacement_capacity(result, origin_kind, "loadout_skill", _get_loadout_instance("loadout_skill", target_key))
		"loadout_gear":
			var result := _can_equip_to_gear(instance, String(target_key), origin_kind, origin_key)
			return _with_displacement_capacity(result, origin_kind, "loadout_gear", get_gear_instance(String(target_key)))
	return {"ok": false, "reason": "INCOMPATIBLE SLOT"}


func _with_displacement_capacity(result: Dictionary, origin_kind: String, target_kind: String, displaced: ItemInstance) -> Dictionary:
	if bool(result.get("ok", false)) and displaced != null and origin_kind not in ["stash", target_kind] and not has_stash_space():
		return {"ok": false, "reason": "STASH FULL — TARGET MUST BE EMPTY"}
	return result


func transfer_item(payload: Dictionary, target_kind: String, target_key: Variant, save_after: bool = true) -> bool:
	var allowed := can_transfer_item(payload, target_kind, target_key)
	if not bool(allowed.get("ok", false)):
		return _fail(String(allowed.get("reason", "INVALID DROP")))
	var instance := get_instance(String(payload.get("instance_id", "")))
	var origin_kind := String(payload.get("origin_kind", "stash"))
	var origin_key: Variant = payload.get("origin_key", "")
	if target_kind == origin_kind and str(target_key) == str(origin_key):
		return true
	var inventory_before := main_inventory.duplicate()
	var weapons_before := weapon_slots.duplicate()
	var weapon_instances_before := weapon_instance_slots.duplicate()
	var skills_before := skill_slots.duplicate()
	var gear_before := equipped_gear.duplicate(true)
	var gear_instances_before := equipped_gear_instances.duplicate(true)
	var owned_before := owned_item_instances.duplicate()
	var pending_before := pending_reward_instances.duplicate()
	if origin_kind == "overflow":
		_claim_pending_instance(instance)

	if origin_kind == "inventory" and target_kind == "inventory":
		var source_slot := int(origin_key)
		var destination_slot := int(target_key)
		var displaced := main_inventory[destination_slot]
		main_inventory[destination_slot] = instance.instance_id
		main_inventory[source_slot] = displaced
	elif origin_kind == target_kind and origin_kind.begins_with("loadout_"):
		_swap_loadout_slots(origin_kind, origin_key, target_key)
	elif target_kind == "stash":
		_clear_item_origin(origin_kind, origin_key)
	elif target_kind == "inventory":
		main_inventory[int(target_key)] = instance.instance_id
		_clear_item_origin(origin_kind, origin_key)
	else:
		_set_loadout_target(target_kind, target_key, instance)
		_clear_item_origin(origin_kind, origin_key)

	if _instance_reference_count(instance.instance_id) > 1:
		main_inventory = inventory_before
		weapon_slots = weapons_before
		weapon_instance_slots = weapon_instances_before
		skill_slots = skills_before
		equipped_gear = gear_before
		equipped_gear_instances = gear_instances_before
		owned_item_instances = owned_before
		pending_reward_instances = pending_before
		_rebuild_instance_indexes()
		return _fail("TRANSFER REJECTED")
	last_error = ""
	new_instance_ids.erase(instance.instance_id)
	profile_changed.emit()
	loadout_changed.emit()
	if save_after:
		save_profile()
	return true


func quick_equip_instance(instance_id: String, save_after: bool = true) -> bool:
	var instance := get_instance(instance_id)
	var definition := get_definition(String(instance.definition_id)) if instance != null else null
	if definition == null:
		return _fail("ITEM NOT FOUND")
	var origin_slot := find_inventory_slot(instance_id)
	var origin_kind := "inventory" if origin_slot >= 0 else ("overflow" if pending_instance_index.has(instance_id) else "stash")
	var payload := {"instance_id": instance_id, "origin_kind": origin_kind, "origin_key": origin_slot if origin_slot >= 0 else (instance_id if origin_kind == "overflow" else "")}
	match definition.item_type:
		ItemDefinition.ItemType.WEAPON:
			var slot := weapon_instance_slots.find("")
			if slot < 0: slot = 0
			return transfer_item(payload, "loadout_weapon", slot, save_after)
		ItemDefinition.ItemType.SKILL:
			var slot := skill_slots.find("")
			if slot < 0: slot = 0
			return transfer_item(payload, "loadout_skill", slot, save_after)
		ItemDefinition.ItemType.GEAR:
			var key := _preferred_gear_key(definition)
			return transfer_item(payload, "loadout_gear", key, save_after)
	return _fail("INCOMPATIBLE SLOT")


func unequip_to_storage(kind: String, key: Variant, to_inventory: bool, save_after: bool = true) -> bool:
	var instance := _get_loadout_instance(kind, key)
	if instance == null:
		return _fail("SLOT IS EMPTY")
	var payload := {"instance_id": instance.instance_id, "origin_kind": kind, "origin_key": key}
	if not to_inventory:
		return transfer_item(payload, "stash", "", save_after)
	var free_slot := get_first_free_inventory_slot()
	if free_slot < 0:
		return _fail("NO FREE SLOT")
	return transfer_item(payload, "inventory", free_slot, save_after)


func validate_loadout() -> Dictionary:
	var errors: Array[String] = []
	if weapon_slots.size() != 2:
		errors.append("Loadout requires two weapon slots")
	else:
		for item_id: String in weapon_slots:
			var definition := get_definition(item_id)
			if definition == null or definition.item_type != ItemDefinition.ItemType.WEAPON or not owned_item_ids.has(item_id):
				errors.append("Both weapon slots must contain valid weapons")
		if weapon_slots[0] == weapon_slots[1]:
			errors.append("Weapon slots must be different")
	if skill_slots.size() != 2:
		errors.append("Loadout requires two skill slots")
	else:
		for item_id: String in skill_slots:
			var definition := get_definition(item_id)
			if definition == null or definition.item_type != ItemDefinition.ItemType.SKILL or not owned_item_ids.has(item_id):
				errors.append("Both skill slots must contain valid skills")
		if skill_slots[0] == skill_slots[1]:
			errors.append("Skill slots must be different")
	if get_skill_power() > POWER_LIMIT:
		errors.append("Skill Power exceeds %d" % POWER_LIMIT)
	for slot_key: String in GEAR_KEYS:
		var definition := get_definition(String(equipped_gear.get(slot_key, "")))
		if definition != null and (definition.item_type != ItemDefinition.ItemType.GEAR or not _gear_fits(slot_key, definition.gear_slot) or not owned_item_ids.has(String(definition.id))):
			errors.append("Invalid gear in %s" % slot_key.capitalize())
	return {"valid": errors.is_empty(), "errors": errors, "power": get_skill_power()}


func to_save_data() -> Dictionary:
	var serialized_instances: Array[Dictionary] = []
	for instance: ItemInstance in owned_item_instances:
		serialized_instances.append(instance.to_dictionary())
	var serialized_pending: Array[Dictionary] = []
	for instance: ItemInstance in pending_reward_instances:
		serialized_pending.append(instance.to_dictionary())
	return {
		"save_version": SAVE_VERSION,
		"owned_item_ids": owned_item_ids.duplicate(),
		"owned_item_instances": serialized_instances,
		"pending_reward_instances": serialized_pending,
		"weapon_slots": weapon_slots.duplicate(),
		"weapon_instance_slots": weapon_instance_slots.duplicate(),
		"skill_slots": skill_slots.duplicate(),
		"equipped_gear": equipped_gear.duplicate(true),
		"equipped_gear_instances": equipped_gear_instances.duplicate(true),
		"main_inventory": main_inventory.duplicate(),
		"gold": gold,
		"scrap": scrap,
		"training_best_time_ms": training_best_time_ms,
	}


func apply_save_data(data: Dictionary, emit_signals: bool = true) -> bool:
	var incoming_version := int(data.get("save_version", -1))
	if incoming_version not in [1, 2, 3, 4, SAVE_VERSION]:
		last_error = "Unsupported save version"
		return false
	var incoming_owned := _string_array(data.get("owned_item_ids", []))
	var incoming_weapons := _string_array(data.get("weapon_slots", []))
	var incoming_skills := _string_array(data.get("skill_slots", []))
	var incoming_inventory := _string_array(data.get("main_inventory", []))
	var incoming_gear: Variant = data.get("equipped_gear", {})
	if incoming_weapons.size() != 2 or incoming_skills.size() != 2 or incoming_inventory.size() != INVENTORY_SIZE or not incoming_gear is Dictionary:
		last_error = "Save data has an invalid shape"
		return false
	owned_item_ids = incoming_owned
	new_instance_ids.clear()
	catalog_migrated_last_load = incoming_version < SAVE_VERSION
	_rebuild_item_instances(data.get("owned_item_instances", []) if incoming_version >= 2 else [])
	_rebuild_pending_instances(data.get("pending_reward_instances", []) if incoming_version >= 5 else [])
	_remove_development_only_dungeon_items()
	weapon_slots = incoming_weapons
	weapon_instance_slots.clear()
	if incoming_version >= 2:
		weapon_instance_slots = _string_array(data.get("weapon_instance_slots", []))
	if weapon_instance_slots.size() != 2:
		weapon_instance_slots = ["", ""]
	for slot: int in 2:
		if get_instance(weapon_instance_slots[slot]) == null:
			var instance := get_instance_for_definition(weapon_slots[slot])
			weapon_instance_slots[slot] = instance.instance_id if instance != null else ""
	skill_slots = incoming_skills
	main_inventory = incoming_inventory
	gold = maxi(0, int(data.get("gold", 120)))
	scrap = maxi(0, int(data.get("scrap", 0)))
	training_best_time_ms = maxi(0, int(data.get("training_best_time_ms", 0)))
	equipped_gear = (incoming_gear as Dictionary).duplicate(true)
	equipped_gear_instances = (data.get("equipped_gear_instances", {}) as Dictionary).duplicate(true) if data.get("equipped_gear_instances", {}) is Dictionary else {}
	var used_gear_instances: Dictionary = {}
	for key: String in GEAR_KEYS:
		var desired_definition := String(equipped_gear.get(key, ""))
		var instance := get_instance(String(equipped_gear_instances.get(key, "")))
		if instance == null or used_gear_instances.has(instance.instance_id) or String(instance.definition_id) != desired_definition:
			instance = _find_unreferenced_instance_for_definition(desired_definition, used_gear_instances)
		if instance == null and not desired_definition.is_empty():
			var definition := get_definition(desired_definition)
			if definition != null:
				instance = ItemInstance.create(definition, "migrated:%s:%s" % [desired_definition, key])
				owned_item_instances.append(instance)
				instance_index[instance.instance_id] = instance
		equipped_gear_instances[key] = instance.instance_id if instance != null else ""
		if instance != null:
			used_gear_instances[instance.instance_id] = true
	if incoming_version < 5:
		var used_instances := used_gear_instances.duplicate()
		for weapon_reference: String in weapon_instance_slots:
			if not weapon_reference.is_empty():
				used_instances[weapon_reference] = true
		for slot: int in main_inventory.size():
			var reference := main_inventory[slot]
			if reference.is_empty():
				continue
			var inventory_instance := get_instance(reference)
			var definition_id := String(inventory_instance.definition_id) if inventory_instance != null else reference
			if inventory_instance == null or used_instances.has(inventory_instance.instance_id):
				inventory_instance = _find_unreferenced_instance_for_definition(definition_id, used_instances)
			if inventory_instance == null:
				var definition := get_definition(definition_id)
				if definition != null:
					inventory_instance = ItemInstance.create(definition, "migrated:%s:inventory:%d" % [definition_id, slot])
					owned_item_instances.append(inventory_instance)
					instance_index[inventory_instance.instance_id] = inventory_instance
			main_inventory[slot] = inventory_instance.instance_id if inventory_instance != null else ""
			if inventory_instance != null:
				used_instances[inventory_instance.instance_id] = true
	if incoming_version == 1:
		catalog_migrated_last_load = true
	if not _references_are_unique():
		last_error = "Save data contains duplicate slot references"
		return false
	last_error = ""
	last_load_used_defaults = false
	if emit_signals:
		profile_changed.emit()
		loadout_changed.emit()
	return true


func save_profile(path: String = SAVE_PATH) -> bool:
	if development_session and path == SAVE_PATH:
		return _fail("Development profile is temporary and cannot overwrite the normal save")
	var data := to_save_data()
	if not _references_are_unique():
		return _fail("Refusing unsafe save: duplicate slot references")
	var validation := _validate_save_payload(data)
	if not bool(validation.get("valid", false)):
		return _fail("Refusing unsafe save: %s" % String(validation.get("error", "invalid data")))
	var temp_path := "%s.tmp" % path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _fail("Unable to open temporary profile for writing")
	file.store_string(JSON.stringify(data, "  "))
	file.flush()
	file = null
	var written := _read_save_dictionary(temp_path)
	var written_validation := _validate_save_payload(written)
	if not bool(written_validation.get("valid", false)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return _fail("Temporary profile failed verification")
	var existing := _read_save_dictionary(path)
	if bool(_validate_save_payload(existing).get("valid", false)):
		if not _copy_file(path, _backup_path_for(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
			return _fail("Unable to create profile backup")
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		rename_error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		return _fail("Unable to replace profile atomically")
	last_error = ""
	return true


func load_profile(path: String = SAVE_PATH, persist_fallback: bool = true) -> bool:
	last_load_recovered_backup = false
	var had_existing_data := FileAccess.file_exists(path) or FileAccess.file_exists(_backup_path_for(path))
	var primary := _read_save_dictionary(path)
	if bool(_validate_save_payload(primary).get("valid", false)) and apply_save_data(primary):
		if catalog_migrated_last_load and persist_fallback:
			save_profile(path)
		return true
	var backup_path := _backup_path_for(path)
	var backup := _read_save_dictionary(backup_path)
	if bool(_validate_save_payload(backup).get("valid", false)) and apply_save_data(backup):
		last_load_recovered_backup = true
		last_error = "Recovered profile from backup"
		if persist_fallback:
			save_profile(path)
		return true
	var failure := last_error if not last_error.is_empty() else "No valid primary or backup profile"
	reset_to_defaults(false)
	last_load_used_defaults = true
	last_error = failure
	if persist_fallback:
		save_profile(path)
	return not had_existing_data


func _commit_loadout_change(save_after: bool) -> void:
	last_error = ""
	profile_changed.emit()
	loadout_changed.emit()
	if save_after:
		save_profile()


func _fail(message: String) -> bool:
	last_error = message
	validation_failed.emit(message)
	return false


func _gear_fits(slot_key: String, slot_type: ItemDefinition.GearSlot) -> bool:
	match slot_key:
		"helmet": return slot_type == ItemDefinition.GearSlot.HELMET
		"chest": return slot_type == ItemDefinition.GearSlot.CHEST
		"gloves": return slot_type == ItemDefinition.GearSlot.GLOVES
		"boots": return slot_type == ItemDefinition.GearSlot.BOOTS
		"necklace": return slot_type == ItemDefinition.GearSlot.NECKLACE
		"ring_1", "ring_2": return slot_type == ItemDefinition.GearSlot.RING
		"charm": return slot_type == ItemDefinition.GearSlot.CHARM
	return false


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			result.append(String(entry))
	return result


func _find_unreferenced_instance_for_definition(definition_id: String, excluded: Dictionary) -> ItemInstance:
	for instance: ItemInstance in owned_item_instances:
		if String(instance.definition_id) == definition_id and not excluded.has(instance.instance_id):
			return instance
	return null


func _backup_path_for(path: String) -> String:
	return BACKUP_SAVE_PATH if path == SAVE_PATH else "%s.backup" % path


func _read_save_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return {}
	return (json.data as Dictionary).duplicate(true)


func _copy_file(source_path: String, destination_path: String) -> bool:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return false
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		return false
	destination.store_buffer(source.get_buffer(source.get_length()))
	destination.flush()
	return true


func _validate_save_payload(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {"valid": false, "error": "missing data"}
	var version := int(data.get("save_version", -1))
	if version not in [1, 2, 3, 4, SAVE_VERSION]:
		return {"valid": false, "error": "unsupported version"}
	var owned_ids := _string_array(data.get("owned_item_ids", []))
	var weapons := _string_array(data.get("weapon_slots", []))
	var skills := _string_array(data.get("skill_slots", []))
	var inventory := _string_array(data.get("main_inventory", []))
	if weapons.size() != 2 or skills.size() != 2 or inventory.size() != INVENTORY_SIZE:
		return {"valid": false, "error": "invalid slot shape"}
	if not data.get("equipped_gear", {}) is Dictionary:
		return {"valid": false, "error": "invalid gear map"}
	var seen_owned_ids: Dictionary = {}
	for definition_id: String in owned_ids:
		if get_definition(definition_id) == null:
			return {"valid": false, "error": "unknown owned item %s" % definition_id}
		if seen_owned_ids.has(definition_id):
			return {"valid": false, "error": "duplicate owned item ID"}
		seen_owned_ids[definition_id] = true
	for definition_id: String in weapons:
		if definition_id.is_empty():
			continue
		var definition := get_definition(definition_id)
		if definition == null or definition.item_type != ItemDefinition.ItemType.WEAPON:
			return {"valid": false, "error": "invalid weapon slot"}
	for definition_id: String in skills:
		if definition_id.is_empty():
			continue
		var definition := get_definition(definition_id)
		if definition == null or definition.item_type != ItemDefinition.ItemType.SKILL:
			return {"valid": false, "error": "invalid skill slot"}
	var gear_map := data.get("equipped_gear", {}) as Dictionary
	for key: String in GEAR_KEYS:
		var definition_id := String(gear_map.get(key, ""))
		if definition_id.is_empty():
			continue
		var definition := get_definition(definition_id)
		if definition == null or definition.item_type != ItemDefinition.ItemType.GEAR or not _gear_fits(key, definition.gear_slot):
			return {"valid": false, "error": "invalid gear slot %s" % key}
	var gold_value: Variant = data.get("gold", 0)
	var scrap_value: Variant = data.get("scrap", 0)
	var training_value: Variant = data.get("training_best_time_ms", 0)
	if not (gold_value is int or gold_value is float) or int(gold_value) < 0 or int(gold_value) > 1000000000:
		return {"valid": false, "error": "invalid gold"}
	if not (scrap_value is int or scrap_value is float) or int(scrap_value) < 0 or int(scrap_value) > 1000000000:
		return {"valid": false, "error": "invalid scrap"}
	if not (training_value is int or training_value is float) or int(training_value) < 0 or int(training_value) > 86400000:
		return {"valid": false, "error": "invalid training best time"}
	var seen_instances: Dictionary = {}
	var owned_instance_ids: Dictionary = {}
	var instance_groups: Array = [data.get("owned_item_instances", [])]
	if version >= 5:
		instance_groups.append(data.get("pending_reward_instances", []))
	for group_index: int in instance_groups.size():
		var group: Variant = instance_groups[group_index]
		if not group is Array:
			return {"valid": false, "error": "invalid item instance list"}
		for entry: Variant in group:
			if not entry is Dictionary:
				return {"valid": false, "error": "invalid item instance"}
			var instance_data := entry as Dictionary
			if not instance_data.get("instance_id", "") is String or not instance_data.get("definition_id", "") is String:
				return {"valid": false, "error": "invalid item identity"}
			var raw_affix_ids: Variant = instance_data.get("affix_ids", [])
			var raw_affix_tiers: Variant = instance_data.get("affix_tiers", [])
			if not raw_affix_ids is Array or not raw_affix_tiers is Array or (raw_affix_ids as Array).size() != (raw_affix_tiers as Array).size():
				return {"valid": false, "error": "invalid affix shape"}
			for tier_value: Variant in raw_affix_tiers:
				if not (tier_value is int or tier_value is float) or int(tier_value) < 1 or int(tier_value) > 3:
					return {"valid": false, "error": "invalid affix tier"}
			var raw_max_value: Variant = instance_data.get("max_durability", 0.0)
			var raw_current_value: Variant = instance_data.get("current_durability", instance_data.get("durability", raw_max_value))
			if not (raw_max_value is int or raw_max_value is float) or not (raw_current_value is int or raw_current_value is float):
				return {"valid": false, "error": "invalid durability type"}
			var raw_max_durability := float(raw_max_value)
			var raw_current_durability := float(raw_current_value)
			if not is_finite(raw_current_durability) or not is_finite(raw_max_durability) or raw_current_durability < 0.0 or raw_max_durability < 0.0 or raw_current_durability > raw_max_durability:
				return {"valid": false, "error": "invalid durability"}
			var instance := ItemInstance.from_dictionary(entry as Dictionary)
			var definition := get_definition(String(instance.definition_id))
			if instance.instance_id.is_empty() or definition == null or seen_instances.has(instance.instance_id):
				return {"valid": false, "error": "unknown or duplicate item instance"}
			if not AffixRoller.validate_instance(instance, definition).is_empty():
				return {"valid": false, "error": "invalid affix data"}
			seen_instances[instance.instance_id] = true
			if group_index == 0:
				owned_instance_ids[instance.instance_id] = String(instance.definition_id)
	if version >= 5:
		var weapon_refs := _string_array(data.get("weapon_instance_slots", []))
		if weapon_refs.size() != 2:
			return {"valid": false, "error": "invalid weapon instance slots"}
		for slot: int in 2:
			if not weapon_refs[slot].is_empty() and (not owned_instance_ids.has(weapon_refs[slot]) or String(owned_instance_ids[weapon_refs[slot]]) != weapons[slot]):
				return {"valid": false, "error": "invalid weapon instance reference"}
		for reference: String in inventory:
			if not reference.is_empty() and not owned_instance_ids.has(reference):
				return {"valid": false, "error": "invalid inventory instance reference"}
		var gear_refs: Variant = data.get("equipped_gear_instances", {})
		if not gear_refs is Dictionary:
			return {"valid": false, "error": "invalid gear instance map"}
		for key: String in GEAR_KEYS:
			var reference := String((gear_refs as Dictionary).get(key, ""))
			var definition_id := String(gear_map.get(key, ""))
			if not reference.is_empty() and (not owned_instance_ids.has(reference) or String(owned_instance_ids[reference]) != definition_id):
				return {"valid": false, "error": "invalid gear instance reference"}
	return {"valid": true, "error": ""}


func create_development_profile() -> void:
	reset_to_defaults(false)
	for definition: ItemDefinition in ItemDatabase.DEFINITIONS:
		var definition_id := String(definition.id)
		if not owned_item_ids.has(definition_id):
			owned_item_ids.append(definition_id)
		if get_instance_for_definition(definition_id) == null:
			var instance := ItemInstance.create(definition, "dev:%s" % definition_id)
			owned_item_instances.append(instance)
	development_session = true
	gold = 999999
	scrap = 9999
	_rebuild_instance_indexes()
	profile_changed.emit()
	loadout_changed.emit()


func _rebuild_item_instances(serialized: Variant) -> void:
	owned_item_instances.clear()
	instance_index.clear()
	if serialized is Array:
		for entry: Variant in serialized:
			if not entry is Dictionary:
				continue
			var instance := ItemInstance.from_dictionary(entry)
			var definition := get_definition(String(instance.definition_id))
			if definition == null or instance.instance_id.is_empty():
				continue
			var expected_max := ItemInstance.get_default_max_durability(definition)
			if instance.max_durability <= 0.0 and expected_max > 0.0:
				instance.max_durability = expected_max
				instance.current_durability = expected_max
			owned_item_instances.append(instance)
			instance_index[instance.instance_id] = instance
	for definition_id: String in owned_item_ids:
		if get_instance_for_definition(definition_id) != null:
			continue
		var definition := get_definition(definition_id)
		if definition == null:
			continue
		if definition_id in DEVELOPMENT_STASH_EXCLUDED:
			continue
		var instance := ItemInstance.create(definition)
		owned_item_instances.append(instance)
		instance_index[instance.instance_id] = instance


func _rebuild_pending_instances(serialized: Variant) -> void:
	pending_reward_instances.clear()
	pending_instance_index.clear()
	if not serialized is Array:
		return
	for entry: Variant in serialized:
		if not entry is Dictionary:
			continue
		var instance := ItemInstance.from_dictionary(entry as Dictionary)
		if get_definition(String(instance.definition_id)) == null or instance.instance_id.is_empty() or instance_index.has(instance.instance_id) or pending_instance_index.has(instance.instance_id):
			continue
		pending_reward_instances.append(instance)
		pending_instance_index[instance.instance_id] = instance


func _rebuild_instance_indexes() -> void:
	instance_index.clear()
	for instance: ItemInstance in owned_item_instances:
		instance_index[instance.instance_id] = instance
	pending_instance_index.clear()
	for instance: ItemInstance in pending_reward_instances:
		pending_instance_index[instance.instance_id] = instance


func _claim_pending_instance(instance: ItemInstance) -> bool:
	if instance == null or not pending_instance_index.has(instance.instance_id):
		return false
	pending_reward_instances.erase(instance)
	pending_instance_index.erase(instance.instance_id)
	owned_item_instances.append(instance)
	instance_index[instance.instance_id] = instance
	var definition_id := String(instance.definition_id)
	if not owned_item_ids.has(definition_id):
		owned_item_ids.append(definition_id)
	return true


func _remove_development_only_dungeon_items() -> void:
	for definition_id: String in DEVELOPMENT_STASH_EXCLUDED:
		var kept_real_instance := false
		for index: int in range(owned_item_instances.size() - 1, -1, -1):
			var instance := owned_item_instances[index]
			if String(instance.definition_id) != definition_id:
				continue
			if instance.instance_id.begins_with("dev:"):
				instance_index.erase(instance.instance_id)
				owned_item_instances.remove_at(index)
			else:
				kept_real_instance = true
		if not kept_real_instance:
			owned_item_ids.erase(definition_id)


func add_owned_instance(instance: ItemInstance, add_to_inventory: bool = false) -> bool:
	if instance == null or get_definition(String(instance.definition_id)) == null:
		return _fail("Cannot add an unknown item")
	if instance.instance_id.is_empty():
		instance.instance_id = "loot:%d:%d" % [Time.get_unix_time_from_system(), owned_item_instances.size()]
	if instance_index.has(instance.instance_id):
		return _fail("Duplicate item instance")
	owned_item_instances.append(instance)
	instance_index[instance.instance_id] = instance
	new_instance_ids[instance.instance_id] = true
	var definition_id := String(instance.definition_id)
	if not owned_item_ids.has(definition_id):
		owned_item_ids.append(definition_id)
	if add_to_inventory:
		for slot: int in main_inventory.size():
			if main_inventory[slot].is_empty():
				main_inventory[slot] = instance.instance_id
				break
	profile_changed.emit()
	return true


func secure_extracted_instance(instance: ItemInstance, save_after: bool = false) -> String:
	if instance == null or get_definition(String(instance.definition_id)) == null:
		_fail("Cannot secure an unknown item")
		return "failed"
	if instance.instance_id.is_empty():
		instance.instance_id = "extract:%d:%d" % [Time.get_ticks_usec(), owned_item_instances.size() + pending_reward_instances.size()]
	if get_instance(instance.instance_id) != null:
		_fail("Duplicate extracted item instance")
		return "failed"
	var location := "stash"
	if has_stash_space():
		if not add_owned_instance(instance, false):
			return "failed"
	else:
		pending_reward_instances.append(instance)
		pending_instance_index[instance.instance_id] = instance
		new_instance_ids[instance.instance_id] = true
		location = "overflow"
		profile_changed.emit()
	if save_after:
		save_profile()
	return location


func get_sell_value(instance: ItemInstance) -> int:
	var definition := get_definition(String(instance.definition_id)) if instance != null else null
	if definition == null or definition.item_type == ItemDefinition.ItemType.KEY:
		return 0
	var rarity_multiplier: Array[float] = [1.0, 1.35, 1.8, 2.5, 3.5, 5.0, 6.0]
	var durability_factor := 1.0
	if instance.max_durability > 0.0:
		durability_factor = 0.25 + 0.75 * clampf(instance.current_durability / instance.max_durability, 0.0, 1.0)
	var tier_bonus := 0
	for tier: int in instance.affix_tiers:
		tier_bonus += tier
	return maxi(1, roundi(float(maxi(1, definition.sell_value)) * rarity_multiplier[clampi(definition.rarity, 0, rarity_multiplier.size() - 1)] * durability_factor * (1.0 + float(tier_bonus) * 0.08)))


func get_dismantle_yield(instance: ItemInstance) -> int:
	var definition := get_definition(String(instance.definition_id)) if instance != null else null
	if definition == null or definition.item_type in [ItemDefinition.ItemType.KEY, ItemDefinition.ItemType.SKILL]:
		return 0
	var base_yield: Array[int] = [1, 2, 3, 5, 8, 12, 16]
	var result := base_yield[clampi(definition.rarity, 0, base_yield.size() - 1)]
	for tier: int in instance.affix_tiers:
		result += tier
	return result


func sell_instance(instance_id: String, save_after: bool = true) -> bool:
	var instance := get_instance(instance_id)
	var value := get_sell_value(instance)
	if instance == null or value <= 0:
		return _fail("This item cannot be sold")
	if is_instance_equipped(instance_id) or String(instance.definition_id) in skill_slots:
		return _fail("Equipped items are protected")
	if not _remove_exact_instance(instance):
		return _fail("Item was already removed")
	gold += value
	profile_changed.emit()
	if save_after:
		save_profile()
	return true


func dismantle_instance(instance_id: String, save_after: bool = true) -> bool:
	var instance := get_instance(instance_id)
	var amount := get_dismantle_yield(instance)
	if instance == null or amount <= 0:
		return _fail("This item cannot be dismantled")
	if is_instance_equipped(instance_id) or String(instance.definition_id) in skill_slots:
		return _fail("Equipped items are protected")
	if not _remove_exact_instance(instance):
		return _fail("Item was already removed")
	scrap += amount
	profile_changed.emit()
	if save_after:
		save_profile()
	return true


func _remove_exact_instance(instance: ItemInstance) -> bool:
	if instance == null:
		return false
	var removed := false
	if instance_index.has(instance.instance_id):
		for slot: int in main_inventory.size():
			if main_inventory[slot] == instance.instance_id:
				main_inventory[slot] = ""
		owned_item_instances.erase(instance)
		instance_index.erase(instance.instance_id)
		removed = true
	elif pending_instance_index.has(instance.instance_id):
		pending_reward_instances.erase(instance)
		pending_instance_index.erase(instance.instance_id)
		removed = true
	if removed:
		new_instance_ids.erase(instance.instance_id)
		var definition_id := String(instance.definition_id)
		var still_owned := false
		for other: ItemInstance in owned_item_instances:
			if String(other.definition_id) == definition_id:
				still_owned = true
				break
		if not still_owned and not skill_slots.has(definition_id):
			owned_item_ids.erase(definition_id)
	return removed


func set_training_best_time(time_ms: int, save_after: bool = true) -> bool:
	if time_ms <= 0 or (training_best_time_ms > 0 and time_ms >= training_best_time_ms):
		return false
	training_best_time_ms = time_ms
	profile_changed.emit()
	if save_after:
		save_profile()
	return true


func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	profile_changed.emit()


func repair_instance(instance_id: String, save_after: bool = true) -> bool:
	var instance := get_instance(instance_id)
	var definition := get_definition(String(instance.definition_id)) if instance != null else null
	var cost := DurabilityService.repair_cost(instance, definition)
	if instance == null or instance.max_durability <= 0.0:
		return _fail("That item cannot be repaired")
	if cost <= 0:
		return _fail("That item is already fully repaired")
	if gold < cost:
		return _fail("Not enough gold")
	gold -= cost
	instance.repair_full()
	profile_changed.emit()
	if save_after:
		save_profile()
	return true


func get_equipped_repair_cost() -> int:
	var total := 0
	for instance: ItemInstance in _get_unique_equipped_instances():
		total += DurabilityService.repair_cost(instance, get_definition(String(instance.definition_id)))
	return total


func repair_all_equipped(save_after: bool = true) -> bool:
	var cost := get_equipped_repair_cost()
	if cost <= 0:
		return _fail("Equipped items are already fully repaired")
	if gold < cost:
		return _fail("Not enough gold for repairs")
	gold -= cost
	for instance: ItemInstance in _get_unique_equipped_instances():
		instance.repair_full()
	profile_changed.emit()
	if save_after:
		save_profile()
	return true


func get_all_damaged_repair_cost() -> int:
	var total := 0
	for instance: ItemInstance in owned_item_instances:
		total += DurabilityService.repair_cost(instance, get_definition(String(instance.definition_id)))
	return total


func repair_all_damaged(save_after: bool = true) -> bool:
	var cost := get_all_damaged_repair_cost()
	if cost <= 0:
		return _fail("ALL ITEMS ARE FULLY REPAIRED")
	if gold < cost:
		return _fail("NOT ENOUGH GOLD")
	gold -= cost
	for instance: ItemInstance in owned_item_instances:
		if instance.current_durability < instance.max_durability:
			instance.repair_full()
	profile_changed.emit()
	if save_after:
		save_profile()
	return true


func _get_unique_equipped_instances() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	var visited: Dictionary = {}
	for instance_id: String in weapon_instance_slots:
		var instance := get_instance(instance_id)
		if instance != null and not visited.has(instance.instance_id):
			visited[instance.instance_id] = true
			result.append(instance)
	for slot_key: String in GEAR_KEYS:
		var instance := get_gear_instance(slot_key)
		if instance != null and not visited.has(instance.instance_id):
			visited[instance.instance_id] = true
			result.append(instance)
	return result


func _source_matches_instance(origin_kind: String, origin_key: Variant, instance: ItemInstance) -> bool:
	match origin_kind:
		"stash": return find_inventory_slot(instance.instance_id) < 0 and not is_instance_equipped(instance.instance_id) and String(instance.definition_id) not in skill_slots
		"overflow": return pending_instance_index.has(instance.instance_id) and (String(origin_key).is_empty() or String(origin_key) == instance.instance_id)
		"inventory": return get_inventory_instance(int(origin_key)) == instance
		"loadout_weapon": return get_weapon_instance(int(origin_key)) == instance
		"loadout_skill": return int(origin_key) >= 0 and int(origin_key) < skill_slots.size() and String(instance.definition_id) == skill_slots[int(origin_key)]
		"loadout_gear": return get_gear_instance(String(origin_key)) == instance
	return false


func _can_equip_to_weapon(instance: ItemInstance, slot: int, origin_kind: String, origin_key: Variant) -> Dictionary:
	var definition := get_definition(String(instance.definition_id))
	if definition == null or definition.item_type != ItemDefinition.ItemType.WEAPON or slot < 0 or slot >= 2:
		return {"ok": false, "reason": "INCOMPATIBLE SLOT"}
	if instance.is_broken():
		return {"ok": false, "reason": "ITEM BROKEN"}
	var other_slot := 1 - slot
	if weapon_instance_slots[other_slot] == instance.instance_id and not (origin_kind == "loadout_weapon" and int(origin_key) == other_slot):
		return {"ok": false, "reason": "ITEM ALREADY EQUIPPED"}
	return {"ok": true, "reason": ""}


func _can_equip_to_skill(instance: ItemInstance, slot: int, origin_kind: String, origin_key: Variant) -> Dictionary:
	var definition := get_definition(String(instance.definition_id))
	if definition == null or definition.item_type != ItemDefinition.ItemType.SKILL or slot < 0 or slot >= 2:
		return {"ok": false, "reason": "INCOMPATIBLE SLOT"}
	var candidate := skill_slots.duplicate()
	candidate[slot] = String(definition.id)
	if candidate[1 - slot] == String(definition.id) and not (origin_kind == "loadout_skill" and int(origin_key) == 1 - slot):
		return {"ok": false, "reason": "ITEM ALREADY EQUIPPED"}
	var total := 0
	for item_id: String in candidate:
		var candidate_definition := get_definition(item_id)
		if candidate_definition != null:
			total += candidate_definition.power_cost
	if total > POWER_LIMIT:
		return {"ok": false, "reason": "POWER LIMIT EXCEEDED", "power": total}
	return {"ok": true, "reason": "", "power": total}


func _can_equip_to_gear(instance: ItemInstance, key: String, origin_kind: String, origin_key: Variant) -> Dictionary:
	var definition := get_definition(String(instance.definition_id))
	if definition == null or definition.item_type != ItemDefinition.ItemType.GEAR or not GEAR_KEYS.has(key) or not _gear_fits(key, definition.gear_slot):
		return {"ok": false, "reason": "INCOMPATIBLE SLOT"}
	if instance.is_broken():
		return {"ok": false, "reason": "ITEM BROKEN"}
	for equipped_key: String in GEAR_KEYS:
		if equipped_key != key and String(equipped_gear_instances.get(equipped_key, "")) == instance.instance_id and not (origin_kind == "loadout_gear" and String(origin_key) == equipped_key):
			return {"ok": false, "reason": "ITEM ALREADY EQUIPPED"}
	return {"ok": true, "reason": ""}


func _clear_item_origin(kind: String, key: Variant) -> void:
	match kind:
		"overflow": pass
		"inventory": main_inventory[int(key)] = ""
		"loadout_weapon":
			weapon_slots[int(key)] = ""
			weapon_instance_slots[int(key)] = ""
		"loadout_skill": skill_slots[int(key)] = ""
		"loadout_gear":
			equipped_gear[String(key)] = ""
			equipped_gear_instances[String(key)] = ""


func _set_loadout_target(kind: String, key: Variant, instance: ItemInstance) -> void:
	var definition_id := String(instance.definition_id)
	match kind:
		"loadout_weapon":
			weapon_slots[int(key)] = definition_id
			weapon_instance_slots[int(key)] = instance.instance_id
		"loadout_skill": skill_slots[int(key)] = definition_id
		"loadout_gear":
			equipped_gear[String(key)] = definition_id
			equipped_gear_instances[String(key)] = instance.instance_id


func _swap_loadout_slots(kind: String, source_key: Variant, target_key: Variant) -> void:
	match kind:
		"loadout_weapon":
			var source := int(source_key)
			var target := int(target_key)
			var item_id := weapon_slots[source]
			var instance_id := weapon_instance_slots[source]
			weapon_slots[source] = weapon_slots[target]
			weapon_instance_slots[source] = weapon_instance_slots[target]
			weapon_slots[target] = item_id
			weapon_instance_slots[target] = instance_id
		"loadout_skill":
			var source := int(source_key)
			var target := int(target_key)
			var item_id := skill_slots[source]
			skill_slots[source] = skill_slots[target]
			skill_slots[target] = item_id
		"loadout_gear":
			var source := String(source_key)
			var target := String(target_key)
			var item_id := String(equipped_gear.get(source, ""))
			var instance_id := String(equipped_gear_instances.get(source, ""))
			equipped_gear[source] = String(equipped_gear.get(target, ""))
			equipped_gear_instances[source] = String(equipped_gear_instances.get(target, ""))
			equipped_gear[target] = item_id
			equipped_gear_instances[target] = instance_id


func _get_loadout_instance(kind: String, key: Variant) -> ItemInstance:
	match kind:
		"loadout_weapon": return get_weapon_instance(int(key))
		"loadout_skill":
			var slot := int(key)
			return get_instance_for_definition(skill_slots[slot]) if slot >= 0 and slot < skill_slots.size() else null
		"loadout_gear": return get_gear_instance(String(key))
	return null


func _preferred_gear_key(definition: ItemDefinition) -> String:
	match definition.gear_slot:
		ItemDefinition.GearSlot.HELMET: return "helmet"
		ItemDefinition.GearSlot.CHEST: return "chest"
		ItemDefinition.GearSlot.GLOVES: return "gloves"
		ItemDefinition.GearSlot.BOOTS: return "boots"
		ItemDefinition.GearSlot.NECKLACE: return "necklace"
		ItemDefinition.GearSlot.CHARM: return "charm"
		ItemDefinition.GearSlot.RING:
			return "ring_1" if String(equipped_gear_instances.get("ring_1", "")).is_empty() else "ring_2"
	return ""


func _references_are_unique() -> bool:
	var references: Dictionary = {}
	for slot: int in main_inventory.size():
		var instance := get_inventory_instance(slot)
		if instance == null:
			continue
		if references.has(instance.instance_id):
			return false
		references[instance.instance_id] = true
	for instance_id: String in weapon_instance_slots:
		if instance_id.is_empty():
			continue
		if references.has(instance_id):
			return false
		references[instance_id] = true
	for key: String in GEAR_KEYS:
		var instance_id := String(equipped_gear_instances.get(key, ""))
		if instance_id.is_empty():
			continue
		if references.has(instance_id):
			return false
		references[instance_id] = true
	if not skill_slots[0].is_empty() and skill_slots[0] == skill_slots[1]:
		return false
	return true


func _instance_reference_count(instance_id: String) -> int:
	var count := 0
	for slot: int in main_inventory.size():
		var inventory_instance := get_inventory_instance(slot)
		if inventory_instance != null and inventory_instance.instance_id == instance_id:
			count += 1
	for equipped_id: String in weapon_instance_slots:
		if equipped_id == instance_id:
			count += 1
	for key: String in GEAR_KEYS:
		if String(equipped_gear_instances.get(key, "")) == instance_id:
			count += 1
	return count
