extends "res://tests/framework/test_suite.gd"

const EDGE = DomainTypes.EdgeType


func tests() -> Array[Callable]:
	return [
		sparse_board_handles_negative_and_large_coordinates,
		board_revision_changes_only_on_insertion,
		frontier_is_orthogonal_unique_and_sorted,
		frontier_ignores_insertion_order,
		quarter_turns_rotate_clockwise,
		endpoint_rotations_preserve_single_socket,
		bend_rotations_preserve_adjacency,
		opposite_edges_preserve_opposition,
		junction_rotations_preserve_three_connected_sockets,
		hybrid_rotations_preserve_distinct_groups_and_access,
		cell_geometry_is_owned_and_retains_history,
		exact_matcher_covers_all_five_types,
		occupied_and_diagonal_targets_are_rejected,
		empty_edges_can_remain_open,
		all_occupied_neighbors_must_match,
		queries_return_legal_rotations_in_order,
		queries_deduplicate_symmetric_geometry,
		query_order_ignores_board_insertion_order,
		query_does_not_mutate_board,
		preview_revisions_and_signatures_detect_staleness,
		invalid_orientation_and_setup_tile_are_rejected,
	]


func sparse_board_handles_negative_and_large_coordinates() -> bool:
	var board: BoardState = BoardState.new()
	for at: Vector2i in [Vector2i(-900000, 500000), Vector2i(800000, -600000)]:
		board.add_cell(_cell(at))
		expect_equal(board.get_cell(at).coordinate, at, "Sparse coordinate resolves exactly")
	expect_equal(board.cells.size(), 2, "Only occupied cells use storage")
	expect_true(board.get_cell(Vector2i.ZERO) == null, "Unoccupied lookup returns null")
	return true


func board_revision_changes_only_on_insertion() -> bool:
	var board: BoardState = BoardState.new()
	expect_equal(board.revision, 0, "Empty board starts at revision zero")
	board.add_cell(_cell(Vector2i.ZERO))
	expect_equal(board.revision, 1, "Insertion increments board revision")
	board.frontier()
	board.sorted_coordinates()
	board.get_cell(Vector2i.ZERO)
	expect_equal(board.revision, 1, "Read-only access preserves revision")
	board.add_cell(_cell(Vector2i.LEFT))
	expect_equal(board.revision, 2, "Next insertion advances revision")
	return true


func frontier_is_orthogonal_unique_and_sorted() -> bool:
	var board: BoardState = _board()
	expect_equal(board.frontier(), [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT], "Frontier sorts x then y")
	board.add_cell(_cell(Vector2i.RIGHT))
	var frontier: Array[Vector2i] = board.frontier()
	expect_equal(frontier.size(), 6, "Shared and occupied candidates do not duplicate")
	expect_true(not frontier.has(Vector2i.ZERO) and not frontier.has(Vector2i.RIGHT), "Occupied targets excluded")
	expect_true(not frontier.has(Vector2i(-1, -1)), "Diagonal-only target excluded")
	return true


func frontier_ignores_insertion_order() -> bool:
	var first: BoardState = _board()
	first.add_cell(_cell(Vector2i.RIGHT))
	var second: BoardState = BoardState.new()
	second.add_cell(_cell(Vector2i.RIGHT))
	second.add_cell(_cell(Vector2i.ZERO))
	expect_equal(first.sorted_coordinates(), second.sorted_coordinates(), "Cell order canonical")
	expect_equal(first.frontier(), second.frontier(), "Frontier independent of Dictionary insertion")
	return true


func quarter_turns_rotate_clockwise() -> bool:
	var canonical: Array[DomainTypes.EdgeType] = [EDGE.SETTLEMENT, EDGE.ROAD, EDGE.RIVER, EDGE.FOREST]
	expect_equal(TileRotation.edges(canonical, 1), [EDGE.FOREST, EDGE.SETTLEMENT, EDGE.ROAD, EDGE.RIVER], "One clockwise quarter turn")
	expect_equal(TileRotation.edges(canonical, 2), [EDGE.RIVER, EDGE.FOREST, EDGE.SETTLEMENT, EDGE.ROAD], "Two quarter turns")
	expect_equal(TileRotation.edges(canonical, 3), [EDGE.ROAD, EDGE.RIVER, EDGE.FOREST, EDGE.SETTLEMENT], "Three quarter turns")
	expect_equal(TileRotation.edges(canonical, 4), canonical, "Four quarter turns restore canonical orientation")
	return true


func endpoint_rotations_preserve_single_socket() -> bool:
	var definition: TileDefinition = _definition([EDGE.ROAD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	for rotation: int in range(4):
		var edges: Array[DomainTypes.EdgeType] = TileRotation.edges(definition.canonical_edges, rotation)
		expect_equal(edges[rotation], EDGE.ROAD, "Endpoint follows rotated direction")
		expect_equal(edges.count(EDGE.ROAD), 1, "Endpoint retains exactly one Road edge")
		expect_equal(TileRotation.groups(definition.feature_groups, rotation)[0].directions, [rotation], "Component socket follows endpoint")
	return true


func bend_rotations_preserve_adjacency() -> bool:
	var definition: TileDefinition = _definition([EDGE.RIVER, EDGE.RIVER, EDGE.FIELD, EDGE.FIELD])
	for rotation: int in range(4):
		var edges: Array[DomainTypes.EdgeType] = TileRotation.edges(definition.canonical_edges, rotation)
		expect_equal(edges[rotation], EDGE.RIVER, "First bend edge rotated")
		expect_equal(edges[(rotation + 1) % 4], EDGE.RIVER, "Second bend edge remains adjacent")
	return true


func opposite_edges_preserve_opposition() -> bool:
	var definition: TileDefinition = _definition([EDGE.FOREST, EDGE.FIELD, EDGE.FOREST, EDGE.FIELD])
	for rotation: int in range(4):
		var edges: Array[DomainTypes.EdgeType] = TileRotation.edges(definition.canonical_edges, rotation)
		expect_equal(edges[rotation], EDGE.FOREST, "First opposite edge rotated")
		expect_equal(edges[(rotation + 2) % 4], EDGE.FOREST, "Second edge remains opposite")
	expect_equal(TileRotation.geometry_signature(definition, 0), TileRotation.geometry_signature(definition, 2), "Opposite geometry is 180-degree equivalent")
	return true


func junction_rotations_preserve_three_connected_sockets() -> bool:
	var definition: TileDefinition = _definition([EDGE.ROAD, EDGE.ROAD, EDGE.ROAD, EDGE.FIELD])
	for rotation: int in range(4):
		var edges: Array[DomainTypes.EdgeType] = TileRotation.edges(definition.canonical_edges, rotation)
		expect_equal(edges[(3 + rotation) % 4], EDGE.FIELD, "Junction Field edge rotates")
		var groups: Array[TileFeatureGroup] = TileRotation.groups(definition.feature_groups, rotation)
		expect_equal(groups.size(), 1, "Junction remains one internal group")
		expect_equal(groups[0].directions.size(), 3, "All three Road sockets remain connected")
	return true


func hybrid_rotations_preserve_distinct_groups_and_access() -> bool:
	var definition: TileDefinition = _hybrid()
	for rotation: int in range(4):
		var cell: BoardCellState = BoardCellState.from_definition(definition, 9, Vector2i.ZERO, rotation, 1, 1)
		expect_equal(cell.feature_groups.size(), 2, "Settlement and Road remain distinct groups")
		expect_equal(cell.relationships.size(), 1, "Explicit internal access survives rotation")
		expect_equal(cell.relationships[0].kind, TileFeatureRelationship.Kind.ROAD_SETTLEMENT_ACCESS, "Access relationship type preserved")
		for group: TileFeatureGroup in cell.feature_groups:
			for direction: int in group.directions:
				expect_equal(cell.effective_edges[direction], group.edge_type, "Rotated group directions match current sockets")
	return true


func cell_geometry_is_owned_and_retains_history() -> bool:
	var definition: TileDefinition = _hybrid()
	var cell: BoardCellState = BoardCellState.from_definition(definition, 987, Vector2i(-20, 31), 3, 1, 7)
	expect_equal(cell.base_tile_copy_id, 987, "Physical copy retained")
	expect_equal(cell.definition_id, definition.definition_id, "Definition ID retained")
	expect_equal(cell.coordinate, Vector2i(-20, 31), "Coordinate retained")
	expect_equal(cell.rotation, 3, "Canonical rotation retained")
	expect_equal(cell.act_placed, 1, "Historical placement Act retained")
	expect_equal(cell.normal_placement_index, 7, "Historical placement index retained")
	cell.feature_groups[0].directions.clear()
	cell.relationships[0].from_edge_type = EDGE.FOREST
	cell.effective_edges[0] = EDGE.FIELD
	expect_equal(definition.feature_groups[0].directions.size(), 2, "Runtime components do not alias static Resources")
	expect_equal(definition.relationships[0].from_edge_type, EDGE.ROAD, "Runtime access metadata does not alias definition")
	expect_equal(definition.canonical_edges[0], EDGE.SETTLEMENT, "Effective geometry is independent runtime state")
	return true


func exact_matcher_covers_all_five_types() -> bool:
	var edge_types: Array[DomainTypes.EdgeType] = [EDGE.FIELD, EDGE.FOREST, EDGE.RIVER, EDGE.ROAD, EDGE.SETTLEMENT]
	for left: DomainTypes.EdgeType in edge_types:
		for right: DomainTypes.EdgeType in edge_types:
			expect_equal(ExactEdgeMatcher.matches(left, right), left == right, "Only equal mechanical edge types match")
	return true


func occupied_and_diagonal_targets_are_rejected() -> bool:
	var board: BoardState = _board()
	var definition: TileDefinition = _definition([EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	expect_equal(PlacementQueryService.validate(board, definition, Vector2i.ZERO, 0).error_code, &"occupied_target", "Occupied target rejected")
	expect_equal(PlacementQueryService.validate(board, definition, Vector2i(1, 1), 0).error_code, &"not_orthogonally_adjacent", "Diagonal alone is insufficient")
	expect_true(not PlacementQueryService.validate(BoardState.new(), definition, Vector2i.ZERO, 0).is_valid, "Ordinary Expansion cannot seed an empty board")
	return true


func empty_edges_can_remain_open() -> bool:
	var definition: TileDefinition = _definition([EDGE.ROAD, EDGE.RIVER, EDGE.FIELD, EDGE.SETTLEMENT])
	expect_true(PlacementQueryService.validate(_board(), definition, Vector2i.UP, 0).is_valid, "Three edges facing empty squares remain open")
	return true


func all_occupied_neighbors_must_match() -> bool:
	var board: BoardState = _board()
	var river: TileDefinition = _definition([EDGE.RIVER, EDGE.RIVER, EDGE.RIVER, EDGE.RIVER])
	board.add_cell(BoardCellState.from_definition(river, 2, Vector2i(1, -1), 0, 1, 1))
	var matching: TileDefinition = _definition([EDGE.ROAD, EDGE.RIVER, EDGE.FIELD, EDGE.SETTLEMENT])
	expect_true(PlacementQueryService.validate(board, matching, Vector2i.UP, 0).is_valid, "Both south and east neighbors match")
	var mismatch: TileDefinition = _definition([EDGE.ROAD, EDGE.FOREST, EDGE.FIELD, EDGE.SETTLEMENT])
	expect_equal(PlacementQueryService.validate(board, mismatch, Vector2i.UP, 0).error_code, &"edge_mismatch", "One mismatching neighbor vetoes placement")
	return true


func queries_return_legal_rotations_in_order() -> bool:
	var definition: TileDefinition = _definition([EDGE.ROAD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	var options: Array[PlacementOption] = PlacementQueryService.query(_board(), definition, 42, 8)
	expect_equal(options.size(), 12, "Each frontier square permits three endpoint rotations")
	var previous_coordinate: Vector2i = options[0].coordinate
	var previous_rotation: int = -1
	for option: PlacementOption in options:
		if option.coordinate != previous_coordinate:
			expect_true(BoardState.coordinate_before(previous_coordinate, option.coordinate), "Coordinates ascend")
			previous_rotation = -1
		expect_true(option.rotation > previous_rotation, "Rotations ascend within coordinate")
		expect_true(PlacementQueryService.validate(_board(), definition, option.coordinate, option.rotation).is_valid, "Each returned rotation is legal")
		expect_equal(option.tile_copy_id, 42, "Selected physical ID retained")
		expect_equal(option.state_revision, 8, "Run-state revision retained")
		previous_coordinate = option.coordinate
		previous_rotation = option.rotation
	expect_true(not PlacementQueryService.validate(_board(), definition, Vector2i.UP, 2).is_valid, "Road facing Field is an omitted illegal orientation")
	return true


func queries_deduplicate_symmetric_geometry() -> bool:
	var fields: TileDefinition = _definition([EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	expect_equal(PlacementQueryService.query(_board(), fields, 2).size(), 4, "Open Fields yields one orientation per frontier square")
	var straight: TileDefinition = _definition([EDGE.ROAD, EDGE.FIELD, EDGE.ROAD, EDGE.FIELD])
	var options: Array[PlacementOption] = PlacementQueryService.query(_board(), straight, 2)
	expect_equal(options.size(), 4, "Straight duplicate orientations collapse at each coordinate")
	for option: PlacementOption in options:
		expect_true(option.rotation < 2, "First equivalent legal orientation is canonical representative")
	return true


func query_order_ignores_board_insertion_order() -> bool:
	var first: BoardState = _board()
	first.add_cell(_cell(Vector2i.RIGHT))
	var second: BoardState = BoardState.new()
	second.add_cell(_cell(Vector2i.RIGHT))
	second.add_cell(_cell(Vector2i.ZERO))
	var definition: TileDefinition = _definition([EDGE.RIVER, EDGE.RIVER, EDGE.FIELD, EDGE.FIELD])
	expect_equal(_signatures(PlacementQueryService.query(first, definition, 70, 9)), _signatures(PlacementQueryService.query(second, definition, 70, 9)), "Equivalent boards yield identical ordered intent signatures")
	return true


func query_does_not_mutate_board() -> bool:
	var board: BoardState = _board()
	var before: Array[DomainTypes.EdgeType] = board.get_cell(Vector2i.ZERO).effective_edges.duplicate()
	PlacementQueryService.query(board, _hybrid(), 2)
	expect_equal(board.revision, 1, "Query does not advance revision")
	expect_equal(board.cells.size(), 1, "Query does not insert candidates")
	expect_equal(board.get_cell(Vector2i.ZERO).effective_edges, before, "Query leaves occupied geometry intact")
	return true


func preview_revisions_and_signatures_detect_staleness() -> bool:
	var definition: TileDefinition = _definition([EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	var board: BoardState = _board()
	var option: PlacementOption = PlacementQueryService.query(board, definition, 11, 17)[0]
	expect_true(option.matches_revision(1, 17), "Fresh preview matches revisions and canonical signature")
	expect_true(not option.matches_revision(1, 18), "Non-board state mutation invalidates snapshot")
	board.add_cell(_cell(Vector2i.RIGHT))
	expect_true(not option.matches_revision(board.revision, 17), "Board mutation invalidates snapshot")
	option.rotation = 1
	expect_true(not option.matches_revision(1, 17), "Mutated intent invalidates stored signature")
	return true


func invalid_orientation_and_setup_tile_are_rejected() -> bool:
	var definition: TileDefinition = _definition([EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	for rotation: int in [-1, 4, 8]:
		expect_equal(PlacementQueryService.validate(_board(), definition, Vector2i.UP, rotation).error_code, &"invalid_rotation", "Player intent requires canonical quarter turns")
	definition.definition_id = &"tile.founding.homestead"
	expect_true(PlacementQueryService.query(_board(), definition, 99).is_empty(), "Founding Tile never becomes an ordinary placement option")
	definition.definition_id = &"test.expansion"
	definition.tile_class = DomainTypes.TileClass.DEVELOPMENT
	expect_true(PlacementQueryService.query(_board(), definition, 99).is_empty(), "Development is outside Expansion query scope")
	return true


func _board() -> BoardState:
	var board: BoardState = BoardState.new()
	board.add_cell(_cell(Vector2i.ZERO))
	return board


func _cell(at: Vector2i) -> BoardCellState:
	return BoardCellState.from_definition(_definition([EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD]), 1, at, 0, 1, 0)


func _definition(edges: Array[DomainTypes.EdgeType]) -> TileDefinition:
	var definition: TileDefinition = TileDefinition.new()
	definition.definition_id = &"test.expansion"
	definition.canonical_edges = edges
	for edge_type: int in range(1, 5):
		var group: TileFeatureGroup = TileFeatureGroup.new()
		group.edge_type = edge_type
		for direction: int in range(4):
			if edges[direction] == edge_type:
				group.directions.append(direction)
		if not group.directions.is_empty():
			definition.feature_groups.append(group)
	return definition


func _hybrid() -> TileDefinition:
	var definition: TileDefinition = _definition([EDGE.SETTLEMENT, EDGE.SETTLEMENT, EDGE.ROAD, EDGE.ROAD])
	definition.relationships.append(TileFeatureRelationship.new())
	return definition


func _signatures(options: Array[PlacementOption]) -> Array[String]:
	var signatures: Array[String] = []
	for option: PlacementOption in options:
		signatures.append(option.signature)
	return signatures
