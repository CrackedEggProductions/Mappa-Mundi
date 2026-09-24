extends "res://tests/framework/test_suite.gd"
## Ferry augments the Phase-4 economic graph, never the physical Road graph.

const Graph = preload("res://tests/fixtures/topology_fixture.gd")
const TYPE = DomainTypes.FeatureType
const EDGE = DomainTypes.EdgeType


func tests() -> Array[Callable]:
	return [same_river_links_settlements, transitive_road_hub_propagation,
		multiple_river_settlements_distinct, separate_rivers_do_not_cross_link,
		river_without_road_access_not_network, merchant_sees_ferry,
		road_base_connectivity_sees_ferry, market_sees_ferry, grand_market_sees_ferry,
		road_milestone_snapshot_sees_ferry, physical_road_length_unchanged,
		acquisition_recomputes_without_scoring, replacement_splits_without_undoing_scoring,
		genealogy_retains_split_ancestry, queries_are_deterministic,
		river_contact_requires_authoritative_relationship, old_snapshot_keeps_old_network,
		second_river_propagates_transitively, invalid_acquisition_does_not_recompute,
		ferry_roundtrip_preserves_graph_and_rng]


func _registry() -> ContentRegistry:
	var registry: ContentRegistry = ContentRegistry.new()
	assert(registry.load_phase_eight().is_valid)
	return registry


func _empty() -> RunState:
	var state: RunState = Graph.empty()
	state.relics = RelicState.new()
	state.rewards = RewardState.new()
	return state


func _add(state: RunState, x: int, road: bool) -> void:
	var edges: Array[DomainTypes.EdgeType] = [EDGE.SETTLEMENT, EDGE.RIVER, EDGE.ROAD if road else EDGE.FIELD, EDGE.RIVER]
	var cell: BoardCellState = Graph.add(state, Vector2i(x, 0), edges)
	var touch: TileFeatureRelationship = TileFeatureRelationship.new()
	touch.from_edge_type = EDGE.SETTLEMENT
	touch.to_edge_type = EDGE.RIVER
	touch.kind = TileFeatureRelationship.Kind.SETTLEMENT_RIVER_TOUCH
	cell.relationships.append(touch)
	if road:
		var access: TileFeatureRelationship = TileFeatureRelationship.new()
		access.from_edge_type = EDGE.ROAD
		access.to_edge_type = EDGE.SETTLEMENT
		access.kind = TileFeatureRelationship.Kind.ROAD_SETTLEMENT_ACCESS
		cell.relationships.append(access)


func _chain(count: int = 3, last_road: bool = true) -> RunState:
	var state: RunState = _empty()
	for index: int in range(count):
		_add(state, index, index == 0 or (last_road and index == count - 1))
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	return state


func _acquire(state: RunState, id: StringName = RelicRules.FERRY, replace_id: StringName = &"") -> void:
	var result: ValidationResult = RelicRules.acquire(state, _registry(), id, replace_id)
	assert(result.is_valid, result.user_message)


func _road_id(state: RunState, x: int = 0) -> int:
	return state.features.component_at(Vector2i(x, 0), TYPE.ROAD).lineage_id


func same_river_links_settlements() -> bool:
	var state: RunState = _chain(2, false)
	expect_equal(TradeNetworkService.settlement_count(state, _road_id(state)), 1, "Before Ferry only road-accessed Settlement")
	_acquire(state)
	expect_equal(TradeNetworkService.settlement_count(state, _road_id(state)), 2, "Same connected River Settlement joins")
	return true


func transitive_road_hub_propagation() -> bool:
	var state: RunState = _chain(3)
	_acquire(state)
	var network: CurrentTradeNetwork = TradeNetworkService.network_for_road(state, _road_id(state))
	expect_equal(network.road_lineage_ids.size(), 2, "Ferry Settlement hub propagates onto attached Road")
	expect_true(TradeNetworkService.same_network(state, _road_id(state), _road_id(state, 2)), "Both Roads join same economic graph")
	return true


func multiple_river_settlements_distinct() -> bool:
	var state: RunState = _chain(5)
	_acquire(state)
	expect_equal(TradeNetworkService.settlement_count(state, _road_id(state)), 5, "Five distinct Settlements count once")
	return true


func separate_rivers_do_not_cross_link() -> bool:
	var state: RunState = _empty()
	for x: int in [0, 1, 10, 11]:
		_add(state, x, x in [0, 10])
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	_acquire(state)
	expect_equal(TradeNetworkService.rebuild(state).size(), 2, "Different connected Rivers stay separate")
	expect_equal(TradeNetworkService.settlement_count(state, _road_id(state)), 2, "No cross-River connectivity")
	return true


func river_without_road_access_not_network() -> bool:
	var state: RunState = _empty()
	_add(state, 0, false)
	_add(state, 1, false)
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	_acquire(state)
	expect_true(TradeNetworkService.rebuild(state).is_empty(), "Ferry alone without native Road access is not a Trade Network")
	return true


func merchant_sees_ferry() -> bool:
	var state: RunState = _chain(3)
	_acquire(state)
	SpecialistRules.initialize(state)
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	piece.role_definition_id = &"specialist.merchant"
	piece.status = SpecialistPieceState.Status.ASSIGNED
	piece.assigned_target_type = TYPE.ROAD
	piece.assigned_target_id = _road_id(state)
	var facts: Array[Dictionary] = SpecialistRules.capture(state, TopologyService.rebuild(state), [_road_id(state)], [])
	var effects: Array[Dictionary] = SpecialistRules.calculate(CompletionSnapshot.new({"specialists": facts}))
	expect_equal(effects[0]["gains"][1], 4, "Merchant sees full Ferry network")
	return true


func road_base_connectivity_sees_ferry() -> bool:
	var state: RunState = _chain(3)
	_acquire(state)
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	var road: CurrentFeature = SpecialistRules.find_feature(current, _road_id(state))
	road.open_exits = 0 # Controlled completion snapshot; graph state remains authoritative.
	var snapshot: CompletionSnapshot = FeatureScoringService.capture(state, current)
	var records: Array[FeatureCompletionRecord] = FeatureScoringService.calculate(snapshot)
	expect_equal(records[0].new_settlement_ids.size(), 3, "Base scoring captures Ferry-linked distinct Settlements")
	expect_equal(records[0].gains[1], 7, "One physical Road tile plus three Settlement connections")
	return true


func _market(stage: StringName) -> int:
	var state: RunState = _chain(3)
	_acquire(state)
	var host_id: int = state.features.component_at(Vector2i.ZERO, TYPE.SETTLEMENT).lineage_id
	var development: DevelopmentState = DevelopmentState.new()
	development.tile_copy_id = state.id_allocator.allocate()
	development.stage = stage
	development.family_id = &"family.market"
	development.host_kind = &"settlement"
	development.host_lineage_id = host_id
	state.expansion.board.get_cell(Vector2i.ZERO).developments.append(development)
	var facts: Array[Dictionary] = DevelopmentEffects.capture(state, TopologyService.rebuild(state), [host_id])
	return DevelopmentEffects.calculate(CompletionSnapshot.new({"developments": facts}))[0]["gains"][1]


func market_sees_ferry() -> bool:
	expect_equal(_market(&"market"), 2, "Market sees two other Ferry-linked Settlements")
	return true


func grand_market_sees_ferry() -> bool:
	expect_equal(_market(&"grand_market"), 4, "Grand Market sees two other Ferry-linked Settlements")
	return true


func road_milestone_snapshot_sees_ferry() -> bool:
	var state: RunState = _chain(5)
	_acquire(state)
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	SpecialistRules.find_feature(current, _road_id(state)).open_exits = 0
	var snapshot: CompletionSnapshot = FeatureScoringService.capture(state, current)
	expect_equal(snapshot.data()["features"][0]["network_settlement_ids"].size(), 5, "Milestone consumes full five-Settlement network in genuine completion facts")
	return true


func physical_road_length_unchanged() -> bool:
	var state: RunState = _chain(5)
	var before: String = Graph.signature(TopologyService.rebuild(state))
	_acquire(state)
	expect_equal(Graph.signature(TopologyService.rebuild(state)), before, "River links do not alter Road components or physical topology")
	return true


func acquisition_recomputes_without_scoring() -> bool:
	var state: RunState = _chain(3)
	var revision: int = state.trade.trade_revision
	var rng_state: int = state.current_rng_state
	var tracks: Array[int] = state.features.tracks.values.duplicate()
	_acquire(state)
	expect_true(state.trade.trade_revision > revision, "Acquisition immediately reconciles network genealogy")
	expect_equal(state.features.tracks.values, tracks, "No retroactive payouts")
	expect_equal(state.current_rng_state, rng_state, "No connectivity RNG")
	return true


func replacement_splits_without_undoing_scoring() -> bool:
	var state: RunState = _chain(3)
	_acquire(state)
	_acquire(state, RelicRules.GREEN)
	state.features.tracks.add(DomainTypes.TrackType.TRADE, 12)
	_acquire(state, RelicRules.BOUNDARY, RelicRules.FERRY)
	expect_equal(TradeNetworkService.rebuild(state).size(), 2, "Removal immediately splits network")
	expect_equal(state.features.tracks.values[1], 12, "Earned Trade remains")
	expect_true(RelicRules.FERRY not in RelicRules.eligible_ids(state, _registry()), "Removed Ferry remains exhausted")
	return true


func genealogy_retains_split_ancestry() -> bool:
	var state: RunState = _chain(3)
	_acquire(state)
	var merged_id: int = TradeNetworkService.rebuild(state)[0].lineage_id
	_acquire(state, RelicRules.GREEN)
	_acquire(state, RelicRules.BOUNDARY, RelicRules.FERRY)
	for network: CurrentTradeNetwork in TradeNetworkService.rebuild(state):
		expect_true(TradeNetworkService.is_ancestor(state, merged_id, network.lineage_id), "Split preserves merged network ancestry")
	return true


func queries_are_deterministic() -> bool:
	var state: RunState = _chain(5)
	_acquire(state)
	var signature: String = TradeNetworkService.graph_signature(state)
	var before: Array = [state.next_runtime_id, state.current_rng_state, state.rng.operation_count, state.trade.history.size()]
	state.features.components.reverse()
	state.features.lineages.reverse()
	expect_equal(TradeNetworkService.graph_signature(state), signature, "Insertion order cannot alter Ferry links")
	TradeNetworkService.rebuild(state)
	expect_equal([state.next_runtime_id, state.current_rng_state, state.rng.operation_count, state.trade.history.size()], before, "Rebuild is pure")
	return true


func river_contact_requires_authoritative_relationship() -> bool:
	var state: RunState = _chain(3)
	state.expansion.board.get_cell(Vector2i(2, 0)).relationships.clear()
	TradeNetworkService.reconcile(state)
	_acquire(state)
	expect_equal(TradeNetworkService.settlement_count(state, _road_id(state)), 2, "Missing explicit same-tile contact does not infer Ferry connection from cohabitation")
	return true


func old_snapshot_keeps_old_network() -> bool:
	var state: RunState = _chain(3)
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	SpecialistRules.find_feature(current, _road_id(state)).open_exits = 0
	var snapshot: CompletionSnapshot = FeatureScoringService.capture(state, current)
	_acquire(state)
	expect_equal(FeatureScoringService.calculate(snapshot)[0].network_settlement_ids.size(), 1, "Later acquisition cannot revise captured Road connectivity")
	return true


func second_river_propagates_transitively() -> bool:
	var state: RunState = _chain(2, false)
	var upper: BoardCellState = Graph.add(state, Vector2i(1, -1), [0, 2, 4, 2])
	var peer: BoardCellState = Graph.add(state, Vector2i(2, -1), [4, 2, 0, 2])
	for cell: BoardCellState in [upper, peer]:
		var contact: TileFeatureRelationship = TileFeatureRelationship.new()
		contact.from_edge_type = EDGE.SETTLEMENT
		contact.to_edge_type = EDGE.RIVER
		contact.kind = TileFeatureRelationship.Kind.SETTLEMENT_RIVER_TOUCH
		cell.relationships.append(contact)
	Graph.reconcile(state)
	TradeNetworkService.reconcile(state)
	_acquire(state)
	expect_equal(TradeNetworkService.settlement_count(state, _road_id(state)), 3, "Shared Settlement hub carries connectivity across additional River")
	return true


func invalid_acquisition_does_not_recompute() -> bool:
	var state: RunState = _chain(3)
	_acquire(state)
	var before: Array = [state.next_runtime_id, state.current_rng_state, state.trade.trade_revision,
		state.trade.history.size(), state.relics.history.size()]
	expect_true(not RelicRules.acquire(state, _registry(), RelicRules.FERRY).is_valid, "Exhausted reacquisition illegal")
	expect_equal([state.next_runtime_id, state.current_rng_state, state.trade.trade_revision,
		state.trade.history.size(), state.relics.history.size()], before, "Rejected acquisition has zero network or history changes")
	return true


func ferry_roundtrip_preserves_graph_and_rng() -> bool:
	var registry: ContentRegistry = _registry()
	var state: RunState = HomesteadRunFactory.create(82471, registry)
	const Geography = preload("res://tests/fixtures/phase_three_factory.gd")
	Geography.add(state, registry, &"tile.riverside_hamlet", Vector2i.UP, 2)
	Geography.add(state, registry, &"tile.riverside_hamlet", Vector2i(1, -1))
	var road_id: int = _road_id(state)
	_acquire(state)
	expect_equal(TradeNetworkService.settlement_count(state, road_id), 2, "Real definitions create Ferry connection")
	var fingerprint: String = StateNormalizer.fingerprint(state)
	for index: int in range(3):
		var saved: SerializationResult = RunSerializer.serialize(state, registry)
		expect_true(saved.validation.is_valid, str(saved.validation.debug_details))
		if not saved.validation.is_valid:
			return true
		var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, registry)
		expect_true(loaded.validation.is_valid, str(loaded.validation.debug_details))
		if not loaded.validation.is_valid:
			return true
		state = loaded.state
		expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Repeated load preserves IDs, RNG, scoring and network genealogy exactly")
		expect_equal(TradeNetworkService.settlement_count(state, road_id), 2, "Loaded Ferry connectivity")
	_acquire(state, RelicRules.GREEN)
	_acquire(state, RelicRules.BOUNDARY, RelicRules.FERRY)
	var removed_save: SerializationResult = RunSerializer.serialize(state, registry)
	expect_true(removed_save.validation.is_valid, str(removed_save.validation.debug_details))
	if removed_save.validation.is_valid:
		var removed: DeserializationResult = RunSerializer.deserialize(removed_save.json_text, registry)
		expect_true(removed.validation.is_valid, str(removed.validation.debug_details))
		if removed.validation.is_valid:
			expect_equal(StateNormalizer.fingerprint(removed.state), StateNormalizer.fingerprint(state), "Removed Ferry history and split graph round-trip")
			expect_equal(TradeNetworkService.settlement_count(removed.state, road_id), 1, "Removed Ferry links do not rebuild on load")
	return true
