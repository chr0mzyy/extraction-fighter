class_name LaunchPad
extends Area3D

@export var vertical_speed: float = 13.5
@export var forward_speed: float = 7.0
@export var pad_radius: float = 1.35


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	monitorable = true

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PadMesh"
	var mesh := CylinderMesh.new()
	mesh.top_radius = pad_radius
	mesh.bottom_radius = pad_radius
	mesh.height = 0.28
	mesh.radial_segments = 12
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.06, 0.48, 0.55)
	material.emission_enabled = true
	material.emission = Color(0.05, 0.65, 0.8)
	material.emission_energy_multiplier = 2.1
	material.metallic = 0.45
	material.roughness = 0.28
	mesh.material = material
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "TriggerShape"
	var shape := CylinderShape3D.new()
	shape.radius = pad_radius
	shape.height = 0.8
	collision.shape = shape
	collision.position.y = 0.25
	add_child(collision)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("apply_launch"):
		return
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	body.apply_launch(Vector3(forward.x * forward_speed, vertical_speed, forward.z * forward_speed))

