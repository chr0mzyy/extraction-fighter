class_name MouseModeService
extends RefCounted


static func enter_lobby() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func capture_gameplay(player: PlayerController = null) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(player):
		player.is_cursor_free = false


static func release_gameplay(player: PlayerController = null) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(player):
		player.is_cursor_free = true
