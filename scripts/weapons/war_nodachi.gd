class_name WarNodachiWeapon
extends KatanaWeapon

@export var light_lunge: float = 4.5
@export var heavy_lunge: float = 8.0


func _ready() -> void:
	super._ready()
	weapon_display_name = "War Nodachi"
	light_damage = 38.0
	heavy_damage = 58.0
	light_range = 3.05
	heavy_range = 3.55
	light_recovery = 0.62
	heavy_recovery = 1.15
	heavy_windup = 0.24
	blocked_damage_multiplier = 0.45
	perfect_deflect_duration = 0.0


func request_primary() -> void:
	if equipped and recovery_remaining <= 0.0 and not is_blocking and is_instance_valid(wielder) and can_operate():
		_lunge(light_lunge)
	super.request_primary()


func request_heavy() -> void:
	if equipped and recovery_remaining <= 0.0 and not is_blocking and is_instance_valid(wielder) and can_operate():
		_lunge(heavy_lunge)
	super.request_heavy()


func get_damage_response(info: DamageInfo) -> Dictionary:
	if not equipped or not is_blocking or is_broken():
		return {}
	return {"damage_multiplier": blocked_damage_multiplier}


func _lunge(strength: float) -> void:
	if wielder.has_method("apply_weapon_lunge"):
		wielder.apply_weapon_lunge(strength * effects.get_lunge_multiplier())
