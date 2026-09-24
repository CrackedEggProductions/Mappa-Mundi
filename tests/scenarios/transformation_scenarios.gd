extends "res://tests/framework/test_suite.gd"

const Fixture = preload("res://tests/fixtures/phase_six_factory.gd")
const TYPE = DomainTypes.FeatureType
const EDGE = DomainTypes.EdgeType
const TRACK = DomainTypes.TrackType


func tests() -> Array[Callable]:
	return [urban_starts_new_settlement, urban_reopens_completed_host,
		urban_closed_merger_retains_history_and_developments, urban_query_is_pure_and_deterministic,
		bridge_preserves_completed_river, bridge_new_settlement_road_components,
		bridge_reopens_existing_road_without_duplicate_growth, bridge_invalid_underlying_geography,
		bridge_occupied_nonqualifying_neighbor_rejected,
		rewild_expansion_reopens_completed_forest, rewild_occupied_field_creates_new_growth,
		rewild_preserves_road_identity, rewild_preserves_settlement_development,
		rewild_preserves_river_identity, rewild_existing_forest_is_not_new_growth,
		rewild_field_dependent_developments_block, rewild_occupied_edges_must_match,
		stale_transformation_intent_is_atomic, forged_target_is_atomic,
		reserve_transformation_does_not_draw, survey_transformation,
		playable_transformation_prevents_dead_hand, transformation_round_trip_continuation,
		bridge_closed_road_merger_preserves_paid_growth, urban_nonsettlement_boundary_excluded,
		rewild_incomplete_forest_boundary_excluded, rewild_overlay_preserves_development_slot,
		forged_geometry_signature_is_atomic, transformation_bag_prevents_global_stalemate,
		unplayable_transformations_allow_dead_hand, post_transform_query_remains_deterministic]


func urban_starts_new_settlement() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 2)
	Fixture.Geography.add(state, registry, &"tile.road_end", Vector2i.RIGHT, 3)
	var before: int = state.expansion.normal_placements
	var copy_id: int = Fixture.play(state, registry, Fixture.URBAN, Vector2i(2, 0), &"urban_expansion")
	var cell: BoardCellState = state.expansion.board.get_cell(Vector2i(2, 0))
	expect_equal(cell.base_tile_copy_id, copy_id, "Urban Expansion becomes physical base copy")
	expect_equal(Fixture.Previous.location(state, copy_id), TileLocationState.Kind.BOARD_BASE, "New-square mode has one base location")
	expect_equal(state.expansion.normal_placements, before + 1, "Urban consumes exactly one normal placement")
	expect_equal(cell.transformations.size(), 1, "Specialized expansion retains Transformation audit")
	var settlement: FeatureComponentState = Fixture.component(state, Vector2i(2, 0), TYPE.SETTLEMENT)
	expect_true(not state.features.lineage(settlement.lineage_id).completed, "Opposite Settlement exits start unfinished feature")
	expect_equal(settlement.origin_act, 2, "New contribution records current Act")
	expect_equal(settlement.origin_source_runtime_id, copy_id, "Contribution belongs to physical Urban copy")
	_valid(state, registry)
	return true


func urban_reopens_completed_host() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 2)
	Fixture.Previous.complete_settlement(state, registry)
	var housing: int = Fixture.Previous.play(state, registry, &"tile.development.housing", Vector2i.UP)
	var host: FeatureLineageState = state.features.lineage(Fixture.component(state, Vector2i.UP, TYPE.SETTLEMENT).lineage_id)
	var old_components: Array[int] = host.scored_component_ids.duplicate()
	var population: int = state.features.tracks.values[TRACK.POPULATION]
	Fixture.play(state, registry, Fixture.URBAN, Vector2i(0, -2), &"urban_expansion")
	expect_equal(state.expansion.board.get_cell(Vector2i.UP).effective_edges[0], EDGE.SETTLEMENT, "Urban permanently rewrites facing Field boundary")
	expect_true(not host.completed, "Real topology reopens completed Settlement")
	expect_equal(host.scored_component_ids, old_components, "Reopening preserves old base eligibility history")
	expect_equal(state.features.tracks.values[TRACK.POPULATION], population, "Reopening alone does not score or trigger Housing")
	Fixture.Previous.play(state, registry, &"tile.hamlet_edge", Vector2i(0, -3))
	expect_true(host.completed, "Normal later Expansion closes growth")
	expect_equal(Fixture.gains(state, housing, TRACK.POPULATION), 4, "Existing Housing retriggers only on genuine re-completion")
	var record: FeatureCompletionRecord = state.features.completions[-1]
	expect_equal(record.new_component_ids.size(), 2, "Only Urban and new cap base-score")
	_valid(state, registry)
	return true


func urban_closed_merger_retains_history_and_developments() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.two_settlements(registry)
	var first: FeatureLineageState = state.features.lineage(Fixture.component(state, Vector2i.UP, TYPE.SETTLEMENT).lineage_id)
	var second: FeatureLineageState = state.features.lineage(Fixture.component(state, Vector2i(0, -3), TYPE.SETTLEMENT).lineage_id)
	var housing: int = Fixture.Previous.play(state, registry, &"tile.development.housing", Vector2i.UP)
	var market: int = Fixture.Previous.play(state, registry, &"tile.development.market", Vector2i(0, -3))
	var history: int = state.features.completions.size()
	Fixture.play(state, registry, Fixture.URBAN, Vector2i(0, -2), &"urban_expansion", 2)
	var descendant: FeatureLineageState = state.features.lineage(Fixture.component(state, Vector2i.UP, TYPE.SETTLEMENT).lineage_id)
	expect_true(descendant.lineage_id != first.lineage_id and descendant.lineage_id != second.lineage_id, "Closed merge creates descendant identity")
	expect_true(descendant.parent_ids.has(first.lineage_id) and descendant.parent_ids.has(second.lineage_id), "Both parent histories remain")
	expect_true(descendant.completed, "No remaining Settlement exit immediately completes merged host")
	expect_equal(state.features.completions.size(), history + 1, "Closed merger records genuine new completion")
	expect_equal(state.features.completions[-1].new_component_ids.size(), 1, "Only Urban contribution base-scores; ancestor tiles do not repay")
	expect_equal(Fixture.Previous.development(state, Vector2i.UP).host_lineage_id, descendant.lineage_id, "Housing follows descendant")
	expect_equal(Fixture.Previous.development(state, Vector2i(0, -3)).host_lineage_id, descendant.lineage_id, "Market follows descendant")
	expect_equal(Fixture.gains(state, housing, TRACK.POPULATION), 4, "Historical Housing resolves on genuine closed merge")
	expect_equal(Fixture.gains(state, market, TRACK.TRADE), 0, "Merged hub is one Settlement, not two historical Trade nodes")
	_valid(state, registry)
	return true


func urban_query_is_pure_and_deterministic() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.two_settlements(registry)
	var copy_id: int = Fixture.Previous.acquire_hand(state, Fixture.URBAN)
	var before: String = StateNormalizer.fingerprint(state)
	var options: Array[PlacementOption] = PlacementQueryService.query_for_copy(state, registry, copy_id)
	var repeat: Array[PlacementOption] = PlacementQueryService.query_for_copy(state, registry, copy_id)
	expect_equal(options.size(), repeat.size(), "Repeated projected query has stable count")
	for index: int in range(options.size()):
		expect_equal(options[index].signature, repeat[index].signature, "Complete intent signatures deterministic")
		expect_true(RulesEngine.validate(state, registry, Fixture.command(options[index])).is_valid, "Every planned rewrite validates")
	expect_equal(StateNormalizer.fingerprint(state), before, "Projection creates no live components/events/RNG/IDs")
	return true


func bridge_preserves_completed_river() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.river(registry, true)
	var river: FeatureComponentState = Fixture.component(state, Vector2i.DOWN, TYPE.RIVER)
	var lineage: FeatureLineageState = state.features.lineage(river.lineage_id)
	var records: Array[int] = lineage.completion_ids.duplicate()
	var scored: Array[int] = lineage.scored_component_ids.duplicate()
	var ecology: int = state.features.tracks.values[TRACK.ECOLOGY]
	var mill: int = Fixture.Previous.play(state, registry, &"tile.development.mill", Vector2i.DOWN)
	var bridge: int = Fixture.play(state, registry, Fixture.BRIDGE, Vector2i.DOWN, &"bridge")
	expect_equal(Fixture.component(state, Vector2i.DOWN, TYPE.RIVER), river, "Bridge retains original River component identity")
	expect_true(lineage.completed, "Bridge does not reopen completed River")
	expect_equal(lineage.completion_ids, records, "Bridge does not recomplete River")
	expect_equal(lineage.scored_component_ids, scored, "Bridge retains River scoring history")
	expect_equal(state.features.tracks.values[TRACK.ECOLOGY], ecology, "Bridge awards no River score")
	expect_equal(Fixture.Previous.development(state, Vector2i.DOWN).tile_copy_id, mill, "Existing Field-dependent Development survives Bridge")
	expect_equal(Fixture.Previous.location(state, bridge), TileLocationState.Kind.BOARD_TRANSFORMATION, "Bridge physical copy is overlay")
	expect_equal(state.expansion.board.get_cell(Vector2i.DOWN).effective_edges, [2, 3, 2, 3], "Perpendicular Road preserves continuous River")
	_valid(state, registry)
	return true


func bridge_new_settlement_road_components() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.river(registry)
	Fixture.Geography.add(state, registry, &"tile.hamlet_edge", Vector2i.ONE)
	Fixture.Geography.add(state, registry, &"tile.hamlet_edge", Vector2i(-1, 1), 2)
	var settlements: Array[int] = [Fixture.component(state, Vector2i.ONE, TYPE.SETTLEMENT).lineage_id,
		Fixture.component(state, Vector2i(-1, 1), TYPE.SETTLEMENT).lineage_id]
	var before: int = state.features.tracks.values[TRACK.TRADE]
	var bridge: int = Fixture.play(state, registry, Fixture.BRIDGE, Vector2i.DOWN, &"bridge")
	var road: FeatureLineageState = state.features.lineage(Fixture.component(state, Vector2i.DOWN, TYPE.ROAD).lineage_id)
	expect_true(road.completed, "Settlement endpoints close the three-tile Bridge Road")
	for at: Vector2i in [Vector2i.DOWN, Vector2i.ONE, Vector2i(-1, 1)]:
		var component: FeatureComponentState = Fixture.component(state, at, TYPE.ROAD)
		expect_equal(component.origin_act, 3, "New Road on old base records current Act")
		expect_equal(component.origin_source_runtime_id, bridge, "Bridge is provenance for every newly created Road contribution")
		expect_equal(component.origin_source_type, &"transformation", "New contribution explicitly records Transformation source")
		expect_equal(component.lineage_id, road.lineage_id, "All three Road contributions physically connect")
	expect_equal(state.features.tracks.values[TRACK.TRADE] - before, 7, "Three new Road tiles plus two newly connected Settlements")
	for settlement: int in settlements:
		expect_true(road.scored_settlement_ids.has(settlement), "Explicit Bridge access makes neighboring Settlement a network node")
	_valid(state, registry)
	return true


func bridge_reopens_existing_road_without_duplicate_growth() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.river(registry)
	Fixture.Geography.add(state, registry, &"tile.bending_road", Vector2i.RIGHT, 2)
	Fixture.Geography.add(state, registry, &"tile.road_end", Vector2i.ONE)
	var old: FeatureComponentState = Fixture.component(state, Vector2i.ONE, TYPE.ROAD)
	var lineage: FeatureLineageState = state.features.lineage(old.lineage_id)
	var scored: Array[int] = lineage.scored_component_ids.duplicate()
	expect_true(lineage.completed, "Existing Road completed before Bridge")
	Fixture.play(state, registry, Fixture.BRIDGE, Vector2i.DOWN, &"bridge")
	expect_equal(Fixture.component(state, Vector2i.ONE, TYPE.ROAD), old, "New exit extends existing component instead of duplicating tile")
	expect_equal(lineage.scored_component_ids, scored, "Reopening retains paid components")
	expect_true(not lineage.completed, "Empty opposite Bridge side creates genuine Road reopening")
	Fixture.Previous.play(state, registry, &"tile.road_end", Vector2i(-1, 1))
	expect_equal(state.features.completions[-1].new_component_ids.size(), 2, "Only Bridge target and new endpoint provide new Road Trade")
	_valid(state, registry)
	return true


func bridge_invalid_underlying_geography() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.Geography.add(state, registry, &"tile.river_bend", Vector2i.DOWN)
	var copy_id: int = Fixture.Previous.acquire_hand(state, Fixture.BRIDGE)
	expect_true(PlacementQueryService.query_for_copy(state, registry, copy_id).is_empty(), "River bend and founding mixed River are not straight River Run")
	return true


func bridge_occupied_nonqualifying_neighbor_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.river(registry)
	Fixture.Geography.add(state, registry, &"tile.open_fields", Vector2i.ONE)
	var copy_id: int = Fixture.Previous.acquire_hand(state, Fixture.BRIDGE)
	expect_true(Fixture.option_at(state, registry, copy_id, Vector2i.DOWN, &"bridge") == null,
		"Occupied pure Field neighbor cannot gain invented Road or Settlement access")
	return true


func rewild_expansion_reopens_completed_forest() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.Geography.add(state, registry, &"tile.forest_edge", Vector2i.LEFT, 1)
	var forest: FeatureLineageState = state.features.lineage(Fixture.component(state, Vector2i.LEFT, TYPE.FOREST).lineage_id)
	var scored: Array[int] = forest.scored_component_ids.duplicate()
	var ecology: int = state.features.tracks.values[TRACK.ECOLOGY]
	Fixture.play(state, registry, Fixture.REWILD, Vector2i(-2, 0), &"rewilding_expansion", 1)
	expect_equal(state.expansion.board.get_cell(Vector2i.LEFT).effective_edges[3], EDGE.FOREST, "Completed Forest boundary permanently opens into Rewilding")
	expect_true(not forest.completed, "Expansion leaves opposite Forest growth exit open")
	expect_equal(forest.scored_component_ids, scored, "Reopening preserves paid Forest history")
	expect_equal(state.features.tracks.values[TRACK.ECOLOGY], ecology, "No score merely for reopening")
	Fixture.Previous.play(state, registry, &"tile.forest_edge", Vector2i(-3, 0))
	expect_equal(state.features.completions[-1].new_component_ids.size(), 2, "New Rewilding and cap score only once")
	expect_equal(state.features.tracks.values[TRACK.ECOLOGY] - ecology, 4, "Two new Forest contributions plus current preservation")
	_valid(state, registry)
	return true


func rewild_occupied_field_creates_new_growth() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	var target: Vector2i = Fixture.Previous.fields(state, registry)
	var base: int = state.expansion.board.get_cell(target).base_tile_copy_id
	var placements: int = state.expansion.normal_placements
	var copy_id: int = Fixture.play(state, registry, Fixture.REWILD, target, &"rewilding", 1)
	var cell: BoardCellState = state.expansion.board.get_cell(target)
	var forest: FeatureComponentState = Fixture.component(state, target, TYPE.FOREST)
	expect_equal(cell.base_tile_copy_id, base, "Occupied Rewilding preserves physical base tile")
	expect_equal(state.expansion.normal_placements, placements + 1, "Occupied Rewilding consumes one normal placement")
	expect_equal(Fixture.Previous.location(state, copy_id), TileLocationState.Kind.BOARD_TRANSFORMATION, "Consumed Rewilding is physical overlay")
	expect_true(not cell.has_field_geography, "Rewilding consumes current Field support geography")
	expect_equal(forest.origin_act, 3, "New Forest on old base has Act-III origin")
	expect_equal(forest.origin_source_runtime_id, copy_id, "New Forest provenance is physical Rewilding copy")
	var mill: int = Fixture.Previous.acquire_hand(state, &"tile.development.mill")
	for option: PlacementOption in PlacementQueryService.query_for_copy(state, registry, mill):
		expect_true(option.coordinate != target, "Remaining Field-facing boundary does not restore consumed Field geography")
	_valid(state, registry)
	return true


func rewild_preserves_road_identity() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.Geography.add(state, registry, &"tile.road_end", Vector2i.RIGHT, 3)
	var road: FeatureComponentState = Fixture.component(state, Vector2i.RIGHT, TYPE.ROAD)
	var lineage: FeatureLineageState = state.features.lineage(road.lineage_id)
	var completions: Array[int] = lineage.completion_ids.duplicate()
	Fixture.play(state, registry, Fixture.REWILD, Vector2i.RIGHT, &"rewilding", 0)
	expect_equal(Fixture.component(state, Vector2i.RIGHT, TYPE.ROAD), road, "Built Road contribution remains intact")
	expect_equal(lineage.completion_ids, completions, "Rewilding does not cause false Road completion")
	expect_equal(state.expansion.board.get_cell(Vector2i.RIGHT).effective_edges[3], EDGE.ROAD, "Built Road edge preserved")
	_valid(state, registry)
	return true


func rewild_preserves_settlement_development() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.Previous.complete_settlement(state, registry)
	var housing: int = Fixture.Previous.play(state, registry, &"tile.development.housing", Vector2i.UP)
	var settlement: FeatureComponentState = Fixture.component(state, Vector2i.UP, TYPE.SETTLEMENT)
	var lineage: FeatureLineageState = state.features.lineage(settlement.lineage_id)
	var support: Array[int] = lineage.scored_field_ids.duplicate()
	var population: int = state.features.tracks.values[TRACK.POPULATION]
	Fixture.play(state, registry, Fixture.REWILD, Vector2i.UP, &"rewilding", 1)
	expect_equal(Fixture.component(state, Vector2i.UP, TYPE.SETTLEMENT), settlement, "Settlement identity survives new Forest")
	expect_equal(Fixture.Previous.development(state, Vector2i.UP).tile_copy_id, housing, "Legal Settlement Development survives")
	expect_equal(lineage.scored_field_ids, support, "Historical Field-support payments never erased")
	expect_equal(state.features.tracks.values[TRACK.POPULATION], population, "No retroactive score removal or Housing retrigger")
	for feature: CurrentFeature in TopologyService.rebuild(state):
		if feature.lineage_id == lineage.lineage_id:
			expect_true(not FeatureContactService.support_ids(state, feature, EDGE.FIELD).has(state.expansion.board.get_cell(Vector2i.UP).base_tile_copy_id), "Current Field support excludes consumed geography")
	_valid(state, registry)
	return true


func rewild_preserves_river_identity() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.river(registry, true)
	var river: FeatureComponentState = Fixture.component(state, Vector2i.DOWN, TYPE.RIVER)
	var completions: Array[int] = state.features.lineage(river.lineage_id).completion_ids.duplicate()
	Fixture.play(state, registry, Fixture.REWILD, Vector2i.DOWN, &"rewilding", 1)
	expect_equal(Fixture.component(state, Vector2i.DOWN, TYPE.RIVER), river, "Compatible underlying River survives")
	expect_equal(state.features.lineage(river.lineage_id).completion_ids, completions, "Completed River never falsely recompletes")
	expect_equal(state.expansion.board.get_cell(Vector2i.DOWN).effective_edges, [2, 1, 2, 1], "Rewilding preserves River axis")
	_valid(state, registry)
	return true


func rewild_existing_forest_is_not_new_growth() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.Geography.add(state, registry, &"tile.forest_edge", Vector2i.LEFT, 1)
	var forest: FeatureComponentState = Fixture.component(state, Vector2i.LEFT, TYPE.FOREST)
	var lineage: FeatureLineageState = state.features.lineage(forest.lineage_id)
	var old_paid: Array[int] = lineage.scored_component_ids.duplicate()
	Fixture.play(state, registry, Fixture.REWILD, Vector2i.LEFT, &"rewilding", 0)
	expect_equal(Fixture.component(state, Vector2i.LEFT, TYPE.FOREST), forest, "Existing Forest tile never gains duplicate component")
	expect_equal(lineage.scored_component_ids, old_paid, "Rewilding hybrid cannot reset paid history")
	expect_true(not lineage.completed, "New exits genuinely reopen Forest")
	_valid(state, registry)
	return true


func rewild_field_dependent_developments_block() -> bool:
	var registry: ContentRegistry = Fixture.content()
	for id: StringName in [&"tile.development.mill", &"tile.development.monastery"]:
		var state: RunState = Fixture.create(registry)
		var target: Vector2i = Fixture.Previous.fields(state, registry)
		Fixture.Previous.play(state, registry, id, target)
		var copy_id: int = Fixture.Previous.acquire_hand(state, Fixture.REWILD)
		expect_true(Fixture.option_at(state, registry, copy_id, target, &"rewilding") == null, "Continued Field-dependent Development blocks occupied Rewilding")
	return true


func rewild_occupied_edges_must_match() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	var target: Vector2i = Fixture.Previous.fields(state, registry, 8)
	var copy_id: int = Fixture.Previous.acquire_hand(state, Fixture.REWILD)
	expect_true(Fixture.option_at(state, registry, copy_id, target, &"rewilding") == null, "Both Forest orientations blocked by occupied non-Forest edges")
	return true


func stale_transformation_intent_is_atomic() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.river(registry)
	var copy_id: int = Fixture.Previous.acquire_hand(state, Fixture.BRIDGE)
	var intent: PlaceTileCommand = Fixture.command(Fixture.option_at(state, registry, copy_id, Vector2i.DOWN, &"bridge"))
	state.expansion.state_revision += 1
	_rejected_unchanged(state, registry, intent)
	return true


func forged_target_is_atomic() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.river(registry)
	var copy_id: int = Fixture.Previous.acquire_hand(state, Fixture.BRIDGE)
	var intent: PlaceTileCommand = Fixture.command(Fixture.option_at(state, registry, copy_id, Vector2i.DOWN, &"bridge"))
	intent.target_base_copy_id = state.expansion.board.get_cell(Vector2i.ZERO).base_tile_copy_id
	intent.expected_signature = ""
	_rejected_unchanged(state, registry, intent)
	return true


func reserve_transformation_does_not_draw() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.river(registry)
	var copy_id: int = Fixture.Previous.acquire_hand(state, Fixture.BRIDGE)
	expect_true(RulesEngine.execute(state, registry, ReserveTileCommand.new(copy_id)).is_valid, "Physical Transformation can enter Reserve")
	var hand: Array[int] = state.expansion.hand.duplicate()
	var bag: Array[int] = state.expansion.bag.duplicate()
	var count: int = state.expansion.normal_placements
	var intent: PlaceTileCommand = Fixture.command(Fixture.option_at(state, registry, copy_id, Vector2i.DOWN, &"bridge"), TileLocationState.Kind.RESERVE)
	expect_true(RulesEngine.execute(state, registry, intent).is_valid, "Reserved Transformation executes")
	expect_equal(state.expansion.reserve_id, 0, "Reserve empties")
	expect_equal(state.expansion.hand, hand, "Reserve play never refills hand")
	expect_equal(state.expansion.bag, bag, "Reserve play consumes no draw")
	expect_equal(state.expansion.normal_placements, count + 1, "Reserved Transformation is one placement")
	return true


func survey_transformation() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	var copy_id: int = Fixture.Previous.acquire_hand(state, Fixture.REWILD)
	var count: int = state.expansion.normal_placements
	expect_true(RulesEngine.execute(state, registry, SurveyTileCommand.new(copy_id)).is_valid, "Survey uses normal physical rules for Transformation")
	expect_equal(Fixture.Previous.location(state, copy_id), TileLocationState.Kind.REMOVED_FROM_RUN, "Survey removes Transformation copy")
	expect_equal(state.expansion.normal_placements, count, "Survey consumes no normal placement")
	expect_true(not state.expansion.hand.has(copy_id), "Survey refills physical hand slot")
	return true


func playable_transformation_prevents_dead_hand() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.river(registry)
	for slot: int in range(3):
		Fixture.Previous.acquire_hand(state, Fixture.BRIDGE, slot)
	expect_true(not StalemateRules.is_dead_hand(state, registry), "Playable Transformations prevent cycling even without Expansion copies")
	var before: String = StateNormalizer.fingerprint(state)
	expect_equal(RulesEngine.execute(state, registry, CycleDeadHandCommand.new()).error_code, &"hand_is_playable", "No free cycle while actual class has a legal target")
	expect_equal(StateNormalizer.fingerprint(state), before, "Rejected cycle inert")
	return true


func transformation_round_trip_continuation() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.Previous.complete_settlement(state, registry)
	Fixture.Previous.play(state, registry, &"tile.development.housing", Vector2i.UP)
	Fixture.play(state, registry, Fixture.URBAN, Vector2i(0, -2), &"urban_expansion")
	Fixture.Geography.add(state, registry, &"tile.river_run", Vector2i.DOWN)
	Fixture.play(state, registry, Fixture.BRIDGE, Vector2i.DOWN, &"bridge")
	Fixture.play(state, registry, Fixture.REWILD, Vector2i.UP, &"rewilding", 1)
	var copy_id: int = Fixture.Previous.acquire_hand(state, &"tile.hamlet_edge")
	var fingerprint: String = StateNormalizer.fingerprint(state)
	var loaded: RunState = state
	for index: int in range(3):
		var serialized: SerializationResult = RunSerializer.serialize(loaded, registry)
		expect_true(serialized.validation.is_valid, "Transformation run serializes")
		var result: DeserializationResult = RunSerializer.deserialize(serialized.json_text, registry)
		expect_true(result.validation.is_valid, "Transformation geometry/history reconstructs")
		if result.state == null:
			return true
		loaded = result.state
		expect_equal(StateNormalizer.fingerprint(loaded), fingerprint, "Repeated load creates zero scores, events, allocations or RNG use")
	var original_options: Array[PlacementOption] = PlacementQueryService.query_for_copy(state, registry, copy_id)
	var loaded_options: Array[PlacementOption] = PlacementQueryService.query_for_copy(loaded, registry, copy_id)
	expect_equal(original_options.size(), loaded_options.size(), "Loaded legal options agree")
	for index: int in range(original_options.size()):
		expect_equal(original_options[index].signature, loaded_options[index].signature, "Future exact intents agree")
	var intent: PlaceTileCommand = null
	for option: PlacementOption in original_options:
		if option.coordinate == Vector2i(0, -3):
			intent = Fixture.command(option)
	assert(intent != null, "Continuation has expected Settlement closing placement")
	expect_true(RulesEngine.execute(state, registry, intent).is_valid, "Original continuation succeeds")
	expect_true(RulesEngine.execute(loaded, registry, intent).is_valid, "Loaded continuation succeeds")
	expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Continuation preserves triggers, topology, Trade, draws, IDs, tracks and RNG")
	_valid(loaded, registry)
	return true


func _valid(state: RunState, registry: ContentRegistry) -> void:
	var report: InvariantReport = InvariantValidator.validate(state, registry)
	expect_true(report.is_valid, report.describe())


func _rejected_unchanged(state: RunState, registry: ContentRegistry, intent: PlaceTileCommand) -> void:
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, registry, intent).is_valid, "Invalid exact Transformation returns structured failure")
	expect_equal(StateNormalizer.fingerprint(state), before, "Invalid intent moves no copies and changes no edges, history, scores, IDs or RNG")


func bridge_closed_road_merger_preserves_paid_growth() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.river(registry)
	Fixture.Geography.add(state, registry, &"tile.bending_road", Vector2i.RIGHT, 2)
	Fixture.Geography.add(state, registry, &"tile.road_end", Vector2i.ONE)
	Fixture.Geography.add(state, registry, &"tile.road_end", Vector2i(-1, 1), 2)
	Fixture.Geography.add(state, registry, &"tile.road_end", Vector2i(-1, 2))
	var first: int = Fixture.component(state, Vector2i.ONE, TYPE.ROAD).lineage_id
	var second: int = Fixture.component(state, Vector2i(-1, 1), TYPE.ROAD).lineage_id
	expect_true(state.features.lineage(first).completed and state.features.lineage(second).completed, "Both parent Roads already scored")
	Fixture.play(state, registry, Fixture.BRIDGE, Vector2i.DOWN, &"bridge")
	var merged: FeatureLineageState = state.features.lineage(Fixture.component(state, Vector2i.DOWN, TYPE.ROAD).lineage_id)
	expect_true(merged.parent_ids.has(first) and merged.parent_ids.has(second), "Bridge physically merges both Road lineages")
	expect_true(merged.completed, "No open exits means genuine immediate closed Road completion")
	expect_equal(state.features.completions[-1].new_component_ids.size(), 1, "Only Bridge target is new Road growth")
	expect_equal(state.features.completions[-1].gains[TRACK.TRADE], 1, "Previously scored Road tiles do not repay")
	_valid(state, registry)
	return true


func urban_nonsettlement_boundary_excluded() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.Geography.add(state, registry, &"tile.road_end", Vector2i.RIGHT, 3)
	var copy_id: int = Fixture.Previous.acquire_hand(state, Fixture.URBAN)
	# North/South Urban axis would face the road_end's northern Field boundary.
	expect_true(Fixture.option_at(state, registry, copy_id, Vector2i(1, -1), &"urban_expansion", 0) == null, "Field on a tile without Settlement cannot be rewritten into invented Settlement")
	return true


func rewild_incomplete_forest_boundary_excluded() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.Geography.add(state, registry, &"tile.forest_belt", Vector2i.LEFT, 1)
	var copy_id: int = Fixture.Previous.acquire_hand(state, Fixture.REWILD)
	expect_true(Fixture.option_at(state, registry, copy_id, Vector2i(-1, -1), &"rewilding_expansion", 0) == null, "Boundary rewrite permission requires a completed Forest")
	return true


func rewild_overlay_preserves_development_slot() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	var target: Vector2i = Fixture.Previous.fields(state, registry)
	Fixture.play(state, registry, Fixture.REWILD, target, &"rewilding", 1)
	expect_true(state.expansion.board.get_cell(target).developments.is_empty(), "Transformation uses its own layer")
	var lodge: int = Fixture.Previous.play(state, registry, &"tile.development.foresters_lodge", target)
	expect_equal(Fixture.Previous.development(state, target).tile_copy_id, lodge, "New Forest may receive Lodge in still-free Development slot")
	expect_equal(state.expansion.board.get_cell(target).transformations.size(), 1, "Development preserves Transformation history")
	_valid(state, registry)
	return true


func forged_geometry_signature_is_atomic() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.river(registry)
	var copy_id: int = Fixture.Previous.acquire_hand(state, Fixture.BRIDGE)
	var intent: PlaceTileCommand = Fixture.command(Fixture.option_at(state, registry, copy_id, Vector2i.DOWN, &"bridge"))
	intent.transformation_signature += "changed"
	intent.expected_signature = ""
	_rejected_unchanged(state, registry, intent)
	return true


func transformation_bag_prevents_global_stalemate() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.river(registry)
	_empty_bag(state)
	for slot: int in range(3):
		Fixture.Previous.acquire_hand(state, &"tile.development.abbey", slot)
	var copy_id: int = PhysicalTileRules.acquire(state, Fixture.BRIDGE, &"scenario_fixture", TileLocationState.Kind.BAG)
	state.expansion.bag.append(copy_id)
	expect_true(StalemateRules.is_dead_hand(state, registry), "No active-hand Abbey prerequisite")
	expect_true(not StalemateRules.is_global_stalemate(state, registry), "Bag-wide search recognizes Bridge target")
	return true


func unplayable_transformations_allow_dead_hand() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	_empty_bag(state)
	for slot: int in range(3):
		Fixture.Previous.acquire_hand(state, Fixture.BRIDGE, slot)
	expect_true(StalemateRules.is_dead_hand(state, registry), "Three Bridges without River Run are dead")
	expect_true(StalemateRules.is_global_stalemate(state, registry), "No target anywhere in hand or bag")
	expect_true(RulesEngine.execute(state, registry, CycleDeadHandCommand.new()).is_valid, "Normal free cycle applies to physical Transformations")
	var emergency: Array[StringName] = []
	for copy: TileCopyState in state.tile_copies:
		if copy.acquisition_source == &"emergency_replenishment":
			emergency.append(copy.definition_id)
	emergency.sort()
	var expected: Array[StringName] = registry.get_config().emergency_definitions.duplicate()
	expected.sort()
	expect_equal(emergency, expected, "Fallback remains established three Expansion tiles")
	return true


func post_transform_query_remains_deterministic() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.river(registry)
	Fixture.play(state, registry, Fixture.BRIDGE, Vector2i.DOWN, &"bridge")
	var copy_id: int = Fixture.Previous.acquire_hand(state, Fixture.REWILD)
	var fingerprint: String = StateNormalizer.fingerprint(state)
	var first: Array[PlacementOption] = PlacementQueryService.query_for_copy(state, registry, copy_id)
	var second: Array[PlacementOption] = PlacementQueryService.query_for_copy(state, registry, copy_id)
	var signatures: Array[String] = []
	expect_equal(first.size(), second.size(), "Modified geometry query count stable")
	for index: int in range(first.size()):
		expect_equal(first[index].signature, second[index].signature, "Plan intent stable after other Transformation")
		expect_true(not signatures.has(first[index].signature), "No duplicate canonical intent")
		signatures.append(first[index].signature)
	expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Repeated query over modified geometry is read-only")
	return true


func _empty_bag(state: RunState) -> void:
	for copy_id: int in state.expansion.bag:
		state.expansion.removed_ids.append(copy_id)
		PhysicalTileRules.set_location(state, copy_id, TileLocationState.Kind.REMOVED_FROM_RUN)
	state.expansion.bag.clear()
