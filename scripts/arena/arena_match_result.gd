class_name ArenaMatchResult
extends RefCounted

var mode_id: StringName = &""
var mode_display_name: String = ""
var result_id: String = ""
var winner_team: int = -1
var loser_team: int = -1
var team_a_score: int = 0
var team_b_score: int = 0
var rounds_played: int = 0
var abandoned: bool = false
var participants: Array[Dictionary] = []
var max_reward_exchanges: int = 0
var rewards_processed: bool = false
var reward_transactions: Array[Dictionary] = []


func configure(
		mode: ArenaModeDefinition,
		p_winner_team: int,
		p_team_a_score: int,
		p_team_b_score: int,
		p_rounds_played: int,
		p_participants: Array[ArenaParticipantState],
		p_abandoned: bool = false,
		p_result_id: String = ""
) -> ArenaMatchResult:
	mode_id = mode.mode_id
	mode_display_name = mode.display_name
	result_id = p_result_id
	winner_team = p_winner_team
	loser_team = 1 - p_winner_team if p_winner_team in [0, 1] else -1
	team_a_score = p_team_a_score
	team_b_score = p_team_b_score
	rounds_played = p_rounds_played
	abandoned = p_abandoned
	max_reward_exchanges = mode.max_reward_exchanges
	rewards_processed = false
	reward_transactions.clear()
	participants.clear()
	for participant: ArenaParticipantState in p_participants:
		participants.append(participant.to_result_dictionary())
	return self


func local_player_won() -> bool:
	for participant: Dictionary in participants:
		if bool(participant.get("is_local_player", false)):
			return int(participant.get("team_id", -1)) == winner_team
	return false


func local_player_stats() -> Dictionary:
	for participant: Dictionary in participants:
		if bool(participant.get("is_local_player", false)):
			return participant
	return {}


func local_owner_id() -> String:
	for participant: Dictionary in participants:
		if bool(participant.get("is_local_player", false)):
			return String(participant.get("inventory_owner_id", ""))
	return ""


func is_owner_on_team(owner_id: String, team_id: int) -> bool:
	for participant: Dictionary in participants:
		if String(participant.get("inventory_owner_id", "")) == owner_id:
			return int(participant.get("team_id", -1)) == team_id
	return false


func owner_display_name(owner_id: String) -> String:
	for participant: Dictionary in participants:
		if String(participant.get("inventory_owner_id", "")) == owner_id:
			return String(participant.get("display_name", owner_id))
	return owner_id


func owner_ids_for_team(team_id: int) -> Array[String]:
	var result: Array[String] = []
	for participant: Dictionary in participants:
		if int(participant.get("team_id", -1)) == team_id:
			result.append(String(participant.get("inventory_owner_id", "")))
	return result


func exchange_count_for_owner(owner_id: String) -> int:
	var count := 0
	for transaction: Dictionary in reward_transactions:
		if String(transaction.get("winner_owner_id", "")) == owner_id:
			count += 1
	return count


func was_item_used(instance_id: String) -> bool:
	for transaction: Dictionary in reward_transactions:
		if String(transaction.get("give_instance_id", "")) == instance_id or String(transaction.get("take_instance_id", "")) == instance_id:
			return true
	return false
