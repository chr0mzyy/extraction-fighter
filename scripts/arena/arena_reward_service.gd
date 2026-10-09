class_name ArenaRewardService
extends RefCounted

var item_index: Dictionary


func _init(p_item_index: Dictionary = {}) -> void:
	item_index = p_item_index if not p_item_index.is_empty() else ItemDatabase.build_index()


func commit_exchange(
		transaction: ItemSwapTransaction,
		result: ArenaMatchResult,
		winner: ArenaTradeInventory,
		loser: ArenaTradeInventory,
		persist_callback: Callable = Callable()
) -> Dictionary:
	var validation := _validate_exchange(transaction, result, winner, loser)
	if not bool(validation.get("ok", false)):
		transaction.failure_reason = String(validation.get("reason", "INVALID EXCHANGE"))
		return validation
	if bool(validation.get("idempotent", false)):
		transaction.committed = true
		transaction.idempotent_replay = true
		return validation
	var winner_before := winner.snapshot()
	var loser_before := loser.snapshot()
	var winner_count := winner.inventory_count()
	var loser_count := loser.inventory_count()
	var take_data := loser.get_instance_data(transaction.take_instance_id)
	var give_data := winner.get_instance_data(transaction.give_instance_id)
	if winner.swap_inventory_instance(transaction.give_instance_id, take_data).is_empty() or loser.swap_inventory_instance(transaction.take_instance_id, give_data).is_empty():
		winner.restore(winner_before)
		loser.restore(loser_before)
		return _fail(transaction, "ATOMIC SWAP COULD NOT BE APPLIED")
	winner.add_completed_transaction(transaction.transaction_id)
	loser.add_completed_transaction(transaction.transaction_id)
	var integrity := _validate_pair_integrity(winner, loser, winner_count, loser_count)
	if not bool(integrity.get("ok", false)):
		winner.restore(winner_before)
		loser.restore(loser_before)
		return _fail(transaction, String(integrity.get("reason", "INTEGRITY CHECK FAILED")))
	if persist_callback.is_valid():
		if not bool(persist_callback.call(winner.owner_id, winner.snapshot())):
			winner.restore(winner_before)
			loser.restore(loser_before)
			return _fail(transaction, "WINNER PROFILE PERSISTENCE FAILED")
		if not bool(persist_callback.call(loser.owner_id, loser.snapshot())):
			winner.restore(winner_before)
			loser.restore(loser_before)
			persist_callback.call(winner.owner_id, winner_before)
			return _fail(transaction, "LOSER PROFILE PERSISTENCE FAILED; EXCHANGE ROLLED BACK")
	result.reward_transactions.append(transaction.to_dictionary())
	transaction.committed = true
	transaction.failure_reason = ""
	return {
		"ok": true,
		"reason": "",
		"transaction_id": transaction.transaction_id,
		"take": take_data,
		"give": give_data,
		"swaps_remaining": maxi(0, result.max_reward_exchanges - result.exchange_count_for_owner(winner.owner_id)),
	}


func finish_rewards(
		result: ArenaMatchResult,
		winner: ArenaTradeInventory,
		opponents: Array[ArenaTradeInventory],
		persist_callback: Callable = Callable()
) -> Dictionary:
	if result == null or result.result_id.is_empty() or result.abandoned:
		return {"ok": false, "reason": "ABANDONED OR INVALID RESULT"}
	if result.rewards_processed or winner.has_processed_result(result.result_id):
		return {"ok": true, "already_processed": true}
	var snapshots: Dictionary = {winner.owner_id: winner.snapshot()}
	winner.add_processed_result(result.result_id)
	for opponent: ArenaTradeInventory in opponents:
		snapshots[opponent.owner_id] = opponent.snapshot()
		opponent.add_processed_result(result.result_id)
	if persist_callback.is_valid():
		var persisted: Array[ArenaTradeInventory] = []
		var owners: Array[ArenaTradeInventory] = [winner]
		owners.append_array(opponents)
		for owner: ArenaTradeInventory in owners:
			if bool(persist_callback.call(owner.owner_id, owner.snapshot())):
				persisted.append(owner)
				continue
			for rollback_owner: ArenaTradeInventory in owners:
				rollback_owner.restore(snapshots[rollback_owner.owner_id])
			for rollback_owner: ArenaTradeInventory in persisted:
				persist_callback.call(rollback_owner.owner_id, snapshots[rollback_owner.owner_id])
			return {"ok": false, "reason": "RESULT PERSISTENCE FAILED; COMPLETION ROLLED BACK"}
	result.rewards_processed = true
	return {"ok": true, "already_processed": false}


func _validate_exchange(transaction: ItemSwapTransaction, result: ArenaMatchResult, winner: ArenaTradeInventory, loser: ArenaTradeInventory) -> Dictionary:
	if transaction == null or result == null or winner == null or loser == null:
		return {"ok": false, "reason": "MISSING TRANSACTION DATA"}
	if transaction.transaction_id.is_empty() or transaction.result_id != result.result_id:
		return {"ok": false, "reason": "INVALID TRANSACTION IDENTITY"}
	if winner.has_completed_transaction(transaction.transaction_id) and loser.has_completed_transaction(transaction.transaction_id):
		return {"ok": true, "idempotent": true, "reason": "ALREADY COMMITTED"}
	if winner.has_completed_transaction(transaction.transaction_id) != loser.has_completed_transaction(transaction.transaction_id):
		return {"ok": false, "reason": "INCONSISTENT TRANSACTION HISTORY"}
	if result.abandoned or result.rewards_processed or winner.has_processed_result(result.result_id):
		return {"ok": false, "reason": "REWARDS ARE NOT AVAILABLE FOR THIS RESULT"}
	if transaction.winner_owner_id != winner.owner_id or transaction.loser_owner_id != loser.owner_id:
		return {"ok": false, "reason": "OWNER IDENTITY MISMATCH"}
	var winner_integrity := winner.validate_integrity()
	var loser_integrity := loser.validate_integrity()
	if not bool(winner_integrity.get("ok", false)):
		return {"ok": false, "reason": "WINNER PROFILE: %s" % String(winner_integrity.get("reason", "INVALID"))}
	if not bool(loser_integrity.get("ok", false)):
		return {"ok": false, "reason": "LOSER PROFILE: %s" % String(loser_integrity.get("reason", "INVALID"))}
	if not result.is_owner_on_team(winner.owner_id, result.winner_team) or not result.is_owner_on_team(loser.owner_id, result.loser_team):
		return {"ok": false, "reason": "MATCH WINNER OR LOSER VALIDATION FAILED"}
	if result.exchange_count_for_owner(winner.owner_id) >= result.max_reward_exchanges:
		return {"ok": false, "reason": "EXCHANGE LIMIT REACHED"}
	if transaction.give_instance_id == transaction.take_instance_id:
		return {"ok": false, "reason": "AN ITEM CANNOT BE TRADED FOR ITSELF"}
	if result.was_item_used(transaction.give_instance_id) or result.was_item_used(transaction.take_instance_id):
		return {"ok": false, "reason": "ITEM WAS ALREADY USED IN THIS REWARD"}
	var give_eligibility := winner.eligibility(transaction.give_instance_id, item_index)
	if not bool(give_eligibility.get("ok", false)):
		return {"ok": false, "reason": "GIVE: %s" % String(give_eligibility.get("reason", "INVALID"))}
	var take_eligibility := loser.eligibility(transaction.take_instance_id, item_index)
	if not bool(take_eligibility.get("ok", false)):
		return {"ok": false, "reason": "TAKE: %s" % String(take_eligibility.get("reason", "INVALID"))}
	if loser.has_any_instance_id(transaction.give_instance_id) or winner.has_any_instance_id(transaction.take_instance_id):
		return {"ok": false, "reason": "DUPLICATE INSTANCE ID ACROSS OWNERS"}
	return {"ok": true, "reason": ""}


func _validate_pair_integrity(winner: ArenaTradeInventory, loser: ArenaTradeInventory, winner_count: int, loser_count: int) -> Dictionary:
	if winner.inventory_count() != winner_count or loser.inventory_count() != loser_count:
		return {"ok": false, "reason": "INVENTORY ITEM COUNT CHANGED"}
	var winner_integrity := winner.validate_integrity()
	if not bool(winner_integrity.get("ok", false)):
		return winner_integrity
	var loser_integrity := loser.validate_integrity()
	if not bool(loser_integrity.get("ok", false)):
		return loser_integrity
	var seen: Dictionary = {}
	for owner: ArenaTradeInventory in [winner, loser]:
		for group_name: String in ["owned_item_instances", "pending_reward_instances"]:
			for entry: Variant in owner.profile_data.get(group_name, []):
				var instance_id := String((entry as Dictionary).get("instance_id", ""))
				if seen.has(instance_id):
					return {"ok": false, "reason": "CROSS-OWNER DUPLICATE INSTANCE ID"}
				seen[instance_id] = true
	return {"ok": true, "reason": ""}


func _fail(transaction: ItemSwapTransaction, reason: String) -> Dictionary:
	transaction.failure_reason = reason
	return {"ok": false, "reason": reason}
