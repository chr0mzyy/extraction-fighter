extends Node

signal profile_changed
signal loadout_changed
signal validation_failed(message: String)

const SAVE_VERSION := 3
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


func _ready() -> void:
	item_index = ItemDatabase.build_index()
	load_profile()


func reset_to_defaults(save_after: bool = true) -> void:
	owned_item_ids.clear()
	owned_item_instances.clear()
	instance_index.clear()
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
	if not item_id.is_empty() and get_definition(item_id) == null:
		return _fail("Unknown inventory item")
	main_inventory[slot] = item_id
	profile_changed.emit()
	if save_after:
		save_profile()
	return true


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
	if incoming_version not in [1, 2, SAVE_VERSION]:
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
