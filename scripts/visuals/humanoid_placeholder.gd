extends MeshInstance3D

@export var accent: Color = Color(0.04, 0.72, 0.88)
@export var show_preview_weapon: bool = false

var telegraph: MeshInstance3D
var telegraph_remaining: float = 0.0


func _ready() -> void:
	# The visual root remains the animation target used by crouch, FPP hiding and VFX.
	mesh = null
	var armor := PlaceholderParts.material(Color(0.13, 0.16, 0.18), 0.72)
	var armor_light := PlaceholderParts.material(Color(0.30, 0.34, 0.36), 0.68)
	var undersuit := PlaceholderParts.material(Color(0.025, 0.035, 0.042), 0.28)
	var fabric := PlaceholderParts.material(accent.darkened(0.34), 0.16)
	var accent_metal := PlaceholderParts.material(accent, 0.52)
	var accent_glow := PlaceholderParts.material(accent.lightened(0.16), 0.0, true)
	var visor := PlaceholderParts.material(Color(0.025, 0.18, 0.24).lerp(accent, 0.42), 0.78, true)

	# Layered plate carrier and abdominal articulation.
	PlaceholderParts.box(self, Vector3(0.0, 0.24, 0.02), Vector3(0.48, 0.50, 0.30), fabric)
	PlaceholderParts.box(self, Vector3(0.0, 0.30, -0.175), Vector3(0.40, 0.30, 0.075), armor)
	PlaceholderParts.box(self, Vector3(0.0, 0.12, -0.185), Vector3(0.34, 0.075, 0.065), armor_light)
	PlaceholderParts.box(self, Vector3(0.0, 0.365, -0.218), Vector3(0.25, 0.045, 0.025), accent_glow)
	for rib_y: float in [-0.05, 0.015, 0.08]:
		PlaceholderParts.box(self, Vector3(0.0, rib_y, -0.115), Vector3(0.32, 0.045, 0.10), armor)

	# Backpack, shoulder radio and belt modules create a recognisable tactical silhouette.
	PlaceholderParts.box(self, Vector3(0.0, 0.25, 0.22), Vector3(0.34, 0.44, 0.18), armor)
	PlaceholderParts.box(self, Vector3(0.0, 0.15, 0.325), Vector3(0.25, 0.18, 0.07), undersuit)
	PlaceholderParts.box(self, Vector3(0.0, -0.105, 0.0), Vector3(0.56, 0.105, 0.34), undersuit)
	for pouch_x: float in [-0.19, 0.0, 0.19]:
		PlaceholderParts.box(self, Vector3(pouch_x, -0.105, -0.205), Vector3(0.15, 0.15, 0.105), armor)
	PlaceholderParts.box(self, Vector3(0.0, -0.09, -0.265), Vector3(0.10, 0.055, 0.025), accent_metal)
	PlaceholderParts.cylinder(self, Vector3(0.255, 0.48, 0.16), 0.028, 0.30, armor_light, 0.018)
	PlaceholderParts.box(self, Vector3(0.255, 0.65, 0.16), Vector3(0.075, 0.055, 0.055), accent_glow)

	# Helmet: rounded shell, brow, luminous visor, respirator and side rails.
	PlaceholderParts.sphere(self, Vector3(0.0, 0.72, 0.0), 0.255, armor, Vector3(0.94, 0.83, 1.02))
	PlaceholderParts.box(self, Vector3(0.0, 0.79, -0.205), Vector3(0.40, 0.08, 0.10), armor_light)
	PlaceholderParts.box(self, Vector3(0.0, 0.715, -0.252), Vector3(0.34, 0.105, 0.035), visor)
	PlaceholderParts.box(self, Vector3(0.0, 0.625, -0.225), Vector3(0.22, 0.10, 0.075), armor)
	PlaceholderParts.box(self, Vector3(0.0, 0.615, -0.272), Vector3(0.06, 0.035, 0.025), accent_glow)
	for side: float in [-1.0, 1.0]:
		PlaceholderParts.box(self, Vector3(side * 0.235, 0.72, -0.01), Vector3(0.055, 0.17, 0.19), armor_light)
		PlaceholderParts.box(self, Vector3(side * 0.268, 0.72, -0.02), Vector3(0.025, 0.07, 0.12), accent_metal)

	# Armoured arms, gloves and asymmetric wrist tech.
	for side: float in [-1.0, 1.0]:
		var shoulder := PlaceholderParts.sphere(self, Vector3(side * 0.37, 0.39, 0.0), 0.19, fabric, Vector3(1.16, 0.78, 1.05))
		shoulder.rotation.z = side * 0.08
		var shoulder_plate := PlaceholderParts.box(self, Vector3(side * 0.405, 0.405, -0.075), Vector3(0.22, 0.13, 0.22), armor)
		shoulder_plate.rotation.z = side * 0.12
		PlaceholderParts.box(self, Vector3(side * 0.405, 0.42, -0.205), Vector3(0.12, 0.035, 0.025), accent_metal)
		PlaceholderParts.cylinder(self, Vector3(side * 0.40, 0.16, 0.0), 0.102, 0.34, fabric, 0.085)
		PlaceholderParts.box(self, Vector3(side * 0.40, -0.02, -0.075), Vector3(0.16, 0.13, 0.18), armor_light)
		PlaceholderParts.cylinder(self, Vector3(side * 0.40, -0.21, 0.0), 0.092, 0.27, undersuit, 0.074)
		PlaceholderParts.box(self, Vector3(side * 0.40, -0.365, -0.035), Vector3(0.15, 0.14, 0.17), armor)
		if side > 0.0:
			PlaceholderParts.box(self, Vector3(side * 0.49, -0.18, -0.07), Vector3(0.055, 0.16, 0.12), accent_metal)

	# Separated legs, thigh armour, knee caps and weighted boots.
	for side: float in [-1.0, 1.0]:
		PlaceholderParts.cylinder(self, Vector3(side * 0.155, -0.34, 0.015), 0.13, 0.42, fabric, 0.105)
		PlaceholderParts.box(self, Vector3(side * 0.155, -0.32, -0.105), Vector3(0.20, 0.29, 0.10), armor)
		PlaceholderParts.box(self, Vector3(side * 0.155, -0.54, -0.125), Vector3(0.18, 0.15, 0.13), armor_light)
		PlaceholderParts.box(self, Vector3(side * 0.155, -0.54, -0.198), Vector3(0.09, 0.045, 0.025), accent_metal)
		PlaceholderParts.cylinder(self, Vector3(side * 0.155, -0.69, 0.025), 0.105, 0.27, undersuit, 0.085)
		PlaceholderParts.box(self, Vector3(side * 0.155, -0.845, -0.075), Vector3(0.23, 0.18, 0.36), armor)
		PlaceholderParts.box(self, Vector3(side * 0.155, -0.845, -0.27), Vector3(0.24, 0.08, 0.11), armor_light)

	if show_preview_weapon:
		_build_preview_rifle(armor, armor_light, undersuit, accent_metal, accent_glow)

	telegraph = PlaceholderParts.cylinder(self, Vector3(0.0, -0.93, 0.0), 0.64, 0.045, PlaceholderParts.material(Color(1.0, 0.26, 0.12), 0.0, true), 0.0)
	telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	telegraph.visible = false


func _build_preview_rifle(armor: Material, armor_light: Material, undersuit: Material, accent_metal: Material, accent_glow: Material) -> void:
	var rifle := Node3D.new()
	rifle.name = "PreviewRifle"
	rifle.position = Vector3(0.02, 0.18, 0.28)
	rifle.rotation.z = -0.72
	rifle.scale = Vector3.ONE * 0.82
	add_child(rifle)
	PlaceholderParts.box(rifle, Vector3(-0.48, 0.0, 0.0), Vector3(0.34, 0.18, 0.16), undersuit)
	PlaceholderParts.box(rifle, Vector3(-0.20, 0.0, 0.0), Vector3(0.28, 0.23, 0.18), armor)
	PlaceholderParts.box(rifle, Vector3(0.08, 0.0, 0.0), Vector3(0.36, 0.24, 0.19), armor_light)
	PlaceholderParts.box(rifle, Vector3(0.42, 0.0, 0.0), Vector3(0.36, 0.16, 0.15), armor)
	PlaceholderParts.box(rifle, Vector3(0.70, -0.01, 0.0), Vector3(0.28, 0.055, 0.055), accent_metal)
	PlaceholderParts.box(rifle, Vector3(0.04, 0.16, 0.0), Vector3(0.25, 0.055, 0.09), undersuit)
	PlaceholderParts.box(rifle, Vector3(0.04, 0.205, -0.005), Vector3(0.12, 0.035, 0.045), accent_glow)
	var magazine := PlaceholderParts.box(rifle, Vector3(0.04, -0.20, 0.0), Vector3(0.14, 0.28, 0.12), armor)
	magazine.rotation.z = -0.12
	var grip := PlaceholderParts.box(rifle, Vector3(0.25, -0.15, 0.0), Vector3(0.10, 0.22, 0.11), undersuit)
	grip.rotation.z = -0.22


func _process(delta: float) -> void:
	telegraph_remaining = maxf(0.0, telegraph_remaining - delta)
	if telegraph != null:
		telegraph.visible = telegraph_remaining > 0.0 and visible
		if telegraph.visible:
			var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.024) * 0.12
			telegraph.scale = Vector3(pulse, 1.0, pulse)


func telegraph_attack(duration: float = 0.32, color: Color = Color(1.0, 0.26, 0.12)) -> void:
	telegraph_remaining = maxf(telegraph_remaining, duration)
	if telegraph != null:
		telegraph.material_override = PlaceholderParts.material(color, 0.0, true)
