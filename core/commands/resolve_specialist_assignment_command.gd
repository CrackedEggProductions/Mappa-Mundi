class_name ResolveSpecialistAssignmentCommand
extends PlayerCommand
## Resolves exactly one persisted local assignment opportunity, or declines it.

var choice_id: int
var piece_id: int
var target_type: int
var target_id: int
var decline: bool
var expected_state_revision: int = -1


func _init(choice: int = 0, piece: int = 0, type: int = -1, target: int = 0, skip: bool = false) -> void:
	choice_id = choice
	piece_id = piece
	target_type = type
	target_id = target
	decline = skip
