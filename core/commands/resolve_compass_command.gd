class_name ResolveCompassCommand
extends PlayerCommand
## Choose one persisted physical copy; no offer regeneration occurs on resolution.

var choice_id: int
var tile_copy_id: int
var expected_state_revision: int = -1


func _init(choice: int = 0, copy_id: int = 0) -> void:
	choice_id = choice
	tile_copy_id = copy_id
