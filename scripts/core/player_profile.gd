extends Node

signal profile_changed
signal loadout_changed
signal validation_failed(message: String)

const SAVE_VERSION := 4
const SAVE_PATH := "user://player_profile.json"
const INVENTORY_SIZE := 24
const POWER_LIMIT := 200
const DEVELOPMENT_STASH_EXCLUDED: Array[String] = ["extraction_key", "armory_scrap", "field_tonic"]
const GEAR_KEYS: Array[String] = [
	"helmet", "chest", "gloves", "boots", "necklace", "ring_1", "ring_2", "charm"
]

var item_index: Dictionary = {}
var instance_index: Dictionary = {}
var owned_item_ids: Array[String] = []
var owned_item_instances: Array[ItemInstance] = []
var weapon_slots: Array[String] = ["", ""]
var weapon_instance_slots: Array[String] = ["", ""]
var skill_slots: Array[String] = ["", ""]
var equipped_gear: Dictionary = {}
var equipped_gear_instances: Dictionary = {}
var main_inventory: Array[String] = []
var last_load_used_defaults: bool = false
var last_error: String = ""
var catalog_migrated_last_load: bool = false
var gold: int = 750
var new_instance_ids: Dictionary = {}


func _ready() -> void:
	item_index = ItemDatabase.build_index()
	load_profile()


func reset_to_defaults(save_after: bool = true) -> void:
	owned_item_ids.clear()
	owned_item_instances.clear()
	instance_index.clear()
	new_instance_ids.clear()
	for definition: ItemDefinition in ItemDatabase.DEFINITIONS:
		if String(definition.id) in DEVELOPMENT_STASH_EXCLUDED:
			continue
		owned_item_ids.append(String(definition.id))
		var instance := ItemInstance.create(definition)
		owned_item_instances.append(instance)
		instance_index[instance.instance_id] = instance
	weapon_slots = ["ronin_katana", "huntsman_rifle"]
	weapon_instance_slots = ["dev:ronin_katana", "dev:huntsman_rifle"]
	skill_slots = ["dash", "double_jump"]
	equipped_gear = {
		"helmet": "training_helmet",
		"chest": "training_chest",
		"gloves": "training_gloves",
		"boots": "training_boots",
		"necklace": "simple_necklace",
		"ring_1": "simple_ring",
		"ring_2": "iron_ring",
		"charm": "basic_charm",
	}
	equipped_gear_instances = {}
	for key: String in GEAR_KEYS:
		equipped_gear_instances[key] = "dev:%s" % String(equipped_gear[key])
	main_inventory.clear()
	main_inventory.resize(INVENTORY_SIZE)
	main_inventory.fill("")
	gold = 750
	last_load_used_defaults = true
	catalog_migrated_last_load = false
	last_error = ""
	profile_changed.emit()
	loadout_changed.emit()
	if save_after:
		save_profile()


func get_definition(item_id: String) -> ItemDefinition:
	return item_index.get(item_id) as ItemDefinition


func get_instance(instance_id: String) -> ItemInstance:
	return instance_index.get(instance_id) as ItemInstance


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
	main_inventory[slot] = item_id
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
			return {"ok": true, "reason": ""}
		"inventory":
			var target_slot := int(target_key)
			if target_slot < 0 or target_slot >= main_inventory.size():
				return {"ok": false, "reason": "INCOMPATIBLE SLOT"}
			if origin_kind.begins_with("loadout_") and get_inventory_instance(target_slot) != null:
				return {"ok": false, "reason": "NO FREE SLOT"}
			return {"ok": true, "reason": ""}
		"loadout_weapon":
			return _can_equip_to_weapon(instance, int(target_key), origin_kind, origin_key)
		"loadout_skill":
			return _can_equip_to_skill(instance, int(target_key), origin_kind, origin_key)
		"loadout_gear":
			return _can_equip_to_gear(instance, String(target_key), origin_kind, origin_key)
	return {"ok": false, "reason": "INCOMPATIBLE SLOT"}


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
	var payload := {"instance_id": instance_id, "origin_kind": "inventory" if origin_slot >= 0 else "stash", "origin_key": origin_slot if origin_slot >= 0 else ""}
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
	return {
		"save_version": SAVE_VERSION,
		"owned_item_ids": owned_item_ids.duplicate(),
		"owned_item_instances": serialized_instances,
		"weapon_slots": weapon_slots.duplicate(),
		"weapon_instance_slots": weapon_instance_slots.duplicate(),
		"skill_slots": skill_slots.duplicate(),
		"equipped_gear": equipped_gear.duplicate(true),
		"equipped_gear_instances": equipped_gear_instances.duplicate(true),
		"main_inventory": main_inventory.duplicate(),
		"gold": gold,
	}


func apply_save_data(data: Dictionary, emit_signals: bool = true) -> bool:
	var incoming_version := int(data.get("save_version", -1))
	if incoming_version not in [1, 2, 3, SAVE_VERSION]:
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
	catalog_migrated_last_load = _ensure_development_catalog_owned()
	_rebuild_item_instances(data.get("owned_item_instances", []) if incoming_version >= 2 else [])
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
	gold = maxi(0, int(data.get("gold", 750)))
	equipped_gear = (incoming_gear as Dictionary).duplicate(true)
	equipped_gear_instances = (data.get("equipped_gear_instances", {}) as Dictionary).duplicate(true) if data.get("equipped_gear_instances", {}) is Dictionary else {}
	for key: String in GEAR_KEYS:
		if get_instance(String(equipped_gear_instances.get(key, ""))) == null:
			var instance := get_instance_for_definition(String(equipped_gear.get(key, "")))
			equipped_gear_instances[key] = instance.instance_id if instance != null else ""
	if incoming_version == 1:
		catalog_migrated_last_load = true
	var validation := validate_loadout()
	if not bool(validation.valid):
		last_error = "; ".join(validation.errors)
		return false
	last_error = ""
	last_load_used_defaults = false
	if emit_signals:
		profile_changed.emit()
		loadout_changed.emit()
	return true


func save_profile(path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "Unable to open profile for writing"
		return false
	file.store_string(JSON.stringify(to_save_data(), "  "))
	last_error = ""
	return true


func load_profile(path: String = SAVE_PATH, persist_fallback: bool = true) -> bool:
	if not FileAccess.file_exists(path):
		reset_to_defaults(false)
		last_load_used_defaults = true
		if persist_fallback:
			save_profile(path)
		return true
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = null
	if file != null:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			parsed = json.data
	if not parsed is Dictionary or not apply_save_data(parsed as Dictionary):
		var failure := last_error if not last_error.is_empty() else "Profile JSON is corrupt"
		reset_to_defaults(false)
		last_load_used_defaults = true
		last_error = failure
		if persist_fallback:
			save_profile(path)
		return false
	if catalog_migrated_last_load and persist_fallback:
		save_profile(path)
	return true


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


func _ensure_development_catalog_owned() -> bool:
	var changed := false
	for definition: ItemDefinition in ItemDatabase.DEFINITIONS:
		var item_id := String(definition.id)
		if item_id in DEVELOPMENT_STASH_EXCLUDED:
			continue
		if not owned_item_ids.has(item_id):
			owned_item_ids.append(item_id)
			changed = true
	return changed


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
