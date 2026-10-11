class_name ArenaWeaponGameplayDefinition
extends Resource

@export var family_id: StringName
@export var display_name: String = "Weapon"
@export_multiline var role: String = ""
@export_multiline var weakness: String = ""
@export var damage: float = 0.0
@export var heavy_damage: float = 0.0
@export var fire_rate: float = 0.0
@export var magazine_size: int = 0
@export var reload_time: float = 0.0
@export var headshot_damage: float = 0.0
@export var block_reduction: float = 0.0
@export var deflect_window: float = 0.0
@export var range_label: String = ""
@export var attack_speed_label: String = ""
@export var tuning: Dictionary = {}


func apply_to(cosmetic_item: ItemDefinition) -> ItemDefinition:
	if cosmetic_item == null:
		return null
	var resolved := cosmetic_item.duplicate(true) as ItemDefinition
	resolved.weapon_family = family_id
	resolved.damage = damage
	resolved.heavy_damage = heavy_damage
	resolved.fire_rate = fire_rate
	resolved.magazine_size = magazine_size
	resolved.reload_time = reload_time
	resolved.headshot_damage = headshot_damage
	resolved.block_reduction = block_reduction
	resolved.deflect_window = deflect_window
	resolved.range_label = range_label
	resolved.attack_speed_label = attack_speed_label
	resolved.special_parameters = tuning.duplicate(true)
	resolved.affix_ids = []
	resolved.affix_tiers = []
	resolved.special_effect_id = &""
	resolved.special_description = "Arena skin — normalized family statistics"
	resolved.arena_tradable = false
	resolved.permanently_protected = true
	resolved.durability_max = 0
	return resolved


func gameplay_fingerprint() -> Dictionary:
	return {
		"family": String(family_id),
		"damage": damage,
		"heavy_damage": heavy_damage,
		"fire_rate": fire_rate,
		"magazine_size": magazine_size,
		"reload_time": reload_time,
		"headshot_damage": headshot_damage,
		"block_reduction": block_reduction,
		"deflect_window": deflect_window,
		"tuning": tuning.duplicate(true),
	}
