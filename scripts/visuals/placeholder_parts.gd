class_name PlaceholderParts
extends RefCounted

static func material(color: Color, metal: float = 0.0, glow: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metal
	result.roughness = 0.65
	if glow:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

static func box(parent: Node3D, at: Vector3, dimensions: Vector3, surface: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = dimensions
	return part(parent, at, shape, surface)

static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, surface: Material, top: float = -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius if top < 0.0 else top
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 10
	return part(parent, at, shape, surface)


static func sphere(parent: Node3D, at: Vector3, radius: float, surface: Material, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 16
	shape.rings = 8
	var instance := part(parent, at, shape, surface)
	instance.scale = scale
	return instance

static func part(parent: Node3D, at: Vector3, shape: Mesh, surface: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = surface
	instance.position = at
	parent.add_child(instance)
	return instance
