class_name ArenaModeDefinition
extends Resource

@export var mode_id: StringName = &"1v1"
@export var display_name: String = "1V1"
@export_range(1, 2, 1) var team_size: int = 1
@export_range(1, 9, 1) var rounds_to_win: int = 4
@export_range(1, 15, 1) var max_rounds: int = 7
@export_range(15.0, 300.0, 5.0) var round_time_limit: float = 90.0


func is_valid() -> bool:
	return not mode_id.is_empty() and team_size > 0 and rounds_to_win > 0 and max_rounds >= rounds_to_win and max_rounds >= rounds_to_win * 2 - 1 and round_time_limit > 0.0
