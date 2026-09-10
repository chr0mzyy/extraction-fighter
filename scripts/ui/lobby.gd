class_name LobbyController
extends Control

const COLOR_BG := Color(0.018, 0.024, 0.034)
const COLOR_PANEL := Color(0.035, 0.046, 0.061, 0.96)
const COLOR_PANEL_LIGHT := Color(0.065, 0.081, 0.101, 0.96)
const COLOR_BORDER := Color(0.22, 0.31, 0.38)
const COLOR_TEXT := Color(0.90, 0.92, 0.93)
const COLOR_MUTED := Color(0.54, 0.60, 0.65)
const COLOR_ACCENT := Color(0.34, 0.77, 0.84)
const COLOR_READY := Color(0.36, 0.84, 0.66)
const COLOR_WARNING := Color(0.96, 0.35, 0.27)

var screen_host: Control
var footer_label: Label
var selected_kind: String = "weapon"
var selected_slot: int = 0
var selected_gear_key: String = ""
var stash_filter: int = -1
var details_label: Label
var feedback_label: Label
var item_tooltip: ItemTooltip

const RESTART_TEST_PATH := "user://extraction_fighter_restart_test.json"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_shell()
	var args := OS.get_cmdline_user_args()
	if "--scene-flow-test" in args:
		_handle_scene_flow_test()
		return
	if "--dungeon-scene-flow-test" in args:
		_handle_dungeon_scene_flow_test()
		return
	if _should_route_to_dungeon(args):
		_route_to_dungeon.call_deferred()
		return
	if _should_route_to_arena(args):
		PlayerProfile.reset_to_defaults(false)
		if "--loadout-integration-test" in args:
			_configure_integration_loadout()
		elif "--content-arena-test" in args:
			_configure_content_loadout()
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


func _should_route_to_arena(args: PackedStringArray) -> bool:
	for flag in ["--self-test", "--ai-soak-test", "--hud-layout-test", "--capture-frame", "--capture-tpp", "--loadout-integration-test", "--content-arena-test", "--effect-self-test", "--pause-flow-test"]:
		if flag in args:
			return true
	return false


func _should_route_to_dungeon(args: PackedStringArray) -> bool:
	for flag in ["--dungeon-self-test", "--extraction-flow-test", "--durability-self-test", "--dungeon-soak-test"]:
		if flag in args:
			return true
	return false


func _route_to_arena() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _route_to_dungeon() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon/armory_dungeon.tscn")


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
	PlayerProfile.reset_to_defaults(false)
	PlayerProfile.set_meta("scene_flow_stage", "arena")
	_route_to_arena.call_deferred()


func _handle_dungeon_scene_flow_test() -> void:
	if String(PlayerProfile.get_meta("dungeon_flow_stage", "")) == "returned":
		PlayerProfile.remove_meta("dungeon_flow_stage")
		print("DUNGEON_SCENE_FLOW_OK: Lobby -> Armory -> Lobby retained persistent profile state")
		get_tree().quit(0)
		return
	PlayerProfile.set_meta("dungeon_flow_stage", "deployed")
	_route_to_dungeon.call_deferred()


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var glow := ColorRect.new()
	glow.color = Color(0.08, 0.18, 0.22, 0.24)
	glow.set_anchors_preset(Control.PRESET_CENTER)
	glow.offset_left = -420
	glow.offset_right = 420
	glow.offset_top = -260
	glow.offset_bottom = 300
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 76
	top.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BORDER, 0, 0))
	add_child(top)
	var top_margin := _margin(top, 28, 12, 28, 10)
	var title_row := HBoxContainer.new()
	top_margin.add_child(title_row)
	var title := _label(title_row, "EXTRACTION FIGHTER", 25, COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var milestone := _label(title_row, "MVP 0.2.2  /  VARIANT FORGE", 12, COLOR_ACCENT)
	milestone.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	screen_host = Control.new()
	screen_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_host.offset_top = 76
	screen_host.offset_bottom = -38
	add_child(screen_host)

	footer_label = _label(self, "LOCAL COMBAT PROFILE  •  SAVE VERSION 2", 11, COLOR_MUTED)
	footer_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer_label.offset_left = 24
	footer_label.offset_right = -24
	footer_label.offset_top = -32
	footer_label.offset_bottom = -8
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	item_tooltip = ItemTooltip.new()
	item_tooltip.name = "ItemTooltip"
	add_child(item_tooltip)


func _clear_screen() -> void:
	if item_tooltip != null:
		item_tooltip.hide_item()
	for child: Node in screen_host.get_children():
		child.queue_free()
	details_label = null
	feedback_label = null


func _show_main() -> void:
	_clear_screen()
	var margin := _margin(screen_host, 44, 36, 44, 34)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)

	var menu_panel := _panel(row, Vector2(310, 0))
	menu_panel.name = "MainMenuPanel"
	var menu_margin := _margin(menu_panel, 22, 22, 22, 22)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 9)
	menu_margin.add_child(menu)
	_label(menu, "MAIN LOBBY", 13, COLOR_ACCENT)
	var rule := HSeparator.new()
	menu.add_child(rule)
	_add_menu_button(menu, "PLAY", _show_play)
	_add_menu_button(menu, "LOADOUT", _show_loadout)
	_add_menu_button(menu, "STASH", _show_stash)
	_add_menu_button(menu, "CUSTOMIZATION", _show_customization)
	_add_menu_button(menu, "SETTINGS", _show_settings)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.add_child(spacer)
	_add_menu_button(menu, "QUIT", _quit_game, true)

	var display_panel := _panel(row)
	display_panel.name = "BuildSummaryPanel"
	display_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var display_margin := _margin(display_panel, 28, 24, 28, 24)
	var display_row := HBoxContainer.new()
	display_row.add_theme_constant_override("separation", 32)
	display_margin.add_child(display_row)
	var character_stage := _build_character_placeholder(display_row)
	character_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var summary := VBoxContainer.new()
	summary.custom_minimum_size.x = 330
	summary.add_theme_constant_override("separation", 9)
	display_row.add_child(summary)
	_label(summary, "CURRENT BUILD", 13, COLOR_ACCENT)
	_label(summary, _definition_name(PlayerProfile.weapon_slots[0]), 22, COLOR_TEXT)
	_label(summary, _definition_name(PlayerProfile.weapon_slots[1]), 18, COLOR_MUTED)
	var separator := HSeparator.new()
	summary.add_child(separator)
	for index: int in PlayerProfile.skill_slots.size():
		var definition := PlayerProfile.get_definition(PlayerProfile.skill_slots[index])
		_label(summary, "SLOT %d  •  %s  •  %d POWER" % [index + 1, definition.display_name.to_upper(), definition.power_cost], 13, COLOR_TEXT)
	var power := _label(summary, "%03d / %03d POWER" % [PlayerProfile.get_skill_power(), PlayerProfile.POWER_LIMIT], 24, COLOR_READY)
	power.add_theme_color_override("font_color", COLOR_READY)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.add_child(fill)
	_label(summary, "ARENA READY", 12, COLOR_READY)


func _show_play() -> void:
	_show_simple_screen("SELECT ACTIVITY", "Choose a deployment route.")
	var content := screen_host.get_node("ScreenMargin/Content") as VBoxContainer
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cards)
	var arena := _activity_card(cards, "ARENA", "Continuous deathmatch testing\nSelected loadout enabled", true)
	arena.pressed.connect(_launch_arena)
	var dungeon := _activity_card(cards, "THE ARMORY", "15 minute extraction run\nLoot is lost on death", true)
	dungeon.pressed.connect(_launch_dungeon)
	_add_back_button(content)


func _show_loadout() -> void:
	_clear_screen()
	var margin := _margin(screen_host, 28, 20, 28, 20)
	margin.name = "LoadoutMargin"
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var heading := _label(header, "LOADOUT", 24, COLOR_TEXT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var power := PlayerProfile.get_skill_power()
	var power_label := _label(header, "POWER  %d / %d" % [power, PlayerProfile.POWER_LIMIT], 20, COLOR_READY if power <= PlayerProfile.POWER_LIMIT else COLOR_WARNING)
	power_label.name = "PowerLabel"
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	var equipped_panel := _panel(columns, Vector2(330, 0))
	equipped_panel.name = "EquippedPanel"
	var equipped_scroll := ScrollContainer.new()
	equipped_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	equipped_panel.add_child(equipped_scroll)
	var equipped_margin := _margin(equipped_scroll, 16, 14, 16, 14)
	var equipped := VBoxContainer.new()
	equipped.add_theme_constant_override("separation", 6)
	equipped_margin.add_child(equipped)
	_label(equipped, "WEAPONS", 12, COLOR_ACCENT)
	for index: int in 2:
		_add_slot_button(equipped, "[%d]  %s" % [index + 1, _definition_name(PlayerProfile.weapon_slots[index])], "weapon", index, PlayerProfile.get_definition(PlayerProfile.weapon_slots[index]), PlayerProfile.get_weapon_instance(index))
	_label(equipped, "SKILLS", 12, COLOR_ACCENT)
	for index: int in 2:
		var definition := PlayerProfile.get_definition(PlayerProfile.skill_slots[index])
		_add_slot_button(equipped, "[%s]  %s  •  %d" % ["Q" if index == 0 else "E", definition.display_name, definition.power_cost], "skill", index, definition)
	_label(equipped, "GEAR", 12, COLOR_ACCENT)
	for key: String in PlayerProfile.GEAR_KEYS:
		var slot_title := key.capitalize().replace(" 1", " I").replace(" 2", " II")
		var gear_definition := PlayerProfile.get_definition(String(PlayerProfile.equipped_gear.get(key, "")))
		_add_gear_slot_button(equipped, "%s  •  %s" % [slot_title, _definition_name(String(PlayerProfile.equipped_gear.get(key, "")))], key, gear_definition, PlayerProfile.get_gear_instance(key))

	var choices_panel := _panel(columns)
	choices_panel.name = "ChoicesPanel"
	choices_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var choices_margin := _margin(choices_panel, 16, 14, 16, 14)
	var choices_root := VBoxContainer.new()
	choices_margin.add_child(choices_root)
	_label(choices_root, "OWNED OPTIONS", 12, COLOR_ACCENT)
	var choices_scroll := ScrollContainer.new()
	choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choices_root.add_child(choices_scroll)
	var choices := GridContainer.new()
	choices.name = "Choices"
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 8)
	choices.add_theme_constant_override("v_separation", 8)
	choices_scroll.add_child(choices)

	var details_panel := _panel(columns, Vector2(285, 0))
	details_panel.name = "DetailsPanel"
	var details_margin := _margin(details_panel, 17, 15, 17, 15)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 10)
	details_margin.add_child(details)
	_label(details, "ITEM DETAILS", 12, COLOR_ACCENT)
	details_label = _label(details, "Select an owned item.", 14, COLOR_TEXT)
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feedback_label = _label(details, "", 12, COLOR_WARNING)
	_add_back_button(root)
	_populate_loadout_choices(choices)


func _show_stash() -> void:
	_clear_screen()
	var margin := _margin(screen_host, 28, 20, 28, 20)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := _label(header, "STASH", 24, COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(header, "%d GOLD" % PlayerProfile.gold, 13, COLOR_READY)
	var repair_cost := PlayerProfile.get_equipped_repair_cost()
	var repair := _button(header, "REPAIR EQUIPPED  •  %d" % repair_cost, false)
	repair.custom_minimum_size = Vector2(205, 38)
	repair.disabled = repair_cost <= 0
	repair.pressed.connect(_repair_equipped)
	_label(header, "%d ITEM INSTANCES" % PlayerProfile.owned_item_instances.size(), 13, COLOR_MUTED)
	var header_back := _button(header, "BACK", false)
	header_back.custom_minimum_size = Vector2(120, 38)
	header_back.pressed.connect(_show_main)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 7)
	root.add_child(filters)
	for filter_data: Array in [["ALL", -1], ["WEAPONS", ItemDefinition.ItemType.WEAPON], ["SKILLS", ItemDefinition.ItemType.SKILL], ["GEAR", ItemDefinition.ItemType.GEAR]]:
		var button := _button(filters, filter_data[0], false)
		button.pressed.connect(_set_stash_filter.bind(int(filter_data[1])))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var stash_panel := _panel(body)
	stash_panel.name = "StashPanel"
	stash_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stash_margin := _margin(stash_panel, 14, 12, 14, 12)
	var stash_scroll := ScrollContainer.new()
	stash_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stash_margin.add_child(stash_scroll)
	var item_grid := GridContainer.new()
	item_grid.columns = 3
	item_grid.add_theme_constant_override("h_separation", 8)
	item_grid.add_theme_constant_override("v_separation", 8)
	stash_scroll.add_child(item_grid)
	for instance: ItemInstance in PlayerProfile.get_owned_instances(stash_filter):
		var definition := PlayerProfile.get_definition(String(instance.definition_id))
		var condition := "  BROKEN" if instance.is_broken() else ("  %d%%" % roundi(instance.current_durability / instance.max_durability * 100.0) if instance.max_durability > 0.0 else "")
		var item_button := _button(item_grid, "%s%s\n%s" % [definition.display_name, condition, definition.get_type_name().to_upper()], false)
		item_button.custom_minimum_size = Vector2(190, 64)
		item_button.pressed.connect(_show_item_details.bind(definition))
		_bind_tooltip(item_button, definition, instance)
	var inventory_panel := _panel(body, Vector2(390, 0))
	inventory_panel.name = "InventoryPanel"
	var inventory_margin := _margin(inventory_panel, 14, 12, 14, 12)
	var inventory_root := VBoxContainer.new()
	inventory_root.add_theme_constant_override("separation", 9)
	inventory_margin.add_child(inventory_root)
	_label(inventory_root, "MAIN INVENTORY  •  24 SLOTS", 12, COLOR_ACCENT)
	var inventory_grid := GridContainer.new()
	inventory_grid.columns = 6
	inventory_grid.add_theme_constant_override("h_separation", 5)
	inventory_grid.add_theme_constant_override("v_separation", 5)
	inventory_root.add_child(inventory_grid)
	for index: int in PlayerProfile.INVENTORY_SIZE:
		var item_id := PlayerProfile.main_inventory[index]
		var slot := _button(inventory_grid, str(index + 1) if item_id.is_empty() else _definition_name(item_id).left(3), false)
		slot.name = "InventorySlot%d" % index
		slot.custom_minimum_size = Vector2(50, 50)
		slot.disabled = item_id.is_empty()
		if not item_id.is_empty():
			_bind_tooltip(slot, PlayerProfile.get_definition(item_id), PlayerProfile.get_instance_for_definition(item_id))
	details_label = _label(inventory_root, "Empty slots are ready for future dungeon loot.", 12, COLOR_MUTED)
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _show_customization() -> void:
	_show_placeholder("CUSTOMIZATION", "COMING SOON", "Cosmetics and character presentation are outside MVP 0.2.1.")


func _repair_equipped() -> void:
	var success := PlayerProfile.repair_all_equipped()
	_show_stash()
	footer_label.text = "EQUIPPED ITEMS REPAIRED" if success else PlayerProfile.last_error.to_upper()
	footer_label.add_theme_color_override("font_color", COLOR_READY if success else COLOR_WARNING)


func _show_settings() -> void:
	_show_placeholder("SETTINGS", "CURRENT PROFILE", "Keyboard + mouse  •  Local save enabled\nGameplay settings remain managed by the current prototype defaults.")


func _show_placeholder(title: String, status: String, body: String) -> void:
	_show_simple_screen(title, body)
	var content := screen_host.get_node("ScreenMargin/Content") as VBoxContainer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var status_label := _label(content, status, 28, COLOR_ACCENT)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer_two := Control.new()
	spacer_two.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer_two)
	_add_back_button(content)


func _show_simple_screen(title: String, subtitle: String) -> void:
	_clear_screen()
	var margin := _margin(screen_host, 44, 32, 44, 32)
	margin.name = "ScreenMargin"
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	_label(content, title, 26, COLOR_TEXT)
	_label(content, subtitle, 13, COLOR_MUTED)


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


func _show_item_details(definition: ItemDefinition) -> void:
	if details_label == null:
		return
	var lines: Array[String] = [definition.display_name.to_upper(), definition.get_type_name(), definition.get_rarity_name(), "", definition.description]
	if definition.item_type == ItemDefinition.ItemType.SKILL:
		lines.append("\nPOWER  %d" % definition.power_cost)
	elif definition.item_type == ItemDefinition.ItemType.WEAPON:
		lines.append("\nFAMILY  %s" % String(definition.weapon_family).capitalize())
	elif definition.item_type == ItemDefinition.ItemType.GEAR:
		lines.append("\nSLOT  %s" % definition.get_gear_slot_name())
	var instance := PlayerProfile.get_instance_for_definition(String(definition.id))
	if instance != null and instance.max_durability > 0.0:
		lines.append("\nDURABILITY  %d / %d" % [ceili(instance.current_durability), ceili(instance.max_durability)])
		lines.append("REPAIR COST  %d GOLD" % DurabilityService.repair_cost(instance, definition))
	details_label.text = "\n".join(lines)


func _bind_tooltip(control: Control, definition: ItemDefinition, instance: ItemInstance = null) -> void:
	if definition == null or item_tooltip == null:
		return
	control.mouse_entered.connect(item_tooltip.show_item.bind(definition, instance))
	control.mouse_exited.connect(item_tooltip.hide_item.bind(definition))


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
	_show_stash()


func _add_menu_button(parent: Control, text: String, callable: Callable, danger: bool = false) -> void:
	var button := _button(parent, text, danger)
	button.custom_minimum_size.y = 48
	button.pressed.connect(callable)


func _add_back_button(parent: Control) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var back := _button(row, "BACK", false)
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
	stage.custom_minimum_size = Vector2(360, 420)
	parent.add_child(stage)
	var halo := ColorRect.new()
	halo.color = Color(0.18, 0.45, 0.50, 0.16)
	halo.set_anchors_preset(Control.PRESET_CENTER)
	halo.offset_left = -120
	halo.offset_right = 120
	halo.offset_top = -170
	halo.offset_bottom = 170
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(halo)
	var head := ColorRect.new()
	head.color = Color(0.18, 0.22, 0.25)
	head.set_anchors_preset(Control.PRESET_CENTER)
	head.offset_left = -38
	head.offset_right = 38
	head.offset_top = -158
	head.offset_bottom = -82
	stage.add_child(head)
	var body := ColorRect.new()
	body.color = Color(0.11, 0.25, 0.31)
	body.set_anchors_preset(Control.PRESET_CENTER)
	body.offset_left = -74
	body.offset_right = 74
	body.offset_top = -78
	body.offset_bottom = 142
	stage.add_child(body)
	var blade := ColorRect.new()
	blade.color = Color(0.56, 0.65, 0.68)
	blade.set_anchors_preset(Control.PRESET_CENTER)
	blade.offset_left = 78
	blade.offset_right = 86
	blade.offset_top = -114
	blade.offset_bottom = 142
	blade.rotation = 0.28
	stage.add_child(blade)
	var caption := _label(stage, "ARENA OPERATIVE", 11, COLOR_MUTED)
	caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	caption.offset_left = -120
	caption.offset_right = 120
	caption.offset_top = -32
	caption.offset_bottom = -8
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return stage


func _run_profile_self_test() -> void:
	print("PROFILE_TEST_START")
	var failures: Array[String] = []
	var snapshot := PlayerProfile.to_save_data()
	var test_path := "user://extraction_fighter_profile_test.json"
	PlayerProfile.reset_to_defaults(false)
	if PlayerProfile.get_skill_power() != 130 or not bool(PlayerProfile.validate_loadout().valid):
		failures.append("Default loadout or 130 Power calculation failed")
	if PlayerProfile.main_inventory.size() != 24:
		failures.append("Main inventory does not contain 24 persistent slots")
	if PlayerProfile.owned_item_ids.size() != ItemDatabase.DEFINITIONS.size() - PlayerProfile.DEVELOPMENT_STASH_EXCLUDED.size():
		failures.append("Default stash does not contain the complete development catalog")
	if PlayerProfile.get_owned_definitions(ItemDefinition.ItemType.WEAPON).size() != 30 or PlayerProfile.get_owned_definitions(ItemDefinition.ItemType.SKILL).size() != 10 or PlayerProfile.get_owned_definitions(ItemDefinition.ItemType.GEAR).size() != 27:
		failures.append("Starting stash category counts are invalid")
	if PlayerProfile.equip_gear("helmet", "simple_ring", false):
		failures.append("Gear compatibility allowed a ring in the helmet slot")
	PlayerProfile.set_inventory_item(0, "basic_charm", false)
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
	_configure_integration_loadout()
	if PlayerProfile.get_skill_power() != 200 or not bool(PlayerProfile.validate_loadout().valid):
		failures.append("Grapple + Blink should be valid at exactly 200 Power")
	if not PlayerProfile.save_profile(test_path):
		failures.append("Temporary profile save failed")
	PlayerProfile.reset_to_defaults(false)
	if not PlayerProfile.load_profile(test_path, false) or PlayerProfile.weapon_slots != ["vanguard_rifle", "knight_sword"] or PlayerProfile.skill_slots != ["grapple", "blink"] or PlayerProfile.main_inventory[0] != "basic_charm":
		failures.append("Save/load round trip did not retain selected loadout")
	var corrupt := FileAccess.open(test_path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("{ this is not valid json")
	corrupt = null
	if PlayerProfile.load_profile(test_path, true) or not PlayerProfile.last_load_used_defaults or not FileAccess.file_exists(test_path):
		failures.append("Corrupt save did not fall back to the default profile")
	var absolute_test_path := ProjectSettings.globalize_path(test_path)
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(absolute_test_path)
	if not PlayerProfile.load_profile(test_path, true) or not PlayerProfile.last_load_used_defaults or not FileAccess.file_exists(test_path):
		failures.append("Missing save did not create a default profile")
	PlayerProfile.apply_save_data(snapshot)
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(absolute_test_path)
	if failures.is_empty():
		print("PROFILE_TEST_OK: defaults, 24 slots, Power limits, alternate loadout, round-trip persistence and safe fallbacks passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("PROFILE_TEST_FAILURE: " + failure)
		get_tree().quit(1)


func _run_content_self_test() -> void:
	print("CONTENT_TEST_START")
	var failures: Array[String] = []
	var snapshot := PlayerProfile.to_save_data()
	PlayerProfile.reset_to_defaults(false)
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
	if not PlayerProfile.apply_save_data(old_save, false) or not PlayerProfile.catalog_migrated_last_load or PlayerProfile.owned_item_ids.size() != ItemDatabase.DEFINITIONS.size() - PlayerProfile.DEVELOPMENT_STASH_EXCLUDED.size():
		failures.append("Legacy profile did not migrate to the development catalog")
	if PlayerProfile.weapon_slots != ["ronin_katana", "huntsman_rifle"] or PlayerProfile.skill_slots != ["dash", "double_jump"]:
		failures.append("Legacy profile migration did not preserve selected loadout")
	PlayerProfile.apply_save_data(snapshot, false)
	if failures.is_empty():
		print("CONTENT_TEST_OK: 30 weapon variants, 10 skills, 27 gear items, Power rules, gameplay scenes and save migration passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("CONTENT_TEST_FAILURE: " + failure)
		get_tree().quit(1)


func _run_tooltip_self_test() -> void:
	print("TOOLTIP_TEST_START")
	var failures: Array[String] = []
	var snapshot := PlayerProfile.to_save_data()
	PlayerProfile.reset_to_defaults(false)
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
	if not PlayerProfile.apply_save_data(migrated, false) or PlayerProfile.owned_item_instances.size() != PlayerProfile.owned_item_ids.size() or PlayerProfile.get_weapon_instance(0) == null:
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
	_configure_integration_loadout()
	PlayerProfile.set_inventory_item(7, "basic_charm", false)
	if PlayerProfile.save_profile(RESTART_TEST_PATH):
		print("PROFILE_RESTART_WRITE_OK")
		get_tree().quit(0)
	else:
		push_error("PROFILE_RESTART_WRITE_FAILURE: " + PlayerProfile.last_error)
		get_tree().quit(1)


func _run_profile_restart_read() -> void:
	var loaded := PlayerProfile.load_profile(RESTART_TEST_PATH, false)
	var valid := loaded and PlayerProfile.weapon_slots == ["vanguard_rifle", "knight_sword"] and PlayerProfile.skill_slots == ["grapple", "blink"] and PlayerProfile.main_inventory[7] == "basic_charm"
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
		_show_loadout()
		await get_tree().process_frame
		await get_tree().process_frame
		_validate_controls_in_view(["EquippedPanel", "ChoicesPanel", "DetailsPanel", "PowerLabel"], test_size, failures)
		_show_stash()
		await get_tree().process_frame
		await get_tree().process_frame
		_validate_controls_in_view(["StashPanel", "InventoryPanel"], test_size, failures)
	if failures.is_empty():
		print("LOBBY_LAYOUT_OK: lobby, loadout, stash and 24-slot inventory fit 1280x720, 1920x1080 and 2560x1440")
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
	for frame: int in 20:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var capture_path := "res://validation_%s.png" % screen_name
	var error := image.save_png(capture_path)
	print("LOBBY_CAPTURE_OK: " + capture_path if error == OK else "LOBBY_CAPTURE_FAILED")
	get_tree().quit(0 if error == OK else 1)


func _capture_tooltip() -> void:
	item_tooltip.show_item(PlayerProfile.get_definition("falcon_burst"))
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
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, COLOR_BORDER, 1, 7))
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
	button.add_theme_stylebox_override("normal", _style(COLOR_PANEL_LIGHT, COLOR_BORDER, 1, 4))
	button.add_theme_stylebox_override("hover", _style(Color(0.09, 0.16, 0.19), COLOR_ACCENT, 2, 4))
	button.add_theme_stylebox_override("pressed", _style(Color(0.05, 0.22, 0.24), COLOR_ACCENT, 2, 4))
	button.add_theme_stylebox_override("disabled", _style(Color(0.03, 0.04, 0.05), Color(0.11, 0.13, 0.15), 1, 4))
	parent.add_child(button)
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
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style
