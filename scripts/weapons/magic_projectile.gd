class_name MagicProjectile
extends Node3D

var source: Node
var source_weapon: WeaponBase
var travel_direction: Vector3 = Vector3.FORWARD
var speed: float = 34.0
var damage: float = 31.0
var remaining_life: float = 3.0


func setup(p_weapon: WeaponBase, p_source: Node, origin: Vector3, direction: Vector3, p_damage: float, p_speed: float) -> void:
	source_weapon = p_weapon
	source = p_source
	global_position = origin
	travel_direction = direction.normalized()
	damage = p_damage
	speed = p_speed
	_build_visual()


func _physics_process(delta: float) -> void:
	remaining_life -= delta
	if remaining_life <= 0.0:
		queue_free()
		return
	var destination := global_position + travel_direction * speed * delta
	var exclusions: Array[RID] = []
	if is_instance_valid(source) and source is CollisionObject3D:
		exclusions.append((source as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(global_position, destination, 1 | 2 | 4, exclusions)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = destination
		return
	var collider := hit.get("collider") as Node
	var target: Node = null
	var headshot := false
	if collider != null and collider.has_method("get_damage_receiver"):
		target = collider.get_damage_receiver()
		headshot = bool(collider.is_headshot_hitbox())
	elif collider != null and collider.has_method("receive_damage"):
		target = collider
	if target != null and target != source and target.has_method("receive_damage"):
		var base_damage := damage * (1.35 if headshot else 1.0)
		var info := source_weapon.make_damage_info(base_damage, target, &"arcane_projectile", headshot, false, hit.get("position", destination), travel_direction * 2.0)
		source_weapon.resolve_damage(target, info)
	elif is_instance_valid(source_weapon):
		source_weapon.notify_attack_missed()
	queue_free()


func _build_visual() -> void:
	var orb := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.28
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.62, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.12, 0.38, 1.0)
	material.emission_energy_multiplier = 4.0
	mesh.material = material
	orb.mesh = mesh
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(orb)
	var light := OmniLight3D.new()
	light.light_color = Color(0.25, 0.52, 1.0)
	light.light_energy = 1.2
	light.omni_range = 2.5
	light.shadow_enabled = false
	add_child(light)
