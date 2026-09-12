class_name PlacementOption
extends RefCounted
## A query snapshot, never permission to bypass command-time validation.

var placement_mode: DomainTypes.PlacementMode = DomainTypes.PlacementMode.EXPANSION
var coordinate: Vector2i = Vector2i.ZERO
var rotation: int = 0
var tile_copy_id: int = 0
var board_revision: int = 0
var state_revision: int = 0
var signature: String = ""


func canonical_signature() -> String:
	return "%d|%d|%d,%d|%d|%d|%d" % [
		placement_mode, tile_copy_id, coordinate.x, coordinate.y,
		rotation, board_revision, state_revision,
	]


func matches_revision(current_board_revision: int, current_state_revision: int) -> bool:
	return (board_revision == current_board_revision
		and state_revision == current_state_revision and signature == canonical_signature())
