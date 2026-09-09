class_name ItemDatabase
extends RefCounted

const DEFINITIONS: Array[ItemDefinition] = [
	preload("res://resources/items/ronin_katana.tres"),
	preload("res://resources/items/huntsman_rifle.tres"),
	preload("res://resources/items/vanguard_rifle.tres"),
	preload("res://resources/items/knight_sword.tres"),
	preload("res://resources/items/dash.tres"),
	preload("res://resources/items/double_jump.tres"),
	preload("res://resources/items/grapple.tres"),
	preload("res://resources/items/blink.tres"),
	preload("res://resources/items/training_helmet.tres"),
	preload("res://resources/items/training_chest.tres"),
	preload("res://resources/items/training_gloves.tres"),
	preload("res://resources/items/training_boots.tres"),
	preload("res://resources/items/simple_necklace.tres"),
	preload("res://resources/items/simple_ring.tres"),
	preload("res://resources/items/iron_ring.tres"),
	preload("res://resources/items/basic_charm.tres"),
]


static func build_index() -> Dictionary:
	var result: Dictionary = {}
	for definition: ItemDefinition in DEFINITIONS:
		result[String(definition.id)] = definition
	return result
