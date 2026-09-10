class_name TwinGlockWeapon
extends VanguardRifleWeapon


func _ready() -> void:
	super._ready()
	weapon_display_name = "Twin Glocks"
	automatic_fire = true
	magazine_size = 34
	ammo = magazine_size
	body_damage = 15.0
	headshot_damage = 22.0
	fire_delay = 0.105
	reload_duration = 2.25
	max_range = 80.0
	hipfire_spread_degrees = 1.55
	ads_spread_degrees = hipfire_spread_degrees


func secondary_pressed() -> void:
	pass


func secondary_released() -> void:
	is_ads = false


func get_weapon_status() -> String:
	return "RELOADING %.1fs" % reload_remaining if is_reloading else effect_status_or("AKIMBO")
