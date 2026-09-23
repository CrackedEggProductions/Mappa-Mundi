extends "res://tests/framework/test_suite.gd"

const TYPE = DomainTypes.FeatureType
const EDGE = DomainTypes.EdgeType
const TRACK = DomainTypes.TrackType


func tests() -> Array[Callable]:
	return [housing_copies_trigger_independently, mill_multiple_hosts_each_receive_river_bonus, mill_capture_uses_current_orthogonal_contacts,
		market_and_grand_market_multiply_other_settlements, ports_share_frozen_peer_count, capture_ports_uses_specific_river_and_all_peers,
		lodge_scores_ecology, town_square_uses_hosted_family_diversity,
		capture_filters_new_copy_and_trigger_hosts, captured_facts_ignore_later_state_changes,
		development_batch_leaves_base_histories_unchanged, development_events_follow_base_events,
		lodge_preserves_undeveloped_forest, other_development_breaks_forest_preservation,
		completed_enclosure_stages_are_independent, abbey_mixed_neighbors_count_both,
		settlement_completion_records_development_families, enclosure_completion_record_preserves_stage]


func housing_copies_trigger_independently() -> bool:
	var records: Array[Dictionary] = _calculate([_fact("housing", 10), _fact("housing", 11)])
	expect_equal(records.size(), 2, "Every physical Housing triggers")
	expect_equal(records[0]["gains"], [2, 0, 0, 0], "Housing Population")
	expect_equal(records[1]["gains"], [2, 0, 0, 0], "Duplicate Housing Population")
	return true


func mill_multiple_hosts_each_receive_river_bonus() -> bool:
	var first: Dictionary = _fact("mill", 10)
	first["touches_river"] = true
	var second: Dictionary = first.duplicate(true)
	second["lineage_id"] = 2
	var records: Array[Dictionary] = _calculate([first, second])
	expect_equal(records.size(), 2, "One Mill retains two distinct host triggers")
	for record: Dictionary in records:
		expect_equal(record["gains"], [2, 1, 0, 0], "River bonus applies per Settlement")
	first["touches_river"] = false
	expect_equal(_calculate([first])[0]["gains"], [2, 0, 0, 0], "No River gives no Trade")
	return true


func mill_capture_uses_current_orthogonal_contacts() -> bool:
	var state: RunState = _state()
	var mill: DevelopmentState = _overlay(state, "mill", 10, 0, Vector2i.ZERO)
	mill.host_kind = &"field"
	_overlay(state, "housing", 11, 1, Vector2i.RIGHT)
	_overlay(state, "housing", 12, 2, Vector2i.LEFT)
	_overlay(state, "housing", 13, 3, Vector2i.ONE)
	_overlay(state, "foresters_lodge", 14, 4, Vector2i.UP).host_kind = &"forest"
	var current: Array[CurrentFeature] = [_feature(1, TYPE.SETTLEMENT, Vector2i.RIGHT),
		_feature(2, TYPE.SETTLEMENT, Vector2i.LEFT), _feature(3, TYPE.SETTLEMENT, Vector2i.ONE),
		_feature(4, TYPE.RIVER, Vector2i.UP)]
	var facts: Array[Dictionary] = DevelopmentEffects.capture(state, current, [1, 2, 3], 10)
	expect_equal(facts.size(), 2, "Orthogonal Settlements count independently; diagonal does not")
	for fact: Dictionary in facts:
		expect_true(fact["touches_river"], "Current orthogonal River contact captured")
	current[3].coordinates = [Vector2i(2, 2)]
	facts = DevelopmentEffects.capture(state, current, [1, 2, 3], 10)
	for fact: Dictionary in facts:
		expect_true(not fact["touches_river"], "Mill reevaluates River contact dynamically")
	return true


func market_and_grand_market_multiply_other_settlements() -> bool:
	var market: Dictionary = _fact("market", 10)
	market["other_settlements"] = 3
	var grand: Dictionary = market.duplicate(true)
	grand["stage"] = "grand_market"
	expect_equal(_calculate([market])[0]["gains"], [0, 3, 0, 0], "Market full-network peers")
	expect_equal(_calculate([grand])[0]["gains"], [0, 6, 0, 0], "Grand Market doubles peers")
	market["other_settlements"] = 0
	expect_equal(_calculate([market])[0]["gains"], [0, 0, 0, 0], "Host alone scores zero")
	return true


func ports_share_frozen_peer_count() -> bool:
	var first: Dictionary = _fact("port", 10)
	first["other_ports"] = 2
	var second: Dictionary = first.duplicate(true)
	second["copy_id"] = 11
	var state: RunState = _state()
	var pipeline: CompletionPipeline = CompletionPipeline.new()
	DevelopmentEffects.apply(state, _calculate([first, second]), 100, pipeline)
	expect_equal(state.features.tracks.values, [0, 8, 0, 0], "Each Port sees same two peers")
	return true


func capture_ports_uses_specific_river_and_all_peers() -> bool:
	var state: RunState = _state()
	var first: DevelopmentState = _overlay(state, "port", 10, 1, Vector2i.ZERO)
	var second: DevelopmentState = _overlay(state, "port", 11, 2, Vector2i.RIGHT)
	var other: DevelopmentState = _overlay(state, "port", 12, 3, Vector2i(2, 0))
	first.river_lineage_id = 50
	second.river_lineage_id = 50
	other.river_lineage_id = 51
	var current: Array[CurrentFeature] = [_feature(1, TYPE.SETTLEMENT, Vector2i.ZERO), _feature(2, TYPE.SETTLEMENT, Vector2i.RIGHT)]
	var frozen: CompletionSnapshot = CompletionSnapshot.new({"developments": DevelopmentEffects.capture(state, current, [1, 2])})
	other.river_lineage_id = 50
	var calculated: Array[Dictionary] = DevelopmentEffects.calculate(frozen)
	expect_equal(calculated.size(), 2, "Only genuinely completing hosts trigger")
	for effect: Dictionary in calculated:
		expect_equal(effect["gains"][TRACK.TRADE], 3, "Each sees one same-River peer; unrelated River excluded in immutable snapshot")
	return true


func lodge_scores_ecology() -> bool:
	expect_equal(_calculate([_fact("foresters_lodge", 10)])[0]["gains"], [0, 0, 0, 1], "Lodge gives Ecology")
	return true


func town_square_uses_hosted_family_diversity() -> bool:
	var state: RunState = _state()
	_overlay(state, "housing", 10, 1, Vector2i.ZERO)
	_overlay(state, "housing", 11, 1, Vector2i.RIGHT)
	_overlay(state, "market", 12, 1, Vector2i(2, 0))
	var grand: DevelopmentState = _overlay(state, "grand_market", 13, 1, Vector2i(3, 0))
	grand.family_id = &"family.market"
	_overlay(state, "town_square", 14, 1, Vector2i(4, 0))
	var lodge: DevelopmentState = _overlay(state, "foresters_lodge", 15, 1, Vector2i(5, 0))
	lodge.host_kind = &"forest"
	var families: Array[StringName] = DevelopmentService.families(state, 1)
	expect_equal(families, [&"family.housing", &"family.market", &"family.town_square"], "Physical duplicates/upgrades deduplicate; unrelated host excluded")
	var facts: Dictionary = _fact("town_square", 14)
	facts["families"] = families
	expect_equal(_calculate([facts])[0]["gains"], [0, 0, 6, 0], "Includes Town Square itself")
	return true


func capture_filters_new_copy_and_trigger_hosts() -> bool:
	var state: RunState = _state()
	_overlay(state, "housing", 10, 1, Vector2i.ZERO)
	_overlay(state, "housing", 11, 1, Vector2i.RIGHT)
	_overlay(state, "housing", 12, 2, Vector2i(2, 0))
	var current: Array[CurrentFeature] = [_feature(1, TYPE.SETTLEMENT, Vector2i.ZERO), _feature(2, TYPE.SETTLEMENT, Vector2i(2, 0))]
	var facts: Array[Dictionary] = DevelopmentEffects.capture(state, current, [1], 11)
	expect_equal(facts.size(), 1, "Only newly placed copy with qualifying trigger")
	expect_equal(facts[0]["copy_id"], 11, "Old Housing excluded")
	expect_true(DevelopmentEffects.capture(state, current, []).is_empty(), "Topology changes without completion cause no triggers")
	return true


func captured_facts_ignore_later_state_changes() -> bool:
	var state: RunState = _state()
	var square: DevelopmentState = _overlay(state, "town_square", 10, 1, Vector2i.ZERO)
	var current: Array[CurrentFeature] = [_feature(1, TYPE.SETTLEMENT, Vector2i.ZERO)]
	var snapshot: CompletionSnapshot = CompletionSnapshot.new({"developments": DevelopmentEffects.capture(state, current, [1])})
	_overlay(state, "housing", 11, 1, Vector2i.RIGHT)
	square.host_lineage_id = 999
	state.features.tracks.add(TRACK.CULTURE, 100)
	expect_equal(DevelopmentEffects.calculate(snapshot)[0]["gains"], [0, 0, 2, 0], "Later families, hosts and Tracks cannot alter frozen effect")
	return true


func development_batch_leaves_base_histories_unchanged() -> bool:
	var state: RunState = _state()
	var lineage: FeatureLineageState = FeatureLineageState.new()
	lineage.lineage_id = 1
	lineage.scored_component_ids = [100]
	lineage.scored_field_ids = [200]
	state.features.lineages.append(lineage)
	var pipeline: CompletionPipeline = CompletionPipeline.new()
	DevelopmentEffects.apply(state, _calculate([_fact("housing", 10)]), 99, pipeline, true)
	expect_true(state.features.history.is_empty(), "Children remain queued during parent batch")
	pipeline.drain_children(state)
	expect_equal(lineage.scored_component_ids, [100], "Development is not component anti-farming history")
	expect_equal(lineage.scored_field_ids, [200], "Development is not support history")
	expect_true(lineage.completion_ids.is_empty(), "Immediate effect creates no feature completion")
	expect_equal(state.features.history[0].kind, &"development_immediate_effect", "Typed immediate event")
	expect_equal(state.features.history[1].parent_event_id, state.features.history[0].event_id, "Track event identifies its Development trigger")
	return true


func development_events_follow_base_events() -> bool:
	var state: RunState = _state()
	var lineage: FeatureLineageState = FeatureLineageState.new()
	lineage.lineage_id = 1
	lineage.feature_type = TYPE.SETTLEMENT
	state.features.lineages.append(lineage)
	var data: Dictionary = _snapshot_data()
	data["features"] = [_feature_facts()]
	data["developments"] = [_fact("housing", 10), _fact("town_square", 11)]
	FeatureScoringService.apply_snapshot(state, CompletionSnapshot.new(data))
	var kinds: Array[StringName] = []
	for event: FeatureHistoryRecord in state.features.history:
		kinds.append(event.kind)
	expect_equal(kinds, [&"completion_snapshot", &"feature_completed", &"realm_track_changed", &"development_completion_trigger", &"realm_track_changed", &"development_completion_trigger"], "Base children precede Development batch children")
	expect_equal(state.features.tracks.values, [4, 0, 0, 0], "Base + Housing applied once")
	return true


func lodge_preserves_undeveloped_forest() -> bool:
	var state: RunState = _state()
	var feature: CurrentFeature = _feature(1, TYPE.FOREST, Vector2i.ZERO)
	var lodge: DevelopmentState = _overlay(state, "foresters_lodge", 10, 1, Vector2i.ZERO)
	lodge.host_kind = &"forest"
	expect_true(FeatureContactService.forest_is_undeveloped(state, feature), "Lodge light-development exception")
	var facts: Dictionary = _feature_facts()
	facts["feature_type"] = TYPE.FOREST
	facts["undeveloped"] = FeatureContactService.forest_is_undeveloped(state, feature)
	var data: Dictionary = _snapshot_data()
	data["features"] = [facts]
	expect_equal(FeatureScoringService.calculate(CompletionSnapshot.new(data))[0].gains[TRACK.ECOLOGY], 3, "New component plus two preservation")
	return true


func other_development_breaks_forest_preservation() -> bool:
	var state: RunState = _state()
	_overlay(state, "mill", 10, 0, Vector2i.ZERO).host_kind = &"field"
	expect_true(not FeatureContactService.forest_is_undeveloped(state, _feature(1, TYPE.FOREST, Vector2i.ZERO)), "Mill on Forest-containing square makes Forest developed")
	return true


func completed_enclosure_stages_are_independent() -> bool:
	var state: RunState = _enclosure()
	var enclosure: EnclosureState = state.features.enclosures[0]
	enclosure.completed_stages = [&"monastery"]
	expect_true(EnclosureService.capture(state).is_empty(), "Completed Monastery never repeats")
	enclosure.stage = &"abbey"
	expect_equal(EnclosureService.capture(state).size(), 1, "Abbey is a new eligible stage")
	enclosure.completed_stages.append(&"abbey")
	expect_true(EnclosureService.capture(state).is_empty(), "Abbey stage never repeats")
	return true


func abbey_mixed_neighbors_count_both() -> bool:
	var state: RunState = _enclosure()
	state.features.enclosures[0].stage = &"abbey"
	state.expansion.board.get_cell(Vector2i.UP).effective_edges = [EDGE.SETTLEMENT, EDGE.FIELD, EDGE.RIVER, EDGE.FOREST]
	var data: Dictionary = _snapshot_data()
	data["enclosures"] = EnclosureService.capture(state)
	var record: FeatureCompletionRecord = FeatureScoringService.calculate(CompletionSnapshot.new(data))[0]
	expect_equal(record.gains[TRACK.CULTURE], 17, "Eight base + eight natural squares + one Settlement")
	expect_equal(record.natural_neighbor_count, 8, "Multi-natural square only counted once")
	expect_equal(record.settlement_neighbor_count, 1, "Mixed square additionally counts Settlement")
	return true


func settlement_completion_records_development_families() -> bool:
	var data: Dictionary = _snapshot_data()
	var facts: Dictionary = _feature_facts()
	facts["total_size"] = 9
	facts["development_families"] = [&"family.housing", &"family.market"]
	data["features"] = [facts]
	var record: FeatureCompletionRecord = FeatureScoringService.calculate(CompletionSnapshot.new(data))[0]
	expect_equal(record.settlement_class, 4, "Nine tiles and two hosted families qualifies City")
	expect_equal(record.development_families, facts["development_families"], "Historical family snapshot retained")
	return true


func enclosure_completion_record_preserves_stage() -> bool:
	var state: RunState = _enclosure()
	var data: Dictionary = _snapshot_data()
	data["enclosures"] = EnclosureService.capture(state)
	FeatureScoringService.apply_snapshot(state, CompletionSnapshot.new(data), 500)
	expect_equal(state.features.completions[0].enclosure_stage, &"monastery", "Record identifies completed stage")
	expect_equal(state.features.enclosures[0].completed_stages, [&"monastery"], "Authoritative enclosure marks stage")
	expect_equal(state.features.history[0].parent_event_id, 500, "Immediate enclosure snapshot retains placement parent")
	return true


func _fact(stage: String, copy_id: int) -> Dictionary:
	return {"stage": stage, "copy_id": copy_id, "lineage_id": 1, "feature_type": TYPE.SETTLEMENT,
		"other_settlements": 0, "other_ports": 0, "touches_river": false, "families": []}


func _calculate(facts: Array) -> Array[Dictionary]:
	return DevelopmentEffects.calculate(CompletionSnapshot.new({"developments": facts}))


func _state() -> RunState:
	var state: RunState = RunState.new(123)
	state.expansion = ExpansionState.new()
	state.features = FeatureState.new()
	return state


func _overlay(state: RunState, stage: String, copy_id: int, host_id: int, at: Vector2i) -> DevelopmentState:
	var cell: BoardCellState = BoardCellState.new()
	cell.coordinate = at
	cell.base_tile_copy_id = copy_id + 1000
	cell.effective_edges = [EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD]
	cell.has_field_geography = true
	var development: DevelopmentState = DevelopmentState.new()
	development.stage = StringName(stage)
	development.family_id = StringName("family." + stage)
	development.tile_copy_id = copy_id
	development.host_kind = &"settlement"
	development.host_lineage_id = host_id
	cell.developments.append(development)
	state.expansion.board.add_cell(cell)
	return development


func _feature(id: int, type: int, at: Vector2i) -> CurrentFeature:
	var feature: CurrentFeature = CurrentFeature.new()
	feature.lineage_id = id
	feature.feature_type = type
	feature.coordinates = [at]
	return feature


func _feature_facts() -> Dictionary:
	return {"lineage_id": 1, "feature_type": TYPE.SETTLEMENT, "total_size": 1, "first_completion": true,
		"growth_phase": 1, "component_ids": [100], "new_component_ids": [100], "field_support_ids": [],
		"river_support_ids": [], "forest_contact_ids": [], "new_field_ids": [], "new_river_ids": [], "new_forest_ids": [], "undeveloped": true}


func _snapshot_data() -> Dictionary:
	return {"act": 1, "placement_index": 1, "source_id": 10, "features": [], "enclosures": [], "developments": []}


func _enclosure() -> RunState:
	var state: RunState = _state()
	for x: int in range(-1, 2):
		for y: int in range(-1, 2):
			var cell: BoardCellState = BoardCellState.new()
			cell.coordinate = Vector2i(x, y)
			cell.effective_edges = [EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD]
			cell.has_field_geography = true
			state.expansion.board.add_cell(cell)
	var enclosure: EnclosureState = EnclosureState.new()
	enclosure.enclosure_id = state.id_allocator.allocate()
	enclosure.coordinate = Vector2i.ZERO
	state.features.enclosures.append(enclosure)
	return state
