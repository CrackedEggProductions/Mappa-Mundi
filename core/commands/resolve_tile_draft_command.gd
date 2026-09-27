class_name ResolveTileDraftCommand
extends PlayerCommand
## Choose one exact saved design; a draft always acquires one physical copy.

var choice_id: int
var option_index: int
var expected_state_revision: int


func _init(choice: int = 0, option: int = -1, revision: int = -1) -> void:
	choice_id = choice
	option_index = option
	expected_state_revision = revision
