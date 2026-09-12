class_name TileCopyState
extends RefCounted
## Physical identity and acquisition metadata, not static geometry or UI state.
## The run's TileLocationState records are the sole source of location truth.

var tile_copy_id: int
var definition_id: StringName
var acquired_act: int
var acquisition_source: StringName


func _init(
	copy_id: int = 0, static_id: StringName = &"", act: int = 1, source: StringName = &""
) -> void:
	tile_copy_id = copy_id
	definition_id = static_id
	acquired_act = act
	acquisition_source = source
