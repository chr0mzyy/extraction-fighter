class_name LobbyController
extends Control

const COLOR_BG := Color(0.012, 0.015, 0.018)
const COLOR_PANEL := Color(0.025, 0.032, 0.037, 0.97)
const COLOR_PANEL_LIGHT := Color(0.055, 0.065, 0.070, 0.98)
const COLOR_BORDER := Color(0.25, 0.29, 0.30)
const COLOR_TEXT := Color(0.96, 0.97, 0.95)
const COLOR_MUTED := Color(0.52, 0.56, 0.56)
const COLOR_ACCENT := Color(0.02, 0.74, 0.90)
const COLOR_YELLOW := Color(1.0, 0.78, 0.08)
const COLOR_READY := Color(0.35, 0.92, 0.64)
const COLOR_WARNING := Color(0.94, 0.22, 0.18)
const HUMANOID_VISUAL_SCRIPT := preload("res://scripts/visuals/humanoid_placeholder.gd")

var screen_host: Control
var footer_label: Label
var selected_kind: String = "weapon"
var selected_slot: int = 0
var selected_gear_key: String = ""
var stash_filter: int = -1
var stash_subfilter: String = "all"
var stash_sort: int = 0
var stash_search: String = ""
var stash_overflow_only: bool = false
var selected_instance_id: String = ""
var details_label: Label
var comparison_details: RichTextLabel
var feedback_label: Label
var item_tooltip: ItemTooltip
var context_menu: PopupMenu
var context_payload: Dictionary = {}
var repair_dialog: ConfirmationDialog
var pending_repair: Dictionary = {}
var destructive_dialog: ConfirmationDialog
var pending_destructive: Dictionary = {}
var top_gold_label: Label
var current_screen: String = "main"
var screen_tween: Tween
var stash_search_timer: Timer
var pending_bind_action: StringName = &""
var pending_bind_button: Button
var keybind_feedback: Label
var operative_preview: Node3D
var preview_time: float = 0.0

const RESTART_TEST_PATH := "user://extraction_fighter_restart_test.json"


func _process(delta: float) -> void:
	if is_instance_valid(operative_preview):
		preview_time += delta
		operative_preview.rotation.y = -0.24 + sin(preview_time * 0.72) * 0.055
		operative_preview.position.y = 0.91 + sin(preview_time * 1.15) * 0.012


func _ready() -> void:
	MouseModeService.enter_lobby()
	AudioManager.play_music(&"lobby")
	var args := OS.get_cmdline_user_args()
	_apply_development_flags(args)
	if _should_use_development_test_profile(args):
		PlayerProfile.create_development_profile()
	_build_shell()
	if "--scene-flow-test" in args:
		_handle_scene_flow_test()
		return
	if "--dungeon-scene-flow-test" in args:
		_handle_dungeon_scene_flow_test()
		return
	if _should_route_to_dungeon(args):
		_route_to_dungeon.call_deferred()
		return
	if "--training-self-test" in args:
		_route_to_training.call_deferred()
		return
	if _should_route_to_arena(args):
		if "--loadout-integration-test" in args:
			PlayerProfile.create_development_profile()
			_configure_integration_loadout()
		elif "--content-arena-test" in args:
			PlayerProfile.create_development_profile()
			_configure_content_loadout()
		elif _needs_legacy_arena_test_loadout(args):
			PlayerProfile.create_development_profile()
			PlayerProfile.equip_weapon(0, "ronin_katana", false)
			PlayerProfile.equip_weapon(1, "huntsman_rifle", false)
		else:
			PlayerProfile.reset_to_defaults(false)
		_route_to_arena.call_deferred()
		return
	_show_main()
	if "--profile-self-test" in args:
		_run_profile_self_test.call_deferred()
	elif "--profile-restart-write-test" in args:
		_run_profile_restart_write.call_deferred()
	elif "--profile-restart-read-test" in args:
		_run_profile_restart_read.call_deferred()
	elif "--lobby-layout-test" in args:
		_run_lobby_layout_test.call_deferred()
	elif "--content-self-test" in args:
		_run_content_self_test.call_deferred()
	elif "--tooltip-self-test" in args:
		_run_tooltip_self_test.call_deferred()
	elif "--affix-self-test" in args:
		_run_affix_self_test.call_deferred()
	elif "--inventory-ui-test" in args:
		_run_inventory_ui_test.call_deferred()
	elif "--settings-self-test" in args:
		_run_settings_self_test.call_deferred()
	elif "--loot-statistics-test" in args:
		_run_loot_statistics_test.call_deferred()
	elif "--capture-loadout" in args:
		_show_loadout()
		_capture_lobby.bind("loadout").call_deferred()
	elif "--capture-stash" in args:
		_show_stash()
		_capture_lobby.bind("stash").call_deferred()
	elif "--capture-tooltip" in args:
		_show_loadout()
		_capture_tooltip.call_deferred()
	elif "--capture-lobby" in args:
		_capture_lobby.bind("lobby").call_deferred()


func _input(event: InputEvent) -> void:
	if pending_bind_action == &"":
		if event.is_action_pressed("menu_toggle") and current_screen != "main":
			_show_main()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		get_viewport().set_input_as_handled()
		if key_event.physical_keycode == KEY_ESCAPE or key_event.keycode == KEY_ESCAPE:
			_finish_rebind(false, "Binding cancelled")
			return
		_accept_rebind(key_event)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
		_accept_rebind(event)


func _should_route_to_arena(args: PackedStringArray) -> bool:
	for flag in ["--self-test", "--ai-soak-test", "--hud-layout-test", "--capture-frame", "--capture-tpp", "--capture-pause", "--capture-ads", "--loadout-integration-test", "--content-arena-test", "--effect-self-test", "--pause-flow-test", "--polish-self-test", "--combat-feel-test"]:
		if flag in args:
			return true
	return false


func _should_route_to_dungeon(args: PackedStringArray) -> bool:
	for flag in ["--dungeon-self-test", "--extraction-flow-test", "--durability-self-test", "--dungeon-soak-test", "--capture-dungeon-inventory"]:
		if flag in args:
			return true
	return false


func _needs_legacy_arena_test_loadout(args: PackedStringArray) -> bool:
	for flag: String in ["--self-test", "--ai-soak-test", "--hud-layout-test", "--effect-self-test", "--pause-flow-test", "--polish-self-test", "--combat-feel-test"]:
		if flag in args:
			return true
	return false


func _route_to_arena() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _route_to_dungeon() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon/armory_dungeon.tscn")


func _route_to_training() -> void:
	get_tree().change_scene_to_file("res://scenes/training/movement_training.tscn")


func _should_use_development_test_profile(args: PackedStringArray) -> bool:
	for flag: String in ["--content-self-test", "--tooltip-self-test", "--affix-self-test", "--inventory-ui-test"]:
		if flag in args:
			return true
	return false


func _apply_development_flags(args: PackedStringArray) -> void:
	var development_requested := false
	for argument: String in args:
		if argument.begins_with("--dev-"):
			development_requested = true
	if not development_requested:
		return
	PlayerProfile.development_session = true
	if "--dev-unlock-all" in args:
		PlayerProfile.create_development_profile()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_usec())
	for argument: String in args:
		if argument.begins_with("--dev-gold="):
			PlayerProfile.add_gold(maxi(0, int(argument.trim_prefix("--dev-gold="))))
		elif argument == "--dev-give-key":
			PlayerProfile.secure_extracted_instance(ItemInstance.create(PlayerProfile.get_definition("extraction_key"), "debug:key:%d" % Time.get_ticks_usec()), false)
		elif argument.begins_with("--dev-loot="):
			var source := argument.trim_prefix("--dev-loot=")
			var instance := LootTableService.roll_instance(rng, source, "arsenal", 0, 0, "debug:loot:%d" % Time.get_ticks_usec())
			if instance != null:
				PlayerProfile.secure_extracted_instance(instance, false)
		elif argument.begins_with("--dev-rarity="):
			var rarity_name := argument.trim_prefix("--dev-rarity=").to_upper()
			var rarity_index := ItemDefinition.Rarity.keys().find(rarity_name)
			if rarity_index >= 0 and rarity_index <= ItemDefinition.Rarity.UNIQUE:
				var instance := ItemInstance.create(PlayerProfile.get_definition("extraction_key"), "debug:unique:%d" % Time.get_ticks_usec()) if rarity_index == ItemDefinition.Rarity.UNIQUE else LootTableService.roll_instance_for_rarity(rng, rarity_index as ItemDefinition.Rarity, "arsenal", "debug:rarity:%d" % Time.get_ticks_usec())
				if instance != null:
					PlayerProfile.secure_extracted_instance(instance, false)
	PlayerProfile.development_session = true


func _handle_scene_flow_test() -> void:
	if String(PlayerProfile.get_meta("scene_flow_stage", "")) == "returned":
		var failure := String(PlayerProfile.get_meta("scene_flow_failure", ""))
		PlayerProfile.remove_meta("scene_flow_stage")
		PlayerProfile.remove_meta("scene_flow_failure")
		if failure.is_empty() and PlayerProfile.weapon_slots == ["ronin_katana", "huntsman_rifle"]:
			print("SCENE_FLOW_OK: Lobby -> Arena -> Lobby retained the selected loadout")
			get_tree().quit(0)
		else:
			push_error("SCENE_FLOW_FAILURE: " + (failure if not failure.is_empty() else "Loadout changed during scene flow"))
			get_tree().quit(1)
		return
	PlayerProfile.create_development_profile()
	PlayerProfile.equip_weapon(0, "ronin_katana", false)
	PlayerProfile.equip_weapon(1, "huntsman_rifle", false)
	PlayerProfile.set_meta("scene_flow_stage", "arena")
	_route_to_arena.call_deferred()


func _handle_dungeon_scene_flow_test() -> void:
	var stage := String(PlayerProfile.get_meta("dungeon_flow_stage", ""))
	if stage == "returned":
		var failure := String(PlayerProfile.get_meta("dungeon_flow_failure", ""))
		PlayerProfile.remove_meta("dungeon_flow_stage")
		PlayerProfile.remove_meta("dungeon_flow_failure")
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			failure = "Lobby did not restore visible mouse mode"
		if failure.is_empty():
			print("DUNGEON_SCENE_FLOW_OK: Lobby -> Armory -> Lobby retained profile and restored mouse ownership")
			get_tree().quit(0)
		else:
			push_error("DUNGEON_SCENE_FLOW_FAILURE: " + failure)
			get_tree().quit(1)
		return
	if stage == "between":
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			PlayerProfile.set_meta("dungeon_flow_failure", "Lobby between dungeon deployments did not restore visible mouse mode")
		PlayerProfile.set_meta("dungeon_flow_stage", "second")
		_route_to_dungeon.call_deferred()
		return
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		PlayerProfile.set_meta("dungeon_flow_failure", "Initial Lobby mouse mode was not visible")
	PlayerProfile.set_meta("dungeon_flow_stage", "first")
	_route_to_dungeon.call_deferred()


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_add_shell_graphics()

	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 96
	top.add_theme_stylebox_override("panel", _style(Color(0.0, 0.0, 0.0, 0.96), COLOR_YELLOW, 0, 0))
	add_child(top)
	var top_margin := _margin(top, 34, 10, 34, 9)
	var title_row := HBoxContainer.new()
	top_margin.add_child(title_row)
	var brand_mark := _label(title_row, "EF//", 18, COLOR_YELLOW)
	brand_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var title := _label(title_row, " EXTRACTION FIGHTER", 38, COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var milestone := _label(title_row, "MVP 0.4.3  //  LOCAL\nCORE LOOP ONLINE", 11, COLOR_ACCENT)
	milestone.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	milestone.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_gold_label = _label(title_row, "%d GOLD  •  %d SCRAP" % [PlayerProfile.gold, PlayerProfile.scrap], 13, COLOR_YELLOW)
	top_gold_label.custom_minimum_size.x = 120
	top_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var yellow_rule := ColorRect.new()
	yellow_rule.color = COLOR_YELLOW
	yellow_rule.anchor_left = 0.0
	yellow_rule.anchor_top = 0.0
	yellow_rule.anchor_right = 1.0
	yellow_rule.anchor_bottom = 0.0
	yellow_rule.offset_left = 0.0
	yellow_rule.offset_top = 92.0
	yellow_rule.offset_right = 0.0
	yellow_rule.offset_bottom = 96.0
	yellow_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(yellow_rule)

	screen_host = Control.new()
	screen_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_host.offset_top = 96
	screen_host.offset_bottom = -42
	add_child(screen_host)

	footer_label = _label(self, "[ESC] BACK   //   LOCAL COMBAT PROFILE   //   SAVE VERSION 5", 11, COLOR_YELLOW)
	footer_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer_label.offset_left = 30
	footer_label.offset_right = -30
	footer_label.offset_top = -34
	footer_label.offset_bottom = -10
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	item_tooltip = ItemTooltip.new()
	item_tooltip.name = "ItemTooltip"
	add_child(item_tooltip)
	item_tooltip.set_comparison_provider(PlayerProfile.get_comparison_instance)
	context_menu = PopupMenu.new()
	context_menu.name = "ItemContextMenu"
	context_menu.index_pressed.connect(_on_context_action)
	add_child(context_menu)
	repair_dialog = ConfirmationDialog.new()
	repair_dialog.title = "CONFIRM REPAIR"
	repair_dialog.confirmed.connect(_execute_pending_repair)
	add_child(repair_dialog)
	destructive_dialog = ConfirmationDialog.new()
	destructive_dialog.title = "CONFIRM ITEM ACTION"
	destructive_dialog.confirmed.connect(_execute_pending_destructive)
	add_child(destructive_dialog)
	stash_search_timer = Timer.new()
	stash_search_timer.one_shot = true
	stash_search_timer.wait_time = 0.18
	stash_search_timer.timeout.connect(_show_stash)
	add_child(stash_search_timer)


func _add_shell_graphics() -> void:
	var graphics := Control.new()
	graphics.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	graphics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(graphics)
	var cyan_mass := ColorRect.new()
	cyan_mass.color = Color(COLOR_ACCENT, 0.095)
	cyan_mass.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	cyan_mass.offset_right = 440
	cyan_mass.rotation = -0.035
	cyan_mass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graphics.add_child(cyan_mass)
	for index: int in range(15):
		var line := ColorRect.new()
		line.color = Color(0.18, 0.22, 0.23, 0.22 if index % 3 else 0.38)
		line.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		line.offset_left = index * 96
		line.offset_right = line.offset_left + 1
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		graphics.add_child(line)
	for index: int in range(9):
		var line := ColorRect.new()
		line.color = Color(0.18, 0.22, 0.23, 0.22)
		line.set_anchors_preset(Control.PRESET_TOP_WIDE)
		line.offset_top = 96 + index * 82
		line.offset_bottom = line.offset_top + 1
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		graphics.add_child(line)
	for index: int in range(5):
		var hazard := ColorRect.new()
		hazard.color = Color(COLOR_YELLOW, 0.16)
		hazard.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		hazard.offset_left = -330 + index * 54
		hazard.offset_right = hazard.offset_left + 22
		hazard.offset_top = -170
		hazard.offset_bottom = 30
		hazard.rotation = 0.42
		hazard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		graphics.add_child(hazard)


func _clear_screen() -> void:
	pending_bind_action = &""
	pending_bind_button = null
	keybind_feedback = null
	if item_tooltip != null:
		item_tooltip.hide_item()
	if context_menu != null:
		context_menu.hide()
	for child: Node in screen_host.get_children():
		child.queue_free()
	details_label = null
	comparison_details = null
	feedback_label = null
	if top_gold_label != null:
		top_gold_label.text = "%d GOLD  •  %d SCRAP" % [PlayerProfile.gold, PlayerProfile.scrap]
	if screen_tween != null and screen_tween.is_valid():
		screen_tween.kill()
	screen_host.modulate.a = 0.15
	screen_host.position.x = 8.0
	_animate_screen_in.call_deferred()


func _animate_screen_in() -> void:
	screen_tween = create_tween().set_parallel(true)
	screen_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	screen_tween.tween_property(screen_host, "modulate:a", 1.0, 0.16)
	screen_tween.tween_property(screen_host, "position:x", 0.0, 0.16)


func _show_main() -> void:
	_clear_screen()
	current_screen = "main"
	var margin := _margin(screen_host, 34, 22, 34, 22)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)

	var operative_panel := _panel(row, Vector2(510, 0))
	operative_panel.name = "OperativePreviewPanel"
	operative_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var operative_margin := _margin(operative_panel, 4, 4, 4, 4)
	var character_stage := _build_character_placeholder(operative_margin)
	character_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size.x = 500
	right_column.add_theme_constant_override("separation", 12)
	row.add_child(right_column)
	_label(right_column, "// DEPLOYMENT TERMINAL", 13, COLOR_YELLOW)
	var menu_panel := _panel(right_column)
	menu_panel.name = "MainMenuPanel"
	menu_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var menu_margin := _margin(menu_panel, 18, 14, 18, 14)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 7)
	menu_margin.add_child(menu)
	_label(menu, "SELECT OPERATION", 11, COLOR_MUTED)
	_add_menu_button(menu, "PLAY", _show_play)
	_add_menu_button(menu, "LOADOUT", _show_loadout)
	_add_menu_button(menu, "STASH", _show_stash)
	_add_menu_button(menu, "CUSTOMIZATION", _show_customization)
	_add_menu_button(menu, "SETTINGS", _show_settings)
	_add_menu_button(menu, "QUIT", _quit_game, true)

	var summary_panel := _panel(right_column)
	summary_panel.name = "BuildSummaryPanel"
	var summary_margin := _margin(summary_panel, 15, 11, 15, 11)
	var summary := VBoxContainer.new()
	summary.add_theme_constant_override("separation", 4)
	summary_margin.add_child(summary)
	var summary_header := HBoxContainer.new()
	summary.add_child(summary_header)
	var current_build := _label(summary_header, "ACTIVE KIT", 11, COLOR_ACCENT)
	current_build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(summary_header, "%03d/%03d POWER" % [PlayerProfile.get_skill_power(), PlayerProfile.POWER_LIMIT], 11, COLOR_READY)
	_label(summary, "%s  //  %s" % [_definition_name(PlayerProfile.weapon_slots[0]).to_upper(), _definition_name(PlayerProfile.weapon_slots[1]).to_upper()], 15, COLOR_TEXT)
	var skills: Array[String] = []
	for item_id: String in PlayerProfile.skill_slots:
		skills.append(_definition_name(item_id).to_upper())
	_label(summary, " + ".join(skills) + "   //   READY", 11, COLOR_MUTED)


func _show_play() -> void:
	current_screen = "play"
	var content := _show_simple_screen("SELECT ACTIVITY", "Choose a deployment route.")
	var cards := HBoxContainer.new()
	cards.name = "ActivityCards"
	cards.add_theme_constant_override("separation", 18)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cards)
	var arena := _activity_card(cards, "ARENA", "Continuous deathmatch testing\nSelected loadout enabled", true)
	arena.pressed.connect(_launch_arena)
	var dungeon := _activity_card(cards, "THE ARMORY", "15 minute extraction run\nLoot is lost on death", true)
	dungeon.pressed.connect(_launch_dungeon)
	var training := _activity_card(cards, "MOVEMENT TRAINING", "10-mechanic timed course\nCheckpoints • personal best • no item wear", false)
	training.name = "MovementTrainingCard"
	training.pressed.connect(_launch_training)
	_add_back_button(content)


func _show_loadout() -> void:
	_clear_screen()
	current_screen = "loadout"
	var margin := _margin(screen_host, 22, 16, 22, 16)
	margin.name = "LoadoutMargin"
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 9)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var heading := _label(header, "LOADOUT", 24, COLOR_TEXT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var power := PlayerProfile.get_skill_power()
	var power_label := _label(header, "POWER  %d / %d" % [power, PlayerProfile.POWER_LIMIT], 20, COLOR_READY if power <= PlayerProfile.POWER_LIMIT else COLOR_WARNING)
	power_label.name = "PowerLabel"
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(header, "   %d GOLD" % PlayerProfile.gold, 13, COLOR_YELLOW)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	var choices_panel := _panel(columns, Vector2(420, 0))
	choices_panel.name = "ChoicesPanel"
	choices_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var choices_margin := _margin(choices_panel, 12, 10, 12, 10)
	var choices_root := VBoxContainer.new()
	choices_root.add_theme_constant_override("separation", 7)
	choices_margin.add_child(choices_root)
	_label(choices_root, "AVAILABLE  //  %s" % selected_kind.to_upper(), 12, COLOR_ACCENT)
	var hint := _label(choices_root, "Drag to a compatible slot. Double-click for quick equip.", 10, COLOR_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var storage_targets := HBoxContainer.new()
	storage_targets.add_theme_constant_override("separation", 6)
	choices_root.add_child(storage_targets)
	var stash_target := _make_item_slot(storage_targets, null, null, "stash", "", {"compact": true, "empty_caption": "DROP → STASH"})
	stash_target.custom_minimum_size = Vector2(185, 58)
	var free_slot := PlayerProfile.get_first_free_inventory_slot()
	var inventory_target := _make_item_slot(storage_targets, null, null, "inventory", free_slot, {"compact": true, "empty_caption": "DROP → INVENTORY"})
	inventory_target.custom_minimum_size = Vector2(185, 58)
	if free_slot < 0:
		inventory_target.modulate.a = 0.38
	var choices_scroll := ScrollContainer.new()
	choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choices_root.add_child(choices_scroll)
	var choices := GridContainer.new()
	choices.name = "Choices"
	choices.columns = 2
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("h_separation", 7)
	choices.add_theme_constant_override("v_separation", 7)
	choices_scroll.add_child(choices)
	for instance: ItemInstance in _get_loadout_available_instances():
		var definition := PlayerProfile.get_definition(String(instance.definition_id))
		var inventory_slot := PlayerProfile.find_inventory_slot(instance.instance_id)
		var origin_kind := "inventory" if inventory_slot >= 0 else "stash"
		var origin_key: Variant = inventory_slot if inventory_slot >= 0 else ""
		var item_slot := _make_item_slot(choices, definition, instance, origin_kind, origin_key, {"new": PlayerProfile.new_instance_ids.has(instance.instance_id)})
		item_slot.custom_minimum_size = Vector2(194, 82)

	var equipped_panel := _panel(columns, Vector2(355, 0))
	equipped_panel.name = "EquippedPanel"
	var equipped_margin := _margin(equipped_panel, 12, 10, 12, 10)
	var equipped_root := VBoxContainer.new()
	equipped_root.add_theme_constant_override("separation", 6)
	equipped_margin.add_child(equipped_root)
	var operative := _label(equipped_root, "OPERATIVE  //  ACTIVE KIT", 13, COLOR_YELLOW)
	operative.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var equipped_scroll := ScrollContainer.new()
	equipped_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipped_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	equipped_root.add_child(equipped_scroll)
	var equipped := VBoxContainer.new()
	equipped.add_theme_constant_override("separation", 5)
	equipped_scroll.add_child(equipped)
	_label(equipped, "WEAPONS", 11, COLOR_ACCENT)
	for index: int in 2:
		_add_loadout_target(equipped, "WEAPON %d" % (index + 1), "loadout_weapon", index, PlayerProfile.get_definition(PlayerProfile.weapon_slots[index]), PlayerProfile.get_weapon_instance(index))
	_label(equipped, "SKILLS  //  %d / %d POWER" % [power, PlayerProfile.POWER_LIMIT], 11, COLOR_ACCENT)
	for index: int in 2:
		var definition := PlayerProfile.get_definition(PlayerProfile.skill_slots[index])
		_add_loadout_target(equipped, "SKILL %s" % GameSettings.get_binding_text(&"skill_slot_1" if index == 0 else &"skill_slot_2"), "loadout_skill", index, definition, PlayerProfile.get_instance_for_definition(PlayerProfile.skill_slots[index]))
	_label(equipped, "GEAR", 11, COLOR_ACCENT)
	for key: String in PlayerProfile.GEAR_KEYS:
		var slot_title := key.to_upper().replace("_1", " 1").replace("_2", " 2")
		var gear_definition := PlayerProfile.get_definition(String(PlayerProfile.equipped_gear.get(key, "")))
		_add_loadout_target(equipped, slot_title, "loadout_gear", key, gear_definition, PlayerProfile.get_gear_instance(key), true)

	var details_panel := _panel(columns, Vector2(270, 0))
	details_panel.name = "DetailsPanel"
	var details_margin := _margin(details_panel, 13, 11, 13, 11)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 7)
	details_margin.add_child(details)
	_label(details, "ITEM DETAILS", 12, COLOR_ACCENT)
	details_label = _label(details, "Select, hover or right-click an item.", 12, COLOR_TEXT)
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	comparison_details = _make_comparison_details(details)
	feedback_label = _label(details, "", 12, COLOR_WARNING)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var help := _label(details, "RIGHT CLICK  context menu\nDOUBLE CLICK  quick equip\nDRAG  move / equip", 10, COLOR_MUTED)
	help.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add_back_button(root)


func _show_stash() -> void:
	_clear_screen()
	current_screen = "stash"
	var margin := _margin(screen_host, 20, 14, 20, 14)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := _label(header, "STASH", 24, COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(header, "%d GOLD  •  %d SCRAP" % [PlayerProfile.gold, PlayerProfile.scrap], 14, COLOR_YELLOW)
	var repair_cost := PlayerProfile.get_equipped_repair_cost()
	var repair := _button(header, "REPAIR EQUIPPED  •  %d" % repair_cost, false)
	repair.custom_minimum_size = Vector2(205, 38)
	repair.disabled = repair_cost <= 0
	repair.pressed.connect(_request_repair_equipped)
	var repair_all_cost := PlayerProfile.get_all_damaged_repair_cost()
	var repair_all := _button(header, "REPAIR ALL  •  %d" % repair_all_cost, false)
	repair_all.custom_minimum_size = Vector2(175, 38)
	repair_all.disabled = repair_all_cost <= 0
	repair_all.pressed.connect(_request_repair_all)
	_label(header, "STORAGE %d / %d  •  OVERFLOW %d" % [PlayerProfile.get_stash_count(), PlayerProfile.STASH_CAPACITY, PlayerProfile.pending_reward_instances.size()], 13, COLOR_MUTED)
	var header_back := _button(header, "BACK", false)
	header_back.custom_minimum_size = Vector2(120, 38)
	header_back.pressed.connect(_show_main)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 7)
	root.add_child(filters)
	for filter_data: Array in [["ALL", -1], ["WEAPONS", ItemDefinition.ItemType.WEAPON], ["SKILLS", ItemDefinition.ItemType.SKILL], ["GEAR", ItemDefinition.ItemType.GEAR], ["CONSUMABLES", ItemDefinition.ItemType.CONSUMABLE], ["JUNK", ItemDefinition.ItemType.JUNK]]:
		var button := _button(filters, filter_data[0], false)
		button.pressed.connect(_set_stash_filter.bind(int(filter_data[1])))
		if not stash_overflow_only and stash_filter == int(filter_data[1]):
			button.add_theme_stylebox_override("normal", _style(Color(0.05, 0.13, 0.14), COLOR_ACCENT, 2, 0))
	var overflow_button := _button(filters, "OVERFLOW (%d)" % PlayerProfile.pending_reward_instances.size(), false)
	overflow_button.pressed.connect(_set_overflow_filter)
	if stash_overflow_only:
		overflow_button.add_theme_stylebox_override("normal", _style(Color(0.12, 0.07, 0.03), COLOR_YELLOW, 2, 0))
	var search := LineEdit.new()
	search.name = "StashSearch"
	search.placeholder_text = "Search name, type or affix"
	search.text = stash_search
	search.custom_minimum_size = Vector2(230, 36)
	search.text_changed.connect(_on_stash_search_changed)
	filters.add_child(search)
	if not stash_search.is_empty():
		search.grab_focus.call_deferred()
		search.set_caret_column.call_deferred(stash_search.length())
	var subfilter := OptionButton.new()
	var subfilter_options := _stash_subfilter_options()
	for option: String in subfilter_options:
		subfilter.add_item(option.to_upper().replace("_", " "))
	var selected_subfilter := subfilter_options.find(stash_subfilter)
	subfilter.select(maxi(0, selected_subfilter))
	subfilter.item_selected.connect(_set_stash_subfilter.bind(subfilter_options))
	filters.add_child(subfilter)
	var sort_label := _label(filters, "SORT", 11, COLOR_MUTED)
	sort_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var sort_menu := OptionButton.new()
	for option: String in ["RARITY", "NAME", "TYPE", "DURABILITY", "VALUE"]:
		sort_menu.add_item(option)
	sort_menu.select(stash_sort)
	sort_menu.item_selected.connect(_set_stash_sort)
	filters.add_child(sort_menu)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var stash_panel := _panel(body)
	stash_panel.name = "StashPanel"
	stash_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stash_margin := _margin(stash_panel, 10, 9, 10, 9)
	var stash_root := VBoxContainer.new()
	stash_root.add_theme_constant_override("separation", 6)
	stash_margin.add_child(stash_root)
	var stash_heading := HBoxContainer.new()
	stash_root.add_child(stash_heading)
	var stash_title := _label(stash_heading, "STORAGE", 11, COLOR_ACCENT)
	stash_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(stash_heading, "EXTRACTION OVERFLOW — MOVE, SELL OR DISMANTLE" if stash_overflow_only else "DROP HERE TO UNEQUIP / STORE", 9, COLOR_MUTED)
	var stash_scroll := ScrollContainer.new()
	stash_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stash_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stash_root.add_child(stash_scroll)
	var item_grid := GridContainer.new()
	item_grid.columns = 2
	item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_grid.add_theme_constant_override("h_separation", 6)
	item_grid.add_theme_constant_override("v_separation", 6)
	stash_scroll.add_child(item_grid)
	for instance: ItemInstance in _get_sorted_stash_instances():
		var definition := PlayerProfile.get_definition(String(instance.definition_id))
		var origin_kind := "overflow" if PlayerProfile.pending_instance_index.has(instance.instance_id) else "stash"
		var item_slot := _make_item_slot(item_grid, definition, instance, origin_kind, instance.instance_id if origin_kind == "overflow" else "", {"selected": selected_instance_id == instance.instance_id, "new": PlayerProfile.new_instance_ids.has(instance.instance_id)})
		item_slot.custom_minimum_size = Vector2(205, 78)
	if item_grid.get_child_count() == 0:
		var empty := _label(item_grid, "NO ITEMS MATCH THIS FILTER", 11, COLOR_MUTED)
		empty.custom_minimum_size = Vector2(410, 80)
	var inventory_panel := _panel(body, Vector2(360, 0))
	inventory_panel.name = "InventoryPanel"
	var inventory_margin := _margin(inventory_panel, 10, 9, 10, 9)
	var inventory_root := VBoxContainer.new()
	inventory_root.add_theme_constant_override("separation", 6)
	inventory_margin.add_child(inventory_root)
	var inventory_heading := HBoxContainer.new()
	inventory_root.add_child(inventory_heading)
	var inventory_title := _label(inventory_heading, "INVENTORY", 11, COLOR_ACCENT)
	inventory_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(inventory_heading, "%d / %d" % [PlayerProfile.INVENTORY_SIZE - _inventory_free_slots(), PlayerProfile.INVENTORY_SIZE], 10, COLOR_MUTED)
	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_root.add_child(inventory_scroll)
	var inventory_grid := GridContainer.new()
	inventory_grid.columns = 3
	inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_grid.add_theme_constant_override("h_separation", 5)
	inventory_grid.add_theme_constant_override("v_separation", 5)
	inventory_scroll.add_child(inventory_grid)
	for index: int in PlayerProfile.INVENTORY_SIZE:
		var instance := PlayerProfile.get_inventory_instance(index)
		var definition := PlayerProfile.get_inventory_definition(index)
		var slot := _make_item_slot(inventory_grid, definition, instance, "inventory", index, {"compact": true, "selected": instance != null and selected_instance_id == instance.instance_id, "new": instance != null and PlayerProfile.new_instance_ids.has(instance.instance_id), "empty_caption": "SLOT %02d" % (index + 1)})
		slot.name = "InventorySlot%d" % index
		slot.custom_minimum_size = Vector2(104, 68)

	var details_panel := _panel(body, Vector2(245, 0))
	details_panel.name = "DetailsPanel"
	var details_margin := _margin(details_panel, 12, 10, 12, 10)
	var details_root := VBoxContainer.new()
	details_root.add_theme_constant_override("separation", 7)
	details_margin.add_child(details_root)
	_label(details_root, "ITEM DETAILS", 11, COLOR_ACCENT)
	details_label = _label(details_root, "Select an item for details and actions.", 12, COLOR_TEXT)
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	comparison_details = _make_comparison_details(details_root)
	feedback_label = _label(details_root, "", 11, COLOR_WARNING)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not selected_instance_id.is_empty():
		_show_selected_instance_details(selected_instance_id)


func _show_customization() -> void:
	_show_placeholder("CUSTOMIZATION", "COMING SOON", "Cosmetics and character presentation are outside MVP 0.4.3.")


func _request_repair_instance(instance_id: String) -> void:
	var instance := PlayerProfile.get_instance(instance_id)
	var definition := PlayerProfile.get_definition(String(instance.definition_id)) if instance != null else null
	var cost := DurabilityService.repair_cost(instance, definition)
	if instance == null or definition == null or cost <= 0:
		_show_transfer_feedback("ITEM DOES NOT NEED REPAIR", false, &"ui_invalid")
		return
	pending_repair = {"kind": "item", "instance_id": instance_id, "cost": cost}
	repair_dialog.dialog_text = "%s\n%d → %d DURABILITY\nCost: %d Gold" % [definition.display_name.to_upper(), ceili(instance.current_durability), ceili(instance.max_durability), cost]
	repair_dialog.popup_centered(Vector2i(390, 190))


func _request_repair_equipped() -> void:
	var cost := PlayerProfile.get_equipped_repair_cost()
	pending_repair = {"kind": "equipped", "cost": cost}
	repair_dialog.dialog_text = "REPAIR ALL EQUIPPED ITEMS\nCost: %d Gold\n\nGold after repair: %d" % [cost, PlayerProfile.gold - cost]
	repair_dialog.popup_centered(Vector2i(390, 190))


func _request_repair_all() -> void:
	var cost := PlayerProfile.get_all_damaged_repair_cost()
	pending_repair = {"kind": "all", "cost": cost}
	repair_dialog.dialog_text = "REPAIR ALL DAMAGED ITEMS\nCost: %d Gold\n\nGold after repair: %d" % [cost, PlayerProfile.gold - cost]
	repair_dialog.popup_centered(Vector2i(390, 190))


func _execute_pending_repair() -> void:
	var success := false
	match String(pending_repair.get("kind", "")):
		"item": success = PlayerProfile.repair_instance(String(pending_repair.get("instance_id", "")))
		"equipped": success = PlayerProfile.repair_all_equipped()
		"all": success = PlayerProfile.repair_all_damaged()
	_show_transfer_feedback("REPAIR COMPLETE" if success else PlayerProfile.last_error, success, &"ui_repair" if success else &"ui_invalid")
	pending_repair.clear()
	if success:
		_refresh_current_inventory_screen()


func _show_settings() -> void:
	_clear_screen()
	current_screen = "settings"
	var margin := _margin(screen_host, 30, 20, 30, 20)
	var root := VBoxContainer.new()
	root.name = "SettingsRoot"
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := _label(header, "SETTINGS", 24, COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(header, "SAVED AUTOMATICALLY", 11, COLOR_READY)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)
	var video := _settings_column(columns, "VIDEO / GRAPHICS")
	var resolution_options := PackedStringArray()
	for resolution: Vector2i in GameSettings.RESOLUTIONS:
		resolution_options.append("%d × %d" % [resolution.x, resolution.y])
	_setting_option(video, "Resolution", resolution_options, GameSettings.RESOLUTIONS.find(GameSettings.resolution), _on_resolution_selected)
	_setting_toggle(video, "Fullscreen", GameSettings.fullscreen, &"fullscreen")
	_setting_toggle(video, "VSync", GameSettings.vsync, &"vsync")
	_setting_slider(video, "Base FOV", GameSettings.base_fov, 70.0, 110.0, 1.0, &"base_fov")
	_setting_slider(video, "FPS Cap", GameSettings.fps_cap, 30.0, 240.0, 15.0, &"fps_cap")
	_setting_option(video, "Shadow Quality", PackedStringArray(["OFF", "MEDIUM", "HIGH"]), GameSettings.shadow_quality, _on_setting_option.bind(&"shadow_quality"))
	_setting_slider(video, "Render Scale", GameSettings.render_scale, 0.5, 1.0, 0.05, &"render_scale")
	_setting_option(video, "Effects Quality", PackedStringArray(["LOW", "MEDIUM", "HIGH"]), GameSettings.effects_quality, _on_setting_option.bind(&"effects_quality"))

	var gameplay := _settings_column(columns, "GAMEPLAY")
	_setting_slider(gameplay, "Mouse Sensitivity", GameSettings.mouse_sensitivity * 1000.0, 0.5, 6.0, 0.1, &"mouse_sensitivity_ui")
	_setting_toggle(gameplay, "Invert Y", GameSettings.invert_y, &"invert_y")
	_setting_toggle(gameplay, "Damage Numbers", GameSettings.damage_numbers, &"damage_numbers")
	_setting_slider(gameplay, "Camera Shake", GameSettings.camera_shake_strength, 0.0, 1.0, 0.05, &"camera_shake_strength")
	_setting_slider(gameplay, "Hit Effects", GameSettings.hit_effects_intensity, 0.0, 1.0, 0.05, &"hit_effects_intensity")
	_setting_slider(gameplay, "Headbob", GameSettings.headbob_strength, 0.0, 1.0, 0.05, &"headbob_strength")
	_setting_slider(gameplay, "TPP Smoothing", GameSettings.tpp_camera_smoothing, 6.0, 30.0, 1.0, &"tpp_camera_smoothing")
	_setting_toggle(gameplay, "Crosshair", GameSettings.crosshair_enabled, &"crosshair_enabled")
	_label(gameplay, "CONTROLS", 12, COLOR_ACCENT)
	var controls := _label(gameplay, "Movement, combat and camera keys can be changed and are saved automatically.", 11, COLOR_MUTED)
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var keybinds_button := _button(gameplay, "EDIT KEYBINDS", false)
	keybinds_button.name = "EditKeybindsButton"
	keybinds_button.pressed.connect(_show_keybinds)

	var audio := _settings_column(columns, "AUDIO")
	_setting_slider(audio, "Master", GameSettings.master_volume, 0.0, 1.0, 0.05, &"master_volume")
	_setting_slider(audio, "Music", GameSettings.music_volume, 0.0, 1.0, 0.05, &"music_volume")
	_setting_slider(audio, "SFX", GameSettings.sfx_volume, 0.0, 1.0, 0.05, &"sfx_volume")
	_setting_slider(audio, "UI", GameSettings.ui_volume, 0.0, 1.0, 0.05, &"ui_volume")
	var audio_note := _label(audio, "Procedural placeholder audio is active. Every cue can be replaced centrally without changing gameplay code.", 11, COLOR_MUTED)
	audio_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var defaults := _button(audio, "RESTORE DEFAULTS", false)
	defaults.pressed.connect(_restore_setting_defaults)
	_add_back_button(root)


func _settings_column(parent: Control, heading: String) -> VBoxContainer:
	var panel := _panel(parent, Vector2(340, 0))
	panel.name = heading.replace(" / ", "").replace(" ", "") + "Panel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := _margin(panel, 14, 12, 14, 12)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	_label(column, heading, 12, COLOR_ACCENT)
	return column


func _setting_toggle(parent: Control, caption: String, enabled: bool, key: StringName) -> void:
	var toggle := CheckButton.new()
	toggle.text = caption
	toggle.button_pressed = enabled
	toggle.add_theme_font_size_override("font_size", 12)
	toggle.toggled.connect(_on_setting_toggled.bind(key))
	parent.add_child(toggle)


func _setting_slider(parent: Control, caption: String, value: float, minimum: float, maximum: float, step: float, key: StringName) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	parent.add_child(row)
	var value_label := _label(row, "%s  %s" % [caption, _format_setting_value(value)], 11, COLOR_TEXT)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.y = 22
	slider.value_changed.connect(_on_setting_slider.bind(key, value_label, caption))
	row.add_child(slider)


func _setting_option(parent: Control, caption: String, options: PackedStringArray, selected: int, callback: Callable) -> void:
	var label := _label(parent, caption, 11, COLOR_MUTED)
	label.custom_minimum_size.y = 16
	var option := OptionButton.new()
	for item: String in options:
		option.add_item(item)
	option.select(clampi(selected, 0, maxi(0, options.size() - 1)))
	option.item_selected.connect(callback)
	parent.add_child(option)


func _on_setting_toggled(enabled: bool, key: StringName) -> void:
	GameSettings.set_value(key, enabled)


func _on_setting_slider(value: float, key: StringName, value_label: Label, caption: String) -> void:
	var actual_value := value / 1000.0 if key == &"mouse_sensitivity_ui" else value
	var actual_key := &"mouse_sensitivity" if key == &"mouse_sensitivity_ui" else key
	value_label.text = "%s  %s" % [caption, _format_setting_value(value)]
	GameSettings.set_value(actual_key, actual_value)


func _on_setting_option(index: int, key: StringName) -> void:
	GameSettings.set_value(key, index)


func _on_resolution_selected(index: int) -> void:
	GameSettings.set_value(&"resolution", GameSettings.RESOLUTIONS[clampi(index, 0, GameSettings.RESOLUTIONS.size() - 1)])


func _format_setting_value(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.2f" % value


func _restore_setting_defaults() -> void:
	GameSettings.reset_defaults()
	GameSettings.save_settings()
	_show_settings()


func _show_keybinds() -> void:
	current_screen = "keybinds"
	var content := _show_simple_screen("KEYBINDS", "Click a binding, then press a keyboard or mouse button. Escape cancels.")
	var scroll := ScrollContainer.new()
	scroll.name = "KeybindsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 5)
	scroll.add_child(grid)
	for action: StringName in GameSettings.REBINDABLE_ACTIONS:
		var caption := _label(grid, GameSettings.get_action_label(action).to_upper(), 12, COLOR_TEXT)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bind_button := _button(grid, GameSettings.get_binding_text(action), false)
		bind_button.custom_minimum_size = Vector2(260, 34)
		bind_button.pressed.connect(_begin_rebind.bind(action, bind_button))
	keybind_feedback = _label(content, "", 11, COLOR_WARNING)
	keybind_feedback.name = "KeybindFeedback"
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	var reset := _button(actions, "RESET KEYBINDS", false)
	reset.pressed.connect(_reset_keybinds)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var back := _button(actions, "BACK TO SETTINGS", false)
	back.set_meta("audio_event", &"ui_back")
	back.pressed.connect(_show_settings)


func _begin_rebind(action: StringName, button: Button) -> void:
	if pending_bind_button != null:
		pending_bind_button.text = GameSettings.get_binding_text(pending_bind_action)
	pending_bind_action = action
	pending_bind_button = button
	button.text = "PRESS A KEY..."
	if keybind_feedback != null:
		keybind_feedback.text = "Waiting for %s" % GameSettings.get_action_label(action)


func _accept_rebind(event: InputEvent) -> void:
	var conflict := GameSettings.find_binding_conflict(pending_bind_action, event)
	if conflict != &"":
		_finish_rebind(false, "%s is already assigned to %s" % [event.as_text().to_upper(), GameSettings.get_action_label(conflict)])
		return
	var action := pending_bind_action
	if GameSettings.set_binding(action, event):
		_finish_rebind(true, "%s updated" % GameSettings.get_action_label(action))
	else:
		_finish_rebind(false, "This input cannot be assigned")


func _finish_rebind(success: bool, message: String) -> void:
	if pending_bind_button != null:
		pending_bind_button.text = GameSettings.get_binding_text(pending_bind_action)
	pending_bind_action = &""
	pending_bind_button = null
	if keybind_feedback != null:
		keybind_feedback.text = message
		keybind_feedback.add_theme_color_override("font_color", COLOR_READY if success else COLOR_WARNING)


func _reset_keybinds() -> void:
	GameSettings.reset_keybinds()
	_show_keybinds()
	if keybind_feedback != null:
		keybind_feedback.text = "Default keybinds restored"
		keybind_feedback.add_theme_color_override("font_color", COLOR_READY)


func _launch_training() -> void:
	PlayerProfile.save_profile()
	_route_to_training()


func _show_placeholder(title: String, status: String, body: String) -> void:
	current_screen = "placeholder"
	var content := _show_simple_screen(title, body)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var status_label := _label(content, status, 28, COLOR_ACCENT)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer_two := Control.new()
	spacer_two.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer_two)
	_add_back_button(content)


func _show_simple_screen(title: String, subtitle: String) -> VBoxContainer:
	_clear_screen()
	var margin := _margin(screen_host, 44, 32, 44, 32)
	margin.name = "ScreenMargin"
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	_label(content, title, 26, COLOR_TEXT)
	_label(content, subtitle, 13, COLOR_MUTED)
	return content


func _make_item_slot(parent: Control, definition: ItemDefinition, instance: ItemInstance, kind: String, key: Variant, options: Dictionary = {}) -> InventoryItemSlot:
	var slot := InventoryItemSlot.new()
	var configured_options := options.duplicate()
	configured_options["compatibility_checker"] = PlayerProfile.can_transfer_item
	configured_options["drop_handler"] = _on_item_dropped
	slot.configure(definition, instance, kind, key, configured_options)
	parent.add_child(slot)
	slot.selected_requested.connect(_select_item_payload)
	slot.quick_action_requested.connect(_quick_equip_payload)
	slot.context_requested.connect(_open_item_context)
	slot.drag_started.connect(_on_item_drag_started)
	slot.drag_finished.connect(_clear_drag_hints)
	_bind_tooltip(slot, definition, instance)
	return slot


func _add_loadout_target(parent: Control, caption: String, kind: String, key: Variant, definition: ItemDefinition, instance: ItemInstance, compact: bool = false) -> void:
	var heading := HBoxContainer.new()
	parent.add_child(heading)
	var caption_label := _label(heading, caption, 10, COLOR_MUTED)
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if definition != null and definition.item_type == ItemDefinition.ItemType.SKILL:
		_label(heading, "%d POWER" % definition.power_cost, 9, COLOR_YELLOW)
	var is_selected := (selected_kind == "weapon" and kind == "loadout_weapon" and selected_slot == int(key)) or (selected_kind == "skill" and kind == "loadout_skill" and selected_slot == int(key)) or (selected_kind == "gear" and kind == "loadout_gear" and selected_gear_key == String(key))
	var slot := _make_item_slot(parent, definition, instance, kind, key, {"selected": is_selected, "equipped": definition != null, "compact": compact, "empty_caption": caption + "  •  EMPTY"})
	slot.custom_minimum_size.y = 66 if compact else 76
	slot.selected_requested.connect(_on_loadout_slot_selected.bind(kind, key))


func _on_loadout_slot_selected(_payload: Dictionary, kind: String, key: Variant) -> void:
	match kind:
		"loadout_weapon":
			selected_kind = "weapon"
			selected_slot = int(key)
		"loadout_skill":
			selected_kind = "skill"
			selected_slot = int(key)
		"loadout_gear":
			selected_kind = "gear"
			selected_gear_key = String(key)
	_show_loadout()


func _get_loadout_available_instances() -> Array[ItemInstance]:
	var type_filter := ItemDefinition.ItemType.WEAPON
	if selected_kind == "skill":
		type_filter = ItemDefinition.ItemType.SKILL
	elif selected_kind == "gear":
		type_filter = ItemDefinition.ItemType.GEAR
	var result: Array[ItemInstance] = []
	for instance: ItemInstance in PlayerProfile.get_owned_instances(type_filter):
		if PlayerProfile.is_instance_equipped(instance.instance_id):
			continue
		var definition := PlayerProfile.get_definition(String(instance.definition_id))
		if selected_kind == "skill" and String(definition.id) in PlayerProfile.skill_slots:
			continue
		if selected_kind == "gear" and not _definition_fits_selected_gear(definition):
			continue
		result.append(instance)
	result.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		var a_definition := PlayerProfile.get_definition(String(a.definition_id))
		var b_definition := PlayerProfile.get_definition(String(b.definition_id))
		return a_definition.rarity > b_definition.rarity if a_definition.rarity != b_definition.rarity else a_definition.display_name < b_definition.display_name
	)
	return result


func _select_item_payload(payload: Dictionary) -> void:
	selected_instance_id = String(payload.get("instance_id", ""))
	if selected_instance_id.is_empty():
		return
	PlayerProfile.new_instance_ids.erase(selected_instance_id)
	_show_selected_instance_details(selected_instance_id)


func _show_selected_instance_details(instance_id: String) -> void:
	var instance := PlayerProfile.get_instance(instance_id)
	var definition := PlayerProfile.get_definition(String(instance.definition_id)) if instance != null else null
	if definition == null or details_label == null:
		return
	_show_item_details(definition, instance)
	if comparison_details != null:
		var equipped_instance := PlayerProfile.get_comparison_instance(definition)
		var equipped_definition := PlayerProfile.get_definition(String(equipped_instance.definition_id)) if equipped_instance != null else null
		comparison_details.text = item_tooltip._build_comparison(definition, instance, equipped_definition, equipped_instance)
		comparison_details.visible = not comparison_details.text.is_empty()


func _make_comparison_details(parent: Control) -> RichTextLabel:
	var comparison := RichTextLabel.new()
	comparison.bbcode_enabled = true
	comparison.fit_content = true
	comparison.scroll_active = false
	comparison.add_theme_font_size_override("normal_font_size", 11)
	comparison.mouse_filter = Control.MOUSE_FILTER_IGNORE
	comparison.visible = false
	parent.add_child(comparison)
	return comparison


func _quick_equip_payload(payload: Dictionary) -> void:
	var success := PlayerProfile.quick_equip_instance(String(payload.get("instance_id", "")))
	_show_transfer_feedback("ITEM EQUIPPED" if success else PlayerProfile.last_error, success, &"ui_equip" if success else &"ui_invalid")
	if success:
		_refresh_current_inventory_screen()


func _on_item_dropped(payload: Dictionary, target_kind: String, target_key: Variant) -> void:
	var success := PlayerProfile.transfer_item(payload, target_kind, target_key)
	_show_transfer_feedback("ITEM MOVED" if success else PlayerProfile.last_error, success, &"ui_equip" if target_kind.begins_with("loadout_") and success else (&"ui_unequip" if success else &"ui_invalid"))
	_clear_drag_hints()
	if success:
		_refresh_current_inventory_screen()


func _on_item_drag_started(payload: Dictionary) -> void:
	for node: Node in find_children("*", "InventoryItemSlot", true, false):
		var slot := node as InventoryItemSlot
		if slot == null:
			continue
		var result := PlayerProfile.can_transfer_item(payload, slot.slot_kind, slot.slot_key)
		slot.set_drag_hint(1 if bool(result.get("ok", false)) else -1)


func _clear_drag_hints() -> void:
	for node: Node in find_children("*", "InventoryItemSlot", true, false):
		var slot := node as InventoryItemSlot
		if slot != null:
			slot.set_drag_hint(0)


func _refresh_current_inventory_screen() -> void:
	if current_screen == "loadout":
		_show_loadout()
	elif current_screen == "stash":
		_show_stash()


func _show_transfer_feedback(message: String, success: bool, audio_event: StringName) -> void:
	footer_label.text = message.to_upper()
	footer_label.add_theme_color_override("font_color", COLOR_READY if success else COLOR_WARNING)
	if feedback_label != null:
		feedback_label.text = message.to_upper()
		feedback_label.add_theme_color_override("font_color", COLOR_READY if success else COLOR_WARNING)
	AudioEvents.play(audio_event)


func _open_item_context(payload: Dictionary, global_position: Vector2) -> void:
	context_payload = payload.duplicate(true)
	context_menu.clear()
	var instance := PlayerProfile.get_instance(String(payload.get("instance_id", "")))
	var definition := PlayerProfile.get_definition(String(instance.definition_id)) if instance != null else null
	if definition == null:
		return
	var origin_kind := String(payload.get("origin_kind", ""))
	if origin_kind.begins_with("loadout_"):
		context_menu.add_item("UNEQUIP TO INVENTORY", 2)
		context_menu.add_item("UNEQUIP TO STASH", 3)
	elif definition.item_type in [ItemDefinition.ItemType.WEAPON, ItemDefinition.ItemType.SKILL, ItemDefinition.ItemType.GEAR]:
		context_menu.add_item("EQUIP", 1)
	if origin_kind == "overflow":
		context_menu.add_item("MOVE TO STASH", 3)
	if instance.max_durability > 0.0 and instance.current_durability < instance.max_durability:
		context_menu.add_separator()
		context_menu.add_item("REPAIR  •  %d GOLD" % DurabilityService.repair_cost(instance, definition), 4)
	context_menu.add_separator()
	context_menu.add_item("INSPECT", 5)
	var sell_value := PlayerProfile.get_sell_value(instance)
	var scrap_yield := PlayerProfile.get_dismantle_yield(instance)
	if sell_value > 0 or scrap_yield > 0:
		context_menu.add_separator()
		if sell_value > 0:
			context_menu.add_item("SELL  •  +%d GOLD" % sell_value, 6)
		if scrap_yield > 0:
			context_menu.add_item("DISMANTLE  •  +%d SCRAP" % scrap_yield, 7)
	context_menu.position = Vector2i(global_position)
	context_menu.popup()


func _on_context_action(action_id: int) -> void:
	var instance_id := String(context_payload.get("instance_id", ""))
	var success := false
	match action_id:
		1:
			success = PlayerProfile.quick_equip_instance(instance_id)
			_show_transfer_feedback("ITEM EQUIPPED" if success else PlayerProfile.last_error, success, &"ui_equip" if success else &"ui_invalid")
		2:
			var free_slot := PlayerProfile.get_first_free_inventory_slot()
			if free_slot < 0:
				_show_transfer_feedback("NO FREE SLOT", false, &"ui_invalid")
			else:
				success = PlayerProfile.transfer_item(context_payload, "inventory", free_slot)
				_show_transfer_feedback("ITEM MOVED TO INVENTORY" if success else PlayerProfile.last_error, success, &"ui_unequip" if success else &"ui_invalid")
		3:
			success = PlayerProfile.transfer_item(context_payload, "stash", "")
			_show_transfer_feedback("ITEM MOVED TO STASH" if success else PlayerProfile.last_error, success, &"ui_unequip" if success else &"ui_invalid")
		4:
			_request_repair_instance(instance_id)
			return
		5:
			_select_item_payload(context_payload)
			return
		6, 7:
			_request_destructive_action("sell" if action_id == 6 else "dismantle", instance_id)
			return
	if success:
		_refresh_current_inventory_screen()


func _request_destructive_action(kind: String, instance_id: String) -> void:
	var instance := PlayerProfile.get_instance(instance_id)
	var definition := PlayerProfile.get_definition(String(instance.definition_id)) if instance != null else null
	if definition == null:
		return
	var reward := PlayerProfile.get_sell_value(instance) if kind == "sell" else PlayerProfile.get_dismantle_yield(instance)
	var currency := "GOLD" if kind == "sell" else "SCRAP"
	var warning := "\n\nHIGH-RARITY ITEM — THIS CANNOT BE UNDONE." if definition.rarity >= ItemDefinition.Rarity.LEGENDARY else "\n\nThis exact item instance will be destroyed."
	pending_destructive = {"kind": kind, "instance_id": instance_id}
	destructive_dialog.dialog_text = "%s %s?\nReward: +%d %s%s" % [kind.to_upper(), definition.display_name.to_upper(), reward, currency, warning]
	destructive_dialog.popup_centered(Vector2i(440, 210))


func _execute_pending_destructive() -> void:
	var kind := String(pending_destructive.get("kind", ""))
	var instance_id := String(pending_destructive.get("instance_id", ""))
	var success := PlayerProfile.sell_instance(instance_id) if kind == "sell" else PlayerProfile.dismantle_instance(instance_id)
	_show_transfer_feedback("ITEM SOLD" if kind == "sell" and success else ("ITEM DISMANTLED" if success else PlayerProfile.last_error), success, &"ui_click" if success else &"ui_invalid")
	pending_destructive.clear()
	if success:
		selected_instance_id = ""
		_refresh_current_inventory_screen()


func _add_slot_button(parent: Control, text: String, kind: String, slot: int, definition: ItemDefinition = null, instance: ItemInstance = null) -> void:
	var button := _button(parent, text, false)
	button.custom_minimum_size.y = 42
	button.pressed.connect(_select_loadout_target.bind(kind, slot, ""))
	_bind_tooltip(button, definition, instance)


func _add_gear_slot_button(parent: Control, text: String, key: String, definition: ItemDefinition = null, instance: ItemInstance = null) -> void:
	var button := _button(parent, text, false)
	button.custom_minimum_size.y = 36
	button.pressed.connect(_select_loadout_target.bind("gear", 0, key))
	_bind_tooltip(button, definition, instance)


func _select_loadout_target(kind: String, slot: int, gear_key: String) -> void:
	selected_kind = kind
	selected_slot = slot
	selected_gear_key = gear_key
	_show_loadout()


func _populate_loadout_choices(container: GridContainer) -> void:
	var type_filter := ItemDefinition.ItemType.WEAPON
	if selected_kind == "skill":
		type_filter = ItemDefinition.ItemType.SKILL
	elif selected_kind == "gear":
		type_filter = ItemDefinition.ItemType.GEAR
	if selected_kind == "skill":
		for definition: ItemDefinition in PlayerProfile.get_owned_definitions(type_filter):
			_add_loadout_choice(container, definition, null)
	else:
		for instance: ItemInstance in PlayerProfile.get_owned_instances(type_filter):
			var definition := PlayerProfile.get_definition(String(instance.definition_id))
			if selected_kind == "gear" and not _definition_fits_selected_gear(definition):
				continue
			_add_loadout_choice(container, definition, instance)


func _add_loadout_choice(container: GridContainer, definition: ItemDefinition, instance: ItemInstance) -> void:
	var suffix := "  •  %d POWER" % definition.power_cost if definition.item_type == ItemDefinition.ItemType.SKILL else ""
	if instance != null and instance.max_durability > 0.0:
		suffix += "  •  %s" % ("BROKEN" if instance.is_broken() else "%d/%d" % [ceili(instance.current_durability), ceili(instance.max_durability)])
	var button := _button(container, "%s%s" % [definition.display_name, suffix], false)
	button.custom_minimum_size = Vector2(220, 52)
	button.pressed.connect(_equip_instance.bind(definition, instance))
	_bind_tooltip(button, definition, instance)
	var selected := _is_definition_selected(definition) if instance == null else _is_instance_selected(instance)
	if selected:
		button.add_theme_stylebox_override("normal", _style(Color(0.055, 0.18, 0.2), COLOR_ACCENT, 2, 4))


func _is_instance_selected(instance: ItemInstance) -> bool:
	if selected_kind == "weapon":
		return PlayerProfile.weapon_instance_slots[selected_slot] == instance.instance_id
	if selected_kind == "gear":
		return String(PlayerProfile.equipped_gear_instances.get(selected_gear_key, "")) == instance.instance_id
	return false


func _equip_definition(definition: ItemDefinition) -> void:
	_show_item_details(definition)
	var success := false
	match selected_kind:
		"weapon": success = PlayerProfile.equip_weapon(selected_slot, String(definition.id))
		"skill": success = PlayerProfile.equip_skill(selected_slot, String(definition.id))
		"gear": success = PlayerProfile.equip_gear(selected_gear_key, String(definition.id))
	if success:
		_show_loadout()
	elif feedback_label != null:
		feedback_label.text = PlayerProfile.last_error
		AudioEvents.play(&"ui_invalid")


func _equip_instance(definition: ItemDefinition, instance: ItemInstance) -> void:
	if instance == null:
		_equip_definition(definition)
		return
	_show_item_details(definition)
	var success := PlayerProfile.equip_weapon_instance(selected_slot, instance.instance_id) if selected_kind == "weapon" else PlayerProfile.equip_gear_instance(selected_gear_key, instance.instance_id)
	if success:
		_show_loadout()
	elif feedback_label != null:
		feedback_label.text = PlayerProfile.last_error
		AudioEvents.play(&"ui_invalid")


func _show_item_details(definition: ItemDefinition, instance: ItemInstance = null) -> void:
	if details_label == null:
		return
	if instance == null:
		instance = PlayerProfile.get_instance_for_definition(String(definition.id))
	var lines: Array[String] = [definition.display_name.to_upper(), definition.get_rarity_name().to_upper(), "", '"%s"' % (definition.flavor_text if not definition.flavor_text.is_empty() else definition.description), "", definition.get_type_name().to_upper()]
	if definition.item_type == ItemDefinition.ItemType.SKILL:
		lines.append("POWER  %d" % definition.power_cost)
		lines.append("COOLDOWN  %.1fs" % definition.cooldown)
		lines.append("CURRENT TOTAL  %d / %d" % [PlayerProfile.get_skill_power(), PlayerProfile.POWER_LIMIT])
	elif definition.item_type == ItemDefinition.ItemType.WEAPON:
		lines.append("FAMILY  %s" % String(definition.weapon_family).replace("_", " ").to_upper())
		if definition.damage > 0.0: lines.append("DAMAGE  %s" % _format_setting_value(definition.damage))
		if definition.fire_rate > 0.0: lines.append("FIRE RATE  %s / SEC" % _format_setting_value(definition.fire_rate))
		if definition.magazine_size > 0: lines.append("MAGAZINE  %d" % definition.magazine_size)
		if definition.reload_time > 0.0: lines.append("RELOAD  %.2fs" % definition.reload_time)
		if definition.headshot_damage > 0.0: lines.append("HEADSHOT  %s" % _format_setting_value(definition.headshot_damage))
	elif definition.item_type == ItemDefinition.ItemType.GEAR:
		lines.append("SLOT  %s" % definition.get_gear_slot_name().to_upper())
		if definition.armor_value > 0: lines.append("ARMOR  %d" % definition.armor_value)
		if not definition.modifier_text.is_empty(): lines.append("BONUS  %s" % definition.modifier_text)
	if definition.rarity == ItemDefinition.Rarity.MYTHIC and not definition.special_description.is_empty():
		lines.append("\nUNIQUE  //  %s\n%s" % [definition.display_name.to_upper(), definition.special_description])
	if instance != null and not instance.affix_ids.is_empty():
		lines.append("\nAFFIXES")
		for index: int in instance.affix_ids.size():
			var affix := AffixDatabase.get_definition(instance.affix_ids[index])
			if affix == null:
				continue
			var tier := instance.affix_tiers[index] if index < instance.affix_tiers.size() else 1
			lines.append("%s %s\n%s" % [affix.display_name, ["I", "II", "III"][clampi(tier, 1, 3) - 1], affix.formatted_description(tier)])
	if instance != null and instance.max_durability > 0.0:
		lines.append("\nDURABILITY  %d / %d" % [ceili(instance.current_durability), ceili(instance.max_durability)])
		if instance.is_broken(): lines.append("BROKEN  //  CANNOT EQUIP")
		elif instance.current_durability / instance.max_durability <= 0.2: lines.append("LOW DURABILITY")
		lines.append("REPAIR COST  %d GOLD" % DurabilityService.repair_cost(instance, definition))
	if instance != null:
		var sell_value := PlayerProfile.get_sell_value(instance)
		var scrap_yield := PlayerProfile.get_dismantle_yield(instance)
		if sell_value > 0:
			lines.append("\nSELL VALUE  %d GOLD" % sell_value)
		if scrap_yield > 0:
			lines.append("DISMANTLE  %d SCRAP" % scrap_yield)
	details_label.text = "\n".join(lines)


func _bind_tooltip(control: Control, definition: ItemDefinition, instance: ItemInstance = null) -> void:
	if definition == null or item_tooltip == null:
		return
	control.mouse_entered.connect(item_tooltip.show_item.bind(definition, instance))
	if instance != null:
		control.mouse_entered.connect(_mark_item_seen.bind(instance.instance_id))
	control.mouse_exited.connect(item_tooltip.hide_item.bind(definition))


func _mark_item_seen(instance_id: String) -> void:
	PlayerProfile.new_instance_ids.erase(instance_id)


func _is_definition_selected(definition: ItemDefinition) -> bool:
	var item_id := String(definition.id)
	match selected_kind:
		"weapon": return PlayerProfile.weapon_slots[selected_slot] == item_id
		"skill": return PlayerProfile.skill_slots[selected_slot] == item_id
		"gear": return String(PlayerProfile.equipped_gear.get(selected_gear_key, "")) == item_id
	return false


func _definition_fits_selected_gear(definition: ItemDefinition) -> bool:
	match selected_gear_key:
		"helmet": return definition.gear_slot == ItemDefinition.GearSlot.HELMET
		"chest": return definition.gear_slot == ItemDefinition.GearSlot.CHEST
		"gloves": return definition.gear_slot == ItemDefinition.GearSlot.GLOVES
		"boots": return definition.gear_slot == ItemDefinition.GearSlot.BOOTS
		"necklace": return definition.gear_slot == ItemDefinition.GearSlot.NECKLACE
		"ring_1", "ring_2": return definition.gear_slot == ItemDefinition.GearSlot.RING
		"charm": return definition.gear_slot == ItemDefinition.GearSlot.CHARM
	return false


func _launch_arena() -> void:
	var validation := PlayerProfile.validate_loadout()
	if not bool(validation.valid):
		footer_label.text = "LOADOUT INVALID  •  " + "; ".join(validation.errors)
		footer_label.add_theme_color_override("font_color", COLOR_WARNING)
		return
	PlayerProfile.save_profile()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _launch_dungeon() -> void:
	var validation := PlayerProfile.validate_loadout()
	if not bool(validation.valid):
		footer_label.text = "LOADOUT INVALID  •  " + "; ".join(validation.errors)
		footer_label.add_theme_color_override("font_color", COLOR_WARNING)
		return
	PlayerProfile.save_profile()
	get_tree().change_scene_to_file("res://scenes/dungeon/armory_dungeon.tscn")


func _configure_integration_loadout() -> void:
	PlayerProfile.equip_weapon(0, "vanguard_rifle", false)
	PlayerProfile.equip_weapon(1, "knight_sword", false)
	PlayerProfile.equip_skill(0, "grapple", false)
	PlayerProfile.equip_skill(1, "blink", false)


func _configure_content_loadout() -> void:
	PlayerProfile.equip_weapon(0, "war_nodachi", false)
	PlayerProfile.equip_weapon(1, "arcane_wand", false)
	PlayerProfile.equip_skill(0, "wallrun", false)
	PlayerProfile.equip_skill(1, "smoke_veil", false)


func _set_stash_filter(filter_value: int) -> void:
	stash_filter = filter_value
	stash_overflow_only = false
	stash_subfilter = "all"
	_show_stash()


func _set_overflow_filter() -> void:
	stash_overflow_only = true
	stash_filter = -1
	stash_subfilter = "all"
	_show_stash()


func _set_stash_sort(sort_value: int) -> void:
	stash_sort = sort_value
	_show_stash()


func _set_stash_subfilter(index: int, options: Array[String]) -> void:
	stash_subfilter = options[clampi(index, 0, options.size() - 1)]
	_show_stash()


func _on_stash_search_changed(value: String) -> void:
	stash_search = value.strip_edges()
	stash_search_timer.start()


func _stash_subfilter_options() -> Array[String]:
	if stash_filter == ItemDefinition.ItemType.WEAPON:
		return ["all", "melee", "ranged", "magic"]
	if stash_filter == ItemDefinition.ItemType.GEAR:
		return ["all", "helmet", "chest", "gloves", "boots", "necklace", "ring", "charm"]
	return ["all"]


func _get_sorted_stash_instances() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	var source: Array[ItemInstance] = PlayerProfile.get_pending_instances() if stash_overflow_only else PlayerProfile.get_stash_instances(stash_filter)
	for instance: ItemInstance in source:
		var definition := PlayerProfile.get_definition(String(instance.definition_id))
		if stash_overflow_only and stash_filter >= 0 and definition.item_type != stash_filter:
			continue
		if not _matches_stash_subfilter(definition):
			continue
		if not _matches_stash_search(definition, instance):
			continue
		result.append(instance)
	result.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		var a_definition := PlayerProfile.get_definition(String(a.definition_id))
		var b_definition := PlayerProfile.get_definition(String(b.definition_id))
		match stash_sort:
			1: return a_definition.display_name.naturalnocasecmp_to(b_definition.display_name) < 0
			2: return a_definition.item_type < b_definition.item_type if a_definition.item_type != b_definition.item_type else a_definition.display_name < b_definition.display_name
			3:
				var a_ratio := a.current_durability / a.max_durability if a.max_durability > 0.0 else 1.0
				var b_ratio := b.current_durability / b.max_durability if b.max_durability > 0.0 else 1.0
				return a_ratio > b_ratio
			4: return PlayerProfile.get_sell_value(a) > PlayerProfile.get_sell_value(b)
			_: return a_definition.rarity > b_definition.rarity if a_definition.rarity != b_definition.rarity else a_definition.display_name < b_definition.display_name
	)
	return result


func _matches_stash_subfilter(definition: ItemDefinition) -> bool:
	if stash_subfilter == "all":
		return true
	if definition.item_type == ItemDefinition.ItemType.WEAPON:
		if stash_subfilter == "magic": return definition.weapon_family == &"magic"
		var melee := definition.weapon_family in [&"katana", &"nodachi", &"sword"]
		return melee if stash_subfilter == "melee" else not melee and definition.weapon_family != &"magic"
	if definition.item_type == ItemDefinition.ItemType.GEAR:
		return definition.get_gear_slot_name().to_lower() == stash_subfilter
	return true


func _matches_stash_search(definition: ItemDefinition, instance: ItemInstance) -> bool:
	if stash_search.is_empty():
		return true
	var query := stash_search.to_lower()
	var haystack := "%s %s %s" % [definition.display_name, definition.get_type_name(), String(definition.weapon_family).replace("_", " ")]
	for affix_id: StringName in instance.affix_ids:
		var affix := AffixDatabase.get_definition(affix_id)
		if affix != null:
			haystack += " " + affix.display_name
	return haystack.to_lower().contains(query)


func _inventory_free_slots() -> int:
	var free := 0
	for slot: int in PlayerProfile.main_inventory.size():
		if PlayerProfile.get_inventory_instance(slot) == null:
			free += 1
	return free


func _is_instance_equipped(instance_id: String) -> bool:
	return PlayerProfile.weapon_instance_slots.has(instance_id) or PlayerProfile.equipped_gear_instances.values().has(instance_id)


func _add_menu_button(parent: Control, text: String, callable: Callable, danger: bool = false) -> void:
	var button := _button(parent, "//  " + text, danger)
	button.custom_minimum_size.y = 46
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callable)


func _add_back_button(parent: Control) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var back := _button(row, "BACK", false)
	back.set_meta("audio_event", &"ui_back")
	back.custom_minimum_size = Vector2(150, 42)
	back.pressed.connect(_show_main)


func _activity_card(parent: Control, title: String, subtitle: String, enabled: bool) -> Button:
	var card := _button(parent, "%s\n\n%s" % [title, subtitle], false)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.disabled = not enabled
	card.add_theme_font_size_override("font_size", 20)
	return card


func _build_character_placeholder(parent: Control) -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(430, 500)
	parent.add_child(stage)
	var viewport_container := SubViewportContainer.new()
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(viewport_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(620, 680)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.78
	pedestal_mesh.bottom_radius = 0.94
	pedestal_mesh.height = 0.13
	pedestal_mesh.radial_segments = 32
	pedestal_mesh.material = PlaceholderParts.material(Color(0.04, 0.06, 0.07), 0.72)
	pedestal.mesh = pedestal_mesh
	pedestal.position = Vector3(0.0, -0.02, 0.0)
	world.add_child(pedestal)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.83
	ring_mesh.outer_radius = 0.88
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 8
	ring_mesh.material = PlaceholderParts.material(COLOR_ACCENT, 0.0, true)
	ring.mesh = ring_mesh
	ring.position.y = 0.055
	world.add_child(ring)
	operative_preview = MeshInstance3D.new()
	operative_preview.name = "OperativePreviewModel"
	operative_preview.set_script(HUMANOID_VISUAL_SCRIPT)
	operative_preview.set("accent", COLOR_ACCENT)
	operative_preview.set("show_preview_weapon", true)
	operative_preview.position = Vector3(0.0, 0.91, 0.0)
	operative_preview.rotation.y = -0.24
	world.add_child(operative_preview)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key_light.light_color = Color(0.70, 0.88, 1.0)
	key_light.light_energy = 2.5
	key_light.shadow_enabled = true
	world.add_child(key_light)
	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(-1.6, 1.6, 0.9)
	rim_light.light_color = COLOR_ACCENT
	rim_light.light_energy = 5.0
	rim_light.omni_range = 4.5
	world.add_child(rim_light)
	var warm_light := OmniLight3D.new()
	warm_light.position = Vector3(1.8, 1.1, -1.0)
	warm_light.light_color = COLOR_YELLOW
	warm_light.light_energy = 2.2
	warm_light.omni_range = 4.0
	world.add_child(warm_light)
	var camera := Camera3D.new()
	camera.position = Vector3(2.55, 1.45, -4.8)
	camera.fov = 34.0
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 0.93, 0.0), Vector3.UP)
	var tag := _label(stage, "OPERATIVE // EF-01", 12, COLOR_YELLOW)
	tag.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tag.offset_left = 16
	tag.offset_top = 14
	tag.offset_right = 250
	tag.offset_bottom = 42
	var status := _label(stage, "COMBAT READY", 12, COLOR_READY)
	status.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	status.offset_left = -190
	status.offset_right = -16
	status.offset_top = -42
	status.offset_bottom = -14
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return stage


func _run_profile_self_test() -> void:
	print("PROFILE_TEST_START")
	var failures: Array[String] = []
	var snapshot := PlayerProfile.to_save_data()
	var test_path := "user://extraction_fighter_profile_test.json"
	for stale_path: String in [test_path, test_path + ".backup", test_path + ".tmp"]:
		if FileAccess.file_exists(stale_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(stale_path))
	PlayerProfile.reset_to_defaults(false)
	if PlayerProfile.get_skill_power() != 130 or not bool(PlayerProfile.validate_loadout().valid):
		failures.append("Default loadout or 130 Power calculation failed")
	if PlayerProfile.main_inventory.size() != 24:
		failures.append("Main inventory does not contain 24 persistent slots")
	if PlayerProfile.gold != 120 or PlayerProfile.owned_item_ids.size() != PlayerProfile.STARTER_ITEM_IDS.size() or PlayerProfile.owned_item_instances.size() != PlayerProfile.STARTER_ITEM_IDS.size() + 1:
		failures.append("Normal profile did not contain only the intended starter kit and small gold grant")
	if PlayerProfile.get_owned_definitions(ItemDefinition.ItemType.WEAPON).size() != 2 or PlayerProfile.get_owned_definitions(ItemDefinition.ItemType.SKILL).size() != 2:
		failures.append("Starter weapon/skill counts are invalid")
	if PlayerProfile.equip_gear("helmet", "simple_ring", false):
		failures.append("Gear compatibility allowed a ring in the helmet slot")
	PlayerProfile.create_development_profile()
	var validation_fixture := PlayerProfile.to_save_data()
	var unknown_id_save := validation_fixture.duplicate(true)
	(unknown_id_save["owned_item_ids"] as Array).append("unknown_definition")
	if bool(PlayerProfile._validate_save_payload(unknown_id_save).get("valid", false)):
		failures.append("Save validator accepted an unknown item definition")
	var duplicate_instance_save := validation_fixture.duplicate(true)
	(duplicate_instance_save["owned_item_instances"] as Array).append((duplicate_instance_save["owned_item_instances"] as Array)[0].duplicate(true))
	if bool(PlayerProfile._validate_save_payload(duplicate_instance_save).get("valid", false)):
		failures.append("Save validator accepted a duplicate instance ID")
	var invalid_value_save := validation_fixture.duplicate(true)
	(invalid_value_save["owned_item_instances"] as Array)[0]["current_durability"] = -5.0
	if bool(PlayerProfile._validate_save_payload(invalid_value_save).get("valid", false)):
		failures.append("Save validator accepted invalid durability")
	var invalid_slot_save := validation_fixture.duplicate(true)
	(invalid_slot_save["weapon_instance_slots"] as Array)[0] = "missing:instance"
	if bool(PlayerProfile._validate_save_payload(invalid_slot_save).get("valid", false)):
		failures.append("Save validator accepted an invalid slot reference")
	PlayerProfile.set_inventory_item(0, PlayerProfile.get_instance_for_definition("void_charm").instance_id, false)
	PlayerProfile.equip_skill(1, "blink", false)
	if PlayerProfile.get_skill_power() != 170:
		failures.append("Dash + Blink should be allowed at 170 Power")
	if PlayerProfile.can_afford_skill_costs([110, 140]):
		failures.append("Power validator accepted a 250 Power combination")
	var over_limit_skill := ItemDefinition.new()
	over_limit_skill.id = &"test_over_limit"
	over_limit_skill.display_name = "Test Over Limit"
	over_limit_skill.item_type = ItemDefinition.ItemType.SKILL
	over_limit_skill.power_cost = 140
	PlayerProfile.item_index["test_over_limit"] = over_limit_skill
	PlayerProfile.owned_item_ids.append("test_over_limit")
	var skills_before_rejection := PlayerProfile.skill_slots.duplicate()
	if PlayerProfile.equip_skill(0, "test_over_limit", false) or PlayerProfile.last_error != "POWER LIMIT EXCEEDED" or PlayerProfile.skill_slots != skills_before_rejection:
		failures.append("Equip path did not explicitly reject and preserve a >200 Power loadout")
	PlayerProfile.item_index.erase("test_over_limit")
	PlayerProfile.owned_item_ids.erase("test_over_limit")
	var transfer_weapon := PlayerProfile.get_instance_for_definition("rushfang")
	var stash_payload := {"instance_id": transfer_weapon.instance_id, "origin_kind": "stash", "origin_key": ""}
	if not PlayerProfile.transfer_item(stash_payload, "inventory", 1, false) or PlayerProfile.get_inventory_instance(1) != transfer_weapon:
		failures.append("Stash to inventory did not preserve the exact ItemInstance")
	var inventory_payload := {"instance_id": transfer_weapon.instance_id, "origin_kind": "inventory", "origin_key": 1}
	if not PlayerProfile.transfer_item(inventory_payload, "inventory", 2, false) or PlayerProfile.get_inventory_instance(2) != transfer_weapon or PlayerProfile.get_inventory_instance(1) != null:
		failures.append("Inventory drag did not move the exact instance atomically")
	inventory_payload["origin_key"] = 2
	if not PlayerProfile.transfer_item(inventory_payload, "loadout_weapon", 0, false) or PlayerProfile.get_weapon_instance(0) != transfer_weapon or PlayerProfile.get_inventory_instance(2) != null:
		failures.append("Inventory to loadout did not preserve identity or clear the source")
	var weapon_payload := {"instance_id": transfer_weapon.instance_id, "origin_kind": "loadout_weapon", "origin_key": 0}
	if not PlayerProfile.unequip_to_storage("loadout_weapon", 0, true, false) or PlayerProfile.find_inventory_slot(transfer_weapon.instance_id) < 0:
		failures.append("Quick unequip did not move the exact instance to a free inventory slot")
	var charm_instance := PlayerProfile.get_inventory_instance(0)
	var invalid_payload := {"instance_id": charm_instance.instance_id, "origin_kind": "inventory", "origin_key": 0}
	var inventory_before_invalid := PlayerProfile.main_inventory.duplicate()
	if PlayerProfile.transfer_item(invalid_payload, "loadout_gear", "helmet", false) or PlayerProfile.main_inventory != inventory_before_invalid:
		failures.append("Invalid gear drop was not rejected without mutation")
	if PlayerProfile._instance_reference_count(transfer_weapon.instance_id) > 1:
		failures.append("Transfer operations created duplicate item references")
	_configure_integration_loadout()
	if PlayerProfile.get_skill_power() != 200 or not bool(PlayerProfile.validate_loadout().valid):
		failures.append("Grapple + Blink should be valid at exactly 200 Power")
	var sale_a := ItemInstance.create(PlayerProfile.get_definition("rusty_katana"), "test:sale:a")
	var sale_b := ItemInstance.create(PlayerProfile.get_definition("rusty_katana"), "test:sale:b")
	PlayerProfile.add_owned_instance(sale_a, false)
	PlayerProfile.add_owned_instance(sale_b, false)
	var gold_before_sale := PlayerProfile.gold
	var sale_value := PlayerProfile.get_sell_value(sale_a)
	if not PlayerProfile.sell_instance(sale_a.instance_id, false) or PlayerProfile.gold != gold_before_sale + sale_value or PlayerProfile.get_instance(sale_b.instance_id) == null or PlayerProfile.sell_instance(sale_a.instance_id, false):
		failures.append("Selling did not destroy exactly one selected duplicate exactly once")
	var scrap_before := PlayerProfile.scrap
	var scrap_yield := PlayerProfile.get_dismantle_yield(sale_b)
	if not PlayerProfile.dismantle_instance(sale_b.instance_id, false) or PlayerProfile.scrap != scrap_before + scrap_yield or PlayerProfile.dismantle_instance(sale_b.instance_id, false):
		failures.append("Dismantling did not grant Scrap and destroy the exact instance once")
	var filler_serial := 0
	while PlayerProfile.get_stash_count() < PlayerProfile.STASH_CAPACITY:
		var filler := ItemInstance.create(PlayerProfile.get_definition("armory_scrap"), "test:filler:%d" % filler_serial)
		filler_serial += 1
		PlayerProfile.add_owned_instance(filler, false)
	var overflow_item := AffixRoller.roll_item(PlayerProfile.get_definition("vanguard_rifle"), 44551, "test:overflow:exact")
	overflow_item.current_durability = 47.0
	if PlayerProfile.secure_extracted_instance(overflow_item, false) != "overflow" or PlayerProfile.get_pending_instances().back() != overflow_item:
		failures.append("Full stash did not preserve the exact extracted instance in Overflow")
	var overflow_payload := {"instance_id": overflow_item.instance_id, "origin_kind": "overflow", "origin_key": overflow_item.instance_id}
	if PlayerProfile.transfer_item(overflow_payload, "stash", "", false) or PlayerProfile.transfer_item(overflow_payload, "loadout_weapon", 0, false) or PlayerProfile.get_instance(overflow_item.instance_id) != overflow_item:
		failures.append("Full-stash transfer displaced or deleted an Overflow item instead of rejecting atomically")
	if not PlayerProfile.save_profile(test_path):
		failures.append("Temporary profile save failed")
	PlayerProfile.add_gold(1)
	if not PlayerProfile.save_profile(test_path) or not FileAccess.file_exists(test_path + ".backup"):
		failures.append("Verified save did not create a backup before replacement")
	PlayerProfile.reset_to_defaults(false)
	if not PlayerProfile.load_profile(test_path, false) or PlayerProfile.weapon_slots != ["vanguard_rifle", "knight_sword"] or PlayerProfile.skill_slots != ["grapple", "blink"] or PlayerProfile.main_inventory[0] != "dev:void_charm" or PlayerProfile.get_instance("test:overflow:exact") == null or not is_equal_approx(PlayerProfile.get_instance("test:overflow:exact").current_durability, 47.0):
		failures.append("Save/load round trip did not retain selected loadout")
	var corrupt := FileAccess.open(test_path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("{ this is not valid json")
	corrupt = null
	if not PlayerProfile.load_profile(test_path, false) or not PlayerProfile.last_load_recovered_backup or PlayerProfile.weapon_slots != ["vanguard_rifle", "knight_sword"]:
		failures.append("Corrupt primary did not recover the verified backup")
	corrupt = FileAccess.open(test_path, FileAccess.WRITE)
	if corrupt != null: corrupt.store_string("broken primary")
	corrupt = FileAccess.open(test_path + ".backup", FileAccess.WRITE)
	if corrupt != null: corrupt.store_string("broken backup")
	corrupt = null
	if PlayerProfile.load_profile(test_path, false) or not PlayerProfile.last_load_used_defaults or PlayerProfile.gold != 120:
		failures.append("Dual corruption did not fall back to the starter profile")
	var absolute_test_path := ProjectSettings.globalize_path(test_path)
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(absolute_test_path)
	if FileAccess.file_exists(test_path + ".backup"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + ".backup"))
	if not PlayerProfile.load_profile(test_path, true) or not PlayerProfile.last_load_used_defaults or not FileAccess.file_exists(test_path):
		failures.append("Missing save did not create a default profile")
	PlayerProfile.apply_save_data(snapshot)
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(absolute_test_path)
	if FileAccess.file_exists(test_path + ".backup"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + ".backup"))
	if failures.is_empty():
		print("PROFILE_TEST_OK: starter profile, 24 slots, atomic transfers, Power limits, verified save, backup recovery and fresh fallback passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("PROFILE_TEST_FAILURE: " + failure)
		get_tree().quit(1)


func _run_settings_self_test() -> void:
	var failures: Array[String] = []
	var snapshot := GameSettings.to_dictionary()
	var test_path := "user://extraction_fighter_settings_test.json"
	GameSettings.reset_defaults(false)
	if GameSettings.get_binding_text(&"skill_slot_1") != "Q" or GameSettings.get_binding_text(&"skill_slot_2") != "E" or GameSettings.get_binding_text(&"peek_left") != "3" or GameSettings.get_binding_text(&"peek_right") != "4":
		failures.append("Canonical defaults are not Q/E skills and 3/4 peek")
	var legacy_settings := GameSettings.to_dictionary()
	legacy_settings["save_version"] = 1
	var legacy_keybinds := (legacy_settings["keybinds"] as Dictionary).duplicate(true)
	for pair: Array in [["skill_slot_1", KEY_3], ["skill_slot_2", KEY_4], ["peek_left", KEY_Q], ["peek_right", KEY_E]]:
		var legacy_event := InputEventKey.new()
		legacy_event.physical_keycode = pair[1]
		legacy_keybinds[pair[0]] = [GameSettings._serialize_input_event(legacy_event)]
	legacy_settings["keybinds"] = legacy_keybinds
	if not GameSettings.apply_dictionary(legacy_settings) or GameSettings.get_binding_text(&"skill_slot_1") != "Q" or GameSettings.get_binding_text(&"peek_left") != "3":
		failures.append("Version-1 3/4-skill Q/E-peek layout did not migrate to canonical controls")
	var test_binding := InputEventKey.new()
	test_binding.physical_keycode = KEY_Z
	GameSettings.set_binding(&"move_forward", test_binding, false)
	GameSettings.set_value(&"base_fov", 104.0, false)
	GameSettings.set_value(&"mouse_sensitivity", 0.0034, false)
	GameSettings.set_value(&"damage_numbers", false, false)
	GameSettings.set_value(&"hit_effects_intensity", 0.35, false)
	GameSettings.set_value(&"headbob_strength", 0.2, false)
	GameSettings.set_value(&"resolution", Vector2i(1920, 1080), false)
	if not GameSettings.save_settings(test_path):
		failures.append("Settings save failed")
	GameSettings.reset_defaults(false)
	if not GameSettings.load_settings(test_path, false):
		failures.append("Settings load failed")
	if not is_equal_approx(GameSettings.base_fov, 104.0) or not is_equal_approx(GameSettings.mouse_sensitivity, 0.0034) or GameSettings.damage_numbers or not is_equal_approx(GameSettings.hit_effects_intensity, 0.35) or GameSettings.resolution != Vector2i(1920, 1080):
		failures.append("Settings round trip changed persisted values")
	var loaded_forward := InputMap.action_get_events(&"move_forward")
	if loaded_forward.is_empty() or not loaded_forward[0] is InputEventKey or (loaded_forward[0] as InputEventKey).physical_keycode != KEY_Z:
		failures.append("Custom keybind did not survive settings round trip")
	var corrupt := FileAccess.open(test_path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("{ invalid settings")
	corrupt = null
	if GameSettings.load_settings(test_path, true) or not FileAccess.file_exists(test_path) or not is_equal_approx(GameSettings.base_fov, 90.0):
		failures.append("Corrupt settings did not recover to persisted defaults")
	GameSettings.apply_dictionary(snapshot)
	GameSettings.save_settings()
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	_show_settings()
	await get_tree().process_frame
	if screen_host.find_child("SettingsRoot", true, false) == null:
		failures.append("Settings UI did not instantiate")
	_show_keybinds()
	await get_tree().process_frame
	if screen_host.find_child("KeybindsScroll", true, false) == null:
		failures.append("Keybind editor did not instantiate")
	if failures.is_empty():
		print("SETTINGS_TEST_OK: video, gameplay, audio, keybind persistence and corrupt-save fallback passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("SETTINGS_TEST_FAILURE: " + failure)
		get_tree().quit(1)


func _run_loot_statistics_test() -> void:
	var failures: Array[String] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x4032026
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	var compatibility_failures := 0
	const SAMPLE_COUNT := 10000
	for index: int in SAMPLE_COUNT:
		var instance := LootTableService.roll_instance(rng, "ordinary", "", 0, 0, "stats:%d" % index)
		if instance == null:
			failures.append("Ordinary loot roll returned no item")
			break
		var definition := PlayerProfile.get_definition(String(instance.definition_id))
		if definition.rarity < ItemDefinition.Rarity.COMMON or definition.rarity > ItemDefinition.Rarity.MYTHIC:
			failures.append("Ordinary table emitted a source-exclusive rarity")
			break
		counts[definition.rarity] += 1
		if not AffixRoller.validate_instance(instance, definition).is_empty():
			compatibility_failures += 1
	var tolerance: Array[float] = [2.0, 1.8, 1.4, 0.9, 0.55, 0.35]
	for rarity: int in counts.size():
		var observed := float(counts[rarity]) * 100.0 / float(SAMPLE_COUNT)
		if absf(observed - LootTableService.BASE_RARITY_WEIGHTS[rarity]) > tolerance[rarity]:
			failures.append("%s observed %.2f%% outside tolerance" % [ItemDefinition.Rarity.keys()[rarity], observed])
	if compatibility_failures > 0:
		failures.append("%d rolled items had incompatible or duplicate affixes" % compatibility_failures)
	for index: int in 2000:
		var boss := LootTableService.roll_instance(rng, "boss", "boss", 4, 0, "boss-stats:%d" % index)
		var definition := PlayerProfile.get_definition(String(boss.definition_id)) if boss != null else null
		if definition == null or definition.rarity < ItemDefinition.Rarity.RARE:
			failures.append("Boss table violated its guaranteed Rare+ floor")
			break
	var key := PlayerProfile.get_definition("extraction_key")
	if key == null or key.rarity != ItemDefinition.Rarity.UNIQUE or not LootTableService.UNIQUE_SOURCE_ITEMS.has("extraction_key"):
		failures.append("Unique Extraction Key is not isolated to its source-specific rule")
	var report_parts: Array[String] = []
	for rarity: int in counts.size():
		report_parts.append("%s %.2f%%" % [ItemDefinition.Rarity.keys()[rarity], float(counts[rarity]) * 100.0 / float(SAMPLE_COUNT)])
	if failures.is_empty():
		print("LOOT_STATISTICS_OK: 10,000 ordinary rolls = %s; affix compatibility 100%%; 2,000 boss rolls respected Rare+ floor" % ", ".join(report_parts))
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("LOOT_STATISTICS_FAILURE: " + failure)
		get_tree().quit(1)


func _run_content_self_test() -> void:
	print("CONTENT_TEST_START")
	var failures: Array[String] = []
	var snapshot := PlayerProfile.to_save_data()
	PlayerProfile.create_development_profile()
	var expected_weapons: Array[String] = ["ronin_katana", "war_nodachi", "huntsman_rifle", "vanguard_rifle", "falcon_burst", "ironclad_rifle", "knight_sword", "arcane_wand", "service_glock", "twin_glock"]
	var expected_skills: Array[String] = ["dash", "double_jump", "grapple", "blink", "wallrun", "air_dash", "launch", "ground_slam", "invisibility", "smoke_veil"]
	for item_id: String in expected_weapons:
		var definition := PlayerProfile.get_definition(item_id)
		if definition == null or definition.item_type != ItemDefinition.ItemType.WEAPON or definition.gameplay_scene == null:
			failures.append("Missing weapon definition or scene: " + item_id)
			continue
		var instance := definition.gameplay_scene.instantiate()
		if not instance is WeaponBase:
			failures.append("Weapon scene does not instantiate WeaponBase: " + item_id)
		instance.free()
	var visual_signatures: Dictionary = {}
	var tested_weapon_count := 0
	var scoped_families: Array[StringName] = [&"sniper", &"assault_rifle", &"burst_rifle", &"battle_rifle"]
	for definition: ItemDefinition in ItemDatabase.DEFINITIONS:
		if definition.item_type != ItemDefinition.ItemType.WEAPON:
			continue
		tested_weapon_count += 1
		var weapon := definition.gameplay_scene.instantiate() as WeaponBase
		if weapon == null:
			continue
		add_child(weapon)
		weapon.configure_from_item(definition, ItemInstance.create(definition, "visual-test:%s" % definition.id))
		var visual: Node = null
		for child: Node in weapon.get_children():
			if child.has_method("configure_variant"):
				visual = child
				break
		var generated: Node = visual.get("generated_root") if visual != null else null
		if generated == null or String(generated.get_meta("variant_id", "")) != String(definition.id):
			failures.append("Missing unique generated model: %s" % definition.id)
		else:
			var family := String(definition.weapon_family)
			if not visual_signatures.has(family):
				visual_signatures[family] = []
			(visual_signatures[family] as Array).append(int(generated.get_meta("part_count", 0)))
			if definition.weapon_family in scoped_families and (not bool(generated.get_meta("has_scope", false)) or not bool(generated.get_meta("has_sight", false))):
				failures.append("Rifle variant lacks scope or backup sight: %s" % definition.id)
		remove_child(weapon)
		weapon.free()
	if tested_weapon_count != 30:
		failures.append("Expected 30 generated weapon variants, got %d" % tested_weapon_count)
	for family: String in visual_signatures:
		var signatures := visual_signatures[family] as Array
		if signatures.size() != 3 or signatures[0] == signatures[1] or signatures[1] == signatures[2] or signatures[0] == signatures[2]:
			failures.append("Weapon variants do not have three distinct silhouettes: %s %s" % [family, str(signatures)])
	for item_id: String in expected_skills:
		var definition := PlayerProfile.get_definition(item_id)
		if definition == null or definition.item_type != ItemDefinition.ItemType.SKILL or definition.gameplay_scene == null:
			failures.append("Missing skill definition or scene: " + item_id)
			continue
		var instance := definition.gameplay_scene.instantiate()
		if not instance is SkillBase:
			failures.append("Skill scene does not instantiate SkillBase: " + item_id)
		instance.free()
	if PlayerProfile.get_owned_definitions(ItemDefinition.ItemType.GEAR).size() != 27:
		failures.append("Expected 27 development gear definitions")
	PlayerProfile.equip_skill(0, "invisibility", false)
	PlayerProfile.equip_skill(1, "air_dash", false)
	if PlayerProfile.get_skill_power() != 200:
		failures.append("Invisibility + Air Dash should total exactly 200 Power")
	var before_rejected := PlayerProfile.skill_slots.duplicate()
	if PlayerProfile.equip_skill(1, "blink", false) or PlayerProfile.skill_slots != before_rejected:
		failures.append("230 Power loadout was not rejected atomically")
	PlayerProfile.equip_skill(0, "wallrun", false)
	PlayerProfile.equip_skill(1, "smoke_veil", false)
	if PlayerProfile.get_skill_power() != 140:
		failures.append("Wallrun + Smoke Veil should total 140 Power")
	var old_save := PlayerProfile.to_save_data()
	old_save["weapon_slots"] = ["ronin_katana", "huntsman_rifle"]
	old_save["skill_slots"] = ["dash", "double_jump"]
	old_save["owned_item_ids"] = ["ronin_katana", "huntsman_rifle", "dash", "double_jump", "training_helmet", "training_chest", "training_gloves", "training_boots", "simple_necklace", "simple_ring", "iron_ring", "basic_charm"]
	old_save["save_version"] = 4
	old_save.erase("pending_reward_instances")
	old_save.erase("scrap")
	old_save.erase("training_best_time_ms")
	var legacy_instances: Array = []
	for entry: Dictionary in old_save.get("owned_item_instances", []):
		if String(entry.get("definition_id", "")) in old_save["owned_item_ids"]:
			legacy_instances.append(entry)
	old_save["owned_item_instances"] = legacy_instances
	if not PlayerProfile.apply_save_data(old_save, false) or not PlayerProfile.catalog_migrated_last_load or PlayerProfile.owned_item_ids.has("rushfang"):
		failures.append("Legacy profile migration injected development catalog items")
	if PlayerProfile.weapon_slots != ["ronin_katana", "huntsman_rifle"] or PlayerProfile.skill_slots != ["dash", "double_jump"]:
		failures.append("Legacy profile migration did not preserve selected loadout")
	PlayerProfile.apply_save_data(snapshot, false)
	if failures.is_empty():
		print("CONTENT_TEST_OK: 30 distinct weapon models, rifle optics, 10 skills, 27 gear items, Power rules, gameplay scenes and non-destructive save migration passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("CONTENT_TEST_FAILURE: " + failure)
		get_tree().quit(1)


func _run_tooltip_self_test() -> void:
	print("TOOLTIP_TEST_START")
	var failures: Array[String] = []
	var snapshot := PlayerProfile.to_save_data()
	PlayerProfile.create_development_profile()
	PlayerProfile.set_inventory_item(0, "war_nodachi", false)
	_show_stash()
	await get_tree().process_frame
	await get_tree().process_frame
	var inventory_slot := find_child("InventorySlot0", true, false) as Control
	if inventory_slot == null or not inventory_slot.mouse_entered.has_connections() or not inventory_slot.mouse_exited.has_connections():
		failures.append("Main inventory item is not connected to the reusable tooltip")
	var katana := PlayerProfile.get_definition("ronin_katana")
	item_tooltip.show_item(katana)
	await get_tree().process_frame
	if not item_tooltip.visible or item_tooltip.name_label.text != "RONIN KATANA" or item_tooltip.rarity_label.text != "RARE" or item_tooltip.flavor_label.text.is_empty():
		failures.append("Weapon tooltip omitted identity, rarity or flavor")
	if not item_tooltip.get_stats_text().contains("Damage") or item_tooltip.get_stats_text().contains("Magazine"):
		failures.append("Melee tooltip relevant-field filtering failed")
	item_tooltip.show_item(PlayerProfile.get_definition("huntsman_rifle"))
	await get_tree().process_frame
	if not item_tooltip.get_stats_text().contains("Magazine") or not item_tooltip.get_stats_text().contains("Headshot"):
		failures.append("Ranged tooltip omitted magazine or headshot data")
	if not item_tooltip.weapon_preview_container.visible or item_tooltip.weapon_preview_model == null:
		failures.append("Weapon tooltip did not render the selected 3D weapon model")
	item_tooltip.show_item(PlayerProfile.get_definition("grapple"))
	await get_tree().process_frame
	if not item_tooltip.get_stats_text().contains("Power") or not item_tooltip.get_stats_text().contains("Cooldown") or not item_tooltip.get_stats_text().contains("ACTIVATION"):
		failures.append("Skill tooltip omitted Power, cooldown or activation")
	item_tooltip.show_item(PlayerProfile.get_definition("void_crown"))
	await get_tree().process_frame
	if not item_tooltip.get_stats_text().contains("Slot") or not item_tooltip.get_stats_text().contains("Armor"):
		failures.append("Gear tooltip omitted slot or armor")
	if item_tooltip.preview_glyph == null or not item_tooltip.preview_glyph.visible:
		failures.append("Generated placeholder preview is not visible")
	var comparison_candidate := PlayerProfile.get_definition("rushfang")
	var comparison_equipped := PlayerProfile.get_definition("vanguard_rifle")
	item_tooltip.show_item(comparison_candidate, PlayerProfile.get_instance_for_definition("rushfang"), comparison_equipped, PlayerProfile.get_instance_for_definition("vanguard_rifle"))
	await get_tree().process_frame
	if not item_tooltip.comparison_label.visible or not item_tooltip.comparison_label.text.contains("COMPARISON") or not item_tooltip.comparison_label.text.contains("Reload"):
		failures.append("Direction-aware weapon comparison did not render")
	var previewed_weapon_count := 0
	for definition: ItemDefinition in ItemDatabase.DEFINITIONS:
		if definition.item_type != ItemDefinition.ItemType.WEAPON:
			continue
		item_tooltip.show_item(definition)
		await get_tree().process_frame
		previewed_weapon_count += 1
		if not item_tooltip.weapon_preview_container.visible or item_tooltip.weapon_preview_model == null:
			failures.append("Missing 3D tooltip preview for %s" % String(definition.id))
	if previewed_weapon_count != 30:
		failures.append("Expected 30 weapon tooltip previews, got %d" % previewed_weapon_count)
	for test_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		get_window().size = test_size
		await get_tree().process_frame
		var result_position := item_tooltip.reposition_for_test(Vector2(test_size) - Vector2(2, 2), Vector2(test_size))
		var rect := Rect2(result_position, item_tooltip.size.max(item_tooltip.custom_minimum_size))
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > test_size.x or rect.end.y > test_size.y:
			failures.append("Tooltip escaped %dx%d viewport" % [test_size.x, test_size.y])
	item_tooltip.hide_item()
	if item_tooltip.visible:
		failures.append("Tooltip did not disappear")
	PlayerProfile.apply_save_data(snapshot, false)
	if failures.is_empty():
		print("TOOLTIP_TEST_OK: reusable weapon/skill/gear previews, filtering, inventory hover, hide and viewport clamping passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("TOOLTIP_TEST_FAILURE: " + failure)
		get_tree().quit(1)


func _run_inventory_ui_test() -> void:
	print("INVENTORY_UI_TEST_START")
	var failures: Array[String] = []
	var snapshot := PlayerProfile.to_save_data()
	PlayerProfile.create_development_profile()
	_show_stash()
	await get_tree().process_frame
	await get_tree().process_frame
	var inventory_slots := find_children("InventorySlot*", "InventoryItemSlot", true, false)
	if inventory_slots.size() != PlayerProfile.INVENTORY_SIZE:
		failures.append("Inventory grid did not create exactly 24 reusable slots")
	stash_filter = ItemDefinition.ItemType.WEAPON
	stash_subfilter = "ranged"
	stash_search = "fast reload"
	var search_results := _get_sorted_stash_instances()
	if search_results.is_empty():
		failures.append("Affix-name search returned no ranged weapon")
	else:
		for instance: ItemInstance in search_results:
			if not _matches_stash_search(PlayerProfile.get_definition(String(instance.definition_id)), instance):
				failures.append("Search returned an item that did not match")
	var owned_before_sort: Array[String] = []
	for instance: ItemInstance in PlayerProfile.owned_item_instances: owned_before_sort.append(instance.instance_id)
	for sort_mode: int in 5:
		stash_sort = sort_mode
		_get_sorted_stash_instances()
	var owned_after_sort: Array[String] = []
	for instance: ItemInstance in PlayerProfile.owned_item_instances: owned_after_sort.append(instance.instance_id)
	if owned_before_sort != owned_after_sort:
		failures.append("Sorting modified item ownership or identity")
	var broken := PlayerProfile.get_instance_for_definition("vanguard_rifle")
	broken.current_durability = 0.0
	if PlayerProfile.quick_equip_instance(broken.instance_id, false) or PlayerProfile.last_error != "ITEM BROKEN":
		failures.append("Broken item quick-equip was not explicitly rejected")
	var repair_cost := DurabilityService.repair_cost(broken, PlayerProfile.get_definition(String(broken.definition_id)))
	PlayerProfile.gold = repair_cost
	if not PlayerProfile.repair_instance(broken.instance_id, false) or broken.is_broken() or PlayerProfile.gold != 0:
		failures.append("Single-item repair did not charge the displayed price")
	var equipped_weapon := PlayerProfile.get_weapon_instance(0)
	equipped_weapon.current_durability *= 0.5
	var equipped_cost := PlayerProfile.get_equipped_repair_cost()
	PlayerProfile.gold = equipped_cost
	if not PlayerProfile.repair_all_equipped(false) or PlayerProfile.gold != 0:
		failures.append("Repair Equipped failed")
	var damaged_one := PlayerProfile.get_instance_for_definition("rusted_helmet")
	var damaged_two := PlayerProfile.get_instance_for_definition("chipped_sword")
	damaged_one.current_durability *= 0.6
	damaged_two.current_durability *= 0.7
	var all_cost := PlayerProfile.get_all_damaged_repair_cost()
	PlayerProfile.gold = all_cost
	if not PlayerProfile.repair_all_damaged(false) or PlayerProfile.gold != 0 or damaged_one.current_durability != damaged_one.max_durability or damaged_two.current_durability != damaged_two.max_durability:
		failures.append("Repair All Damaged failed or charged the wrong total")
	PlayerProfile.apply_save_data(snapshot, false)
	if failures.is_empty():
		print("INVENTORY_UI_TEST_OK: 24 slots, filters, affix search, identity-safe sorting, broken rejection and all repair paths passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("INVENTORY_UI_TEST_FAILURE: " + failure)
		get_tree().quit(1)


func _run_affix_self_test() -> void:
	print("AFFIX_TEST_START")
	var failures: Array[String] = []
	var affixes := AffixDatabase.all()
	if affixes.size() != 50:
		failures.append("Expected exactly 50 affix definitions, got %d" % affixes.size())
	var unique_ids: Dictionary = {}
	for affix: AffixDefinition in affixes:
		if unique_ids.has(affix.id): failures.append("Duplicate affix definition: " + String(affix.id))
		unique_ids[affix.id] = true
		if affix.tier_values.size() != 3: failures.append("Affix does not expose three tiers: " + String(affix.id))
	var family_counts: Dictionary = {}
	var family_rarities: Dictionary = {}
	var weapon_count := 0
	var mythic_count := 0
	for definition: ItemDefinition in ItemDatabase.DEFINITIONS:
		if definition.item_type != ItemDefinition.ItemType.WEAPON:
			continue
		weapon_count += 1
		var family := String(definition.weapon_family)
		family_counts[family] = int(family_counts.get(family, 0)) + 1
		if not family_rarities.has(family): family_rarities[family] = {}
		(family_rarities[family] as Dictionary)[definition.rarity] = true
		var dev_instance := ItemInstance.create(definition)
		failures.append_array(AffixRoller.validate_instance(dev_instance, definition))
		if definition.gameplay_scene == null:
			failures.append("Variant has no gameplay scene: " + String(definition.id))
		else:
			var runtime_weapon := definition.gameplay_scene.instantiate() as WeaponBase
			if runtime_weapon == null:
				failures.append("Variant scene is not WeaponBase: " + String(definition.id))
			else:
				add_child(runtime_weapon)
				runtime_weapon.configure_from_item(definition, dev_instance)
				if runtime_weapon.item_definition != definition or runtime_weapon.weapon_display_name != definition.display_name:
					failures.append("Variant did not configure its family runtime: " + String(definition.id))
				runtime_weapon.free()
		if definition.rarity == ItemDefinition.Rarity.MYTHIC:
			mythic_count += 1
			if definition.special_effect_id == &"" or definition.special_description.is_empty():
				failures.append("Mythic lacks a real unique identity: " + String(definition.id))
	if weapon_count != 30 or family_counts.size() != 10 or mythic_count != 10:
		failures.append("Variant roster must contain 30 weapons, 10 families and 10 mythics")
	for family: Variant in family_counts:
		var rarities: Dictionary = family_rarities[family]
		if int(family_counts[family]) != 3 or not rarities.has(ItemDefinition.Rarity.COMMON) or not rarities.has(ItemDefinition.Rarity.RARE) or not rarities.has(ItemDefinition.Rarity.MYTHIC):
			failures.append("Family does not contain Common/Rare/Mythic: " + String(family))
	var rifle := PlayerProfile.get_definition("vanguard_rifle")
	var roll_a := AffixRoller.roll_item(rifle, 42021, "test:roll")
	var roll_b := AffixRoller.roll_item(rifle, 42021, "test:roll")
	if roll_a.affix_ids != roll_b.affix_ids or roll_a.affix_tiers != roll_b.affix_tiers:
		failures.append("Seeded affix rolling is not deterministic")
	if not AffixRoller.validate_instance(roll_a, rifle).is_empty():
		failures.append("Rolled rifle contains duplicates, invalid tiers, or incompatible affixes")
	var round_trip := ItemInstance.from_dictionary(roll_a.to_dictionary())
	if round_trip.instance_id != roll_a.instance_id or round_trip.definition_id != roll_a.definition_id or round_trip.affix_ids != roll_a.affix_ids or round_trip.affix_tiers != roll_a.affix_tiers:
		failures.append("ItemInstance serialization round trip failed")
	var equipped_instance := PlayerProfile.get_weapon_instance(0)
	equipped_instance.current_durability = 37.0
	var version_two_save := PlayerProfile.to_save_data()
	if not PlayerProfile.apply_save_data(version_two_save, false) or PlayerProfile.get_weapon_instance(0) == null or not is_equal_approx(PlayerProfile.get_weapon_instance(0).current_durability, 37.0):
		failures.append("Version 3 profile did not preserve equipped instance data")
	var ricochet := AffixDatabase.get_definition(&"ricochet")
	if not ricochet.is_compatible(rifle) or ricochet.is_compatible(PlayerProfile.get_definition("ronin_katana")):
		failures.append("Gun-only affix compatibility is invalid")
	var vampiric := AffixDatabase.get_definition(&"vampiric")
	if not vampiric.is_compatible(PlayerProfile.get_definition("ronin_katana")) or vampiric.is_compatible(rifle):
		failures.append("Melee-only affix compatibility is invalid")
	var migrated := PlayerProfile.to_save_data()
	migrated["save_version"] = 1
	migrated.erase("owned_item_instances")
	migrated.erase("weapon_instance_slots")
	migrated.erase("equipped_gear_instances")
	if not PlayerProfile.apply_save_data(migrated, false) or PlayerProfile.owned_item_instances.size() < PlayerProfile.owned_item_ids.size() or PlayerProfile.get_weapon_instance(0) == null:
		failures.append("Version 1 profile did not migrate to persistent item instances")
	item_tooltip.show_item(PlayerProfile.get_definition("phantom_katana"), PlayerProfile.get_instance_for_definition("phantom_katana"))
	await get_tree().process_frame
	var tooltip_text := item_tooltip.get_stats_text()
	if not tooltip_text.contains("AFFIXES") or not tooltip_text.contains("Duelist III") or not tooltip_text.contains("Perfect parry") or not tooltip_text.contains("UNIQUE"):
		failures.append("Tooltip did not render readable affix tiers and mythic identity")
	item_tooltip.show_item(PlayerProfile.get_definition("rushfang"), PlayerProfile.get_instance_for_definition("rushfang"))
	await get_tree().process_frame
	if not item_tooltip.get_stats_text().contains("Fire Rate") or not item_tooltip.get_stats_text().contains("->") or not item_tooltip.get_stats_text().contains("Fast Reload II"):
		failures.append("Tooltip did not show affix-modified effective stats")
	item_tooltip.hide_item()
	if failures.is_empty():
		print("AFFIX_TEST_OK: 30 variants, 50 tiered affixes, compatibility, deterministic rolls, instances, migration and tooltip passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("AFFIX_TEST_FAILURE: " + failure)
		get_tree().quit(1)


func _run_profile_restart_write() -> void:
	PlayerProfile.create_development_profile()
	_configure_integration_loadout()
	PlayerProfile.set_inventory_item(7, "dev:void_charm", false)
	if PlayerProfile.save_profile(RESTART_TEST_PATH):
		print("PROFILE_RESTART_WRITE_OK")
		get_tree().quit(0)
	else:
		push_error("PROFILE_RESTART_WRITE_FAILURE: " + PlayerProfile.last_error)
		get_tree().quit(1)


func _run_profile_restart_read() -> void:
	var loaded := PlayerProfile.load_profile(RESTART_TEST_PATH, false)
	var valid := loaded and PlayerProfile.weapon_slots == ["vanguard_rifle", "knight_sword"] and PlayerProfile.skill_slots == ["grapple", "blink"] and PlayerProfile.main_inventory[7] == "dev:void_charm"
	var absolute_path := ProjectSettings.globalize_path(RESTART_TEST_PATH)
	if FileAccess.file_exists(RESTART_TEST_PATH):
		DirAccess.remove_absolute(absolute_path)
	if valid:
		print("PROFILE_RESTART_READ_OK: a fresh process retained weapons, skills and inventory")
		get_tree().quit(0)
	else:
		push_error("PROFILE_RESTART_READ_FAILURE")
		get_tree().quit(1)


func _run_lobby_layout_test() -> void:
	print("LOBBY_LAYOUT_START")
	var failures: Array[String] = []
	for test_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		get_window().size = test_size
		_show_main()
		await get_tree().process_frame
		await get_tree().process_frame
		_validate_controls_in_view(["MainMenuPanel", "BuildSummaryPanel"], test_size, failures)
		var operative_model := find_child("OperativePreviewModel", true, false)
		if operative_model == null or operative_model.get_child_count() < 30:
			failures.append("%dx%d main menu operative model is missing or lacks detail" % [test_size.x, test_size.y])
		_show_loadout()
		await get_tree().process_frame
		await get_tree().process_frame
		_validate_controls_in_view(["EquippedPanel", "ChoicesPanel", "DetailsPanel", "PowerLabel"], test_size, failures)
		_show_stash()
		await get_tree().process_frame
		await get_tree().process_frame
		_validate_controls_in_view(["StashPanel", "InventoryPanel"], test_size, failures)
		_show_settings()
		await get_tree().process_frame
		await get_tree().process_frame
		_validate_controls_in_view(["SettingsRoot", "VIDEOGRAPHICSPanel", "GAMEPLAYPanel", "AUDIOPanel"], test_size, failures)
		_show_keybinds()
		await get_tree().process_frame
		await get_tree().process_frame
		_validate_controls_in_view(["KeybindsScroll", "KeybindFeedback"], test_size, failures)
		_show_play()
		await get_tree().process_frame
		await get_tree().process_frame
		_validate_controls_in_view(["ActivityCards"], test_size, failures)
		var activity_cards := find_child("ActivityCards", true, false) as HBoxContainer
		if activity_cards == null or activity_cards.get_child_count() != 3:
			failures.append("%dx%d play screen did not contain three activity cards" % [test_size.x, test_size.y])
	if failures.is_empty():
		print("LOBBY_LAYOUT_OK: lobby, loadout, stash, settings, keybinds and three activity cards fit 1280x720, 1920x1080 and 2560x1440")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("LOBBY_LAYOUT_FAILURE: " + failure)
		get_tree().quit(1)


func _validate_controls_in_view(names: Array[String], viewport_size: Vector2i, failures: Array[String]) -> void:
	for control_name: String in names:
		var control := find_child(control_name, true, false) as Control
		if control == null:
			failures.append("%dx%d missing %s" % [viewport_size.x, viewport_size.y, control_name])
			continue
		var rect := control.get_global_rect()
		if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > viewport_size.x + 1.0 or rect.end.y > viewport_size.y + 1.0:
			failures.append("%dx%d %s outside viewport: %s" % [viewport_size.x, viewport_size.y, control_name, str(rect)])


func _capture_lobby(screen_name: String) -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	for frame: int in 20:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var capture_path := "res://validation_%s.png" % screen_name
	var error := image.save_png(capture_path)
	print("LOBBY_CAPTURE_OK: " + capture_path if error == OK else "LOBBY_CAPTURE_FAILED")
	get_tree().quit(0 if error == OK else 1)


func _capture_tooltip() -> void:
	item_tooltip.show_item(PlayerProfile.get_definition("worn_assault_rifle"), PlayerProfile.get_instance_for_definition("worn_assault_rifle"))
	for frame: int in 20:
		await get_tree().process_frame
	item_tooltip.reposition_for_test(Vector2(get_viewport_rect().size) - Vector2(16, 16), get_viewport_rect().size)
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("res://validation_tooltip.png")
	print("TOOLTIP_CAPTURE_OK" if error == OK else "TOOLTIP_CAPTURE_FAILED")
	get_tree().quit(0 if error == OK else 1)


func _quit_game() -> void:
	get_tree().quit()


func _definition_name(item_id: String) -> String:
	var definition := PlayerProfile.get_definition(item_id)
	return definition.display_name if definition != null else "Empty"


func _panel(parent: Control, minimum: Vector2 = Vector2.ZERO) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BORDER, 1, 0))
	parent.add_child(panel)
	return panel


func _button(parent: Control, text: String, danger: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", COLOR_WARNING if danger else COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", COLOR_MUTED)
	button.add_theme_color_override("font_hover_color", Color(0.01, 0.02, 0.025))
	button.add_theme_stylebox_override("normal", _style(COLOR_PANEL_LIGHT, COLOR_BORDER, 1, 0))
	button.add_theme_stylebox_override("hover", _style(COLOR_YELLOW, COLOR_YELLOW, 2, 0))
	button.add_theme_stylebox_override("pressed", _style(COLOR_ACCENT, COLOR_ACCENT, 2, 0))
	button.add_theme_stylebox_override("disabled", _style(Color(0.025, 0.03, 0.032), Color(0.10, 0.12, 0.12), 1, 0))
	parent.add_child(button)
	button.pressed.connect(func() -> void: AudioEvents.play(StringName(button.get_meta("audio_event", &"ui_click"))))
	button.mouse_entered.connect(func() -> void: AudioEvents.play(&"ui_hover"))
	return button


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _margin(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(margin)
	return margin


func _style(color: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style
