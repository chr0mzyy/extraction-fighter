class_name RunInventory
extends Node

signal changed

const SLOT_COUNT := 24
var slots: Array[ItemInstance] = []
var run_gold: int = 0


func _ready() -> void:
	clear()


func clear() -> void:
	slots.clear()
	slots.resize(SLOT_COUNT)
	for index: int in SLOT_COUNT:
		slots[index] = null
	run_gold = 0
	changed.emit()


func add_item(instance: ItemInstance) -> bool:
	if instance == null:
		return false
	for index: int in slots.size():
		if slots[index] == null:
			slots[index] = instance
			changed.emit()
			return true
	return false


func get_item(slot: int) -> ItemInstance:
	return slots[slot] if slot >= 0 and slot < slots.size() else null


func move_item(source_slot: int, target_slot: int) -> bool:
	if source_slot < 0 or source_slot >= slots.size() or target_slot < 0 or target_slot >= slots.size() or slots[source_slot] == null:
		return false
	var displaced := slots[target_slot]
	slots[target_slot] = slots[source_slot]
	slots[source_slot] = displaced
	changed.emit()
	return true


func remove_at(slot: int) -> ItemInstance:
	if slot < 0 or slot >= slots.size():
		return null
	var instance := slots[slot]
	if instance != null:
		slots[slot] = null
		changed.emit()
	return instance


func find_instance(instance_id: String) -> int:
	for slot: int in slots.size():
		if slots[slot] != null and slots[slot].instance_id == instance_id:
			return slot
	return -1


func add_gold(amount: int) -> void:
	run_gold += maxi(0, amount)
	changed.emit()


func has_definition(definition_id: StringName) -> bool:
	for instance: ItemInstance in slots:
		if instance != null and instance.definition_id == definition_id:
			return true
	return false


func consume_definition(definition_id: StringName) -> bool:
	for index: int in slots.size():
		var instance := slots[index]
		if instance != null and instance.definition_id == definition_id:
			slots[index] = null
			changed.emit()
			return true
	return false


func take_all_items() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for instance: ItemInstance in slots:
		if instance != null:
			result.append(instance)
	clear()
	return result


func item_count() -> int:
	var total := 0
	for instance: ItemInstance in slots:
		if instance != null:
			total += 1
	return total


func free_slots() -> int:
	return SLOT_COUNT - item_count()
