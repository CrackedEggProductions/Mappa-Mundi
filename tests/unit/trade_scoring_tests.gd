extends "res://tests/framework/test_suite.gd"
## Isolated economic/scoring graphs; integration scenarios additionally validate zones.

const Fixture = preload("res://tests/fixtures/topology_fixture.gd")
const EDGE = DomainTypes.EdgeType
const TYPE = DomainTypes.FeatureType
const TRACK = DomainTypes.TrackType


func tests() -> Array[Callable]:
	return [one_settlement_adds_two_trade, two_settlements_add_four_trade,
		three_settlements_add_six_trade, full_network_crosses_unfinished_road,
		unfinished_settlement_counts, repeated_access_counts_settlement_once,
		simultaneous_roads_have_independent_payments, snapshot_survives_live_history_mutation,
		snapshot_retains_network_after_live_access_removal, resolving_records_payment_history,
		old_payment_is_not_eligible_again, paid_ancestor_blocks_merged_settlement,
		unpaid_merged_settlement_can_pay, historical_road_merger_unions_payments,
		network_growth_does_not_score, no_network_has_only_tile_trade]


func one_settlement_adds_two_trade() -> bool:
	var record: FeatureCompletionRecord = _road_record(_chain(1))
	expect_equal(record.gains[TRACK.TRADE], 4, "Two Road components plus one Settlement")
	expect_equal(record.new_settlement_ids.size(), 1, "One distinct historical payment")
	return true


func two_settlements_add_four_trade() -> bool:
	var record: FeatureCompletionRecord = _road_record(_chain(2))
	expect_equal(record.gains[TRACK.TRADE], 6, "Two Road components plus two Settlements")
	return true


func three_settlements_add_six_trade() -> bool:
	var record: FeatureCompletionRecord = _road_record(_chain(3))
	expect_equal(record.gains[TRACK.TRADE], 8, "Two Road components plus all three Settlements")
	expect_equal(record.network_road_ids.size(), 3, "Three physically separate Roads in snapshot")
	expect_equal(record.network_settlement_ids.size(), 3, "Full transitive snapshot membership")
	return true


func full_network_crosses_unfinished_road() -> bool:
	var state: RunState = _chain(3, true)
	var middle: FeatureLineageState = _lineage(state, 2, TYPE.ROAD)
	var middle_current: CurrentFeature = _current(state, middle.lineage_id)
	expect_true(middle_current.open_exits > 0, "Intermediate Road remains unfinished")
	expect_equal(_road_record(state).gains[TRACK.TRADE], 8, "Distant third Settlement contributes through unfinished Road")
	return true


func unfinished_settlement_counts() -> bool:
	var state: RunState = _chain(1)
	var settlement: FeatureLineageState = _lineage(state, 0, TYPE.SETTLEMENT)
	expect_true(_current(state, settlement.lineage_id).open_exits > 0, "Settlement has unresolved west exit")
	expect_equal(_road_record(state).new_settlement_ids, [settlement.lineage_id], "Unestablished Settlement already participates")
	return true


func repeated_access_counts_settlement_once() -> bool:
	var state: RunState = _chain(2)
	var cell: BoardCellState = state.expansion.board.get_cell(Vector2i.ZERO)
	cell.relationships.append(cell.relationships[0].duplicate(true) as TileFeatureRelationship)
	TradeNetworkService.reconcile(state)
	expect_equal(_road_record(state).gains[TRACK.TRADE], 6, "Duplicate access paths never duplicate Settlement identity")
	return true


func simultaneous_roads_have_independent_payments() -> bool:
	var state: RunState = _chain(3)
	var snapshot: CompletionSnapshot = FeatureScoringService.capture(state, TopologyService.rebuild(state))
	var road_count: int = 0
	var expected: Array[int] = _road_record(state).network_settlement_ids
	for record: FeatureCompletionRecord in FeatureScoringService.calculate(snapshot):
		if record.feature_type != TYPE.ROAD:
			continue
		road_count += 1
		expect_equal(record.network_settlement_ids, expected, "Every peer sees same Settlement membership")
		expect_equal(record.new_settlement_ids, expected, "Each Road has its own unpaid relationships")
		expect_equal(record.gains[TRACK.TRADE], 8, "Each independent Road scores two tiles plus six connectivity")
	expect_equal(road_count, 3, "Three physical Roads complete simultaneously")
	return true


func snapshot_survives_live_history_mutation() -> bool:
	var state: RunState = _chain(3)
	var snapshot: CompletionSnapshot = FeatureScoringService.capture(state, TopologyService.rebuild(state))
	var road: FeatureLineageState = _lineage(state, 0, TYPE.ROAD)
	road.scored_settlement_ids = _road_record(state).network_settlement_ids.duplicate()
	var snapshot_record: FeatureCompletionRecord = _record_from(snapshot, road.lineage_id)
	expect_equal(snapshot_record.gains[TRACK.TRADE], 8, "Historical eligibility was frozen before live mutation")
	expect_equal(_road_record(state).gains[TRACK.TRADE], 2, "Fresh snapshot observes paid history")
	return true


func snapshot_retains_network_after_live_access_removal() -> bool:
	var state: RunState = _chain(3)
	var road: FeatureLineageState = _lineage(state, 0, TYPE.ROAD)
	var snapshot: CompletionSnapshot = FeatureScoringService.capture(state, TopologyService.rebuild(state))
	for cell: BoardCellState in state.expansion.board.cells.values():
		cell.relationships.clear()
	expect_equal(_record_from(snapshot, road.lineage_id).network_settlement_ids.size(), 3, "Snapshot owns removed membership")
	expect_equal(_road_record(state).network_settlement_ids.size(), 0, "Current graph reflects access removal")
	return true


func resolving_records_payment_history() -> bool:
	var state: RunState = _chain(3)
	var road: FeatureLineageState = _lineage(state, 0, TYPE.ROAD)
	var expected: Array[int] = _road_record(state).network_settlement_ids
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	expect_equal(road.scored_settlement_ids, expected, "Resolution permanently stores per-Road identities")
	expect_equal(state.features.tracks.values[TRACK.TRADE], 24, "Three independent completed Roads legitimately score")
	var count: int = state.features.completions.size()
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	expect_equal(state.features.completions.size(), count, "Completed state cannot repeat its completion trigger")
	return true


func old_payment_is_not_eligible_again() -> bool:
	var state: RunState = _chain(2)
	var road: FeatureLineageState = _lineage(state, 0, TYPE.ROAD)
	var paid: int = _lineage(state, 0, TYPE.SETTLEMENT).lineage_id
	road.scored_settlement_ids.append(paid)
	var record: FeatureCompletionRecord = _road_record(state)
	expect_equal(record.gains[TRACK.TRADE], 4, "Only one new Settlement plus two Road tiles")
	expect_true(not record.new_settlement_ids.has(paid), "Historical payment is excluded")
	return true


func paid_ancestor_blocks_merged_settlement() -> bool:
	var state: RunState = _chain(1)
	var road: FeatureLineageState = _lineage(state, 0, TYPE.ROAD)
	var settlement: FeatureLineageState = _lineage(state, 0, TYPE.SETTLEMENT)
	var parent: FeatureLineageState = _historical_parent(state, settlement)
	var grandparent: FeatureLineageState = _historical_parent(state, parent)
	road.scored_settlement_ids.append(grandparent.lineage_id)
	expect_equal(_road_record(state).new_settlement_ids, [], "Transitive ancestor already paid this Road")
	expect_equal(_road_record(state).gains[TRACK.TRADE], 2, "Merged descendant cannot repay connection bonus")
	return true


func unpaid_merged_settlement_can_pay() -> bool:
	var state: RunState = _chain(1)
	var settlement: FeatureLineageState = _lineage(state, 0, TYPE.SETTLEMENT)
	_historical_parent(state, settlement)
	_historical_parent(state, settlement)
	expect_equal(_road_record(state).new_settlement_ids, [settlement.lineage_id], "Current descendant pays once when neither ancestor paid")
	return true


func historical_road_merger_unions_payments() -> bool:
	var state: RunState = _chain(2)
	var first: FeatureLineageState = _lineage(state, 0, TYPE.ROAD)
	var second: FeatureLineageState = _lineage(state, 2, TYPE.ROAD)
	first.scored_settlement_ids = [_lineage(state, 0, TYPE.SETTLEMENT).lineage_id]
	second.scored_settlement_ids = [_lineage(state, 1, TYPE.SETTLEMENT).lineage_id]
	var expected: Array[int] = first.scored_settlement_ids + second.scored_settlement_ids
	expected.sort()
	var merged: CurrentFeature = CurrentFeature.new()
	merged.feature_type = TYPE.ROAD
	merged.component_ids = first.member_ids + second.member_ids
	merged.component_ids.sort()
	LineageService.reconcile(state, [merged])
	var descendant: FeatureLineageState = state.features.lineage(merged.lineage_id)
	expect_equal(descendant.scored_settlement_ids, expected, "Road lineage merger retains both parents' paid Settlements")
	expect_true(not first.active and not second.active, "Parent Road identities remain historical")
	return true


func network_growth_does_not_score() -> bool:
	var state: RunState = _chain(1)
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	var before: Array[int] = state.features.tracks.values.duplicate()
	var history_count: int = state.features.completions.size()
	var cell: BoardCellState = Fixture.add(state, Vector2i(2, 0), [EDGE.ROAD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	# This isolated added Road has no access; reconstruction still must never score.
	Fixture.reconcile(state)
	TradeNetworkService.reconcile(state, cell.base_tile_copy_id)
	expect_equal(state.features.tracks.values, before, "Trade reconstruction never awards retroactive score")
	expect_equal(state.features.completions.size(), history_count, "No completion events from network reconciliation")
	return true


func no_network_has_only_tile_trade() -> bool:
	var state: RunState = _chain(1)
	state.expansion.board.get_cell(Vector2i.ZERO).relationships.clear()
	TradeNetworkService.reconcile(state)
	var record: FeatureCompletionRecord = _road_record(state)
	expect_equal(record.trade_network_id, 0, "Standalone Road has no qualifying network identity")
	expect_equal(record.gains[TRACK.TRADE], 2, "Physical Road tile base score remains independent")
	return true


func _chain(settlement_count: int, open_middle_road: bool = false) -> RunState:
	var state: RunState = Fixture.empty()
	state.trade = TradeState.new()
	# Alternating shared Road/Settlement sockets create distinct physical features.
	# The first Settlement has an open western exit; every Road normally closes.
	for x: int in range(settlement_count * 2):
		var last: bool = x == settlement_count * 2 - 1
		var left: DomainTypes.EdgeType = EDGE.SETTLEMENT if x % 2 == 0 else EDGE.ROAD
		var right: DomainTypes.EdgeType = EDGE.FIELD if last else (EDGE.ROAD if x % 2 == 0 else EDGE.SETTLEMENT)
		var north: DomainTypes.EdgeType = EDGE.ROAD if open_middle_road and x == 2 else EDGE.FIELD
		var cell: BoardCellState = Fixture.add(state, Vector2i(x, 0), [north, right, EDGE.FIELD, left])
		if not last:
			cell.relationships.append(TileFeatureRelationship.new())
	Fixture.reconcile(state)
	TradeNetworkService.reconcile(state)
	return state


func _lineage(state: RunState, x: int, type: DomainTypes.FeatureType) -> FeatureLineageState:
	return state.features.lineage(state.features.component_at(Vector2i(x, 0), type).lineage_id)


func _current(state: RunState, lineage_id: int) -> CurrentFeature:
	for feature: CurrentFeature in TopologyService.rebuild(state):
		if feature.lineage_id == lineage_id:
			return feature
	return null


func _road_record(state: RunState) -> FeatureCompletionRecord:
	return _record_from(FeatureScoringService.capture(state, TopologyService.rebuild(state)),
		_lineage(state, 0, TYPE.ROAD).lineage_id)


func _record_from(snapshot: CompletionSnapshot, lineage_id: int) -> FeatureCompletionRecord:
	for record: FeatureCompletionRecord in FeatureScoringService.calculate(snapshot):
		if record.lineage_id == lineage_id:
			return record
	return null


func _historical_parent(state: RunState, descendant: FeatureLineageState) -> FeatureLineageState:
	var parent: FeatureLineageState = FeatureLineageState.new()
	parent.lineage_id = state.id_allocator.allocate()
	parent.feature_type = descendant.feature_type
	parent.active = false
	state.features.lineages.append(parent)
	descendant.parent_ids.append(parent.lineage_id)
	descendant.parent_ids.sort()
	return parent
