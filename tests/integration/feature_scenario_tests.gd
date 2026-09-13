extends "res://tests/framework/test_suite.gd"

const Fixture = preload("res://tests/fixtures/phase_three_factory.gd")
const EDGE = DomainTypes.EdgeType
const TYPE = DomainTypes.FeatureType


func tests() -> Array[Callable]:
	return [settlement_recompletion_scores_only_growth_and_new_support,
		forest_recompletion_preserves_old_scores_and_reevaluates_preservation,
		road_recompletion_scores_new_tiles_only,
		forest_merger_inherits_two_scored_parents, road_merger_never_repays_parents,
		river_reopening_is_rejected_without_history_change,
		riverside_support_retains_distinct_categories,
		woodland_river_contact_scores_once, shared_field_support_is_per_settlement,
		monastery_fixture_completes_once, simultaneous_batch_freezes_every_peer,
		deterministic_homestead_demo, threshold_crossings_have_no_rewards,
		live_peer_mutation_cannot_change_shared_snapshot, settlement_merger_preserves_support_eligibility]


func settlement_recompletion_scores_only_growth_and_new_support() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.add(state, content, &"tile.hamlet_edge", Vector2i.UP, 2)
	var lineage: FeatureLineageState = Fixture.lineage_at(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	var id: int = lineage.lineage_id
	expect_equal(state.features.tracks.values[0], 5, "Founding and Hamlet +4; Hamlet Field +1")
	expect_true(Fixture.rewrite(state, content, Vector2i.UP, [EDGE.SETTLEMENT, EDGE.FIELD, EDGE.SETTLEMENT, EDGE.FIELD]).is_valid, "Controlled genuine reopening")
	Fixture.add(state, content, &"tile.hamlet_edge", Vector2i(0, -2), 2)
	expect_equal(Fixture.lineage_at(state, Vector2i.UP, TYPE.SETTLEMENT).lineage_id, id, "Same historical lineage")
	expect_equal(state.features.tracks.values[0], 8, "Only new component +2 and new Field support +1")
	expect_equal(lineage.completion_ids.size(), 2, "Both Establishments retained")
	expect_equal(lineage.growth_phase, 2, "Reopening begins second growth phase")
	expect_equal(lineage.highest_settlement_class, 2, "Three tiles establish Village")
	var record: FeatureCompletionRecord = state.features.completions[-1]
	expect_true(not record.first_completion, "Explicit re-completion flag")
	expect_equal(record.new_component_ids.size(), 1, "Only genuine new growth pays")
	expect_equal(record.new_field_ids.size(), 1, "Old support excluded")
	_valid(state, content)
	return true


func forest_recompletion_preserves_old_scores_and_reevaluates_preservation() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.add(state, content, &"tile.forest_edge", Vector2i.LEFT, 1)
	var lineage: FeatureLineageState = Fixture.lineage_at(state, Vector2i.ZERO, TYPE.FOREST)
	expect_equal(state.features.tracks.values[3], 4, "Two Forest tiles and preservation")
	expect_true(Fixture.rewrite(state, content, Vector2i.LEFT, [EDGE.FIELD, EDGE.FOREST, EDGE.FIELD, EDGE.FOREST]).is_valid, "Forest reopening")
	Fixture.add(state, content, &"tile.forest_edge", Vector2i(-2, 0), 1)
	expect_equal(state.features.tracks.values[3], 7, "New Forest +1 and repeat preservation +2")
	expect_equal(lineage.scored_component_ids.size(), 3, "Old eligibility retained and new growth recorded")
	expect_equal(lineage.completion_ids.size(), 2, "Both historical completions retained")
	_valid(state, content)
	return true


func road_recompletion_scores_new_tiles_only() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.add(state, content, &"tile.road_end", Vector2i.RIGHT, 3)
	var lineage: FeatureLineageState = Fixture.lineage_at(state, Vector2i.ZERO, TYPE.ROAD)
	expect_equal(state.features.tracks.values[1], 2, "Two Road tiles; Founding access gives no network bonus")
	expect_true(Fixture.rewrite(state, content, Vector2i.RIGHT, [EDGE.FIELD, EDGE.ROAD, EDGE.FIELD, EDGE.ROAD]).is_valid, "Road reopening")
	Fixture.add(state, content, &"tile.road_end", Vector2i(2, 0), 3)
	expect_equal(state.features.tracks.values[1], 3, "Only new Road tile pays")
	expect_true(lineage.scored_settlement_ids.is_empty(), "No Phase-4 history populated")
	_valid(state, content)
	return true


func forest_merger_inherits_two_scored_parents() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = _merge_fixture(content, true)
	var lineage: FeatureLineageState = Fixture.lineage_at(state, Vector2i.ZERO, TYPE.FOREST)
	expect_equal(lineage.parent_ids.size(), 2, "Two parents become one descendant")
	expect_equal(lineage.scored_component_ids.size(), 5, "Both old histories and one new connector retained")
	expect_equal(state.features.tracks.values[3], 11, "4 + 4 + new connector 1 + preservation 2")
	expect_equal(lineage.completion_ids.size(), 3, "Descendant includes both parental completions")
	for parent_id: int in lineage.parent_ids:
		expect_true(not state.features.lineage(parent_id).active, "Merged parent archived")
		expect_true(LineageService.is_ancestor(state, parent_id, lineage.lineage_id), "Ancestry resolves historical parent")
	_valid(state, content)
	return true


func road_merger_never_repays_parents() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = _merge_fixture(content, false)
	expect_equal(state.features.tracks.values[1], 5, "Two scored pairs then only new connector")
	expect_equal(state.features.completions[-1].new_component_ids.size(), 1, "New lineage does not reset eligibility")
	_valid(state, content)
	return true


func settlement_merger_preserves_support_eligibility() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.add(state, content, &"tile.hamlet_edge", Vector2i.UP, 2)
	Fixture.add(state, content, &"tile.open_fields", Vector2i(1, -1))
	Fixture.add(state, content, &"tile.open_fields", Vector2i(1, -2))
	Fixture.add(state, content, &"tile.hamlet_edge", Vector2i(1, -3), 3)
	Fixture.add(state, content, &"tile.hamlet_edge", Vector2i(0, -3), 1)
	expect_equal(state.features.tracks.values[0], 12, "Independent Settlement histories score 5 and 7")
	expect_true(Fixture.rewrite(state, content, Vector2i.UP, [4, 0, 4, 0]).is_valid, "Reopen first Settlement")
	expect_true(Fixture.rewrite(state, content, Vector2i(0, -3), [0, 4, 4, 0]).is_valid, "Reopen second Settlement")
	Fixture.add(state, content, &"tile.settlement_throughway", Vector2i(0, -2))
	var descendant: FeatureLineageState = Fixture.lineage_at(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	expect_equal(descendant.parent_ids.size(), 2, "Settlement merge retains both parents")
	expect_equal(state.features.tracks.values[0], 16, "Only connector +2 and two new supports +2; parental support never repays")
	expect_equal(state.features.completions[-1].new_field_ids.size(), 2, "Inherited support is excluded from descendant payout")
	_valid(state, content)
	return true


func _merge_fixture(content: ContentRegistry, forest: bool) -> RunState:
	var state: RunState = Fixture.create(content)
	var side: int = -1 if forest else 1
	var edge: DomainTypes.EdgeType = EDGE.FOREST if forest else EDGE.ROAD
	var endpoint: StringName = &"tile.forest_edge" if forest else &"tile.road_end"
	var straight: StringName = &"tile.forest_belt" if forest else &"tile.straight_road"
	Fixture.add(state, content, endpoint, Vector2i(side, 0), 1 if forest else 3)
	Fixture.add(state, content, &"tile.open_fields", Vector2i(2 * side, 0))
	Fixture.add(state, content, &"tile.open_fields", Vector2i(2 * side, 1))
	Fixture.add(state, content, endpoint, Vector2i(2 * side, 2), 1 if forest else 3)
	Fixture.add(state, content, endpoint, Vector2i(side, 2), 3 if forest else 1)
	var first: Array[DomainTypes.EdgeType] = [EDGE.FIELD, edge if forest else EDGE.FIELD, edge, EDGE.FIELD if forest else edge]
	var second: Array[DomainTypes.EdgeType] = [edge, EDGE.FIELD if forest else edge, EDGE.FIELD, edge if forest else EDGE.FIELD]
	assert(Fixture.rewrite(state, content, Vector2i(side, 0), first).is_valid)
	assert(Fixture.rewrite(state, content, Vector2i(side, 2), second).is_valid)
	Fixture.add(state, content, straight, Vector2i(side, 1))
	return state


func river_reopening_is_rejected_without_history_change() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.add(state, content, &"tile.river_end", Vector2i.DOWN)
	expect_equal(state.features.tracks.values[3], 1, "Two River tiles score floor(2/2)")
	var before: String = StateNormalizer.fingerprint(state)
	var result: ValidationResult = Fixture.rewrite(state, content, Vector2i.DOWN, [EDGE.RIVER, EDGE.FIELD, EDGE.RIVER, EDGE.FIELD])
	expect_equal(result.error_code, &"completed_river_reopening", "Completed River cannot reopen")
	expect_equal(StateNormalizer.fingerprint(state), before, "Rejected rewrite preserves all history")
	FeatureResolutionService.resolve(state)
	expect_equal(StateNormalizer.fingerprint(state), before, "Completed River cannot pay again on rebuild")
	return true


func riverside_support_retains_distinct_categories() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	var id: int = Fixture.add(state, content, &"tile.riverside_hamlet", Vector2i.UP, 2)
	var lineage: FeatureLineageState = Fixture.lineage_at(state, Vector2i.UP, TYPE.SETTLEMENT)
	expect_true(id in lineage.scored_field_ids and id in lineage.scored_river_ids, "One Riverside tile pays distinct Field and River categories")
	expect_equal(state.features.tracks.values[0], 6, "Two Settlement components and two genuine support categories")
	Fixture.add(state, content, &"tile.river_end", Vector2i(-1, -1), 1)
	expect_equal(state.features.tracks.values[0], 6, "New nearby support does not create a false completion")
	_valid(state, content)
	return true


func woodland_river_contact_scores_once() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	var woodland: int = Fixture.add(state, content, &"tile.woodland_river", Vector2i.DOWN, 2)
	var neighbor: int = Fixture.add(state, content, &"tile.forest_edge", Vector2i(-1, 1), 1)
	Fixture.add(state, content, &"tile.river_end", Vector2i.ONE, 3)
	var river: FeatureLineageState = Fixture.lineage_at(state, Vector2i.DOWN, TYPE.RIVER)
	expect_equal(river.scored_forest_ids, [woodland, neighbor], "Same-tile and touching Forest counted once each")
	expect_equal(state.features.tracks.values[3], 3, "River length floor(3/2) plus two Forest contacts")
	var before: String = StateNormalizer.fingerprint(state)
	FeatureResolutionService.resolve(state)
	expect_equal(StateNormalizer.fingerprint(state), before, "Repeated resolution cannot farm River contact")
	return true


func shared_field_support_is_per_settlement() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.add(state, content, &"tile.road_end", Vector2i.RIGHT, 3)
	var support: int = Fixture.add(state, content, &"tile.open_fields", Vector2i(1, -1))
	Fixture.add(state, content, &"tile.hamlet_edge", Vector2i.UP, 2)
	Fixture.add(state, content, &"tile.hamlet_edge", Vector2i(2, -1))
	Fixture.add(state, content, &"tile.hamlet_edge", Vector2i(2, -2), 2)
	var first: FeatureLineageState = Fixture.lineage_at(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	var second: FeatureLineageState = Fixture.lineage_at(state, Vector2i(2, -1), TYPE.SETTLEMENT)
	expect_true(first.lineage_id != second.lineage_id, "Distinct established Settlements")
	expect_true(support in first.scored_field_ids and support in second.scored_field_ids, "Same Field supports each lineage independently")
	_valid(state, content)
	return true


func monastery_fixture_completes_once() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	var enclosure: EnclosureState = Fixture.add_monastery(state, content, Vector2i.ZERO)
	Fixture.add(state, content, &"tile.hamlet_edge", Vector2i.UP, 2)
	Fixture.add(state, content, &"tile.road_end", Vector2i.RIGHT, 3)
	Fixture.add(state, content, &"tile.river_end", Vector2i.DOWN)
	Fixture.add(state, content, &"tile.forest_edge", Vector2i.LEFT, 1)
	for coordinate: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		Fixture.add(state, content, &"tile.open_fields", coordinate)
	expect_equal(state.features.tracks.values[2], 0, "Seven neighbors remain incomplete")
	Fixture.add(state, content, &"tile.open_fields", Vector2i.ONE)
	expect_equal(state.features.tracks.values[2], 13, "Five base plus eight distinct natural squares")
	expect_equal(enclosure.completed_stages, [&"monastery"], "Persistent enclosure stage completion")
	var before: String = StateNormalizer.fingerprint(state)
	FeatureResolutionService.resolve(state)
	expect_equal(StateNormalizer.fingerprint(state), before, "Enclosure cannot repeat its completed stage")
	_valid(state, content)
	return true


func simultaneous_batch_freezes_every_peer() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = simultaneous_fixture(content)
	var last: FeatureCompletionRecord = state.features.completions[-1]
	var previous: FeatureCompletionRecord = state.features.completions[-2]
	expect_equal(last.snapshot_id, previous.snapshot_id, "One placement uses a shared immutable completion batch")
	expect_true(last.feature_type != previous.feature_type, "Road and Settlement complete independently")
	expect_equal(state.features.tracks.values[1], 7, "Seven Road components, no Settlement connection bonus")
	var snapshot: CompletionSnapshot = FeatureScoringService.capture(state, TopologyService.rebuild(state))
	expect_true(FeatureScoringService.calculate(snapshot).is_empty(), "Completed peers cannot fire again")
	_valid(state, content)
	return true


static func simultaneous_fixture(content: ContentRegistry, place_final: bool = true) -> RunState:
	var state: RunState = Fixture.create(content)
	Fixture.add(state, content, &"tile.settlement_corner", Vector2i.UP, 1)
	Fixture.add(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	Fixture.add(state, content, &"tile.bending_road", Vector2i(2, 0), 3)
	Fixture.add(state, content, &"tile.straight_road", Vector2i(2, -1))
	Fixture.add(state, content, &"tile.bending_road", Vector2i(2, -2), 2)
	Fixture.add(state, content, &"tile.bending_road", Vector2i(1, -2), 1)
	if place_final:
		Fixture.add(state, content, &"tile.settlement_gate", Vector2i(1, -1), 3)
	return state


func live_peer_mutation_cannot_change_shared_snapshot() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = simultaneous_fixture(content, false)
	var at: Vector2i = Vector2i(1, -1)
	var definition: TileDefinition = content.get_tile(&"tile.settlement_gate")
	expect_true(PlacementQueryService.validate(state.expansion.board, definition, at, 3).is_valid, "Final tile legal")
	# Inspect the deterministic internal resolution boundary before any completion applies.
	var id: int = PhysicalTileRules.acquire(state, definition.definition_id, &"scenario_fixture", TileLocationState.Kind.BOARD_BASE)
	state.expansion.normal_placements += 1
	var cell: BoardCellState = BoardCellState.from_definition(definition, id, at, 3, 1, state.expansion.normal_placements)
	state.expansion.board.add_cell(cell)
	TopologyService.add_cell_components(state, cell)
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	LineageService.reconcile(state, current, id)
	var snapshot: CompletionSnapshot = FeatureScoringService.capture(state, current, id)
	var expected: Array[FeatureCompletionRecord] = FeatureScoringService.calculate(snapshot)
	expect_equal(expected.size(), 2, "Both genuine peers identified before scoring")
	var peer: FeatureLineageState = state.features.lineage(expected[1].lineage_id)
	var history: Array[int] = peer.scored_component_ids.duplicate()
	peer.scored_component_ids = peer.member_ids.duplicate()
	state.features.tracks.values[0] = 999
	var repeated: Array[FeatureCompletionRecord] = FeatureScoringService.calculate(snapshot)
	expect_equal(repeated[1].gains, expected[1].gains, "Live history change cannot affect frozen peer scoring")
	expect_equal(snapshot.data()["tracks"][0], 0, "Snapshot retains shared pre-resolution Tracks")
	peer.scored_component_ids = history
	state.features.tracks.values[0] = 0
	FeatureScoringService.resolve(state, current, id)
	state.expansion.state_revision += 1
	_valid(state, content)
	return true


func threshold_crossings_have_no_rewards() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.add(state, content, &"tile.forest_edge", Vector2i.LEFT, 1)
	var copies: int = state.tile_copies.size()
	var rng: int = state.current_rng_state
	for index: int in range(50):
		expect_true(Fixture.rewrite(state, content, Vector2i.LEFT, [EDGE.FIELD, EDGE.FOREST, EDGE.FIELD, EDGE.FOREST]).is_valid, "Fixture reopens Forest")
		expect_true(Fixture.rewrite(state, content, Vector2i.LEFT, [EDGE.FIELD, EDGE.FOREST, EDGE.FIELD, EDGE.FIELD]).is_valid, "Fixture recloses without fresh growth")
	expect_equal(state.features.tracks.values[3], 104, "Preservation reevaluates across all threshold values")
	expect_equal(state.tile_copies.size(), copies, "No fake reward additions")
	expect_equal(state.current_rng_state, rng, "Scoring uses no gameplay RNG")
	for event: FeatureHistoryRecord in state.features.history:
		expect_true(event.kind != &"track_threshold_crossed", "Threshold rewards are deferred")
	_valid(state, content)
	return true


func deterministic_homestead_demo() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = HomesteadRunFactory.create(16, content)
	var mirror: RunState = null
	var seen_types: Array[int] = []
	for index: int in range(12):
		if index == 5:
			var saved: SerializationResult = RunSerializer.serialize(state, content)
			expect_true(saved.validation.is_valid, "Demo save valid")
			var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
			expect_true(loaded.validation.is_valid, loaded.validation.user_message)
			mirror = loaded.state
			if mirror == null:
				return true
			expect_equal(StateNormalizer.fingerprint(mirror), StateNormalizer.fingerprint(state), "Load performs no scoring/history effects")
		var intent: PlaceTileCommand = _best_intent(state, content, seen_types)
		for attempt: int in range(20):
			if intent != null:
				break
			expect_true(RulesEngine.execute(state, content, CycleDeadHandCommand.new()).is_valid, "Free dead-hand cycle")
			if mirror != null:
				expect_true(RulesEngine.execute(mirror, content, CycleDeadHandCommand.new()).is_valid, "Mirror free cycle")
			intent = _best_intent(state, content, seen_types)
		if intent == null:
			expect_true(false, "Demo must find a legal placement")
			return true
		expect_true(RulesEngine.execute(state, content, intent).is_valid, "Demo legal command")
		for record: FeatureCompletionRecord in state.features.completions:
			if record.feature_type not in seen_types:
				seen_types.append(record.feature_type)
		if mirror != null:
			expect_true(RulesEngine.execute(mirror, content, intent).is_valid, "Loaded continuation command")
			expect_equal(StateNormalizer.fingerprint(mirror), StateNormalizer.fingerprint(state), "Identical scored continuation")
		_valid(state, content)
	expect_equal(state.expansion.normal_placements, 12, "Twelve seeded scored placements")
	expect_equal(seen_types.size(), 4, "Seeded run completes all four tracked feature types")
	print("DEMO Phase 3: 12 seeded legal placements; completed types=%s; Tracks=%s; save/load after 5; identical topology, lineage, history and scoring continuation." % [seen_types, state.features.tracks.values])
	return true


func _best_intent(state: RunState, content: ContentRegistry, seen_types: Array[int]) -> PlaceTileCommand:
	var best: PlaceTileCommand = null
	var best_value: int = -1
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	for tile_id: int in state.expansion.hand:
		var definition: TileDefinition = content.get_tile(PhysicalTileRules.find_copy(state, tile_id).definition_id)
		for option: PlacementOption in PlacementQueryService.query(state.expansion.board, definition, tile_id, state.expansion.state_revision):
			var edges: Array[DomainTypes.EdgeType] = TileRotation.edges(definition.canonical_edges, option.rotation)
			var value: int = 0
			for type: int in range(4):
				var edge: int = FeatureState.edge_for_type(type as DomainTypes.FeatureType)
				if edge not in edges:
					continue
				var exits: int = 0
				var parents: Array[int] = []
				for direction: int in range(4):
					if edges[direction] != edge:
						continue
					var at: Vector2i = option.coordinate + BoardState.ORTHOGONAL_OFFSETS[direction]
					var component: FeatureComponentState = state.features.component_at(at, type as DomainTypes.FeatureType)
					if component == null:
						exits += 1
						continue
					exits -= 1
					if component.lineage_id not in parents:
						parents.append(component.lineage_id)
						for feature: CurrentFeature in current:
							if feature.lineage_id == component.lineage_id:
								exits += feature.open_exits
				if exits == 0:
					value += 1 if type in seen_types else 10
			if value > best_value:
				best_value = value
				best = PlaceTileCommand.new(tile_id, TileLocationState.Kind.ACTIVE_HAND, option.coordinate, option.rotation)
	return best


func _valid(state: RunState, content: ContentRegistry) -> void:
	var report: InvariantReport = InvariantValidator.validate(state, content)
	expect_true(report.is_valid, report.describe())
