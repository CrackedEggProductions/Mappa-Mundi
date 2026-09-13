extends "res://tests/framework/test_suite.gd"

const TYPE = DomainTypes.FeatureType
const EDGE = DomainTypes.EdgeType
const TRACK = DomainTypes.TrackType


func tests() -> Array[Callable]:
	return [snapshot_owns_nested_input, snapshot_returns_isolated_views,
		settlement_scores_new_components_and_support, settlement_recompletion_scores_only_new_eligibility,
		forest_preservation_repeats_without_repaying_old_tiles, road_scores_tiles_without_network_bonus,
		river_length_rounds_down, river_contact_is_distinct_historical_eligibility,
		river_length_does_not_repay_historical_completion, simultaneous_calculation_is_state_independent,
		monastery_requires_eight_neighbors, monastery_counts_natural_squares_once,
		monastery_completed_stage_does_not_repeat, abbey_scoring_is_deferred,
		same_tile_support_requires_explicit_relationship, support_requires_shared_reachable_socket,
		woodland_river_has_explicit_same_tile_contact, pipeline_child_events_are_fifo,
		pipeline_stages_preserve_canonical_order]


func snapshot_owns_nested_input() -> bool:
	var source: Dictionary = {"rows": [{"values": [1, 2]}]}
	var snapshot: CompletionSnapshot = CompletionSnapshot.new(source)
	source["rows"][0]["values"][0] = 99
	expect_equal(snapshot.data()["rows"][0]["values"], [1, 2], "Capture owns every nested primitive")
	return true


func snapshot_returns_isolated_views() -> bool:
	var snapshot: CompletionSnapshot = CompletionSnapshot.new({"values": [1, 2]})
	var view: Dictionary = snapshot.data()
	view["values"][0] = 99
	expect_equal(snapshot.data()["values"], [1, 2], "Consumers cannot mutate frozen peer state")
	return true


func settlement_scores_new_components_and_support() -> bool:
	var facts: Dictionary = _facts(TYPE.SETTLEMENT, [11, 12])
	facts["new_field_ids"] = [21, 22]
	facts["new_river_ids"] = [21]
	var record: FeatureCompletionRecord = _score(facts)
	expect_equal(record.gains, [7, 0, 0, 0], "Two components plus two Fields and one River category")
	expect_equal(record.settlement_class, 1, "Two tiles establish Hamlet")
	return true


func settlement_recompletion_scores_only_new_eligibility() -> bool:
	var facts: Dictionary = _facts(TYPE.SETTLEMENT, [11, 12, 13])
	facts["first_completion"] = false
	facts["new_component_ids"] = [13]
	facts["field_support_ids"] = [21, 22]
	facts["new_field_ids"] = [22]
	facts["river_support_ids"] = [31]
	facts["new_river_ids"] = []
	expect_equal(_score(facts).gains, [3, 0, 0, 0], "Only new growth and new support pay")
	return true


func forest_preservation_repeats_without_repaying_old_tiles() -> bool:
	var facts: Dictionary = _facts(TYPE.FOREST, [11, 12, 13])
	facts["first_completion"] = false
	facts["new_component_ids"] = [13]
	expect_equal(_score(facts).gains[TRACK.ECOLOGY], 3, "New Forest plus reevaluated flat preservation")
	facts["undeveloped"] = false
	expect_equal(_score(facts).gains[TRACK.ECOLOGY], 1, "Developed snapshot has no preservation")
	return true


func road_scores_tiles_without_network_bonus() -> bool:
	var facts: Dictionary = _facts(TYPE.ROAD, [11, 12, 13])
	facts["first_completion"] = false
	facts["new_component_ids"] = [13]
	facts["settlement_connections"] = [100, 101]
	expect_equal(_score(facts).gains, [0, 1, 0, 0], "Road only pays newly scoring component Trade")
	return true


func river_length_rounds_down() -> bool:
	expect_equal(_score(_facts(TYPE.RIVER, [11, 12, 13])).gains[TRACK.ECOLOGY], 1, "Odd length rounds down")
	expect_equal(_score(_facts(TYPE.RIVER, [11, 12, 13, 14])).gains[TRACK.ECOLOGY], 2, "Even length divides by two")
	return true


func river_contact_is_distinct_historical_eligibility() -> bool:
	var facts: Dictionary = _facts(TYPE.RIVER, [11, 12])
	facts["forest_contact_ids"] = [21, 22]
	facts["new_forest_ids"] = [22]
	expect_equal(_score(facts).gains[TRACK.ECOLOGY], 2, "Length plus only previously unscored Forest contact")
	return true


func river_length_does_not_repay_historical_completion() -> bool:
	var facts: Dictionary = _facts(TYPE.RIVER, [11, 12])
	facts["first_completion"] = false
	facts["new_component_ids"] = []
	expect_equal(_score(facts).gains, [0, 0, 0, 0], "Historical River length is never paid twice")
	return true


func simultaneous_calculation_is_state_independent() -> bool:
	var first: Dictionary = _facts(TYPE.ROAD, [11, 12])
	var second: Dictionary = _facts(TYPE.FOREST, [21, 22])
	second["lineage_id"] = 2
	var data: Dictionary = _data([first, second])
	var snapshot: CompletionSnapshot = CompletionSnapshot.new(data)
	var records: Array[FeatureCompletionRecord] = FeatureScoringService.calculate(snapshot)
	records[0].gains[TRACK.TRADE] = 1000
	data["features"][1]["new_component_ids"] = []
	var repeated: Array[FeatureCompletionRecord] = FeatureScoringService.calculate(snapshot)
	expect_equal(repeated[0].gains[TRACK.TRADE], 2, "First result mutation cannot change snapshot")
	expect_equal(repeated[1].gains[TRACK.ECOLOGY], 4, "Peer uses shared captured history and geography")
	return true


func monastery_requires_eight_neighbors() -> bool:
	var state: RunState = _enclosure_state(7)
	expect_true(EnclosureService.capture(state).is_empty(), "Seven surrounding squares incomplete")
	return true


func monastery_counts_natural_squares_once() -> bool:
	var state: RunState = _enclosure_state(8)
	var captured: Array[Dictionary] = EnclosureService.capture(state)
	expect_equal(captured.size(), 1, "Existing eight neighbors immediately qualify")
	expect_equal(captured[0]["natural_count"], 8, "Mixed Field Forest River square counts once")
	var data: Dictionary = _data([])
	data["enclosures"] = captured
	var scored: Array[FeatureCompletionRecord] = FeatureScoringService.calculate(CompletionSnapshot.new(data))
	expect_equal(scored[0].gains, [0, 0, 13, 0], "Five base plus eight natural squares")
	return true


func monastery_completed_stage_does_not_repeat() -> bool:
	var state: RunState = _enclosure_state(8)
	state.features.enclosures[0].completed_stages.append(&"monastery")
	expect_true(EnclosureService.capture(state).is_empty(), "Completed enclosure stage cannot repeat")
	return true


func abbey_scoring_is_deferred() -> bool:
	var state: RunState = _enclosure_state(8)
	state.features.enclosures[0].stage = &"abbey"
	expect_true(EnclosureService.capture(state).is_empty(), "No unimplemented Abbey gameplay")
	return true


func same_tile_support_requires_explicit_relationship() -> bool:
	var state: RunState = _state()
	var cell: BoardCellState = _cell(Vector2i.ZERO, 10)
	cell.effective_edges = [EDGE.SETTLEMENT, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD]
	state.expansion.board.add_cell(cell)
	var feature: CurrentFeature = _feature(TYPE.SETTLEMENT, Vector2i.ZERO)
	expect_true(FeatureContactService.support_ids(state, feature, EDGE.FIELD).is_empty(), "Contains Field alone does not establish internal contact")
	cell.field_supports_settlement = true
	expect_equal(FeatureContactService.support_ids(state, feature, EDGE.FIELD), [10], "Explicit internal Field support counts")
	return true


func support_requires_shared_reachable_socket() -> bool:
	var state: RunState = _state()
	var center: BoardCellState = _cell(Vector2i.ZERO, 10)
	center.effective_edges = [EDGE.SETTLEMENT, EDGE.ROAD, EDGE.FIELD, EDGE.FIELD]
	center.field_supports_settlement = true
	state.expansion.board.add_cell(center)
	var neighbor: BoardCellState = _cell(Vector2i.RIGHT, 11)
	neighbor.effective_edges = [EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.ROAD]
	state.expansion.board.add_cell(neighbor)
	var feature: CurrentFeature = _feature(TYPE.SETTLEMENT, Vector2i.ZERO)
	expect_equal(FeatureContactService.support_ids(state, feature, EDGE.FIELD), [10], "Road interface does not invent Field contact")
	center.effective_edges[1] = EDGE.FIELD
	neighbor.effective_edges[3] = EDGE.FIELD
	expect_equal(FeatureContactService.support_ids(state, feature, EDGE.FIELD), [10, 11], "Reachable matching Field interface provides support")
	return true


func woodland_river_has_explicit_same_tile_contact() -> bool:
	var state: RunState = _state()
	var definition: TileDefinition = load("res://content/tiles/homestead/woodland_river.tres") as TileDefinition
	state.expansion.board.add_cell(BoardCellState.from_definition(definition, 10, Vector2i.ZERO, 0, 1, 0))
	expect_equal(FeatureContactService.support_ids(state, _feature(TYPE.RIVER, Vector2i.ZERO), EDGE.FOREST), [10], "Woodland River explicitly contributes own Forest cell")
	return true


func pipeline_child_events_are_fifo() -> bool:
	var state: RunState = _state()
	var pipeline: CompletionPipeline = CompletionPipeline.new()
	for id: int in [4, 2, 7]:
		var event: FeatureHistoryRecord = FeatureHistoryRecord.new()
		event.event_id = id
		pipeline.enqueue_child(event)
	expect_true(state.features.history.is_empty(), "Children do not interrupt parent batch")
	pipeline.drain_children(state)
	var ids: Array[int] = []
	for event: FeatureHistoryRecord in state.features.history:
		ids.append(event.event_id)
	expect_equal(ids, [4, 2, 7], "FIFO creation order rather than ID sort")
	return true


func pipeline_stages_preserve_canonical_order() -> bool:
	expect_equal(CompletionPipeline.STAGES, [&"snapshot", &"base_feature_scoring", &"development_effects", &"specialist_effects", &"specialist_returns", &"relic_effects", &"relic_milestones", &"queue_crossed_track_thresholds", &"resolve_threshold_queue"], "Canonical future extension stages are explicit")
	return true


func _facts(type: int, ids: Array[int]) -> Dictionary:
	return {"lineage_id": 1, "feature_type": type, "component_ids": ids,
		"total_size": ids.size(), "first_completion": true, "growth_phase": 1,
		"new_component_ids": ids.duplicate(), "field_support_ids": [], "river_support_ids": [],
		"forest_contact_ids": [], "new_field_ids": [], "new_river_ids": [], "new_forest_ids": [], "undeveloped": true}


func _data(features: Array) -> Dictionary:
	return {"act": 1, "placement_index": 3, "source_id": 100, "features": features, "enclosures": []}


func _score(facts: Dictionary) -> FeatureCompletionRecord:
	return FeatureScoringService.calculate(CompletionSnapshot.new(_data([facts])))[0]


func _state() -> RunState:
	var state: RunState = RunState.new(99)
	state.expansion = ExpansionState.new()
	state.features = FeatureState.new()
	return state


func _cell(at: Vector2i, id: int) -> BoardCellState:
	var cell: BoardCellState = BoardCellState.new()
	cell.coordinate = at
	cell.base_tile_copy_id = id
	cell.effective_edges = [EDGE.FIELD, EDGE.FOREST, EDGE.RIVER, EDGE.FIELD]
	return cell


func _feature(type: DomainTypes.FeatureType, at: Vector2i) -> CurrentFeature:
	var feature: CurrentFeature = CurrentFeature.new()
	feature.feature_type = type
	feature.coordinates = [at]
	return feature


func _enclosure_state(count: int) -> RunState:
	var state: RunState = _state()
	var enclosure: EnclosureState = EnclosureState.new()
	enclosure.enclosure_id = 1
	state.features.enclosures.append(enclosure)
	state.expansion.board.add_cell(_cell(Vector2i.ZERO, 2))
	var added: int = 0
	for x: int in range(-1, 2):
		for y: int in range(-1, 2):
			if (x == 0 and y == 0) or added == count:
				continue
			state.expansion.board.add_cell(_cell(Vector2i(x, y), 3 + added))
			added += 1
	return state
