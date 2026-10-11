class_name ArenaMatchManager
extends Node

signal state_changed(new_state: StringName)
signal combat_lock_changed(locked: bool)
signal healing_lock_changed(locked: bool)
signal round_reset_requested(round_number: int, swap_sides: bool)
signal intro_updated(title: String, cue: String, match_point: bool)
signal round_started(round_number: int)
signal round_ended(winner_team: int, team_a_score: int, team_b_score: int)
signal spectator_requested(local_participant: ArenaParticipantState, living_teammates: Array[ArenaParticipantState])
signal sudden_death_started
signal pressure_tick(damage: float)
signal match_ended(result: ArenaMatchResult)
signal results_ready(result: ArenaMatchResult)
signal timer_changed(remaining: float)
signal stats_changed

const TEAM_A := 0
const TEAM_B := 1
const STATE_PRE_MATCH: StringName = &"PRE_MATCH"
const STATE_ROUND_INTRO: StringName = &"ROUND_INTRO"
const STATE_ROUND_ACTIVE: StringName = &"ROUND_ACTIVE"
const STATE_SUDDEN_DEATH: StringName = &"SUDDEN_DEATH"
const STATE_ROUND_END: StringName = &"ROUND_END"
const STATE_MATCH_END: StringName = &"MATCH_END"
const STATE_RESULTS: StringName = &"RESULTS"

const INTRO_DURATION := 3.0
const ROUND_END_DURATION := 2.5
const MATCH_END_DURATION := 1.6
const SUDDEN_DEATH_GRACE := 10.0
const PRESSURE_INTERVAL := 1.5
const PRESSURE_DAMAGE := 5.0

var mode: ArenaModeDefinition
var participants: Array[ArenaParticipantState] = []
var state: StringName = STATE_PRE_MATCH
var round_number: int = 0
var team_a_score: int = 0
var team_b_score: int = 0
var round_time_remaining: float = 0.0
var phase_remaining: float = 0.0
var sudden_death_grace_remaining: float = 0.0
var pressure_remaining: float = PRESSURE_INTERVAL
var loadout_locked: bool = false
var friendly_fire_enabled: bool = false
var latest_result: ArenaMatchResult
var match_result_id: String = ""
var _last_intro_cue: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func configure(p_mode: ArenaModeDefinition) -> bool:
	if p_mode == null or not p_mode.is_valid():
		return false
	mode = p_mode
	return true


func register_participant(participant: ArenaParticipantState) -> bool:
	if participant == null or participant.actor == null or participant.team_id not in [TEAM_A, TEAM_B]:
		return false
	if participant_for_actor(participant.actor) != null:
		return false
	participants.append(participant)
	return true


func begin_match(skip_intro: bool = false) -> bool:
	if mode == null or participants.is_empty():
		return false
	team_a_score = 0
	team_b_score = 0
	round_number = 0
	latest_result = null
	match_result_id = "arena:%s:%d:%d" % [String(mode.mode_id), Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	loadout_locked = true
	for participant: ArenaParticipantState in participants:
		participant.reset_match_stats()
	set_process(true)
	_begin_next_round(skip_intro)
	return true


func rematch(skip_intro: bool = false) -> bool:
	return begin_match(skip_intro)


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	match state:
		STATE_ROUND_INTRO:
			phase_remaining = maxf(0.0, phase_remaining - delta)
			_update_intro_cue()
			if phase_remaining <= 0.0:
				_activate_round()
		STATE_ROUND_ACTIVE:
			round_time_remaining = maxf(0.0, round_time_remaining - delta)
			timer_changed.emit(round_time_remaining)
			if round_time_remaining <= 0.0:
				_resolve_timeout()
		STATE_SUDDEN_DEATH:
			sudden_death_grace_remaining = maxf(0.0, sudden_death_grace_remaining - delta)
			if sudden_death_grace_remaining <= 0.0:
				pressure_remaining -= delta
				if pressure_remaining <= 0.0:
					pressure_remaining = PRESSURE_INTERVAL
					pressure_tick.emit(PRESSURE_DAMAGE)
		STATE_ROUND_END:
			phase_remaining = maxf(0.0, phase_remaining - delta)
			if phase_remaining <= 0.0:
				if _match_winner() >= 0:
					_finish_match(_match_winner(), false)
				else:
					_begin_next_round(false)
		STATE_MATCH_END:
			phase_remaining = maxf(0.0, phase_remaining - delta)
			if phase_remaining <= 0.0:
				_set_state(STATE_RESULTS)
				results_ready.emit(latest_result)


func _process(delta: float) -> void:
	advance(delta)


func report_death(actor: Node, info: DamageInfo = null) -> void:
	if state not in [STATE_ROUND_ACTIVE, STATE_SUDDEN_DEATH]:
		return
	var victim := participant_for_actor(actor)
	if victim == null or not victim.alive:
		return
	victim.alive = false
	victim.deaths += 1
	if info != null:
		var killer := participant_for_actor(info.attacker)
		if killer != null and killer.team_id != victim.team_id:
			killer.kills += 1
			var kill_family := String(info.weapon_family)
			if not kill_family.is_empty():
				killer.weapon_kills_by_family[kill_family] = int(killer.weapon_kills_by_family.get(kill_family, 0)) + 1
	stats_changed.emit()
	if victim.is_local_player:
		var teammates := living_participants(victim.team_id)
		if not teammates.is_empty():
			spectator_requested.emit(victim, teammates)
	var team_a_alive := alive_count(TEAM_A)
	var team_b_alive := alive_count(TEAM_B)
	if team_a_alive <= 0 and team_b_alive > 0:
		_finish_round(TEAM_B)
	elif team_b_alive <= 0 and team_a_alive > 0:
		_finish_round(TEAM_A)


func record_damage(info: DamageInfo, applied_amount: float) -> void:
	if info == null or applied_amount <= 0.0:
		return
	var attacker := participant_for_actor(info.attacker)
	if attacker == null:
		return
	attacker.damage_dealt += applied_amount
	attacker.round_damage += applied_amount
	var family := String(info.weapon_family)
	if not family.is_empty():
		attacker.weapon_damage_by_family[family] = float(attacker.weapon_damage_by_family.get(family, 0.0)) + applied_amount
		attacker.weapon_hits_by_family[family] = int(attacker.weapon_hits_by_family.get(family, 0)) + 1
	if info.headshot:
		attacker.headshots += 1
	stats_changed.emit()


func abandon(local_team: int = TEAM_A) -> ArenaMatchResult:
	if state in [STATE_MATCH_END, STATE_RESULTS] and latest_result != null:
		return latest_result
	_finish_match(TEAM_B if local_team == TEAM_A else TEAM_A, true)
	return latest_result


func resolve_timeout_now() -> void:
	if state == STATE_ROUND_ACTIVE:
		_resolve_timeout()


func force_round_winner(team_id: int) -> void:
	if state in [STATE_ROUND_INTRO, STATE_ROUND_ACTIVE, STATE_SUDDEN_DEATH] and team_id in [TEAM_A, TEAM_B]:
		_finish_round(team_id)


func finish_transition_now() -> void:
	if state in [STATE_ROUND_END, STATE_MATCH_END]:
		advance(maxf(phase_remaining, 0.0) + 0.01)


func participant_for_actor(actor: Node) -> ArenaParticipantState:
	if actor == null:
		return null
	for participant: ArenaParticipantState in participants:
		if participant.actor == actor:
			return participant
	return null


func living_participants(team_id: int) -> Array[ArenaParticipantState]:
	var result: Array[ArenaParticipantState] = []
	for participant: ArenaParticipantState in participants:
		if participant.team_id == team_id and participant.alive:
			result.append(participant)
	return result


func alive_count(team_id: int) -> int:
	return living_participants(team_id).size()


func score_for_team(team_id: int) -> int:
	return team_a_score if team_id == TEAM_A else team_b_score


func is_match_point() -> bool:
	if mode == null:
		return false
	return team_a_score == mode.rounds_to_win - 1 or team_b_score == mode.rounds_to_win - 1


func get_header_text() -> String:
	if mode == null:
		return "ARENA"
	var timer_text := _format_time(round_time_remaining)
	return "BLUE  %d     -     %d  RED     //     ROUND %d     //     %s" % [team_a_score, team_b_score, round_number, timer_text]


func get_debug_snapshot() -> Dictionary:
	return {
		"mode": String(mode.mode_id) if mode != null else "NONE",
		"round": round_number,
		"score": "%d-%d" % [team_a_score, team_b_score],
		"timer": round_time_remaining,
		"state": String(state),
		"team_a_alive": alive_count(TEAM_A),
		"team_b_alive": alive_count(TEAM_B),
		"friendly_fire": friendly_fire_enabled,
	}


func _begin_next_round(skip_intro: bool) -> void:
	round_number += 1
	for participant: ArenaParticipantState in participants:
		participant.reset_for_round()
	round_time_remaining = mode.round_time_limit
	phase_remaining = 0.0 if skip_intro else INTRO_DURATION
	_last_intro_cue = ""
	healing_lock_changed.emit(false)
	combat_lock_changed.emit(true)
	round_reset_requested.emit(round_number, round_number % 2 == 0)
	if skip_intro:
		_activate_round()
	else:
		_set_state(STATE_ROUND_INTRO)
		_update_intro_cue()


func _update_intro_cue() -> void:
	var cue := str(maxi(1, ceili(phase_remaining)))
	if cue == _last_intro_cue:
		return
	_last_intro_cue = cue
	intro_updated.emit("ROUND %d" % round_number, cue, is_match_point())


func _activate_round() -> void:
	round_time_remaining = mode.round_time_limit
	combat_lock_changed.emit(false)
	_set_state(STATE_ROUND_ACTIVE)
	intro_updated.emit("ROUND %d" % round_number, "FIGHT", is_match_point())
	round_started.emit(round_number)
	timer_changed.emit(round_time_remaining)


func _resolve_timeout() -> void:
	var team_a_alive := alive_count(TEAM_A)
	var team_b_alive := alive_count(TEAM_B)
	if team_a_alive != team_b_alive:
		_finish_round(TEAM_A if team_a_alive > team_b_alive else TEAM_B)
		return
	var team_a_hp := _team_remaining_hp(TEAM_A)
	var team_b_hp := _team_remaining_hp(TEAM_B)
	if not is_equal_approx(team_a_hp, team_b_hp):
		_finish_round(TEAM_A if team_a_hp > team_b_hp else TEAM_B)
		return
	_set_state(STATE_SUDDEN_DEATH)
	sudden_death_grace_remaining = SUDDEN_DEATH_GRACE
	pressure_remaining = PRESSURE_INTERVAL
	healing_lock_changed.emit(true)
	sudden_death_started.emit()


func _finish_round(winner_team: int) -> void:
	if state in [STATE_ROUND_END, STATE_MATCH_END, STATE_RESULTS]:
		return
	combat_lock_changed.emit(true)
	healing_lock_changed.emit(false)
	for participant: ArenaParticipantState in participants:
		participant.finish_round()
	if winner_team == TEAM_A:
		team_a_score += 1
	else:
		team_b_score += 1
	phase_remaining = ROUND_END_DURATION
	_set_state(STATE_ROUND_END)
	round_ended.emit(winner_team, team_a_score, team_b_score)
	stats_changed.emit()


func _finish_match(winner_team: int, abandoned: bool) -> void:
	combat_lock_changed.emit(true)
	healing_lock_changed.emit(false)
	loadout_locked = false
	latest_result = ArenaMatchResult.new().configure(mode, winner_team, team_a_score, team_b_score, round_number, participants, abandoned, match_result_id)
	phase_remaining = MATCH_END_DURATION
	_set_state(STATE_MATCH_END)
	match_ended.emit(latest_result)
	if abandoned:
		phase_remaining = 0.0


func _match_winner() -> int:
	if mode == null:
		return -1
	if team_a_score >= mode.rounds_to_win:
		return TEAM_A
	if team_b_score >= mode.rounds_to_win:
		return TEAM_B
	if round_number >= mode.max_rounds:
		if team_a_score != team_b_score:
			return TEAM_A if team_a_score > team_b_score else TEAM_B
	return -1


func _team_remaining_hp(team_id: int) -> float:
	var result := 0.0
	for participant: ArenaParticipantState in living_participants(team_id):
		if is_instance_valid(participant.actor):
			var health_node := participant.actor.get_node_or_null("HealthComponent") as HealthComponent
			if health_node != null:
				result += health_node.current_health
	return result


func _set_state(new_state: StringName) -> void:
	state = new_state
	state_changed.emit(state)


func _format_time(value: float) -> String:
	var seconds := maxi(0, ceili(value))
	return "%02d:%02d" % [seconds / 60, seconds % 60]
