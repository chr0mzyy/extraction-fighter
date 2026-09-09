class_name FalconBurstWeapon
extends VanguardRifleWeapon

@export var burst_size: int = 3
@export var burst_interval: float = 0.075
@export var burst_delay: float = 0.48

var is_bursting: bool = false


func _ready() -> void:
	super._ready()
	weapon_display_name = "Falcon Burst"
	automatic_fire = false
	magazine_size = 24
	ammo = magazine_size
	body_damage = 19.0
	headshot_damage = 31.0
	fire_delay = burst_delay
	reload_duration = 1.9
	hipfire_spread_degrees = 0.55
	ads_spread_degrees = 0.10


func request_primary() -> void:
	if not equipped or is_bursting or is_reloading or fire_cooldown_remaining > 0.0 or not is_instance_valid(wielder):
		return
	if ammo <= 0:
		if wielder.has_method("on_empty_weapon"):
			wielder.on_empty_weapon()
		return
	is_bursting = true
	fire_cooldown_remaining = burst_delay
	_fire_burst()


func _fire_burst() -> void:
	for shot: int in burst_size:
		if not equipped or is_reloading or ammo <= 0 or not is_instance_valid(wielder):
			break
		ammo -= 1
		_fire_hitscan()
		state_changed.emit()
		if shot < burst_size - 1:
			await get_tree().create_timer(burst_interval).timeout
	is_bursting = false


func reset_weapon() -> void:
	super.reset_weapon()
	is_bursting = false


func get_weapon_status() -> String:
	return "RELOADING %.1fs" % reload_remaining if is_reloading else "3-RND BURST"
