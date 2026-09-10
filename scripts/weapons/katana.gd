class_name KatanaWeapon
extends WeaponBase

@export_group("Light Attack")
@export var light_damage: float = 28.0
@export var light_range: float = 2.35
@export var light_recovery: float = 0.42
@export_group("Heavy Attack")
@export var heavy_damage: float = 45.0
@export var heavy_range: float = 2.85
@export var heavy_recovery: float = 0.9
@export var heavy_windup: float = 0.18
@export_group("Defense")
@export_range(0.0, 1.0) var blocked_damage_multiplier: float = 0.3
@export var perfect_deflect_duration: float = 0.18

var recovery_remaining: float = 0.0
var deflect_remaining: float = 0.0
var is_blocking: bool = false
var attack_serial: int = 0
var base_rotation: Vector3
var swing_remaining: float = 0.0
var swing_total: float = 0.24
var swing_strength: float = 0.85


func _ready() -> void:
	weapon_display_name = "Katana"
	base_rotation = rotation


func _process(delta: float) -> void:
	effects.tick(delta)
	recovery_remaining = maxf(0.0, recovery_remaining - delta)
	deflect_remaining = maxf(0.0, deflect_remaining - delta)
	swing_remaining = maxf(0.0, swing_remaining - delta)
	var swing_offset := 0.0
	if swing_remaining > 0.0:
		var swing_progress := 1.0 - swing_remaining / swing_total
		swing_offset = sin(swing_progress * PI) * swing_strength
	var target_roll := -0.75 if is_blocking and equipped else 0.0
	rotation.z = lerpf(rotation.z, base_rotation.z + target_roll, minf(1.0, delta * 18.0))
	rotation.y = lerpf(rotation.y, base_rotation.y + swing_offset, minf(1.0, delta * 28.0))
	rotation.x = lerpf(rotation.x, base_rotation.x - swing_offset * 0.18, minf(1.0, delta * 24.0))


func request_primary() -> void:
	if not equipped or recovery_remaining > 0.0 or is_blocking or not is_instance_valid(wielder) or not can_operate():
		return
	recovery_remaining = light_recovery / effects.get_rate_multiplier()
	effects.on_shot_fired()
	attack_serial += 1
	swing_total = 0.24
	swing_remaining = swing_total
	swing_strength = 0.9
	if wielder.has_method("on_melee_swing"):
		wielder.on_melee_swing(false)
	perform_attack(light_damage, light_range, false, attack_serial)
	state_changed.emit()


func request_heavy() -> void:
	if not equipped or recovery_remaining > 0.0 or is_blocking or not is_instance_valid(wielder) or not can_operate():
		return
	recovery_remaining = heavy_recovery / effects.get_rate_multiplier()
	effects.on_shot_fired()
	attack_serial += 1
	swing_total = 0.46
	swing_remaining = swing_total
	swing_strength = 1.35
	var this_attack := attack_serial
	if wielder.has_method("on_melee_swing"):
		wielder.on_melee_swing(true)
	state_changed.emit()
	var special_lunge := effects.get_lunge_multiplier()
	if item_definition != null and item_definition.special_effect_id == &"oathbreaker" and special_lunge > 1.0 and wielder.has_method("apply_weapon_lunge"):
		wielder.apply_weapon_lunge(4.5 * special_lunge)
	await get_tree().create_timer(heavy_windup * effects.get_heavy_windup_multiplier()).timeout
	if equipped and is_instance_valid(wielder) and not bool(wielder.get("is_dead")) and this_attack == attack_serial:
		perform_attack(heavy_damage, heavy_range, true, this_attack)


func secondary_pressed() -> void:
	if not equipped or not is_instance_valid(wielder) or not can_operate():
		return
	if not is_blocking:
		is_blocking = true
		deflect_remaining = perfect_deflect_duration
		if wielder.has_method("on_block_started"):
			wielder.on_block_started()
		state_changed.emit()


func secondary_released() -> void:
	if is_blocking:
		is_blocking = false
		deflect_remaining = 0.0
		state_changed.emit()


func get_damage_response(info: DamageInfo) -> Dictionary:
	if not equipped or not is_blocking or is_broken():
		return {}
	if deflect_remaining > 0.0:
		effects.on_block(true)
		return {
			"negate": true,
			"reflect": not info.is_melee,
			"stagger_attacker": info.is_melee,
			"stagger_duration": 0.7
		}
	effects.on_block(false)
	return {"damage_multiplier": blocked_damage_multiplier}


func perform_attack(damage: float, attack_range: float, heavy: bool, _serial: int) -> void:
	var origin: Vector3 = wielder.get_melee_origin() if wielder.has_method("get_melee_origin") else get_aim_origin()
	var direction: Vector3 = get_aim_direction().normalized()
	var sphere := SphereShape3D.new()
	sphere.radius = attack_range * 0.46
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, origin + direction * attack_range * 0.56)
	query.collision_mask = 2
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = get_query_exclusions()
	var results := get_world_3d().direct_space_state.intersect_shape(query, 16)
	var hit_ids: Dictionary = {}
	for result: Dictionary in results:
		var target := result.get("collider") as Node
		if target == null or target == wielder or not target.has_method("receive_damage"):
			continue
		var target_id := target.get_instance_id()
		if hit_ids.has(target_id):
			continue
		var target_3d := target as Node3D
		if target_3d == null:
			continue
		var to_target: Vector3 = target_3d.global_position - origin
		if to_target.length() > attack_range + 0.8 or direction.dot(to_target.normalized()) < 0.05:
			continue
		hit_ids[target_id] = true
		var horizontal_knockback := direction
		horizontal_knockback.y = 0.18 if heavy else 0.05
		horizontal_knockback = horizontal_knockback.normalized() * (7.0 if heavy else 2.4)
		if heavy and effects.has(&"crusher"):
			horizontal_knockback *= 1.0 + effects.value(&"crusher") / 100.0
		var info := make_damage_info(
			damage,
			target,
			&"katana_heavy" if heavy else &"katana_light",
			false,
			true,
			target_3d.global_position,
			horizontal_knockback
		)
		if heavy and effects.has(&"crusher") and target.has_method("apply_stagger"):
			target.apply_stagger(0.15 + effects.value(&"crusher") * 0.01)
		resolve_damage(target, info, heavy)
	if hit_ids.is_empty():
		effects.on_attack_missed()


func unequip() -> void:
	secondary_released()
	super.unequip()


func reset_weapon() -> void:
	attack_serial += 1
	recovery_remaining = 0.0
	swing_remaining = 0.0
	secondary_released()
	rotation = base_rotation
