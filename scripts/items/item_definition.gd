class_name ItemDefinition
extends Resource

enum ItemType { WEAPON, SKILL, GEAR, CONSUMABLE, JUNK, KEY }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC, UNIQUE }
enum GearSlot { NONE, HELMET, CHEST, GLOVES, BOOTS, NECKLACE, RING, CHARM }

@export var id: StringName
@export var display_name: String = "Item"
@export_multiline var description: String = ""
@export var item_type: ItemType = ItemType.JUNK
@export var rarity: Rarity = Rarity.COMMON
@export var sell_value: int = 0
@export var affix_ids: Array[StringName] = []

@export_group("Gameplay")
@export var gameplay_scene: PackedScene
@export var weapon_family: StringName
@export var power_cost: int = 0
@export var gear_slot: GearSlot = GearSlot.NONE
@export var armor_value: int = 0


func get_type_name() -> String:
	return ItemType.keys()[item_type].capitalize()


func get_rarity_name() -> String:
	return Rarity.keys()[rarity].capitalize()


func get_gear_slot_name() -> String:
	return GearSlot.keys()[gear_slot].capitalize()
