extends RefCounted
## Controlled domain scenarios. No future player command or transformation is exposed.

const PhaseTwo = preload("res://tests/fixtures/phase_two_factory.gd")


static func content() -> ContentRegistry:
	return PhaseTwo.content()


static func create(registry: ContentRegistry) -> RunState:
	var state: RunState = PhaseTwo.minimal(registry,
		[&"tile.road_junction", &"tile.hamlet_edge", &"tile.forest_edge"], [&"tile.forest_edge"])
	FeatureResolutionService.initialize(state)
	assert(InvariantValidator.validate(state, registry).is_valid)
	return state


static func add(state: RunState, registry: ContentRegistry, id: StringName,
		coordinate: Vector2i, rotation: int = 0) -> int:
	if id in [&"tile.riverside_hamlet", &"tile.woodland_river"]:
		return _river_overlay(state, registry, id, coordinate, rotation)
	var definition: TileDefinition = registry.get_tile(id)
	assert(PlacementQueryService.validate(state.expansion.board, definition, coordinate, rotation).is_valid)
	var copy_id: int = PhysicalTileRules.acquire(state, id, &"scenario_fixture", TileLocationState.Kind.BOARD_BASE)
	state.expansion.normal_placements += 1
	var cell: BoardCellState = BoardCellState.from_definition(definition, copy_id, coordinate,
		rotation, 1, state.expansion.normal_placements)
	state.expansion.board.add_cell(cell)
	TopologyService.add_cell_components(state, cell)
	FeatureResolutionService.resolve(state, copy_id)
	state.expansion.state_revision += 1
	assert(InvariantValidator.validate(state, registry).is_valid, InvariantValidator.validate(state, registry).describe())
	return copy_id


static func rewrite(state: RunState, registry: ContentRegistry, coordinate: Vector2i,
		edges: Array[DomainTypes.EdgeType]) -> ValidationResult:
	# Replace only a temporary cell for preview. No history/RNG/IDs change on rejection.
	var before: BoardCellState = state.expansion.board.get_cell(coordinate)
	assert(before != null and coordinate != Vector2i.ZERO)
	var cell: BoardCellState = BoardCellState.from_definition(registry.get_tile(before.definition_id),
		before.base_tile_copy_id, coordinate, before.rotation, before.act_placed, before.normal_placement_index)
	cell.effective_edges = edges.duplicate()
	cell.geometry_revision = before.geometry_revision + 1
	cell.relationships = before.relationships.duplicate()
	cell.developments = before.developments.duplicate()
	cell.field_supports_settlement = before.field_supports_settlement
	cell.feature_groups.clear()
	for edge: int in range(1, 5):
		var group: TileFeatureGroup = TileFeatureGroup.new()
		group.edge_type = edge
		for direction: int in range(4):
			if edges[direction] == edge:
				group.directions.append(direction)
		if not group.directions.is_empty():
			cell.feature_groups.append(group)
	for direction: int in range(4):
		var neighbor: BoardCellState = state.expansion.board.get_cell(coordinate + BoardState.ORTHOGONAL_OFFSETS[direction])
		if neighbor != null and neighbor.effective_edges[(direction + 2) % 4] != edges[direction]:
			return ValidationResult.failure(&"edge_mismatch", "Fixture rewrite must preserve matching occupied edges.")
	# These fixtures reopen existing types, never implement creation/removal/Bridge/Rewilding.
	for group: TileFeatureGroup in cell.feature_groups:
		if state.features.component_at(coordinate, FeatureState.type_for_edge(group.edge_type)) == null:
			return ValidationResult.failure(&"fixture_new_type", "Reopening fixtures preserve feature types.")
	state.expansion.board.cells[coordinate] = cell
	var result: ValidationResult = LineageService.validate_rebuild(state, TopologyService.rebuild(state))
	if not result.is_valid:
		state.expansion.board.cells[coordinate] = before
		return result
	state.expansion.board.revision += 1
	FeatureResolutionService.resolve(state, cell.base_tile_copy_id)
	state.expansion.state_revision += 1
	assert(InvariantValidator.validate(state, registry).is_valid, InvariantValidator.validate(state, registry).describe())
	return result


static func lineage_at(state: RunState, coordinate: Vector2i, type: DomainTypes.FeatureType) -> FeatureLineageState:
	return state.features.lineage(state.features.component_at(coordinate, type).lineage_id)


static func add_monastery(state: RunState, registry: ContentRegistry, coordinate: Vector2i) -> EnclosureState:
	assert(state.expansion.board.get_cell(coordinate) != null)
	var enclosure: EnclosureState = EnclosureState.new()
	enclosure.enclosure_id = state.id_allocator.allocate()
	enclosure.coordinate = coordinate
	state.features.enclosures.append(enclosure)
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	assert(InvariantValidator.validate(state, registry).is_valid, InvariantValidator.validate(state, registry).describe())
	return enclosure


static func _river_overlay(state: RunState, registry: ContentRegistry, id: StringName,
		coordinate: Vector2i, rotation: int) -> int:
	# Isolated topology fixture: stage environmental geography, then apply the
	# canonical occupied overlay plan. This is not a player River-expansion command.
	var hamlet: bool = id == &"tile.riverside_hamlet"
	var base_id: StringName = &"tile.river_run" if hamlet else &"tile.river_bend"
	var base_rotation: int = (rotation + 1) % 2 if hamlet else (rotation + 2) % 4
	var base_copy: int = PhysicalTileRules.acquire(state, base_id, &"scenario_environment", TileLocationState.Kind.BOARD_BASE)
	state.expansion.normal_placements += 1
	var cell: BoardCellState = BoardCellState.from_definition(registry.get_tile(base_id), base_copy,
		coordinate, base_rotation, 1, state.expansion.normal_placements)
	state.expansion.board.add_cell(cell)
	TopologyService.add_cell_components(state, cell)
	FeatureResolutionService.resolve(state, base_copy, false)
	var overlay: int = PhysicalTileRules.acquire(state, id, &"scenario_fixture", TileLocationState.Kind.BOARD_TRANSFORMATION)
	var wanted_rotation: int = rotation if hamlet else base_rotation
	for option: PlacementOption in TransformationPlacementQuery.query(state, registry, overlay):
		if option.coordinate != coordinate or option.rotation != wanted_rotation:
			continue
		state.expansion.normal_placements += 1
		var command: PlaceTileCommand = PlaceTileCommand.new(overlay, TileLocationState.Kind.ACTIVE_HAND, coordinate, option.rotation)
		TransformationPlacementService.place(state, registry, command, option.transformation_plan)
		state.expansion.state_revision += 2
		assert(InvariantValidator.validate(state, registry).is_valid, InvariantValidator.validate(state, registry).describe())
		return base_copy
	assert(false, "No canonical River overlay fixture plan: %s at %s" % [id, coordinate])
	return 0
