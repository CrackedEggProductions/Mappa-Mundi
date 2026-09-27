class_name HomesteadRunFactory
extends RefCounted
## Setup RNG: environment, Charter, Starter offer; chosen copy, full shuffle, hand draw.


static func create(seed_value: int, content: ContentRegistry) -> RunState:
	assert(content.is_loaded(), "Load the validated Homestead content before setup.")
	var config: RunConfig = content.get_config()
	assert(config.starting_bag.size() == 10, "Homestead needs the fixed ten-design core.")
	var state: RunState = RunState.new(seed_value)
	state.expansion = ExpansionState.new()
	state.expansion.survey_charges = config.initial_survey_charges
	var founding_id: int = PhysicalTileRules.acquire(
		state, &"tile.founding.homestead", &"homestead_founding", TileLocationState.Kind.BOARD_BASE
	)
	state.expansion.board.add_cell(BoardCellState.from_definition(
		content.get_tile(&"tile.founding.homestead"), founding_id, Vector2i.ZERO, 0, 1, 0
	))
	EnvironmentalRiverService.generate(state, content)
	FeatureResolutionService.initialize(state)
	TradeNetworkService.initialize(state)
	if content.get_specialist_ids().size() == 8:
		SpecialistRules.initialize(state)
	if content.get_relic_ids().size() == 10:
		state.relics = RelicState.new()
		state.rewards = RewardState.new()
	var phase_nine: bool = content.get_charter_ids().size() == 9
	if phase_nine:
		state.charters = CharterState.new()
	# Definition order is explicit and sorted before the RNG-sensitive construction.
	var entries: Array[StartingBagEntry] = config.starting_bag.duplicate()
	entries.sort_custom(_entry_before)
	for entry: StartingBagEntry in entries:
		for index: int in range(entry.count):
			state.expansion.bag.append(PhysicalTileRules.acquire(
				state, entry.definition_id, &"homestead_starting_bag", TileLocationState.Kind.BAG
			))
	if phase_nine:
		CharterRules.select_ordinary(state, content, 1)
		state.expansion.hand.assign([0, 0, 0])
		TileDraftService.begin(state, content, &"starter")
	else:
		# Isolated earlier-phase manifests have no Charter/directional draft content.
		state.expansion.bag = state.rng.shuffled_ids(state.expansion.bag, &"starting_bag_shuffle")
		state.expansion.hand.resize(config.hand_capacity)
		finish_opening_hand(state, content)
		StalemateRules.cycle_if_dead(state, content)
	InvariantValidator.assert_valid(state, content)
	return state


static func finish_opening_hand(state: RunState, content: ContentRegistry) -> void:
	for index: int in range(content.get_config().hand_capacity):
		assert(state.expansion.hand[index] == 0)
		state.expansion.hand[index] = PhysicalTileRules.draw(state, content.get_config())
	state.phase = GamePhase.Type.TURN_INPUT


static func _entry_before(left: StartingBagEntry, right: StartingBagEntry) -> bool:
	return String(left.definition_id) < String(right.definition_id)
