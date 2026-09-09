class_name ServiceGlockWeapon
extends VanguardRifleWeapon


func _ready() -> void:
	super._ready()
	weapon_display_name = "Service Glock"
	automatic_fire = false
	magazine_size = 17
	ammo = magazine_size
	body_damage = 20.0
	headshot_damage = 30.0
	fire_delay = 0.16
	reload_duration = 1.35
	max_range = 105.0
	hipfire_spread_degrees = 0.55
	ads_spread_degrees = 0.20


func get_weapon_status() -> String:
	return "RELOADING %.1fs" % reload_remaining if is_reloading else "SEMI"
