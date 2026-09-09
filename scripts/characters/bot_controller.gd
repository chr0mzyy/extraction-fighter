class_name BotController
extends CharacterBody3D

signal actor_died(actor: Node, info: DamageInfo)
signal feedback(event_name: StringName, data: Dictionary)

@export_group("Movement")
@export var move_speed: float = 6.2
@export var acceleration: float = 22.0
@export var jump_velocity: float = 6.5
@export var gravity: float = 18.0
@export_group("AI")
@export var reaction_time: float = 0.32
@export var aim_error: float = 0.32
@export_range(0.0, 1.0) var aggression: float = 0.62
@export var preferred_sniper_range: float = 15.0
@export var melee_switch_threshold: float = 4.4
@export_range(0.0, 1.0) var dash_probability: float = 0.13
@export_range(0.0, 1.0) var jump_probability: float = 0.08
@export_range(0.0, 1.0) var block_probability: float = 0.19
@export_range(0.0, 1.0) var heavy_attack_probability: float = 0.3

@onready var health: HealthComponent = $HealthComponent
@onready var head_hurtbox: Hurtbox3D = $HeadHurtbox
@onready var visual_body: MeshInstance3D = $VisualBody
@onready var aim_pivot: Node3D = $AimPivot
@onready var weapon_mount: Node3D = $AimPivot/WeaponMount
@onready var dash_skill: DashSkill = $DashSkill

var weapons: Array[WeaponBase] = []
var current_weapon: WeaponBase
var current_weapon_index: int = 0
var target: Node3D
var is_dead: bool = false
var spawn_transform: Transform3D
var ai_state: String = "SPAWNING"
var reaction_remaining: float = 0.0
var action_remaining: float = 0.0
var strafe_sign: float = 1.0
var desired_aim_direction: Vector3 = Vector3.FORWARD
var aim_direction: Vector3 = Vector3.FORWARD
var move_direction: Vector3 = Vector3.ZERO
var stagger_remaining: float = 0.0
var block_remaining: float = 0.0
var random := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("bot")
	spawn_transform = global_transform
	random.randomize()
	for child in weapon_mount.get_children():
		if child is WeaponBase:
			var weapon := child as WeaponBase
			weapons.append(weapon)
			weapon.setup(self)
			weapon.unequip()
	health.died.connect(_on_health_died)
	equip_weapon(1)
	aim_direction = -global_basis.z
	desired_aim_direction = aim_direction
	reaction_remaining = reaction_time


func set_target(new_target: Node3D) -> void:
	target = new_target


func _physics_process(delta: float) -> void:
	dash_skill.tick(delta)
	stagger_remaining = maxf(0.0, stagger_remaining - delta)
	reaction_remaining -= delta
	action_remaining -= delta
	block_remaining -= delta
	if is_dead:
		velocity = Vector3.ZERO
		return
	if not is_instance_valid(target) or bool(target.get("is_dead")):
		_apply_gravity_and_move(delta, Vector3.ZERO)
		ai_state = "SEARCH"
		return

	_update_aim(delta)
	if reaction_remaining <= 0.0:
		reaction_remaining = reaction_time * random.randf_range(0.75, 1.35)
		_make_decision()
	_handle_block_timer()
	_apply_gravity_and_move(delta, move_direction)


func _make_decision() -> void:
	var offset := target.global_position - global_position
	var distance := offset.length()
	var toward := Vector3(offset.x, 0.0, offset.z).normalized()
	var strafe := Vector3(-toward.z, 0.0, toward.x) * strafe_sign
	if action_remaining <= 0.0:
		strafe_sign = -strafe_sign if random.randf() < 0.62 else strafe_sign
		action_remaining = random.randf_range(0.7, 1.7)

	if distance <= melee_switch_threshold:
		ai_state = "MELEE_PRESSURE"
		equip_weapon(0)
		move_direction = (toward * 0.55 + strafe * 0.8).normalized()
		if random.randf() < block_probability and block_remaining <= 0.0:
			current_weapon.secondary_pressed()
			block_remaining = random.randf_range(0.28, 0.8)
		elif block_remaining <= 0.0:
			current_weapon.secondary_released()
			if random.randf() < heavy_attack_probability:
				current_weapon.request_heavy()
			else:
				current_weapon.request_primary()
	elif distance < preferred_sniper_range * 0.72:
		ai_state = "REPOSITION"
		equip_weapon(1)
		move_direction = (-toward * 0.72 + strafe * 0.72).normalized()
		_try_sniper_action(distance)
	else:
		ai_state = "SNIPER_STRAFE"
		equip_weapon(1)
		var approach := toward * (0.28 if distance > preferred_sniper_range * 1.35 else 0.0)
		move_direction = (strafe * 0.82 + approach).normalized()
		_try_sniper_action(distance)

	if random.randf() < dash_probability:
		var dash_direction := move_direction if move_direction.length_squared() > 0.01 else toward
		if dash_skill.try_activate(dash_direction):
			ai_state = "DASH_REPOSITION"
	if is_on_floor() and random.randf() < jump_probability:
		velocity.y = jump_velocity


func _try_sniper_action(distance: float) -> void:
	var sniper := current_weapon as SniperWeapon
	if sniper == null:
		return
	if sniper.ammo <= 0:
		sniper.request_reload()
		ai_state = "RELOAD"
		return
	if sniper.is_reloading:
		return
	var accuracy_requirement := 0.965 if distance > 24.0 else 0.93
	var true_direction := (target.global_position + Vector3.UP * 1.2 - get_aim_origin()).normalized()
	if aim_direction.dot(true_direction) > accuracy_requirement and random.randf() < aggression:
		sniper.secondary_pressed()
		sniper.request_primary()
		sniper.secondary_released()


func _update_aim(delta: float) -> void:
	var distance := global_position.distance_to(target.global_position)
	if reaction_remaining <= 0.0:
		var distance_error := aim_error * clampf(distance / 16.0, 0.7, 1.8)
		var error := Vector3(
			random.randf_range(-distance_error, distance_error),
			random.randf_range(-distance_error * 0.65, distance_error * 0.65),
			random.randf_range(-distance_error, distance_error)
		)
		desired_aim_direction = (target.global_position + Vector3.UP * 1.25 + error - get_aim_origin()).normalized()
	aim_direction = aim_direction.slerp(desired_aim_direction, clampf(delta * 4.2, 0.0, 1.0)).normalized()
	var horizontal_aim := Vector3(aim_direction.x, 0.0, aim_direction.z)
	if horizontal_aim.length_squared() > 0.01:
		look_at(global_position + horizontal_aim, Vector3.UP)
	var flat_length := Vector2(aim_direction.x, aim_direction.z).length()
	aim_pivot.rotation.x = -atan2(aim_direction.y, flat_length)


func _handle_block_timer() -> void:
	if current_weapon is KatanaWeapon and block_remaining <= 0.0:
		(current_weapon as KatanaWeapon).secondary_released()


func _apply_gravity_and_move(delta: float, desired_direction: Vector3) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.2
	if dash_skill.is_active():
		velocity.x = dash_skill.dash_direction.x * dash_skill.dash_speed
		velocity.z = dash_skill.dash_direction.z * dash_skill.dash_speed
	else:
		var speed_scale := 0.2 if stagger_remaining > 0.0 else 1.0
		var target_velocity := desired_direction * move_speed * speed_scale
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	move_and_slide()


func equip_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == current_weapon_index and current_weapon != null:
		return
	if current_weapon != null:
		current_weapon.unequip()
	current_weapon_index = index
	current_weapon = weapons[index]
	current_weapon.equip()


func get_aim_origin() -> Vector3:
	return global_position + Vector3.UP * 1.48


func get_melee_origin() -> Vector3:
	return global_position + Vector3.UP * 1.1


func get_aim_direction() -> Vector3:
	return aim_direction.normalized()


func get_aim_exclusions() -> Array[RID]:
	return [get_rid(), head_hurtbox.get_rid()]


func is_headshot_position(hit_position: Vector3) -> bool:
	return hit_position.y - global_position.y >= 1.4


func modify_incoming_damage(info: DamageInfo) -> Dictionary:
	if current_weapon is KatanaWeapon:
		return (current_weapon as KatanaWeapon).get_damage_response(info)
	return {}


func receive_damage(info: DamageInfo) -> Dictionary:
	return health.apply_damage(info)


func on_damage_response(response_type: StringName, _info: DamageInfo, _applied: float) -> void:
	if response_type == &"deflect":
		ai_state = "PERFECT_DEFLECT"
	elif response_type == &"block":
		ai_state = "BLOCK"


func apply_knockback(force: Vector3) -> void:
	velocity += force


func apply_stagger(duration: float) -> void:
	stagger_remaining = maxf(stagger_remaining, duration)
	ai_state = "STAGGERED"


func apply_launch(launch_velocity: Vector3) -> void:
	velocity.x = lerpf(velocity.x, launch_velocity.x, 0.65)
	velocity.z = lerpf(velocity.z, launch_velocity.z, 0.65)
	velocity.y = maxf(velocity.y, launch_velocity.y)
	ai_state = "LAUNCHED"


func force_kill() -> void:
	health.kill(null, &"fall")


func on_sniper_fired(_ads: bool) -> void:
	pass


func on_melee_swing(_heavy: bool) -> void:
	pass


func on_block_started() -> void:
	pass


func on_reload_started() -> void:
	pass


func on_empty_weapon() -> void:
	pass


func _on_health_died(info: DamageInfo) -> void:
	is_dead = true
	ai_state = "DEAD"
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	visual_body.visible = false
	weapon_mount.visible = false
	if current_weapon != null:
		current_weapon.secondary_released()
	actor_died.emit(self, info)


func respawn() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	is_dead = false
	stagger_remaining = 0.0
	block_remaining = 0.0
	collision_layer = 2
	collision_mask = 1
	visual_body.visible = true
	weapon_mount.visible = true
	dash_skill.reset()
	for weapon in weapons:
		weapon.reset_weapon()
	health.reset()
	equip_weapon(1)
	ai_state = "RESPAWN"
