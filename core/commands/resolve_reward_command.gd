class_name ResolveRewardCommand
extends PlayerCommand
## Select an exact persisted option. Decline is itself a persisted option.

var choice_id: int
var option_index: int
var expected_state_revision: int = -1


func _init(choice: int = 0, option: int = -1) -> void:
	choice_id = choice
	option_index = option
