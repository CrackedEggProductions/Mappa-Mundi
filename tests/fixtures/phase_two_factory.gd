extends RefCounted
## Small, explicit physical inventories for headless safeguard tests.


static func content() -> ContentRegistry:
	var registry: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = registry.load_homestead()
	assert(result.is_valid, result.user_message)
	return registry


static func minimal(registry: ContentRegistry, hand_definitions: Array[StringName],
		bag_definitions: Array[StringName], reserve_definition: StringName = &"",
		seed_value: int = 4701) -> RunState:
	var state: RunState = RunState.new(seed_value)
	state.expansion = ExpansionState.new()
	state.phase = GamePhase.Type.TURN_INPUT
	var founding_id: int = PhysicalTileRules.acquire(state, &"tile.founding.homestead",
		&"founding", TileLocationState.Kind.BOARD_BASE)
	state.expansion.board.add_cell(BoardCellState.from_definition(
		registry.get_tile(&"tile.founding.homestead"), founding_id, Vector2i.ZERO, 0, 1, 0
	))
	for definition_id: StringName in hand_definitions:
		state.expansion.hand.append(PhysicalTileRules.acquire(state, definition_id,
			&"test_fixture", TileLocationState.Kind.ACTIVE_HAND))
	for definition_id: StringName in bag_definitions:
		state.expansion.bag.append(PhysicalTileRules.acquire(state, definition_id,
			&"test_fixture", TileLocationState.Kind.BAG))
	if reserve_definition != &"":
		state.expansion.reserve_id = PhysicalTileRules.acquire(state, reserve_definition,
			&"test_fixture", TileLocationState.Kind.RESERVE)
	return state


static func options(state: RunState, registry: ContentRegistry, copy_id: int) -> Array[PlacementOption]:
	var copy: TileCopyState = PhysicalTileRules.find_copy(state, copy_id)
	return PlacementQueryService.query(state.expansion.board,
		registry.get_tile(copy.definition_id), copy_id, state.expansion.state_revision)


static func first_placement(state: RunState, registry: ContentRegistry,
		prefer_rotation: bool = false) -> PlaceTileCommand:
	for copy_id: int in state.expansion.hand:
		for option: PlacementOption in options(state, registry, copy_id):
			if not prefer_rotation or option.rotation != 0:
				return PlaceTileCommand.new(copy_id, TileLocationState.Kind.ACTIVE_HAND,
					option.coordinate, option.rotation)
	return null
