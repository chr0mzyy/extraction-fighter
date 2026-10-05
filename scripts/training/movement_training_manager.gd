class_name MovementTrainingManager
extends Node3D

const COURSE_PROMPTS: Array[String] = [
	"1 / 10  RUN  •  WASD",
	"2 / 10  JUMP  •  SPACE",
	"3 / 10  HOLD SPACE  •  CHAIN BUNNY HOPS",
	"4 / 10  CROUCH UNDER THE BEAM  •  SHIFT / C",
	"5 / 10  SLIDE AT SPEED  •  SHIFT / C",
	"6 / 10  SLIDE-JUMP  •  SPACE WHILE SLIDING",
	"7 / 10  DOUBLE JUMP  •  RELEASE, THEN PRESS SPACE IN AIR",
	"8 / 10  DASH  •  Q",
	"9 / 10  AIR STEER  •  HOLD SPACE + MATCH MOUSE WITH A / D",
	"10 / 10  WALLRUN / GRAPPLE  •  Q / E",
]
const CHECKPOINT_POSITIONS: Array[Vector3] = [
	Vector3(0, 0.2, 8), Vector3(0, 0.2, -25), Vector3(0, 0.2, -60), Vector3(0, 0.2, -95),
	Vector3(0, 0.2, -130), Vector3(0, 0.2, -165), Vector3(0, 0.2, -200), Vector3(0, 2.4, -235),
	Vector3(0, 3.8, -270), Vector3(0, 3.8, -310),
]

@onready var player: PlayerController = $Player

var checkpoint_areas: Array[Area3D] = []
var current_checkpoint: int = -1
var elapsed_ms: int = 0
var course_running: bool = false
var course_finished: bool = false
var last_tick_usec: int = 0
var prompt_label: Label
var timer_label: Label
var best_label: Label
var notice_label: Label
var start_transform: Transform3D


func _ready() -> void:
	MouseModeService.capture_gameplay(player)
	_build_course()
	_build_hud()
	start_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 13.0))
	player.global_transform = start_transform
	player.spawn_transform = start_transform
	player.dungeon_durability_enabled = false
	player.configure_runtime_skills(["dash", "double_jump"])
	player.pause_requested.connect(_return_to_lobby)
	last_tick_usec = Time.get_ticks_usec()
	_update_hud()
	if "--training-self-test" in OS.get_cmdline_user_args():
		_run_self_test.call_deferred()


func _physics_process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if course_running and not course_finished:
		elapsed_ms += int((now - last_tick_usec) / 1000)
	last_tick_usec = now
	if player.global_position.y < -7.0:
		_reset_to_checkpoint()
	_update_hud()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.physical_keycode == KEY_R or key_event.keycode == KEY_R:
			_restart_course()
			get_viewport().set_input_as_handled()


func _build_course() -> void:
	var floor_material := _material(Color(0.075, 0.09, 0.105))
	var accent_material := _material(Color(0.02, 0.52, 0.66))
	var warning_material := _material(Color(0.92, 0.62, 0.07))
	_add_box("CourseFloor", Vector3(0, -0.35, -151), Vector3(9.0, 0.7, 340.0), floor_material)
	_add_box("CrouchBeam", Vector3(0, 1.55, -95), Vector3(8.0, 0.45, 1.2), warning_material)
	_add_box("SlideGateLeft", Vector3(-3.7, 1.0, -130), Vector3(0.45, 2.0, 4.0), accent_material)
	_add_box("SlideGateRight", Vector3(3.7, 1.0, -130), Vector3(0.45, 2.0, 4.0), accent_material)
	_add_box("JumpPlatformA", Vector3(0, 0.55, -198), Vector3(6.0, 1.1, 4.0), accent_material)
	_add_box("JumpPlatformB", Vector3(0, 1.25, -233), Vector3(5.0, 2.5, 4.0), accent_material)
	_add_box("AirPlatform", Vector3(0, 2.0, -270), Vector3(6.0, 4.0, 10.0), floor_material)
	_add_box("WallrunLeft", Vector3(-2.4, 3.0, -302), Vector3(0.5, 6.0, 22.0), accent_material)
	_add_box("WallrunRight", Vector3(2.4, 3.0, -302), Vector3(0.5, 6.0, 22.0), accent_material)
	for index: int in CHECKPOINT_POSITIONS.size():
		var area := Area3D.new()
		area.name = "Checkpoint%02d" % (index + 1)
		area.position = CHECKPOINT_POSITIONS[index]
		area.collision_layer = 0
		area.collision_mask = 2
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(7.5, 4.5, 1.25)
		shape_node.shape = shape
		area.add_child(shape_node)
		area.body_entered.connect(_on_checkpoint_entered.bind(index))
		add_child(area)
		checkpoint_areas.append(area)
		var marker := MeshInstance3D.new()
		var marker_mesh := BoxMesh.new()
		marker_mesh.size = Vector3(7.7, 0.08, 0.18)
		marker.mesh = marker_mesh
		marker.position = CHECKPOINT_POSITIONS[index] + Vector3(0, 0.04, 0)
		marker.material_override = warning_material if index == CHECKPOINT_POSITIONS.size() - 1 else accent_material
		add_child(marker)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 22)
	panel.custom_minimum_size = Vector2(590, 118)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.018, 0.025, 0.92)
	style.border_color = Color(0.02, 0.74, 0.90)
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	panel.add_child(root)
	prompt_label = Label.new()
	prompt_label.add_theme_font_size_override("font_size", 17)
	prompt_label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.95))
	root.add_child(prompt_label)
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.08))
	root.add_child(timer_label)
	best_label = Label.new()
	best_label.add_theme_font_size_override("font_size", 12)
	root.add_child(best_label)
	notice_label = Label.new()
	notice_label.text = "R  RESTART COURSE   •   ESC  RETURN TO LOBBY   •   TRAINING NEVER CHANGES GEAR OR DURABILITY"
	notice_label.add_theme_font_size_override("font_size", 11)
	notice_label.add_theme_color_override("font_color", Color(0.56, 0.67, 0.7))
	root.add_child(notice_label)


func _on_checkpoint_entered(body: Node3D, index: int) -> void:
	if body != player or course_finished or index > current_checkpoint + 1:
		return
	if index <= current_checkpoint:
		return
	current_checkpoint = index
	if index == 0:
		course_running = true
		last_tick_usec = Time.get_ticks_usec()
	if index == 6:
		player.configure_runtime_skills(["dash", "double_jump"])
	elif index == 8:
		player.configure_runtime_skills(["wallrun", "grapple"])
	if index == CHECKPOINT_POSITIONS.size() - 1:
		_finish_course()
	else:
		notice_label.text = "CHECKPOINT %d / %d" % [index + 1, CHECKPOINT_POSITIONS.size()]


func _finish_course() -> void:
	course_running = false
	course_finished = true
	var new_best := PlayerProfile.set_training_best_time(elapsed_ms, true)
	prompt_label.text = "COURSE COMPLETE  •  %s" % ("NEW PERSONAL BEST" if new_best else "RUN LOGGED")
	notice_label.text = "R  RUN AGAIN   •   ESC  RETURN TO LOBBY"


func _reset_to_checkpoint() -> void:
	var reset_position := start_transform.origin if current_checkpoint < 0 else CHECKPOINT_POSITIONS[current_checkpoint] + Vector3(0, 0.45, 2.0)
	player.global_position = reset_position
	player.velocity = Vector3.ZERO
	player.movement.reset()
	notice_label.text = "FALL RESET  •  CHECKPOINT RESTORED"


func _restart_course() -> void:
	current_checkpoint = -1
	elapsed_ms = 0
	course_running = false
	course_finished = false
	player.global_transform = start_transform
	player.velocity = Vector3.ZERO
	player.movement.reset()
	player.configure_runtime_skills(["dash", "double_jump"])
	notice_label.text = "COURSE RESET  •  CROSS THE FIRST CYAN LINE TO START"
	last_tick_usec = Time.get_ticks_usec()


func _update_hud() -> void:
	if not course_finished:
		var prompt_index := clampi(current_checkpoint + 1, 0, COURSE_PROMPTS.size() - 1)
		prompt_label.text = COURSE_PROMPTS[prompt_index]
	timer_label.text = "TIME  %s" % _format_time(elapsed_ms)
	best_label.text = "BEST  %s" % (_format_time(PlayerProfile.training_best_time_ms) if PlayerProfile.training_best_time_ms > 0 else "--:--.---")


func _format_time(value_ms: int) -> String:
	var minutes := value_ms / 60000
	var seconds := (value_ms / 1000) % 60
	return "%02d:%02d.%03d" % [minutes, seconds, value_ms % 1000]


func _return_to_lobby() -> void:
	MouseModeService.enter_lobby()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _add_box(node_name: String, box_position: Vector3, box_size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = box_position
	body.collision_layer = 1
	body.collision_mask = 0
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material


func _run_self_test() -> void:
	var failures: Array[String] = []
	if checkpoint_areas.size() != 10 or COURSE_PROMPTS.size() != 10:
		failures.append("Training course does not expose ten ordered mechanics/checkpoints")
	var straight_line_seconds := CHECKPOINT_POSITIONS[0].distance_to(CHECKPOINT_POSITIONS[-1]) / player.movement.run_speed
	if straight_line_seconds < 30.0 or straight_line_seconds > 90.0:
		failures.append("Training course baseline is outside the intended 30–90 second duration")
	if player.dungeon_durability_enabled:
		failures.append("Training enabled durability wear")
	if player.skill_definition_ids != ["dash", "double_jump"]:
		failures.append("Training did not apply its controlled temporary skill loadout")
	if PlayerProfile.skill_slots == player.skill_definition_ids and PlayerProfile.skill_slots != ["dash", "double_jump"]:
		failures.append("Training modified the persistent profile loadout")
	_restart_course()
	if current_checkpoint != -1 or elapsed_ms != 0 or course_running or course_finished:
		failures.append("Course restart did not reset timer and checkpoint state")
	if failures.is_empty():
		print("TRAINING_SELF_TEST_OK: 10 mechanics, checkpoints, reset, temporary loadout and progression isolation passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("TRAINING_SELF_TEST_FAILURE: " + failure)
		get_tree().quit(1)
