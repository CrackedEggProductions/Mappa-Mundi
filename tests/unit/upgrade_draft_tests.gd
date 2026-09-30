extends "res://tests/framework/test_suite.gd"

const F = preload("res://tests/fixtures/phase_nine_factory.gd")
const Acquire = preload("res://tests/fixtures/phase_five_factory.gd")


func tests() -> Array[Callable]:
	var result: Array[Callable] = [guaranteed_core, starter_still_nineteen,
		entry_without_market_has_two, saved_offer_is_not_refiltered, draw_then_place_changes_eligibility,
		reward_pools_unchanged]
	for base: StringName in [&"monastery", &"market"]:
		for zone: String in ["bag", "board", "hand", "reserve", "upgraded", "history", "one_remaining"]:
			result.append(prerequisite_case.bind(base, zone))
	return result


func _clear_bases(state: RunState) -> void:
	for id: int in state.expansion.bag.duplicate():
		if PhysicalTileRules.find_copy(state, id).definition_id in [&"tile.development.monastery", &"tile.development.market"]:
			state.expansion.bag.erase(id)
			state.expansion.removed_ids.append(id)
			PhysicalTileRules.set_location(state, id, TileLocationState.Kind.REMOVED_FROM_RUN)
	for index: int in range(3):
		var copy: TileCopyState = PhysicalTileRules.find_copy(state, state.expansion.hand[index])
		if copy != null and copy.definition_id in [&"tile.development.monastery", &"tile.development.market"]:
			Acquire.acquire_hand(state, &"tile.forest_edge", index)


func _board_copy(state: RunState, base: StringName) -> void:
	var id: StringName = StringName("tile.development." + String(base))
	var development: DevelopmentState = DevelopmentState.new()
	development.tile_copy_id = PhysicalTileRules.acquire(state, id, &"scenario_fixture", TileLocationState.Kind.BOARD_DEVELOPMENT)
	development.stage = base
	state.expansion.board.get_cell(Vector2i.ZERO).developments.append(development)


func prerequisite_case(base: StringName, zone: String) -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.started(content)
	_clear_bases(state)
	var definition_id: StringName = StringName("tile.development." + String(base))
	var upgrade: StringName = &"tile.development.abbey" if base == &"monastery" else &"tile.development.grand_market"
	match zone:
		"bag": state.expansion.bag.append(PhysicalTileRules.acquire(state, definition_id, &"scenario_fixture", TileLocationState.Kind.BAG))
		"board": _board_copy(state, base)
		"hand": Acquire.acquire_hand(state, definition_id)
		"reserve": state.expansion.reserve_id = PhysicalTileRules.acquire(state, definition_id, &"scenario_fixture", TileLocationState.Kind.RESERVE)
		"upgraded": _board_copy(state, &"abbey" if base == &"monastery" else &"grand_market")
		"history":
			state.expansion.removed_ids.append(PhysicalTileRules.acquire(state, definition_id, &"scenario_fixture", TileLocationState.Kind.REMOVED_FROM_RUN))
		"one_remaining":
			_board_copy(state, &"abbey" if base == &"monastery" else &"grand_market")
			_board_copy(state, base)
	var expected: bool = zone in ["bag", "board", "one_remaining"]
	for subtype: StringName in [&"cadence", &"act_entry"]:
		var act: int = 2 if base == &"monastery" else 3
		expect_equal(TileDraftService.eligible_pool(state, content, subtype, act).has(upgrade), expected,
			"Only current board/bag non-upgraded %s qualifies: %s" % [base, zone])
	return true


func guaranteed_core() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(1, content)
	var ids: Array[int] = []
	var counts: Dictionary = {}
	for id: int in state.expansion.bag:
		expect_true(id not in ids, "Unique physical starting copy")
		ids.append(id)
		var name: StringName = PhysicalTileRules.find_copy(state, id).definition_id
		counts[name] = int(counts.get(name, 0)) + 1
	expect_equal(ids.size(), 18, "Core stays eighteen")
	expect_equal(counts.get(&"tile.development.monastery", 0), 1, "Guaranteed Monastery")
	expect_equal(counts.get(&"tile.settlement_throughway", 0), 0, "Throughway is acquired by choice")
	for id: StringName in [&"tile.development.monastery", &"tile.settlement_throughway"]:
		expect_true(TileDraftService.eligible_pool(state, content, &"cadence", 1).has(id), "Design remains draftable")
		expect_true(RewardRules.tile_pool(content, 1).has(id), "Design remains reward eligible")
	expect_true(TileDraftService.pool(content, &"starter", 1).has(&"tile.development.monastery"), "Starter may add another Monastery")
	return true


func starter_still_nineteen() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(1, content)
	expect_true(RulesEngine.execute(state, content, ResolveTileDraftCommand.new(state.pending_choice.choice_id, 0)).is_valid, "Starter choice executes")
	expect_equal(state.expansion.bag.size() + state.expansion.hand.size(), 19, "Nineteen unplaced copies after acquisition")
	return true


func entry_without_market_has_two() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.started(content)
	_clear_bases(state)
	state.expansion.current_act = 3
	TileDraftService.begin(state, content, &"act_entry")
	expect_equal(state.pending_choice.options.size(), 2, "No padding when Grand Market is ineligible")
	var offered: Array[String] = []
	for option: Dictionary in state.pending_choice.options:
		offered.append(option.definition_id)
	expect_true("tile.transformation.bridge" in offered and "tile.transformation.rewilding" in offered, "Only the two legal incoming designs")
	return true


func saved_offer_is_not_refiltered() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.started(content)
	state.expansion.current_act = 3
	state.expansion.normal_placements = 2
	state.relics.capacity = 5
	var market: int = PhysicalTileRules.acquire(state, &"tile.development.market", &"scenario_fixture", TileLocationState.Kind.BAG)
	state.expansion.bag.append(market)
	# Entry pool shows all three while the base exists; use a real transition fixture for round trips elsewhere.
	TileDraftService.begin(state, content, &"act_entry")
	var offer: Array[Dictionary] = state.pending_choice.options.duplicate(true)
	state.expansion.bag.erase(market)
	state.expansion.removed_ids.append(market)
	PhysicalTileRules.set_location(state, market, TileLocationState.Kind.REMOVED_FROM_RUN)
	for index: int in range(offer.size()):
		expect_true(TileDraftService.validate_command(state, content, ResolveTileDraftCommand.new(state.pending_choice.choice_id, index)).is_valid, "Persisted offer is not re-filtered after inventory changes")
	expect_equal(state.pending_choice.options, offer, "No saved option mutation")
	return true


func draw_then_place_changes_eligibility() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.started(content)
	_clear_bases(state)
	var id: int = PhysicalTileRules.acquire(state, &"tile.development.monastery", &"scenario_fixture", TileLocationState.Kind.BAG)
	state.expansion.bag.append(id)
	expect_true(TileDraftService.has_board_or_bag_copy(state, &"tile.development.monastery"), "Bag permits Abbey")
	state.expansion.bag.erase(id)
	PhysicalTileRules.set_location(state, id, TileLocationState.Kind.ACTIVE_HAND)
	expect_true(not TileDraftService.has_board_or_bag_copy(state, &"tile.development.monastery"), "Drawing removes the only qualifier")
	var development: DevelopmentState = DevelopmentState.new()
	development.tile_copy_id = id
	development.stage = &"monastery"
	state.expansion.board.get_cell(Vector2i.ZERO).developments.append(development)
	PhysicalTileRules.set_location(state, id, TileLocationState.Kind.BOARD_DEVELOPMENT)
	expect_true(TileDraftService.has_board_or_bag_copy(state, &"tile.development.monastery"), "Current board copy restores eligibility")
	return true


func reward_pools_unchanged() -> bool:
	var content: ContentRegistry = F.content()
	for id: StringName in [&"tile.development.abbey", &"tile.development.grand_market"]:
		expect_true(RewardRules.tile_pool(content, 3).has(id), "Normal Tile Rewards ignore draft prerequisites")
	return true
