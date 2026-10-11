class_name WeaponCosmeticDefinition
extends Resource

@export var skin_id: StringName
@export var display_name: String = "Skin"
@export var weapon_family: StringName
@export var cosmetic_rarity: ItemDefinition.Rarity = ItemDefinition.Rarity.COMMON
@export_multiline var flavor_text: String = ""
@export var preview_icon: Texture2D
@export var model_scene: PackedScene
@export var source_definition_id: StringName


static func from_legacy_item(definition: ItemDefinition) -> WeaponCosmeticDefinition:
	var cosmetic := WeaponCosmeticDefinition.new()
	if definition == null:
		return cosmetic
	cosmetic.skin_id = definition.id
	cosmetic.display_name = definition.display_name
	cosmetic.weapon_family = definition.weapon_family
	cosmetic.cosmetic_rarity = definition.rarity
	cosmetic.flavor_text = definition.flavor_text
	cosmetic.preview_icon = definition.preview_icon
	cosmetic.model_scene = definition.gameplay_scene
	cosmetic.source_definition_id = definition.id
	return cosmetic
