extends MeshInstance3D

@export var accent: Color = Color(0.12, 0.43, 0.55)

func _ready() -> void:
	# Retain the existing visual root so stance scaling and FPP hiding still apply.
	mesh = null
	var steel := PlaceholderParts.material(Color(0.30, 0.34, 0.39), 0.5)
	var cloth := PlaceholderParts.material(accent)
	var leather := PlaceholderParts.material(Color(0.075, 0.065, 0.06))
	var trim := PlaceholderParts.material(Color(0.62, 0.52, 0.30), 0.5)
	PlaceholderParts.cylinder(self, Vector3(0, 0.27, 0), 0.31, 0.53, steel, 0.37)
	PlaceholderParts.box(self, Vector3(0, 0.2, -0.25), Vector3(0.23, 0.6, 0.07), cloth)
	PlaceholderParts.box(self, Vector3(0, -0.06, 0), Vector3(0.52, 0.12, 0.34), leather)
	PlaceholderParts.box(self, Vector3(0, -0.05, -0.2), Vector3(0.1, 0.1, 0.04), trim)
	PlaceholderParts.cylinder(self, Vector3(0, 0.70, 0), 0.23, 0.36, steel, 0.18)
	PlaceholderParts.box(self, Vector3(0, 0.71, -0.215), Vector3(0.3, 0.055, 0.03), leather)
	PlaceholderParts.box(self, Vector3(0, 0.6, -0.23), Vector3(0.045, 0.19, 0.04), trim)
	for side: float in [-1.0, 1.0]:
		PlaceholderParts.cylinder(self, Vector3(side * 0.39, 0.4, 0), 0.19, 0.22, cloth, 0.14)
		PlaceholderParts.cylinder(self, Vector3(side * 0.39, 0.10, 0), 0.105, 0.42, steel)
		PlaceholderParts.box(self, Vector3(side * 0.39, -0.15, -0.02), Vector3(0.15, 0.18, 0.17), leather)
		PlaceholderParts.cylinder(self, Vector3(side * 0.16, -0.38, 0), 0.125, 0.5, cloth)
		PlaceholderParts.box(self, Vector3(side * 0.16, -0.55, -0.1), Vector3(0.18, 0.19, 0.13), steel)
		PlaceholderParts.box(self, Vector3(side * 0.16, -0.77, -0.055), Vector3(0.22, 0.25, 0.34), leather)
