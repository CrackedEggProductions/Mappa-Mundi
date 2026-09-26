extends "res://tests/framework/test_suite.gd"

const Graph = preload("res://tests/fixtures/topology_fixture.gd")
const TYPE = DomainTypes.FeatureType
const EDGE = DomainTypes.EdgeType


func tests() -> Array[Callable]:
	var cases: Array[Callable] = [exact_roster, registry_definitions_are_copies, older_profile_has_no_charters,
		growing_realm_history_required, growing_realm_genuine_recompletion_counts,
		open_roads_ferry_current_network, living_landscape_both_histories_required,
		market_towns_history_required, market_towns_reopened_history_qualifies,
		market_towns_grand_market_family, communities_same_settlement_required,
		communities_counts_instances_not_families, stewardship_current_sizes,
		metropolis_reopened_fails, metropolis_unestablished_fails, metropolis_same_witness,
		metropolis_two_other_settlements, metropolis_upgrade_family_diversity,
		metropolis_exceed_another_unfinished_settlement, metropolis_exceed_never_bypasses_fulfill,
		republic_reopened_road_qualifies, republic_history_required,
		republic_same_network_commerce, republic_exceed_same_qualifying_network,
		republic_market_and_port_distinct, heritage_abbey_history,
		heritage_culture_and_ecology_both_required, selection_single_rng_idempotent,
		selection_is_seed_deterministic, forecast_hides_exact_requirements,
		reveal_is_rng_free_idempotent, act_three_no_ordinary_visibility,
		evaluation_does_not_mutate_state, reward_order, invalid_id_is_explicit,
		inherited_road_history_after_legal_merge, market_settlements_distinct,
		metropolis_current_open_exit_disqualifies, communities_upgrade_one_instance,
		heritage_natural_sizes_not_historical, selection_ignores_dictionary_order]
	for id: StringName in CharterContentValidator.ROSTER:
		cases.append(fulfill_exceed_and_track_failure.bind(id))
	for mutation: StringName in [&"missing", &"duplicate", &"deferred", &"act", &"behavior", &"forecast", &"rewards", &"targets"]:
		cases.append(invalid_content.bind(mutation))
	return cases


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	assert(content.load_phase_nine().is_valid)
	return content


func _state() -> RunState:
	var state: RunState = Graph.empty()
	state.charters = CharterState.new()
	state.relics = RelicState.new()
	state.rewards = RewardState.new()
	return state


func _row(state: RunState, type: int, count: int, origin: Vector2i, closed: bool = true) -> int:
	var edge: int = FeatureState.edge_for_type(type as DomainTypes.FeatureType)
	for x: int in range(count):
		var edges: Array[DomainTypes.EdgeType] = [EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD]
		if x > 0:
			edges[3] = edge as DomainTypes.EdgeType
		if x + 1 < count or not closed:
			edges[1] = edge as DomainTypes.EdgeType
		Graph.add(state, origin + Vector2i(x, 0), edges)
	Graph.reconcile(state)
	return state.features.component_at(origin, type as DomainTypes.FeatureType).lineage_id


func _completion(state: RunState, type: int, lineage_id: int = 0, completed: bool = true) -> void:
	var record: FeatureCompletionRecord = FeatureCompletionRecord.new()
	record.record_id = state.id_allocator.allocate()
	record.feature_type = type
	record.lineage_id = lineage_id
	if type == -1:
		record.enclosure_id = state.id_allocator.allocate()
		record.enclosure_stage = &"monastery"
	state.features.completions.append(record)
	if lineage_id != 0:
		var lineage: FeatureLineageState = state.features.lineage(lineage_id)
		lineage.completion_ids.append(record.record_id)
		lineage.completed = completed


func _development(state: RunState, coordinate: Vector2i, family: StringName, stage: StringName = &"") -> void:
	var development: DevelopmentState = DevelopmentState.new()
	development.tile_copy_id = state.id_allocator.allocate()
	development.family_id = StringName("family." + String(family))
	development.host_kind = &"settlement"
	development.host_lineage_id = state.features.component_at(coordinate, TYPE.SETTLEMENT).lineage_id
	development.stage = family if stage == &"" else stage
	state.expansion.board.get_cell(coordinate).developments.append(development)


func _ferry_chain(count: int) -> RunState:
	var state: RunState = _state()
	for x: int in range(count):
		var cell: BoardCellState = Graph.add(state, Vector2i(x, 0), [EDGE.SETTLEMENT, EDGE.RIVER, EDGE.ROAD if x == 0 else EDGE.FIELD, EDGE.RIVER])
		var touch: TileFeatureRelationship = TileFeatureRelationship.new()
		touch.from_edge_type = EDGE.SETTLEMENT
		touch.to_edge_type = EDGE.RIVER
		touch.kind = TileFeatureRelationship.Kind.SETTLEMENT_RIVER_TOUCH
		cell.relationships.append(touch)
		if x == 0:
			var access: TileFeatureRelationship = TileFeatureRelationship.new()
			access.from_edge_type = EDGE.ROAD
			access.to_edge_type = EDGE.SETTLEMENT
			access.kind = TileFeatureRelationship.Kind.ROAD_SETTLEMENT_ACCESS
			cell.relationships.append(access)
	Graph.reconcile(state)
	TradeNetworkService.initialize(state)
	assert(RelicRules.acquire(state, _content(), RelicRules.FERRY).is_valid)
	return state


func _metropolis_state() -> RunState:
	var state: RunState = _ferry_chain(3)
	for y: int in range(1, 8):
		Graph.add(state, Vector2i(0, -y), [EDGE.SETTLEMENT if y < 7 else EDGE.FIELD, EDGE.FIELD, EDGE.SETTLEMENT, EDGE.FIELD])
	Graph.reconcile(state)
	TradeNetworkService.reconcile(state)
	var lineage_id: int = state.features.component_at(Vector2i.ZERO, TYPE.SETTLEMENT).lineage_id
	_completion(state, TYPE.SETTLEMENT, lineage_id)
	for family: StringName in [&"housing", &"market", &"town_square"]:
		_development(state, Vector2i.ZERO, family)
	state.features.tracks.values[0] = 70
	return state


func _successful(id: StringName) -> RunState:
	var state: RunState = _state()
	match id:
		&"charter.a1_growing_realm":
			_completion(state, TYPE.SETTLEMENT)
			_completion(state, TYPE.SETTLEMENT)
		&"charter.a1_open_roads":
			state = _ferry_chain(2)
			_completion(state, TYPE.ROAD)
			_completion(state, TYPE.ROAD)
		&"charter.a1_living_landscape":
			_completion(state, TYPE.FOREST)
			_completion(state, TYPE.RIVER)
		&"charter.a2_market_towns":
			state = _ferry_chain(3)
			_completion(state, TYPE.ROAD, state.features.component_at(Vector2i.ZERO, TYPE.ROAD).lineage_id, false)
			_development(state, Vector2i.ZERO, &"market")
			_development(state, Vector2i.RIGHT, &"market")
		&"charter.a2_growing_communities":
			_row(state, TYPE.SETTLEMENT, 6, Vector2i.ZERO)
			_development(state, Vector2i.ZERO, &"housing")
			_development(state, Vector2i.RIGHT, &"market")
		&"charter.a2_stewardship_of_land":
			_row(state, TYPE.FOREST, 6, Vector2i.ZERO)
			_row(state, TYPE.RIVER, 6, Vector2i(0, 10))
		&"charter.grand_great_metropolis":
			state = _metropolis_state()
		&"charter.grand_merchant_republic":
			state = _ferry_chain(4)
			_completion(state, TYPE.ROAD, state.features.component_at(Vector2i.ZERO, TYPE.ROAD).lineage_id, false)
			_development(state, Vector2i.ZERO, &"market")
			_development(state, Vector2i.RIGHT, &"port")
		&"charter.grand_living_heritage":
			_row(state, TYPE.FOREST, 8, Vector2i.ZERO)
			_row(state, TYPE.RIVER, 8, Vector2i(0, 10))
			_completion(state, -1)
	var targets: Dictionary = _content().get_charter(id).targets
	for name: String in CharterRules.TRACKS:
		if targets.has(name):
			state.features.tracks.values[CharterRules.TRACKS[name]] = int(targets[name])
	return state


func _result(state: RunState, id: StringName) -> StringName:
	return CharterRules.evaluate(state, _content(), id).overall_state


func exact_roster() -> bool:
	var content: ContentRegistry = _content()
	expect_equal(content.get_charter_ids().size(), 9, "Exactly nine alpha Charters")
	for act: int in [1, 2, 3]:
		expect_equal(content.get_charter_ids(act).size(), 3, "Exactly three per tier")
	return true


func registry_definitions_are_copies() -> bool:
	var content: ContentRegistry = _content()
	content.get_charter(&"charter.a1_growing_realm").targets["population"] = 999
	expect_equal(content.get_charter(&"charter.a1_growing_realm").targets["population"], 20, "Query cannot mutate registered content")
	return true


func older_profile_has_no_charters() -> bool:
	var content: ContentRegistry = ContentRegistry.new()
	expect_true(content.load_phase_eight().is_valid, "Older profile preserved")
	expect_true(content.get_charter_ids().is_empty(), "Phase eight has no Charter selection pool")
	return true


func invalid_content(mutation: StringName) -> bool:
	var manifest: ContentManifest = (load(ContentRegistry.PHASE_NINE_MANIFEST_PATH) as ContentManifest).duplicate(true)
	match mutation:
		&"missing": manifest.charters.pop_back()
		&"duplicate": manifest.charters[1] = manifest.charters[0]
		&"deferred": manifest.charters[0].definition_id = &"charter.future"
		&"act": manifest.charters[0].evaluation_act = 3
		&"behavior": manifest.charters[0].behavior_id = &"arbitrary_callback"
		&"forecast": manifest.charters[6].forecast_text = ""
		&"rewards": manifest.charters[3].fulfill_rewards.reverse()
		&"targets": manifest.charters[0].targets["population"] = 1
	expect_true(not CharterContentValidator.validate(manifest.charters).is_valid, "Invalid canonical content rejected: " + String(mutation))
	return true


func fulfill_exceed_and_track_failure(id: StringName) -> bool:
	var state: RunState = _successful(id)
	expect_equal(_result(state, id), &"fulfilled", "Exact fulfillment targets: " + String(id))
	var targets: Dictionary = _content().get_charter(id).targets
	for name: String in CharterRules.TRACKS:
		if targets.has("exceed_" + name):
			state.features.tracks.values[CharterRules.TRACKS[name]] = int(targets["exceed_" + name])
	if id == &"charter.grand_great_metropolis":
		_row(state, TYPE.SETTLEMENT, 10, Vector2i(20, 0), false)
	if id == &"charter.grand_merchant_republic":
		var extra: BoardCellState = Graph.add(state, Vector2i(4, 0), [EDGE.SETTLEMENT, EDGE.RIVER, EDGE.FIELD, EDGE.RIVER])
		var touch: TileFeatureRelationship = TileFeatureRelationship.new()
		touch.from_edge_type = EDGE.SETTLEMENT
		touch.to_edge_type = EDGE.RIVER
		touch.kind = TileFeatureRelationship.Kind.SETTLEMENT_RIVER_TOUCH
		extra.relationships.append(touch)
		Graph.reconcile(state)
		TradeNetworkService.reconcile(state)
	expect_equal(_result(state, id), &"exceeded", "Additional exceed targets: " + String(id))
	for name: String in CharterRules.TRACKS:
		if targets.has(name):
			state.features.tracks.values[CharterRules.TRACKS[name]] = int(targets[name]) - 1
			break
	expect_equal(_result(state, id), &"failed", "Exceed cannot bypass minimum Track: " + String(id))
	return true


func growing_realm_history_required() -> bool:
	var state: RunState = _state()
	state.features.tracks.values[0] = 100
	_row(state, TYPE.SETTLEMENT, 8, Vector2i.ZERO)
	expect_equal(_result(state, &"charter.a1_growing_realm"), &"failed", "Population and current geometry do not invent completion history")
	return true


func growing_realm_genuine_recompletion_counts() -> bool:
	var state: RunState = _state()
	var id: int = _row(state, TYPE.SETTLEMENT, 2, Vector2i.ZERO)
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	Graph.set_geometry(state.expansion.board.get_cell(Vector2i.RIGHT), [EDGE.SETTLEMENT, EDGE.FIELD, EDGE.FIELD, EDGE.SETTLEMENT])
	Graph.reconcile(state)
	Graph.add(state, Vector2i(1, -1), [EDGE.FIELD, EDGE.FIELD, EDGE.SETTLEMENT, EDGE.FIELD])
	Graph.reconcile(state)
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	state.features.tracks.values[0] = 20
	expect_equal(state.features.lineage(id).completion_ids.size(), 2, "One lineage genuinely completes twice")
	expect_equal(_result(state, &"charter.a1_growing_realm"), &"fulfilled", "Genuine re-completions both count")
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	expect_equal(CharterRules.completion_count(state, TYPE.SETTLEMENT), 2, "Repeated resolution is not a completion event")
	return true


func open_roads_ferry_current_network() -> bool:
	var state: RunState = _successful(&"charter.a1_open_roads")
	expect_equal(_result(state, &"charter.a1_open_roads"), &"fulfilled", "Ferry network counts")
	state.relics.instances.clear()
	expect_equal(_result(state, &"charter.a1_open_roads"), &"failed", "Current lost Ferry connectivity fails despite retained history")
	return true


func living_landscape_both_histories_required() -> bool:
	var state: RunState = _successful(&"charter.a1_living_landscape")
	state.features.completions.pop_back()
	state.features.tracks.values[3] = 50
	expect_equal(_result(state, &"charter.a1_living_landscape"), &"failed", "River completion cannot be replaced by Ecology")
	return true


func market_towns_history_required() -> bool:
	var state: RunState = _successful(&"charter.a2_market_towns")
	state.features.lineage(state.features.component_at(Vector2i.ZERO, TYPE.ROAD).lineage_id).completion_ids.clear()
	expect_equal(_result(state, &"charter.a2_market_towns"), &"failed", "Current network without Road completion history fails")
	return true


func market_towns_reopened_history_qualifies() -> bool:
	var state: RunState = _successful(&"charter.a2_market_towns")
	expect_true(not state.features.lineage(state.features.component_at(Vector2i.ZERO, TYPE.ROAD).lineage_id).completed, "Fixture Road is unfinished")
	expect_equal(_result(state, &"charter.a2_market_towns"), &"fulfilled", "Historical Road completion suffices while reopened")
	return true


func market_towns_grand_market_family() -> bool:
	var state: RunState = _successful(&"charter.a2_market_towns")
	state.expansion.board.get_cell(Vector2i.ZERO).developments[0].stage = &"grand_market"
	expect_equal(_result(state, &"charter.a2_market_towns"), &"fulfilled", "Upgrade remains Market family")
	return true


func communities_same_settlement_required() -> bool:
	var state: RunState = _successful(&"charter.a2_growing_communities")
	_row(state, TYPE.SETTLEMENT, 2, Vector2i(20, 0))
	for coordinate: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT]:
		state.expansion.board.get_cell(coordinate).developments.clear()
	_development(state, Vector2i(20, 0), &"housing")
	_development(state, Vector2i(21, 0), &"market")
	expect_equal(_result(state, &"charter.a2_growing_communities"), &"failed", "Size and Developments must refer to same Settlement")
	return true


func communities_counts_instances_not_families() -> bool:
	var state: RunState = _successful(&"charter.a2_growing_communities")
	state.expansion.board.get_cell(Vector2i.RIGHT).developments[0].family_id = &"family.housing"
	expect_equal(_result(state, &"charter.a2_growing_communities"), &"fulfilled", "Two Developments need not be different families")
	return true


func stewardship_current_sizes() -> bool:
	var state: RunState = _successful(&"charter.a2_stewardship_of_land")
	expect_true(state.features.completions.is_empty(), "Current-sized features have no completion history")
	expect_equal(_result(state, &"charter.a2_stewardship_of_land"), &"fulfilled", "Unfinished Forest and River current sizes count")
	return true


func metropolis_reopened_fails() -> bool:
	var state: RunState = _metropolis_state()
	state.features.lineage(state.features.component_at(Vector2i.ZERO, TYPE.SETTLEMENT).lineage_id).completed = false
	expect_equal(_result(state, &"charter.grand_great_metropolis"), &"failed", "Human ruling: reopened Settlement is ineligible")
	return true


func metropolis_unestablished_fails() -> bool:
	var state: RunState = _metropolis_state()
	state.features.lineage(state.features.component_at(Vector2i.ZERO, TYPE.SETTLEMENT).lineage_id).completion_ids.clear()
	expect_equal(_result(state, &"charter.grand_great_metropolis"), &"failed", "Completed geometry alone is not historical Establishment")
	return true


func metropolis_same_witness() -> bool:
	var state: RunState = _metropolis_state()
	var id: int = _row(state, TYPE.SETTLEMENT, 8, Vector2i(20, 0))
	_completion(state, TYPE.SETTLEMENT, id)
	state.expansion.board.get_cell(Vector2i.ZERO).developments.clear()
	for family: StringName in [&"housing", &"market", &"town_square"]:
		_development(state, Vector2i(20, 0), family)
	expect_equal(_result(state, &"charter.grand_great_metropolis"), &"failed", "One Settlement has network; another families; neither qualifies")
	return true


func metropolis_two_other_settlements() -> bool:
	var state: RunState = _metropolis_state()
	state.expansion.board.get_cell(Vector2i(2, 0)).relationships.clear()
	expect_equal(_result(state, &"charter.grand_great_metropolis"), &"failed", "Total two includes self and is only one other")
	return true


func metropolis_upgrade_family_diversity() -> bool:
	var state: RunState = _metropolis_state()
	state.expansion.board.get_cell(Vector2i.ZERO).developments[1].stage = &"grand_market"
	expect_equal(_result(state, &"charter.grand_great_metropolis"), &"fulfilled", "Grand Market retains one Market family")
	state.expansion.board.get_cell(Vector2i.ZERO).developments[2].family_id = &"family.market"
	expect_equal(_result(state, &"charter.grand_great_metropolis"), &"failed", "Duplicate Market family is not third family")
	return true


func metropolis_exceed_another_unfinished_settlement() -> bool:
	var state: RunState = _metropolis_state()
	_row(state, TYPE.SETTLEMENT, 10, Vector2i(20, 0), false)
	state.features.tracks.values[0] = 90
	expect_equal(_result(state, &"charter.grand_great_metropolis"), &"exceeded", "Separate unfinished size-ten Settlement satisfies only additional exceed condition")
	return true


func metropolis_exceed_never_bypasses_fulfill() -> bool:
	var state: RunState = _state()
	_row(state, TYPE.SETTLEMENT, 10, Vector2i.ZERO, false)
	state.features.tracks.values[0] = 100
	expect_equal(_result(state, &"charter.grand_great_metropolis"), &"failed", "Exceed size and Population never bypass Establishment and families/network")
	return true


func republic_reopened_road_qualifies() -> bool:
	var state: RunState = _successful(&"charter.grand_merchant_republic")
	expect_true(not state.features.lineage(state.features.component_at(Vector2i.ZERO, TYPE.ROAD).lineage_id).completed, "Road is currently unfinished")
	expect_equal(_result(state, &"charter.grand_merchant_republic"), &"fulfilled", "Human ruling: Road completion history remains sufficient")
	return true


func republic_history_required() -> bool:
	var state: RunState = _successful(&"charter.grand_merchant_republic")
	state.features.lineage(state.features.component_at(Vector2i.ZERO, TYPE.ROAD).lineage_id).completion_ids.clear()
	expect_equal(_result(state, &"charter.grand_merchant_republic"), &"failed", "Unfinished Road never completed does not qualify")
	return true


func republic_same_network_commerce() -> bool:
	var state: RunState = _successful(&"charter.grand_merchant_republic")
	state.expansion.board.get_cell(Vector2i.RIGHT).developments.clear()
	_row(state, TYPE.SETTLEMENT, 2, Vector2i(20, 0))
	_development(state, Vector2i(20, 0), &"port")
	expect_equal(_result(state, &"charter.grand_merchant_republic"), &"failed", "Commercial Settlement outside qualifying network does not count")
	return true


func republic_exceed_same_qualifying_network() -> bool:
	var state: RunState = _successful(&"charter.grand_merchant_republic")
	state.features.tracks.values[1] = 90
	expect_equal(_result(state, &"charter.grand_merchant_republic"), &"fulfilled", "Four-Settlement network cannot exceed even at Trade ninety")
	return true


func republic_market_and_port_distinct() -> bool:
	var state: RunState = _successful(&"charter.grand_merchant_republic")
	state.expansion.board.get_cell(Vector2i.ZERO).developments[0].stage = &"grand_market"
	expect_equal(_result(state, &"charter.grand_merchant_republic"), &"fulfilled", "Grand Market and Port qualify")
	state.expansion.board.get_cell(Vector2i.RIGHT).developments.clear()
	_development(state, Vector2i.ZERO, &"port")
	expect_equal(_result(state, &"charter.grand_merchant_republic"), &"failed", "Market plus Port on one Settlement is still only one Settlement")
	return true


func heritage_abbey_history() -> bool:
	var state: RunState = _successful(&"charter.grand_living_heritage")
	state.features.completions[0].enclosure_stage = &"abbey"
	expect_equal(_result(state, &"charter.grand_living_heritage"), &"fulfilled", "Abbey genuine completion counts as Monastery-family history")
	state.features.completions.clear()
	expect_equal(_result(state, &"charter.grand_living_heritage"), &"failed", "Natural sizes without enclosure completion fail")
	return true


func heritage_culture_and_ecology_both_required() -> bool:
	var state: RunState = _successful(&"charter.grand_living_heritage")
	state.features.tracks.values[2] = 39
	state.features.tracks.values[3] = 100
	expect_equal(_result(state, &"charter.grand_living_heritage"), &"failed", "High Ecology cannot replace Culture")
	return true


func selection_single_rng_idempotent() -> bool:
	var state: RunState = _state()
	var content: ContentRegistry = _content()
	var before: int = state.rng.operation_count
	var first: StringName = CharterRules.select_ordinary(state, content, 1)
	expect_equal(state.rng.operation_count, before + 1, "Act I consumes one selection operation")
	expect_equal(CharterRules.select_ordinary(state, content, 1), first, "Retry returns stored selection")
	expect_equal(state.rng.operation_count, before + 1, "Retry does not reroll")
	state.expansion.current_act = 2
	CharterRules.select_ordinary(state, content, 2)
	var grand: StringName = CharterRules.select_grand(state, content)
	expect_equal(state.rng.operation_count, before + 3, "Act II and secret Grand each consume exactly one operation")
	expect_equal(CharterRules.select_grand(state, content), grand, "Grand retry retains ID")
	expect_equal(state.rng.operation_count, before + 3, "No second Grand RNG draw")
	return true


func selection_is_seed_deterministic() -> bool:
	var content: ContentRegistry = _content()
	var a: RunState = _state()
	var b: RunState = _state()
	b.features.tracks.values = [900, 0, 0, 0]
	expect_equal(CharterRules.select_ordinary(a, content, 1), CharterRules.select_ordinary(b, content, 1), "Track helpfulness does not weight selection")
	a.expansion.current_act = 2
	b.expansion.current_act = 2
	expect_equal(CharterRules.select_ordinary(a, content, 2), CharterRules.select_ordinary(b, content, 2), "Act II deterministic")
	expect_equal(CharterRules.select_grand(a, content), CharterRules.select_grand(b, content), "Grand deterministic independent of Tracks")
	expect_equal(a.current_rng_state, b.current_rng_state, "Selection leaves identical stream continuation")
	return true


func forecast_hides_exact_requirements() -> bool:
	var state: RunState = _state()
	state.expansion.current_act = 2
	CharterRules.select_grand(state, _content())
	var view: Dictionary = CharterRules.visible_grand(state, _content())
	expect_equal(view.size(), 2, "Only forecast and visibility before reveal")
	expect_true(not view.has("charter_id") and not view.has("targets") and not view.has("progress"), "Exact ID and requirements hidden")
	expect_equal(view["forecast"], _content().get_charter(state.charters.grand_id).forecast_text, "Forecast corresponds to persisted Grand")
	return true


func reveal_is_rng_free_idempotent() -> bool:
	var state: RunState = _state()
	state.expansion.current_act = 2
	state.expansion.normal_placements = 11
	CharterRules.select_grand(state, _content())
	var before: int = state.rng.operation_count
	CharterRules.reveal_grand(state)
	var events: int = state.charters.history.size()
	CharterRules.reveal_grand(state)
	expect_equal(state.rng.operation_count, before, "Reveal consumes zero RNG")
	expect_equal(state.charters.history.size(), events, "Reveal emits only once")
	expect_equal(state.charters.exact_revealed_index, 11, "Exact reveal point retained")
	expect_true(CharterRules.visible_grand(state, _content()).has("progress"), "Post-reveal view includes exact evaluated conditions")
	return true


func act_three_no_ordinary_visibility() -> bool:
	var state: RunState = _state()
	CharterRules.select_ordinary(state, _content(), 1)
	state.expansion.current_act = 3
	expect_true(CharterRules.visible_ordinary(state, _content()).is_empty(), "Act III has no ordinary objective")
	return true


func evaluation_does_not_mutate_state() -> bool:
	var state: RunState = _metropolis_state()
	var rng: int = state.current_rng_state
	var next: int = state.next_runtime_id
	var topology: String = Graph.signature(TopologyService.rebuild(state))
	var graph: String = TradeNetworkService.graph_signature(state)
	var completions: int = state.features.completions.size()
	var a: Dictionary = CharterRules.evaluate(state, _content(), &"charter.grand_great_metropolis").to_dict()
	var b: Dictionary = CharterRules.evaluate(state, _content(), &"charter.grand_great_metropolis").to_dict()
	expect_equal(a, b, "Structured evaluation deterministic")
	expect_equal(state.current_rng_state, rng, "Evaluation consumes no RNG")
	expect_equal(state.next_runtime_id, next, "Evaluation allocates no IDs")
	expect_equal(Graph.signature(TopologyService.rebuild(state)), topology, "Board topology untouched")
	expect_equal(TradeNetworkService.graph_signature(state), graph, "Trade graph untouched")
	expect_equal(state.features.completions.size(), completions, "History unchanged")
	return true


func reward_order() -> bool:
	var content: ContentRegistry = _content()
	for id: StringName in content.get_charter_ids(1):
		expect_equal(CharterRules.ordered_rewards(content.get_charter(id), &"failed"), [], "Failure gives nothing")
		expect_equal(CharterRules.ordered_rewards(content.get_charter(id), &"fulfilled"), [&"tile_reward"], "Act I fulfillment Tile")
		expect_equal(CharterRules.ordered_rewards(content.get_charter(id), &"exceeded"), [&"tile_reward", &"relic_offer"], "Act I Tile then Relic")
	for id: StringName in content.get_charter_ids(2):
		expect_equal(CharterRules.ordered_rewards(content.get_charter(id), &"fulfilled"), [&"relic_offer", &"tile_reward"], "Act II Relic then Tile")
		expect_equal(CharterRules.ordered_rewards(content.get_charter(id), &"exceeded"), [&"relic_offer", &"tile_reward", &"major_reward"], "Act II Major last")
	for id: StringName in content.get_charter_ids(3):
		expect_true(CharterRules.ordered_rewards(content.get_charter(id), &"exceeded").is_empty(), "Grand evaluation has no outgoing reward")
	return true


func invalid_id_is_explicit() -> bool:
	expect_equal(_result(_state(), &"charter.future"), &"invalid", "Unknown content is not silently a normal failed Charter")
	return true


func inherited_road_history_after_legal_merge() -> bool:
	var state: RunState = _successful(&"charter.a2_market_towns")
	var parent: int = state.features.component_at(Vector2i.ZERO, TYPE.ROAD).lineage_id
	Graph.add(state, Vector2i(0, 2), [EDGE.ROAD, EDGE.FIELD, EDGE.ROAD, EDGE.FIELD])
	Graph.reconcile(state)
	Graph.add(state, Vector2i(0, 1), [EDGE.ROAD, EDGE.FIELD, EDGE.ROAD, EDGE.FIELD])
	Graph.reconcile(state)
	TradeNetworkService.reconcile(state)
	var descendant: int = state.features.component_at(Vector2i.ZERO, TYPE.ROAD).lineage_id
	expect_true(parent != descendant, "Legal merger creates descendant lineage")
	expect_true(parent in state.features.lineage(descendant).parent_ids, "Ancestry retained")
	expect_equal(_result(state, &"charter.a2_market_towns"), &"fulfilled", "Inherited completion history qualifies current descendant network")
	return true


func market_settlements_distinct() -> bool:
	var state: RunState = _successful(&"charter.a2_market_towns")
	state.expansion.board.get_cell(Vector2i.RIGHT).developments.clear()
	_development(state, Vector2i.ZERO, &"market")
	expect_equal(_result(state, &"charter.a2_market_towns"), &"failed", "Two Markets in one Settlement are not two Settlements")
	return true


func metropolis_current_open_exit_disqualifies() -> bool:
	var state: RunState = _metropolis_state()
	Graph.set_geometry(state.expansion.board.get_cell(Vector2i(0, -7)), [EDGE.SETTLEMENT, EDGE.FIELD, EDGE.SETTLEMENT, EDGE.FIELD])
	expect_equal(_result(state, &"charter.grand_great_metropolis"), &"failed", "Current open topology cannot qualify from stale completed flag")
	return true


func communities_upgrade_one_instance() -> bool:
	var state: RunState = _successful(&"charter.a2_growing_communities")
	state.expansion.board.get_cell(Vector2i.ZERO).developments.clear()
	state.expansion.board.get_cell(Vector2i.RIGHT).developments[0].stage = &"grand_market"
	expect_equal(_result(state, &"charter.a2_growing_communities"), &"failed", "Upgrade plus replaced historical base is one current Development")
	return true


func heritage_natural_sizes_not_historical() -> bool:
	var state: RunState = _successful(&"charter.grand_living_heritage")
	state.features.largest_completed_sizes[TYPE.FOREST] = 20
	state.features.largest_completed_sizes[TYPE.RIVER] = 20
	Graph.set_geometry(state.expansion.board.get_cell(Vector2i(3, 0)), [EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	expect_equal(_result(state, &"charter.grand_living_heritage"), &"failed", "Historical large Forest does not replace current connected size")
	return true


func selection_ignores_dictionary_order() -> bool:
	var a: RunState = _metropolis_state()
	var b: RunState = _metropolis_state()
	var reversed_cells: Dictionary = {}
	var coordinates: Array[Vector2i] = b.expansion.board.sorted_coordinates()
	coordinates.reverse()
	for coordinate: Vector2i in coordinates:
		reversed_cells[coordinate] = b.expansion.board.cells[coordinate]
	b.expansion.board.cells.assign(reversed_cells)
	expect_equal(CharterRules.evaluate(a, _content(), &"charter.grand_great_metropolis").to_dict(),
		CharterRules.evaluate(b, _content(), &"charter.grand_great_metropolis").to_dict(), "Board Dictionary insertion cannot change progress or witnesses")
	return true
