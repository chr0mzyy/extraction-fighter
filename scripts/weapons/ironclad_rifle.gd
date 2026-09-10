class_name IroncladRifleWeapon
extends VanguardRifleWeapon


func _ready() -> void:
	super._ready()
	weapon_display_name = "Ironclad Rifle"
	automatic_fire = false
	magazine_size = 14
	ammo = magazine_size
	body_damage = 36.0
	headshot_damage = 54.0
	fire_delay = 0.36
	reload_duration = 2.25
	hipfire_spread_degrees = 1.05
	ads_spread_degrees = 0.16


func request_primary() -> void:
	var ammo_before := ammo
	super.request_primary()
	if ammo < ammo_before and is_instance_valid(wielder):
		var recoil_direction := -get_aim_direction()
		recoil_direction.y = 0.0
		wielder.velocity += recoil_direction.normalized() * 0.35


func get_weapon_status() -> String:
	return "RELOADING %.1fs" % reload_remaining if is_reloading else effect_status_or("BATTLE SEMI")
