class_name RequestSpecialistTrainingCommand
extends PlayerCommand
## Specialist-side reward hook. Zero selects fallback only if nobody can train.

var piece_id: int
var expected_state_revision: int = -1


func _init(piece: int = 0) -> void:
	piece_id = piece
