class_name ResolveGrandSurveyCommand
extends PlayerCommand
## Remove one still-eligible original hand tile, or finish the optional sequence.

var choice_id: int
var tile_copy_id: int
var finish: bool
var expected_state_revision: int = -1


func _init(choice: int = 0, copy_id: int = 0, done: bool = false) -> void:
	choice_id = choice
	tile_copy_id = copy_id
	finish = done
