class_name InventoryItemSlot
extends PanelContainer

signal quick_action_requested(payload: Dictionary)
signal selected_requested(payload: Dictionary)
signal context_requested(payload: Dictionary, global_position: Vector2)
signal drag_started(payload: Dictionary)
signal drag_finished

const RARITY_COLORS: Array[Color] = [
	Color(0.62, 0.65, 0.68), Color(0.35, 0.72, 0.45), Color(0.27, 0.58, 0.88),
	Color(0.61, 0.38, 0.85), Color(0.90, 0.62, 0.22), Color(0.84, 0.25, 0.54), Color(0.24, 0.82, 0.78),
]

var definition: ItemDefinition
var instance: ItemInstance
var slot_kind: String = "stash"
var slot_key: Variant = ""
var compatibility_checker: Callable
var drop_handler: Callable
var selected: bool = false
var equipped: bool = false
var is_new: bool = false
var empty_caption: String = "EMPTY"
var compact: bool = false
var hovered: bool = false

var icon_frame: PanelContainer
var icon_texture: TextureRect
var glyph_label: Label
var name_label: Label
var type_label: Label
var badge_label: Label
var condition_bar: ProgressBar
var drag_hint: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_build()
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_set_hovered.bind(true))
	focus_exited.connect(_set_hovered.bind(false))
	_refresh()


func configure(item_definition: ItemDefinition, item_instance: ItemInstance, kind: String, key: Variant, options: Dictionary = {}) -> void:
	definition = item_definition
	instance = item_instance
	slot_kind = kind
	slot_key = key
	selected = bool(options.get("selected", false))
	equipped = bool(options.get("equipped", false))
	is_new = bool(options.get("new", false))
	empty_caption = String(options.get("empty_caption", "EMPTY"))
	compact = bool(options.get("compact", false))
	var checker: Variant = options.get("compatibility_checker", Callable())
	var handler: Variant = options.get("drop_handler", Callable())
	compatibility_checker = checker if checker is Callable else Callable()
	drop_handler = handler if handler is Callable else Callable()
	if is_node_ready():
		_refresh()


func get_payload() -> Dictionary:
	return {
		"instance_id": instance.instance_id if instance != null else "",
		"definition_id": String(definition.id) if definition != null else "",
		"origin_kind": slot_kind,
		"origin_key": slot_key,
	}


func set_drag_hint(state: int) -> void:
	drag_hint = clampi(state, -1, 1)
	_apply_style()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and definition != null:
		quick_action_requested.emit(get_payload())
		accept_event()
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and definition != null:
		context_requested.emit(get_payload(), get_global_mouse_position())
		accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click and definition != null:
		quick_action_requested.emit(get_payload())
		accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		selected_requested.emit(get_payload())
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if definition == null or instance == null:
		return null
	var payload := get_payload()
	set_drag_preview(_make_drag_preview())
	drag_started.emit(payload)
	return payload


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not compatibility_checker.is_valid():
		set_drag_hint(-1)
		return false
	var result: Variant = compatibility_checker.call(data as Dictionary, slot_kind, slot_key)
	var valid := bool(result.get("ok", false)) if result is Dictionary else bool(result)
	set_drag_hint(1 if valid else -1)
	return valid


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	set_drag_hint(0)
	if data is Dictionary and drop_handler.is_valid():
		drop_handler.call(data as Dictionary, slot_kind, slot_key)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		set_drag_hint(0)
		drag_finished.emit()


func _build() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 7 if compact else 9)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	margin.add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	icon_frame = PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(42, 42) if compact else Vector2(54, 54)
	top.add_child(icon_frame)
	icon_texture = TextureRect.new()
	icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon_texture)
	glyph_label = Label.new()
	glyph_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph_label.add_theme_font_size_override("font_size", 23 if compact else 28)
	glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(glyph_label)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(copy)
	name_label = _label(copy, 12 if compact else 14, Color(0.92, 0.94, 0.93))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size.y = 17 if compact else 20
	type_label = _label(copy, 9 if compact else 10, Color(0.49, 0.56, 0.58))
	badge_label = _label(copy, 9, Color(0.28, 0.82, 0.72))
	condition_bar = ProgressBar.new()
	condition_bar.min_value = 0.0
	condition_bar.max_value = 100.0
	condition_bar.show_percentage = false
	condition_bar.custom_minimum_size.y = 3
	condition_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(condition_bar)


func _refresh() -> void:
	if name_label == null:
		return
	var occupied := definition != null and instance != null
	if not occupied:
		name_label.text = empty_caption
		type_label.text = "" if compact else "DROP COMPATIBLE ITEM HERE"
		badge_label.text = ""
		glyph_label.text = "+"
		glyph_label.add_theme_color_override("font_color", Color(0.31, 0.38, 0.40))
		icon_texture.visible = false
		condition_bar.visible = false
		_apply_style()
		return
	var accent := RARITY_COLORS[clampi(definition.rarity, 0, RARITY_COLORS.size() - 1)]
	name_label.text = definition.display_name.to_upper()
	name_label.add_theme_color_override("font_color", accent.lightened(0.16) if definition.rarity >= ItemDefinition.Rarity.EPIC else Color(0.92, 0.94, 0.93))
	type_label.text = "%s  ·  %s" % [definition.get_type_name().to_upper(), _subtype_text()]
	var badges: Array[String] = []
	if equipped: badges.append("EQUIPPED")
	if is_new: badges.append("NEW")
	if instance.is_broken(): badges.append("BROKEN")
	badge_label.text = "  ·  ".join(badges)
	badge_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.23) if instance.is_broken() else accent)
	icon_texture.texture = definition.preview_icon
	icon_texture.visible = definition.preview_icon != null
	glyph_label.visible = definition.preview_icon == null
	glyph_label.text = _glyph()
	glyph_label.add_theme_color_override("font_color", accent)
	condition_bar.visible = instance.max_durability > 0.0
	if condition_bar.visible:
		condition_bar.value = instance.current_durability / maxf(instance.max_durability, 1.0) * 100.0
		condition_bar.add_theme_stylebox_override("background", _style(Color(0.07, 0.08, 0.08), Color.TRANSPARENT, 0))
		var condition_color := Color(0.92, 0.25, 0.18) if condition_bar.value <= 20.0 else Color(0.34, 0.55, 0.54)
		condition_bar.add_theme_stylebox_override("fill", _style(condition_color, Color.TRANSPARENT, 0))
	_apply_style()


func _apply_style() -> void:
	var accent := RARITY_COLORS[clampi(definition.rarity, 0, RARITY_COLORS.size() - 1)] if definition != null else Color(0.18, 0.22, 0.23)
	var background := Color(0.025, 0.033, 0.035, 0.96)
	var border := accent.darkened(0.34)
	var width := 1
	if selected:
		background = Color(0.035, 0.11, 0.12, 0.98)
		border = Color(0.08, 0.76, 0.82)
		width = 2
	elif hovered:
		background = Color(0.045, 0.065, 0.068, 0.98)
		border = accent.lightened(0.18)
		width = 2
	if instance != null and instance.is_broken():
		background = Color(0.09, 0.035, 0.03, 0.88)
		border = Color(0.58, 0.16, 0.12)
	if drag_hint > 0:
		background = Color(0.035, 0.16, 0.12, 0.98)
		border = Color(0.26, 0.90, 0.62)
		width = 2
	elif drag_hint < 0:
		background = Color(0.16, 0.035, 0.03, 0.98)
		border = Color(0.96, 0.25, 0.18)
		width = 2
	add_theme_stylebox_override("panel", _style(background, border, width))
	if icon_frame != null:
		icon_frame.add_theme_stylebox_override("panel", _style(Color(0.012, 0.018, 0.019, 0.95), accent, 2))
	modulate.a = 0.58 if instance != null and instance.is_broken() else 1.0


func _set_hovered(value: bool) -> void:
	var changed := hovered != value
	hovered = value
	if value and changed and definition != null:
		AudioEvents.play(&"ui_hover")
	_apply_style()


func _make_drag_preview() -> Control:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(220, 60)
	var accent := RARITY_COLORS[clampi(definition.rarity, 0, RARITY_COLORS.size() - 1)]
	preview.add_theme_stylebox_override("panel", _style(Color(0.015, 0.022, 0.024, 0.96), accent, 2))
	var label := Label.new()
	label.text = "%s\n%s" % [definition.display_name.to_upper(), definition.get_rarity_name().to_upper()]
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", accent.lightened(0.18))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.add_child(label)
	return preview


func _subtype_text() -> String:
	if definition.item_type == ItemDefinition.ItemType.WEAPON:
		return String(definition.weapon_family).replace("_", " ").to_upper()
	if definition.item_type == ItemDefinition.ItemType.GEAR:
		return definition.get_gear_slot_name().to_upper()
	if definition.item_type == ItemDefinition.ItemType.SKILL:
		return "%d POWER" % definition.power_cost
	return definition.get_rarity_name().to_upper()


func _glyph() -> String:
	match definition.item_type:
		ItemDefinition.ItemType.WEAPON:
			return "⚔" if definition.weapon_family in [&"katana", &"nodachi", &"sword"] else ("✦" if definition.weapon_family == &"magic" else "▰")
		ItemDefinition.ItemType.SKILL: return "◆"
		ItemDefinition.ItemType.GEAR: return "⬟"
		ItemDefinition.ItemType.CONSUMABLE: return "+"
		ItemDefinition.ItemType.KEY: return "◇"
		_: return "□"


func _label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
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
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
