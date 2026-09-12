class_name TileLocationState
extends RefCounted
## ID-only location reference. No duplicated location field on TileCopyState.
## Phase-1 fixtures use REMOVED_FROM_RUN; initialized ExpansionState supplies
## Phase-2 bag/hand/Reserve/board/removed containers. Overlay zones remain deferred.

enum Kind {
	BAG = 0,
	ACTIVE_HAND = 1,
	RESERVE = 2,
	BOARD_BASE = 3,
	BOARD_DEVELOPMENT = 4,
	BOARD_TRANSFORMATION = 5,
	REMOVED_FROM_RUN = 6,
}

var tile_copy_id: int
var kind: Kind


func _init(copy_id: int = 0, location_kind: Kind = Kind.REMOVED_FROM_RUN) -> void:
	tile_copy_id = copy_id
	kind = location_kind
