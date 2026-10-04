class_name DungeonInventoryMenu
extends CanvasLayer

signal closed

var inventory: RunInventory
var player: PlayerController
var drop_callback: Callable
var root: Control
var grid: GridContainer
var details_label: Label
var feedback_label: Label
var tooltip: ItemTooltip
var context_menu: PopupMenu
var context_payload: Dictionary = {}
var selected_slot: int = -1


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func bind(run_inventory: RunInventory, actor: PlayerController, on_drop: Callable) -> void:
	inventory = run_inventory
	player = actor
	drop_callback = on_drop
	if not inventory.changed.is_connected(_refresh):
		inventory.changed.connect(_refresh)
	tooltip.set_comparison_provider(PlayerProfile.get_comparison_instance)
	_refresh()


func open() -> void:
	if inventory == null or player == null:
		return
	visible = true
	if player.current_weapon != null:
		player.current_weapon.cancel_combat()
	MouseModeService.enter_settings(player)
	_refresh()


func close() -> void:
	visible = false
	tooltip.hide_item()
	context_menu.hide()
	MouseModeService.capture_gameplay(player)
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.008, 0.012, 0.014, 0.90)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var panel := PanelContainer.new()
	panel.name = "DungeonInventoryPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -305
	panel.offset_bottom = 305
	panel.add_theme_stylebox_override("panel", _style(Color(0.018, 0.026, 0.029, 0.985), Color(0.25, 0.48, 0.49), 2))
	root.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := _label(header, "RUN INVENTORY", 24, Color(0.92, 0.94, 0.93))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(header, "TAB  CLOSE   //   RIGHT CLICK  ACTIONS", 11, Color(0.48, 0.61, 0.62))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	var inventory_panel := PanelContainer.new()
	inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_panel.add_theme_stylebox_override("panel", _style(Color(0.012, 0.018, 0.020, 0.92), Color(0.11, 0.17, 0.18), 1))
	body.add_child(inventory_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_panel.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	var details_panel := PanelContainer.new()
	details_panel.custom_minimum_size.x = 285
	details_panel.add_theme_stylebox_override("panel", _style(Color(0.022, 0.032, 0.035, 0.96), Color(0.18, 0.28, 0.29), 1))
	body.add_child(details_panel)
	var details_margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		details_margin.add_theme_constant_override("margin_" + side, 14)
	details_panel.add_child(details_margin)
	var details_root := VBoxContainer.new()
	details_root.add_theme_constant_override("separation", 8)
	details_margin.add_child(details_root)
	_label(details_root, "INSPECT / COMPARE", 11, Color(0.28, 0.78, 0.80))
	details_label = _label(details_root, "Select an item.", 12, Color(0.88, 0.91, 0.90))
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feedback_label = _label(details_root, "", 11, Color(0.95, 0.31, 0.23))
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size.y = 42
	close_button.pressed.connect(close)
	details_root.add_child(close_button)
	tooltip = ItemTooltip.new()
	root.add_child(tooltip)
	context_menu = PopupMenu.new()
	context_menu.index_pressed.connect(_on_context_action)
	root.add_child(context_menu)


func _refresh() -> void:
	if grid == null or inventory == null:
		return
	for child: Node in grid.get_children():
		child.queue_free()
	for slot_index: int in RunInventory.SLOT_COUNT:
		var instance := inventory.get_item(slot_index)
		var definition := PlayerProfile.get_definition(String(instance.definition_id)) if instance != null else null
		var slot := InventoryItemSlot.new()
		slot.configure(definition, instance, "run_inventory", slot_index, {
			"compact": true,
			"selected": slot_index == selected_slot,
			"empty_caption": "SLOT %02d" % (slot_index + 1),
			"compatibility_checker": _can_drop,
			"drop_handler": _drop_into_slot,
		})
		slot.custom_minimum_size = Vector2(118, 78)
		grid.add_child(slot)
		slot.selected_requested.connect(_select_slot)
		slot.quick_action_requested.connect(_quick_action)
		slot.context_requested.connect(_open_context)
		if definition != null:
			slot.mouse_entered.connect(tooltip.show_item.bind(definition, instance))
			slot.mouse_exited.connect(tooltip.hide_item.bind(definition))
	if selected_slot >= 0:
		_update_details(selected_slot)


func _can_drop(payload: Dictionary, target_kind: String, target_key: Variant) -> Dictionary:
	var source := int(payload.get("origin_key", -1))
	var target := int(target_key)
	return {"ok": target_kind == "run_inventory" and source >= 0 and source < RunInventory.SLOT_COUNT and target >= 0 and target < RunInventory.SLOT_COUNT}


func _drop_into_slot(payload: Dictionary, _target_kind: String, target_key: Variant) -> void:
	var source := int(payload.get("origin_key", -1))
	var target := int(target_key)
	if inventory.move_item(source, target):
		selected_slot = target
		AudioEvents.play(&"ui_click")
	else:
		_show_feedback("INVALID DROP", false)


func _select_slot(payload: Dictionary) -> void:
	selected_slot = int(payload.get("origin_key", -1))
	_update_details(selected_slot)


func _quick_action(payload: Dictionary) -> void:
	var slot := int(payload.get("origin_key", -1))
	var instance := inventory.get_item(slot)
	var definition := PlayerProfile.get_definition(String(instance.definition_id)) if instance != null else null
	if definition != null and definition.item_type == ItemDefinition.ItemType.CONSUMABLE:
		_use_item(slot)
	else:
		selected_slot = slot
		_update_details(slot)


func _open_context(payload: Dictionary, global_position: Vector2) -> void:
	context_payload = payload.duplicate(true)
	var slot := int(payload.get("origin_key", -1))
	var instance := inventory.get_item(slot)
	var definition := PlayerProfile.get_definition(String(instance.definition_id)) if instance != null else null
	if definition == null:
		return
	context_menu.clear()
	if definition.item_type == ItemDefinition.ItemType.CONSUMABLE:
		context_menu.add_item("USE", 1)
	context_menu.add_item("INSPECT", 2)
	context_menu.add_separator()
	context_menu.add_item("DROP", 3)
	context_menu.position = Vector2i(global_position)
	context_menu.popup()


func _on_context_action(action_id: int) -> void:
	var slot := int(context_payload.get("origin_key", -1))
	match action_id:
		1: _use_item(slot)
		2:
			selected_slot = slot
			_update_details(slot)
		3:
			if drop_callback.is_valid():
				drop_callback.call(slot)


func _use_item(slot: int) -> void:
	var instance := inventory.get_item(slot)
	var definition := PlayerProfile.get_definition(String(instance.definition_id)) if instance != null else null
	if definition == null or definition.item_type != ItemDefinition.ItemType.CONSUMABLE:
		_show_feedback("ITEM CANNOT BE USED", false)
		return
	var healed := player.health.heal(35.0)
	if healed <= 0.0:
		_show_feedback("HEALTH ALREADY FULL", false)
		return
	inventory.remove_at(slot)
	selected_slot = -1
	details_label.text = "Consumed %s.\n\n+%d HEALTH" % [definition.display_name.to_upper(), roundi(healed)]
	_show_feedback("ITEM USED", true)


func _update_details(slot: int) -> void:
	var instance := inventory.get_item(slot)
	var definition := PlayerProfile.get_definition(String(instance.definition_id)) if instance != null else null
	if definition == null:
		details_label.text = "EMPTY SLOT"
		return
	var lines: Array[String] = [definition.display_name.to_upper(), definition.get_rarity_name().to_upper(), "", definition.description, "", definition.get_type_name().to_upper()]
	if instance.max_durability > 0.0:
		lines.append("DURABILITY  %d / %d" % [ceili(instance.current_durability), ceili(instance.max_durability)])
	var equipped := PlayerProfile.get_comparison_instance(definition)
	if equipped != null and equipped != instance:
		var equipped_definition := PlayerProfile.get_definition(String(equipped.definition_id))
		lines.append("\nCOMPARE  //  %s" % equipped_definition.display_name.to_upper())
		if definition.item_type == ItemDefinition.ItemType.WEAPON:
			lines.append("DAMAGE  %s → %s" % [_number(equipped_definition.damage), _number(definition.damage)])
			if definition.reload_time > 0.0: lines.append("RELOAD  %.2fs → %.2fs" % [equipped_definition.reload_time, definition.reload_time])
		elif definition.item_type == ItemDefinition.ItemType.GEAR:
			lines.append("ARMOR  %d → %d" % [equipped_definition.armor_value, definition.armor_value])
	details_label.text = "\n".join(lines)


func _show_feedback(message: String, success: bool) -> void:
	feedback_label.text = message
	feedback_label.add_theme_color_override("font_color", Color(0.34, 0.88, 0.64) if success else Color(0.95, 0.31, 0.23))
	AudioEvents.play(&"ui_click" if success else &"ui_invalid")


func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


func _label(parent: Control, text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	return style
