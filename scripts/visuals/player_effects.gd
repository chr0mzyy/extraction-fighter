extends Node3D

var rope: MeshInstance3D
var line_mesh := ImmediateMesh.new()
var trace_mesh := ImmediateMesh.new()
var actor: PlayerController
var flash: ColorRect
var dash_trail: MeshInstance3D
var dash_trail_remaining: float = 0.0
var trace_remaining: float = 0.0

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
			flash.color = Color(0.18, 0.95, 0.86, 0.08 * GameSettings.camera_shake_strength)
		&"damage_taken":
			flash.color = Color(0.85, 0.08, 0.04, 0.035 * GameSettings.camera_shake_strength)
		&"damage_dealt":
			if GameSettings.effects_quality > 0 and _data.has("position"):
				_show_trace(_data.position as Vector3, bool(_data.get("headshot", false)))


func _show_trace(end_position: Vector3, headshot: bool) -> void:
	trace_mesh.clear_surfaces()
	trace_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	trace_mesh.surface_set_color(Color(1.0, 0.34, 0.18) if headshot else Color(1.0, 0.78, 0.32))
	trace_mesh.surface_add_vertex(to_local(actor.weapon_mount.global_position))
	trace_mesh.surface_add_vertex(to_local(end_position))
	trace_mesh.surface_end()
	trace_remaining = 0.055


func get_active_vfx_count() -> int:
	return int(flash.color.a > 0.001) + int(dash_trail_remaining > 0.0) + int(line_mesh.get_surface_count() > 0) + int(trace_mesh.get_surface_count() > 0)
