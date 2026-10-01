extends "res://tests/framework/test_suite.gd"
## Access probabilities change; acquired Relic effects and saved offers do not.

const F = preload("res://tests/fixtures/phase_eight_factory.gd")
const Graph = preload("res://tests/fixtures/topology_fixture.gd")
const TYPE = DomainTypes.FeatureType
const EXPECTED: Dictionary = {
	RelicRules.BOUNDARY: [&"common", 1, 60], RelicRules.COMPASS: [&"common", 1, 60],
	RelicRules.SATCHEL: [&"common", 1, 60], RelicRules.GREEN: [&"uncommon", 1, 30],
	RelicRules.MIXED: [&"uncommon", 2, 30], RelicRules.HISTORIC: [&"uncommon", 2, 30],
	RelicRules.FERRY: [&"rare", 1, 10], RelicRules.RELAY: [&"rare", 1, 10],
	RelicRules.CITY: [&"rare", 1, 10], RelicRules.LONG_ROAD: [&"rare", 1, 10],
}


func tests() -> Array[Callable]:
	var result: Array[Callable] = [exact_classification, missing_metadata_rejected,
		wrong_minimum_act_rejected, rarity_is_not_act, weighted_offer_order_and_rng,
		weighted_small_and_empty_pools, acquired_excluded_unselected_remain,
		weighted_pending_roundtrip, threshold_twenty_capacity_replace_or_decline,
		multiple_twenty_offers_resolve_in_track_order, cache_uses_weighted_sampler,
		early_city_changes_future_base_only, early_long_road_keeps_prior_record,
		early_relay_returns_same_piece_locally]
	for values: Array in [
		[RelicRules.BOUNDARY, RelicRules.COMPASS, RelicRules.SATCHEL],
		[RelicRules.BOUNDARY, RelicRules.COMPASS, RelicRules.GREEN, RelicRules.MIXED],
		[RelicRules.BOUNDARY, RelicRules.SATCHEL, RelicRules.CITY, RelicRules.FERRY],
		[RelicRules.BOUNDARY, RelicRules.GREEN, RelicRules.CITY, RelicRules.RELAY]]:
		var ids: Array[StringName] = []
		ids.assign(values)
		result.append(weighted_integer_oracle.bind(ids))
	for track: int in range(4):
		for gain: Vector2i in [Vector2i(19, 20), Vector2i(19, 21), Vector2i(0, 25)]:
			result.append(threshold_twenty_crossing.bind(track, gain))
	return result


func _state(seed_value: int = 913, act: int = 1) -> RunState:
	var state: RunState = RunState.new(seed_value)
	state.expansion = ExpansionState.new()
	state.expansion.current_act = act
	state.features = FeatureState.new()
	state.relics = RelicState.new()
	state.relics.current_act = act
	state.relics.capacity = RelicRules.capacity_for_act(act)
	state.rewards = RewardState.new()
	return state


func _prepare_rewards(state: RunState) -> void:
	state.resolution = ResolutionState.new()
	state.resolution.stage = &"reward_queue"
	state.resolution.context = {"mode": "reward"}
	state.phase = GamePhase.Type.RESOLVING_PLACEMENT


func _choose(state: RunState, content: ContentRegistry, index: int = 0) -> void:
	var command: ResolveRewardCommand = ResolveRewardCommand.new(state.pending_choice.choice_id, index)
	assert(RewardCommands.validate_command(state, content, command).is_valid)
	RewardCommands.execute_command(state, content, command)


func exact_classification() -> bool:
	var content: ContentRegistry = F.content()
	for id: StringName in EXPECTED:
		var definition: RelicDefinition = content.get_relic(id)
		expect_equal([definition.rarity, definition.minimum_act, definition.offer_weight()], EXPECTED[id], String(id))
	return true


func missing_metadata_rejected() -> bool:
	var content: ContentRegistry = F.content()
	for property: StringName in [&"rarity", &"minimum_act"]:
		var definitions: Array[RelicDefinition] = []
		for id: StringName in content.get_relic_ids():
			definitions.append(content.get_relic(id))
		definitions[0].set(property, &"" if property == &"rarity" else 0)
		expect_true(not RelicContentValidator.validate(definitions).is_valid, "Missing " + String(property) + " fails startup")
	expect_equal(RelicDefinition.new().offer_weight(), 0, "Missing rarity has no silent Common default")
	return true


func wrong_minimum_act_rejected() -> bool:
	var content: ContentRegistry = F.content()
	var definitions: Array[RelicDefinition] = []
	for id: StringName in content.get_relic_ids():
		definitions.append(content.get_relic(id))
	definitions[0].minimum_act = 3
	expect_true(not RelicContentValidator.validate(definitions).is_valid, "Old Act tier cannot silently return")
	return true


func rarity_is_not_act() -> bool:
	var content: ContentRegistry = F.content()
	for act: int in [1, 2, 3]:
		var state: RunState = _state(1, act)
		var pool: Array[StringName] = RelicRules.eligible_ids(state, content)
		for id: StringName in EXPECTED:
			expect_equal(pool.has(id), act >= int(EXPECTED[id][1]), "Act gate " + String(id))
	return true


func weighted_integer_oracle(ids: Array[StringName]) -> bool:
	var content: ContentRegistry = F.content()
	for seed_value: int in range(1, 65):
		var state: RunState = _state(seed_value)
		var oracle: RunRNG = RunRNG.new(seed_value)
		var pool: Array[StringName] = ids.duplicate()
		pool.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		var expected: Array[StringName] = []
		for slot: int in range(mini(3, pool.size())):
			var tickets: Array[StringName] = []
			for id: StringName in pool:
				for ticket: int in range(int(EXPECTED[id][2])):
					tickets.append(id)
			var selected: StringName = tickets[oracle.integer_range(1, tickets.size()) - 1]
			expected.append(selected)
			pool.erase(selected)
		expect_equal(RewardRules.sample_relics(state, ids, content), expected, "Per-Relic tickets, removed after each weighted selection")
		expect_equal(state.current_rng_state, oracle.current_state, "Only canonical integer draws advance RNG")
	return true


func weighted_offer_order_and_rng() -> bool:
	var content: ContentRegistry = F.content()
	var first: RunState = _state(891, 2)
	var second: RunState = _state(891, 2)
	var ids: Array[StringName] = RelicRules.eligible_ids(first, content)
	var offer: Array[StringName] = RewardRules.sample_relics(first, ids, content)
	ids.reverse()
	expect_equal(RewardRules.sample_relics(second, ids, content), offer, "Input insertion order cannot affect weighted offer")
	expect_equal(first.current_rng_state, second.current_rng_state, "Same seed gives same continuation")
	expect_equal(first.rng.operation_count, 3, "One integer draw per offered slot")
	for id: StringName in offer:
		expect_equal(offer.count(id), 1, "No duplicate slot")
	expect_equal(ids.size(), 10, "Sampler does not consume persistent eligibility")
	return true


func weighted_small_and_empty_pools() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = _state()
	for values: Array in [[], [RelicRules.CITY], [RelicRules.GREEN, RelicRules.CITY]]:
		var ids: Array[StringName] = []
		ids.assign(values)
		var before: int = state.rng.operation_count
		var offer: Array[StringName] = RewardRules.sample_relics(state, ids, content)
		expect_equal(offer.size(), ids.size(), "Offer up to available candidates without padding")
		expect_equal(state.rng.operation_count - before, ids.size(), "Weighted display order uses one roll for every slot")
	return true


func acquired_excluded_unselected_remain() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = _state()
	var offer: Array[StringName] = RewardRules.sample_relics(state, RelicRules.eligible_ids(state, content), content)
	assert(RelicRules.acquire(state, content, offer[0]).is_valid)
	var remaining: Array[StringName] = RelicRules.eligible_ids(state, content)
	expect_true(offer[0] not in remaining, "Acquisition exhausts")
	expect_true(offer[1] in remaining and offer[2] in remaining, "Unselected designs are not exhausted")
	for seed_value: int in range(1, 25):
		state.rng = RunRNG.new(seed_value)
		expect_true(offer[0] not in RewardRules.sample_relics(state, remaining, content), "Exhausted design never sampled")
	return true


func weighted_pending_roundtrip() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(741, content)
	_prepare_rewards(state)
	RewardRules.enqueue(state, &"relic_offer")
	RewardRules.advance(state, content)
	var before: String = StateNormalizer.fingerprint(state)
	var restored: RunState = F.load_copy(state, content)
	expect_equal(StateNormalizer.fingerprint(restored), before, "Load preserves RNG, exact weighted offer and order")
	for copy: RunState in [state, restored]:
		expect_true(RulesEngine.execute(copy, content, ResolveRewardCommand.new(copy.pending_choice.choice_id, 0)).is_valid, "Saved weighted choice resolves normally")
	expect_equal(StateNormalizer.fingerprint(restored), StateNormalizer.fingerprint(state), "Saved choice has identical continuation")
	return true


func threshold_twenty_crossing(track: int, gain: Vector2i) -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = _state()
	_prepare_rewards(state)
	state.features.tracks.values[track] = gain.x
	RewardRules.queue_thresholds(state)
	expect_true(state.rewards.queue.is_empty(), "Below threshold has no reward")
	state.features.tracks.values[track] = gain.y
	RewardRules.queue_thresholds(state)
	expect_equal(state.rewards.queue.size(), 1, "Exactly one new crossing reward")
	expect_equal(state.rewards.queue[0].kind, "relic_offer", "20 grants Relic, never tiles")
	expect_equal(state.rng.operation_count, 0, "Queueing alone consumes no RNG")
	RewardRules.advance(state, content)
	expect_equal(state.pending_choice.kind, &"relic_offer", "Crossing waits for actual player choice")
	expect_equal(state.rng.operation_count, 3, "Weighted offer consumes three integer draws")
	_choose(state, content)
	expect_equal(RelicRules.equipped(state).size(), 1, "Choosing equips one Relic")
	expect_true(state.expansion.bag.is_empty(), "20 does not add physical tiles")
	RewardRules.queue_thresholds(state)
	expect_true(state.rewards.queue.is_empty(), "Threshold cannot repeat")
	return true


func threshold_twenty_capacity_replace_or_decline() -> bool:
	var content: ContentRegistry = F.content()
	for decline: bool in [false, true]:
		var state: RunState = _state()
		_prepare_rewards(state)
		assert(RelicRules.acquire(state, content, RelicRules.BOUNDARY).is_valid)
		assert(RelicRules.acquire(state, content, RelicRules.COMPASS).is_valid)
		state.features.tracks.values[0] = 20
		RewardRules.queue_thresholds(state)
		RewardRules.advance(state, content)
		var incoming: StringName = StringName(state.pending_choice.options[0].definition_id)
		_choose(state, content)
		expect_equal(state.pending_choice.kind, &"relic_replacement", "Full capacity still offers acquisition")
		var replaced: StringName = StringName(state.pending_choice.options[1].replace_id)
		_choose(state, content, 0 if decline else 1)
		expect_equal(state.relics.capacity, 2, "Act-I capacity unchanged")
		expect_equal(RelicRules.equipped(state).size(), 2, "No over-capacity acquisition")
		expect_equal(RelicRules.active(state, incoming), not decline, "Accept or decline preserves choice")
		expect_equal(RelicRules.eligible_ids(state, content).has(incoming), decline, "Only acquired Relic is exhausted")
		if not decline:
			expect_true(not RelicRules.active(state, replaced), "Chosen former Relic is replaced")
			expect_true(replaced not in RelicRules.eligible_ids(state, content), "Removed Relic remains exhausted")
	return true


func multiple_twenty_offers_resolve_in_track_order() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = _state()
	_prepare_rewards(state)
	state.features.tracks.values = [20, 20, 20, 20]
	RewardRules.queue_thresholds(state)
	for track: int in range(4):
		RewardRules.advance(state, content)
		expect_equal(state.pending_choice.kind, &"relic_offer", "Each newly crossed Track opens an offer")
		expect_equal(state.pending_choice.context.track, track, "Population, Trade, Culture, Ecology order")
		var offer_id: int = state.pending_choice.choice_id
		var rng: int = state.current_rng_state
		RewardRules.advance(state, content)
		expect_equal(state.pending_choice.choice_id, offer_id, "Next offer waits for current one")
		expect_equal(state.current_rng_state, rng, "Pending offer cannot reroll")
		_choose(state, content)
		if track >= 2:
			expect_equal(state.pending_choice.kind, &"relic_replacement", "Capacity replacement fully resolves before next Track")
			_choose(state, content, 1 if track == 2 else 0)
	RewardRules.queue_thresholds(state)
	expect_true(state.rewards.queue.is_empty() and state.pending_choice == null, "All four crossings resolve exactly once")
	expect_equal(state.relics.instances.size(), 3, "Two equips and one replacement; final decline creates no instance")
	return true


func cache_uses_weighted_sampler() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = _state(578)
	var oracle: RunState = _state(578)
	var expected: Array[StringName] = RewardRules.sample_relics(oracle, RelicRules.eligible_ids(oracle, content), content)
	_prepare_rewards(state)
	RewardCommands._major(state, content, &"relic_cache", {"eligibility_act": 1, "source_id": 0})
	RewardRules.advance(state, content)
	var actual: Array[StringName] = []
	for option: Dictionary in state.pending_choice.options:
		actual.append(StringName(option.definition_id))
	expect_equal(actual, expected, "Cache uses same weighted offer generator")
	expect_equal(state.current_rng_state, oracle.current_rng_state, "Cache has identical offer RNG")
	_choose(state, content)
	RewardRules.advance(state, content)
	expect_equal(state.pending_choice.kind, &"tile_reward", "Cache still grants its Normal Tile Reward afterward")
	return true


func early_city_changes_future_base_only() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = _state()
	Graph.add(state, Vector2i.ZERO, [0, 4, 0, 0])
	Graph.add(state, Vector2i.RIGHT, [0, 0, 0, 4])
	Graph.reconcile(state)
	var before: CompletionSnapshot = FeatureScoringService.capture(state, TopologyService.rebuild(state))
	assert(RelicRules.acquire(state, content, RelicRules.CITY).is_valid)
	expect_equal(state.features.tracks.values, [0, 0, 0, 0], "Early acquisition causes no retroactive scoring")
	expect_equal(FeatureScoringService.calculate(before)[0].base_multiplier, 1, "Previous completion snapshot stays unchanged")
	var after: Dictionary = FeatureScoringService.capture(state, TopologyService.rebuild(state)).data()
	after["specialists"] = [{"piece_id": 999, "role_definition_id": "", "target_id": after.features[0].lineage_id, "target_type": TYPE.SETTLEMENT}]
	var snapshot: CompletionSnapshot = CompletionSnapshot.new(after)
	expect_equal(FeatureScoringService.calculate(snapshot)[0].base_multiplier, 2, "Act-I largest Settlement future base doubles")
	expect_equal(SpecialistRules.calculate(snapshot)[0].gains[0], 2, "Generic Steward remains +2")
	Graph.add(state, Vector2i(10, 0), [4, 4, 4, 4])
	Graph.add(state, Vector2i(11, 0), [4, 4, 4, 4])
	Graph.add(state, Vector2i(12, 0), [4, 4, 4, 4])
	Graph.reconcile(state)
	snapshot = FeatureScoringService.capture(state, TopologyService.rebuild(state))
	expect_equal(FeatureScoringService.calculate(snapshot)[0].base_multiplier, 0, "Act-I smaller Settlement base suppressed")
	return true


func early_long_road_keeps_prior_record() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = _state()
	Graph.add(state, Vector2i.ZERO, [0, 3, 0, 0])
	Graph.add(state, Vector2i.RIGHT, [0, 0, 0, 3])
	Graph.reconcile(state)
	FeatureScoringService.resolve(state, TopologyService.rebuild(state))
	var paid: Array[int] = state.features.tracks.values.duplicate()
	assert(RelicRules.acquire(state, content, RelicRules.LONG_ROAD).is_valid)
	expect_equal(state.features.largest_completed_sizes[TYPE.ROAD], 2, "Act-I historical record predates acquisition")
	expect_equal(state.features.tracks.values, paid, "Acquiring Long Road never replays old scoring")
	var relic_facts: Dictionary = RelicRules.capture(state, TopologyService.rebuild(state))
	var snapshot: CompletionSnapshot = CompletionSnapshot.new({"act": 1, "relics": relic_facts,
		"specialists": [{"piece_id": 999, "role_definition_id": "", "target_id": 1, "target_type": TYPE.ROAD}]})
	for size: int in [1, 2, 3]:
		expect_equal(RelicRules.base_multiplier(snapshot, {"feature_type": TYPE.ROAD, "total_size": size}), 0 if size < 2 else 2, "Existing record controls future base multiplier")
	expect_equal(SpecialistRules.calculate(snapshot)[0].gains[1], 2, "Non-base Steward Trade remains +2")
	return true


func early_relay_returns_same_piece_locally() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.create(content, 1)
	assert(RelicRules.acquire(state, content, RelicRules.RELAY).is_valid)
	F.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	F.Previous.assign(state, content, TYPE.ROAD)
	var piece_id: int = state.specialists.pieces[0].piece_id
	F.play(state, content, &"tile.settlement_gate", Vector2i(2, 0), 2)
	F.decline_assignment(state, content)
	expect_equal(state.pending_choice.kind, &"specialist_relay", "Act-I return opens normal Relay")
	for option: Dictionary in state.pending_choice.options:
		expect_equal(option.piece_id, piece_id, "Only returned physical piece can Relay")
		expect_true(not SpecialistRules.occupied(state, int(option.target_type), int(option.target_id)), "Occupied target excluded")
	var selected: Dictionary = state.pending_choice.options[0].duplicate()
	expect_true(RulesEngine.execute(state, content, ResolveRelayCommand.new(state.pending_choice.choice_id, 0)).is_valid, "Same local typed Relay command works in Act I")
	expect_equal(state.specialists.pieces[0].assigned_target_id, selected.target_id, "Returned Steward assigned to exact offered target")
	expect_equal(state.specialists.pieces[0].status, SpecialistPieceState.Status.ASSIGNED, "No global reassignment workaround")
	return true
