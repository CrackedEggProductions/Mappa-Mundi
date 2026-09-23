extends "res://tests/framework/test_suite.gd"

const F = preload("res://tests/fixtures/phase_six_factory.gd")
const TYPE = DomainTypes.FeatureType
const EDGE = DomainTypes.EdgeType


func tests() -> Array[Callable]:
	var cases: Array[Callable] = [forest_closed_merger, developed_forest_merger,
		urban_shared_completion_snapshot, rewild_shared_enclosure_snapshot,
		urban_open_merger, urban_trade_hub_merger, compatible_rewilding_stack,
		bridge_rewilding_ambiguity, abbey_rewilding_ambiguity, bridge_duplicate_rejected,
		bridge_end_rejected, effective_edges_drive_later_placement,
		new_occupancy_completes_enclosure, occupied_transform_does_not_fill_enclosure,
		stale_development_dependency, transformed_field_cannot_supply_boundary,
		bridge_preserves_monastery, preserved_housing_develops_new_forest]
	for stage: String in ["housing", "market", "grand_market", "port", "town_square"]:
		cases.append(urban_remaps_host.bind(stage))
	for id: StringName in [F.URBAN, F.BRIDGE, F.REWILD]:
		cases.append(reserve_each_design.bind(id))
		cases.append(survey_each_design.bind(id))
		cases.append(hand_refill_each_design.bind(id))
		cases.append(playable_each_design.bind(id))
	return cases


func _valid(state: RunState, registry: ContentRegistry) -> void:
	var report: InvariantReport = InvariantValidator.validate(state, registry)
	expect_true(report.is_valid, report.describe())


func _rejected(state: RunState, registry: ContentRegistry, intent: PlaceTileCommand) -> void:
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, registry, intent).is_valid, "Invalid command is structured rejection")
	expect_equal(StateNormalizer.fingerprint(state), before, "Rejection preserves all zones, IDs, RNG, counters, geometry and histories")


func _forest_merge(registry: ContentRegistry, developed: bool) -> RunState:
	var state: RunState = F.two_forests(registry)
	F.Previous.play(state, registry, &"tile.development.mill" if developed else &"tile.development.foresters_lodge", Vector2i.LEFT)
	F.Previous.play(state, registry, &"tile.development.foresters_lodge", Vector2i(-1, 2))
	F.play(state, registry, F.REWILD, Vector2i(-1, 2), &"rewilding", 0)
	F.Geography.add(state, registry, &"tile.forest_edge", Vector2i(-1, 3))
	return state


func forest_closed_merger() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _forest_merge(registry, false)
	var first: DevelopmentState = F.Previous.development(state, Vector2i.LEFT)
	var second: DevelopmentState = F.Previous.development(state, Vector2i(-1, 2))
	var parents: Array[int] = [first.host_lineage_id, second.host_lineage_id]
	var before: int = state.features.tracks.values[3]
	F.play(state, registry, F.REWILD, Vector2i(-1, 1), &"rewilding_expansion", 0)
	expect_equal(first.host_lineage_id, second.host_lineage_id, "Both Lodges follow merged Forest descendant")
	var lineage: FeatureLineageState = state.features.lineage(first.host_lineage_id)
	for parent: int in parents:
		expect_true(LineageService.is_ancestor(state, parent, lineage.lineage_id), "Both old Forest histories survive actual Transformation merger")
	expect_true(lineage.completed, "Final geometry is closed and genuinely completes")
	expect_equal(state.features.completions[-1].new_component_ids.size(), 2, "Only Rewilding base and new cap score; old Forest footprint cannot repay")
	expect_equal(state.features.tracks.values[3] - before, 6, "Two new components, preservation and both independent Lodge effects")
	_valid(state, registry)
	return true


func developed_forest_merger() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _forest_merge(registry, true)
	var before: int = state.features.tracks.values[3]
	F.play(state, registry, F.REWILD, Vector2i(-1, 1), &"rewilding_expansion", 0)
	expect_true(not state.features.completions[-1].forest_undeveloped, "Preserved Mill cancels future preservation")
	expect_equal(state.features.tracks.values[3] - before, 3, "Two new components and one Lodge, without preservation")
	_valid(state, registry)
	return true


func urban_remaps_host(stage: String) -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.two_settlements(registry)
	if stage == "port":
		F.Geography.add(state, registry, &"tile.river_end", Vector2i.DOWN)
	if stage == "grand_market":
		F.Previous.play(state, registry, &"tile.development.market", Vector2i.ZERO)
	var copy_id: int = F.Previous.play(state, registry, StringName("tile.development." + stage), Vector2i.ZERO)
	var overlay: DevelopmentState = DevelopmentService.find(state, copy_id)
	var old_host: int = overlay.host_lineage_id
	var river: int = overlay.river_lineage_id
	var placed_events: int = F.events(state, &"development_placed")
	F.play(state, registry, F.URBAN, Vector2i(0, -2), &"urban_expansion", 2)
	expect_true(LineageService.is_ancestor(state, old_host, overlay.host_lineage_id), stage + " remaps through live Urban merger")
	expect_equal(overlay.river_lineage_id, river, "Port's specific River remains unchanged")
	expect_equal(F.events(state, &"development_placed"), placed_events, "Host evolution never impersonates Development placement")
	_valid(state, registry)
	return true


func urban_open_merger() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.two_settlements(registry)
	var housing: int = F.Previous.play(state, registry, &"tile.development.housing", Vector2i.UP)
	F.play(state, registry, F.URBAN, Vector2i(0, -4), &"urban_expansion", 0)
	var before: Array[int] = state.features.tracks.values.duplicate()
	var completions: int = state.features.completions.size()
	F.play(state, registry, F.URBAN, Vector2i(0, -2), &"urban_expansion", 2)
	var host: FeatureLineageState = state.features.lineage(DevelopmentService.find(state, housing).host_lineage_id)
	expect_true(not host.completed, "Completed plus unfinished merger retains unresolved outer exit")
	expect_equal(state.features.completions.size(), completions, "Open merger creates no completion")
	expect_equal(state.features.tracks.values, before, "Open merger scores no base or Development gain")
	F.Previous.play(state, registry, &"tile.hamlet_edge", Vector2i(0, -5))
	expect_true(host.completed, "Later cap genuinely completes descendant")
	expect_equal(F.gains(state, housing, 0), 4, "Housing resolves once immediately and once on genuine later completion")
	_valid(state, registry)
	return true


func urban_trade_hub_merger() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.two_settlements(registry)
	F.Geography.add(state, registry, &"tile.river_run", Vector2i(2, -3))
	F.play(state, registry, F.BRIDGE, Vector2i(2, -3), &"bridge")
	var first: int = F.component(state, Vector2i.RIGHT, TYPE.ROAD).lineage_id
	var second: int = F.component(state, Vector2i(2, -3), TYPE.ROAD).lineage_id
	var before: int = state.features.tracks.values[1]
	F.play(state, registry, F.URBAN, Vector2i(0, -2), &"urban_expansion", 2)
	expect_equal(state.features.tracks.values[1], before, "Economic merger awards no automatic Trade")
	expect_equal(F.component(state, Vector2i.RIGHT, TYPE.ROAD).lineage_id, first, "First physical Road identity unchanged")
	expect_equal(F.component(state, Vector2i(2, -3), TYPE.ROAD).lineage_id, second, "Second physical Road identity unchanged")
	var shared: bool = false
	for network: CurrentTradeNetwork in TradeNetworkService.rebuild(state):
		if first in network.road_lineage_ids and second in network.road_lineage_ids:
			shared = true
			expect_equal(network.settlement_lineage_ids.size(), 1, "Descendant is one current Settlement hub")
	expect_true(shared, "Attached networks become connected through merged Settlement")
	_valid(state, registry)
	return true


func compatible_rewilding_stack() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	F.Geography.add(state, registry, &"tile.road_end", Vector2i.RIGHT, 3)
	var first: int = F.play(state, registry, F.REWILD, Vector2i(2, 0), &"rewilding_expansion", 0)
	# Move outward before applying the perpendicular second Forest axis: west remains occupied Field here.
	F.play(state, registry, F.REWILD, Vector2i(2, -1), &"rewilding_expansion", 0)
	var target: Vector2i = Vector2i(2, -1)
	var component: FeatureComponentState = F.component(state, target, TYPE.FOREST)
	var second: int = F.play(state, registry, F.REWILD, target, &"rewilding", 1)
	var cell: BoardCellState = state.expansion.board.get_cell(target)
	expect_equal(cell.transformations.size(), 2, "Compatible Transformation instances coexist")
	expect_equal(F.component(state, target, TYPE.FOREST), component, "Stack does not create duplicate Forest contribution")
	expect_equal(cell.effective_edges, [1, 1, 1, 1], "New axis preserves earlier Forest edges")
	expect_true(first != second, "Each physical Transformation retains separate identity")
	var repeat_id: int = F.Previous.acquire_hand(state, F.REWILD)
	expect_true(F.option_at(state, registry, repeat_id, target, &"rewilding") == null, "No effect remains after Field is consumed")
	_valid(state, registry)
	return true


func bridge_rewilding_ambiguity() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.river(registry)
	F.play(state, registry, F.REWILD, Vector2i.DOWN, &"rewilding", 1)
	expect_true(TransformationPlacementQuery.underlying_bridge_target(state.expansion.board.get_cell(Vector2i.DOWN)), "Rewilded straight River retains explicit underlying Bridge eligibility")
	var id: int = F.Previous.acquire_hand(state, F.BRIDGE)
	var intent: PlaceTileCommand = PlaceTileCommand.new(id, TileLocationState.Kind.ACTIVE_HAND, Vector2i.DOWN, 1)
	intent.placement_mode = DomainTypes.PlacementMode.TRANSFORMATION
	expect_equal(RulesEngine.validate(state, registry, intent).error_code, &"unresolved_bridge_rewilding_rewrite", "Exact Forest-to-Road permission is explicitly unresolved")
	_rejected(state, registry, intent)
	return true


func abbey_rewilding_ambiguity() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	var target: Vector2i = F.Previous.fields(state, registry)
	F.Previous.play(state, registry, &"tile.development.monastery", target)
	F.Previous.play(state, registry, &"tile.development.abbey", target)
	var id: int = F.Previous.acquire_hand(state, F.REWILD)
	var intent: PlaceTileCommand = PlaceTileCommand.new(id, TileLocationState.Kind.ACTIVE_HAND, target, 1)
	intent.placement_mode = DomainTypes.PlacementMode.TRANSFORMATION
	expect_equal(RulesEngine.validate(state, registry, intent).error_code, &"unresolved_abbey_field_dependency", "Abbey dependency is an explicit source-rule gap")
	_rejected(state, registry, intent)
	return true


func bridge_duplicate_rejected() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.river(registry)
	F.play(state, registry, F.BRIDGE, Vector2i.DOWN, &"bridge")
	var id: int = F.Previous.acquire_hand(state, F.BRIDGE)
	expect_true(F.option_at(state, registry, id, Vector2i.DOWN, &"bridge") == null, "Second Bridge has no new authorized Road geometry")
	var intent: PlaceTileCommand = PlaceTileCommand.new(id, TileLocationState.Kind.ACTIVE_HAND, Vector2i.DOWN, 1)
	intent.placement_mode = DomainTypes.PlacementMode.TRANSFORMATION
	_rejected(state, registry, intent)
	return true


func bridge_end_rejected() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	F.Geography.add(state, registry, &"tile.river_end", Vector2i.DOWN)
	var id: int = F.Previous.acquire_hand(state, F.BRIDGE)
	expect_true(PlacementQueryService.query_for_copy(state, registry, id).is_empty(), "River End is not an underlying straight Run")
	return true


func effective_edges_drive_later_placement() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.river(registry)
	F.play(state, registry, F.BRIDGE, Vector2i.DOWN, &"bridge")
	expect_equal(registry.get_tile(&"tile.river_run").canonical_edges, [2, 0, 2, 0], "Static Resource retains historical River geometry")
	expect_equal(state.expansion.board.get_cell(Vector2i.DOWN).effective_edges, [2, 3, 2, 3], "Runtime geometry includes Bridge Road axis")
	expect_true(not PlacementQueryService.validate(state.expansion.board, registry.get_tile(&"tile.open_fields"), Vector2i.ONE, 0).is_valid, "Ordinary placement cannot match historical Field instead of effective Road")
	expect_true(PlacementQueryService.validate(state.expansion.board, registry.get_tile(&"tile.road_end"), Vector2i.ONE, 3).is_valid, "Ordinary placement matches new effective Road")
	return true


func new_occupancy_completes_enclosure() -> bool:
	var registry: ContentRegistry = F.content()
	for urban: bool in [false, true]:
		var state: RunState = F.create(registry)
		F.Geography.add(state, registry, &"tile.river_end", Vector2i.DOWN)
		F.Geography.add(state, registry, &"tile.hamlet_edge" if urban else &"tile.forest_edge", Vector2i(0, 2), 3)
		F.Geography.add(state, registry, &"tile.open_fields", Vector2i(0, 3))
		for at: Vector2i in [Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4), Vector2i(0, 4), Vector2i(-1, 4), Vector2i(-1, 3)]:
			F.Geography.add(state, registry, &"tile.open_fields", at)
		F.Previous.play(state, registry, &"tile.development.monastery", Vector2i(0, 3))
		var enclosure: EnclosureState = state.features.enclosures[0]
		expect_true(enclosure.completed_stages.is_empty(), "Seven surrounding squares leave enclosure unfinished")
		F.play(state, registry, F.URBAN if urban else F.REWILD, Vector2i(-1, 2),
			&"urban_expansion" if urban else &"rewilding_expansion", 3 if urban else 1)
		expect_true(&"monastery" in enclosure.completed_stages, "Specialized new base fills eighth enclosure square")
		_valid(state, registry)
	return true


func occupied_transform_does_not_fill_enclosure() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.river(registry)
	F.Previous.play(state, registry, &"tile.development.monastery", Vector2i.DOWN)
	var squares: int = state.expansion.board.cells.size()
	F.play(state, registry, F.BRIDGE, Vector2i.DOWN, &"bridge")
	expect_equal(state.expansion.board.cells.size(), squares, "Bridge adds no occupied coordinate")
	expect_true(state.features.enclosures[0].completed_stages.is_empty(), "Overlay cannot fill a missing neighboring square")
	_valid(state, registry)
	return true


func stale_development_dependency() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.river(registry)
	var id: int = F.Previous.acquire_hand(state, F.REWILD, 2)
	var option: PlacementOption = F.option_at(state, registry, id, Vector2i.DOWN, &"rewilding", 1)
	F.Previous.play(state, registry, &"tile.development.mill", Vector2i.DOWN)
	var intent: PlaceTileCommand = F.command(option)
	_rejected(state, registry, intent)
	intent.expected_board_revision = -1
	intent.expected_state_revision = -1
	intent.expected_signature = ""
	_rejected(state, registry, intent)
	return true


func transformed_field_cannot_supply_boundary() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	F.Previous.complete_settlement(state, registry)
	F.play(state, registry, F.REWILD, Vector2i.UP, &"rewilding", 1)
	var id: int = F.Previous.acquire_hand(state, F.URBAN)
	expect_true(F.option_at(state, registry, id, Vector2i(0, -2), &"urban_expansion", 0) == null, "Field-facing socket does not recreate consumed Field geography")
	return true


func bridge_preserves_monastery() -> bool:
	var registry: ContentRegistry = F.content()
	for stage: String in ["mill", "monastery", "abbey"]:
		var state: RunState = F.river(registry, true)
		if stage == "abbey":
			F.Previous.play(state, registry, &"tile.development.monastery", Vector2i.DOWN)
		var id: int = F.Previous.play(state, registry, StringName("tile.development." + stage), Vector2i.DOWN)
		var count: int = state.features.completions.size()
		F.play(state, registry, F.BRIDGE, Vector2i.DOWN, &"bridge")
		expect_equal(F.Previous.development(state, Vector2i.DOWN).tile_copy_id, id, "Bridge preserves existing " + stage)
		expect_equal(state.features.completions.size(), count, "Neither occupied overlay nor preserved River causes completion")
		expect_true(state.expansion.board.get_cell(Vector2i.DOWN).has_field_geography, "Protected interior Field remains despite Road bank exits")
		_valid(state, registry)
	return true


func preserved_housing_develops_new_forest() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	F.Previous.complete_settlement(state, registry)
	F.Previous.play(state, registry, &"tile.development.housing", Vector2i.UP)
	F.play(state, registry, F.REWILD, Vector2i.UP, &"rewilding", 1)
	var before: int = state.features.tracks.values[3]
	F.Previous.play(state, registry, &"tile.forest_edge", Vector2i(1, -1))
	F.Previous.play(state, registry, &"tile.forest_edge", Vector2i(-1, -1))
	expect_true(not state.features.completions[-1].forest_undeveloped, "Housing preserved inside new Forest makes it developed")
	expect_equal(state.features.tracks.values[3] - before, 3, "Only three new Forest components pay, with no preservation")
	_valid(state, registry)
	return true


func reserve_each_design(id: StringName) -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.river(registry)
	var copy_id: int = F.Previous.acquire_hand(state, id)
	expect_true(RulesEngine.execute(state, registry, ReserveTileCommand.new(copy_id)).is_valid, "Physical Transformation enters Reserve")
	var hand: Array[int] = state.expansion.hand.duplicate()
	var bag: Array[int] = state.expansion.bag.duplicate()
	var options: Array[PlacementOption] = PlacementQueryService.query_for_copy(state, registry, copy_id)
	expect_true(not options.is_empty(), "Reserved design has legal intent")
	if not options.is_empty():
		expect_true(RulesEngine.execute(state, registry, F.command(options[0], TileLocationState.Kind.RESERVE)).is_valid, "Reserve Transformation command resolves")
		expect_equal(state.expansion.reserve_id, 0, "Reserve clears")
		expect_equal(state.expansion.hand, hand, "Reserve play never refills hand")
		expect_equal(state.expansion.bag, bag, "Reserve play never consumes a bag copy")
	_valid(state, registry)
	return true


func survey_each_design(id: StringName) -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.river(registry)
	var copy_id: int = F.Previous.acquire_hand(state, id)
	var count: int = state.expansion.normal_placements
	expect_true(RulesEngine.execute(state, registry, SurveyTileCommand.new(copy_id)).is_valid, "Survey accepts physical Transformation")
	expect_equal(F.Previous.location(state, copy_id), TileLocationState.Kind.REMOVED_FROM_RUN, "Surveyed copy is permanently removed")
	expect_equal(state.expansion.normal_placements, count, "Survey is not a normal placement")
	_valid(state, registry)
	return true


func hand_refill_each_design(id: StringName) -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.river(registry)
	var copy_id: int = F.Previous.acquire_hand(state, id)
	var next: int = state.expansion.bag[0]
	var count: int = state.expansion.normal_placements
	var options: Array[PlacementOption] = PlacementQueryService.query_for_copy(state, registry, copy_id)
	expect_true(not options.is_empty(), "Every Transformation design can play from hand")
	if not options.is_empty():
		expect_true(RulesEngine.execute(state, registry, F.command(options[0])).is_valid, "Active-hand Transformation resolves")
		expect_equal(state.expansion.normal_placements, count + 1, "Exactly one normal placement consumed")
		expect_equal(state.expansion.hand[0], next, "Normal post-consequence draw refills consumed slot")
		expect_equal(state.expansion.pending_refill_index, -1, "No unfinished refill remains")
	_valid(state, registry)
	return true


func playable_each_design(id: StringName) -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.river(registry)
	for slot: int in range(3):
		F.Previous.acquire_hand(state, id, slot)
	expect_true(not StalemateRules.is_dead_hand(state, registry), "Actual-class legal options prevent dead hand for " + String(id))
	return true


func urban_shared_completion_snapshot() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.two_settlements(registry)
	F.Geography.add(state, registry, &"tile.river_end", Vector2i.DOWN)
	F.Geography.add(state, registry, &"tile.open_fields", Vector2i(-1, -1))
	F.Geography.add(state, registry, &"tile.road_end", Vector2i(-1, -2), 1)
	var overlays: Array[int] = [
		F.Previous.play(state, registry, &"tile.development.port", Vector2i.ZERO),
		F.Previous.play(state, registry, &"tile.development.housing", Vector2i.UP),
		F.Previous.play(state, registry, &"tile.development.market", Vector2i(0, -3)),
		F.Previous.play(state, registry, &"tile.development.town_square", Vector2i(1, -3)),
		F.Previous.play(state, registry, &"tile.development.mill", Vector2i(1, -2)),
	]
	var history_size: int = state.features.history.size()
	var completions: int = state.features.completions.size()
	F.play(state, registry, F.URBAN, Vector2i(0, -2), &"urban_expansion", 2)
	expect_equal(state.features.completions.size() - completions, 2, "One transformed board completes Settlement and its distinct physical Road")
	var snapshot: int = state.features.completions[-1].snapshot_id
	expect_equal(state.features.completions[-2].snapshot_id, snapshot, "All base effects share immutable final-state snapshot")
	var triggered: Array[int] = []
	for index: int in range(history_size, state.features.history.size()):
		var event: FeatureHistoryRecord = state.features.history[index]
		if event.kind == &"development_completion_trigger":
			expect_equal(event.parent_event_id, snapshot, "Every Development calculation uses the same completion package")
			triggered.append(event.source_id)
	triggered.sort()
	overlays.sort()
	expect_equal(triggered, overlays, "Housing, Market, Port, Town Square and touching Mill each resolve independently")
	_valid(state, registry)
	return true


func rewild_shared_enclosure_snapshot() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	F.Geography.add(state, registry, &"tile.river_end", Vector2i.DOWN)
	F.Geography.add(state, registry, &"tile.forest_edge", Vector2i(0, 2), 3)
	F.Geography.add(state, registry, &"tile.open_fields", Vector2i(0, 3))
	for at: Vector2i in [Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4), Vector2i(0, 4), Vector2i(-1, 4), Vector2i(-1, 3), Vector2i(-2, 3)]:
		F.Geography.add(state, registry, &"tile.open_fields", at)
	F.Geography.add(state, registry, &"tile.forest_edge", Vector2i(-2, 2), 1)
	F.Previous.play(state, registry, &"tile.development.monastery", Vector2i(0, 3))
	F.Previous.play(state, registry, &"tile.development.abbey", Vector2i(0, 3))
	var count: int = state.features.completions.size()
	F.play(state, registry, F.REWILD, Vector2i(-1, 2), &"rewilding_expansion", 1)
	expect_equal(state.features.completions.size() - count, 2, "New Rewilding base simultaneously closes Forest and Abbey enclosure")
	expect_equal(state.features.completions[-1].snapshot_id, state.features.completions[-2].snapshot_id, "Enclosure and Forest share snapshot")
	expect_equal(state.features.enclosures[0].completed_stages, [&"abbey"], "Incomplete replaced Monastery stage never scores")
	_valid(state, registry)
	return true
