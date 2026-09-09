class_name PlayerController
extends CharacterBody3D

signal actor_died(actor: Node, info: DamageInfo)
signal feedback(event_name: StringName, data: Dictionary)

@export_group("Camera")
@export var mouse_sensitivity: float = 0.0022
@export var first_person_fov: float = 90.0
@export var third_person_fov: float = 78.0
@export var ads_fov: float = 45.0

@onready var health: HealthComponent = $HealthComponent
@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var head_hurtbox: Hurtbox3D = $HeadHurtbox
@onready var visual_body: MeshInstance3D = $VisualBody
@onready var pitch_pivot: Node3D = $PitchPivot
@onready var first_person_camera: Camera3D = $PitchPivot/FirstPersonCamera
@onready var spring_arm: SpringArm3D = $PitchPivot/ThirdPersonSpringArm
@onready var third_person_camera: Camera3D = $PitchPivot/ThirdPersonSpringArm/ThirdPersonCamera
@onready var weapon_mount: Node3D = $PitchPivot/WeaponMount
@onready var dash_skill: DashSkill = $DashSkill
@onready var double_jump_skill: DoubleJumpSkill = $DoubleJumpSkill
@onready var movement: PlayerMovementController = $MovementController

var weapons: Array[WeaponBase] = []
var current_weapon: WeaponBase
var current_weapon_index: int = 0
var is_first_person: bool = true
var is_dead: bool = false
var is_cursor_free: bool = false
var spawn_transform: Transform3D
var stagger_remaining: float = 0.0
var camera_kick: float = 0.0


func _ready() -> void:
	add_to_group("player")
	spawn_transform = global_transform
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for child in weapon_mount.get_children():
		if child is WeaponBase:
			var weapon := child as WeaponBase
			weapons.append(weapon)
			weapon.setup(self)
			weapon.hit_confirmed.connect(_on_weapon_hit)
			weapon.unequip()
	health.died.connect(_on_health_died)
	movement.setup(self, body_collision, visual_body, pitch_pivot, head_hurtbox, dash_skill, double_jump_skill)
	movement.movement_event.connect(_on_movement_event)
	spring_arm.add_excluded_object(get_rid())
	spring_arm.add_excluded_object(head_hurtbox.get_rid())
	equip_weapon(0)
	set_camera_mode(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_toggle"):
		is_cursor_free = not is_cursor_free
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_cursor_free else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if is_cursor_free:
		if event is InputEventMouseButton and event.pressed:
			is_cursor_free = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and not is_dead:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		pitch_pivot.rotation.x = clampf(pitch_pivot.rotation.x, deg_to_rad(-84.0), deg_to_rad(84.0))
	if is_dead:
		return
	if event.is_action_pressed("toggle_camera"):
		set_camera_mode(not is_first_person)
	elif event.is_action_pressed("weapon_1"):
		equip_weapon(0)
	elif event.is_action_pressed("weapon_2"):
		equip_weapon(1)
	elif event.is_action_pressed("primary_attack") and current_weapon != null:
		current_weapon.request_primary()
	elif event.is_action_pressed("secondary_attack") and current_weapon != null:
		current_weapon.secondary_pressed()
	elif event.is_action_released("secondary_attack") and current_weapon != null:
		current_weapon.secondary_released()
	elif event.is_action_pressed("heavy_attack") and current_weapon != null:
		current_weapon.request_heavy()
	elif event.is_action_pressed("reload") and current_weapon != null:
		current_weapon.request_reload()


func _process(delta: float) -> void:
	if camera_kick > 0.0001:
		var recovery := minf(camera_kick, delta * 0.8)
		pitch_pivot.rotation.x += recovery
		camera_kick -= recovery
	var desired_fpp_fov := first_person_fov
	var desired_tpp_fov := third_person_fov
	if current_weapon is SniperWeapon and (current_weapon as SniperWeapon).is_ads:
		desired_fpp_fov = ads_fov
		desired_tpp_fov = ads_fov + 7.0
	first_person_camera.fov = lerpf(first_person_camera.fov, desired_fpp_fov, minf(1.0, delta * 14.0))
	third_person_camera.fov = lerpf(third_person_camera.fov, desired_tpp_fov, minf(1.0, delta * 14.0))


func _physics_process(delta: float) -> void:
	stagger_remaining = maxf(0.0, stagger_remaining - delta)
	if is_dead:
		velocity = Vector3.ZERO
		return
	movement.physics_step(delta, stagger_remaining)


func equip_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == current_weapon_index and current_weapon != null:
		return
	if current_weapon != null:
		current_weapon.unequip()
	current_weapon_index = index
	current_weapon = weapons[index]
	current_weapon.equip()
	feedback.emit(&"weapon_switched", {"name": current_weapon.weapon_display_name})


func set_camera_mode(first_person: bool) -> void:
	is_first_person = first_person
	first_person_camera.current = first_person
	third_person_camera.current = not first_person
	visual_body.visible = not first_person and not is_dead
	feedback.emit(&"camera_switched", {"mode": get_camera_mode_name()})


func get_camera_mode_name() -> String:
	return "FPP" if is_first_person else "TPP"


func get_aim_origin() -> Vector3:
	return first_person_camera.global_position if is_first_person else third_person_camera.global_position


func get_melee_origin() -> Vector3:
	return global_position + Vector3.UP * minf(1.15, pitch_pivot.position.y - 0.2)


func get_aim_direction() -> Vector3:
	var camera := first_person_camera if is_first_person else third_person_camera
	return -camera.global_basis.z.normalized()


func get_aim_exclusions() -> Array[RID]:
	return [get_rid(), head_hurtbox.get_rid()]


func is_headshot_position(hit_position: Vector3) -> bool:
	return hit_position.y - global_position.y >= head_hurtbox.position.y - 0.24


func get_block_weapon() -> KatanaWeapon:
	if current_weapon is KatanaWeapon:
		return current_weapon as KatanaWeapon
	return null


func modify_incoming_damage(info: DamageInfo) -> Dictionary:
	var katana := get_block_weapon()
	if katana != null:
		return katana.get_damage_response(info)
	return {}


func receive_damage(info: DamageInfo) -> Dictionary:
	return health.apply_damage(info)


func on_damage_response(response_type: StringName, info: DamageInfo, applied: float) -> void:
	match response_type:
		&"deflect":
			feedback.emit(&"deflect", {"damage": info.amount})
		&"block":
			feedback.emit(&"block", {"damage": applied})
		_:
			feedback.emit(&"damage_taken", {"damage": applied, "headshot": info.headshot})


func apply_knockback(force: Vector3) -> void:
	velocity += force


func apply_stagger(duration: float) -> void:
	stagger_remaining = maxf(stagger_remaining, duration)
	feedback.emit(&"stagger", {})


func apply_launch(launch_velocity: Vector3) -> void:
	velocity.x = lerpf(velocity.x, launch_velocity.x, 0.65)
	velocity.z = lerpf(velocity.z, launch_velocity.z, 0.65)
	velocity.y = maxf(velocity.y, launch_velocity.y)
	movement.on_external_launch()
	feedback.emit(&"launch", {})


func force_kill() -> void:
	health.kill(null, &"fall")


func on_sniper_fired(ads: bool) -> void:
	var kick := 0.018 if ads else 0.028
	pitch_pivot.rotation.x = clampf(pitch_pivot.rotation.x - kick, deg_to_rad(-84.0), deg_to_rad(84.0))
	camera_kick += kick
	feedback.emit(&"sniper_fired", {"ads": ads})


func on_melee_swing(heavy: bool) -> void:
	feedback.emit(&"heavy_swing" if heavy else &"light_swing", {})


func on_block_started() -> void:
	feedback.emit(&"block_started", {})


func on_reload_started() -> void:
	feedback.emit(&"reload", {})


func on_empty_weapon() -> void:
	feedback.emit(&"empty", {})


func _on_weapon_hit(headshot: bool) -> void:
	feedback.emit(&"headshot" if headshot else &"hitmarker", {})


func _on_movement_event(event_name: StringName) -> void:
	feedback.emit(event_name, {})


func _on_health_died(info: DamageInfo) -> void:
	is_dead = true
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	visual_body.visible = false
	movement.on_death()
	if current_weapon != null:
		current_weapon.secondary_released()
	feedback.emit(&"death", {})
	actor_died.emit(self, info)


func respawn() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	is_dead = false
	stagger_remaining = 0.0
	collision_layer = 2
	collision_mask = 1
	dash_skill.reset()
	double_jump_skill.reset()
	movement.reset()
	for weapon in weapons:
		weapon.reset_weapon()
	health.reset()
	set_camera_mode(is_first_person)
	feedback.emit(&"respawn", {})
