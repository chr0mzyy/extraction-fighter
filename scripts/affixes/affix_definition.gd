class_name AffixDefinition
extends Resource

var id: StringName
var display_name: String = "Affix"
var description: String = ""
var category: StringName
var allowed_item_types: Array[int] = []
var allowed_weapon_families: Array[StringName] = []
var tier_values: Array[float] = [0.0, 0.0, 0.0]
var secondary_values: Array[float] = [0.0, 0.0, 0.0]
var effect_key: StringName
var requires_magazine: bool = false


func value_for_tier(tier: int) -> float:
	return tier_values[clampi(tier, 1, 3) - 1]


func secondary_for_tier(tier: int) -> float:
	return secondary_values[clampi(tier, 1, 3) - 1]


func is_compatible(item: ItemDefinition) -> bool:
	if item == null or not allowed_item_types.has(item.item_type):
		return false
	if item.item_type == ItemDefinition.ItemType.WEAPON and not allowed_weapon_families.is_empty() and not allowed_weapon_families.has(item.weapon_family):
		return false
	if requires_magazine and item.magazine_size <= 0:
		return false
	return true


func formatted_description(tier: int) -> String:
	return description.replace("{value}", _format_value(value_for_tier(tier))).replace("{secondary}", _format_value(secondary_for_tier(tier)))


func _format_value(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
