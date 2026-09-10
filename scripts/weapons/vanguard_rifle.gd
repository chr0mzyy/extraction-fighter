class_name VanguardRifleWeapon
extends WeaponBase

@export var magazine_size: int = 30
@export var body_damage: float = 18.0
@export var headshot_damage: float = 27.0
@export var fire_delay: float = 0.111
@export var reload_duration: float = 2.0
@export var max_range: float = 190.0
@export var hipfire_spread_degrees: float = 0.9
@export var ads_spread_degrees: float = 0.18

var ammo: int = 30
var fire_cooldown_remaining: float = 0.0
var reload_remaining: float = 0.0
var is_reloading: bool = false
var is_ads: bool = false
var primary_held: bool = false
var random := RandomNumberGenerator.new()


func _ready() -> void:
	weapon_display_name = "Vanguard Rifle"
	automatic_fire = true
	ammo = magazine_size
	random.randomize()


func _process(delta: float) -> void:
	effects.tick(delta)
	fire_cooldown_remaining = maxf(0.0, fire_cooldown_remaining - delta)
	if is_reloading:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		if reload_remaining <= 0.0:
			is_reloading = false
			ammo = magazine_size
			effects.on_reload_completed()
			state_changed.emit()
	if automatic_fire and primary_held and equipped:
		request_primary()


func request_primary() -> void:
	if not equipped or is_reloading or fire_cooldown_remaining > 0.0 or not is_instance_valid(wielder) or not can_operate():
		return
	if ammo <= 0:
		if wielder.has_method("on_empty_weapon"):
			wielder.on_empty_weapon()
		return
	ammo -= 1
	spend_shot_durability()
	fire_cooldown_remaining = fire_delay / effects.get_rate_multiplier()
	effects.on_shot_fired()
	_fire_hitscan()
	state_changed.emit()


func _fire_hitscan() -> void:
	var origin := get_aim_origin()
	var direction := get_aim_direction().normalized()
	var spread := deg_to_rad((ads_spread_degrees if is_ads else hipfire_spread_degrees) * effects.get_spread_multiplier(is_ads))
	var right := direction.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	direction = direction.rotated(Vector3.UP, random.randf_range(-spread, spread))
	direction = direction.rotated(right, random.randf_range(-spread, spread)).normalized()
	if wielder.has_method("on_rifle_fired"):
		wielder.on_rifle_fired(is_ads)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_range, 1 | 2 | 4, get_query_exclusions())
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		effects.on_attack_missed()
		return
	var collider := hit.get("collider") as Node
	if collider != null and not collider.has_method("get_damage_receiver") and not collider.has_method("receive_damage"):
		var ricochet_hit := try_ricochet_hit(origin, hit, max_range)
		if not ricochet_hit.is_empty():
			hit = ricochet_hit
			collider = hit.get("collider") as Node
	var target: Node = null
	var was_headshot := false
	if collider != null and collider.has_method("get_damage_receiver"):
		target = collider.get_damage_receiver()
		was_headshot = bool(collider.is_headshot_hitbox())
	elif collider != null and collider.has_method("receive_damage"):
		target = collider
		if target.has_method("is_headshot_position"):
			was_headshot = bool(target.is_headshot_position(hit.get("position", target.global_position)))
	if target == null or target == wielder or not target.has_method("receive_damage"):
		effects.on_attack_missed()
		return
	var damage := headshot_damage if was_headshot else body_damage
	var info := make_damage_info(damage, target, &"vanguard_rifle", was_headshot, false, hit.get("position", target.global_position), direction * 1.1)
	resolve_damage(target, info)


func secondary_pressed() -> void:
	if equipped and not is_reloading:
		is_ads = true
		state_changed.emit()


func secondary_released() -> void:
	if is_ads:
		is_ads = false
		state_changed.emit()


func set_primary_held(held: bool) -> void:
	primary_held = held


func request_reload() -> void:
	if try_special_activation():
		return
	if not equipped or is_reloading or ammo >= magazine_size or not can_operate():
		return
	is_reloading = true
	is_ads = false
	primary_held = false
	reload_remaining = reload_duration / effects.get_reload_multiplier()
	if is_instance_valid(wielder) and wielder.has_method("on_reload_started"):
		wielder.on_reload_started()
	state_changed.emit()


func unequip() -> void:
	primary_held = false
	secondary_released()
	super.unequip()


func reset_weapon() -> void:
	ammo = magazine_size
	fire_cooldown_remaining = 0.0
	reload_remaining = 0.0
	is_reloading = false
	is_ads = false
	primary_held = false
	state_changed.emit()


func is_aiming_down_sights() -> bool:
	return is_ads


func uses_ammunition() -> bool:
	return true


func get_ammo_text() -> String:
	return "%d / %d" % [ammo, magazine_size]


func get_weapon_status() -> String:
	return "RELOADING %.1fs" % reload_remaining if is_reloading else effect_status_or("AUTO")
