class_name ArenaSessionRequest
extends RefCounted

const VALID_MODES: Array[StringName] = [&"1v1", &"2v2"]
const VALID_DIFFICULTIES: Array[StringName] = [&"EASY", &"NORMAL", &"HARD"]

static var mode_id: StringName = &"1v1"
static var bot_difficulty: StringName = &"NORMAL"
static var playlist: StringName = &"CASUAL"
static var camera_policy: StringName = &"FREE_SWITCH"
static var standard_rules_enabled: bool = true
const RANKED_AVAILABLE := false


static func configure(requested_mode: StringName, requested_difficulty: StringName = &"NORMAL", requested_playlist: StringName = &"CASUAL") -> void:
	mode_id = requested_mode if requested_mode in VALID_MODES else &"1v1"
	bot_difficulty = requested_difficulty if requested_difficulty in VALID_DIFFICULTIES else &"NORMAL"
	playlist = &"RANKED" if requested_playlist == &"RANKED" else &"CASUAL"
	camera_policy = &"FPP_ONLY" if playlist == &"RANKED" else &"FREE_SWITCH"
	standard_rules_enabled = true


static func allows_camera_switch() -> bool:
	return camera_policy == &"FREE_SWITCH"


static func can_launch_ranked() -> bool:
	return RANKED_AVAILABLE
