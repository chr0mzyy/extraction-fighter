class_name ItemDefinition
extends Resource

enum ItemType { WEAPON, SKILL, GEAR, CONSUMABLE, JUNK, KEY }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC, UNIQUE }
enum GearSlot { NONE, HELMET, CHEST, GLOVES, BOOTS, NECKLACE, RING, CHARM }

@export var id: StringName
@export var display_name: String = "Item"
@export_multiline var flavor_text: String = ""
@export_multiline var description: String = ""
@export var item_type: ItemType = ItemType.JUNK
@export var rarity: Rarity = Rarity.COMMON
@export var preview_icon: Texture2D
@export var sell_value: int = 0
@export var affix_ids: Array[StringName] = []
@export var affix_tiers: Array[int] = []

@export_group("Gameplay")
@export var gameplay_scene: PackedScene
@export var weapon_family: StringName
@export var power_cost: int = 0
@export var gear_slot: GearSlot = GearSlot.NONE
@export var armor_value: int = 0

@export_group("Weapon Tooltip Stats")
@export var damage: float = 0.0
@export var heavy_damage: float = 0.0
@export var fire_rate: float = 0.0
@export var attack_speed_label: String = ""
@export var magazine_size: int = 0
@export var reload_time: float = 0.0
@export var headshot_damage: float = 0.0
@export_range(0.0, 1.0, 0.01) var block_reduction: float = 0.0
@export var deflect_window: float = 0.0
@export var range_label: String = ""
@export_multiline var special_description: String = ""
@export var durability_max: int = 0

@export_group("Skill Tooltip Stats")
@export var cooldown: float = 0.0
@export var activation_method: String = ""

@export_group("Gear Tooltip Stats")
@export var modifier_text: String = ""

@export_group("Variant Identity")
@export var special_effect_id: StringName
@export var special_parameters: Dictionary = {}


func get_type_name() -> String:
	return ItemType.keys()[item_type].capitalize()


func get_rarity_name() -> String:
	return Rarity.keys()[rarity].capitalize()


func get_gear_slot_name() -> String:
	return GearSlot.keys()[gear_slot].capitalize()
