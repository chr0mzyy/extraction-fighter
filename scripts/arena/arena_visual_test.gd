extends Node

# Run normally with -- --arena-visual-test, never --headless. Rendering into a
# SubViewport verifies exact sizes independently of compositor window tiling.
var failures: Array[String] = []
var capture_directory := "user://arena_visual_validation"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_all.call_deferred()


func _capture_all() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual validation requires a graphics display")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_directory))
	for target: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		var viewport := SubViewport.new()
		viewport.size = target
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		get_tree().root.add_child(viewport)
		var lobby := load("res://scenes/lobby.tscn").instantiate() as LobbyController
		viewport.add_child(lobby)
		for screen: String in ["main", "loadout", "customization", "profile"]:
			lobby.call("_show_" + screen)
			await _capture(viewport, screen, target)
		lobby.queue_free()
		await get_tree().process_frame
		ArenaSessionRequest.configure(&"1v1")
		var game := load("res://scenes/main.tscn").instantiate() as GameManager
		viewport.add_child(game)
		game.player.set_physics_process(false)
		for actor: BotController in game.arena_bots:
			actor.set_physics_process(false)
		game.player.set_camera_mode(true, false)
		await _capture(viewport, "fpp", target)
		game.player.set_camera_mode(false, false)
		await _capture(viewport, "tpp", target)
		game._toggle_pause()
		await _capture(viewport, "pause", target)
		game._toggle_pause()
		# Finish a match through normal damage/death signals for real results.
		game.progression_save_path = "user://arena_visual_test_rewards.json"
		for round_index: int in game.arena_match.mode.rounds_to_win:
			game.arena_match.advance(ArenaMatchManager.INTRO_DURATION + 0.01)
			game.bot.current_weapon.cancel_combat()
			var info := DamageInfo.new(1000.0, game.player, &"visual_validation")
			info.weapon_family = &"katana"
			game.bot.receive_damage(info)
			game.arena_match.finish_transition_now()
		game.arena_match.finish_transition_now()
		await _capture(viewport, "results", target)
		game.arena_ui.present_results(game.arena_match.latest_result, {"save_failed": true})
		await _capture(viewport, "retry_save", target)
		viewport.queue_free()
		await get_tree().process_frame
	if failures.is_empty():
		print("ARENA_VISUAL_OK: 27 GPU captures at 1280x720, 1920x1080, 2560x1440 in " + ProjectSettings.globalize_path(capture_directory))
	else:
		for failure: String in failures:
			push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _capture(viewport: SubViewport, screen: String, target: Vector2i) -> void:
	for frame: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image.get_size() != target:
		failures.append("Wrong capture dimensions: " + screen)
	var path := "%s/%s_%dx%d.png" % [capture_directory, screen, target.x, target.y]
	if image.save_png(path) != OK:
		failures.append("Failed to save " + path)
