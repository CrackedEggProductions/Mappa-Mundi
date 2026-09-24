extends "res://tests/framework/test_suite.gd"

const Graph = preload("res://tests/fixtures/topology_fixture.gd")
const TYPE = DomainTypes.FeatureType
const EDGE = DomainTypes.EdgeType


func tests() -> Array[Callable]:
	return [city_suppression_keeps_new_elements_unpaid, city_recompletion_can_pay_previously_suppressed,
		city_doubles_only_base_population, city_largest_snapshot_ignores_batch_order,
		long_road_suppression_keeps_connections_unpaid, long_road_doubles_base_not_merchant_or_historic,
		longest_record_exists_before_relic, long_road_batch_uses_prior_record,
		green_recompletion_full_size_no_base_history, historic_recompletion_current_old_components]


func _state() -> RunState:
	var state: RunState = Graph.empty()
	state.expansion.current_act = 3
	state.relics = RelicState.new()
	state.relics.current_act = 3
	state.relics.capacity = 5
	state.rewards = RewardState.new()
	return state


func _equip(state: RunState, id: StringName) -> void:
	var registry: ContentRegistry = ContentRegistry.new()
	assert(registry.load_phase_eight().is_valid)
	assert(RelicRules.acquire(state, registry, id).is_valid)


func _settlements() -> RunState:
	var state: RunState = _state()
	Graph.add(state, Vector2i.ZERO, [0, 4, 0, 0])
	Graph.add(state, Vector2i.RIGHT, [0, 0, 0, 4])
	for x: int in [10, 11, 12]:
		Graph.add(state, Vector2i(x, 0), [4, 4, 4, 4])
	Graph.reconcile(state)
	return state


func city_suppression_keeps_new_elements_unpaid() -> bool:
	var state: RunState = _settlements()
	_equip(state, RelicRules.CITY)
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	var lineage: FeatureLineageState = state.features.lineage(state.features.component_at(Vector2i.ZERO, TYPE.SETTLEMENT).lineage_id)
	expect_true(lineage.completed, "Suppressed feature still genuinely completes")
	expect_equal(state.features.tracks.values[0], 0, "Smaller feature receives no base Population")
	expect_true(lineage.scored_component_ids.is_empty(), "No payout means not historically paid")
	expect_equal(state.features.completions[0].new_component_ids.size(), 2, "Audit retains suppressed eligible facts")
	expect_equal(state.features.completions[0].base_multiplier, 0, "Audit records explicit suppression")
	return true


func city_recompletion_can_pay_previously_suppressed() -> bool:
	var state: RunState = _settlements()
	_equip(state, RelicRules.CITY)
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	Graph.set_geometry(state.expansion.board.get_cell(Vector2i.ZERO), [4, 4, 0, 0])
	Graph.reconcile(state)
	Graph.add(state, Vector2i.UP, [0, 0, 4, 0])
	Graph.reconcile(state)
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	expect_equal(state.features.completions.size(), 2, "Genuine reopened feature completes again")
	expect_equal(state.features.tracks.values[0], 12, "All three unpaid tiles now qualify and pay doubled base")
	expect_equal(state.features.completions[1].new_component_ids.size(), 3, "Suppressed old components were never paid")
	return true


func city_doubles_only_base_population() -> bool:
	var data: Dictionary = _facts(TYPE.SETTLEMENT, 2)
	data["relics"] = _legacy(RelicRules.CITY, 2)
	data["developments"] = [{"copy_id": 20, "stage": "housing", "lineage_id": 1, "feature_type": TYPE.SETTLEMENT},
		{"copy_id": 21, "stage": "mill", "lineage_id": 1, "feature_type": TYPE.SETTLEMENT, "touches_river": false}]
	data["specialists"] = [{"piece_id": 22, "role_definition_id": "specialist.homesteader", "target_id": 1,
		"target_type": TYPE.SETTLEMENT, "field_count": 3}]
	var snapshot: CompletionSnapshot = CompletionSnapshot.new(data)
	expect_equal(FeatureScoringService.calculate(snapshot)[0].gains[0], 8, "Two new Settlement tiles doubled")
	for effect: Dictionary in DevelopmentEffects.calculate(snapshot):
		expect_equal(effect["gains"][0], 2, "Housing and Mill remain +2 each")
	expect_equal(SpecialistRules.calculate(snapshot)[0]["gains"][0], 3, "Homesteader remains unmultiplied")
	return true


func city_largest_snapshot_ignores_batch_order() -> bool:
	var data: Dictionary = _facts(TYPE.SETTLEMENT, 2)
	var second: Dictionary = data["features"][0].duplicate(true)
	second["lineage_id"] = 2
	second["total_size"] = 3
	second["component_ids"] = [10, 11, 12]
	second["new_component_ids"] = [10, 11, 12]
	data["features"].append(second)
	data["relics"] = _legacy(RelicRules.CITY, 3)
	var records: Array[FeatureCompletionRecord] = FeatureScoringService.calculate(CompletionSnapshot.new(data))
	expect_equal([records[0].gains[0], records[1].gains[0]], [0, 12], "Shared largest snapshot applies to simultaneous completions")
	data["features"].reverse()
	records = FeatureScoringService.calculate(CompletionSnapshot.new(data))
	expect_equal([records[0].gains[0], records[1].gains[0]], [12, 0], "Reversed batch iteration changes no payout")
	return true


func long_road_suppression_keeps_connections_unpaid() -> bool:
	var state: RunState = _state()
	Graph.add(state, Vector2i.ZERO, [0, 3, 0, 0])
	Graph.add(state, Vector2i.RIGHT, [0, 0, 0, 3])
	Graph.reconcile(state)
	state.features.largest_completed_sizes[TYPE.ROAD] = 3
	_equip(state, RelicRules.LONG_ROAD)
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	var lineage: FeatureLineageState = state.features.lineage(state.features.component_at(Vector2i.ZERO, TYPE.ROAD).lineage_id)
	expect_true(lineage.scored_component_ids.is_empty(), "Suppressed Road tiles remain unpaid")
	var data: Dictionary = _facts(TYPE.ROAD, 2)
	data["features"][0]["network_settlement_ids"] = [20, 21]
	data["features"][0]["new_settlement_ids"] = [20, 21]
	data["relics"] = _legacy(RelicRules.LONG_ROAD, 3)
	var record: FeatureCompletionRecord = FeatureScoringService.calculate(CompletionSnapshot.new(data))[0]
	expect_equal(record.gains[1], 0, "Both tiles and Settlement connection base are suppressed")
	expect_equal(record.new_settlement_ids, [20, 21], "Suppressed eligible connection facts remain auditable")
	return true


func long_road_doubles_base_not_merchant_or_historic() -> bool:
	var data: Dictionary = _facts(TYPE.ROAD, 3)
	data["features"][0]["network_settlement_ids"] = [20, 21]
	data["features"][0]["new_settlement_ids"] = [20, 21]
	data["relics"] = _legacy(RelicRules.LONG_ROAD, 3)
	data["relics"]["equipped"].append({"runtime_id": 10, "definition_id": String(RelicRules.HISTORIC), "acquisition_order": 2})
	data["relics"]["feature_facts"] = {"1": {"act_one_road_count": 2, "natural_contact": false}}
	data["specialists"] = [{"piece_id": 22, "role_definition_id": "specialist.merchant", "target_id": 1,
		"target_type": TYPE.ROAD, "network_settlement_count": 2}]
	var snapshot: CompletionSnapshot = CompletionSnapshot.new(data)
	expect_equal(FeatureScoringService.calculate(snapshot)[0].gains[1], 14, "Three new Road tiles and two new connections double")
	expect_equal(SpecialistRules.calculate(snapshot)[0]["gains"][1], 2, "Merchant not doubled")
	expect_equal(RelicRules.calculate(snapshot)[0]["gains"][2], 2, "Historic Routes not doubled")
	return true


func longest_record_exists_before_relic() -> bool:
	var state: RunState = _state()
	Graph.add(state, Vector2i.ZERO, [0, 3, 0, 0])
	Graph.add(state, Vector2i.RIGHT, [0, 0, 0, 3])
	Graph.reconcile(state)
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	expect_equal(state.features.largest_completed_sizes[TYPE.ROAD], 2, "Record tracks completions before Relic exists")
	_equip(state, RelicRules.LONG_ROAD)
	expect_equal(state.features.largest_completed_sizes[TYPE.ROAD], 2, "Acquisition preserves historical record")
	return true


func long_road_batch_uses_prior_record() -> bool:
	var data: Dictionary = _facts(TYPE.ROAD, 3)
	var second: Dictionary = data["features"][0].duplicate(true)
	second["lineage_id"] = 2
	second["total_size"] = 5
	second["component_ids"] = [10, 11, 12, 13, 14]
	second["new_component_ids"] = [10, 11, 12, 13, 14]
	data["features"].append(second)
	data["relics"] = _legacy(RelicRules.LONG_ROAD, 3)
	var records: Array[FeatureCompletionRecord] = FeatureScoringService.calculate(CompletionSnapshot.new(data))
	expect_equal([records[0].gains[1], records[1].gains[1]], [6, 10], "Both compare record from before batch")
	data["features"].reverse()
	records = FeatureScoringService.calculate(CompletionSnapshot.new(data))
	expect_equal([records[0].gains[1], records[1].gains[1]], [10, 6], "Larger-first iteration cannot suppress tied prior-record Road")
	return true


func green_recompletion_full_size_no_base_history() -> bool:
	var state: RunState = _settlements()
	state.expansion.board.get_cell(Vector2i.ZERO).field_supports_settlement = true
	_equip(state, RelicRules.GREEN)
	var first: CompletionSnapshot = FeatureScoringService.capture(state, TopologyService.rebuild(state))
	var lineage: FeatureLineageState = state.features.lineage(state.features.component_at(Vector2i.ZERO, TYPE.SETTLEMENT).lineage_id)
	var pipeline: CompletionPipeline = CompletionPipeline.new()
	RelicRules.apply(state, RelicRules.calculate(first), 0, pipeline)
	pipeline.drain_children(state)
	expect_true(lineage.scored_component_ids.is_empty(), "Relic bonus does not mark base history")
	expect_equal(state.features.tracks.values[2], 2, "Current two-tile size Culture")
	RelicRules.apply(state, RelicRules.calculate(first), 0, pipeline)
	pipeline.drain_children(state)
	expect_equal(state.features.tracks.values[2], 4, "Same current facts on a later genuine completion can pay again")
	return true


func historic_recompletion_current_old_components() -> bool:
	var state: RunState = _state()
	Graph.add(state, Vector2i.ZERO, [0, 3, 0, 0])
	Graph.add(state, Vector2i.RIGHT, [0, 0, 0, 3])
	for component: FeatureComponentState in state.features.components:
		component.origin_act = 1
	Graph.reconcile(state)
	_equip(state, RelicRules.HISTORIC)
	var snapshot: CompletionSnapshot = FeatureScoringService.capture(state, TopologyService.rebuild(state))
	var pipeline: CompletionPipeline = CompletionPipeline.new()
	RelicRules.apply(state, RelicRules.calculate(snapshot), 0, pipeline)
	pipeline.drain_children(state)
	RelicRules.apply(state, RelicRules.calculate(snapshot), 0, pipeline)
	pipeline.drain_children(state)
	expect_equal(state.features.tracks.values[2], 4, "Full current Act I components are not consumed by Relic history")
	return true


func _legacy(id: StringName, size: int) -> Dictionary:
	return {"equipped": [{"runtime_id": 9, "definition_id": String(id), "acquisition_order": 1}],
		"largest_settlement_size": size, "prior_longest_road": size, "feature_facts": {}}


func _facts(type: int, size: int) -> Dictionary:
	var components: Array[int] = []
	for index: int in range(size):
		components.append(index + 3)
	return {"act": 3, "placement_index": 1, "source_id": 2, "enclosures": [], "features": [
		{"lineage_id": 1, "feature_type": type, "total_size": size, "component_ids": components,
		 "new_component_ids": components.duplicate(), "first_completion": true, "growth_phase": 0,
		 "highest_settlement_class": 0, "development_families": [], "field_support_ids": [],
		 "river_support_ids": [], "forest_contact_ids": [], "new_field_ids": [], "new_river_ids": [],
		 "new_forest_ids": [], "network_settlement_ids": [], "new_settlement_ids": [], "undeveloped": true}]}
