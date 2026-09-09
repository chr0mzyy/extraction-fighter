extends Node3D

@export_enum("Katana", "Huntsman", "Vanguard", "Sword") var model: int = 0
var flash: MeshInstance3D
var trail: MeshInstance3D
var previous_ammo: int = -1
var flash_time: float = 0.0

func _ready() -> void:
	var weapon := get_parent() as WeaponBase
	for child: Node in weapon.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	var steel := PlaceholderParts.material(Color(0.58, 0.66, 0.72), 0.75)
	var iron := PlaceholderParts.material(Color(0.12, 0.15, 0.18), 0.6)
	var wood := PlaceholderParts.material(Color(0.25, 0.12, 0.065))
	var brass := PlaceholderParts.material(Color(0.62, 0.43, 0.18), 0.6)
	if model == 0 or model == 3:
		var heavy := model == 3
		var blade := PlaceholderParts.cylinder(self, Vector3(0, 0, -0.78), 0.09 if heavy else 0.048, 1.35, steel, 0.0)
		blade.rotation.x = -PI / 2.0
		blade.scale.y = 1.0
		blade.scale.z = 0.32
		PlaceholderParts.box(self, Vector3(0, 0, -0.10), Vector3(0.46 if heavy else 0.19, 0.055, 0.1), brass)
		var grip := PlaceholderParts.cylinder(self, Vector3(0, 0, 0.11), 0.047, 0.35, wood)
		grip.rotation.x = PI / 2.0
		for i: int in 5:
			PlaceholderParts.box(self, Vector3(0, 0, -0.02 + i * 0.065), Vector3(0.096, 0.096, 0.018), iron)
		PlaceholderParts.box(self, Vector3(0, 0, 0.3), Vector3(0.10, 0.1, 0.07), brass)
		trail = PlaceholderParts.box(self, Vector3(0.14, 0, -0.77), Vector3(0.018, 0.014, 1.2), PlaceholderParts.material(Color(0.65, 0.9, 1.0), 0, true))
		trail.visible = false
	else:
		var long_rifle := model == 1
		PlaceholderParts.box(self, Vector3(0, 0, -0.29), Vector3(0.15, 0.13, 0.62), iron)
		PlaceholderParts.box(self, Vector3(0, -0.025, 0.1), Vector3(0.13, 0.19, 0.35), wood)
		PlaceholderParts.box(self, Vector3(0, -0.09, -0.56), Vector3(0.14, 0.1, 0.43), wood if long_rifle else iron)
		var barrel := PlaceholderParts.cylinder(self, Vector3(0, 0.015, -0.98 if long_rifle else -0.79), 0.029, 0.9 if long_rifle else 0.55, iron)
		barrel.rotation.x = PI / 2.0
		var grip := PlaceholderParts.box(self, Vector3(0, -0.17, -0.05), Vector3(0.10, 0.24, 0.12), wood)
		grip.rotation.x = -0.25
		if long_rifle:
			var scope := PlaceholderParts.cylinder(self, Vector3(0, 0.145, -0.32), 0.064, 0.42, iron)
			scope.rotation.x = PI / 2.0
			var lens := PlaceholderParts.cylinder(self, Vector3(0, 0.145, -0.54), 0.052, 0.014, PlaceholderParts.material(Color(0.19, 0.62, 0.7), 0, true))
			lens.rotation.x = PI / 2.0
		else:
			var magazine := PlaceholderParts.box(self, Vector3(0, -0.22, -0.35), Vector3(0.1, 0.32, 0.18), iron)
			magazine.rotation.x = 0.17
			PlaceholderParts.box(self, Vector3(0, 0.11, -0.42), Vector3(0.05, 0.07, 0.45), brass)
		PlaceholderParts.box(self, Vector3(0.085, 0, -0.17), Vector3(0.04, 0.045, 0.15), brass)
		flash = PlaceholderParts.cylinder(self, Vector3(0, 0.015, -1.49 if long_rifle else -1.11), 0.10, 0.20, PlaceholderParts.material(Color(1.0, 0.78, 0.29), 0, true), 0.0)
		flash.rotation.x = PI / 2.0
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.visible = false

func _process(delta: float) -> void:
	var weapon := get_parent() as WeaponBase
	if flash != null:
		var ammo := int(weapon.get("ammo"))
		if previous_ammo >= 0 and ammo < previous_ammo and weapon.equipped:
			flash_time = 0.045
		previous_ammo = ammo
		flash_time = maxf(0, flash_time - delta)
		flash.visible = flash_time > 0 and weapon.equipped
	if trail != null:
		trail.visible = weapon.equipped and float(weapon.get("swing_remaining")) > 0.05
