extends Node3D

var rope: MeshInstance3D
var line_mesh := ImmediateMesh.new()
var trace_mesh := ImmediateMesh.new()
var actor: PlayerController
var flash: ColorRect
var dash_trail: MeshInstance3D
var dash_trail_remaining: float = 0.0
var trace_remaining: float = 0.0
var impact_pool: Array[MeshInstance3D] = []
var impact_lifetimes: Array[float] = []
var impact_durations: Array[float] = []
var next_impact_index: int = 0
var impact_materials: Dictionary = {}

func _ready() -> void:
	actor = get_parent() as PlayerController
	rope = MeshInstance3D.new()
	rope.mesh = line_mesh
	rope.material_override = PlaceholderParts.material(Color(0.4, 0.83, 0.91), 0, true)
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rope)
	var trace := MeshInstance3D.new()
	trace.mesh = trace_mesh
	trace.material_override = PlaceholderParts.material(Color(1.0, 0.78, 0.32), 0, true)
	trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trace)
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0.5, 0.35, 0.9, 0)
	layer.add_child(flash)
	dash_trail = PlaceholderParts.box(self, Vector3(0, 0.7, 1.0), Vector3(0.52, 0.035, 2.4), PlaceholderParts.material(Color(0.35, 0.62, 1.0, 0.44), 0, true))
	dash_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dash_trail.visible = false
	_build_impact_pool()
	actor.feedback.connect(_feedback)

func _process(delta: float) -> void:
	flash.color.a = move_toward(flash.color.a, 0.0, delta * 0.8)
	dash_trail_remaining = maxf(0.0, dash_trail_remaining - delta)
	trace_remaining = maxf(0.0, trace_remaining - delta)
	if trace_remaining <= 0.0:
		trace_mesh.clear_surfaces()
	dash_trail.visible = dash_trail_remaining > 0.0 and GameSettings.effects_quality > 0 and not actor.is_first_person
	if dash_trail.visible:
			dash_trail.scale.z = clampf(dash_trail_remaining / 0.16, 0.15, 1.0)
	for index: int in impact_pool.size():
		impact_lifetimes[index] = maxf(0.0, impact_lifetimes[index] - delta)
		var impact := impact_pool[index]
		impact.visible = impact_lifetimes[index] > 0.0 and GameSettings.effects_quality > 0 and GameSettings.hit_effects_intensity > 0.05
		if impact.visible:
			var progress := 1.0 - impact_lifetimes[index] / maxf(impact_durations[index], 0.001)
			impact.scale = Vector3.ONE * lerpf(0.34, 1.55, progress) * lerpf(0.55, 1.0, GameSettings.hit_effects_intensity)
			impact.transparency = clampf(progress, 0.0, 1.0)
	line_mesh.clear_surfaces()
	if actor.is_dead:
		return
	for skill: SkillBase in actor.equipped_skills:
		if skill is GrappleSkill and (skill as GrappleSkill).attached:
			var start := actor.weapon_mount.global_position
			line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			line_mesh.surface_add_vertex(to_local(start))
			line_mesh.surface_add_vertex(to_local((skill as GrappleSkill).grapple_point))
			line_mesh.surface_end()

func _feedback(event: StringName, _data: Dictionary) -> void:
	match event:
		&"blink":
			flash.color = Color(0.5, 0.35, 0.9, 0.13)
		&"dash":
			dash_trail_remaining = 0.16
		&"deflect":
			flash.color = Color(0.18, 0.95, 0.86, 0.10 * GameSettings.hit_effects_intensity)
			_show_impact(actor.global_position + actor.get_aim_direction() * 1.1 + Vector3.UP, &"deflect", true)
		&"damage_taken":
			flash.color = Color(0.85, 0.08, 0.04, 0.045 * GameSettings.hit_effects_intensity)
		&"weapon_trace":
			if GameSettings.effects_quality > 0 and _data.has("position"):
				_show_trace(_data.position as Vector3, bool(_data.get("hit", false)), float(_data.get("duration", 0.055)))
		&"damage_dealt":
			if GameSettings.effects_quality > 0 and _data.has("position"):
				var impact_kind: StringName = &"kill" if bool(_data.get("killed", false)) else (&"headshot" if bool(_data.get("headshot", false)) else (&"armor" if bool(_data.get("armor_hit", false)) else (&"blocked" if bool(_data.get("blocked", false)) else &"normal")))
				_show_impact(_data.position as Vector3, impact_kind, bool(_data.get("critical", false)) or bool(_data.get("proc", false)) or bool(_data.get("heavy", false)))
		&"affix_proc", &"affix_impact":
			if _data.has("position"):
				_show_impact(_data.position as Vector3, StringName(String(_data.get("affix", "proc"))), true)
			flash.color = _affix_color(StringName(String(_data.get("affix", "proc"))), 0.028 * GameSettings.hit_effects_intensity)
		&"mythic_ready", &"mythic_proc":
			if _data.has("position"):
				_show_impact(_data.position as Vector3, &"mythic", true)
			flash.color = Color(0.68, 0.27, 1.0, 0.025 * GameSettings.hit_effects_intensity)


func _show_trace(end_position: Vector3, hit: bool, duration: float) -> void:
	trace_mesh.clear_surfaces()
	trace_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	trace_mesh.surface_set_color(Color(1.0, 0.52, 0.22) if hit else Color(1.0, 0.82, 0.44, 0.78))
	trace_mesh.surface_add_vertex(to_local(actor.weapon_mount.global_position))
	trace_mesh.surface_add_vertex(to_local(end_position))
	trace_mesh.surface_end()
	trace_remaining = duration


func _build_impact_pool() -> void:
	impact_materials = {
		&"normal": PlaceholderParts.material(Color(1.0, 0.72, 0.28, 0.76), 0.0, true),
		&"headshot": PlaceholderParts.material(Color(1.0, 0.20, 0.10, 0.86), 0.0, true),
		&"armor": PlaceholderParts.material(Color(0.30, 0.72, 1.0, 0.78), 0.0, true),
		&"blocked": PlaceholderParts.material(Color(0.42, 0.84, 1.0, 0.72), 0.0, true),
		&"kill": PlaceholderParts.material(Color(1.0, 0.34, 0.22, 0.92), 0.0, true),
		&"burning": PlaceholderParts.material(Color(1.0, 0.30, 0.05, 0.82), 0.0, true),
		&"frost": PlaceholderParts.material(Color(0.35, 0.85, 1.0, 0.80), 0.0, true),
		&"poisoned": PlaceholderParts.material(Color(0.40, 0.95, 0.24, 0.80), 0.0, true),
		&"bleeding": PlaceholderParts.material(Color(0.92, 0.08, 0.16, 0.82), 0.0, true),
		&"shock": PlaceholderParts.material(Color(1.0, 0.92, 0.22, 0.86), 0.0, true),
		&"void": PlaceholderParts.material(Color(0.55, 0.18, 1.0, 0.82), 0.0, true),
		&"echo": PlaceholderParts.material(Color(0.88, 0.48, 1.0, 0.82), 0.0, true),
		&"mythic": PlaceholderParts.material(Color(0.72, 0.30, 1.0, 0.90), 0.0, true),
		&"deflect": PlaceholderParts.material(Color(0.20, 1.0, 0.86, 0.90), 0.0, true),
	}
	for index: int in 10:
		var impact := MeshInstance3D.new()
		impact.name = "Impact%02d" % index
		var mesh := SphereMesh.new()
		mesh.radius = 0.10
		mesh.height = 0.20
		mesh.radial_segments = 6
		mesh.rings = 3
		mesh.material = impact_materials[&"normal"]
		impact.mesh = mesh
		impact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		impact.set_as_top_level(true)
		impact.visible = false
		add_child(impact)
		impact_pool.append(impact)
		impact_lifetimes.append(0.0)
		impact_durations.append(0.0)


func _show_impact(position: Vector3, kind: StringName, strong: bool) -> void:
	if impact_pool.is_empty() or GameSettings.hit_effects_intensity <= 0.05:
		return
	var index := next_impact_index
	next_impact_index = (next_impact_index + 1) % impact_pool.size()
	var impact := impact_pool[index]
	impact.global_position = position
	var mesh := impact.mesh as SphereMesh
	mesh.material = impact_materials.get(kind, impact_materials.get(&"mythic" if strong else &"normal"))
	impact_durations[index] = (0.24 if strong else 0.15) * lerpf(0.70, 1.0, GameSettings.hit_effects_intensity)
	impact_lifetimes[index] = impact_durations[index]
	impact.transparency = 0.0
	impact.visible = true
	AudioEvents.play(&"impact", position)


func _affix_color(affix: StringName, alpha: float) -> Color:
	match affix:
		&"burning": return Color(1.0, 0.18, 0.03, alpha)
		&"frost": return Color(0.25, 0.78, 1.0, alpha)
		&"shock": return Color(1.0, 0.88, 0.12, alpha)
		&"poisoned": return Color(0.35, 0.90, 0.18, alpha)
		&"bleeding": return Color(0.90, 0.04, 0.12, alpha)
		&"void": return Color(0.50, 0.14, 1.0, alpha)
		_: return Color(0.72, 0.28, 1.0, alpha)


func get_active_vfx_count() -> int:
	var active_impacts := 0
	for lifetime: float in impact_lifetimes:
		active_impacts += int(lifetime > 0.0)
	return int(flash.color.a > 0.001) + int(dash_trail_remaining > 0.0) + int(line_mesh.get_surface_count() > 0) + int(trace_mesh.get_surface_count() > 0) + active_impacts
