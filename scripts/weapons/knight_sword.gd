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


func get_damage_response(_info: DamageInfo) -> Dictionary:
	if not equipped or not is_blocking:
		return {}
	return {"damage_multiplier": blocked_damage_multiplier}
