class_name ItemTooltip
extends PanelContainer

const RARITY_COLORS: Array[Color] = [
	Color(0.72, 0.75, 0.77), Color(0.43, 0.76, 0.51), Color(0.35, 0.62, 0.91),
	Color(0.66, 0.43, 0.89), Color(0.90, 0.66, 0.28), Color(0.78, 0.29, 0.56), Color(0.31, 0.82, 0.82),
]

var current_item: ItemDefinition
var preview_texture: TextureRect
var preview_glyph: Label
var name_label: Label
var rarity_label: Label
var flavor_label: Label
var type_label: Label
var stats_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	visible = false
	custom_minimum_size = Vector2(340, 0)
	_build()


func show_item(definition: ItemDefinition) -> void:
	if definition == null:
		return
	if current_item != definition:
		current_item = definition
		_update_content(definition)
	visible = true
	_reposition(get_viewport().get_mouse_position(), get_viewport_rect().size)


func hide_item(definition: ItemDefinition = null) -> void:
	if definition != null and current_item != definition:
		return
	visible = false
	current_item = null


func get_stats_text() -> String:
	return stats_label.text if stats_label != null else ""


func reposition_for_test(cursor: Vector2, viewport_size: Vector2) -> Vector2:
	_reposition(cursor, viewport_size)
	return position


func _process(_delta: float) -> void:
	if visible:
		size = get_combined_minimum_size()
		_reposition(get_viewport().get_mouse_position(), get_viewport_rect().size)


func _build() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.034, 0.047, 0.985), Color(0.32, 0.45, 0.52)))
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 13)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	margin.add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var preview_frame := PanelContainer.new()
	preview_frame.custom_minimum_size = Vector2(104, 104)
	preview_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.071, 0.09), Color(0.2, 0.3, 0.36)))
	top.add_child(preview_frame)
	preview_texture = TextureRect.new()
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 9)
	preview_frame.add_child(preview_texture)
	preview_glyph = Label.new()
	preview_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_glyph.add_theme_font_size_override("font_size", 34)
	preview_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.add_child(preview_glyph)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	name_label = _make_label(heading, 19, Color(0.94, 0.95, 0.96))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rarity_label = _make_label(heading, 12, Color.WHITE)
	type_label = _make_label(heading, 11, Color(0.52, 0.67, 0.73))
	flavor_label = _make_label(root, 12, Color(0.68, 0.71, 0.74))
	flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(HSeparator.new())
	stats_label = _make_label(root, 12, Color(0.88, 0.9, 0.91))
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _update_content(definition: ItemDefinition) -> void:
	var accent := RARITY_COLORS[clampi(definition.rarity, 0, RARITY_COLORS.size() - 1)]
	name_label.text = definition.display_name.to_upper()
	rarity_label.text = definition.get_rarity_name().to_upper()
	rarity_label.add_theme_color_override("font_color", accent)
	type_label.text = _type_line(definition)
	flavor_label.text = '"%s"' % (definition.flavor_text if not definition.flavor_text.is_empty() else definition.description)
	stats_label.text = _build_stats(definition)
	preview_texture.texture = definition.preview_icon
	preview_texture.visible = definition.preview_icon != null
	preview_glyph.visible = definition.preview_icon == null
	preview_glyph.text = _glyph_for(definition)
	preview_glyph.add_theme_color_override("font_color", accent)
	add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.034, 0.047, 0.985), accent.darkened(0.25)))
	reset_size()


func _type_line(definition: ItemDefinition) -> String:
	if definition.item_type == ItemDefinition.ItemType.WEAPON:
		return "%s  ·  %s" % [definition.get_type_name().to_upper(), String(definition.weapon_family).replace("_", " ").to_upper()]
	if definition.item_type == ItemDefinition.ItemType.GEAR:
		return "GEAR  ·  %s" % definition.get_gear_slot_name().to_upper()
	return definition.get_type_name().to_upper()


func _build_stats(definition: ItemDefinition) -> String:
	var lines: Array[String] = []
	if definition.item_type == ItemDefinition.ItemType.WEAPON:
		_add_number(lines, "Damage", definition.damage)
		_add_number(lines, "Heavy Damage", definition.heavy_damage)
		if not definition.attack_speed_label.is_empty(): lines.append("Attack Speed  %s" % definition.attack_speed_label)
		_add_number(lines, "Fire Rate", definition.fire_rate, " / sec")
		if definition.magazine_size > 0: lines.append("Magazine  %d" % definition.magazine_size)
		_add_number(lines, "Reload", definition.reload_time, "s")
		_add_number(lines, "Headshot", definition.headshot_damage)
		if definition.block_reduction > 0.0: lines.append("Block  %d%%" % roundi(definition.block_reduction * 100.0))
		_add_number(lines, "Deflect Window", definition.deflect_window, "s")
		if not definition.range_label.is_empty(): lines.append("Range  %s" % definition.range_label)
		if definition.durability_max > 0: lines.append("Durability  %d" % definition.durability_max)
		if not definition.special_description.is_empty(): lines.append("\nSPECIAL\n%s" % definition.special_description)
	elif definition.item_type == ItemDefinition.ItemType.SKILL:
		lines.append("Power  %d" % definition.power_cost)
		_add_number(lines, "Cooldown", definition.cooldown, "s")
		if not definition.description.is_empty(): lines.append("\n%s" % definition.description)
		if not definition.activation_method.is_empty(): lines.append("\nACTIVATION\n%s" % definition.activation_method)
	elif definition.item_type == ItemDefinition.ItemType.GEAR:
		lines.append("Slot  %s" % definition.get_gear_slot_name())
		if definition.armor_value > 0: lines.append("Armor  %d" % definition.armor_value)
		if not definition.modifier_text.is_empty(): lines.append("Modifier  %s" % definition.modifier_text)
		if not definition.description.is_empty(): lines.append("\n%s" % definition.description)
	if not definition.affix_ids.is_empty(): lines.append("\nAFFIXES\n%s" % ", ".join(definition.affix_ids))
	return "\n".join(lines)


func _add_number(lines: Array[String], label_text: String, value: float, suffix: String = "") -> void:
	if value <= 0.0:
		return
	var formatted := str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.2f" % value
	lines.append("%s  %s%s" % [label_text, formatted, suffix])


func _glyph_for(definition: ItemDefinition) -> String:
	match definition.item_type:
		ItemDefinition.ItemType.WEAPON:
			return "⚔" if definition.weapon_family in [&"katana", &"nodachi", &"sword"] else ("✦" if definition.weapon_family == &"magic" else "▰")
		ItemDefinition.ItemType.SKILL: return "◆"
		ItemDefinition.ItemType.GEAR: return "⬟"
		_: return "□"


func _reposition(cursor: Vector2, viewport_size: Vector2) -> void:
	var tooltip_size := size.max(custom_minimum_size)
	var target := cursor + Vector2(18, 18)
	if target.x + tooltip_size.x > viewport_size.x - 8.0: target.x = cursor.x - tooltip_size.x - 18.0
	if target.y + tooltip_size.y > viewport_size.y - 8.0: target.y = cursor.y - tooltip_size.y - 18.0
	position = Vector2(clampf(target.x, 8.0, maxf(8.0, viewport_size.x - tooltip_size.x - 8.0)), clampf(target.y, 8.0, maxf(8.0, viewport_size.y - tooltip_size.y - 8.0)))


func _make_label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style
