extends "res://tests/framework/test_suite.gd"

const Fixture = preload("res://tests/fixtures/phase_four_factory.gd")
const Graph = preload("res://tests/fixtures/topology_fixture.gd")
const TYPE = DomainTypes.FeatureType


func tests() -> Array[Callable]:
	return [founding_access, gate_access, corner_gate_access, road_bend_access, throughway_access,
		adjacency_is_not_access, isolated_members_do_not_form_networks,
		transitive_hubs_keep_roads_distinct, deterministic_queries,
		growth_retains_identity, merger_retains_parents_without_score,
		split_and_reconnect_preserve_genealogy, rebuild_does_not_allocate_or_consume_rng,
		dissolved_network_reconnects_with_history]


func _definition_access(id: StringName) -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Graph.empty()
	var cell: BoardCellState = BoardCellState.from_definition(content.get_tile(id), state.id_allocator.allocate(), Vector2i.ZERO, 0, 1, 0)
	state.expansion.board.add_cell(cell)
	TopologyService.add_cell_components(state, cell)
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	var networks: Array[CurrentTradeNetwork] = TradeNetworkService.rebuild(state)
	expect_equal(networks.size(), 1, "Explicit definition access produces one economic network")
	expect_equal(networks[0].road_lineage_ids.size(), 1, "One physical Road")
	expect_equal(networks[0].settlement_lineage_ids.size(), 1, "One distinct Settlement")
	expect_true(networks[0].road_lineage_ids[0] != networks[0].settlement_lineage_ids[0], "Access never collapses feature identity")
	return true


func founding_access() -> bool: return _definition_access(&"tile.founding.homestead")
func gate_access() -> bool: return _definition_access(&"tile.settlement_gate")
func corner_gate_access() -> bool: return _definition_access(&"tile.settlement_corner_gate")
func road_bend_access() -> bool: return _definition_access(&"tile.settlement_road_bend")
func throughway_access() -> bool: return _definition_access(&"tile.settlement_road_throughway")


func adjacency_is_not_access() -> bool:
	var state: RunState = Graph.empty()
	Graph.add(state, Vector2i.ZERO, [3, 0, 0, 0])
	Graph.add(state, Vector2i.RIGHT, [4, 0, 0, 0])
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	expect_equal(TradeNetworkService.rebuild(state).size(), 0, "Adjacent Road and Settlement without access remain economically separate")
	return true


func isolated_members_do_not_form_networks() -> bool:
	var state: RunState = Graph.empty()
	Graph.add(state, Vector2i.ZERO, [3, 0, 0, 0])
	Graph.add(state, Vector2i(10, 10), [4, 0, 0, 0])
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	expect_equal(state.trade.lineages.size(), 0, "Isolated members create no network history")
	return true


func transitive_hubs_keep_roads_distinct() -> bool:
	var state: RunState = Fixture.chain(Fixture.content(), 3)
	var network: CurrentTradeNetwork = TradeNetworkService.rebuild(state)[0]
	expect_equal(network.road_lineage_ids.size(), 3, "Three physically separate Roads")
	expect_equal(network.settlement_lineage_ids.size(), 4, "Founding plus three accessed Settlement hubs")
	for road_id: int in network.road_lineage_ids:
		expect_equal(TradeNetworkService.settlements_reachable_from_road(state, road_id), network.settlement_lineage_ids, "Full transitive reach from every Road")
	return true


func deterministic_queries() -> bool:
	var state: RunState = Fixture.chain(Fixture.content())
	var network: CurrentTradeNetwork = TradeNetworkService.rebuild(state)[0]
	var signature: String = network.signature()
	state.features.components.reverse()
	state.features.lineages.reverse()
	state.trade.lineages.reverse()
	expect_equal(TradeNetworkService.rebuild(state)[0].signature(), signature, "Insertion order does not alter graph")
	for settlement: int in network.settlement_lineage_ids:
		expect_equal(TradeNetworkService.network_for_settlement(state, settlement).lineage_id, network.lineage_id, "Settlement query resolves same network")
		expect_equal(TradeNetworkService.settlement_count(state, settlement), 3, "Current distinct count")
		expect_true(TradeNetworkService.same_network(state, settlement, network.road_lineage_ids[0]), "Hub and Road share network")
	return true


func growth_retains_identity() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	var id: int = TradeNetworkService.rebuild(state)[0].lineage_id
	Fixture.Previous.add(state, registry, &"tile.settlement_gate", Vector2i.RIGHT, 2)
	expect_equal(TradeNetworkService.rebuild(state)[0].lineage_id, id, "Adding a Settlement retains network identity")
	Fixture.Previous.add(state, registry, &"tile.settlement_gate", Vector2i.ONE)
	expect_equal(TradeNetworkService.rebuild(state)[0].lineage_id, id, "Adding an unfinished Road retains identity")
	return true


func merger_retains_parents_without_score() -> bool:
	var state: RunState = Fixture.pair(Fixture.content())
	var before: Array[int] = state.features.tracks.values.duplicate()
	Fixture.connect_pair(state)
	var network: CurrentTradeNetwork = TradeNetworkService.rebuild(state)[0]
	expect_equal(state.trade.lineage(network.lineage_id).parent_ids.size(), 2, "Merger records both prior networks")
	expect_equal(state.features.tracks.values, before, "Merger grants no score")
	return true


func split_and_reconnect_preserve_genealogy() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.pair(registry)
	Fixture.connect_pair(state)
	var ancestor: int = TradeNetworkService.rebuild(state)[0].lineage_id
	var before: Array[int] = state.features.tracks.values.duplicate()
	Fixture.disconnect_pair(state)
	var split: Array[CurrentTradeNetwork] = TradeNetworkService.rebuild(state)
	expect_equal(split.size(), 2, "Authorized bridge removal splits current network")
	for network: CurrentTradeNetwork in split:
		expect_true(TradeNetworkService.is_ancestor(state, ancestor, network.lineage_id), "Every split descendant retains ancestor")
	Fixture.connect_pair(state)
	var reconnected: int = TradeNetworkService.rebuild(state)[0].lineage_id
	for network: CurrentTradeNetwork in split:
		expect_true(TradeNetworkService.is_ancestor(state, network.lineage_id, reconnected), "Reconnection includes both split histories")
	expect_equal(state.features.tracks.values, before, "Split/reconnection produces zero Trade")
	expect_true(InvariantValidator.validate(state, registry).is_valid, "Genealogy remains invariant-valid")
	return true


func rebuild_does_not_allocate_or_consume_rng() -> bool:
	var state: RunState = Fixture.chain(Fixture.content())
	var fingerprint: String = StateNormalizer.fingerprint(state)
	for index: int in range(3):
		TradeNetworkService.rebuild(state)
		TradeNetworkService.reconcile(state)
	expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Unchanged rebuild and reconcile allocate and mutate nothing")
	return true


func dissolved_network_reconnects_with_history() -> bool:
	var state: RunState = Graph.empty()
	var cell: BoardCellState = Graph.add(state, Vector2i.ZERO, [4, 3, 0, 0])
	cell.relationships.append(TileFeatureRelationship.new())
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	var ancestor: int = TradeNetworkService.rebuild(state)[0].lineage_id
	cell.relationships.clear()
	TradeNetworkService.reconcile(state)
	expect_equal(TradeNetworkService.rebuild(state).size(), 0, "No current access means no network")
	cell.relationships.append(TileFeatureRelationship.new())
	TradeNetworkService.reconcile(state)
	expect_true(TradeNetworkService.is_ancestor(state, ancestor, TradeNetworkService.rebuild(state)[0].lineage_id), "Restoring access retains dissolved history")
	return true
