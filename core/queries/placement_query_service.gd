class_name PlacementQueryService
extends RefCounted
## Pure Expansion queries: deterministic frontier, then ascending quarter-turns.


static func query_for_copy(state: RunState, content: ContentRegistry,
		copy_id: int) -> Array[PlacementOption]:
	if state.expansion == null:
		return []
	var copy: TileCopyState = PhysicalTileRules.find_copy(state, copy_id)
	if copy == null:
		return []
	var definition: TileDefinition = content.get_tile(copy.definition_id)
	if definition == null:
		return []
	if definition.tile_class == DomainTypes.TileClass.TRANSFORMATION:
		return TransformationPlacementQuery.query(state, content, copy_id)
	if definition.tile_class == DomainTypes.TileClass.EXPANSION:
		var legal: Array[PlacementOption] = []
		for option: PlacementOption in query(state.expansion.board, definition, copy_id, state.expansion.state_revision):
			if SpecialistPlacementService.expansion_is_legal(state, definition, copy_id, option.coordinate, option.rotation):
				legal.append(option)
		return legal
	return DevelopmentPlacementQuery.query(state, content, copy_id)


static func query(
	board: BoardState, definition: TileDefinition, tile_copy_id: int,
	state_revision: int = 0
) -> Array[PlacementOption]:
	var result: Array[PlacementOption] = []
	if board == null or definition == null or tile_copy_id <= 0:
		return result
	for coordinate: Vector2i in board.frontier():
		var seen_geometry: Dictionary[String, bool] = {}
		for rotation: int in range(4):
			if not validate(board, definition, coordinate, rotation).is_valid:
				continue
			var geometry: String = TileRotation.geometry_signature(definition, rotation)
			if seen_geometry.has(geometry):
				continue
			seen_geometry[geometry] = true
			var option: PlacementOption = PlacementOption.new()
			option.coordinate = coordinate
			option.rotation = rotation
			option.tile_copy_id = tile_copy_id
			option.board_revision = board.revision
			option.state_revision = state_revision
			option.signature = option.canonical_signature()
			result.append(option)
	return result


static func validate(
	board: BoardState, definition: TileDefinition, coordinate: Vector2i, rotation: int
) -> ValidationResult:
	if board == null or definition == null:
		return ValidationResult.failure(&"missing_placement_context", "Board and tile definition are required.")
	if definition.tile_class != DomainTypes.TileClass.EXPANSION:
		return ValidationResult.failure(&"wrong_tile_class", "This query accepts Expansion tiles only.")
	if definition.definition_id == &"tile.founding.homestead":
		return ValidationResult.failure(&"setup_tile_only", "The Founding Tile is placed only during setup.")
	if rotation < 0 or rotation > 3:
		return ValidationResult.failure(&"invalid_rotation", "Rotation must be a canonical quarter-turn from 0 to 3.")
	if definition.canonical_edges.size() != 4:
		return ValidationResult.failure(&"invalid_edges", "The tile must have exactly four edges.")
	if board.cells.has(coordinate):
		return ValidationResult.failure(&"occupied_target", "The target square is occupied.")
	var effective: Array[DomainTypes.EdgeType] = TileRotation.edges(definition.canonical_edges, rotation)
	var has_neighbor: bool = false
	for direction: int in range(4):
		var neighbor: BoardCellState = board.get_cell(coordinate + BoardState.ORTHOGONAL_OFFSETS[direction])
		if neighbor == null:
			continue
		has_neighbor = true
		if neighbor.effective_edges.size() != 4:
			return ValidationResult.failure(&"invalid_neighbor_edges", "An occupied neighbor has invalid edges.")
		if not ExactEdgeMatcher.matches(effective[direction], neighbor.effective_edges[(direction + 2) % 4]):
			return ValidationResult.failure(&"edge_mismatch", "Every occupied neighboring edge must match.", {
				"direction": direction, "coordinate": [coordinate.x, coordinate.y],
			})
	if not has_neighbor:
		return ValidationResult.failure(&"not_orthogonally_adjacent", "Place beside an occupied square.")
	return ValidationResult.success()
