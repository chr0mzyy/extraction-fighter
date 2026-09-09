extends Node3D

var rope: MeshInstance3D
var line_mesh := ImmediateMesh.new()
var actor: PlayerController
var flash: ColorRect

func _ready() -> void:
	actor = get_parent() as PlayerController
	rope = MeshInstance3D.new()
	rope.mesh = line_mesh
	rope.material_override = PlaceholderParts.material(Color(0.4, 0.83, 0.91), 0, true)
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rope)
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0.5, 0.35, 0.9, 0)
	layer.add_child(flash)
	actor.feedback.connect(_feedback)

func _process(delta: float) -> void:
	flash.color.a = move_toward(flash.color.a, 0.0, delta * 0.8)
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
	if event == &"blink":
		flash.color.a = 0.13
