class_name ArenaSessionRequest
extends RefCounted

const VALID_MODES: Array[StringName] = [&"1v1", &"2v2"]
const VALID_DIFFICULTIES: Array[StringName] = [&"EASY", &"NORMAL", &"HARD"]

static var mode_id: StringName = &"1v1"
static var bot_difficulty: StringName = &"NORMAL"


static func configure(requested_mode: StringName, requested_difficulty: StringName = &"NORMAL") -> void:
	mode_id = requested_mode if requested_mode in VALID_MODES else &"1v1"
	bot_difficulty = requested_difficulty if requested_difficulty in VALID_DIFFICULTIES else &"NORMAL"
