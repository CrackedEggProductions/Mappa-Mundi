class_name ResolveRelayCommand
extends PlayerCommand
## Select a persisted same-piece Relay target, or decline with option_index -1.

var choice_id: int
var option_index: int
var expected_state_revision: int = -1


func _init(choice: int = 0, option: int = -1) -> void:
	choice_id = choice
	option_index = option
