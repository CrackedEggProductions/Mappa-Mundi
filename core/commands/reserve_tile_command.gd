class_name ReserveTileCommand
extends PlayerCommand

var tile_copy_id: int
## -1 selects the first empty legal slot.
var reserve_slot: int = -1


func _init(copy_id: int = 0, slot: int = -1) -> void:
	tile_copy_id = copy_id
	reserve_slot = slot
