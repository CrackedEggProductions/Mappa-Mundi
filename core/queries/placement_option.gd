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
var host_lineage_id: int = 0
var river_lineage_id: int = 0
var target_development_copy_id: int = 0
var enclosure_id: int = 0


func canonical_signature() -> String:
	var base: String = "%d|%d|%d,%d|%d|%d|%d" % [
		placement_mode, tile_copy_id, coordinate.x, coordinate.y,
		rotation, board_revision, state_revision,
	]
	if placement_mode == DomainTypes.PlacementMode.EXPANSION:
		return base
	return base + "|%d|%d|%d|%d" % [host_lineage_id, river_lineage_id,
		target_development_copy_id, enclosure_id]


func matches_revision(current_board_revision: int, current_state_revision: int) -> bool:
	return (board_revision == current_board_revision
		and state_revision == current_state_revision and signature == canonical_signature())
