class_name KnightSwordWeapon
extends KatanaWeapon


func _ready() -> void:
	super._ready()
	weapon_display_name = "Knight Sword"
	light_damage = 34.0
	heavy_damage = 55.0
	light_recovery = 0.53
	heavy_recovery = 1.05
	heavy_windup = 0.24
	light_range = 2.45
	heavy_range = 3.0
	blocked_damage_multiplier = 0.2
	perfect_deflect_duration = 0.0


func get_damage_response(info: DamageInfo) -> Dictionary:
	if not equipped or not is_blocking:
		return {}
	if deflect_remaining > 0.0 and info.is_melee and item_definition != null and item_definition.special_effect_id == &"oathbreaker":
		effects.on_block(true)
		return {"negate": true, "stagger_attacker": true, "stagger_duration": 0.85}
	effects.on_block(false)
	return {"damage_multiplier": blocked_damage_multiplier}
