extends "res://tests/framework/test_suite.gd"

const Graph = preload("res://tests/fixtures/topology_fixture.gd")
const Junction = preload("res://content/tiles/homestead/road_junction.tres")
const TYPE = DomainTypes.FeatureType


func tests() -> Array[Callable]:
	return [empty_hub_has_no_road, three_roads_remain_separate, terminal_closes_road,
		one_hub_completes_three_roads_together, hub_scores_no_road_tiles,
		trade_connects_three_roads, hub_to_hub_has_no_road_length,
		settlement_access_propagates_through_hub, merchant_sees_full_hub_network,
		junction_does_not_become_specialist_target, junction_locality_includes_attached_road,
		old_road_components_exclude_junction, junction_growth_excludes_hub,
		hub_serialization_preserves_identity, hub_graph_queries_are_pure,
		hub_graph_order_is_deterministic, growth_retains_network_identity,
		hub_merger_retains_network_parents, market_families_see_junction_network,
		command_completion_and_full_save_roundtrip, hub_membership_order_normalizes,
		assigned_roads_do_not_merge_at_junction]


func _hub(state: RunState, at: Vector2i = Vector2i.ZERO, rotation: int = 0) -> BoardCellState:
	var cell: BoardCellState = BoardCellState.from_definition(Junction,
		state.id_allocator.allocate(), at, rotation, state.expansion.current_act, 0)
	state.expansion.board.add_cell(cell)
	TopologyService.add_cell_components(state, cell)
	return cell


func _three_roads(state: RunState) -> void:
	Graph.add(state, Vector2i.UP, [0, 0, 3, 0])
	Graph.add(state, Vector2i.RIGHT, [0, 0, 0, 3])
	Graph.add(state, Vector2i.DOWN, [3, 0, 0, 0])
	Graph.reconcile(state)


func _ready_three() -> RunState:
	var state: RunState = Graph.empty()
	_three_roads(state)
	_hub(state)
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	return state


func empty_hub_has_no_road() -> bool:
	var state: RunState = Graph.empty()
	_hub(state)
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	expect_equal(state.features.components.size(), 0, "Empty hub arms create no unfinished Road")
	expect_equal(IntersectionHubService.rebuild(state)[0].socket_directions, [0, 1, 2], "Three terminal sockets")
	expect_equal(TradeNetworkService.rebuild(state)[0].road_lineage_ids.size(), 0, "Infrastructure network has no invented Road")
	return true


func three_roads_remain_separate() -> bool:
	var state: RunState = _ready_three()
	var roads: Array[CurrentFeature] = TopologyService.rebuild(state)
	expect_equal(roads.size(), 3, "Three incoming physical Roads remain separate")
	for road: CurrentFeature in roads:
		expect_equal(road.component_ids.size(), 1, "Hub adds zero physical size")
		expect_equal(road.open_exits, 0, "Every incoming arm terminates")
	return true


func terminal_closes_road() -> bool:
	var state: RunState = Graph.empty()
	Graph.add(state, Vector2i.UP, [0, 0, 3, 0])
	Graph.reconcile(state)
	expect_equal(TopologyService.rebuild(state)[0].open_exits, 1, "Road initially has an unresolved exit")
	_hub(state)
	Graph.reconcile(state)
	expect_equal(TopologyService.rebuild(state)[0].open_exits, 0, "Hub closes Road without closing all its own sockets")
	return true


func one_hub_completes_three_roads_together() -> bool:
	var state: RunState = _ready_three()
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	expect_equal(state.features.completions.size(), 3, "One Junction causes three genuine Road completions")
	var snapshot_id: int = state.features.completions[0].snapshot_id
	for record: FeatureCompletionRecord in state.features.completions:
		expect_equal(record.snapshot_id, snapshot_id, "All Roads use one immutable completion batch")
	return true


func hub_scores_no_road_tiles() -> bool:
	var state: RunState = _ready_three()
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	expect_equal(state.features.tracks.values[DomainTypes.TrackType.TRADE], 3, "Three physical Road tiles score; Junction scores zero")
	expect_equal(state.features.largest_completed_sizes[TYPE.ROAD], 1, "Longest Road excludes Junction")
	return true


func trade_connects_three_roads() -> bool:
	var state: RunState = _ready_three()
	var network: CurrentTradeNetwork = TradeNetworkService.rebuild(state)[0]
	expect_equal(network.road_lineage_ids.size(), 3, "Separate Roads share the existing Trade graph")
	expect_equal(network.junction_hub_ids.size(), 1, "Explicit hub graph member")
	expect_equal(network.settlement_lineage_ids.size(), 0, "No phantom Settlement is invented")
	return true


func hub_to_hub_has_no_road_length() -> bool:
	var state: RunState = Graph.empty()
	_hub(state)
	_hub(state, Vector2i.RIGHT, 2)
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	var network: CurrentTradeNetwork = TradeNetworkService.rebuild(state)[0]
	expect_equal(network.junction_hub_ids.size(), 2, "Matching Junction sockets connect hubs")
	expect_equal(network.road_lineage_ids.size(), 0, "Hub-to-hub link adds no physical Road")
	expect_equal(network.links.size(), 1, "Reciprocal hub link emitted only once")
	return true


func _commercial() -> RunState:
	var state: RunState = Graph.empty()
	_hub(state)
	var first: BoardCellState = Graph.add(state, Vector2i.UP, [4, 0, 3, 0])
	var second: BoardCellState = Graph.add(state, Vector2i.RIGHT, [0, 4, 0, 3])
	first.relationships.append(TileFeatureRelationship.new())
	second.relationships.append(TileFeatureRelationship.new())
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	return state


func settlement_access_propagates_through_hub() -> bool:
	var state: RunState = _commercial()
	var first: int = state.features.component_at(Vector2i.UP, TYPE.ROAD).lineage_id
	var second: int = state.features.component_at(Vector2i.RIGHT, TYPE.ROAD).lineage_id
	expect_equal(TradeNetworkService.settlements_reachable_from_road(state, first).size(), 2, "Road sees Settlement beyond other Junction arm")
	expect_true(TradeNetworkService.same_network(state, first, second), "Physical Roads are commercially connected")
	var snapshot: CompletionSnapshot = FeatureScoringService.capture(state, TopologyService.rebuild(state))
	for record: FeatureCompletionRecord in FeatureScoringService.calculate(snapshot):
		expect_equal(record.gains[1], 5, "Each Road scores one physical tile plus two Settlement relationships")
	return true


func _assign(state: RunState, at: Vector2i, role: StringName) -> SpecialistPieceState:
	SpecialistRules.initialize(state)
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	piece.role_definition_id = role
	piece.status = SpecialistPieceState.Status.ASSIGNED
	piece.assigned_target_type = TYPE.ROAD
	piece.assigned_target_id = state.features.component_at(at, TYPE.ROAD).lineage_id
	piece.assigned_act = 1
	piece.growth_baseline_component_ids = SpecialistRules.all_component_ids(state)
	return piece


func merchant_sees_full_hub_network() -> bool:
	var state: RunState = _commercial()
	_assign(state, Vector2i.UP, &"specialist.merchant")
	var effects: Array[Dictionary] = SpecialistRules.calculate(FeatureScoringService.capture(state, TopologyService.rebuild(state)))
	expect_equal(effects[0]["gains"][1], 2, "Merchant counts both Settlement hubs through Junction")
	return true


func junction_does_not_become_specialist_target() -> bool:
	var state: RunState = Graph.empty()
	_hub(state)
	Graph.reconcile(state)
	SpecialistRules.initialize(state)
	var command: PlaceTileCommand = PlaceTileCommand.new()
	command.coordinate = Vector2i.ZERO
	expect_equal(SpecialistPlacementService.affected_targets(state, command, null).size(), 0, "Junction itself is never a Road target")
	return true


func junction_locality_includes_attached_road() -> bool:
	var state: RunState = Graph.empty()
	Graph.add(state, Vector2i.UP, [3, 0, 3, 0])
	_hub(state)
	Graph.reconcile(state)
	SpecialistRules.initialize(state)
	var command: PlaceTileCommand = PlaceTileCommand.new()
	command.coordinate = Vector2i.ZERO
	var targets: Array[Dictionary] = SpecialistPlacementService.affected_targets(state, command, null)
	expect_equal(targets.size(), 1, "Junction directly affects its attached unfinished Road")
	expect_equal(SpecialistRules.assignment_options(state, targets).size(), 2, "Both available Stewards may choose that local Road")
	return true


func old_road_components_exclude_junction() -> bool:
	var state: RunState = _ready_three()
	state.relics = RelicState.new()
	var facts: Dictionary = RelicRules.capture(state, TopologyService.rebuild(state))
	for feature: CurrentFeature in TopologyService.rebuild(state):
		expect_equal(facts["feature_facts"][str(feature.lineage_id)]["act_one_road_count"], 1, "Historic Routes counts real Act-I Road component only")
	return true


func junction_growth_excludes_hub() -> bool:
	var state: RunState = Graph.empty()
	Graph.add(state, Vector2i.UP, [0, 0, 3, 0])
	Graph.reconcile(state)
	var piece: SpecialistPieceState = _assign(state, Vector2i.UP, &"specialist.cartographer")
	_hub(state)
	var current: Array[CurrentFeature] = Graph.reconcile(state)
	SpecialistRules.remap_and_growth(state, current)
	expect_equal(piece.qualifying_component_ids.size(), 0, "Junction creates no Cartographer growth")
	expect_equal(SpecialistRules.calculate(FeatureScoringService.capture(state, current))[0]["gains"][1], 0, "Cartographer receives no Junction tile bonus")
	return true


func hub_serialization_preserves_identity() -> bool:
	var state: RunState = _commercial()
	var encoded_board: Dictionary = ExpansionSerializer.encode(state.expansion)
	var encoded_trade: Dictionary = TradeSerializer.encode(state.trade)
	expect_true(ExpansionSerializer.validate_shape(encoded_board).is_valid, "Hub board schema validates")
	expect_true(TradeSerializer.validate_shape(encoded_trade).is_valid, "Hub genealogy schema validates")
	var mirror: RunState = RunState.new(913)
	mirror.expansion = ExpansionSerializer.decode(encoded_board)
	mirror.features = FeatureSerializer.decode(FeatureSerializer.encode(state.features))
	mirror.trade = TradeSerializer.decode(encoded_trade)
	expect_equal(IntersectionHubService.rebuild(mirror)[0].hub_id, IntersectionHubService.rebuild(state)[0].hub_id, "Stable physical-copy hub identity survives")
	expect_equal(TradeNetworkService.rebuild(mirror)[0].signature(), TradeNetworkService.rebuild(state)[0].signature(), "Exact graph reconstructed from persisted data")
	expect_equal(TradeSerializer.encode(mirror.trade), encoded_trade, "Load does not reconcile or allocate genealogy")
	return true


func hub_graph_queries_are_pure() -> bool:
	var state: RunState = _commercial()
	var before: String = StateNormalizer.fingerprint(state)
	for repeat: int in range(3):
		IntersectionHubService.rebuild(state)
		TradeNetworkService.rebuild(state)
		TradeNetworkService.reconcile(state)
	expect_equal(StateNormalizer.fingerprint(state), before, "Hub queries and unchanged reconciliation consume no RNG, IDs or history")
	return true


func hub_graph_order_is_deterministic() -> bool:
	var state: RunState = _commercial()
	var signature: String = TradeNetworkService.rebuild(state)[0].signature()
	state.features.components.reverse()
	state.features.lineages.reverse()
	state.trade.lineages.reverse()
	expect_equal(TradeNetworkService.rebuild(state)[0].signature(), signature, "Dictionary/registry order cannot change hub graph")
	return true


func growth_retains_network_identity() -> bool:
	var state: RunState = Graph.empty()
	_hub(state)
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	var original: int = TradeNetworkService.rebuild(state)[0].lineage_id
	Graph.add(state, Vector2i.UP, [0, 0, 3, 0])
	Graph.reconcile(state)
	TradeNetworkService.reconcile(state)
	expect_equal(TradeNetworkService.rebuild(state)[0].lineage_id, original, "First attached Road grows the same infrastructure network")
	return true


func hub_merger_retains_network_parents() -> bool:
	var state: RunState = Graph.empty()
	_hub(state)
	_hub(state, Vector2i(2, 0), 2)
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	var parents: Array[int] = []
	for network: CurrentTradeNetwork in TradeNetworkService.rebuild(state):
		parents.append(network.lineage_id)
	_hub(state, Vector2i.RIGHT, 1)
	Graph.reconcile(state)
	TradeNetworkService.reconcile(state)
	var merged: CurrentTradeNetwork = TradeNetworkService.rebuild(state)[0]
	expect_equal(merged.junction_hub_ids.size(), 3, "Middle Junction joins both infrastructure networks")
	for parent: int in parents:
		expect_true(TradeNetworkService.is_ancestor(state, parent, merged.lineage_id), "Existing Trade genealogy records hub merger ancestry")
	expect_equal(state.features.tracks.values, [0, 0, 0, 0], "Economic network merger does not retroactively score")
	return true


func market_families_see_junction_network() -> bool:
	for stage: StringName in [&"market", &"grand_market"]:
		var state: RunState = _commercial()
		var cell: BoardCellState = state.expansion.board.get_cell(Vector2i.UP)
		var settlement: int = state.features.component_at(Vector2i.UP, TYPE.SETTLEMENT).lineage_id
		var development: DevelopmentState = DevelopmentState.new()
		development.tile_copy_id = state.id_allocator.allocate()
		development.host_lineage_id = settlement
		development.host_kind = &"settlement"
		development.family_id = &"market"
		development.stage = stage
		cell.developments.append(development)
		var facts: Array[Dictionary] = DevelopmentEffects.capture(state, TopologyService.rebuild(state), [settlement])
		var effects: Array[Dictionary] = DevelopmentEffects.calculate(CompletionSnapshot.new({"developments": facts}))
		expect_equal(effects[0]["gains"][1], 1 if stage == &"market" else 2, "Market family sees other Settlement across Junction")
	return true


func command_completion_and_full_save_roundtrip() -> bool:
	var content: ContentRegistry = ContentRegistry.new()
	expect_true(content.load_phase_nine().is_valid, "Current canonical content loads")
	var state: RunState = HomesteadRunFactory.create(6001, content)
	var fixture: Script = preload("res://tests/fixtures/phase_five_factory.gd")
	var copy_id: int = fixture.acquire_hand(state, &"tile.road_junction")
	var selected: PlacementOption = null
	for option: PlacementOption in PlacementQueryService.query_for_copy(state, content, copy_id):
		if option.coordinate == Vector2i.RIGHT:
			selected = option
			break
	expect_true(selected != null, "Junction can terminate Founding Road at east edge")
	if selected == null:
		return true
	var result: ValidationResult = RulesEngine.execute(state, content, fixture.command(selected))
	expect_true(result.is_valid, "Real command commits Junction and runs normal consequence pipeline")
	expect_equal(state.features.completions.size(), 1, "Founding Road genuinely completes once")
	expect_equal(state.features.completions[0].total_size, 1, "Junction is absent from completion Road size")
	var saved: SerializationResult = RunSerializer.serialize(state, content)
	expect_true(saved.validation.is_valid, "Full state with hub network passes invariant/save validation")
	if not saved.validation.is_valid:
		return true
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	expect_true(loaded.validation.is_valid, "Full revised save restores hub graph")
	if loaded.state != null:
		expect_equal(StateNormalizer.fingerprint(loaded.state), StateNormalizer.fingerprint(state), "Full save/load preserves hub identity, score and RNG exactly")
	return true


func hub_membership_order_normalizes() -> bool:
	var state: RunState = Graph.empty()
	_hub(state)
	_hub(state, Vector2i.RIGHT, 2)
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	var before: String = StateNormalizer.fingerprint(state)
	for lineage: TradeNetworkLineageState in state.trade.lineages:
		lineage.junction_hub_ids.reverse()
	for event: TradeHistoryRecord in state.trade.history:
		event.junction_hub_ids.reverse()
	expect_equal(StateNormalizer.fingerprint(state), before, "Hub identity set order has no gameplay meaning")
	return true


func assigned_roads_do_not_merge_at_junction() -> bool:
	var state: RunState = Graph.empty()
	Graph.add(state, Vector2i.UP, [0, 0, 3, 0])
	Graph.add(state, Vector2i.RIGHT, [0, 0, 0, 3])
	Graph.reconcile(state)
	SpecialistRules.initialize(state)
	for index: int in range(2):
		var piece: SpecialistPieceState = state.specialists.pieces[index]
		piece.status = SpecialistPieceState.Status.ASSIGNED
		piece.assigned_target_type = TYPE.ROAD
		piece.assigned_target_id = state.features.component_at(Vector2i.UP if index == 0 else Vector2i.RIGHT, TYPE.ROAD).lineage_id
	expect_true(SpecialistPlacementService.expansion_is_legal(state, Junction, 100, Vector2i.ZERO, 0), "Distinct assigned Roads terminate at hub; no prohibited physical merger occurs")
	return true
