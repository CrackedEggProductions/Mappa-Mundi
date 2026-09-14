class_name HomesteadRunFactory
extends RefCounted
## Deterministic Phase-2 setup only. Charter selection is explicitly deferred.


static func create(seed_value: int, content: ContentRegistry) -> RunState:
	assert(content.is_loaded(), "Load the validated Homestead content before setup.")
	var config: RunConfig = content.get_config()
	assert(config.starting_bag.size() == 21, "Homestead needs the complete starting manifest.")
	var state: RunState = RunState.new(seed_value)
	state.expansion = ExpansionState.new()
	state.expansion.survey_charges = config.initial_survey_charges
	var founding_id: int = PhysicalTileRules.acquire(
		state, &"tile.founding.homestead", &"homestead_founding", TileLocationState.Kind.BOARD_BASE
	)
	state.expansion.board.add_cell(BoardCellState.from_definition(
		content.get_tile(&"tile.founding.homestead"), founding_id, Vector2i.ZERO, 0, 1, 0
	))
	# Definition order is explicit and sorted before the RNG-sensitive construction.
	var entries: Array[StartingBagEntry] = config.starting_bag.duplicate()
	entries.sort_custom(_entry_before)
	for entry: StartingBagEntry in entries:
		for index: int in range(entry.count):
			state.expansion.bag.append(PhysicalTileRules.acquire(
				state, entry.definition_id, &"homestead_starting_bag", TileLocationState.Kind.BAG
			))
	state.expansion.bag = state.rng.shuffled_ids(state.expansion.bag, &"starting_bag_shuffle")
	for index: int in range(config.hand_capacity):
		state.expansion.hand.append(PhysicalTileRules.draw(state, config))
	state.phase = GamePhase.Type.TURN_INPUT
	StalemateRules.cycle_if_dead(state, content)
	FeatureResolutionService.initialize(state)
	InvariantValidator.assert_valid(state, content)
	return state


static func _entry_before(left: StartingBagEntry, right: StartingBagEntry) -> bool:
	return String(left.definition_id) < String(right.definition_id)
