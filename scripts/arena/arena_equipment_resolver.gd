class_name ArenaEquipmentResolver
extends RefCounted

const FAMILY_ORDER: Array[StringName] = [
	&"katana", &"nodachi", &"sniper", &"assault_rifle", &"burst_rifle",
	&"battle_rifle", &"sword", &"magic", &"pistol", &"akimbo_pistols",
]
const DEFAULT_SKINS := {
	&"katana": &"rusty_katana",
	&"nodachi": &"chipped_nodachi",
	&"sniper": &"cracked_long_rifle",
	&"assault_rifle": &"worn_assault_rifle",
	&"burst_rifle": &"damaged_burst_rifle",
	&"battle_rifle": &"rusty_battle_rifle",
	&"sword": &"chipped_sword",
	&"magic": &"cracked_wand",
	&"pistol": &"worn_glock",
	&"akimbo_pistols": &"scuffed_akimbo",
}
const SKILL_IDS: Array[String] = [
	"dash", "double_jump", "wallrun", "smoke_veil", "air_dash",
	"launch", "grapple", "ground_slam", "blink", "invisibility",
]
const WEAPON_SKIN_IDS: Array[String] = [
	"rusty_katana", "ronin_katana", "phantom_katana",
	"chipped_nodachi", "war_nodachi", "bloodrush_nodachi",
	"cracked_long_rifle", "huntsman_rifle", "skybreaker",
	"worn_assault_rifle", "vanguard_rifle", "rushfang",
	"damaged_burst_rifle", "falcon_burst", "trident",
	"rusty_battle_rifle", "ironclad_rifle", "kingslayer",
	"chipped_sword", "knight_sword", "oathbreaker",
	"cracked_wand", "arcane_wand", "rift_wand",
	"worn_glock", "service_glock", "quickfang",
	"scuffed_akimbo", "twin_glock", "hell_twins",
]

static var _gameplay: Dictionary = {}
static var _cosmetics: Dictionary = {}


static func gameplay_definition(family: StringName) -> ArenaWeaponGameplayDefinition:
	_ensure_catalogs()
	return _gameplay.get(family) as ArenaWeaponGameplayDefinition


static func cosmetic_definition(skin_id: StringName) -> WeaponCosmeticDefinition:
	_ensure_catalogs()
	return _cosmetics.get(skin_id) as WeaponCosmeticDefinition


static func cosmetics_for_family(family: StringName) -> Array[WeaponCosmeticDefinition]:
	_ensure_catalogs()
	var result: Array[WeaponCosmeticDefinition] = []
	for cosmetic: WeaponCosmeticDefinition in _cosmetics.values():
		if cosmetic.weapon_family == family:
			result.append(cosmetic)
	result.sort_custom(func(a: WeaponCosmeticDefinition, b: WeaponCosmeticDefinition) -> bool:
		if a.cosmetic_rarity == b.cosmetic_rarity:
			return a.display_name.naturalnocasecmp_to(b.display_name) < 0
		return a.cosmetic_rarity < b.cosmetic_rarity
	)
	return result


static func all_skill_ids() -> Array[String]:
	return SKILL_IDS.duplicate()


static func default_skin_for_family(family: StringName) -> StringName:
	return StringName(String(DEFAULT_SKINS.get(family, &"")))


static func is_valid_skin_for_family(skin_id: StringName, family: StringName) -> bool:
	var cosmetic := cosmetic_definition(skin_id)
	return cosmetic != null and cosmetic.weapon_family == family


static func resolve_item(family: StringName, skin_id: StringName) -> ItemDefinition:
	_ensure_catalogs()
	var gameplay_definition_value := gameplay_definition(family)
	var cosmetic := cosmetic_definition(skin_id)
	if cosmetic == null or cosmetic.weapon_family != family:
		cosmetic = cosmetic_definition(default_skin_for_family(family))
	if gameplay_definition_value == null or cosmetic == null:
		return null
	var source := _item_index().get(String(cosmetic.source_definition_id)) as ItemDefinition
	return gameplay_definition_value.apply_to(source)


static func gameplay_fingerprint(family: StringName, skin_id: StringName) -> Dictionary:
	var resolved := resolve_item(family, skin_id)
	if resolved == null:
		return {}
	return {
		"family": String(resolved.weapon_family),
		"damage": resolved.damage,
		"heavy_damage": resolved.heavy_damage,
		"fire_rate": resolved.fire_rate,
		"magazine_size": resolved.magazine_size,
		"reload_time": resolved.reload_time,
		"headshot_damage": resolved.headshot_damage,
		"block_reduction": resolved.block_reduction,
		"deflect_window": resolved.deflect_window,
		"tuning": resolved.special_parameters.duplicate(true),
		"affixes": resolved.affix_ids.duplicate(),
		"special": String(resolved.special_effect_id),
	}


static func _ensure_catalogs() -> void:
	if not _gameplay.is_empty() and not _cosmetics.is_empty():
		return
	_gameplay.clear()
	_cosmetics.clear()
	_add_gameplay(&"katana", "Katana", "Fast deflect blade", "Short reach", 28.0, 45.0, 0.0, 0, 0.0, 0.0, 0.70, 0.18, "Short", "Fast", {"light_recovery": 0.48, "heavy_recovery": 0.92})
	_add_gameplay(&"nodachi", "Nodachi", "Reach and heavy pressure", "Slow recovery", 38.0, 58.0, 0.0, 0, 0.0, 0.0, 0.55, 0.0, "Long Melee", "Slow", {"light_recovery": 0.72, "heavy_recovery": 1.24, "light_lunge": 4.2, "heavy_lunge": 7.0})
	_add_gameplay(&"sniper", "Sniper Rifle", "Precision burst damage", "Misses expose a long recovery", 58.0, 0.0, 1.05, 4, 1.8, 90.0, 0.0, 0.0, "Extreme", "", {"hipfire_spread_degrees": 1.15})
	_add_gameplay(&"assault_rifle", "Assault Rifle", "Versatile automatic pressure", "Average at every range", 17.0, 0.0, 8.5, 30, 2.05, 26.0, 0.0, 0.0, "Medium", "", {"hipfire_spread_degrees": 1.0, "ads_spread_degrees": 0.22})
	_add_gameplay(&"burst_rifle", "Burst Rifle", "Accurate burst rhythm", "Punished between bursts", 18.0, 0.0, 6.25, 24, 1.95, 29.0, 0.0, 0.0, "Medium–Long", "", {"burst_delay": 0.58, "hipfire_spread_degrees": 1.0, "ads_spread_degrees": 0.2})
	_add_gameplay(&"battle_rifle", "Battle Rifle", "High damage per controlled shot", "Heavy recoil and small magazine", 34.0, 0.0, 2.7, 14, 2.3, 52.0, 0.0, 0.0, "Long", "", {"hipfire_spread_degrees": 1.45, "ads_spread_degrees": 0.25})
	_add_gameplay(&"sword", "Knight Sword", "Defensive guard and parry", "Limited chase reach", 32.0, 50.0, 0.0, 0, 0.0, 0.0, 0.78, 0.15, "Short", "Measured", {"light_recovery": 0.58, "heavy_recovery": 1.15, "heavy_windup": 0.30})
	_add_gameplay(&"magic", "Magic Wand", "Visible prediction projectile", "Projectile can be dodged", 30.0, 0.0, 2.0, 0, 0.0, 0.0, 0.0, 0.0, "Medium", "Moderate", {"projectile_speed": 31.0})
	_add_gameplay(&"pistol", "Glock", "Mobile responsive sidearm", "Low burst at long range", 20.0, 0.0, 6.25, 17, 1.35, 30.0, 0.0, 0.0, "Close–Medium", "", {"hipfire_spread_degrees": 0.9})
	_add_gameplay(&"akimbo_pistols", "Akimbo Glock", "Close-range pressure", "Wide spread and no ADS", 14.0, 0.0, 9.2, 34, 2.3, 21.0, 0.0, 0.0, "Close", "", {"hipfire_spread_degrees": 1.85})
	for skin_id: String in WEAPON_SKIN_IDS:
		var definition := load("res://resources/items/%s.tres" % skin_id) as ItemDefinition
		if definition != null and definition.item_type == ItemDefinition.ItemType.WEAPON and definition.weapon_family in FAMILY_ORDER:
			_cosmetics[definition.id] = WeaponCosmeticDefinition.from_legacy_item(definition)


static func _add_gameplay(
		family: StringName, label: String, role: String, weakness: String,
		damage: float, heavy_damage: float, fire_rate: float, magazine: int,
		reload_time: float, headshot_damage: float, block_reduction: float,
		deflect_window: float, range_label: String, speed_label: String,
		tuning: Dictionary
) -> void:
	var definition := ArenaWeaponGameplayDefinition.new()
	definition.family_id = family
	definition.display_name = label
	definition.role = role
	definition.weakness = weakness
	definition.damage = damage
	definition.heavy_damage = heavy_damage
	definition.fire_rate = fire_rate
	definition.magazine_size = magazine
	definition.reload_time = reload_time
	definition.headshot_damage = headshot_damage
	definition.block_reduction = block_reduction
	definition.deflect_window = deflect_window
	definition.range_label = range_label
	definition.attack_speed_label = speed_label
	definition.tuning = tuning.duplicate(true)
	_gameplay[family] = definition


static func _item_index() -> Dictionary:
	var result: Dictionary = {}
	for skin_id: String in WEAPON_SKIN_IDS:
		var definition := load("res://resources/items/%s.tres" % skin_id) as ItemDefinition
		if definition != null:
			result[skin_id] = definition
	return result
