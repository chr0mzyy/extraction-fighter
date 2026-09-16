class_name ExtractionPoint
extends Node3D

signal extraction_completed(point: ExtractionPoint)
signal channel_changed(point: ExtractionPoint, progress: float, message: String)

enum State { AVAILABLE, CHANNELING, USED, DISABLED }

@export var extraction_id: StringName
@export var hidden_extraction: bool = false
@export var channel_duration: float = 5.0
@export var activation_radius: float = 2.4
@export var room_index: int = -1

var state: State = State.AVAILABLE
var channel_progress: float = 0.0
var beacon: MeshInstance3D


func _ready() -> void:
	_build_visual()


func can_channel(actor: Node3D) -> bool:
	return state in [State.AVAILABLE, State.CHANNELING] and is_instance_valid(actor) and global_position.distance_to(actor.global_position) <= activation_radius


func update_channel(actor: Node3D, holding: bool, delta: float, has_key: bool = false) -> void:
	if state in [State.USED, State.DISABLED]:
		return
	if not can_channel(actor) or not holding:
		cancel_channel()
		return
	if hidden_extraction and not has_key:
		cancel_channel("EXTRACTION KEY REQUIRED")
		return
	if state == State.AVAILABLE:
		AudioEvents.play(&"extraction_start", global_position)
	state = State.CHANNELING
	channel_progress = minf(channel_duration, channel_progress + delta)
	channel_changed.emit(self, channel_progress / channel_duration, "[X]  EXTRACTING  %.1fs" % (channel_duration - channel_progress))
	if channel_progress >= channel_duration:
		state = State.USED
		channel_changed.emit(self, 1.0, "EXTRACTION COMPLETE")
		extraction_completed.emit(self)
		_update_visual()


func cancel_channel(message: String = "") -> void:
	if state == State.CHANNELING:
		state = State.AVAILABLE
	channel_progress = 0.0
	if not message.is_empty():
		channel_changed.emit(self, 0.0, message)


func disable() -> void:
	state = State.DISABLED
	channel_progress = 0.0
	_update_visual()


func prompt_text(has_key: bool) -> String:
	if state == State.USED:
		return "EXTRACTION USED"
	if state == State.DISABLED:
		return "EXTRACTION OFFLINE"
	if hidden_extraction and not has_key:
		return "EXTRACTION KEY REQUIRED"
	return "[X]  HOLD TO EXTRACT"


func _build_visual() -> void:
	var base := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.65
	cylinder.bottom_radius = 1.85
	cylinder.height = 0.16
	cylinder.radial_segments = 12
	base.mesh = cylinder
	base.position.y = 0.08
	base.material_override = _material(Color(0.07, 0.35, 0.37) if not hidden_extraction else Color(0.22, 0.09, 0.28), true)
	add_child(base)
	beacon = MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = 0.05
	column.bottom_radius = 0.62
	column.height = 4.5
	column.radial_segments = 8
	beacon.mesh = column
	beacon.position.y = 2.25
	beacon.material_override = _material(Color(0.12, 0.9, 0.78, 0.32) if not hidden_extraction else Color(0.58, 0.18, 0.72, 0.16), true)
	add_child(beacon)
	_update_visual()


func _update_visual() -> void:
	if beacon != null:
		beacon.visible = state != State.DISABLED
		beacon.scale.y = 0.35 if state == State.USED else 1.0


func _material(color: Color, emission: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if emission else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if emission:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = 2.2
	return material
