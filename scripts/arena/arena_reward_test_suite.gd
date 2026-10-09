class_name ArenaRewardTestSuite
extends RefCounted

const WINNER_PATH := "user://arena_reward_winner_test.json"
const LOSER_PATH := "user://arena_reward_loser_test.json"

var service := ArenaRewardService.new(ItemDatabase.build_index())
var failures: Array[String] = []


func run() -> Array[String]:
	failures.clear()
	_test_exact_atomic_exchange()
	_test_protection_and_invalid_ownership()
	_test_limits_idempotency_and_skip()
	_test_full_inventory_exchange()
	_test_rollback()
	_test_persistence_restart()
	_test_bot_simulation_isolation()
	_test_abandonment_and_authoritative_gate()
	_test_2v2_individual_ownership()
	_cleanup_test_files()
	return failures.duplicate()


func _test_exact_atomic_exchange() -> void:
	var result := _make_result(preload("res://resources/arena/mode_1v1.tres"), "exact")
	var winner := _make_inventory("winner", "WINNER", ["rusty_katana"])
	var loser := _make_inventory("loser", "LOSER", ["skybreaker"])
	var give_id := _inventory_id(winner, 0)
	var take_id := _inventory_id(loser, 0)
	var take_before := loser.get_instance_data(take_id)
	var give_before := winner.get_instance_data(give_id)
	var winner_count := winner.inventory_count()
	var loser_count := loser.inventory_count()
	var transaction := ItemSwapTransaction.create("tx:exact", result.result_id, winner.owner_id, loser.owner_id, give_id, take_id)
	var response := service.commit_exchange(transaction, result, winner, loser)
	_expect(bool(response.get("ok", false)), "Winner could not receive the selected item")
	_expect(winner.get_instance_data(take_id) == take_before, "Taken exact ItemInstance, affixes or durability changed")
	_expect(loser.get_instance_data(give_id) == give_before, "Loser did not receive the exact offered ItemInstance")
	_expect(winner.inventory_count() == winner_count and loser.inventory_count() == loser_count, "Item counts changed after exchange")
	_expect(not winner.has_any_instance_id(give_id) and not loser.has_any_instance_id(take_id), "Old ownership remained after exchange")
	_expect(winner.validate_integrity().ok and loser.validate_integrity().ok, "Item IDs were no longer unique after exchange")
	var duplicate_response := service.commit_exchange(transaction, result, winner, loser)
	_expect(bool(duplicate_response.get("ok", false)) and bool(duplicate_response.get("idempotent", false)), "Duplicate transaction was not safely rejected as an idempotent replay")
	_expect(result.reward_transactions.size() == 1, "Duplicate transaction executed twice")
	var reused := ItemSwapTransaction.create("tx:reuse", result.result_id, winner.owner_id, loser.owner_id, take_id, give_id)
	_expect(not bool(service.commit_exchange(reused, result, winner, loser).get("ok", false)), "The same reward items could be selected twice")


func _test_protection_and_invalid_ownership() -> void:
	var result := _make_result(preload("res://resources/arena/mode_1v1.tres"), "protected")
	var winner := _make_inventory("winner", "WINNER", ["rusty_katana"])
	var loser := _make_inventory("loser", "LOSER", ["worn_assault_rifle"])
	var equipped_id := _inventory_id(loser, 0)
	loser.profile_data["weapon_instance_slots"] = [equipped_id, ""]
	var equipped_tx := ItemSwapTransaction.create("tx:equipped", result.result_id, winner.owner_id, loser.owner_id, _inventory_id(winner, 0), equipped_id)
	_expect(not bool(service.commit_exchange(equipped_tx, result, winner, loser).get("ok", false)), "Equipped weapon was tradable")
	var skill_loser := _make_inventory("loser", "LOSER", ["dash"])
	var skill_tx := ItemSwapTransaction.create("tx:skill", result.result_id, winner.owner_id, skill_loser.owner_id, _inventory_id(winner, 0), _inventory_id(skill_loser, 0))
	_expect(not bool(service.commit_exchange(skill_tx, result, winner, skill_loser).get("ok", false)), "Skill was tradable")
	var key_loser := _make_inventory("loser", "LOSER", ["extraction_key"])
	var key_tx := ItemSwapTransaction.create("tx:key", result.result_id, winner.owner_id, key_loser.owner_id, _inventory_id(winner, 0), _inventory_id(key_loser, 0))
	_expect(not bool(service.commit_exchange(key_tx, result, winner, key_loser).get("ok", false)), "Protected system item was tradable")
	var clean_loser := _make_inventory("loser", "LOSER", ["skybreaker"])
	var wrong_owner_tx := ItemSwapTransaction.create("tx:wrong-owner", result.result_id, "intruder", clean_loser.owner_id, _inventory_id(winner, 0), _inventory_id(clean_loser, 0))
	_expect(not bool(service.commit_exchange(wrong_owner_tx, result, winner, clean_loser).get("ok", false)), "Invalid winner ownership was accepted")
	var stale_tx := ItemSwapTransaction.create("tx:stale", result.result_id, winner.owner_id, clean_loser.owner_id, "missing", _inventory_id(clean_loser, 0))
	_expect(not bool(service.commit_exchange(stale_tx, result, winner, clean_loser).get("ok", false)), "Stale item reference was accepted")


func _test_limits_idempotency_and_skip() -> void:
	var result := _make_result(preload("res://resources/arena/mode_1v1.tres"), "limit")
	var winner := _make_inventory("winner", "WINNER", ["rusty_katana", "worn_assault_rifle", "cracked_long_rifle", "chipped_sword"])
	var loser := _make_inventory("loser", "LOSER", ["skybreaker", "vanguard_rifle", "ronin_katana", "knight_sword"])
	for index: int in 3:
		var transaction := ItemSwapTransaction.create("tx:limit:%d" % index, result.result_id, winner.owner_id, loser.owner_id, _inventory_id(winner, index), _inventory_id(loser, index))
		_expect(bool(service.commit_exchange(transaction, result, winner, loser).get("ok", false)), "Valid 1v1 exchange %d was rejected" % (index + 1))
	var fourth := ItemSwapTransaction.create("tx:limit:3", result.result_id, winner.owner_id, loser.owner_id, _inventory_id(winner, 3), _inventory_id(loser, 3))
	_expect(not bool(service.commit_exchange(fourth, result, winner, loser).get("ok", false)), "1v1 exchange limit above three was not enforced")
	var skip_result := _make_result(preload("res://resources/arena/mode_1v1.tres"), "skip")
	var skip_winner := _make_inventory("winner", "WINNER", ["rusty_katana"])
	var skip_loser := _make_inventory("loser", "LOSER", ["skybreaker"])
	var before_winner := skip_winner.snapshot()
	var before_loser := skip_loser.snapshot()
	var finish := service.finish_rewards(skip_result, skip_winner, [skip_loser])
	_expect(bool(finish.get("ok", false)) and skip_result.rewards_processed, "Winner could not skip rewards")
	_expect(_without_reward_history(skip_winner.snapshot()) == _without_reward_history(before_winner) and _without_reward_history(skip_loser.snapshot()) == _without_reward_history(before_loser), "Skipping rewards changed item ownership")
	var reopen := service.finish_rewards(skip_result, skip_winner, [skip_loser])
	_expect(bool(reopen.get("already_processed", false)), "Reopening results could process rewards again")


func _test_rollback() -> void:
	var result := _make_result(preload("res://resources/arena/mode_1v1.tres"), "rollback")
	var winner := _make_inventory("winner", "WINNER", ["rusty_katana"])
	var loser := _make_inventory("loser", "LOSER", ["skybreaker"])
	var winner_before := winner.snapshot()
	var loser_before := loser.snapshot()
	var persist_state := {"calls": 0}
	var failing_persist := func(_owner_id: String, _data: Dictionary) -> bool:
		persist_state.calls = int(persist_state.calls) + 1
		return int(persist_state.calls) != 2
	var transaction := ItemSwapTransaction.create("tx:rollback", result.result_id, winner.owner_id, loser.owner_id, _inventory_id(winner, 0), _inventory_id(loser, 0))
	var response := service.commit_exchange(transaction, result, winner, loser, failing_persist)
	_expect(not bool(response.get("ok", false)), "Persistence failure incorrectly reported success")
	_expect(winner.snapshot() == winner_before and loser.snapshot() == loser_before, "Persistence failure did not roll both inventories back")
	_expect(result.reward_transactions.is_empty(), "Failed transaction was recorded as a reward")


func _test_full_inventory_exchange() -> void:
	var winner_ids: Array[String] = []
	var loser_ids: Array[String] = []
	var pool: Array[String] = ["rusty_katana", "worn_assault_rifle", "cracked_long_rifle", "chipped_sword"]
	var opponent_pool: Array[String] = ["skybreaker", "vanguard_rifle", "ronin_katana", "knight_sword"]
	for index: int in PlayerProfile.INVENTORY_SIZE:
		winner_ids.append(pool[index % pool.size()])
		loser_ids.append(opponent_pool[index % opponent_pool.size()])
	var result := _make_result(preload("res://resources/arena/mode_1v1.tres"), "full")
	var winner := _make_inventory("winner", "WINNER", winner_ids)
	var loser := _make_inventory("loser", "LOSER", loser_ids)
	var transaction := ItemSwapTransaction.create("tx:full", result.result_id, winner.owner_id, loser.owner_id, _inventory_id(winner, 23), _inventory_id(loser, 23))
	_expect(bool(service.commit_exchange(transaction, result, winner, loser).get("ok", false)), "Full 24-slot inventories could not exchange item-for-item")
	_expect(winner.inventory_count() == 24 and loser.inventory_count() == 24, "Full inventory exchange changed capacity")


func _test_persistence_restart() -> void:
	_cleanup_test_files()
	var result := _make_result(preload("res://resources/arena/mode_1v1.tres"), "restart")
	var winner := _make_inventory("winner", "WINNER", ["rusty_katana"])
	var loser := _make_inventory("loser", "LOSER", ["skybreaker"])
	var give_id := _inventory_id(winner, 0)
	var take_id := _inventory_id(loser, 0)
	var paths := {winner.owner_id: WINNER_PATH, loser.owner_id: LOSER_PATH}
	var persist := func(owner_id: String, data: Dictionary) -> bool:
		return PlayerProfile.save_profile_data(data, String(paths[owner_id]))
	var transaction := ItemSwapTransaction.create("tx:restart", result.result_id, winner.owner_id, loser.owner_id, give_id, take_id)
	var response := service.commit_exchange(transaction, result, winner, loser, persist)
	_expect(bool(response.get("ok", false)), "Persistent test-profile exchange failed")
	_expect(bool(service.finish_rewards(result, winner, [loser], persist).get("ok", false)), "Persistent reward completion failed")
	var winner_reloaded := ArenaTradeInventory.new("winner", "WINNER", _read_json(WINNER_PATH))
	var loser_reloaded := ArenaTradeInventory.new("loser", "LOSER", _read_json(LOSER_PATH))
	_expect(winner_reloaded.has_any_instance_id(take_id) and loser_reloaded.has_any_instance_id(give_id), "Save/restart did not preserve committed ownership")
	_expect(winner_reloaded.has_completed_transaction(transaction.transaction_id) and loser_reloaded.has_completed_transaction(transaction.transaction_id), "Save/restart lost idempotency history")
	_expect(winner_reloaded.has_processed_result(result.result_id) and loser_reloaded.has_processed_result(result.result_id), "Save/restart lost processed-result guard")


func _test_bot_simulation_isolation() -> void:
	var real_before := PlayerProfile.to_save_data()
	var result := _make_result(preload("res://resources/arena/mode_1v1.tres"), "bot-sim")
	var winner := _make_inventory("winner", "WINNER", ["rusty_katana"])
	var bot := ArenaBotRewardFactory.create_inventory("loser", "BOT", result.result_id, 8)
	var bot_items := bot.eligible_items(service.item_index)
	_expect(not bot_items.is_empty(), "Synthetic bot reward inventory was empty")
	if not bot_items.is_empty():
		var transaction := ItemSwapTransaction.create("tx:bot-sim", result.result_id, winner.owner_id, bot.owner_id, _inventory_id(winner, 0), String(bot_items[0].instance_id))
		_expect(bool(service.commit_exchange(transaction, result, winner, bot).get("ok", false)), "Synthetic bot exchange preview failed")
	_expect(PlayerProfile.to_save_data() == real_before, "Bot simulation modified the real PlayerProfile")
	for entry: Dictionary in bot.eligible_items(service.item_index):
		var definition := entry.definition as ItemDefinition
		_expect(definition.rarity <= ItemDefinition.Rarity.RARE, "Synthetic bot inventory generated farmable Legendary/Mythic loot")


func _test_abandonment_and_authoritative_gate() -> void:
	var abandoned := _make_result(preload("res://resources/arena/mode_1v1.tres"), "abandon", true)
	var winner := _make_inventory("winner", "WINNER", ["rusty_katana"])
	var loser := _make_inventory("loser", "LOSER", ["skybreaker"])
	var transaction := ItemSwapTransaction.create("tx:abandon", abandoned.result_id, winner.owner_id, loser.owner_id, _inventory_id(winner, 0), _inventory_id(loser, 0))
	_expect(not bool(service.commit_exchange(transaction, abandoned, winner, loser).get("ok", false)), "Abandonment granted a reward exchange")
	var manager := ArenaMatchManager.new()
	manager.configure(preload("res://resources/arena/mode_1v1.tres"))
	var gate_actors: Array[Node3D] = []
	for index: int in 2:
		var actor := Node3D.new()
		gate_actors.append(actor)
		manager.register_participant(ArenaParticipantState.new(StringName("gate_%d" % index), "GATE", index, 0, actor, index == 0))
	manager.begin_match(true)
	_expect(manager.latest_result == null and manager.state == ArenaMatchManager.STATE_ROUND_ACTIVE, "Rewards became available before the full match finished")
	manager.free()
	for actor: Node3D in gate_actors:
		actor.free()


func _test_2v2_individual_ownership() -> void:
	var result := _make_result(preload("res://resources/arena/mode_2v2.tres"), "team")
	var winner := _make_inventory("winner", "WINNER", ["rusty_katana", "worn_assault_rifle", "cracked_long_rifle"])
	var enemy_two := _make_inventory("enemy_two", "ENEMY TWO", ["skybreaker", "ronin_katana", "vanguard_rifle"])
	for index: int in 2:
		var transaction := ItemSwapTransaction.create("tx:team:%d" % index, result.result_id, winner.owner_id, enemy_two.owner_id, _inventory_id(winner, index), _inventory_id(enemy_two, index))
		_expect(bool(service.commit_exchange(transaction, result, winner, enemy_two).get("ok", false)), "Valid 2v2 individual-owner exchange failed")
	var third := ItemSwapTransaction.create("tx:team:2", result.result_id, winner.owner_id, enemy_two.owner_id, _inventory_id(winner, 2), _inventory_id(enemy_two, 2))
	_expect(not bool(service.commit_exchange(third, result, winner, enemy_two).get("ok", false)), "2v2 per-winner limit above two was not enforced")
	var ally := _make_inventory("ally", "ALLY", ["knight_sword"])
	var ally_result := _make_result(preload("res://resources/arena/mode_2v2.tres"), "ally-check")
	var clean_winner := _make_inventory("winner", "WINNER", ["rusty_katana"])
	var ally_tx := ItemSwapTransaction.create("tx:ally", ally_result.result_id, clean_winner.owner_id, ally.owner_id, _inventory_id(clean_winner, 0), _inventory_id(ally, 0))
	_expect(not bool(service.commit_exchange(ally_tx, ally_result, clean_winner, ally).get("ok", false)), "2v2 pooled an ally inventory into opponent loot")


func _make_result(mode: ArenaModeDefinition, suffix: String, abandoned: bool = false) -> ArenaMatchResult:
	var participants: Array[ArenaParticipantState] = []
	var winner := ArenaParticipantState.new(&"winner", "WINNER", 0, 0, null, true)
	winner.inventory_owner_id = "winner"
	participants.append(winner)
	if mode.team_size == 2:
		var ally := ArenaParticipantState.new(&"ally", "ALLY", 0, 1)
		ally.inventory_owner_id = "ally"
		participants.append(ally)
	var loser := ArenaParticipantState.new(&"loser", "LOSER", 1, 0)
	loser.inventory_owner_id = "loser"
	participants.append(loser)
	if mode.team_size == 2:
		var enemy_two := ArenaParticipantState.new(&"enemy_two", "ENEMY TWO", 1, 1)
		enemy_two.inventory_owner_id = "enemy_two"
		participants.append(enemy_two)
	return ArenaMatchResult.new().configure(mode, 0, mode.rounds_to_win, 0, mode.rounds_to_win, participants, abandoned, "result:%s" % suffix)


func _make_inventory(owner_id: String, display_name: String, definition_ids: Array[String]) -> ArenaTradeInventory:
	var data := _namespace_profile(PlayerProfile.to_save_data(), owner_id)
	var inventory: Array[String] = []
	inventory.resize(PlayerProfile.INVENTORY_SIZE)
	inventory.fill("")
	var owned: Array = (data.get("owned_item_instances", []) as Array).duplicate(true)
	var owned_ids: Array = (data.get("owned_item_ids", []) as Array).duplicate()
	for slot: int in definition_ids.size():
		var definition := service.item_index.get(definition_ids[slot]) as ItemDefinition
		var instance := ItemInstance.create(definition, "test:%s:%02d:%s" % [owner_id, slot, definition_ids[slot]])
		if definition.id == &"skybreaker":
			instance.current_durability = 37.0
		owned.append(instance.to_dictionary())
		inventory[slot] = instance.instance_id
		if not owned_ids.has(String(definition.id)):
			owned_ids.append(String(definition.id))
	data["main_inventory"] = inventory
	data["owned_item_instances"] = owned
	data["owned_item_ids"] = owned_ids
	data["arena_completed_transaction_ids"] = []
	data["arena_processed_result_ids"] = []
	return ArenaTradeInventory.new(owner_id, display_name, data)


func _namespace_profile(source: Dictionary, owner_id: String) -> Dictionary:
	var data := source.duplicate(true)
	var replacements: Dictionary = {}
	for group_name: String in ["owned_item_instances", "pending_reward_instances"]:
		var renamed: Array = []
		for entry: Variant in data.get(group_name, []):
			var item := (entry as Dictionary).duplicate(true)
			var old_id := String(item.get("instance_id", ""))
			var new_id := "base:%s:%s" % [owner_id, old_id]
			replacements[old_id] = new_id
			item["instance_id"] = new_id
			renamed.append(item)
		data[group_name] = renamed
	var weapon_refs: Array = data.get("weapon_instance_slots", []) as Array
	for index: int in weapon_refs.size():
		weapon_refs[index] = String(replacements.get(String(weapon_refs[index]), String(weapon_refs[index])))
	data["weapon_instance_slots"] = weapon_refs
	var gear_refs: Dictionary = data.get("equipped_gear_instances", {}) as Dictionary
	for key: Variant in gear_refs.keys():
		gear_refs[key] = String(replacements.get(String(gear_refs[key]), String(gear_refs[key])))
	data["equipped_gear_instances"] = gear_refs
	return data


func _inventory_id(inventory: ArenaTradeInventory, slot: int) -> String:
	return String((inventory.profile_data.get("main_inventory", []) as Array)[slot])


func _without_reward_history(data: Dictionary) -> Dictionary:
	var copy := data.duplicate(true)
	copy["arena_completed_transaction_ids"] = []
	copy["arena_processed_result_ids"] = []
	return copy


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _cleanup_test_files() -> void:
	for path: String in [WINNER_PATH, LOSER_PATH, WINNER_PATH + ".backup", LOSER_PATH + ".backup", WINNER_PATH + ".tmp", LOSER_PATH + ".tmp"]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
