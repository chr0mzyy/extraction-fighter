class_name FalconBurstWeapon
extends VanguardRifleWeapon

@export var burst_size: int = 3
@export var burst_interval: float = 0.075
@export var burst_delay: float = 0.48

var is_bursting: bool = false
var burst_serial: int = 0


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
	if not equipped or is_bursting or is_reloading or fire_cooldown_remaining > 0.0 or not is_instance_valid(wielder) or not can_operate():
		return
	if ammo <= 0:
		notify_dry_fire()
		return
	is_bursting = true
	burst_serial += 1
	fire_cooldown_remaining = burst_delay / effects.get_rate_multiplier()
	_fire_burst(burst_serial)


func _fire_burst(serial: int) -> void:
	for shot: int in burst_size:
		if not equipped or not is_bursting or serial != burst_serial or is_reloading or ammo <= 0 or not is_instance_valid(wielder):
			break
		ammo -= 1
		spend_shot_durability()
		effects.on_shot_fired()
		_fire_hitscan()
		state_changed.emit()
		if shot < burst_size - 1:
			await get_tree().create_timer(burst_interval / effects.get_rate_multiplier()).timeout
	is_bursting = false


func reset_weapon() -> void:
	super.reset_weapon()
	burst_serial += 1
	is_bursting = false


func cancel_combat() -> void:
	burst_serial += 1
	is_bursting = false
	super.cancel_combat()


func get_weapon_status() -> String:
	return "RELOADING %.1fs" % reload_remaining if is_reloading else effect_status_or("3-RND BURST")
