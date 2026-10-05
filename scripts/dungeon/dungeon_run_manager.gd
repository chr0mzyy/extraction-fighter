class_name DungeonRunManager
extends Node3D

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const BOT_SCENE := preload("res://scenes/characters/bot.tscn")
const RUN_DURATION := 900.0
const KEY_SPAWN_CHANCE := 0.42

@export_group("Spawn Safety")
@export_range(8.0, 30.0, 0.5) var enemy_spawn_min_player_distance: float = 15.0
@export_range(12.0, 35.0, 0.5) var elite_spawn_min_player_distance: float = 20.0
@export_range(0.25, 3.0, 0.05) var enemy_spawn_activation_delay: float = 1.0
@export_range(0.5, 4.0, 0.05) var player_start_protection_duration: float = 1.75

@onready var generator: ArmoryGenerator = $ArmoryGenerator
@onready var run_inventory: RunInventory = $RunInventory
@onready var player: PlayerController = $Player
@onready var hud: DungeonHUD = $DungeonHUD

var run_seed: int = 0
var time_remaining: float = RUN_DURATION
var normal_extractions: Array[ExtractionPoint] = []
var hidden_extractions: Array[ExtractionPoint] = []
var chests: Array[LootChest] = []
var enemies: Array[BotController] = []
var key_spawned: bool = false
var run_finished: bool = false
var current_extraction: ExtractionPoint
var extraction_requires_release: bool = false
var notice_text: String = ""
var notice_remaining: float = 0.0
var loot_serial: int = 0
var spawn_records: Array[Dictionary] = []
var pause_layer: CanvasLayer
var pause_menu: VBoxContainer
var pause_settings: VBoxContainer
var inventory_menu: DungeonInventoryMenu
var dropped_pickups: Array[RunItemPickup] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MouseModeService.capture_gameplay(player)
	AudioManager.play_music(&"dungeon")
	run_seed = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	_setup_run(run_seed)
	_build_pause_menu()
	inventory_menu = DungeonInventoryMenu.new()
	inventory_menu.name = "DungeonInventoryMenu"
	add_child(inventory_menu)
	inventory_menu.bind(run_inventory, player, _drop_run_item)
	var args := OS.get_cmdline_user_args()
	if "--dungeon-self-test" in args:
		_run_dungeon_self_test.call_deferred()
	elif "--extraction-flow-test" in args:
		_run_extraction_flow_test.call_deferred()
	elif "--durability-self-test" in args:
		_run_durability_self_test.call_deferred()
	elif "--dungeon-soak-test" in args:
		_run_dungeon_soak_test.call_deferred()
	elif "--capture-dungeon-inventory" in args:
		_capture_dungeon_inventory.call_deferred()
	elif "--dungeon-scene-flow-test" in args:
		_run_dungeon_scene_flow_test.call_deferred()


func _physics_process(delta: float) -> void:
	if run_finished:
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	if time_remaining <= 0.0:
		_fail_run("TIME EXPIRED", true)
		return
	notice_remaining = maxf(0.0, notice_remaining - delta)
	var prompt := "INVENTORY OPEN  //  TAB TO CLOSE" if inventory_menu != null and inventory_menu.visible else _update_interactions(delta)
	if notice_remaining > 0.0:
		prompt = notice_text
	hud.update_run(time_remaining, run_inventory, player, prompt, _debug_data())


func _unhandled_input(event: InputEvent) -> void:
	if inventory_menu != null and inventory_menu.visible:
		if event.is_action_pressed("inventory_toggle") or event.is_action_pressed("menu_toggle"):
			inventory_menu.close()
			get_viewport().set_input_as_handled()
		return
	if not get_tree().paused and event.is_action_pressed("inventory_toggle"):
		inventory_menu.open()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused and event.is_action_pressed("menu_toggle"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _setup_run(seed_value: int) -> void:
	run_inventory.clear()
	var layout := generator.generate(seed_value)
	normal_extractions.assign(layout.normal_extractions)
	hidden_extractions.assign(layout.hidden_extractions)
	chests.assign(layout.chests)
	player.global_position = layout.spawn_position
	player.spawn_transform = player.global_transform
	player.dungeon_durability_enabled = true
	player.grant_damage_immunity(player_start_protection_duration)
	hud.bind(player)
	player.actor_died.connect(_on_player_died)
	player.pause_requested.connect(_toggle_pause)
	player.health.damage_resolved.connect(_on_player_damage_resolved)
	for point: ExtractionPoint in normal_extractions + hidden_extractions:
		point.extraction_completed.connect(_on_extraction_completed)
		point.channel_changed.connect(_on_channel_changed)
	_configure_chests()
	_spawn_enemies(layout.enemy_markers, layout.boss_marker)
	hud.update_run(time_remaining, run_inventory, player, "SEARCH THE ARMORY", _debug_data())


func _configure_chests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed ^ 0x2C71
	key_spawned = rng.randf() < KEY_SPAWN_CHANCE
	var key_chest := rng.randi_range(0, chests.size() - 1) if key_spawned and not chests.is_empty() else -1
	for index: int in chests.size():
		var room_index := int(chests[index].get_meta("room_index", 0))
		var room_type := ArmoryGenerator.ROOM_TYPES[clampi(room_index, 0, ArmoryGenerator.ROOM_TYPES.size() - 1)]
		var source_type := LootTableService.source_for_chest(room_type, index)
		var loot: Array[ItemInstance] = []
		loot.append(_roll_loot_instance(rng, source_type, room_type))
		if source_type in ["reinforced", "elite", "vault"] or rng.randf() < 0.38:
			loot.append(_roll_loot_instance(rng, source_type, room_type))
		if source_type == "vault":
			loot.append(_roll_loot_instance(rng, source_type, room_type))
		if index == key_chest:
			loot.append(ItemInstance.create(PlayerProfile.get_definition("extraction_key"), _next_instance_id("key")))
		chests[index].configure(loot, rng.randi_range(18, 65), false, source_type)
		chests[index].opened.connect(_on_chest_opened)


func _roll_loot_instance(rng: RandomNumberGenerator, source_type: String = "ordinary", room_type: String = "") -> ItemInstance:
	return LootTableService.roll_instance(rng, source_type, room_type, 0, 0, _next_instance_id(source_type))


func _next_instance_id(kind: String) -> String:
	loot_serial += 1
	return "run:%d:%s:%d" % [run_seed, kind, loot_serial]


func _spawn_enemies(markers: Array, boss_spawn: Marker3D) -> void:
	spawn_records.clear()
	var normal_candidates: Array[Marker3D] = []
	var elite_candidates: Array[Marker3D] = []
	for marker_value: Variant in markers:
		var marker := marker_value as Marker3D
		if marker == null or int(marker.get_meta("room_index", -1)) == 0:
			continue
		if String(marker.get_meta("enemy_role", "normal")) == "elite":
			elite_candidates.append(marker)
		elif _is_spawn_marker_valid(marker, enemy_spawn_min_player_distance):
			normal_candidates.append(marker)
	normal_candidates.sort_custom(func(a: Marker3D, b: Marker3D) -> bool: return _spawn_marker_score(a) > _spawn_marker_score(b))
	for index: int in mini(5, normal_candidates.size()):
		_spawn_marker_enemy(normal_candidates[index], false)
	elite_candidates.sort_custom(func(a: Marker3D, b: Marker3D) -> bool: return _spawn_marker_score(a) > _spawn_marker_score(b))
	for marker: Marker3D in elite_candidates:
		if _is_spawn_marker_valid(marker, elite_spawn_min_player_distance):
			_spawn_marker_enemy(marker, true)
			break
	# The Warden always uses its dedicated, geometry-safe boss room marker.
	var warden := BOT_SCENE.instantiate() as BotController
	warden.position = boss_spawn.position
	warden.name = "Warden"
	warden.scale = Vector3.ONE * 1.18
	add_child(warden)
	warden.health.max_health = 280.0
	warden.health.reset()
	warden.aggression = 0.82
	warden.accuracy = 0.68
	warden.actor_died.connect(_on_enemy_died)
	warden.feedback.connect(_on_enemy_feedback.bind(warden))
	enemies.append(warden)
	_prepare_enemy_wake(warden)
	spawn_records.append(_make_spawn_record(boss_spawn, "boss"))


func _spawn_marker_enemy(marker: Marker3D, elite: bool) -> void:
	var enemy := BOT_SCENE.instantiate() as BotController
	enemy.position = marker.position
	enemy.name = "ArmoryElite" if elite else "ArmoryGuard%02d" % (enemies.size() + 1)
	add_child(enemy)
	if elite:
		enemy.health.max_health = 155.0
		enemy.health.reset()
		enemy.aggression = 0.74
	enemy.actor_died.connect(_on_enemy_died)
	enemy.feedback.connect(_on_enemy_feedback.bind(enemy))
	enemies.append(enemy)
	_prepare_enemy_wake(enemy)
	spawn_records.append(_make_spawn_record(marker, "elite" if elite else "normal"))


func _prepare_enemy_wake(enemy: BotController) -> void:
	enemy.set_target(null)
	enemy.set_physics_process(false)
	enemy.set_meta("spawn_activation_remaining", enemy_spawn_activation_delay)
	_activate_enemy_after_delay(enemy)


func _activate_enemy_after_delay(enemy: BotController) -> void:
	await get_tree().create_timer(enemy_spawn_activation_delay).timeout
	if run_finished or not is_instance_valid(enemy) or enemy.is_dead:
		return
	enemy.set_meta("spawn_activation_remaining", 0.0)
	enemy.set_target(player)
	enemy.set_physics_process(true)


func _is_spawn_marker_valid(marker: Marker3D, minimum_distance: float) -> bool:
	if marker.global_position.distance_to(player.global_position) < minimum_distance:
		return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.46
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, marker.global_position + Vector3.UP * 0.92)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 0.02
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _spawn_marker_score(marker: Marker3D) -> float:
	var distance_score := marker.global_position.distance_to(player.global_position)
	return distance_score + (1000.0 if not _spawn_has_direct_player_los(marker.global_position) else 0.0)


func _spawn_has_direct_player_los(spawn_position: Vector3) -> bool:
	var origin := player.global_position + Vector3.UP * 1.25
	var destination := spawn_position + Vector3.UP * 1.25
	var query := PhysicsRayQueryParameters3D.create(origin, destination, 1, [player.get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _make_spawn_record(marker: Marker3D, role: String) -> Dictionary:
	return {
		"role": role,
		"room_index": int(marker.get_meta("room_index", 11 if role == "boss" else -1)),
		"position": marker.global_position,
		"distance": marker.global_position.distance_to(player.global_position),
		"direct_los": _spawn_has_direct_player_los(marker.global_position),
	}


func _update_interactions(delta: float) -> String:
	if extraction_requires_release and not Input.is_action_pressed("interact"):
		extraction_requires_release = false
	var closest_pickup: RunItemPickup
	var pickup_distance := 2.4
	for pickup: RunItemPickup in dropped_pickups:
		if not is_instance_valid(pickup) or pickup.item_instance == null:
			continue
		var distance := player.global_position.distance_to(pickup.global_position)
		if distance < pickup_distance:
			pickup_distance = distance
			closest_pickup = pickup
	if closest_pickup != null:
		if Input.is_action_just_pressed("interact"):
			var exact_instance := closest_pickup.item_instance
			if run_inventory.add_item(exact_instance):
				closest_pickup.take_item()
				dropped_pickups.erase(closest_pickup)
				AudioEvents.play(&"pickup", player.global_position)
				return "ITEM RECOVERED"
			return "INVENTORY FULL"
		return closest_pickup.get_prompt()
	var closest_chest: LootChest
	var chest_distance := 2.5
	for chest: LootChest in chests:
		if chest.opened_once:
			continue
		var distance := player.global_position.distance_to(chest.global_position)
		if distance < chest_distance:
			chest_distance = distance
			closest_chest = chest
	if closest_chest != null and Input.is_action_just_pressed("interact"):
		closest_chest.interact()
		return "CHEST OPENED"
	var closest_point: ExtractionPoint
	var closest_distance := INF
	for point: ExtractionPoint in normal_extractions + hidden_extractions:
		if point.state in [ExtractionPoint.State.USED, ExtractionPoint.State.DISABLED]:
			continue
		var distance := player.global_position.distance_to(point.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_point = point
	for point: ExtractionPoint in normal_extractions + hidden_extractions:
		if point != closest_point:
			point.cancel_channel()
	if closest_point != null and closest_distance <= closest_point.activation_radius:
		current_extraction = closest_point
		closest_point.update_channel(player, Input.is_action_pressed("interact") and not extraction_requires_release, delta, run_inventory.has_definition(&"extraction_key"))
		if closest_chest != null:
			return closest_chest.get_prompt()
		return closest_point.prompt_text(run_inventory.has_definition(&"extraction_key"))
	current_extraction = null
	if closest_chest != null:
		return closest_chest.get_prompt()
	var closest_normal := INF
	for point: ExtractionPoint in normal_extractions:
		if point.state == ExtractionPoint.State.AVAILABLE:
			closest_normal = minf(closest_normal, player.global_position.distance_to(point.global_position))
	return "EXTRACTION  %.0fm" % closest_normal if closest_normal < INF else "NO EXTRACTION AVAILABLE"


func _on_chest_opened(_chest: LootChest, items: Array[ItemInstance], gold_reward: int) -> void:
	AudioEvents.play(&"chest", _chest.global_position)
	var added := 0
	var unclaimed: Array[ItemInstance] = []
	for instance: ItemInstance in items:
		if run_inventory.add_item(instance):
			added += 1
		else:
			unclaimed.append(instance)
	_chest.retain_unclaimed_items(unclaimed)
	run_inventory.add_gold(gold_reward)
	if not unclaimed.is_empty():
		_show_notice("RUN PACK FULL  •  %d ITEM%s REMAIN IN CHEST" % [unclaimed.size(), "" if unclaimed.size() == 1 else "S"], 2.2)
	else:
		_show_notice("LOOTED %d ITEM%s  +%d GOLD" % [added, "" if added == 1 else "S", gold_reward])
	if not items.is_empty():
		var found_key := false
		var best := items[0]
		var best_definition := PlayerProfile.get_definition(String(best.definition_id))
		for instance: ItemInstance in items:
			var definition := PlayerProfile.get_definition(String(instance.definition_id))
			if definition != null and best_definition != null and definition.rarity > best_definition.rarity:
				best = instance
				best_definition = definition
			if String(instance.definition_id) == "extraction_key":
				found_key = true
		if best_definition != null:
			_show_notice("+ %s  •  %s  •  +%d GOLD" % [best_definition.display_name.to_upper(), best_definition.get_rarity_name().to_upper(), gold_reward], 2.0)
		AudioEvents.play(&"pickup", player.global_position, {"count": added})
		if found_key:
			AudioEvents.play(&"key_pickup", player.global_position)
		elif best_definition != null and best_definition.rarity == ItemDefinition.Rarity.MYTHIC:
			AudioEvents.play(&"mythic_acquired")


func _drop_run_item(slot: int) -> void:
	var instance := run_inventory.remove_at(slot)
	if instance == null:
		_show_notice("EMPTY SLOT")
		return
	var definition := PlayerProfile.get_definition(String(instance.definition_id))
	var pickup := RunItemPickup.new()
	pickup.name = "Dropped_%s" % instance.instance_id.replace(":", "_")
	pickup.configure(instance, definition)
	add_child(pickup)
	var forward := -player.global_basis.z
	pickup.global_position = player.global_position + forward * 1.35 + Vector3.UP * 0.18
	pickup.base_height = pickup.position.y
	dropped_pickups.append(pickup)
	AudioEvents.play(&"item_drop", pickup.global_position)
	_show_notice("DROPPED  %s" % definition.display_name.to_upper())


func _on_extraction_completed(point: ExtractionPoint) -> void:
	if run_finished:
		return
	if point.hidden_extraction and not run_inventory.consume_definition(&"extraction_key"):
		point.state = ExtractionPoint.State.AVAILABLE
		point.cancel_channel("EXTRACTION KEY REQUIRED")
		return
	_succeed_run(true, true, point.hidden_extraction)


func _succeed_run(return_to_lobby: bool = true, persist_profile: bool = true, hidden_bonus: bool = false) -> void:
	if run_finished:
		return
	run_finished = true
	AudioEvents.play(&"extraction_success", player.global_position)
	_disable_extractions()
	var gold_reward := run_inventory.run_gold
	var items := run_inventory.take_all_items()
	if hidden_bonus:
		var cache_rng := RandomNumberGenerator.new()
		cache_rng.seed = run_seed ^ 0x51EC0
		items.append(_roll_loot_instance(cache_rng, "secure_vault", "vault"))
		gold_reward += 75
	var overflow_count := 0
	for instance: ItemInstance in items:
		if PlayerProfile.secure_extracted_instance(instance, false) == "overflow":
			overflow_count += 1
	PlayerProfile.add_gold(gold_reward)
	if persist_profile:
		PlayerProfile.save_profile()
	var summary := "%d items secured\n%d gold banked" % [items.size(), gold_reward]
	if overflow_count > 0:
		summary += "\n%d sent safely to Extraction Overflow" % overflow_count
	if hidden_bonus:
		summary += "\nSECURE CACHE BONUS CLAIMED"
	hud.show_summary("EXTRACTION SUCCESSFUL", summary)
	if return_to_lobby:
		_return_to_lobby_after_delay()


func _fail_run(reason: String, death_penalty: bool, return_to_lobby: bool = true, persist_profile: bool = true) -> void:
	if run_finished:
		return
	run_finished = true
	AudioEvents.play(&"extraction_failure", player.global_position, {"reason": reason})
	_disable_extractions()
	var lost_count := run_inventory.item_count()
	run_inventory.clear()
	var durability_lost := DurabilityService.apply_death_penalty(PlayerProfile) if death_penalty else 0.0
	if persist_profile:
		PlayerProfile.save_profile()
	hud.show_summary("RUN FAILED", "%s\n%d items lost\n%.1f durability lost" % [reason, lost_count, durability_lost])
	if return_to_lobby:
		_return_to_lobby_after_delay()


func _disable_extractions() -> void:
	for point: ExtractionPoint in normal_extractions + hidden_extractions:
		if point.state != ExtractionPoint.State.USED:
			point.disable()


func _return_to_lobby_after_delay() -> void:
	await get_tree().create_timer(2.5).timeout
	get_tree().paused = false
	MouseModeService.enter_lobby()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _build_pause_menu() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 90
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.022, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-205, -225)
	panel.size = Vector2(410, 450)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.048, 0.98)
	style.border_color = Color(0.27, 0.67, 0.62)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	pause_layer.add_child(panel)
	pause_menu = VBoxContainer.new()
	pause_menu.add_theme_constant_override("separation", 12)
	panel.add_child(pause_menu)
	var title := Label.new()
	title.text = "ARMORY RUN PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	pause_menu.add_child(title)
	var warning := Label.new()
	warning.text = "Returning to Lobby abandons carried run loot"
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.add_theme_color_override("font_color", Color(0.88, 0.57, 0.3))
	pause_menu.add_child(warning)
	_add_pause_button(pause_menu, "RESUME", _toggle_pause)
	_add_pause_button(pause_menu, "SETTINGS", _show_pause_settings)
	_add_pause_button(pause_menu, "RETURN TO LOBBY  /  ABANDON", _abandon_run)
	pause_settings = VBoxContainer.new()
	pause_settings.add_theme_constant_override("separation", 8)
	panel.add_child(pause_settings)
	var settings_title := Label.new()
	settings_title.text = "GAMEPLAY SETTINGS"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", 21)
	pause_settings.add_child(settings_title)
	_add_pause_setting_slider("FOV", GameSettings.base_fov, 70.0, 110.0, 1.0, &"base_fov")
	_add_pause_setting_slider("CAMERA SHAKE", GameSettings.camera_shake_strength, 0.0, 1.0, 0.05, &"camera_shake_strength")
	_add_pause_setting_slider("HEADBOB", GameSettings.headbob_strength, 0.0, 1.0, 0.05, &"headbob_strength")
	_add_pause_setting_slider("TPP SMOOTHING", GameSettings.tpp_camera_smoothing, 6.0, 30.0, 1.0, &"tpp_camera_smoothing")
	var numbers := CheckButton.new()
	numbers.text = "DAMAGE NUMBERS"
	numbers.button_pressed = GameSettings.damage_numbers
	numbers.toggled.connect(func(value: bool) -> void: GameSettings.set_value(&"damage_numbers", value))
	pause_settings.add_child(numbers)
	_add_pause_button(pause_settings, "BACK", _hide_pause_settings)
	pause_settings.visible = false
	pause_layer.visible = false


func _add_pause_button(parent: Control, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 48
	button.mouse_entered.connect(func() -> void: AudioEvents.play(&"ui_hover"))
	button.pressed.connect(func() -> void: AudioEvents.play(&"ui_click"))
	button.pressed.connect(callback)
	parent.add_child(button)


func _add_pause_setting_slider(caption: String, value: float, minimum: float, maximum: float, step: float, key: StringName) -> void:
	var label := Label.new()
	label.text = "%s  %.2f" % [caption, value]
	pause_settings.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.value_changed.connect(func(new_value: float) -> void:
		label.text = "%s  %.2f" % [caption, new_value]
		GameSettings.set_value(key, new_value)
	)
	pause_settings.add_child(slider)


func _toggle_pause() -> void:
	if run_finished:
		return
	if inventory_menu != null and inventory_menu.visible:
		inventory_menu.close()
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_layer.visible = paused
	if paused:
		_hide_pause_settings()
	else:
		MouseModeService.capture_gameplay(player)


func _show_pause_settings() -> void:
	pause_menu.visible = false
	pause_settings.visible = true
	MouseModeService.enter_settings(player)


func _hide_pause_settings() -> void:
	pause_settings.visible = false
	pause_menu.visible = true
	if get_tree().paused:
		MouseModeService.enter_pause(player)


func _abandon_run() -> void:
	get_tree().paused = false
	pause_layer.visible = false
	_fail_run("RUN ABANDONED", false)


func _on_player_died(_actor: Node, _info: DamageInfo) -> void:
	_fail_run("YOU DIED", true)


func _on_return_requested() -> void:
	_toggle_pause()


func _on_player_damage_resolved(_info: DamageInfo, applied: float, _response: Dictionary) -> void:
	if applied > 0.0 and current_extraction != null:
		current_extraction.cancel_channel("EXTRACTION INTERRUPTED")
		current_extraction = null
		extraction_requires_release = true


func _on_enemy_died(actor: Node, _info: DamageInfo) -> void:
	if actor.name != "Warden":
		return
	AudioManager.play_music(&"dungeon")
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed ^ 0x7B055
	var boss_loot: Array[ItemInstance] = []
	for count: int in 3:
		boss_loot.append(_roll_loot_instance(rng, "boss", "boss"))
	var boss_chest := LootChest.new()
	boss_chest.name = "WardenChest"
	boss_chest.position = actor.position
	boss_chest.configure(boss_loot, 280, true, "boss")
	add_child(boss_chest)
	boss_chest.opened.connect(_on_chest_opened)
	chests.append(boss_chest)
	_show_notice("WARDEN DEFEATED  -  CHEST DROPPED  -  EXTRACT WHEN READY")


func _on_enemy_feedback(event_name: StringName, data: Dictionary, enemy: BotController) -> void:
	if event_name == &"boss_phase":
		AudioManager.play_music(&"boss")
		AudioEvents.play(&"boss_phase", enemy.global_position, data)
		_show_notice("WARDEN PHASE %d  -  RECOVERY WINDOW" % int(data.get("phase", 1)), 1.2)
	elif event_name == &"heavy_telegraph" and is_instance_valid(enemy) and player.global_position.distance_to(enemy.global_position) <= 9.0:
		_show_notice("WARDEN HEAVY  -  DODGE / DEFLECT" if enemy.name == "Warden" else "HEAVY ATTACK", 0.45)


func _on_channel_changed(_point: ExtractionPoint, _progress: float, message: String) -> void:
	if not message.is_empty():
		_show_notice(message, 0.15)


func _show_notice(message: String, duration: float = 1.8) -> void:
	notice_text = message
	notice_remaining = maxf(notice_remaining, duration)
	hud.show_notice(message)


func _debug_data() -> Dictionary:
	var alive := 0
	var waking := 0
	for enemy: BotController in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			alive += 1
			if not enemy.is_physics_processing():
				waking += 1
	return {"seed": run_seed, "normal": normal_extractions.size(), "hidden": hidden_extractions.size(), "key_spawned": key_spawned, "enemies": alive, "waking": waking, "protection": player.damage_immunity_remaining}


func _run_dungeon_self_test() -> void:
	var failures: Array[String] = []
	if normal_extractions.size() != 6 or hidden_extractions.size() != 2:
		failures.append("Generated run did not contain exactly 6 normal and 2 hidden extracts")
	var saw_key := false
	var saw_no_key := false
	var first_spawn_plan: Array[Dictionary] = []
	var spawn_plan_changed := false
	for seed_value: int in range(101, 141):
		var plan := ArmoryGenerator.build_extraction_plan(seed_value)
		if plan.normal_rooms.size() != 6 or plan.hidden_rooms.size() != 2:
			failures.append("Extraction plan count failed at seed %d" % seed_value)
		var used: Dictionary = {}
		for room: int in plan.normal_rooms + plan.hidden_rooms:
			if room in [0, 11] or used.has(room):
				failures.append("Extraction plan used spawn/boss or duplicate room at seed %d" % seed_value)
			used[room] = true
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value ^ 0x2C71
		if rng.randf() < KEY_SPAWN_CHANCE: saw_key = true
		else: saw_no_key = true
		var spawn_plan := ArmoryGenerator.build_enemy_spawn_plan(seed_value)
		if spawn_plan.size() != 10:
			failures.append("Enemy marker plan count failed at seed %d" % seed_value)
		for marker_data: Dictionary in spawn_plan:
			if int(marker_data.room_index) in [0, 11]:
				failures.append("Enemy marker entered a protected start/boss room at seed %d" % seed_value)
		if first_spawn_plan.is_empty():
			first_spawn_plan = spawn_plan
		elif spawn_plan != first_spawn_plan:
			spawn_plan_changed = true
	if not saw_key or not saw_no_key:
		failures.append("Key roll did not demonstrate 0-or-1 run outcomes")
	if not spawn_plan_changed:
		failures.append("Enemy marker placement did not vary across dungeon seeds")
	if time_remaining > RUN_DURATION or chests.size() < 8 or enemies.size() < 2:
		failures.append("Dungeon foundation was incomplete")
	var normal_spawn_count := 0
	var elite_spawn_count := 0
	for record: Dictionary in spawn_records:
		match String(record.role):
			"normal":
				normal_spawn_count += 1
				if float(record.distance) < enemy_spawn_min_player_distance or int(record.room_index) == 0:
					failures.append("Normal enemy violated safe spawn distance/room")
			"elite":
				elite_spawn_count += 1
				if float(record.distance) < elite_spawn_min_player_distance:
					failures.append("Elite violated safe spawn distance")
			"boss":
				if int(record.room_index) != 11:
					failures.append("Warden did not use the dedicated boss-room marker")
	if normal_spawn_count == 0 or elite_spawn_count != 1:
		failures.append("Safe spawn selection did not create normal enemies and one elite")
	for enemy: BotController in enemies:
		if enemy.is_physics_processing():
			failures.append("Enemy activated before the configured wake delay")
	var protected_health := player.health.current_health
	var protection_result := player.receive_damage(DamageInfo.new(25.0, enemies[0], &"spawn_test", false, false))
	if float(protection_result.get("applied", -1.0)) != 0.0 or player.health.current_health != protected_health:
		failures.append("Dungeon start protection did not negate incoming damage")
	var warden: BotController
	for enemy: BotController in enemies:
		if enemy.name == "Warden": warden = enemy
	var chest_count_before := chests.size()
	_on_enemy_died(warden, null)
	if run_finished or chests.size() != chest_count_before + 1 or not chests[-1].is_boss_chest:
		failures.append("Warden death did not drop exactly one boss chest while keeping the run active")
	var channel_test := ExtractionPoint.new()
	channel_test.channel_duration = 5.0
	channel_test.position = player.position
	add_child(channel_test)
	channel_test.update_channel(player, true, 4.9)
	if channel_test.state != ExtractionPoint.State.CHANNELING:
		failures.append("Normal extraction did not sustain a 5 second channel")
	player.position += Vector3(4, 0, 0)
	channel_test.update_channel(player, true, 0.2)
	if channel_test.state != ExtractionPoint.State.AVAILABLE or channel_test.channel_progress > 0.0:
		failures.append("Leaving extraction range did not cancel the channel")
	player.position = channel_test.position
	channel_test.update_channel(player, true, 5.0)
	if channel_test.state != ExtractionPoint.State.USED:
		failures.append("Completed extraction did not become single-use")
	channel_test.queue_free()
	var dropped_instance := ItemInstance.create(PlayerProfile.get_definition("armory_scrap"), "test:drop:exact")
	run_inventory.add_item(dropped_instance)
	var dropped_slot := run_inventory.find_instance(dropped_instance.instance_id)
	_drop_run_item(dropped_slot)
	var pickup := dropped_pickups[-1] if not dropped_pickups.is_empty() else null
	if pickup == null or pickup.item_instance != dropped_instance or run_inventory.find_instance(dropped_instance.instance_id) >= 0:
		failures.append("Dungeon drop did not preserve the exact ItemInstance in the world pickup")
	elif not run_inventory.add_item(pickup.item_instance):
		failures.append("Dropped item could not be recovered")
	else:
		var recovered := pickup.take_item()
		dropped_pickups.erase(pickup)
		if recovered != dropped_instance or run_inventory.get_item(run_inventory.find_instance(dropped_instance.instance_id)) != dropped_instance:
			failures.append("Recovered world pickup changed ItemInstance identity")
		run_inventory.remove_at(run_inventory.find_instance(dropped_instance.instance_id))
	inventory_menu.open()
	await get_tree().process_frame
	if not inventory_menu.visible or inventory_menu.grid.get_child_count() != RunInventory.SLOT_COUNT or not player.is_cursor_free:
		failures.append("TAB inventory did not expose 24 slots and release camera input")
	inventory_menu.close()
	if player.is_cursor_free:
		failures.append("Closing dungeon inventory did not restore gameplay mouse ownership")
	_finish_test(failures, "DUNGEON_SELF_TEST_OK: layouts, extraction, enemies, timer, TAB inventory and exact world item drop/recovery passed")


func _run_extraction_flow_test() -> void:
	var failures: Array[String] = []
	var snapshot := PlayerProfile.to_save_data()
	var item := ItemInstance.create(PlayerProfile.get_definition("armory_scrap"), "test:secured:exact")
	run_inventory.add_item(item)
	run_inventory.add_gold(73)
	var gold_before := PlayerProfile.gold
	_succeed_run(false, false)
	if PlayerProfile.get_instance("test:secured:exact") != item or PlayerProfile.gold != gold_before + 73 or run_inventory.item_count() != 0:
		failures.append("Successful extraction did not commit exact instances and gold")
	var extracted_save := PlayerProfile.to_save_data()
	if not PlayerProfile.apply_save_data(extracted_save, false) or PlayerProfile.get_instance("test:secured:exact") == null:
		failures.append("Extracted instance did not survive save serialization")
	PlayerProfile.apply_save_data(snapshot, false)
	run_finished = false
	for point: ExtractionPoint in hidden_extractions: point.state = ExtractionPoint.State.AVAILABLE
	var hidden := hidden_extractions[0]
	if run_inventory.has_definition(&"extraction_key"):
		failures.append("Test began with a run key unexpectedly")
	if not hidden.hidden_extraction or hidden.prompt_text(false) != "EXTRACTION KEY REQUIRED":
		failures.append("Hidden extraction did not reject a keyless player")
	run_inventory.add_item(ItemInstance.create(PlayerProfile.get_definition("extraction_key"), "test:key"))
	if not run_inventory.consume_definition(&"extraction_key") or run_inventory.has_definition(&"extraction_key"):
		failures.append("Hidden extraction key was not consumed exactly once")
	_finish_test(failures, "EXTRACTION_FLOW_OK: exact loot commit, gold, hidden rejection and key consumption passed")


func _run_durability_self_test() -> void:
	var failures: Array[String] = []
	var snapshot := PlayerProfile.to_save_data()
	var weapon := PlayerProfile.get_weapon_instance(0)
	weapon.current_durability = weapon.max_durability
	var before := weapon.current_durability
	player.dungeon_durability_enabled = false
	player.weapons[0].spend_shot_durability()
	if not is_equal_approx(weapon.current_durability, before):
		failures.append("Arena durability gate allowed wear")
	player.dungeon_durability_enabled = true
	DurabilityService.apply_weapon_use(weapon, DurabilityService.SHOT_WEAR)
	if not is_equal_approx(weapon.current_durability, before - DurabilityService.SHOT_WEAR):
		failures.append("Per-shot durability loss failed")
	weapon.current_durability = 0.0
	if not weapon.is_broken() or player.weapons[0].can_operate():
		failures.append("Broken equipped weapon was not blocked")
	weapon.current_durability = weapon.max_durability * 0.5
	var death_before := weapon.current_durability
	run_inventory.add_item(ItemInstance.create(PlayerProfile.get_definition("armory_scrap"), "test:lost"))
	var loadout_before := PlayerProfile.weapon_instance_slots.duplicate()
	_fail_run("TEST DEATH", true, false, false)
	if weapon.current_durability >= death_before or run_inventory.item_count() != 0 or PlayerProfile.weapon_instance_slots != loadout_before:
		failures.append("Death durability penalty failed")
	var cost := DurabilityService.repair_cost(weapon, PlayerProfile.get_definition(String(weapon.definition_id)))
	PlayerProfile.gold = cost + 5
	if not PlayerProfile.repair_instance(weapon.instance_id, false) or not is_equal_approx(weapon.current_durability, weapon.max_durability) or PlayerProfile.gold != 5:
		failures.append("Gold repair service failed")
	var migrated := snapshot.duplicate(true)
	migrated["save_version"] = 2
	for entry: Dictionary in migrated.owned_item_instances:
		entry["durability"] = 1.0
		entry.erase("current_durability")
		entry.erase("max_durability")
	if not PlayerProfile.apply_save_data(migrated, false) or PlayerProfile.get_weapon_instance(0).current_durability != PlayerProfile.get_weapon_instance(0).max_durability:
		failures.append("Version 2 durability migration did not restore maximum durability")
	PlayerProfile.apply_save_data(snapshot, false)
	_finish_test(failures, "DURABILITY_SELF_TEST_OK: use, breakage, death wear, repair and save migration passed")


func _run_dungeon_soak_test() -> void:
	var failures: Array[String] = []
	var snapshot := PlayerProfile.to_save_data()
	player.health.max_health = 10000.0
	player.health.reset()
	var starting_positions: Dictionary = {}
	for enemy: BotController in enemies:
		starting_positions[enemy.get_instance_id()] = enemy.global_position
	for frame: int in 600:
		await get_tree().physics_frame
	var moved_enemies := 0
	for enemy: BotController in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(starting_positions.get(enemy.get_instance_id(), enemy.global_position)) > 0.5:
			moved_enemies += 1
		if enemy.ai_state == BotController.STATE_STUCK and enemy.state_time > 1.5:
			failures.append("%s remained permanently stuck" % enemy.name)
	if moved_enemies == 0:
		failures.append("No hostile moved during the dungeon physics soak")
	if run_finished or time_remaining >= RUN_DURATION or time_remaining < RUN_DURATION - 20.0:
		failures.append("Run timer or active state was invalid during soak")
	PlayerProfile.apply_save_data(snapshot, false)
	_finish_test(failures, "DUNGEON_SOAK_OK: hostile pressure, movement, stuck recovery, HUD and live timer remained active")


func _run_dungeon_scene_flow_test() -> void:
	var failure := String(PlayerProfile.get_meta("dungeon_flow_failure", ""))
	if player.is_cursor_free or (DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		failure = "Dungeon did not capture the mouse on entry"
	var yaw_before := player.rotation.y
	var pitch_before := player.pitch_pivot.rotation.x
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.relative = Vector2(24.0, -12.0)
	get_viewport().push_input(mouse_motion)
	await get_tree().process_frame
	if is_equal_approx(player.rotation.y, yaw_before) and is_equal_approx(player.pitch_pivot.rotation.x, pitch_before):
		failure = "Dungeon HUD consumed mouse motion before camera look"
	var camera_before := player.is_first_person
	var camera_event := InputEventAction.new()
	camera_event.action = &"toggle_camera"
	camera_event.pressed = true
	get_viewport().push_input(camera_event)
	await get_tree().process_frame
	if player.is_first_person == camera_before:
		failure = "FPP/TPP switching failed after dungeon entry"
	_on_return_requested()
	if not get_tree().paused or not pause_layer.visible or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or not player.is_cursor_free or MouseModeService.current_mode != MouseModeService.Mode.PAUSE:
		failure = "Dungeon ESC did not pause and release the mouse"
	_show_pause_settings()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._input(click)
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or not player.is_cursor_free or MouseModeService.current_mode != MouseModeService.Mode.SETTINGS:
		failure = "Dungeon pause settings click recaptured gameplay input"
	_hide_pause_settings()
	_toggle_pause()
	await get_tree().process_frame
	# Headless display servers cannot reacquire OS pointer capture after releasing it.
	# The gameplay ownership flag still verifies that the click reached the capture path.
	if player.is_cursor_free or (DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		failure = "Dungeon resume did not recapture the mouse"
	if not failure.is_empty():
		PlayerProfile.set_meta("dungeon_flow_failure", failure)
	var stage := String(PlayerProfile.get_meta("dungeon_flow_stage", "first"))
	PlayerProfile.set_meta("dungeon_flow_stage", "between" if stage == "first" else "returned")
	MouseModeService.enter_lobby()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _finish_test(failures: Array[String], success: String) -> void:
	if failures.is_empty():
		print(success)
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		get_tree().quit(1)


func _capture_dungeon_inventory() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	var sample_ids: Array[String] = ["field_tonic", "armory_scrap", "worn_assault_rifle", "rusty_katana", "rusted_helmet", "torn_mail", "simple_ring"]
	for index: int in sample_ids.size():
		var definition := PlayerProfile.get_definition(sample_ids[index])
		var instance := AffixRoller.roll_item(definition, 4200 + index, "capture:%d" % index) if definition.item_type == ItemDefinition.ItemType.WEAPON else ItemInstance.create(definition, "capture:%d" % index)
		run_inventory.add_item(instance)
	inventory_menu.open()
	for frame: int in 20:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("res://validation_dungeon_inventory.png")
	print("DUNGEON_INVENTORY_CAPTURE_OK" if error == OK else "DUNGEON_INVENTORY_CAPTURE_FAILED")
	get_tree().quit(0 if error == OK else 1)
