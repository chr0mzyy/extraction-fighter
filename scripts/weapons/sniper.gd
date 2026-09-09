class_name SniperWeapon
extends WeaponBase

@export var magazine_size: int = 4
@export var body_damage: float = 60.0
@export var headshot_damage: float = 110.0
@export var fire_delay: float = 0.9
@export var reload_duration: float = 1.7
@export var max_range: float = 250.0
@export var hipfire_spread_degrees: float = 0.65

var ammo: int = 4
var fire_cooldown_remaining: float = 0.0
var reload_remaining: float = 0.0
var is_reloading: bool = false
var is_ads: bool = false
var random := RandomNumberGenerator.new()


func _ready() -> void:
	weapon_display_name = "Sniper Rifle"
	ammo = magazine_size
	random.randomize()


func _process(delta: float) -> void:
	fire_cooldown_remaining = maxf(0.0, fire_cooldown_remaining - delta)
	if is_reloading:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		if reload_remaining <= 0.0:
			is_reloading = false
			ammo = magazine_size
			state_changed.emit()


func request_primary() -> void:
	if not equipped or is_reloading or fire_cooldown_remaining > 0.0 or not is_instance_valid(wielder):
		return
	if ammo <= 0:
		if wielder.has_method("on_empty_weapon"):
			wielder.on_empty_weapon()
		return
	ammo -= 1
	fire_cooldown_remaining = fire_delay
	fire_hitscan()
	state_changed.emit()


func fire_hitscan() -> void:
	var origin := get_aim_origin()
	var direction := get_aim_direction().normalized()
	if not is_ads:
		var spread := deg_to_rad(hipfire_spread_degrees)
		var yaw_error := random.randf_range(-spread, spread)
		var pitch_error := random.randf_range(-spread, spread)
		var right := direction.cross(Vector3.UP).normalized()
		if right.length_squared() < 0.01:
			right = Vector3.RIGHT
		direction = direction.rotated(Vector3.UP, yaw_error).rotated(right, pitch_error).normalized()

	if wielder.has_method("on_sniper_fired"):
		wielder.on_sniper_fired(is_ads)

	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_range, 1 | 2 | 4, get_query_exclusions())
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider := hit.get("collider") as Node
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
		return
	var damage := headshot_damage if was_headshot else body_damage
	var info := DamageInfo.new(
		damage,
		wielder,
		&"sniper",
		was_headshot,
		false,
		hit.get("position", target.global_position),
		direction * 2.5
	)
	var result: Dictionary = target.receive_damage(info)
	if float(result.get("applied", 0.0)) > 0.0:
		hit_confirmed.emit(was_headshot)


func secondary_pressed() -> void:
	if equipped and not is_reloading:
		is_ads = true
		state_changed.emit()


func secondary_released() -> void:
	if is_ads:
		is_ads = false
		state_changed.emit()


func request_reload() -> void:
	if not equipped or is_reloading or ammo >= magazine_size:
		return
	is_reloading = true
	is_ads = false
	reload_remaining = reload_duration
	if is_instance_valid(wielder) and wielder.has_method("on_reload_started"):
		wielder.on_reload_started()
	state_changed.emit()


func unequip() -> void:
	secondary_released()
	super.unequip()


func reset_weapon() -> void:
	ammo = magazine_size
	fire_cooldown_remaining = 0.0
	reload_remaining = 0.0
	is_reloading = false
	is_ads = false
	state_changed.emit()
