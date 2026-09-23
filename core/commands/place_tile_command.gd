class_name PlaceTileCommand
extends PlayerCommand

var tile_copy_id: int
var source_zone: TileLocationState.Kind
var coordinate: Vector2i
var rotation: int
var placement_mode: DomainTypes.PlacementMode = DomainTypes.PlacementMode.EXPANSION
## Optional preview guard. A command is always checked against current geometry.
var expected_board_revision: int = -1
var expected_state_revision: int = -1
var expected_signature: String = ""
var host_lineage_id: int = 0
var river_lineage_id: int = 0
var target_development_copy_id: int = 0
var enclosure_id: int = 0
var transformation_mode: StringName = &""
var target_base_copy_id: int = 0
var transformation_signature: String = ""


func _init(copy_id: int = 0, source: TileLocationState.Kind = TileLocationState.Kind.ACTIVE_HAND,
		target: Vector2i = Vector2i.ZERO, quarter_turns: int = 0) -> void:
	tile_copy_id = copy_id
	source_zone = source
	coordinate = target
	rotation = quarter_turns
