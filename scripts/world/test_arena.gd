class_name TestArena
extends Node3D

var materials: Dictionary = {}

const PEEK_SPOTS: Array[Vector3] = [
	Vector3(-18.0, 0.02, -4.2), Vector3(-18.0, 0.02, 4.2),
	Vector3(18.0, 0.02, -4.2), Vector3(18.0, 0.02, 4.2),
	Vector3(-7.6, 0.02, 9.0), Vector3(-7.6, 0.02, 17.0),
	Vector3(7.6, 0.02, 9.0), Vector3(7.6, 0.02, 17.0),
	Vector3(-4.4, 0.02, -4.2), Vector3(4.4, 0.02, -4.2),
	Vector3(-4.4, 0.02, 4.2), Vector3(4.4, 0.02, 4.2),
]


func _ready() -> void:
	_create_materials()
	_build_floor_and_bounds()
	_build_vertical_routes()
	_build_cover_and_corridors()
	_build_route_markings()
	_build_ai_tactical_points()
	_build_launch_pads()
	_build_kill_volume()
	_build_visual_details()


func _create_materials() -> void:
	materials["stone"] = _material(Color(0.13, 0.16, 0.19), 0.84)
	materials["floor"] = _material(Color(0.19, 0.22, 0.24), 0.94)
	materials["stone_light"] = _material(Color(0.34, 0.38, 0.40), 0.82)
	materials["platform"] = _material(Color(0.22, 0.29, 0.32), 0.72)
	materials["cover"] = _material(Color(0.38, 0.23, 0.10), 0.78)
	materials["accent"] = _material(Color(0.23, 0.27, 0.29), 0.78)
	materials["edge"] = _material(Color(0.92, 0.68, 0.18), 0.58)
	materials["blue"] = _material(Color(0.10, 0.43, 0.68), 0.55)
	materials["red"] = _material(Color(0.72, 0.16, 0.13), 0.55)
	materials["peek"] = _material(Color(0.30, 0.92, 0.68), 0.40)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result


func _build_visual_details() -> void:
	# Decorative meshes only: the high-contrast training language makes corners,
	# teams and cover heights readable at a glance.
	var iron := PlaceholderParts.material(Color(0.055, 0.07, 0.08), 0.72)
	for x: float in [-22.0, -11.0, 0.0, 11.0, 22.0]:
		PlaceholderParts.box(self, Vector3(x, 4.8, -28.32), Vector3(1.7, 2.7, 0.08), materials["blue"] if x < 0.0 else (materials["red"] if x > 0.0 else materials["edge"]))
		PlaceholderParts.box(self, Vector3(x, 6.25, -28.25), Vector3(2.0, 0.12, 0.15), iron)
	for child: Node in get_children():
		if not child is StaticBody3D:
			continue
		var body := child as StaticBody3D
		if String(body.name).contains("Cover") or String(body.name).contains("Crate"):
			var collision := body.get_child(body.get_child_count() - 1) as CollisionShape3D
			if collision != null and collision.shape is BoxShape3D:
				var dimensions := (collision.shape as BoxShape3D).size
				for side: float in [-1.0, 1.0]:
					PlaceholderParts.box(body, Vector3(side * dimensions.x * 0.32, 0, 0), Vector3(0.09, dimensions.y + 0.02, dimensions.z + 0.03), iron)
		elif String(body.name).begins_with("Pillar"):
			PlaceholderParts.cylinder(body, Vector3(0, -1.64, 0), 1.17, 0.25, iron)
			PlaceholderParts.cylinder(body, Vector3(0, 1.64, 0), 1.17, 0.25, materials["edge"])
		elif String(body.name).contains("SpawnShield"):
			PlaceholderParts.box(body, Vector3(0.0, 0.72, 0.0), Vector3(0.74, 0.10, 6.65), materials["edge"])
			PlaceholderParts.box(body, Vector3(0.0, -0.72, 0.0), Vector3(0.74, 0.10, 6.65), iron)
			for marker_z: float in [-2.6, 0.0, 2.6]:
				PlaceholderParts.box(body, Vector3(0.0, 0.0, marker_z), Vector3(0.75, 1.15, 0.08), materials["peek"])
		elif String(body.name).contains("Peek") or String(body.name).contains("CenterCore"):
			PlaceholderParts.box(body, Vector3(0.0, 1.0, 0.0), Vector3(0.05, 0.55, 0.55), materials["peek"])


func _build_floor_and_bounds() -> void:
	_add_box("ArenaFloor", Vector3(0, -0.5, 0), Vector3(58, 1, 58), "floor")
	_add_box("NorthWall", Vector3(0, 3.5, -29), Vector3(60, 8, 1.2), "stone")
	_add_box("SouthWall", Vector3(0, 3.5, 29), Vector3(60, 8, 1.2), "stone")
	_add_box("WestWall", Vector3(-29, 3.5, 0), Vector3(1.2, 8, 60), "stone")
	_add_box("EastWall", Vector3(29, 3.5, 0), Vector3(1.2, 8, 60), "stone")
	# Repeating wall blocks give the compact training room a measured 5 m rhythm.
	for x in range(-27, 28, 6):
		_add_box("NorthTrainingBlock%d" % x, Vector3(x, 7.8, -29), Vector3(3, 0.8, 1.5), "stone_light")
		_add_box("SouthTrainingBlock%d" % x, Vector3(x, 7.8, 29), Vector3(3, 0.8, 1.5), "stone_light")


func _build_vertical_routes() -> void:
	# Mirrored sniper decks overlook the north route without dominating every lane.
	_add_box("BlueDeck", Vector3(-19, 2.45, -18), Vector3(9, 0.6, 7), "platform")
	_add_box("BlueDeckBack", Vector3(-23.2, 4.0, -18), Vector3(0.6, 3.4, 7), "blue")
	_add_box("BlueDeckRamp", Vector3(-12.7, 1.18, -18), Vector3(7.4, 0.5, 3.2), "stone_light", Vector3(0.0, 0.0, -0.31))
	_add_box("RedDeck", Vector3(19, 2.45, -18), Vector3(9, 0.6, 7), "platform")
	_add_box("RedDeckBack", Vector3(23.2, 4.0, -18), Vector3(0.6, 3.4, 7), "red")
	_add_box("RedDeckRamp", Vector3(12.7, 1.18, -18), Vector3(7.4, 0.5, 3.2), "stone_light", Vector3(0.0, 0.0, 0.31))
	_add_box("CenterAimDeck", Vector3(0, 2.3, -21), Vector3(8, 0.55, 4.5), "platform")
	_add_stairs("CenterDeckStairs", Vector3(0, 0, -16.8), Vector3(0, 0, -1), 7, 3.2, 0.58, 0.32)


func _build_cover_and_corridors() -> void:
	# Spawn shields force both players to choose a side and expose a real lean angle.
	_add_box("BlueSpawnShield", Vector3(-18, 1.55, 0), Vector3(0.7, 3.1, 7.2), "blue")
	_add_box("RedSpawnShield", Vector3(18, 1.55, 0), Vector3(0.7, 3.1, 7.2), "red")
	_add_box("BlueSpawnCrateNorth", Vector3(-21, 0.72, -6.2), Vector3(2.4, 1.44, 2.4), "cover")
	_add_box("BlueSpawnCrateSouth", Vector3(-21, 0.72, 6.2), Vector3(2.4, 1.44, 2.4), "cover")
	_add_box("RedSpawnCrateNorth", Vector3(21, 0.72, -6.2), Vector3(2.4, 1.44, 2.4), "cover")
	_add_box("RedSpawnCrateSouth", Vector3(21, 0.72, 6.2), Vector3(2.4, 1.44, 2.4), "cover")

	# The center cage supports left/right swings while leaving its interior open for duels.
	_add_box("CenterCoreNorth", Vector3(0, 1.5, -4.2), Vector3(8.0, 3.0, 0.7), "accent")
	_add_box("CenterCoreSouth", Vector3(0, 1.5, 4.2), Vector3(8.0, 3.0, 0.7), "accent")
	_add_cylinder("PillarCenterWest", Vector3(-4.3, 1.7, 0), 0.82, 3.4, "stone_light")
	_add_cylinder("PillarCenterEast", Vector3(4.3, 1.7, 0), 0.82, 3.4, "stone_light")

	# Southern slice walls create repeated Q/E practice positions and preserve an
	# open outer lane for movement and long-range accuracy drills.
	_add_box("PeekWallBlueSouth", Vector3(-7, 1.6, 13), Vector3(0.8, 3.2, 8.0), "blue")
	_add_box("PeekWallRedSouth", Vector3(7, 1.6, 13), Vector3(0.8, 3.2, 8.0), "red")
	_add_box("SouthCrossCover", Vector3(0, 1.1, 18), Vector3(8.5, 2.2, 0.7), "accent")
	for position in [Vector3(-13, 0.75, 11), Vector3(13, 0.75, 11), Vector3(-12, 0.75, -10), Vector3(12, 0.75, -10), Vector3(-4, 0.75, -12), Vector3(4, 0.75, 12)]:
		_add_box("TrainingCrate", position, Vector3(2.4, 1.5, 2.2), "cover")
	_add_box("NorthPeekBlue", Vector3(-7, 1.45, -11.5), Vector3(0.7, 2.9, 5.5), "blue")
	_add_box("NorthPeekRed", Vector3(7, 1.45, -11.5), Vector3(0.7, 2.9, 5.5), "red")
	_add_box("NorthLowCover", Vector3(0, 0.72, -10), Vector3(4.0, 1.44, 1.4), "cover")


func _build_launch_pads() -> void:
	var pad_one := LaunchPad.new()
	pad_one.name = "LaunchPadSouth"
	pad_one.position = Vector3(-22, 0.15, -20)
	pad_one.rotation.y = -PI * 0.5
	pad_one.add_to_group("bot_vertical_route")
	add_child(pad_one)
	var pad_two := LaunchPad.new()
	pad_two.name = "LaunchPadNorth"
	pad_two.position = Vector3(22, 0.15, -20)
	pad_two.rotation.y = PI * 0.5
	pad_two.add_to_group("bot_vertical_route")
	add_child(pad_two)
	var pad_three := LaunchPad.new()
	pad_three.name = "LaunchPadWestHigh"
	pad_three.position = Vector3(0, 0.15, -15)
	pad_three.vertical_speed = 11.5
	pad_three.forward_speed = 8.5
	pad_three.rotation.y = PI
	pad_three.add_to_group("bot_vertical_route")
	add_child(pad_three)


func _build_route_markings() -> void:
	# Flush paving bands communicate center, north flank and south movement lane.
	for route in [
		[Vector3(0, 0.012, 0), Vector3(48, 0.015, 1.2)],
		[Vector3(0, 0.012, -12), Vector3(48, 0.015, 0.55)],
		[Vector3(0, 0.012, 22), Vector3(48, 0.015, 0.55)]
	]:
		var paving := MeshInstance3D.new()
		var paving_mesh := BoxMesh.new()
		paving_mesh.size = route[1]
		paving_mesh.material = materials["stone_light"]
		paving.mesh = paving_mesh
		paving.position = route[0]
		paving.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(paving)
	PlaceholderParts.box(self, Vector3(-22, 0.022, 0), Vector3(8.0, 0.02, 0.22), materials["blue"])
	PlaceholderParts.box(self, Vector3(22, 0.022, 0), Vector3(8.0, 0.02, 0.22), materials["red"])
	for peek_position: Vector3 in PEEK_SPOTS:
		var marker := PlaceholderParts.box(self, peek_position, Vector3(0.56, 0.025, 0.12), materials["peek"])
		marker.rotation.y = PI * 0.25
		var marker_cross := PlaceholderParts.box(self, peek_position + Vector3(0.0, 0.002, 0.0), Vector3(0.12, 0.026, 0.56), materials["peek"])
		marker_cross.rotation.y = PI * 0.25


func _build_ai_tactical_points() -> void:
	# Lightweight authored hints keep tactical movement robust without a navigation bake.
	# Cover points are paired across obstacles so the bot can pick the side hidden from
	# the player's current angle instead of treating cover as a fixed destination.
	var cover_points: Array[Vector3] = [
		Vector3(-19.0, 0.1, -4.5), Vector3(-19.0, 0.1, 4.5),
		Vector3(19.0, 0.1, -4.5), Vector3(19.0, 0.1, 4.5),
		Vector3(-8.2, 0.1, 9.0), Vector3(-8.2, 0.1, 17.0),
		Vector3(8.2, 0.1, 9.0), Vector3(8.2, 0.1, 17.0),
		Vector3(-4.8, 0.1, -4.2), Vector3(4.8, 0.1, -4.2),
		Vector3(-4.8, 0.1, 4.2), Vector3(4.8, 0.1, 4.2),
		Vector3(-13.0, 0.1, -12.4), Vector3(13.0, 0.1, -12.4),
		Vector3(-19.0, 2.85, -14.0), Vector3(19.0, 2.85, -14.0),
	]
	for index in range(cover_points.size()):
		_add_tactical_marker("CoverPoint%02d" % index, cover_points[index], "bot_cover_point")

	var flank_points: Array[Vector3] = [
		Vector3(-23, 0.1, 21), Vector3(23, 0.1, 21),
		Vector3(-23, 0.1, -12), Vector3(23, 0.1, -12),
		Vector3(-19, 2.85, -18), Vector3(19, 2.85, -18),
		Vector3(-4.5, 0.1, 0), Vector3(4.5, 0.1, 0),
	]
	for index in range(flank_points.size()):
		_add_tactical_marker("FlankPoint%02d" % index, flank_points[index], "bot_flank_point")
	for index in range(PEEK_SPOTS.size()):
		_add_tactical_marker("PeekTrainingSpot%02d" % index, PEEK_SPOTS[index], "peek_training_spot")


func _add_tactical_marker(marker_name: String, marker_position: Vector3, group_name: StringName) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = marker_position
	marker.add_to_group(group_name)
	add_child(marker)


func _build_kill_volume() -> void:
	var kill_volume := KillVolume.new()
	kill_volume.name = "KillVolume"
	kill_volume.position = Vector3(0, -16, 0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(160, 8, 160)
	collision.shape = shape
	kill_volume.add_child(collision)
	add_child(kill_volume)


func _add_box(node_name: String, position: Vector3, size: Vector3, material_key: String, rotation: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation = rotation
	body.collision_layer = 1
	body.collision_mask = 2
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = materials[material_key]
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	# Thin, non-colliding stone coping distinguishes traversal edges and cover.
	if material_key in ["platform", "stone_light", "cover"] and not node_name.contains("Crenel"):
		for side in [-1.0, 1.0]:
			var trim := MeshInstance3D.new()
			var trim_mesh := BoxMesh.new()
			trim_mesh.size = Vector3(0.1, 0.025, size.z)
			trim_mesh.material = materials["edge"]
			trim.mesh = trim_mesh
			trim.position = Vector3(side * (size.x * 0.5 - 0.05), size.y * 0.5 + 0.015, 0)
			trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.add_child(trim)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func _add_cylinder(node_name: String, position: Vector3, radius: float, height: float, material_key: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 2
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = materials[material_key]
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func _add_stairs(node_prefix: String, start: Vector3, direction: Vector3, steps: int, width: float, depth: float, rise: float) -> void:
	for index in range(steps):
		var height := rise * float(index + 1)
		var position := start + direction * depth * float(index)
		position.y += height * 0.5
		var size := Vector3(width, height, depth + 0.04)
		if absf(direction.x) > 0.5:
			size = Vector3(depth + 0.04, height, width)
		_add_box("%s%d" % [node_prefix, index], position, size, "stone_light")
