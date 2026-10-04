extends Node3D

@export_enum("Katana", "Huntsman", "Vanguard", "Sword", "Nodachi", "Falcon", "Ironclad", "Wand", "Service Glock", "Twin Glocks") var model: int = 0

const WORN_IDS: Array[String] = [
	"rusty_katana", "chipped_nodachi", "cracked_long_rifle", "worn_assault_rifle",
	"damaged_burst_rifle", "rusty_battle_rifle", "chipped_sword", "cracked_wand",
	"worn_glock", "scuffed_akimbo",
]
const MYTHIC_IDS: Array[String] = [
	"phantom_katana", "bloodrush_nodachi", "skybreaker", "rushfang", "trident",
	"kingslayer", "oathbreaker", "rift_wand", "quickfang", "hell_twins",
]

var flash: MeshInstance3D
var flash_nodes: Array[MeshInstance3D] = []
var smoke_nodes: Array[MeshInstance3D] = []
var ads_occluders: Array[MeshInstance3D] = []
var active_flash_index: int = 0
var trail: MeshInstance3D
var generated_root: Node3D
var variant_id: String = ""
var variant_tier: int = 1
var previous_ammo: int = -1
var flash_time: float = 0.0
var smoke_time: float = 0.0
var recoil_offset: float = 0.0
var base_position: Vector3
var base_rotation: Vector3
var part_count: int = 0


func _ready() -> void:
	var weapon := get_parent() as WeaponBase
	base_position = position
	base_rotation = rotation
	if weapon != null:
		weapon.presentation_fired.connect(_on_weapon_fired)
		for child: Node in weapon.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).visible = false
	_rebuild_model(variant_id if not variant_id.is_empty() else _default_variant_id())


func configure_variant(definition: ItemDefinition) -> void:
	variant_id = String(definition.id) if definition != null else _default_variant_id()
	if is_node_ready():
		_rebuild_model(variant_id)


func _rebuild_model(item_id: String) -> void:
	if is_instance_valid(generated_root):
		generated_root.free()
	generated_root = Node3D.new()
	generated_root.name = "Generated_%s" % item_id
	add_child(generated_root)
	variant_id = item_id
	variant_tier = 0 if item_id in WORN_IDS else (2 if item_id in MYTHIC_IDS else 1)
	part_count = 0
	flash = null
	flash_nodes.clear()
	smoke_nodes.clear()
	ads_occluders.clear()
	trail = null
	var palette := _make_palette()
	match model:
		0: _build_blade(palette, 0)
		1: _build_rifle(palette, 0)
		2: _build_rifle(palette, 1)
		3: _build_blade(palette, 1)
		4: _build_blade(palette, 2)
		5: _build_rifle(palette, 2)
		6: _build_rifle(palette, 3)
		7: _build_wand(palette)
		8: _build_pistol(palette, Vector3.ZERO, false)
		9: _build_akimbo(palette)
	generated_root.set_meta("variant_id", variant_id)
	generated_root.set_meta("variant_tier", variant_tier)
	generated_root.set_meta("part_count", part_count)


func _make_palette() -> Dictionary:
	var family_hues: Array[float] = [0.52, 0.50, 0.55, 0.10, 0.00, 0.34, 0.13, 0.73, 0.08, 0.96]
	var hue := family_hues[clampi(model, 0, family_hues.size() - 1)]
	var accent_color := Color.from_hsv(hue, 0.72, 0.94)
	if variant_tier == 0:
		accent_color = Color(0.42, 0.24, 0.12).lerp(accent_color, 0.22)
	elif variant_tier == 2:
		accent_color = Color.from_hsv(fmod(hue + 0.05, 1.0), 0.82, 1.0)
	var primary_color := Color(0.11, 0.125, 0.14) if variant_tier != 0 else Color(0.19, 0.16, 0.13)
	var secondary_color := Color(0.34, 0.38, 0.42) if variant_tier == 1 else (Color(0.16, 0.18, 0.21) if variant_tier == 2 else Color(0.34, 0.29, 0.23))
	return {
		"primary": PlaceholderParts.material(primary_color, 0.78),
		"secondary": PlaceholderParts.material(secondary_color, 0.62),
		"accent": PlaceholderParts.material(accent_color, 0.72),
		"dark": PlaceholderParts.material(Color(0.025, 0.032, 0.04), 0.82),
		"wood": PlaceholderParts.material(Color(0.27, 0.12, 0.055) if variant_tier != 2 else Color(0.09, 0.045, 0.08), 0.12),
		"glow": PlaceholderParts.material(accent_color.lightened(0.2), 0.0, true),
		"lens": PlaceholderParts.material(Color(0.08, 0.62, 0.82) if variant_tier != 2 else accent_color.lightened(0.18), 0.0, true),
		"rust": PlaceholderParts.material(Color(0.35, 0.13, 0.045), 0.28),
	}


func _build_blade(p: Dictionary, blade_kind: int) -> void:
	var length: float = float([1.28, 1.12, 1.68][blade_kind])
	length += [-0.10, 0.0, 0.13][variant_tier]
	var width: float = float([0.075, 0.15, 0.095][blade_kind])
	var blade_z: float = -0.25 - length * 0.5
	_box(Vector3(0.0, 0.0, blade_z), Vector3(width, 0.038, length), p.secondary)
	_box(Vector3(width * 0.42, 0.0, blade_z - 0.03), Vector3(width * 0.24, 0.018, length * 0.92), p.accent)
	_box(Vector3(0.0, 0.0, -0.25 - length + 0.04), Vector3(width * 0.72, 0.042, 0.20), p.secondary, Vector3(0.0, 0.34, 0.0))
	var guard_width: float = float([0.22, 0.48, 0.38][blade_kind]) + variant_tier * 0.045
	_box(Vector3(0.0, 0.0, -0.18), Vector3(guard_width, 0.065, 0.10), p.accent, Vector3(0.0, 0.0, 0.08 * (variant_tier - 1)))
	if variant_tier == 2:
		_box(Vector3(-guard_width * 0.38, 0.0, -0.27), Vector3(0.055, 0.052, 0.25), p.glow, Vector3(0.0, -0.45, 0.0))
		_box(Vector3(guard_width * 0.38, 0.0, -0.27), Vector3(0.055, 0.052, 0.25), p.glow, Vector3(0.0, 0.45, 0.0))
	elif variant_tier == 0:
		for notch: int in 3:
			_box(Vector3(width * 0.57, 0.0, blade_z - length * 0.20 + notch * 0.24), Vector3(0.035, 0.045, 0.08), p.rust, Vector3(0.0, 0.25, 0.0))
	var grip_length := 0.38 if blade_kind != 2 else 0.55
	_cylinder(Vector3(0.0, 0.0, 0.07 + grip_length * 0.5), 0.045 if blade_kind == 0 else 0.052, grip_length, p.wood, Vector3(PI / 2.0, 0.0, 0.0))
	var wrap_count := 5 + variant_tier * 2
	for wrap: int in wrap_count:
		_box(Vector3(0.0, 0.0, 0.11 + wrap * grip_length / float(wrap_count)), Vector3(0.098, 0.07, 0.025), p.dark, Vector3(0.0, 0.0, 0.12 if wrap % 2 == 0 else -0.12))
	_cylinder(Vector3(0.0, 0.0, 0.11 + grip_length), 0.065, 0.075, p.accent, Vector3(PI / 2.0, 0.0, 0.0))
	trail = _box(Vector3(width + 0.035, 0.0, blade_z), Vector3(0.012, 0.012, length * 0.92), p.glow)
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.visible = false


func _build_rifle(p: Dictionary, rifle_kind: int) -> void:
	var receiver_length: float = float([0.78, 0.62, 0.66, 0.76][rifle_kind])
	var barrel_length: float = float([0.92, 0.56, 0.61, 0.74][rifle_kind]) + 0.08 * (variant_tier - 1)
	var stock_length: float = float([0.52, 0.40, 0.37, 0.48][rifle_kind])
	var receiver_z := -0.37
	_box(Vector3(0.0, 0.0, receiver_z), Vector3(0.18, 0.16, receiver_length), p.primary)
	_box(Vector3(0.0, 0.095, receiver_z - 0.04), Vector3(0.145, 0.055, receiver_length * 0.86), p.secondary)
	_box(Vector3(0.0, 0.01, -0.78), Vector3(0.16 + rifle_kind * 0.008, 0.13, 0.38), p.secondary)
	_box(Vector3(0.0, -0.02, 0.21), Vector3(0.16, 0.18, stock_length), p.wood if rifle_kind in [0, 3] else p.primary, Vector3(-0.05, 0.0, 0.0))
	_box(Vector3(0.0, 0.09, 0.18), Vector3(0.145, 0.065, stock_length * 0.62), p.accent)
	_box(Vector3(0.0, -0.13, -0.20), Vector3(0.105, 0.30, 0.14), p.dark, Vector3(-0.22, 0.0, 0.0))
	var magazine := _box(Vector3(0.0, -0.22, -0.43), Vector3(0.115 + rifle_kind * 0.008, 0.31, 0.17 + 0.035 * variant_tier), p.primary, Vector3(0.16 + rifle_kind * 0.025, 0.0, 0.0))
	magazine.name = "Magazine_%s" % variant_id
	if rifle_kind == 2:
		_box(Vector3(0.0, -0.19, -0.58), Vector3(0.15, 0.19, 0.15), p.accent, Vector3(0.12, 0.0, 0.0))
	var muzzle_z: float = -0.86 - barrel_length
	_cylinder(Vector3(0.0, 0.018, -0.86 - barrel_length * 0.5), 0.026 + rifle_kind * 0.002, barrel_length, p.dark, Vector3(PI / 2.0, 0.0, 0.0))
	_cylinder(Vector3(0.0, 0.018, muzzle_z), 0.052 if rifle_kind in [0, 3] else 0.044, 0.16 + 0.03 * variant_tier, p.accent, Vector3(PI / 2.0, 0.0, 0.0), 0.038)
	for vent: int in 3 + variant_tier:
		_box(Vector3(-0.091, 0.035, -0.70 - vent * 0.10), Vector3(0.018, 0.045, 0.052), p.dark)
		_box(Vector3(0.091, 0.035, -0.70 - vent * 0.10), Vector3(0.018, 0.045, 0.052), p.dark)
	if variant_tier == 0:
		_box(Vector3(-0.10, 0.0, -0.26), Vector3(0.035, 0.13, 0.28), p.rust, Vector3(0.0, 0.0, 0.08))
		_box(Vector3(0.0, -0.05, -0.79), Vector3(0.21, 0.035, 0.24), p.wood)
	elif variant_tier == 1:
		_box(Vector3(0.0, -0.10, -0.82), Vector3(0.11, 0.12, 0.28), p.dark)
	else:
		_box(Vector3(-0.13, 0.02, -0.67), Vector3(0.055, 0.08, 0.46), p.glow, Vector3(0.0, -0.10, 0.0))
		_box(Vector3(0.13, 0.02, -0.67), Vector3(0.055, 0.08, 0.46), p.glow, Vector3(0.0, 0.10, 0.0))
		_cylinder(Vector3(0.0, 0.0, -0.36), 0.055, 0.24, p.glow, Vector3(PI / 2.0, 0.0, 0.0))
	_add_rifle_optics(p, rifle_kind)
	_make_muzzle_flash(Vector3(0.0, 0.018, muzzle_z - 0.10), p)


func _add_rifle_optics(p: Dictionary, rifle_kind: int) -> void:
	var scope_length: float = float([0.58, 0.38, 0.42, 0.50][rifle_kind]) + 0.045 * variant_tier
	var scope_z := -0.38
	var optic_rail := _box(Vector3(0.0, 0.145, -0.38), Vector3(0.09, 0.035, 0.76), p.dark)
	optic_rail.name = "OpticRail"
	ads_occluders.append(optic_rail)
	for mount_z: float in [-0.20, -0.52]:
		var mount := _box(Vector3(0.0, 0.205, mount_z), Vector3(0.075, 0.12, 0.045), p.primary)
		mount.name = "ScopeMount"
		ads_occluders.append(mount)
	var scope := _cylinder(Vector3(0.0, 0.255, scope_z), 0.060 + rifle_kind * 0.003, scope_length, p.dark, Vector3(PI / 2.0, 0.0, 0.0))
	scope.name = "Scope_%s" % variant_id
	_open_cylinder(scope)
	ads_occluders.append(scope)
	var scope_ring := _cylinder(Vector3(0.0, 0.255, scope_z - scope_length * 0.51), 0.068, 0.04, p.secondary, Vector3(PI / 2.0, 0.0, 0.0))
	scope_ring.name = "ScopeFrontRing"
	_open_cylinder(scope_ring)
	ads_occluders.append(scope_ring)
	var lens_z: float = scope_z - scope_length * 0.535
	var lens := _cylinder(Vector3(0.0, 0.255, lens_z), 0.052, 0.012, p.lens, Vector3(PI / 2.0, 0.0, 0.0))
	lens.name = "ScopeLens"
	ads_occluders.append(lens)
	var reticle_vertical := _box(Vector3(0.0, 0.255, lens_z - 0.009), Vector3(0.006, 0.084, 0.006), p.glow)
	reticle_vertical.name = "ReticleVertical"
	ads_occluders.append(reticle_vertical)
	var reticle_horizontal := _box(Vector3(0.0, 0.255, lens_z - 0.010), Vector3(0.084, 0.006, 0.006), p.glow)
	reticle_horizontal.name = "ReticleHorizontal"
	ads_occluders.append(reticle_horizontal)
	var rear_sight := _box(Vector3(0.0, 0.19, -0.04), Vector3(0.10, 0.075, 0.032), p.accent)
	rear_sight.name = "RearSight"
	ads_occluders.append(rear_sight)
	var front_sight := _box(Vector3(0.0, 0.19, -0.94), Vector3(0.095, 0.082, 0.026), p.accent)
	front_sight.name = "FrontSight"
	ads_occluders.append(front_sight)
	var front_post := _box(Vector3(0.0, 0.235, -0.94), Vector3(0.018, 0.055, 0.018), p.glow)
	front_post.name = "FrontSightPost"
	ads_occluders.append(front_post)
	generated_root.set_meta("has_scope", true)
	generated_root.set_meta("has_sight", true)


func _build_wand(p: Dictionary) -> void:
	var shaft_length := 0.82 + variant_tier * 0.11
	_cylinder(Vector3(0.0, 0.0, -0.22 - shaft_length * 0.5), 0.04 + variant_tier * 0.004, shaft_length, p.wood, Vector3(PI / 2.0, 0.0, 0.0))
	_cylinder(Vector3(0.0, 0.0, 0.24), 0.065, 0.32, p.dark, Vector3(PI / 2.0, 0.0, 0.0))
	for ring_z: float in [0.10, 0.22, 0.34]:
		_cylinder(Vector3(0.0, 0.0, ring_z), 0.072, 0.035, p.accent, Vector3(PI / 2.0, 0.0, 0.0))
	var focus_z := -0.28 - shaft_length
	if variant_tier == 0:
		_cylinder(Vector3(0.0, 0.0, focus_z), 0.11, 0.23, p.glow, Vector3(PI / 2.0, 0.0, 0.0), 0.02)
		_box(Vector3(0.08, 0.0, focus_z + 0.05), Vector3(0.04, 0.04, 0.28), p.rust, Vector3(0.0, -0.35, 0.0))
	elif variant_tier == 1:
		_cylinder(Vector3(0.0, 0.0, focus_z), 0.15, 0.24, p.glow, Vector3(PI / 2.0, 0.0, 0.0), 0.055)
		for side: int in [-1, 1]:
			_box(Vector3(side * 0.12, 0.0, focus_z + 0.05), Vector3(0.045, 0.045, 0.34), p.accent, Vector3(0.0, side * 0.42, 0.0))
	else:
		_cylinder(Vector3(0.0, 0.0, focus_z), 0.12, 0.36, p.glow, Vector3(PI / 2.0, 0.0, 0.0), 0.0)
		for arm: int in 4:
			var angle := TAU * arm / 4.0
			_box(Vector3(cos(angle) * 0.13, sin(angle) * 0.13, focus_z + 0.02), Vector3(0.045, 0.045, 0.44), p.accent, Vector3(0.0, sin(angle) * 0.42, cos(angle) * 0.42))
	_make_muzzle_flash(Vector3(0.0, 0.0, focus_z - 0.22), p)


func _build_pistol(p: Dictionary, offset: Vector3, mirrored: bool) -> void:
	var side := -1.0 if mirrored else 1.0
	var slide_length := 0.38 + variant_tier * 0.055
	_box(offset + Vector3(0.0, 0.03, -0.24), Vector3(0.145, 0.12, slide_length), p.secondary).name = "PistolSlide"
	_box(offset + Vector3(0.0, -0.045, -0.18), Vector3(0.13, 0.09, 0.27), p.primary)
	_box(offset + Vector3(side * 0.025, -0.17, -0.04), Vector3(0.105, 0.27, 0.14), p.dark, Vector3(-0.24, 0.0, side * 0.03))
	_cylinder(offset + Vector3(0.0, 0.035, -0.48 - variant_tier * 0.045), 0.021, 0.25 + variant_tier * 0.08, p.dark, Vector3(PI / 2.0, 0.0, 0.0))
	_box(offset + Vector3(0.0, 0.115, -0.14), Vector3(0.07, 0.055, 0.035), p.accent).name = "RearPistolSight"
	_box(offset + Vector3(0.0, 0.115, -0.41 - variant_tier * 0.045), Vector3(0.035, 0.06, 0.025), p.glow).name = "FrontPistolSight"
	if variant_tier == 0:
		_box(offset + Vector3(side * 0.078, 0.02, -0.25), Vector3(0.025, 0.09, 0.23), p.rust)
	elif variant_tier == 1:
		_box(offset + Vector3(0.0, -0.085, -0.36), Vector3(0.08, 0.065, 0.12), p.accent)
		_box(offset + Vector3(-0.055, 0.075, -0.26), Vector3(0.018, 0.03, 0.15), p.dark)
		_box(offset + Vector3(0.055, 0.075, -0.26), Vector3(0.018, 0.03, 0.15), p.dark)
	else:
		_box(offset + Vector3(-0.09, 0.02, -0.39), Vector3(0.04, 0.10, 0.28), p.glow, Vector3(0.0, -0.13, 0.0))
		_box(offset + Vector3(0.09, 0.02, -0.39), Vector3(0.04, 0.10, 0.28), p.glow, Vector3(0.0, 0.13, 0.0))
	if flash == null or model == 9:
		_make_muzzle_flash(offset + Vector3(0.0, 0.035, -0.66 - variant_tier * 0.08), p)


func _build_akimbo(p: Dictionary) -> void:
	var separation := 0.17 + variant_tier * 0.025
	_build_pistol(p, Vector3(-separation, 0.0, 0.02), true)
	_build_pistol(p, Vector3(separation, 0.0, -0.02), false)
	_box(Vector3(0.0, -0.16, 0.04), Vector3(separation * 1.45, 0.055, 0.08), p.accent)


func _make_muzzle_flash(at: Vector3, p: Dictionary) -> void:
	flash = _cylinder(at, 0.095, 0.19, p.glow, Vector3(PI / 2.0, 0.0, 0.0), 0.0)
	flash.name = "MuzzleFlash%d" % flash_nodes.size()
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	flash_nodes.append(flash)
	var smoke := _cylinder(at + Vector3(0.0, 0.015, -0.10), 0.065, 0.16, PlaceholderParts.material(Color(0.56, 0.61, 0.66, 0.28), 0.0, false), Vector3(PI / 2.0, 0.0, 0.0), 0.0)
	smoke.name = "MuzzleSmoke%d" % smoke_nodes.size()
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.visible = false
	smoke_nodes.append(smoke)


func _box(at: Vector3, dimensions: Vector3, surface: Material, part_rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var result := PlaceholderParts.box(generated_root, at, dimensions, surface)
	result.rotation = part_rotation
	part_count += 1
	return result


func _cylinder(at: Vector3, radius: float, height: float, surface: Material, part_rotation: Vector3 = Vector3.ZERO, top: float = -1.0) -> MeshInstance3D:
	var result := PlaceholderParts.cylinder(generated_root, at, radius, height, surface, top)
	result.rotation = part_rotation
	part_count += 1
	return result


func _open_cylinder(part: MeshInstance3D) -> void:
	var cylinder := part.mesh as CylinderMesh
	if cylinder == null:
		return
	cylinder.cap_top = false
	cylinder.cap_bottom = false


func _default_variant_id() -> String:
	return ["ronin_katana", "huntsman_rifle", "vanguard_rifle", "knight_sword", "war_nodachi", "falcon_burst", "ironclad_rifle", "arcane_wand", "service_glock", "twin_glock"][clampi(model, 0, 9)]


func _process(delta: float) -> void:
	var weapon := get_parent() as WeaponBase
	if weapon == null:
		return
	_update_ads_occluders(weapon)
	var profile := weapon.get_presentation_profile()
	recoil_offset = move_toward(recoil_offset, 0.0, delta * profile.fire_recovery)
	if not flash_nodes.is_empty():
		var ammo_value: Variant = weapon.get("ammo")
		var ammo := int(ammo_value) if ammo_value != null else -1
		if previous_ammo < 0:
			previous_ammo = ammo
		elif ammo != previous_ammo:
			previous_ammo = ammo
		flash_time = maxf(0.0, flash_time - delta)
		smoke_time = maxf(0.0, smoke_time - delta)
		for index: int in flash_nodes.size():
			var muzzle := flash_nodes[index]
			muzzle.visible = index == active_flash_index and flash_time > 0.0 and weapon.equipped and GameSettings.effects_quality > 0 and GameSettings.hit_effects_intensity > 0.05
			if muzzle.visible:
				var flash_scale := profile.muzzle_flash_scale * lerpf(0.75, 1.25, flash_time / maxf(profile.muzzle_flash_duration, 0.001))
				muzzle.scale = Vector3.ONE * flash_scale
		for index: int in smoke_nodes.size():
			var smoke := smoke_nodes[index]
			smoke.visible = index == active_flash_index and smoke_time > 0.0 and weapon.equipped and GameSettings.effects_quality > 0 and GameSettings.hit_effects_intensity > 0.25
			if smoke.visible:
				var smoke_progress := 1.0 - smoke_time / 0.16
				smoke.scale = Vector3.ONE * lerpf(0.55, 1.45, smoke_progress)
		var reloading_value: Variant = weapon.get("is_reloading")
		var reloading := bool(reloading_value) if reloading_value != null else false
		rotation.x = lerpf(rotation.x, base_rotation.x + (0.28 if reloading else 0.0), minf(1.0, delta * 10.0))
		position = position.lerp(base_position + Vector3(0.0, -0.04 if reloading else 0.0, recoil_offset), minf(1.0, delta * 18.0))
	if trail != null:
		var swing_value: Variant = weapon.get("swing_remaining")
		trail.visible = weapon.equipped and swing_value != null and float(swing_value) > 0.05
		if trail.visible:
			var heavy_trail := weapon.get("swing_strength") != null and float(weapon.get("swing_strength")) > 1.0
			trail.scale = Vector3(2.0, 2.0, 1.0) if heavy_trail else Vector3.ONE


func _update_ads_occluders(weapon: WeaponBase) -> void:
	var wielder_is_first_person := false
	if is_instance_valid(weapon.wielder):
		var first_person_value: Variant = weapon.wielder.get("is_first_person")
		wielder_is_first_person = first_person_value is bool and first_person_value
	var fpp_ads := weapon.equipped and weapon.is_aiming_down_sights() and wielder_is_first_person
	for part: MeshInstance3D in ads_occluders:
		if is_instance_valid(part):
			part.visible = not fpp_ads


func get_visible_ads_occluder_count() -> int:
	var visible_count := 0
	for part: MeshInstance3D in ads_occluders:
		if is_instance_valid(part) and part.visible:
			visible_count += 1
	return visible_count


func is_scope_tunnel_open() -> bool:
	if not is_instance_valid(generated_root):
		return false
	for child: Node in generated_root.get_children():
		if not String(child.name).begins_with("Scope_") or not (child is MeshInstance3D):
			continue
		var cylinder := (child as MeshInstance3D).mesh as CylinderMesh
		return cylinder != null and not cylinder.cap_top and not cylinder.cap_bottom
	return false


func _on_weapon_fired() -> void:
	var weapon := get_parent() as WeaponBase
	if weapon == null or flash_nodes.is_empty():
		return
	var profile := weapon.get_presentation_profile()
	active_flash_index = (active_flash_index + 1) % flash_nodes.size()
	flash_time = profile.muzzle_flash_duration
	smoke_time = 0.16
	recoil_offset = profile.fire_kick_distance
