extends "res://tests/framework/test_suite.gd"

const Graph = preload("res://tests/fixtures/topology_fixture.gd")
const TYPE = DomainTypes.FeatureType
const EDGE = DomainTypes.EdgeType


func tests() -> Array[Callable]:
	return [empty_start_capacity, act_capacity_refresh, mid_act_use, spent_use_does_not_stack,
		invalid_use_atomic, act_tier_pools, frozen_eligibility_pool, acquisition_exhausts,
		equip_uses_empty_slots, full_capacity_requires_choice, replacement_exhausts_both,
		unknown_locked_repeat_acquisition_atomic, unnecessary_replacement_atomic,
		decline_does_not_exhaust, satchel_occupied_blocks_removal, mixed_use_blocks_removal,
		equipped_order_stable, precedence_prohibition, precedence_specificity,
		precedence_acquisition_tie, precedence_input_order_independent,
		green_field_contact, green_forest_contact, green_river_contact,
		green_no_contact, green_full_current_size, green_immutable_snapshot,
		historic_act_one_no_bonus, historic_later_acts, historic_component_age,
		city_largest_and_ties, city_smaller_suppressed, long_road_prior_record,
		legacy_modifiers_do_not_modify_relic_bonus, numeric_effects_fifo,
		acquisition_never_retroactive, capture_does_not_consume_rng,
		refresh_does_not_reacquire_or_restore_removed]


func _registry() -> ContentRegistry:
	var registry: ContentRegistry = ContentRegistry.new()
	assert(registry.load_phase_eight().is_valid)
	return registry


func _state(act: int = 1) -> RunState:
	var state: RunState = Graph.empty()
	state.relics = RelicState.new()
	state.rewards = RewardState.new()
	state.expansion.current_act = act
	state.relics.current_act = act
	state.relics.capacity = RelicRules.capacity_for_act(act)
	return state


func _equip(state: RunState, id: StringName, replace_id: StringName = &"") -> void:
	var result: ValidationResult = RelicRules.acquire(state, _registry(), id, replace_id)
	assert(result.is_valid, result.user_message)


func _proof(state: RunState) -> String:
	var instances: Array = []
	for instance: RelicInstanceState in state.relics.instances:
		instances.append([instance.runtime_id, instance.definition_id, instance.equipped_slot,
			instance.uses_remaining, instance.use_act, instance.removed_act])
	return str([instances, state.relics.history, state.next_runtime_id, state.current_rng_state, state.rng.operation_count])


func empty_start_capacity() -> bool:
	var state: RunState = _state()
	expect_equal(state.relics.capacity, 2, "Act I capacity")
	expect_true(RelicRules.equipped(state).is_empty(), "No free starting Relic")
	return true


func act_capacity_refresh() -> bool:
	var state: RunState = _state()
	for act: int in [2, 3]:
		state.expansion.current_act = act
		expect_true(RelicRules.refresh_act(state, act).is_valid, "Act-start hook")
		expect_equal(state.relics.capacity, 4 if act == 2 else 5, "Canonical capacity")
		expect_true(RelicRules.equipped(state).is_empty(), "Capacity does not grant Relics")
	return true


func mid_act_use() -> bool:
	var state: RunState = _state()
	state.expansion.normal_placements = 9
	_equip(state, RelicRules.BOUNDARY)
	expect_true(RelicRules.use_available(state, RelicRules.BOUNDARY), "Mid-Act acquisition grants current use")
	return true


func spent_use_does_not_stack() -> bool:
	var state: RunState = _state()
	_equip(state, RelicRules.BOUNDARY)
	expect_true(RelicRules.consume_use(state, RelicRules.BOUNDARY).is_valid, "Consume exactly once")
	RelicRules.refresh_act(state, 1)
	expect_true(not RelicRules.use_available(state, RelicRules.BOUNDARY), "Repeated same-Act hook cannot recharge")
	state.expansion.current_act = 2
	RelicRules.refresh_act(state, 2)
	expect_equal(RelicRules.find(state, RelicRules.BOUNDARY).uses_remaining, 1, "Next Act restores one")
	state.expansion.current_act = 3
	RelicRules.refresh_act(state, 3)
	expect_equal(RelicRules.find(state, RelicRules.BOUNDARY).uses_remaining, 1, "Unused use never stacks")
	return true


func invalid_use_atomic() -> bool:
	var state: RunState = _state()
	var before: String = _proof(state)
	expect_true(not RelicRules.consume_use(state, RelicRules.BOUNDARY).is_valid, "Cannot consume unowned Relic")
	expect_equal(_proof(state), before, "Invalid use has no state/ID/RNG effects")
	return true


func act_tier_pools() -> bool:
	for act: int in range(1, 4):
		var state: RunState = _state(act)
		expect_equal(RelicRules.eligible_ids(state, _registry()).size(), [5, 8, 10][act - 1], "Cumulative exact alpha tiers")
	return true


func frozen_eligibility_pool() -> bool:
	var state: RunState = _state(3)
	expect_equal(RelicRules.eligible_ids(state, _registry(), 1).size(), 5, "Outgoing Act pool remains frozen")
	return true


func acquisition_exhausts() -> bool:
	var state: RunState = _state()
	_equip(state, RelicRules.GREEN)
	expect_true(RelicRules.GREEN not in RelicRules.eligible_ids(state, _registry()), "Acquired excluded permanently")
	return true


func equip_uses_empty_slots() -> bool:
	var state: RunState = _state()
	_equip(state, RelicRules.GREEN)
	_equip(state, RelicRules.SATCHEL)
	expect_equal(RelicRules.find(state, RelicRules.GREEN).equipped_slot, 0, "First empty slot")
	expect_equal(RelicRules.find(state, RelicRules.SATCHEL).equipped_slot, 1, "Second empty slot")
	return true


func full_capacity_requires_choice() -> bool:
	var state: RunState = _state()
	_equip(state, RelicRules.GREEN)
	_equip(state, RelicRules.SATCHEL)
	var before: String = _proof(state)
	expect_true(not RelicRules.acquire(state, _registry(), RelicRules.BOUNDARY).is_valid, "Full inventory requires explicit replacement")
	expect_equal(_proof(state), before, "No speculative acquisition")
	return true


func replacement_exhausts_both() -> bool:
	var state: RunState = _state()
	_equip(state, RelicRules.GREEN)
	_equip(state, RelicRules.SATCHEL)
	_equip(state, RelicRules.BOUNDARY, RelicRules.GREEN)
	expect_equal(RelicRules.equipped(state).size(), 2, "No inactive inventory")
	expect_true(not RelicRules.active(state, RelicRules.GREEN), "Old ongoing effect immediately ends")
	expect_equal(RelicRules.find(state, RelicRules.BOUNDARY).equipped_slot, 0, "Replacement uses old slot")
	var pool: Array[StringName] = RelicRules.eligible_ids(state, _registry())
	expect_true(RelicRules.GREEN not in pool and RelicRules.BOUNDARY not in pool, "Both are exhausted")
	return true


func unknown_locked_repeat_acquisition_atomic() -> bool:
	var state: RunState = _state()
	_equip(state, RelicRules.GREEN)
	for id: StringName in [&"relic.unknown", RelicRules.CITY, RelicRules.GREEN]:
		var before: String = _proof(state)
		expect_true(not RelicRules.acquire(state, _registry(), id).is_valid, "Invalid acquisition rejected")
		expect_equal(_proof(state), before, "No invalid side effects")
	return true


func unnecessary_replacement_atomic() -> bool:
	var state: RunState = _state()
	_equip(state, RelicRules.GREEN)
	var before: String = _proof(state)
	expect_true(not RelicRules.acquire(state, _registry(), RelicRules.SATCHEL, RelicRules.GREEN).is_valid, "Empty slot used before replacement")
	expect_equal(_proof(state), before, "Unnecessary replacement atomic")
	return true


func decline_does_not_exhaust() -> bool:
	var state: RunState = _state()
	RelicRules.record(state, &"relic_declined", {"definition_id": String(RelicRules.GREEN)})
	expect_true(RelicRules.GREEN in RelicRules.eligible_ids(state, _registry()), "Declined/unselected remains eligible")
	return true


func satchel_occupied_blocks_removal() -> bool:
	var state: RunState = _state()
	_equip(state, RelicRules.SATCHEL)
	_equip(state, RelicRules.GREEN)
	state.expansion.reserve_extra_id = 42
	var before: String = _proof(state)
	expect_true(not RelicRules.acquire(state, _registry(), RelicRules.BOUNDARY, RelicRules.SATCHEL).is_valid, "Cannot strand second Reserve tile")
	expect_equal(_proof(state), before, "Rejected replacement has no effects")
	state.expansion.reserve_extra_id = 0
	expect_true(RelicRules.removal_validation(state, _registry(), RelicRules.SATCHEL).is_valid, "Empty extra slot removable")
	return true


func mixed_use_blocks_removal() -> bool:
	var state: RunState = _state(2)
	_equip(state, RelicRules.MIXED)
	var cell: BoardCellState = Graph.add(state, Vector2i.ZERO, [4, 0, 0, 0])
	for family: StringName in [&"family.housing", &"family.market"]:
		var development: DevelopmentState = DevelopmentState.new()
		development.family_id = family
		cell.developments.append(development)
	expect_true(not RelicRules.removal_validation(state, _registry(), RelicRules.MIXED).is_valid, "Dependent Housing/Grand Market blocks removal")
	cell.developments.pop_back()
	expect_true(RelicRules.removal_validation(state, _registry(), RelicRules.MIXED).is_valid, "No coexistence dependency after removing second family")
	return true


func equipped_order_stable() -> bool:
	var state: RunState = _state(2)
	_equip(state, RelicRules.HISTORIC)
	_equip(state, RelicRules.GREEN)
	state.relics.instances.reverse()
	expect_equal(RelicRules.equipped(state)[0].definition_id, RelicRules.HISTORIC, "Acquisition order independent of storage iteration")
	return true


func precedence_prohibition() -> bool:
	var winner: Dictionary = RelicRules.precedence([
		{"rule_id": "permission", "specificity": 9, "acquisition_order": 9},
		{"rule_id": "prohibition", "prohibition": true, "specificity": 1, "acquisition_order": 1}])
	expect_equal(winner["rule_id"], "prohibition", "Explicit prohibition beats permission")
	return true


func precedence_specificity() -> bool:
	var winner: Dictionary = RelicRules.precedence([
		{"rule_id": "general", "specificity": 1, "acquisition_order": 9},
		{"rule_id": "specific", "specificity": 2, "acquisition_order": 1}])
	expect_equal(winner["rule_id"], "specific", "Specific beats general")
	return true


func precedence_acquisition_tie() -> bool:
	var winner: Dictionary = RelicRules.precedence([
		{"rule_id": "old", "specificity": 2, "acquisition_order": 1},
		{"rule_id": "new", "specificity": 2, "acquisition_order": 2}])
	expect_equal(winner["rule_id"], "new", "Later acquisition wins true tie")
	return true


func precedence_input_order_independent() -> bool:
	var rules: Array[Dictionary] = [{"rule_id": "a", "specificity": 1}, {"rule_id": "b", "specificity": 2}]
	var first: Dictionary = RelicRules.precedence(rules)
	rules.reverse()
	expect_equal(RelicRules.precedence(rules), first, "Dictionary/list insertion cannot decide precedence")
	return true


func _green(edge: int) -> Array[Dictionary]:
	var state: RunState = _state()
	_equip(state, RelicRules.GREEN)
	Graph.add(state, Vector2i.ZERO, [4, 0, 4, 4])
	Graph.add(state, Vector2i.RIGHT, [edge, edge, edge, 0])
	var current: Array[CurrentFeature] = Graph.reconcile(state)
	var settlement: CurrentFeature = SpecialistRules.find_feature(current, state.features.component_at(Vector2i.ZERO, TYPE.SETTLEMENT).lineage_id)
	return RelicRules.calculate(_snapshot(state, current, [{"lineage_id": settlement.lineage_id, "feature_type": TYPE.SETTLEMENT, "total_size": 1}]))


func green_field_contact() -> bool:
	expect_equal(_green(EDGE.FIELD)[0]["gains"], [0, 0, 1, 0], "Field alone qualifies")
	return true


func green_forest_contact() -> bool:
	expect_equal(_green(EDGE.FOREST)[0]["gains"], [0, 0, 1, 0], "Forest alone qualifies")
	return true


func green_river_contact() -> bool:
	expect_equal(_green(EDGE.RIVER)[0]["gains"], [0, 0, 1, 0], "River alone qualifies")
	return true


func green_no_contact() -> bool:
	var snapshot: CompletionSnapshot = _numeric_snapshot(RelicRules.GREEN, TYPE.SETTLEMENT, 5, false)
	expect_true(RelicRules.calculate(snapshot).is_empty(), "No exterior natural contact gives no Culture")
	return true


func green_full_current_size() -> bool:
	var snapshot: CompletionSnapshot = _numeric_snapshot(RelicRules.GREEN, TYPE.SETTLEMENT, 9, true)
	expect_equal(RelicRules.calculate(snapshot)[0]["gains"], [0, 0, 9, 0], "Full current size, not unpaid size, scores each genuine completion")
	return true


func green_immutable_snapshot() -> bool:
	var snapshot: CompletionSnapshot = _numeric_snapshot(RelicRules.GREEN, TYPE.SETTLEMENT, 4, true)
	var copy: Dictionary = snapshot.data()
	copy["relics"]["feature_facts"]["1"]["natural_contact"] = false
	expect_equal(RelicRules.calculate(snapshot)[0]["gains"][2], 4, "Frozen contact unaffected by later changes")
	return true


func historic_act_one_no_bonus() -> bool:
	var snapshot: CompletionSnapshot = _numeric_snapshot(RelicRules.HISTORIC, TYPE.ROAD, 6, false, 1, 4)
	expect_true(RelicRules.calculate(snapshot).is_empty(), "Act I completion does not trigger Historic Routes")
	return true


func historic_later_acts() -> bool:
	for act: int in [2, 3]:
		var snapshot: CompletionSnapshot = _numeric_snapshot(RelicRules.HISTORIC, TYPE.ROAD, 6, false, act, 4)
		expect_equal(RelicRules.calculate(snapshot)[0]["gains"][2], 4, "Act II/III counts all current Act I Road tiles")
	return true


func historic_component_age() -> bool:
	var state: RunState = _state(2)
	_equip(state, RelicRules.HISTORIC)
	Graph.add(state, Vector2i.ZERO, [3, 3, 3, 0])
	Graph.add(state, Vector2i.RIGHT, [0, 3, 0, 3])
	state.expansion.board.get_cell(Vector2i.ZERO).act_placed = 1
	state.features.component_at(Vector2i.RIGHT, TYPE.ROAD).origin_act = 1
	var current: Array[CurrentFeature] = Graph.reconcile(state)
	var road: CurrentFeature = current[0]
	var snapshot: CompletionSnapshot = _snapshot(state, current, [{"lineage_id": road.lineage_id, "feature_type": TYPE.ROAD, "total_size": 2}])
	expect_equal(RelicRules.calculate(snapshot)[0]["gains"][2], 1, "Later transformed Road on old square does not become Act I")
	return true


func city_largest_and_ties() -> bool:
	var snapshot: CompletionSnapshot = _numeric_snapshot(RelicRules.CITY, TYPE.SETTLEMENT, 8)
	for id: int in [1, 2]:
		expect_equal(RelicRules.base_multiplier(snapshot, {"lineage_id": id, "feature_type": TYPE.SETTLEMENT, "total_size": 8}), 2, "All currently largest ties qualify")
	return true


func city_smaller_suppressed() -> bool:
	var snapshot: CompletionSnapshot = _numeric_snapshot(RelicRules.CITY, TYPE.SETTLEMENT, 8)
	expect_equal(RelicRules.base_multiplier(snapshot, {"feature_type": TYPE.SETTLEMENT, "total_size": 7}), 0, "Smaller base Population suppressed")
	expect_equal(RelicRules.base_multiplier(snapshot, {"feature_type": TYPE.FOREST, "total_size": 1}), 1, "Other feature base scoring unaffected")
	return true


func long_road_prior_record() -> bool:
	var snapshot: CompletionSnapshot = _numeric_snapshot(RelicRules.LONG_ROAD, TYPE.ROAD, 8)
	for size: int in [7, 8, 9]:
		expect_equal(RelicRules.base_multiplier(snapshot, {"feature_type": TYPE.ROAD, "total_size": size}), 0 if size < 8 else 2, "Compare immutable previous record, ties qualify")
	return true


func legacy_modifiers_do_not_modify_relic_bonus() -> bool:
	var data: Dictionary = _numeric_snapshot(RelicRules.GREEN, TYPE.SETTLEMENT, 4, true).data()
	data["relics"]["equipped"].append({"runtime_id": 3, "definition_id": String(RelicRules.CITY), "acquisition_order": 2})
	data["relics"]["largest_settlement_size"] = 8
	var snapshot: CompletionSnapshot = CompletionSnapshot.new(data)
	expect_equal(RelicRules.base_multiplier(snapshot, data["features"][0]), 0, "Smaller city base suppressed")
	expect_equal(RelicRules.calculate(snapshot)[0]["gains"][2], 4, "Village Green still scores unmultiplied full size")
	return true


func numeric_effects_fifo() -> bool:
	var state: RunState = _state(2)
	_equip(state, RelicRules.HISTORIC)
	_equip(state, RelicRules.GREEN)
	var effects: Array[Dictionary] = [
		{"runtime_id": RelicRules.find(state, RelicRules.HISTORIC).runtime_id,
		 "definition_id": String(RelicRules.HISTORIC), "target_id": 20, "target_type": TYPE.ROAD, "gains": [0, 0, 3, 0]},
		{"runtime_id": RelicRules.find(state, RelicRules.GREEN).runtime_id,
		 "definition_id": String(RelicRules.GREEN), "target_id": 21, "target_type": TYPE.SETTLEMENT, "gains": [0, 0, 4, 0]}]
	var pipeline: CompletionPipeline = CompletionPipeline.new()
	RelicRules.apply(state, effects, 10, pipeline)
	expect_equal(state.features.tracks.values, [0, 0, 7, 0], "Numeric effects apply together from precalculated amounts")
	expect_true(state.features.history.is_empty(), "Child events do not interrupt the active batch")
	pipeline.drain_children(state)
	expect_equal(state.features.history.size(), 4, "FIFO trigger/change pairs")
	expect_equal(state.features.history[0].source_id, effects[0]["runtime_id"], "Oldest acquisition first")
	expect_equal(state.features.history[2].source_id, effects[1]["runtime_id"], "Second effect retains order")
	return true


func acquisition_never_retroactive() -> bool:
	var state: RunState = _state()
	var snapshot: CompletionSnapshot = _snapshot(state, [], [{"lineage_id": 1, "feature_type": TYPE.SETTLEMENT, "total_size": 8}])
	_equip(state, RelicRules.GREEN)
	expect_true(RelicRules.calculate(snapshot).is_empty(), "New acquisition cannot alter an earlier snapshot")
	expect_equal(state.features.tracks.values, [0, 0, 0, 0], "Acquisition causes no scoring")
	return true


func capture_does_not_consume_rng() -> bool:
	var state: RunState = _state()
	_equip(state, RelicRules.GREEN)
	var before: String = _proof(state)
	RelicRules.capture(state, [])
	RelicRules.eligible_ids(state, _registry())
	RelicRules.removal_validation(state, _registry(), RelicRules.GREEN)
	expect_equal(_proof(state), before, "Queries allocate nothing and consume no RNG")
	return true


func refresh_does_not_reacquire_or_restore_removed() -> bool:
	var state: RunState = _state()
	_equip(state, RelicRules.BOUNDARY)
	_equip(state, RelicRules.GREEN)
	_equip(state, RelicRules.SATCHEL, RelicRules.BOUNDARY)
	state.relics.normal_surveys_used = 4
	state.expansion.current_act = 2
	RelicRules.refresh_act(state, 2)
	expect_equal(state.relics.normal_surveys_used, 0, "Act resets normal Survey history")
	expect_true(not RelicRules.active(state, RelicRules.BOUNDARY), "Act change does not restore removed Relic")
	expect_equal(state.relics.instances.size(), 3, "No reacquisition")
	return true


func _snapshot(state: RunState, current: Array[CurrentFeature], features: Array[Dictionary]) -> CompletionSnapshot:
	return CompletionSnapshot.new({"act": state.expansion.current_act, "features": features,
		"relics": RelicRules.capture(state, current)})


func _numeric_snapshot(id: StringName, type: int, size: int, natural: bool = false,
		act: int = 3, old_roads: int = 0) -> CompletionSnapshot:
	return CompletionSnapshot.new({"act": act,
		"features": [{"lineage_id": 1, "feature_type": type, "total_size": size}],
		"relics": {"equipped": [{"runtime_id": 2, "definition_id": String(id), "acquisition_order": 1}],
			"largest_settlement_size": size, "prior_longest_road": size,
			"feature_facts": {"1": {"natural_contact": natural, "act_one_road_count": old_roads}}}})
