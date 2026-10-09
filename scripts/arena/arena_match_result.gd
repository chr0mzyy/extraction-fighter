class_name ArenaMatchResult
extends RefCounted

var mode_id: StringName = &""
var mode_display_name: String = ""
var winner_team: int = -1
var loser_team: int = -1
var team_a_score: int = 0
var team_b_score: int = 0
var rounds_played: int = 0
var abandoned: bool = false
var participants: Array[Dictionary] = []


func configure(
		mode: ArenaModeDefinition,
		p_winner_team: int,
		p_team_a_score: int,
		p_team_b_score: int,
		p_rounds_played: int,
		p_participants: Array[ArenaParticipantState],
		p_abandoned: bool = false
) -> ArenaMatchResult:
	mode_id = mode.mode_id
	mode_display_name = mode.display_name
	winner_team = p_winner_team
	loser_team = 1 - p_winner_team if p_winner_team in [0, 1] else -1
	team_a_score = p_team_a_score
	team_b_score = p_team_b_score
	rounds_played = p_rounds_played
	abandoned = p_abandoned
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
