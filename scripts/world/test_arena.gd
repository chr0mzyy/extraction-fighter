class_name TestArena
extends Node3D

var materials: Dictionary = {}


func _ready() -> void:
	_create_materials()
	_build_floor_and_bounds()
	_build_vertical_routes()
	_build_cover_and_corridors()
	_build_route_markings()
	_build_ai_tactical_points()
	_build_launch_pads()
	_build_kill_volume()


func _create_materials() -> void:
	materials["stone"] = _material(Color(0.22, 0.25, 0.29), 0.92)
	materials["floor"] = _material(Color(0.32, 0.35, 0.38), 0.95)
	materials["stone_light"] = _material(Color(0.48, 0.46, 0.40), 0.88)
	materials["platform"] = _material(Color(0.35, 0.40, 0.43), 0.82)
	materials["cover"] = _material(Color(0.40, 0.29, 0.18), 0.9)
	materials["accent"] = _material(Color(0.30, 0.27, 0.25), 0.86)
	materials["edge"] = _material(Color(0.62, 0.55, 0.37), 0.9)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result


func _build_floor_and_bounds() -> void:
	_add_box("ArenaFloor", Vector3(0, -0.5, 0), Vector3(58, 1, 58), "floor")
	_add_box("NorthWall", Vector3(0, 3.5, -29), Vector3(60, 8, 1.2), "stone")
	_add_box("SouthWall", Vector3(0, 3.5, 29), Vector3(60, 8, 1.2), "stone")
	_add_box("WestWall", Vector3(-29, 3.5, 0), Vector3(1.2, 8, 60), "stone")
	_add_box("EastWall", Vector3(29, 3.5, 0), Vector3(1.2, 8, 60), "stone")
	# Crenellations make the silhouette read as a ruined dark arena.
	for x in range(-27, 28, 6):
		_add_box("NorthCrenel%d" % x, Vector3(x, 8.1, -29), Vector3(3, 1.4, 1.5), "stone_light")
		_add_box("SouthCrenel%d" % x, Vector3(x, 8.1, 29), Vector3(3, 1.4, 1.5), "stone_light")


func _build_vertical_routes() -> void:
	# West and east sniper platforms, each with a broad ramp approach.
	_add_box("WestPlatform", Vector3(-20, 3.0, -4), Vector3(13, 0.7, 13), "platform")
	_add_box("WestRamp", Vector3(-11.8, 1.35, -4), Vector3(10.5, 0.55, 4.2), "stone_light", Vector3(0, 0, -0.265))
	_add_box("EastPlatform", Vector3(20, 4.8, 6), Vector3(13, 0.7, 13), "platform")
	_add_box("EastRamp", Vector3(11.7, 2.3, 6), Vector3(11.5, 0.55, 4.2), "stone_light", Vector3(0, 0, 0.39))

	# Northern balcony creates the longest sightline and a protected lower route.
	_add_box("NorthBalcony", Vector3(0, 5.7, -22), Vector3(30, 0.75, 7), "platform")
	_add_box("NorthBalconyBack", Vector3(0, 7.5, -25.2), Vector3(31, 4.2, 0.8), "stone")
	_add_box("NorthRampWest", Vector3(-18.2, 2.8, -18.2), Vector3(4, 0.55, 13), "stone_light", Vector3(0.43, 0, 0))
	_add_box("NorthRampEast", Vector3(18.2, 2.8, -18.2), Vector3(4, 0.55, 13), "stone_light", Vector3(0.43, 0, 0))

	# Broken central bridge and stepping gap for jump/dash tests.
	_add_box("CenterBridgeWest", Vector3(-5.4, 2.45, 1), Vector3(8.2, 0.6, 4), "stone_light")
	_add_box("CenterBridgeEast", Vector3(5.4, 2.45, 1), Vector3(8.2, 0.6, 4), "stone_light")
	_add_box("CenterRampSouth", Vector3(0, 1.15, 7.1), Vector3(4, 0.5, 9), "stone_light", Vector3(0.25, 0, 0))
	_add_box("CenterRampNorth", Vector3(0, 1.15, -5.1), Vector3(4, 0.5, 9), "stone_light", Vector3(-0.25, 0, 0))

	# Readable stairs on both sides, with forgiving shallow steps.
	_add_stairs("WestStairs", Vector3(-24, 0, 11), Vector3(0, 0, -1), 10, 3.2, 0.72, 0.31)
	_add_stairs("EastStairs", Vector3(24, 0, 18), Vector3(0, 0, -1), 14, 3.2, 0.66, 0.35)


func _build_cover_and_corridors() -> void:
	# Central broken keep: close-range routes around a long open lane.
	_add_box("KeepWallA", Vector3(-7, 1.7, 13), Vector3(0.8, 3.4, 13), "stone")
	_add_box("KeepWallB", Vector3(7, 1.7, 13), Vector3(0.8, 3.4, 13), "stone")
	_add_box("KeepCrossWall", Vector3(0, 1.7, 19), Vector3(14.8, 3.4, 0.8), "stone")
	_add_box("FlankWallWest", Vector3(-18, 1.5, 16), Vector3(0.8, 3.0, 12), "stone")
	_add_box("FlankWallEast", Vector3(18, 1.5, -10), Vector3(0.8, 3.0, 11), "stone")

	for position in [Vector3(-12, 1.8, -13), Vector3(12, 1.8, -12), Vector3(-16, 1.8, 8), Vector3(15, 1.8, 18)]:
		_add_cylinder("Pillar", position, 1.15, 3.6, "stone_light")

	for position in [Vector3(-3, 0.8, -13), Vector3(4, 0.8, -10), Vector3(-13, 0.8, 20), Vector3(12, 0.8, 14), Vector3(1, 0.8, 23)]:
		_add_box("Cover", position, Vector3(2.5, 1.6, 1.5), "cover")

	# Narrow wall segments produce peek angles without sealing traversal.
	_add_box("MidWallNW", Vector3(-8, 1.25, -4), Vector3(5, 2.5, 0.65), "accent")
	_add_box("MidWallSE", Vector3(9, 1.25, 5), Vector3(5, 2.5, 0.65), "accent")
	_add_box("HighCoverWest", Vector3(-20, 4.0, -7.5), Vector3(4.5, 1.5, 0.7), "cover")
	_add_box("HighCoverEast", Vector3(20, 5.8, 9.5), Vector3(4.5, 1.5, 0.7), "cover")
	_add_box("BalconyCoverA", Vector3(-8, 6.65, -20.5), Vector3(3.5, 1.2, 0.8), "cover")
	_add_box("BalconyCoverB", Vector3(8, 6.65, -20.5), Vector3(3.5, 1.2, 0.8), "cover")


func _build_launch_pads() -> void:
	var pad_one := LaunchPad.new()
	pad_one.name = "LaunchPadSouth"
	pad_one.position = Vector3(-11, 0.15, 23)
	pad_one.rotation.y = 0.0
	pad_one.add_to_group("bot_vertical_route")
	add_child(pad_one)
	var pad_two := LaunchPad.new()
	pad_two.name = "LaunchPadNorth"
	pad_two.position = Vector3(11, 0.15, -16)
	pad_two.rotation.y = PI
	pad_two.add_to_group("bot_vertical_route")
	add_child(pad_two)
	var pad_three := LaunchPad.new()
	pad_three.name = "LaunchPadWestHigh"
	pad_three.position = Vector3(-20, 3.55, -1)
	pad_three.vertical_speed = 11.5
	pad_three.forward_speed = 8.5
	pad_three.rotation.y = -PI * 0.5
	pad_three.add_to_group("bot_vertical_route")
	add_child(pad_three)


func _build_route_markings() -> void:
	# Flush paving bands communicate the keep approach and outer flanks.
	# Meshes only: no new collision seams for sliding or the bot.
	for route in [
		[Vector3(0, 0.012, 12), Vector3(3.2, 0.015, 10)],
		[Vector3(-22, 0.012, 18), Vector3(2.8, 0.015, 12)],
		[Vector3(22, 0.012, -15), Vector3(2.8, 0.015, 16)]
	]:
		var paving := MeshInstance3D.new()
		var paving_mesh := BoxMesh.new()
		paving_mesh.size = route[1]
		paving_mesh.material = materials["stone_light"]
		paving.mesh = paving_mesh
		paving.position = route[0]
		paving.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(paving)


func _build_ai_tactical_points() -> void:
	# Lightweight authored hints keep tactical movement robust without a navigation bake.
	# Cover points are paired across obstacles so the bot can pick the side hidden from
	# the player's current angle instead of treating cover as a fixed destination.
	var cover_points: Array[Vector3] = [
		Vector3(-12, 0.1, -15.2), Vector3(-12, 0.1, -10.8),
		Vector3(12, 0.1, -14.2), Vector3(12, 0.1, -9.8),
		Vector3(-18.9, 0.1, 11.0), Vector3(-17.1, 0.1, 20.5),
		Vector3(17.1, 0.1, -15.0), Vector3(18.9, 0.1, -4.5),
		Vector3(-3, 0.1, -15.0), Vector3(4, 0.1, -8.2),
		Vector3(-13, 0.1, 22.0), Vector3(12, 0.1, 16.0),
		Vector3(-20, 3.45, -5.8), Vector3(20, 5.25, 8.0),
		Vector3(-8, 6.1, -19.3), Vector3(8, 6.1, -19.3),
	]
	for index in range(cover_points.size()):
		_add_tactical_marker("CoverPoint%02d" % index, cover_points[index], "bot_cover_point")

	var flank_points: Array[Vector3] = [
		Vector3(-24, 0.1, 19), Vector3(24, 0.1, 19),
		Vector3(-24, 0.1, -17), Vector3(24, 0.1, -17),
		Vector3(-20, 3.45, 1), Vector3(20, 5.25, 3),
		Vector3(-16, 6.1, -20), Vector3(16, 6.1, -20),
	]
	for index in range(flank_points.size()):
		_add_tactical_marker("FlankPoint%02d" % index, flank_points[index], "bot_flank_point")


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
