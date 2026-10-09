class_name ArenaMatchUI
extends CanvasLayer

signal play_again_requested
signal return_to_lobby_requested

const ACCENT := Color(0.02, 0.74, 0.90)
const GOLD := Color(1.0, 0.78, 0.08)
const PANEL := Color(0.012, 0.018, 0.022, 0.985)
const MUTED := Color(0.55, 0.62, 0.64)
const RARITY_COLORS: Array[Color] = [
	Color(0.72, 0.75, 0.77), Color(0.43, 0.76, 0.51), Color(0.35, 0.62, 0.91),
	Color(0.66, 0.43, 0.89), Color(0.90, 0.66, 0.28), Color(0.78, 0.29, 0.56), Color(0.31, 0.82, 0.82),
]

var manager: ArenaMatchManager
var local_participant: ArenaParticipantState
var root: Control
var intro_label: Label
var cue_label: Label
var spectator_label: Label
var results_panel: PanelContainer
var result_title: Label
var result_score: Label
var result_stats: Label
var result_continue_button: Button
var reward_panel: PanelContainer
var reward_status: Label
var simulation_warning: Label
var opponent_grid: GridContainer
var winner_grid: GridContainer
var take_label: Label
var give_label: Label
var feedback_label: Label
var confirm_button: Button
var finish_button: Button
var confirmation_dialog: ConfirmationDialog
var summary_panel: PanelContainer
var summary_text: Label
var item_tooltip: ItemTooltip

var current_result: ArenaMatchResult
var reward_service: ArenaRewardService
var winner_inventory: ArenaTradeInventory
var opponent_inventories: Array[ArenaTradeInventory] = []
var simulation: bool = true
var persist_callback: Callable
var selected_take_id: String = ""
var selected_take_owner_id: String = ""
var selected_give_id: String = ""
var exchange_summaries: Array[String] = []


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func bind(p_manager: ArenaMatchManager, p_local: ArenaParticipantState) -> void:
	manager = p_manager
	local_participant = p_local
	manager.intro_updated.connect(_on_intro_updated)
	manager.round_ended.connect(_on_round_ended)
	manager.sudden_death_started.connect(_on_sudden_death)
	manager.round_started.connect(_on_round_started)
	manager.spectator_requested.connect(_on_spectator_requested)
	manager.round_reset_requested.connect(_on_round_reset)


func present_results(
		result: ArenaMatchResult,
		p_winner_inventory: ArenaTradeInventory = null,
		p_opponents: Array[ArenaTradeInventory] = [],
		p_simulation: bool = true,
		p_persist_callback: Callable = Callable()
) -> void:
	current_result = result
	winner_inventory = p_winner_inventory
	opponent_inventories = p_opponents
	simulation = p_simulation
	persist_callback = p_persist_callback
	reward_service = ArenaRewardService.new(PlayerProfile.item_index)
	selected_take_id = ""
	selected_take_owner_id = ""
	selected_give_id = ""
	exchange_summaries.clear()
	_show_results(result)


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center.position = Vector2(-260, 145)
	center.size = Vector2(520, 180)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	intro_label = _label(30, Color(0.92, 0.96, 0.98), HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(intro_label)
	cue_label = _label(58, ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(cue_label)
	spectator_label = _label(18, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	spectator_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	spectator_label.position = Vector2(-310, -130)
	spectator_label.size = Vector2(620, 80)
	spectator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spectator_label.visible = false
	root.add_child(spectator_label)
	_build_results_panel()
	_build_reward_panel()
	_build_summary_panel()
	item_tooltip = ItemTooltip.new()
	root.add_child(item_tooltip)
	confirmation_dialog = ConfirmationDialog.new()
	confirmation_dialog.title = "CONFIRM ITEM-FOR-ITEM EXCHANGE"
	confirmation_dialog.ok_button_text = "CONFIRM TRADE"
	confirmation_dialog.cancel_button_text = "GO BACK"
	confirmation_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	confirmation_dialog.confirmed.connect(_commit_selected_exchange)
	root.add_child(confirmation_dialog)


func _build_results_panel() -> void:
	results_panel = PanelContainer.new()
	results_panel.set_anchors_preset(Control.PRESET_CENTER)
	results_panel.position = Vector2(-290, -225)
	results_panel.size = Vector2(580, 450)
	results_panel.visible = false
	results_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	results_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, ACCENT, 2, 28))
	root.add_child(results_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	results_panel.add_child(column)
	result_title = _label(42, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(result_title)
	result_score = _label(26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(result_score)
	result_stats = _label(15, Color(0.72, 0.80, 0.82), HORIZONTAL_ALIGNMENT_CENTER)
	result_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(result_stats)
	result_continue_button = _action_button("CONTINUE")
	result_continue_button.pressed.connect(_continue_from_results)
	column.add_child(result_continue_button)


func _build_reward_panel() -> void:
	reward_panel = PanelContainer.new()
	reward_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	reward_panel.offset_left = 28.0
	reward_panel.offset_top = 28.0
	reward_panel.offset_right = -28.0
	reward_panel.offset_bottom = -28.0
	reward_panel.visible = false
	reward_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.006, 0.010, 0.013, 0.995), Color(0.20, 0.27, 0.29), 1, 20))
	root.add_child(reward_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	reward_panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := _label(26, Color(0.94, 0.96, 0.96))
	title.text = "ARENA REWARDS  //  ITEM-FOR-ITEM SWAP"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	reward_status = _label(14, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	header.add_child(reward_status)
	simulation_warning = _label(12, Color(0.95, 0.47, 0.24), HORIZONTAL_ALIGNMENT_CENTER)
	simulation_warning.text = "BOT REWARD SIMULATION  //  NON-PERSISTENT  //  NO MYTHIC OR LEGENDARY BOT FARMING"
	layout.add_child(simulation_warning)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	opponent_grid = _inventory_column(columns, "TAKE FROM LOSING INVENTORY")
	_build_exchange_column(columns)
	winner_grid = _inventory_column(columns, "GIVE FROM YOUR MAIN INVENTORY")
	feedback_label = _label(13, Color(0.92, 0.35, 0.28), HORIZONTAL_ALIGNMENT_CENTER)
	feedback_label.custom_minimum_size.y = 22
	layout.add_child(feedback_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	layout.add_child(actions)
	confirm_button = _action_button("CONFIRM TRADE")
	confirm_button.disabled = true
	confirm_button.pressed.connect(_request_confirmation)
	actions.add_child(confirm_button)
	var cancel := _action_button("CANCEL SELECTION")
	cancel.pressed.connect(_cancel_selection)
	actions.add_child(cancel)
	finish_button = _action_button("FINISH")
	finish_button.pressed.connect(_finish_rewards)
	actions.add_child(finish_button)


func _build_exchange_column(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(270, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.032, 0.035), GOLD, 1, 14))
	parent.add_child(panel)
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	panel.add_child(center)
	var title := _label(14, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = "SELECTED EXCHANGE"
	center.add_child(title)
	take_label = _selection_card("TAKE  //  NOT SELECTED")
	center.add_child(take_label)
	var arrows := _label(28, ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	arrows.text = "⇅  EXACT INSTANCE SWAP  ⇅"
	center.add_child(arrows)
	give_label = _selection_card("GIVE  //  NOT SELECTED")
	center.add_child(give_label)


func _inventory_column(parent: HBoxContainer, heading: String) -> GridContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.025, 0.028), Color(0.20, 0.28, 0.30), 1, 12))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := _label(13, ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = heading
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	return grid


func _build_summary_panel() -> void:
	summary_panel = PanelContainer.new()
	summary_panel.set_anchors_preset(Control.PRESET_CENTER)
	summary_panel.position = Vector2(-330, -240)
	summary_panel.size = Vector2(660, 480)
	summary_panel.visible = false
	summary_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	summary_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, GOLD, 2, 28))
	root.add_child(summary_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	summary_panel.add_child(column)
	var title := _label(34, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = "REWARD SUMMARY"
	column.add_child(title)
	summary_text = _label(16, Color(0.84, 0.88, 0.88), HORIZONTAL_ALIGNMENT_CENTER)
	summary_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(summary_text)
	var lobby := _action_button("RETURN TO LOBBY")
	lobby.pressed.connect(func() -> void: return_to_lobby_requested.emit())
	column.add_child(lobby)


func _show_results(result: ArenaMatchResult) -> void:
	var won := result.local_player_won()
	result_title.text = "VICTORY" if won else "DEFEAT"
	result_title.add_theme_color_override("font_color", ACCENT if won else Color(0.95, 0.25, 0.20))
	result_score.text = "BLUE  %d  —  %d  RED" % [result.team_a_score, result.team_b_score]
	var stats := result.local_player_stats()
	result_stats.text = "%s\n\nKILLS  %d     DEATHS  %d\nDAMAGE  %d     HEADSHOTS  %d\nBEST ROUND DAMAGE  %d\nROUNDS PLAYED  %d\n\n%s" % [String(result.mode_display_name), int(stats.get("kills", 0)), int(stats.get("deaths", 0)), int(stats.get("damage_dealt", 0)), int(stats.get("headshots", 0)), int(stats.get("highest_damage_round", 0)), result.rounds_played, "REWARD EXCHANGE AVAILABLE" if won and not result.abandoned else ("NO REWARDS — MATCH ABANDONED" if result.abandoned else "LOSS SUMMARY")]
	result_continue_button.text = "CONTINUE TO REWARDS" if won and not result.abandoned else "RETURN TO LOBBY"
	results_panel.visible = true
	reward_panel.visible = false
	summary_panel.visible = false
	result_continue_button.grab_focus()
	AudioEvents.play(&"victory" if won else &"defeat")


func _continue_from_results() -> void:
	if current_result == null or not current_result.local_player_won() or current_result.abandoned:
		return_to_lobby_requested.emit()
		return
	results_panel.visible = false
	reward_panel.visible = true
	simulation_warning.visible = simulation
	_refresh_reward_screen()
	_fade_panel(reward_panel)


func _refresh_reward_screen() -> void:
	_clear_children(opponent_grid)
	_clear_children(winner_grid)
	var used := current_result.exchange_count_for_owner(winner_inventory.owner_id)
	var remaining := maxi(0, current_result.max_reward_exchanges - used)
	reward_status.text = "%s  //  %d OF %d EXCHANGES REMAIN" % [String(current_result.mode_display_name), remaining, current_result.max_reward_exchanges]
	for opponent: ArenaTradeInventory in opponent_inventories:
		for entry: Dictionary in opponent.eligible_items(reward_service.item_index):
			if current_result.was_item_used(String(entry.instance_id)):
				continue
			_add_item_button(opponent_grid, entry, true, remaining <= 0)
	for entry: Dictionary in winner_inventory.eligible_items(reward_service.item_index):
		if current_result.was_item_used(String(entry.instance_id)):
			continue
		_add_item_button(winner_grid, entry, false, remaining <= 0)
	if opponent_grid.get_child_count() == 0:
		_add_empty_label(opponent_grid, "NO ELIGIBLE ITEMS")
	if winner_grid.get_child_count() == 0:
		_add_empty_label(winner_grid, "NO ELIGIBLE OFFER\nEXCHANGE UNAVAILABLE")
	confirm_button.disabled = remaining <= 0 or selected_take_id.is_empty() or selected_give_id.is_empty()
	finish_button.grab_focus()


func _add_item_button(grid: GridContainer, entry: Dictionary, taking: bool, disabled: bool) -> void:
	var definition := entry.definition as ItemDefinition
	var instance := entry.instance as ItemInstance
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 82)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.clip_text = true
	button.text = "%s\n%s  //  %d GOLD\n%s" % [definition.display_name.to_upper(), definition.get_rarity_name().to_upper(), definition.sell_value, _durability_text(instance)]
	button.icon = definition.preview_icon
	button.expand_icon = true
	button.tooltip_text = "Hover for full stats, affixes and effects"
	var accent := RARITY_COLORS[clampi(definition.rarity, 0, RARITY_COLORS.size() - 1)]
	button.set_meta("instance_id", String(entry.instance_id))
	button.set_meta("accent", accent)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.035, 0.044, 0.047), accent.darkened(0.45), 1, 7))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.055, 0.068, 0.072), accent, 2, 7))
	button.add_theme_stylebox_override("pressed", _panel_style(accent.darkened(0.72), accent, 2, 7))
	button.add_theme_color_override("font_color", accent)
	button.pressed.connect(_select_item.bind(entry, taking))
	button.mouse_entered.connect(_show_tooltip.bind(entry, taking))
	button.mouse_exited.connect(func() -> void: item_tooltip.hide_item())
	grid.add_child(button)


func _select_item(entry: Dictionary, taking: bool) -> void:
	if taking:
		selected_take_id = String(entry.instance_id)
		selected_take_owner_id = String(entry.owner_id)
		take_label.text = "TAKE\n" + _item_summary(entry.definition, entry.instance, String(entry.owner_name))
	else:
		selected_give_id = String(entry.instance_id)
		give_label.text = "GIVE\n" + _item_summary(entry.definition, entry.instance, winner_inventory.display_name)
	feedback_label.text = ""
	confirm_button.disabled = selected_take_id.is_empty() or selected_give_id.is_empty() or current_result.exchange_count_for_owner(winner_inventory.owner_id) >= current_result.max_reward_exchanges
	_update_selection_highlights()
	AudioEvents.play(&"ui_click")


func _request_confirmation() -> void:
	var opponent := _opponent_by_id(selected_take_owner_id)
	if opponent == null:
		_show_error("SELECT A VALID LOSING INVENTORY")
		return
	var take := opponent.get_instance(selected_take_id)
	var give := winner_inventory.get_instance(selected_give_id)
	if take == null or give == null:
		_show_error("SELECTION IS STALE — SELECT ITEMS AGAIN")
		_cancel_selection()
		return
	var take_definition := reward_service.item_index.get(String(take.definition_id)) as ItemDefinition
	var give_definition := reward_service.item_index.get(String(give.definition_id)) as ItemDefinition
	confirmation_dialog.dialog_text = "This exact exchange cannot be edited after confirmation.\n\nTAKE: %s (%s)\nGIVE: %s (%s)\n\nBoth inventories keep the same item count." % [take_definition.display_name, take_definition.get_rarity_name(), give_definition.display_name, give_definition.get_rarity_name()]
	confirmation_dialog.popup_centered(Vector2i(560, 300))


func _commit_selected_exchange() -> void:
	var opponent := _opponent_by_id(selected_take_owner_id)
	if opponent == null:
		_show_error("LOSING INVENTORY IS NO LONGER AVAILABLE")
		return
	var transaction_id := "%s:swap:%s:%d:%d" % [current_result.result_id, winner_inventory.owner_id, current_result.exchange_count_for_owner(winner_inventory.owner_id), Time.get_ticks_usec()]
	var transaction := ItemSwapTransaction.create(transaction_id, current_result.result_id, winner_inventory.owner_id, opponent.owner_id, selected_give_id, selected_take_id)
	var response := reward_service.commit_exchange(transaction, current_result, winner_inventory, opponent, persist_callback if not simulation else Callable())
	if not bool(response.get("ok", false)):
		_show_error(String(response.get("reason", "EXCHANGE REJECTED")))
		return
	var take_data := response.get("take", {}) as Dictionary
	var give_data := response.get("give", {}) as Dictionary
	var take_definition := reward_service.item_index.get(String(take_data.get("definition_id", ""))) as ItemDefinition
	var give_definition := reward_service.item_index.get(String(give_data.get("definition_id", ""))) as ItemDefinition
	exchange_summaries.append("TAKEN  %s  ⇄  GIVEN  %s  [%s]" % [take_definition.display_name, give_definition.display_name, opponent.display_name])
	feedback_label.add_theme_color_override("font_color", Color(0.35, 0.92, 0.64))
	feedback_label.text = "EXCHANGE COMMITTED ATOMICALLY" if not simulation else "SIMULATED EXCHANGE COMPLETE — NO PROFILE WAS SAVED"
	_cancel_selection(false)
	_refresh_reward_screen()
	_fade_panel(reward_panel)
	AudioEvents.play(&"ui_equip")


func _finish_rewards() -> void:
	var response := reward_service.finish_rewards(current_result, winner_inventory, opponent_inventories, persist_callback if not simulation else Callable())
	if not bool(response.get("ok", false)):
		_show_error(String(response.get("reason", "COULD NOT FINISH REWARDS")))
		return
	reward_panel.visible = false
	summary_panel.visible = true
	if exchange_summaries.is_empty():
		summary_text.text = "REWARDS SKIPPED\n\nNo items changed ownership."
	else:
		summary_text.text = "\n".join(exchange_summaries)
	if simulation:
		summary_text.text += "\n\nBOT SIMULATION ONLY — YOUR PERSISTENT PROFILE WAS NOT MODIFIED."
	_fade_panel(summary_panel)


func _cancel_selection(clear_feedback: bool = true) -> void:
	selected_take_id = ""
	selected_take_owner_id = ""
	selected_give_id = ""
	take_label.text = "TAKE  //  NOT SELECTED"
	give_label.text = "GIVE  //  NOT SELECTED"
	confirm_button.disabled = true
	if clear_feedback:
		feedback_label.text = ""
	_update_selection_highlights()


func _show_tooltip(entry: Dictionary, taking: bool) -> void:
	var comparison_instance: ItemInstance = null
	var comparison_definition: ItemDefinition = null
	if taking and not selected_give_id.is_empty():
		comparison_instance = winner_inventory.get_instance(selected_give_id)
	elif not taking and not selected_take_id.is_empty():
		var opponent := _opponent_by_id(selected_take_owner_id)
		comparison_instance = opponent.get_instance(selected_take_id) if opponent != null else null
	if comparison_instance != null:
		comparison_definition = reward_service.item_index.get(String(comparison_instance.definition_id)) as ItemDefinition
	item_tooltip.show_item(entry.definition as ItemDefinition, entry.instance as ItemInstance, comparison_definition, comparison_instance)


func _show_error(message: String) -> void:
	feedback_label.add_theme_color_override("font_color", Color(0.95, 0.28, 0.20))
	feedback_label.text = message
	AudioEvents.play(&"ui_invalid")


func _update_selection_highlights() -> void:
	for grid: GridContainer in [opponent_grid, winner_grid]:
		for child: Node in grid.get_children():
			if not child is Button:
				continue
			var button := child as Button
			var instance_id := String(button.get_meta("instance_id", ""))
			var accent := button.get_meta("accent", ACCENT) as Color
			var selected := instance_id == selected_take_id or instance_id == selected_give_id
			button.add_theme_stylebox_override("normal", _panel_style(accent.darkened(0.70) if selected else Color(0.035, 0.044, 0.047), accent if selected else accent.darkened(0.45), 2 if selected else 1, 7))


func _opponent_by_id(owner_id: String) -> ArenaTradeInventory:
	for opponent: ArenaTradeInventory in opponent_inventories:
		if opponent.owner_id == owner_id:
			return opponent
	return null


func _on_intro_updated(title: String, cue: String, match_point: bool) -> void:
	intro_label.text = ("MATCH POINT  //  " if match_point else "") + title
	cue_label.text = cue
	AudioEvents.play(&"fight" if cue == "FIGHT" else (&"match_point" if match_point and cue == "3" else &"round_countdown"))
	_fade_center()


func _on_round_started(_round_number: int) -> void:
	get_tree().create_timer(0.75).timeout.connect(func() -> void:
		intro_label.text = ""
		cue_label.text = ""
	)


func _on_round_ended(winner_team: int, _team_a: int, _team_b: int) -> void:
	var won := local_participant != null and local_participant.team_id == winner_team
	intro_label.text = "ROUND WON" if won else "ROUND LOST"
	cue_label.text = ""
	AudioEvents.play(&"round_won" if won else &"round_lost")
	_fade_center()


func _on_sudden_death() -> void:
	intro_label.text = "SUDDEN DEATH"
	cue_label.text = "NO HEALING"
	_fade_center()


func _on_spectator_requested(_local: ArenaParticipantState, teammates: Array[ArenaParticipantState]) -> void:
	spectator_label.visible = true
	spectator_label.text = "SPECTATING %s  //  A/D OR ARROWS TO CYCLE" % (teammates[0].display_name if not teammates.is_empty() else "TEAM")


func _on_round_reset(_round: int, _swap: bool) -> void:
	spectator_label.visible = false
	results_panel.visible = false
	reward_panel.visible = false
	summary_panel.visible = false


func _item_summary(definition: ItemDefinition, instance: ItemInstance, owner_name: String) -> String:
	var lines: Array[String] = [definition.display_name.to_upper(), "%s  //  %d GOLD" % [definition.get_rarity_name().to_upper(), definition.sell_value], "OWNER  %s" % owner_name]
	if instance.max_durability > 0.0:
		lines.append("DURABILITY  %d/%d" % [roundi(instance.current_durability), roundi(instance.max_durability)])
	if not instance.affix_ids.is_empty():
		var affixes: Array[String] = []
		for index: int in instance.affix_ids.size():
			affixes.append("%s T%d" % [String(instance.affix_ids[index]).to_upper(), instance.affix_tiers[index]])
		lines.append("AFFIXES  " + ", ".join(affixes))
	if not definition.special_description.is_empty():
		lines.append(definition.special_description)
	return "\n".join(lines)


func _durability_text(instance: ItemInstance) -> String:
	return "DUR %d/%d" % [roundi(instance.current_durability), roundi(instance.max_durability)] if instance.max_durability > 0.0 else "NO DURABILITY"


func _selection_card(text: String) -> Label:
	var label := _label(13, Color(0.88, 0.91, 0.91), HORIZONTAL_ALIGNMENT_CENTER)
	label.text = text
	label.custom_minimum_size = Vector2(0, 145)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _action_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 48)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.045, 0.055, 0.058), Color(0.28, 0.34, 0.35), 1, 8))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.06, 0.13, 0.15), ACCENT, 2, 8))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.11, 0.12, 0.07), GOLD, 2, 8))
	button.mouse_entered.connect(func() -> void: AudioEvents.play(&"ui_hover"))
	return button


func _label(font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result := Label.new()
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.horizontal_alignment = alignment
	return result


func _panel_style(background: Color, border: Color, width: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(margin)
	return style


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.free()


func _add_empty_label(grid: GridContainer, text: String) -> void:
	var label := _label(13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	label.text = text
	label.custom_minimum_size = Vector2(340, 90)
	grid.add_child(label)


func _fade_panel(panel: Control) -> void:
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.985, 0.985)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _fade_center() -> void:
	intro_label.modulate.a = 0.0
	cue_label.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(intro_label, "modulate:a", 1.0, 0.12)
	tween.tween_property(cue_label, "modulate:a", 1.0, 0.12)
