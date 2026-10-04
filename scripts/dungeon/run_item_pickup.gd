class_name RunItemPickup
extends Node3D

var item_instance: ItemInstance
var item_definition: ItemDefinition
var base_height: float = 0.32
var time: float = 0.0


func configure(instance: ItemInstance, definition: ItemDefinition) -> void:
	item_instance = instance
	item_definition = definition
	if is_node_ready():
		_build_visual()


func _ready() -> void:
	_build_visual()


func _process(delta: float) -> void:
	time += delta
	position.y = base_height + sin(time * 2.2) * 0.055
	rotation.y += delta * 0.65


func take_item() -> ItemInstance:
	var result := item_instance
	item_instance = null
	queue_free()
	return result


func get_prompt() -> String:
	return "[X] PICK UP  %s" % (item_definition.display_name.to_upper() if item_definition != null else "ITEM")


func _build_visual() -> void:
	for child: Node in get_children():
		child.queue_free()
	if item_definition == null:
		return
	var accent := InventoryItemSlot.RARITY_COLORS[clampi(item_definition.rarity, 0, InventoryItemSlot.RARITY_COLORS.size() - 1)]
	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.28
	pedestal_mesh.bottom_radius = 0.34
	pedestal_mesh.height = 0.08
	pedestal_mesh.radial_segments = 18
	pedestal_mesh.material = PlaceholderParts.material(Color(0.025, 0.035, 0.04), 0.72)
	pedestal.mesh = pedestal_mesh
	add_child(pedestal)
	var marker := MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.22, 0.22, 0.22)
	marker_mesh.material = PlaceholderParts.material(accent, 0.15, true)
	marker.mesh = marker_mesh
	marker.position.y = 0.18
	marker.rotation = Vector3(0.3, 0.4, 0.2)
	add_child(marker)
	var label := Label3D.new()
	label.text = item_definition.display_name.to_upper()
	label.position.y = 0.62
	label.font_size = 30
	label.modulate = accent.lightened(0.16)
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
