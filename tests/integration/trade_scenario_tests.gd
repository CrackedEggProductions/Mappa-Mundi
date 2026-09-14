extends "res://tests/framework/test_suite.gd"

const Fixture = preload("res://tests/fixtures/phase_four_factory.gd")
const PhaseThree = preload("res://tests/integration/feature_scenario_tests.gd")
const TYPE = DomainTypes.FeatureType


func tests() -> Array[Callable]:
	return [full_network_recompletion_only_pays_new_reach, unfinished_members_extend_scoring,
		leave_rejoin_never_repays, merged_settlement_paid_ancestor_blocks_bonus,
		unpaid_merged_settlement_pays_once, merged_roads_inherit_both_payments,
		merged_road_new_settlement_can_pay, invalid_command_preserves_trade_state,
		seeded_trade_demo, simultaneous_road_recompletions_share_snapshot]


func _first_road(state: RunState) -> FeatureLineageState:
	return state.features.lineage(Fixture.member(state, Vector2i.ZERO, TYPE.ROAD))


func full_network_recompletion_only_pays_new_reach() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.Previous.add(state, registry, &"tile.settlement_gate", Vector2i.RIGHT, 2)
	var first: FeatureLineageState = _first_road(state)
	expect_equal(first.scored_settlement_ids.size(), 2, "First completion sees Founding and first hub")
	var before: int = state.features.tracks.values[1]
	Fixture.Previous.add(state, registry, &"tile.settlement_gate", Vector2i.ONE)
	expect_equal(state.features.tracks.values[1], before, "Unfinished new Road/network growth produces no Trade")
	Fixture.Previous.add(state, registry, &"tile.settlement_gate", Vector2i(2, 1), 2)
	expect_equal(first.scored_settlement_ids.size(), 2, "Distant new Settlement does not retroactively pay completed Road")
	expect_equal(first.completion_ids.size(), 1, "Network growth does not create a completion")
	before = state.features.tracks.values[1]
	Fixture.reopen_first_road(state, registry)
	Fixture.close_first_road(state, registry)
	var record: FeatureCompletionRecord = state.features.completions[-1]
	expect_equal(record.network_settlement_ids.size(), 3, "Recompletion sees full transitive network")
	expect_equal(record.new_settlement_ids.size(), 1, "Only newly reachable Settlement pays")
	expect_equal(state.features.tracks.values[1] - before, 3, "One new Road tile plus one new connection")
	expect_equal(first.scored_settlement_ids.size(), 3, "Per-Road history grows without resetting")
	_valid(state, registry)
	return true


func unfinished_members_extend_scoring() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.chain(registry)
	assert(Fixture.Previous.rewrite(state, registry, Vector2i(2, 1), [0, 3, 4, 3]).is_valid)
	var distant_road: FeatureLineageState = state.features.lineage(Fixture.member(state, Vector2i(2, 1), TYPE.ROAD))
	var distant_settlement: FeatureLineageState = state.features.lineage(Fixture.member(state, Vector2i(2, 1), TYPE.SETTLEMENT))
	expect_true(not distant_road.completed and not distant_settlement.completed, "Both economic intermediates are unfinished")
	Fixture.reopen_first_road(state, registry)
	Fixture.close_first_road(state, registry)
	expect_equal(state.features.completions[-1].network_settlement_ids.size(), 3, "Completion crosses unfinished economic members")
	_valid(state, registry)
	return true


func leave_rejoin_never_repays() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.chain(registry)
	Fixture.reopen_first_road(state, registry)
	Fixture.close_first_road(state, registry)
	var cell: BoardCellState = state.expansion.board.get_cell(Vector2i.ONE)
	var relationships: Array[TileFeatureRelationship] = cell.relationships.duplicate()
	# Controlled removal of an economic access fact; physical features stay intact.
	cell.relationships.clear()
	cell.geometry_revision += 1
	state.expansion.board.revision += 1
	FeatureResolutionService.resolve(state)
	_valid(state, registry)
	expect_equal(TradeNetworkService.settlement_count(state, _first_road(state).lineage_id), 2, "Distant Settlement leaves current network")
	cell.relationships = relationships
	cell.geometry_revision += 1
	state.expansion.board.revision += 1
	FeatureResolutionService.resolve(state)
	var before: int = state.features.tracks.values[1]
	assert(Fixture.Previous.rewrite(state, registry, Vector2i(1, -1), [3, 0, 3, 0]).is_valid)
	Fixture.Previous.add(state, registry, &"tile.road_end", Vector2i(1, -2), 2)
	expect_equal(state.features.tracks.values[1] - before, 1, "Rejoined Settlements never repay; only new Road tile scores")
	expect_equal(state.features.completions[-1].new_settlement_ids, [], "All connections retain payment history")
	_valid(state, registry)
	return true


func merged_settlement_paid_ancestor_blocks_bonus() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.settlement_merger(registry, true)
	expect_equal(state.features.completions[-1].new_settlement_ids, [], "Paid Settlement ancestor blocks merged descendant")
	expect_equal(state.features.completions[-1].gains[1], 1, "Only new Road tile pays after Settlement merger")
	_valid(state, registry)
	return true


func unpaid_merged_settlement_pays_once() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.settlement_merger(registry, false)
	expect_equal(state.features.completions[-1].new_settlement_ids.size(), 1, "Unpaid merged Settlement pays as one current node")
	expect_equal(state.features.completions[-1].gains[1], 4, "Two Road tiles plus one distinct Settlement")
	_valid(state, registry)
	return true


func merged_roads_inherit_both_payments() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.road_merger(registry)
	var road: FeatureLineageState = _first_road(state)
	expect_equal(road.parent_ids.size(), 2, "Two actual physical Roads merge in controlled geometry")
	expect_equal(road.scored_settlement_ids.size(), 2, "Both parental payment sets retained")
	expect_equal(state.features.completions[-1].gains[1], 1, "Connector pays; inherited connections do not")
	_valid(state, registry)
	return true


func merged_road_new_settlement_can_pay() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.road_merger(registry)
	Fixture.Previous.add(state, registry, &"tile.settlement_gate", Vector2i(2, 3))
	Fixture.Previous.add(state, registry, &"tile.settlement_gate", Vector2i(3, 3), 2)
	assert(Fixture.Previous.rewrite(state, registry, Vector2i(1, 2), [3, 3, 0, 3]).is_valid)
	Fixture.Previous.add(state, registry, &"tile.road_end", Vector2i(0, 2), 1)
	expect_equal(state.features.completions[-1].new_settlement_ids.size(), 1, "New Settlement may pay merged Road once")
	expect_equal(state.features.completions[-1].gains[1], 3, "New tile plus new connection, no inherited repayments")
	_valid(state, registry)
	return true


func invalid_command_preserves_trade_state() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = HomesteadRunFactory.create(16, registry)
	var before: String = StateNormalizer.fingerprint(state)
	var intent: PlaceTileCommand = PlaceTileCommand.new(state.expansion.hand[0], TileLocationState.Kind.ACTIVE_HAND, Vector2i.ZERO, 0)
	expect_true(not RulesEngine.execute(state, registry, intent).is_valid, "Occupied target rejected before mutation")
	expect_equal(StateNormalizer.fingerprint(state), before, "Invalid intent preserves graph, history, RNG and IDs")
	state.trade.trade_revision = 9223372036854775807
	before = StateNormalizer.fingerprint(state)
	var picker: RefCounted = PhaseThree.new()
	var seen_types: Array[int] = []
	intent = picker._best_intent(state, registry, seen_types)
	expect_true(intent != null, "Counter scenario otherwise has a legal command")
	expect_equal(RulesEngine.execute(state, registry, intent).error_code, &"invariant_failure", "Trade revision exhaustion rejects a legal placement")
	expect_equal(StateNormalizer.fingerprint(state), before, "Exhaustion remains atomic")
	return true


func seeded_trade_demo() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = HomesteadRunFactory.create(16, registry)
	var mirror: RunState = null
	var picker: RefCounted = PhaseThree.new()
	var seen: Array[int] = []
	for index: int in range(12):
		if index == 5:
			var before: String = StateNormalizer.fingerprint(state)
			var saved: SerializationResult = RunSerializer.serialize(state, registry)
			var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, registry)
			expect_true(loaded.validation.is_valid, "Mid-sequence save/load succeeds")
			mirror = loaded.state
			if mirror == null: return true
			expect_equal(StateNormalizer.fingerprint(mirror), before, "Load adds zero score, events, IDs or RNG use")
		var intent: PlaceTileCommand = picker._best_intent(state, registry, seen)
		if intent == null:
			expect_true(false, "Seeded demo has a legal placement at every step")
			return true
		expect_true(RulesEngine.execute(state, registry, intent).is_valid, "Legal seeded Expansion command")
		for record: FeatureCompletionRecord in state.features.completions:
			if record.feature_type not in seen: seen.append(record.feature_type)
		if mirror != null:
			expect_true(RulesEngine.execute(mirror, registry, intent).is_valid, "Loaded command continuation")
			expect_equal(StateNormalizer.fingerprint(mirror), StateNormalizer.fingerprint(state), "Trade genealogy and scoring continue identically")
		_valid(state, registry)
	var connection_payments: int = 0
	for record: FeatureCompletionRecord in state.features.completions:
		connection_payments += record.new_settlement_ids.size()
	expect_true(connection_payments > 0, "Seeded sequence scores canonical Road network bonus")
	print("DEMO Phase 4: 12 seeded legal placements; Tracks=%s; connection payments=%d; save/load after 5; identical economic graph, genealogy, history, IDs and RNG continuation." % [state.features.tracks.values, connection_payments])
	return true


func _valid(state: RunState, registry: ContentRegistry) -> void:
	var report: InvariantReport = InvariantValidator.validate(state, registry)
	expect_true(report.is_valid, report.describe())


func simultaneous_road_recompletions_share_snapshot() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.chain(registry)
	Fixture.reopen_first_road(state, registry)
	assert(Fixture.Previous.rewrite(state, registry, Vector2i(2, 1), [0, 3, 4, 3]).is_valid)
	# Two fixture placements settle together; normal Expansion grammar has only
	# one Road component per tile, so no future player action is invented here.
	Fixture.stage_expansion(state, registry, &"tile.road_end", Vector2i(1, -1), 2)
	Fixture.stage_expansion(state, registry, &"tile.road_end", Vector2i(3, 1), 3)
	var prior: int = state.features.completions.size()
	FeatureResolutionService.resolve(state)
	var records: Array[FeatureCompletionRecord] = []
	for index: int in range(prior, state.features.completions.size()):
		records.append(state.features.completions[index])
	expect_equal(records.size(), 2, "Both genuine Road transitions resolve in one completion batch")
	expect_equal(records[0].snapshot_id, records[1].snapshot_id, "Simultaneous Roads share immutable snapshot identity")
	expect_equal(records[0].network_settlement_ids, records[1].network_settlement_ids, "Both see full current economic membership")
	expect_equal(records[0].gains[1] + records[1].gains[1], 4, "Independent histories: two new tiles and one new connection")
	_valid(state, registry)
	return true
