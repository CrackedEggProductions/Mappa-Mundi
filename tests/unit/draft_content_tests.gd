extends "res://tests/framework/test_suite.gd"

const Fixture = preload("res://tests/fixtures/phase_eight_factory.gd")


func tests() -> Array[Callable]:
	var result: Array[Callable] = [core_bag_has_exact_eighteen_copies, starter_pool_is_distinct_noncore_content,
		regular_pools_match_unlocked_player_content, entry_pools_are_new_unlocks_only,
		pool_queries_own_their_arrays, threshold_mapping_is_explicit,
		rejects_noncore_and_wrong_core_bag, rejects_missing_duplicate_and_future_draft_ids,
		rejects_wrong_cadence_and_twenty_reward, twenty_crossing_is_reward_noop,
		twenty_repeat_has_no_side_effects, later_threshold_order_unchanged,
		twenty_roundtrip_never_becomes_reward, rejects_forged_twenty_reward_job]
	for track: int in range(4):
		for values: Array in [[19, 20], [19, 21], [0, 25], [20, 40]]:
			result.append(twenty_crossing_cases.bind(track, values[0], values[1]))
	return result


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	assert(content.load_phase_nine().is_valid)
	return content


func _valid_config(config: RunConfig) -> bool:
	var manifest: ContentManifest = load(ContentRegistry.PHASE_NINE_MANIFEST_PATH)
	return ContentValidator.validate(manifest, config).is_valid


func core_bag_has_exact_eighteen_copies() -> bool:
	var config: RunConfig = _content().get_config()
	var actual: Dictionary = {}
	var total: int = 0
	for entry: StartingBagEntry in config.starting_bag:
		expect_true(not actual.has(entry.definition_id), "Each core design occurs once in manifest")
		actual[entry.definition_id] = entry.count
		total += entry.count
	expect_equal(total, 18, "Exactly eighteen core copies before starter choices")
	expect_equal(actual, {&"tile.forest_edge": 3, &"tile.forest_bend": 1, &"tile.forest_belt": 1,
		&"tile.straight_road": 2, &"tile.bending_road": 2, &"tile.road_junction": 2,
		&"tile.hamlet_edge": 3, &"tile.settlement_corner": 1, &"tile.settlement_throughway": 1,
		&"tile.settlement_gate": 2}, "Exact requested core composition")
	return true


func starter_pool_is_distinct_noncore_content() -> bool:
	var config: RunConfig = _content().get_config()
	expect_equal(config.starter_draft_pool.size(), 10, "Six hybrids and four ordinary Developments")
	var seen: Array[StringName] = []
	for id: StringName in config.starter_draft_pool:
		expect_true(id not in seen and id not in HomesteadContentValidator.CORE_COUNTS, "Starter choices are distinct noncore designs")
		seen.append(id)
	expect_true(HomesteadContentValidator._same_pool(config.starter_draft_pool, [
		&"tile.riverside_hamlet", &"tile.woodland_road", &"tile.woodland_river", &"tile.settlement_corner_gate",
		&"tile.settlement_road_bend", &"tile.settlement_road_throughway", &"tile.development.housing",
		&"tile.development.mill", &"tile.development.monastery", &"tile.development.foresters_lodge"]), "Exact starter pool")
	return true


func regular_pools_match_unlocked_player_content() -> bool:
	var content: ContentRegistry = _content()
	var config: RunConfig = content.get_config()
	for act: int in [1, 2, 3]:
		var pool: Array[StringName] = config.draft_pool(act)
		expect_equal(pool.size(), [20, 25, 28][act - 1], "Cumulative pool size")
		expect_true(HomesteadContentValidator._same_pool(pool, RewardRules.tile_pool(content, act)), "Unlock eligibility matches current player acquisitions")
		for id: StringName in HomesteadContentValidator.NON_PLAYER_IDS:
			expect_true(id not in pool, "Legacy/setup geography never enters a draft")
	return true


func entry_pools_are_new_unlocks_only() -> bool:
	var config: RunConfig = _content().get_config()
	expect_true(HomesteadContentValidator._same_pool(config.entry_draft_pool(2), [
		&"tile.development.market", &"tile.development.port", &"tile.transformation.urban_expansion",
		&"tile.development.town_square", &"tile.development.abbey"]), "Act II entry choices")
	expect_true(HomesteadContentValidator._same_pool(config.entry_draft_pool(3), [
		&"tile.transformation.bridge", &"tile.transformation.rewilding", &"tile.development.grand_market"]), "Act III entry choices")
	expect_equal(config.draft_interval, 2, "Draft every second normal placement")
	return true


func pool_queries_own_their_arrays() -> bool:
	var config: RunConfig = _content().get_config()
	var regular: Array[StringName] = config.draft_pool(3)
	var entry: Array[StringName] = config.entry_draft_pool(2)
	regular.clear()
	entry.clear()
	expect_equal(config.draft_pool(3).size(), 28, "Caller cannot change configured regular pool")
	expect_equal(config.entry_draft_pool(2).size(), 5, "Caller cannot change configured entry pool")
	return true


func threshold_mapping_is_explicit() -> bool:
	var config: RunConfig = _content().get_config()
	expect_equal(config.track_thresholds, [20, 40, 70, 100], "Threshold values unchanged")
	expect_equal(config.track_threshold_reward_kinds, [&"none", &"training_reward", &"relic_offer", &"major_reward"], "Twenty is truly no reward")
	expect_equal(RewardRules.THRESHOLD_KINDS, config.track_threshold_reward_kinds, "Runtime and validated metadata agree")
	return true


func rejects_noncore_and_wrong_core_bag() -> bool:
	var config: RunConfig = _content().get_config()
	config.starting_bag[0].count += 1
	expect_true(not _valid_config(config), "Wrong core quantity rejected")
	config = _content().get_config()
	config.starting_bag[0].definition_id = &"tile.woodland_road"
	expect_true(not _valid_config(config), "Noncore design must be selected through draft")
	return true


func rejects_missing_duplicate_and_future_draft_ids() -> bool:
	for mode: int in range(4):
		var config: RunConfig = _content().get_config()
		match mode:
			0: config.starter_draft_pool.pop_back()
			1: config.act_one_draft_pool[0] = config.act_one_draft_pool[1]
			2: config.act_two_unlocks[0] = &"tile.development.grand_market"
			3: config.act_three_unlocks[0] = &"tile.river_run"
		expect_true(not _valid_config(config), "Malformed or non-player draft pool rejected")
	return true


func rejects_wrong_cadence_and_twenty_reward() -> bool:
	var config: RunConfig = _content().get_config()
	config.draft_interval = 3
	expect_true(not _valid_config(config), "Canonical cadence enforced")
	config = _content().get_config()
	config.track_threshold_reward_kinds[0] = &"tile_reward"
	expect_true(not _valid_config(config), "Old twenty-point Tile Reward cannot return silently")
	return true


func twenty_crossing_is_reward_noop() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content, 1)
	state.features.tracks.values = [20, 20, 20, 20]
	var before: Array = [state.current_rng_state, state.rng.operation_count, state.tile_copies.size(),
		state.expansion.bag.duplicate(), state.expansion.hand.duplicate(), state.expansion.pending_refill_index]
	RewardRules.queue_thresholds(state)
	RewardRules.advance(state, content)
	expect_true(state.rewards.queue.is_empty() and state.pending_choice == null, "Twenty creates no reward work or choice")
	expect_equal(state.rewards.threshold_flags.size(), 4, "Each crossing is still audited once")
	expect_equal([state.current_rng_state, state.rng.operation_count, state.tile_copies.size(),
		state.expansion.bag, state.expansion.hand, state.expansion.pending_refill_index], before,
		"No offer RNG, copies, shuffle, draw or refill mutation")
	for event: Dictionary in state.rewards.history:
		expect_equal(event["kind"], "track_threshold_crossed", "No reward offer/resolution event")
	return true


func twenty_repeat_has_no_side_effects() -> bool:
	var state: RunState = Fixture.create(Fixture.content(), 1)
	state.features.tracks.values = [20, 0, 0, 0]
	RewardRules.queue_thresholds(state)
	var fingerprint: String = StateNormalizer.fingerprint(state)
	RewardRules.queue_thresholds(state)
	expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Repeated scan cannot repeat twenty crossing or create a delayed reward")
	return true


func later_threshold_order_unchanged() -> bool:
	var state: RunState = Fixture.create(Fixture.content(), 1)
	state.features.tracks.values = [100, 100, 100, 100]
	RewardRules.queue_thresholds(state)
	expect_equal(state.rewards.threshold_flags.size(), 16, "All crossings are recorded")
	expect_equal(state.rewards.queue.size(), 12, "Only forty/seventy/hundred create rewards")
	for track: int in range(4):
		for rank: int in range(3):
			var job: Dictionary = state.rewards.queue[track * 3 + rank]
			expect_equal(job["track"], track, "Fixed Population/Trade/Culture/Ecology order")
			expect_equal(job["threshold"], [40, 70, 100][rank], "Ascending rewarding thresholds")
			expect_equal(StringName(job["kind"]), [&"training_reward", &"relic_offer", &"major_reward"][rank], "Existing reward type unchanged")
	return true


func twenty_roundtrip_never_becomes_reward() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content, 3)
	for x: int in range(1, 18):
		Fixture.Geography.add(state, content, &"tile.forest_belt", Vector2i(-x, 0), 1)
	Fixture.Geography.add(state, content, &"tile.forest_edge", Vector2i(-18, 0), 1)
	expect_equal(state.features.tracks.values[3], 21, "Real completed Forest supplies a save-valid twenty crossing")
	RewardRules.queue_thresholds(state)
	var fingerprint: String = StateNormalizer.fingerprint(state)
	for iteration: int in range(2):
		var saved: SerializationResult = RunSerializer.serialize(state, content)
		expect_true(saved.validation.is_valid, str(saved.validation.debug_details))
		var restored: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
		expect_true(restored.validation.is_valid, str(restored.validation.debug_details))
		if restored.state == null:
			return true
		state = restored.state
		RewardRules.queue_thresholds(state)
		expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Save/load and rescanning preserve no-op crossing exactly")
	return true


func rejects_forged_twenty_reward_job() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content, 1)
	state.rewards.queue.append({"kind": "tile_reward", "source_id": 0, "eligibility_act": 1,
		"track": 0, "threshold": 20})
	var report: InvariantReport = InvariantValidator.validate(state, content)
	expect_true(not report.is_valid and report.describe().contains("invalid_threshold_job"), "Old twenty reward cannot survive in a forged queue")
	return true


func twenty_crossing_cases(track: int, before_value: int, after_value: int) -> bool:
	var state: RunState = Fixture.create(Fixture.content(), 1)
	state.features.tracks.values[track] = before_value
	RewardRules.queue_thresholds(state)
	var rng_before: int = state.current_rng_state
	state.features.tracks.values[track] = after_value
	RewardRules.queue_thresholds(state)
	expect_equal(state.current_rng_state, rng_before, "Threshold scanning consumes no RNG")
	expect_equal(state.rewards.queue.size(), int(after_value >= 40), "Twenty never contributes a reward")
	if after_value >= 40:
		expect_equal(state.rewards.queue[0]["kind"], "training_reward", "Forty still grants training")
	for job: Dictionary in state.rewards.queue:
		expect_true(job["threshold"] != 20, "No twenty reward even when crossing several thresholds")
	return true
