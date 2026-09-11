extends Node3D

@export_enum("Katana", "Huntsman", "Vanguard", "Sword", "Nodachi", "Falcon", "Ironclad", "Wand", "Service Glock", "Twin Glocks") var model: int = 0
var flash: MeshInstance3D
var trail: MeshInstance3D
var previous_ammo: int = -1
var flash_time: float = 0.0
var recoil_offset: float = 0.0
var base_position: Vector3
var base_rotation: Vector3

func _ready() -> void:
	var weapon := get_parent() as WeaponBase
	base_position = position
	base_rotation = rotation
	for child: Node in weapon.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	var steel := PlaceholderParts.material(Color(0.58, 0.66, 0.72), 0.75)
	var iron := PlaceholderParts.material(Color(0.12, 0.15, 0.18), 0.6)
	var wood := PlaceholderParts.material(Color(0.25, 0.12, 0.065))
	var brass := PlaceholderParts.material(Color(0.62, 0.43, 0.18), 0.6)
	if model == 0 or model == 3 or model == 4:
		var heavy := model == 3 or model == 4
		var nodachi := model == 4
		var blade_length := 1.72 if nodachi else 1.35
		var blade := PlaceholderParts.cylinder(self, Vector3(0, 0, -0.96 if nodachi else -0.78), 0.075 if nodachi else (0.09 if heavy else 0.048), blade_length, steel, 0.0)
		blade.rotation.x = -PI / 2.0
		blade.scale.y = 1.0
		blade.scale.z = 0.32
		PlaceholderParts.box(self, Vector3(0, 0, -0.10), Vector3(0.38 if nodachi else (0.46 if heavy else 0.19), 0.055, 0.1), brass)
		var grip := PlaceholderParts.cylinder(self, Vector3(0, 0, 0.11), 0.047, 0.35, wood)
		grip.rotation.x = PI / 2.0
		for i: int in 5:
			PlaceholderParts.box(self, Vector3(0, 0, -0.02 + i * 0.065), Vector3(0.096, 0.096, 0.018), iron)
		PlaceholderParts.box(self, Vector3(0, 0, 0.3), Vector3(0.10, 0.1, 0.07), brass)
		trail = PlaceholderParts.box(self, Vector3(0.14, 0, -0.9 if nodachi else -0.77), Vector3(0.018, 0.014, 1.55 if nodachi else 1.2), PlaceholderParts.material(Color(0.65, 0.9, 1.0), 0, true))
		trail.visible = false
	elif model == 7:
		var shaft := PlaceholderParts.cylinder(self, Vector3(0, 0, -0.38), 0.045, 0.85, wood)
		shaft.rotation.x = PI / 2.0
		PlaceholderParts.cylinder(self, Vector3(0, 0, 0.08), 0.065, 0.13, brass)
		var focus := PlaceholderParts.cylinder(self, Vector3(0, 0, -0.88), 0.14, 0.24, PlaceholderParts.material(Color(0.2, 0.48, 1.0), 0, true))
		focus.rotation.x = PI / 2.0
	else:
		var long_rifle := model == 1 or model == 6
		var pistol := model == 8 or model == 9
		var body_length := 0.36 if pistol else (0.72 if model == 6 else 0.62)
		PlaceholderParts.box(self, Vector3(0, 0, -0.22 if pistol else -0.29), Vector3(0.15, 0.13, body_length), iron)
		PlaceholderParts.box(self, Vector3(0, -0.025, 0.1), Vector3(0.13, 0.19, 0.35), wood)
		if not pistol:
			PlaceholderParts.box(self, Vector3(0, -0.09, -0.56), Vector3(0.14, 0.1, 0.43), wood if long_rifle else iron)
		var barrel_position := -0.52 if pistol else (-1.02 if long_rifle else -0.79)
		var barrel_length := 0.28 if pistol else (0.95 if long_rifle else 0.55)
		var barrel := PlaceholderParts.cylinder(self, Vector3(0, 0.015, barrel_position), 0.029 if not pistol else 0.022, barrel_length, iron)
		barrel.rotation.x = PI / 2.0
		var grip := PlaceholderParts.box(self, Vector3(0, -0.17, -0.05), Vector3(0.10, 0.24, 0.12), wood)
		grip.rotation.x = -0.25
		if long_rifle:
			var scope := PlaceholderParts.cylinder(self, Vector3(0, 0.145, -0.32), 0.064, 0.42, iron)
			scope.rotation.x = PI / 2.0
			var lens := PlaceholderParts.cylinder(self, Vector3(0, 0.145, -0.54), 0.052, 0.014, PlaceholderParts.material(Color(0.19, 0.62, 0.7), 0, true))
			lens.rotation.x = PI / 2.0
		elif not pistol:
			var magazine := PlaceholderParts.box(self, Vector3(0, -0.22, -0.35), Vector3(0.1, 0.32, 0.18), iron)
			magazine.rotation.x = 0.17
			PlaceholderParts.box(self, Vector3(0, 0.11, -0.42), Vector3(0.05, 0.07, 0.45), brass)
		if model == 5:
			PlaceholderParts.box(self, Vector3(0, 0.1, -0.35), Vector3(0.18, 0.08, 0.5), brass)
		if model == 9:
			PlaceholderParts.box(self, Vector3(0.2, 0, -0.22), Vector3(0.13, 0.13, 0.36), iron)
		PlaceholderParts.box(self, Vector3(0.085, 0, -0.17), Vector3(0.04, 0.045, 0.15), brass)
		var muzzle_z := barrel_position - barrel_length * 0.55
		flash = PlaceholderParts.cylinder(self, Vector3(0, 0.015, muzzle_z), 0.10, 0.20, PlaceholderParts.material(Color(1.0, 0.78, 0.29), 0, true), 0.0)
		flash.rotation.x = PI / 2.0
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.visible = false

func _process(delta: float) -> void:
	var weapon := get_parent() as WeaponBase
	recoil_offset = move_toward(recoil_offset, 0.0, delta * 1.8)
	if flash != null:
		var ammo := int(weapon.get("ammo"))
		if previous_ammo < 0:
			previous_ammo = ammo
		elif ammo < previous_ammo and weapon.equipped:
			flash_time = 0.045
			recoil_offset = 0.075
		previous_ammo = ammo
		flash_time = maxf(0, flash_time - delta)
		flash.visible = flash_time > 0 and weapon.equipped and GameSettings.effects_quality > 0
		var reloading := bool(weapon.get("is_reloading"))
		rotation.x = lerpf(rotation.x, base_rotation.x + (0.28 if reloading else 0.0), minf(1.0, delta * 10.0))
		position = position.lerp(base_position + Vector3(0.0, -0.04 if reloading else 0.0, recoil_offset), minf(1.0, delta * 18.0))
	if trail != null:
		trail.visible = weapon.equipped and float(weapon.get("swing_remaining")) > 0.05
