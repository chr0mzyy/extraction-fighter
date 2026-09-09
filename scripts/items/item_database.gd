class_name ItemDatabase
extends RefCounted

const DEFINITIONS: Array[ItemDefinition] = [
	preload("res://resources/items/ronin_katana.tres"),
	preload("res://resources/items/war_nodachi.tres"),
	preload("res://resources/items/huntsman_rifle.tres"),
	preload("res://resources/items/vanguard_rifle.tres"),
	preload("res://resources/items/falcon_burst.tres"),
	preload("res://resources/items/ironclad_rifle.tres"),
	preload("res://resources/items/knight_sword.tres"),
	preload("res://resources/items/arcane_wand.tres"),
	preload("res://resources/items/service_glock.tres"),
	preload("res://resources/items/twin_glock.tres"),
	preload("res://resources/items/dash.tres"),
	preload("res://resources/items/double_jump.tres"),
	preload("res://resources/items/grapple.tres"),
	preload("res://resources/items/blink.tres"),
	preload("res://resources/items/wallrun.tres"),
	preload("res://resources/items/air_dash.tres"),
	preload("res://resources/items/launch.tres"),
	preload("res://resources/items/ground_slam.tres"),
	preload("res://resources/items/invisibility.tres"),
	preload("res://resources/items/smoke_veil.tres"),
	preload("res://resources/items/training_helmet.tres"),
	preload("res://resources/items/training_chest.tres"),
	preload("res://resources/items/training_gloves.tres"),
	preload("res://resources/items/training_boots.tres"),
	preload("res://resources/items/simple_necklace.tres"),
	preload("res://resources/items/simple_ring.tres"),
	preload("res://resources/items/iron_ring.tres"),
	preload("res://resources/items/basic_charm.tres"),
	preload("res://resources/items/rusted_helmet.tres"),
	preload("res://resources/items/knight_helmet.tres"),
	preload("res://resources/items/void_crown.tres"),
	preload("res://resources/items/torn_mail.tres"),
	preload("res://resources/items/knight_plate.tres"),
	preload("res://resources/items/void_plate.tres"),
	preload("res://resources/items/worn_gloves.tres"),
	preload("res://resources/items/duelist_gloves.tres"),
	preload("res://resources/items/void_grip.tres"),
	preload("res://resources/items/old_boots.tres"),
	preload("res://resources/items/ranger_boots.tres"),
	preload("res://resources/items/voidstep_boots.tres"),
	preload("res://resources/items/copper_necklace.tres"),
	preload("res://resources/items/hunter_necklace.tres"),
	preload("res://resources/items/void_pendant.tres"),
	preload("res://resources/items/void_ring.tres"),
	preload("res://resources/items/wooden_charm.tres"),
	preload("res://resources/items/soldier_charm.tres"),
	preload("res://resources/items/void_charm.tres"),
]


static func build_index() -> Dictionary:
	var result: Dictionary = {}
	for definition: ItemDefinition in DEFINITIONS:
		result[String(definition.id)] = definition
	return result
