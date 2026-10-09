class_name ItemSwapTransaction
extends RefCounted

var transaction_id: String = ""
var result_id: String = ""
var winner_owner_id: String = ""
var loser_owner_id: String = ""
var give_instance_id: String = ""
var take_instance_id: String = ""
var committed: bool = false
var idempotent_replay: bool = false
var failure_reason: String = ""


static func create(
		p_transaction_id: String,
		p_result_id: String,
		p_winner_owner_id: String,
		p_loser_owner_id: String,
		p_give_instance_id: String,
		p_take_instance_id: String
) -> ItemSwapTransaction:
	var result := ItemSwapTransaction.new()
	result.transaction_id = p_transaction_id
	result.result_id = p_result_id
	result.winner_owner_id = p_winner_owner_id
	result.loser_owner_id = p_loser_owner_id
	result.give_instance_id = p_give_instance_id
	result.take_instance_id = p_take_instance_id
	return result


func to_dictionary() -> Dictionary:
	return {
		"transaction_id": transaction_id,
		"result_id": result_id,
		"winner_owner_id": winner_owner_id,
		"loser_owner_id": loser_owner_id,
		"give_instance_id": give_instance_id,
		"take_instance_id": take_instance_id,
	}
