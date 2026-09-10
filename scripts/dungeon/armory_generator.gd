class_name ArmoryGenerator
extends Node3D

const ROOM_COLUMNS := 4
const ROOM_ROWS := 3
const ROOM_SIZE := 17.0
const ROOM_SPACING := 18.0
const ROOM_TYPES: Array[String] = [
	"spawn", "barracks", "forge", "gallery",
	"vault", "crossing", "quarters", "chapel",
	"arsenal", "gallery", "watch", "boss",
]

var room_centers: Array[Vector3] = []
var extraction_points: Array[ExtractionPoint] = []
var loot_chests: Array[LootChest] = []
var enemy_markers: Array[Marker3D] = []
var boss_marker: Marker3D


func generate(seed_value: int) -> Dictionary:
	room_centers = _make_room_centers()
	_build_shell()
	var plan := build_extraction_plan(seed_value)
	for index: int in plan.normal_rooms.size():
		_spawn_extraction(int(plan.normal_rooms[index]), false, index)
	for index: int in plan.hidden_rooms.size():
		_spawn_extraction(int(plan.hidden_rooms[index]), true, index)
	_build_chest_markers(seed_value)
	_build_enemy_markers()
	return {
		"normal_extractions": extraction_points.filter(func(point: ExtractionPoint) -> bool: return not point.hidden_extraction),
		"hidden_extractions": extraction_points.filter(func(point: ExtractionPoint) -> bool: return point.hidden_extraction),
		"chests": loot_chests,
		"enemy_markers": enemy_markers,
		"boss_marker": boss_marker,
		"spawn_position": room_centers[0] + Vector3(0, 0.2, 0),
	}


static func build_extraction_plan(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var candidates: Array[int] = []
	for room_index: int in range(1, 11):
		candidates.append(room_index)
	for index: int in range(candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = value
	return {"normal_rooms": candidates.slice(0, 6), "hidden_rooms": candidates.slice(6, 8)}


func _make_room_centers() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for row: int in ROOM_ROWS:
		for column: int in ROOM_COLUMNS:
			result.append(Vector3((column - 1.5) * ROOM_SPACING, 0.0, (row - 1.0) * ROOM_SPACING))
	return result


func _build_shell() -> void:
	var floor_material := _material(Color(0.105, 0.12, 0.135), 0.82)
	var trim_material := _material(Color(0.19, 0.22, 0.24), 0.7)
	var cover_material := _material(Color(0.16, 0.13, 0.115), 0.88)
	for room_index: int in room_centers.size():
		var center := room_centers[room_index]
		_add_box("RoomFloor%02d" % room_index, center + Vector3.DOWN * 0.3, Vector3(ROOM_SIZE, 0.6, ROOM_SIZE), floor_material)
		var marker := Marker3D.new()
		marker.name = "RoomMarker%02d_%s" % [room_index, ROOM_TYPES[room_index]]
		marker.position = center
		marker.set_meta("room_index", room_index)
		marker.set_meta("room_type", ROOM_TYPES[room_index])
		add_child(marker)
		if room_index not in [0, 11]:
			_add_box("Cover%02dA" % room_index, center + Vector3(-3.2, 0.8, 1.6), Vector3(2.0, 1.6, 1.0), cover_material)
			_add_box("Cover%02dB" % room_index, center + Vector3(3.0, 1.15, -2.3), Vector3(1.1, 2.3, 1.1), trim_material)
		if room_index in [3, 5, 8, 10]:
			_add_box("HighGround%02d" % room_index, center + Vector3(0, 1.25, 3.0), Vector3(7.0, 2.5, 5.0), trim_material)
			_add_ramp(center + Vector3(0, 0.65, -1.5), Vector3(4.0, 0.45, 6.0), -12.0, floor_material)
	for row: int in ROOM_ROWS:
		for column: int in range(ROOM_COLUMNS - 1):
			var left_index := row * ROOM_COLUMNS + column
			var midpoint := (room_centers[left_index] + room_centers[left_index + 1]) * 0.5
			_add_box("BridgeX%d_%d" % [row, column], midpoint + Vector3.DOWN * 0.3, Vector3(2.0, 0.6, 7.0), floor_material)
	for row: int in range(ROOM_ROWS - 1):
		for column: int in ROOM_COLUMNS:
			var top_index := row * ROOM_COLUMNS + column
			var midpoint := (room_centers[top_index] + room_centers[top_index + ROOM_COLUMNS]) * 0.5
			_add_box("BridgeZ%d_%d" % [row, column], midpoint + Vector3.DOWN * 0.3, Vector3(7.0, 0.6, 2.0), floor_material)
	_add_box("NorthWall", Vector3(0, 2.5, -27.2), Vector3(72.0, 5.0, 0.8), trim_material)
	_add_box("SouthWall", Vector3(0, 2.5, 27.2), Vector3(72.0, 5.0, 0.8), trim_material)
	_add_box("WestWall", Vector3(-36.2, 2.5, 0), Vector3(0.8, 5.0, 55.0), trim_material)
	_add_box("EastWall", Vector3(36.2, 2.5, 0), Vector3(0.8, 5.0, 55.0), trim_material)
	var launch_one := LaunchPad.new()
	launch_one.name = "ArmoryLaunchWest"
	launch_one.position = room_centers[4] + Vector3(5.0, 0.08, -4.2)
	launch_one.rotation.y = -PI * 0.5
	add_child(launch_one)
	var launch_two := LaunchPad.new()
	launch_two.name = "ArmoryLaunchEast"
	launch_two.position = room_centers[7] + Vector3(-5.0, 0.08, 4.2)
	launch_two.rotation.y = PI * 0.5
	add_child(launch_two)


func _spawn_extraction(room_index: int, hidden: bool, serial: int) -> void:
	var marker := Marker3D.new()
	marker.name = ("HiddenExtractionMarker" if hidden else "ExtractionMarker") + str(serial + 1)
	var local_z := -4.7 if serial % 3 == 0 else 4.7
	var marker_height := 2.55 if room_index in [3, 5, 8, 10] and local_z > 0.5 else 0.02
	marker.position = room_centers[room_index] + Vector3(4.9 if serial % 2 == 0 else -4.9, marker_height, local_z)
	marker.set_meta("room_index", room_index)
	marker.set_meta("hidden", hidden)
	add_child(marker)
	var point := ExtractionPoint.new()
	point.name = ("HiddenExtraction" if hidden else "Extraction") + str(serial + 1)
	point.extraction_id = StringName(point.name.to_snake_case())
	point.hidden_extraction = hidden
	point.room_index = room_index
	marker.add_child(point)
	extraction_points.append(point)


func _build_chest_markers(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5A17
	for serial: int in 8:
		var room_index := 1 + (serial * 3 + rng.randi_range(0, 2)) % 10
		var chest := LootChest.new()
		chest.name = "LootChest%02d" % (serial + 1)
		var local_position := Vector3(rng.randf_range(-5.2, 5.2), 0.02, rng.randf_range(-5.2, 5.2))
		if room_index in [3, 5, 8, 10] and local_position.z > 0.5:
			local_position.y = 2.55
		chest.position = room_centers[room_index] + local_position
		chest.set_meta("room_index", room_index)
		add_child(chest)
		loot_chests.append(chest)


func _build_enemy_markers() -> void:
	for room_index: int in [2, 4, 5, 7, 8, 9]:
		var marker := Marker3D.new()
		marker.name = "EnemyMarker%02d" % room_index
		marker.position = room_centers[room_index] + Vector3(0, 0.15, -1.5)
		add_child(marker)
		enemy_markers.append(marker)
	boss_marker = Marker3D.new()
	boss_marker.name = "WardenMarker"
	boss_marker.position = room_centers[11] + Vector3(0, 0.15, 0)
	add_child(boss_marker)


func _add_ramp(position_value: Vector3, size_value: Vector3, degrees: float, material: Material) -> void:
	var body := _add_box("Ramp", position_value, size_value, material)
	body.rotation_degrees.x = degrees


func _add_box(node_name: String, position_value: Vector3, size_value: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 0
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
