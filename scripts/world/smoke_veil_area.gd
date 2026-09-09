class_name SmokeVeilArea
extends Node3D

var radius: float = 4.5
var remaining: float = 6.0


func setup(position_world: Vector3, p_radius: float, duration: float) -> void:
	global_position = position_world
	radius = p_radius
	remaining = duration
	add_to_group("smoke_veil")
	_build_visual()


func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
		return
	var pulse := 0.96 + sin(remaining * 2.2) * 0.04
	scale = Vector3.ONE * pulse


func blocks_segment(from: Vector3, to: Vector3) -> bool:
	var segment := to - from
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return from.distance_to(global_position) <= radius
	var t := clampf((global_position - from).dot(segment) / length_squared, 0.0, 1.0)
	return (from + segment * t).distance_to(global_position) <= radius


func _build_visual() -> void:
	var cloud := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.12, 0.14, 0.17, 0.58)
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	cloud.mesh = mesh
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloud)
