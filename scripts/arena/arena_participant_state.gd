class_name ArenaParticipantState
extends RefCounted

var participant_id: StringName
var display_name: String
var team_id: int
var team_slot: int
var actor: Node3D
var is_local_player: bool
var alive: bool = true
var kills: int = 0
var deaths: int = 0
var damage_dealt: float = 0.0
var headshots: int = 0
var highest_damage_round: float = 0.0
var round_damage: float = 0.0
var inventory_owner_id: String = ""
var inventory_item_ids: Array[String] = []
var weapon_damage_by_family: Dictionary = {}
var weapon_hits_by_family: Dictionary = {}
var weapon_kills_by_family: Dictionary = {}


func _init(
		p_id: StringName = &"participant",
		p_display_name: String = "PARTICIPANT",
		p_team_id: int = 0,
		p_team_slot: int = 0,
		p_actor: Node3D = null,
		p_is_local: bool = false
) -> void:
	participant_id = p_id
	display_name = p_display_name
	team_id = p_team_id
	team_slot = p_team_slot
	actor = p_actor
	is_local_player = p_is_local


func reset_match_stats() -> void:
	alive = true
	kills = 0
	deaths = 0
	damage_dealt = 0.0
	headshots = 0
	highest_damage_round = 0.0
	round_damage = 0.0
	weapon_damage_by_family.clear()
	weapon_hits_by_family.clear()
	weapon_kills_by_family.clear()


func reset_for_round() -> void:
	alive = true
	round_damage = 0.0


func finish_round() -> void:
	highest_damage_round = maxf(highest_damage_round, round_damage)


func to_result_dictionary() -> Dictionary:
	return {
		"participant_id": String(participant_id),
		"display_name": display_name,
		"team_id": team_id,
		"is_local_player": is_local_player,
		"kills": kills,
		"deaths": deaths,
		"damage_dealt": damage_dealt,
		"headshots": headshots,
		"highest_damage_round": highest_damage_round,
		"inventory_owner_id": inventory_owner_id,
		"inventory_item_ids": inventory_item_ids.duplicate(),
		"weapon_damage_by_family": weapon_damage_by_family.duplicate(true),
		"weapon_hits_by_family": weapon_hits_by_family.duplicate(true),
		"weapon_kills_by_family": weapon_kills_by_family.duplicate(true),
	}
