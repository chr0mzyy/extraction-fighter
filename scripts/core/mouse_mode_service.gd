class_name MouseModeService
extends RefCounted

enum Mode { LOBBY, GAMEPLAY, PAUSE, SETTINGS }

static var current_mode: int = Mode.LOBBY


static func enter_lobby() -> void:
	current_mode = Mode.LOBBY
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func capture_gameplay(player: PlayerController = null) -> bool:
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree != null and scene_tree.paused:
		enter_pause(player)
		return false
	current_mode = Mode.GAMEPLAY
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(player):
		player.is_cursor_free = false
	return true


static func release_gameplay(player: PlayerController = null) -> void:
	enter_pause(player)


static func enter_pause(player: PlayerController = null) -> void:
	current_mode = Mode.PAUSE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(player):
		player.is_cursor_free = true


static func enter_settings(player: PlayerController = null) -> void:
	current_mode = Mode.SETTINGS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(player):
		player.is_cursor_free = true


static func is_gameplay_active() -> bool:
	return current_mode == Mode.GAMEPLAY


static func is_ui_active() -> bool:
	return current_mode in [Mode.LOBBY, Mode.PAUSE, Mode.SETTINGS]
