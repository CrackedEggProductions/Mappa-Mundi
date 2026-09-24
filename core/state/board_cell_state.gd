class_name BoardCellState
extends RefCounted
## Current geometry and base-tile history; no cross-square topology is built here.

var coordinate: Vector2i = Vector2i.ZERO
var base_tile_copy_id: int = 0
var definition_id: StringName = &""
var rotation: int = 0
var act_placed: int = 1
var normal_placement_index: int = 0
var effective_edges: Array[DomainTypes.EdgeType] = []
var feature_groups: Array[TileFeatureGroup] = []
var relationships: Array[TileFeatureRelationship] = []
var field_supports_settlement: bool = false
## Persistent revision of current geometry, independent of original base age.
var geometry_revision: int = 0
## List-shaped for future explicit slot rules; normal play permits one overlay.
var developments: Array[DevelopmentState] = []
## Field interior survives Bridge; Rewilding explicitly consumes it.
var has_field_geography: bool = false
## Persistent reciprocal hard Field/Forest seams, independent of equipped Relics.
var hard_boundaries: Array[int] = []
var transformations: Array[TransformationState] = []


static func from_definition(
	definition: TileDefinition, tile_copy_id: int, at: Vector2i,
	quarter_turns: int, act: int, placement_index: int
) -> BoardCellState:
	var cell: BoardCellState = BoardCellState.new()
	cell.coordinate = at
	cell.base_tile_copy_id = tile_copy_id
	cell.definition_id = definition.definition_id
	cell.rotation = posmod(quarter_turns, 4)
	cell.act_placed = act
	cell.normal_placement_index = placement_index
	cell.effective_edges = TileRotation.edges(definition.canonical_edges, quarter_turns)
	cell.feature_groups = TileRotation.groups(definition.feature_groups, quarter_turns)
	cell.field_supports_settlement = definition.field_supports_settlement
	cell.has_field_geography = cell.effective_edges.has(DomainTypes.EdgeType.FIELD)
	for relationship: TileFeatureRelationship in definition.relationships:
		cell.relationships.append(relationship.duplicate(true) as TileFeatureRelationship)
	return cell
