extends "res://tests/framework/test_suite.gd"


func tests() -> Array[Callable]:
	return [
		same_seed_and_operations_reproduce_sequence,
		different_seeds_produce_different_sequences,
		advanced_snapshot_continues_native_sequence,
		snapshot_preserves_signed_and_large_seeds,
		shuffling_is_deterministic_and_preserves_input,
		empty_and_singleton_shuffles_count_without_drawing,
		index_and_range_helpers_stay_within_bounds,
		definition_choices_are_deterministic,
		candidate_validation_requires_unique_lexical_order,
		range_validation_rejects_unsupported_bounds,
		operation_counter_counts_helpers_not_internal_draws,
		debug_logging_is_optional_and_does_not_affect_stream,
		restored_logging_is_transient,
	]


func same_seed_and_operations_reproduce_sequence() -> bool:
	var first: RunRNG = RunRNG.new(86420)
	var second: RunRNG = RunRNG.new(86420)
	for index: int in range(40):
		expect_equal(first.integer_range(-999, 999), second.integer_range(-999, 999), "Same seed range %d" % index)
		expect_equal(first.select_index(17), second.select_index(17), "Same seed index %d" % index)
	expect_equal(first.current_state, second.current_state, "Equivalent operations preserve native state")
	return true


func different_seeds_produce_different_sequences() -> bool:
	var first: RunRNG = RunRNG.new(100)
	var second: RunRNG = RunRNG.new(200)
	var first_results: Array[int] = []
	var second_results: Array[int] = []
	for _index: int in range(20):
		first_results.append(first.integer_range(-1000000, 1000000))
		second_results.append(second.integer_range(-1000000, 1000000))
	expect_true(first_results != second_results, "Distinct fixture seeds differ over twenty draws")
	return true


func advanced_snapshot_continues_native_sequence() -> bool:
	var original: RunRNG = RunRNG.new(7219)
	var initial_state: int = original.current_state
	original.integer_range(-20, 80)
	original.shuffled_ids([10, 20, 30, 40, 50])
	original.select_index(7)
	expect_true(original.current_state != initial_state, "Fixture advances beyond seed state")
	var loaded: RunRNG = RunRNG.from_snapshot(original.original_seed, original.current_state, original.operation_count)
	var native: RandomNumberGenerator = RandomNumberGenerator.new()
	native.seed = original.original_seed
	native.state = original.current_state
	expect_equal(loaded.operation_count, 3, "Snapshot restores public operation count")
	for _index: int in range(30):
		var expected: int = native.randi_range(-123456, 123456)
		expect_equal(original.integer_range(-123456, 123456), expected, "Original matches native continuation")
		expect_equal(loaded.integer_range(-123456, 123456), expected, "Snapshot continues current native state")
	return true


func snapshot_preserves_signed_and_large_seeds() -> bool:
	var seeds: Array[int] = [-9223372036854775807 - 1, -17, 0, 9007199254740993, 9223372036854775807]
	for seed_value: int in seeds:
		var original: RunRNG = RunRNG.new(seed_value)
		original.select_index(101)
		var loaded: RunRNG = RunRNG.from_snapshot(seed_value, original.current_state, original.operation_count)
		expect_equal(loaded.original_seed, seed_value, "Original seed retains all signed 64-bit bits")
		for _index: int in range(8):
			expect_equal(loaded.select_index(100000), original.select_index(100000), "Extreme seed snapshot continues exactly")
	return true


func shuffling_is_deterministic_and_preserves_input() -> bool:
	var first: RunRNG = RunRNG.new(197)
	var second: RunRNG = RunRNG.new(197)
	var original: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
	var shuffled: Array[int] = first.shuffled_ids(original)
	expect_equal(shuffled, second.shuffled_ids(original), "Same seed shuffles equally")
	expect_equal(original, [1, 2, 3, 4, 5, 6, 7, 8], "Shuffle leaves caller input unchanged")
	shuffled.sort()
	expect_equal(shuffled, original, "Shuffle preserves each physical ID exactly once")
	return true


func empty_and_singleton_shuffles_count_without_drawing() -> bool:
	var rng: RunRNG = RunRNG.new(49)
	var state_before: int = rng.current_state
	expect_equal(rng.shuffled_ids([]), [], "Empty shuffle is well-defined")
	expect_equal(rng.shuffled_ids([65]), [65], "Singleton shuffle preserves its member")
	expect_equal(rng.operation_count, 2, "Each public shuffle is an operation")
	expect_equal(rng.current_state, state_before, "No internal random draws needed")
	return true


func index_and_range_helpers_stay_within_bounds() -> bool:
	var rng: RunRNG = RunRNG.new(18)
	expect_equal(rng.select_index(1), 0, "Single index is zero")
	expect_equal(rng.integer_range(-5, -5), -5, "Equal bounds select that bound")
	for _index: int in range(30):
		var selected: int = rng.select_index(5)
		var ranged: int = rng.integer_range(-4, 7)
		expect_true(selected >= 0 and selected < 5, "Index is within collection")
		expect_true(ranged >= -4 and ranged <= 7, "Range is inclusive and bounded")
	expect_equal(rng.integer_range(RunRNG.MIN_RANGE_VALUE, RunRNG.MIN_RANGE_VALUE), RunRNG.MIN_RANGE_VALUE, "Signed minimum supported")
	expect_equal(rng.integer_range(RunRNG.MAX_RANGE_VALUE, RunRNG.MAX_RANGE_VALUE), RunRNG.MAX_RANGE_VALUE, "Signed maximum supported")
	return true


func definition_choices_are_deterministic() -> bool:
	var first: RunRNG = RunRNG.new(751)
	var second: RunRNG = RunRNG.new(751)
	var candidates: Array[StringName] = [&"tile.alpha", &"tile.beta", &"tile.gamma"]
	for _index: int in range(20):
		var selected: StringName = first.choose_definition_id(candidates)
		expect_equal(selected, second.choose_definition_id(candidates), "Sorted selection is deterministic")
		expect_true(selected in candidates, "Selected definition belongs to candidate collection")
	expect_equal(first.choose_definition_id([&"tile.only"]), &"tile.only", "Single candidate supported")
	expect_equal(candidates, [&"tile.alpha", &"tile.beta", &"tile.gamma"], "Selection preserves candidate input")
	return true


func candidate_validation_requires_unique_lexical_order() -> bool:
	expect_true(RunRNG.are_ordered_candidates_valid([&"tile.10", &"tile.2", &"tile.Z", &"tile.a"]), "Ordering uses strings, including numeric and case distinctions")
	expect_true(not RunRNG.are_ordered_candidates_valid([]), "Empty candidates rejected")
	expect_true(not RunRNG.are_ordered_candidates_valid([&""]), "Empty definition ID rejected")
	expect_true(not RunRNG.are_ordered_candidates_valid([&"a", &"a"]), "Duplicate candidates rejected")
	expect_true(not RunRNG.are_ordered_candidates_valid([&"b", &"a"]), "Unsorted candidates rejected")
	return true


func range_validation_rejects_unsupported_bounds() -> bool:
	expect_true(RunRNG.is_valid_range(RunRNG.MIN_RANGE_VALUE, RunRNG.MAX_RANGE_VALUE), "Full native range is valid")
	expect_true(not RunRNG.is_valid_range(4, 3), "Reversed bounds rejected")
	expect_true(not RunRNG.is_valid_range(RunRNG.MIN_RANGE_VALUE - 1, 0), "Oversized negative bound rejected")
	expect_true(not RunRNG.is_valid_range(0, RunRNG.MAX_RANGE_VALUE + 1), "Oversized positive bound rejected")
	return true


func operation_counter_counts_helpers_not_internal_draws() -> bool:
	var rng: RunRNG = RunRNG.new(351)
	rng.integer_range(1, 90)
	rng.select_index(5)
	rng.shuffled_ids([1, 2, 3, 4, 5, 6, 7])
	rng.choose_definition_id([&"a", &"b"])
	expect_equal(rng.operation_count, 4, "Four public helpers count as four operations")
	return true


func debug_logging_is_optional_and_does_not_affect_stream() -> bool:
	var plain: RunRNG = RunRNG.new(681)
	var logged: RunRNG = RunRNG.new(681)
	logged.debug_logging_enabled = true
	expect_equal(logged.shuffled_ids([1, 2, 3], &"fixture_shuffle"), plain.shuffled_ids([1, 2, 3]), "Logging preserves shuffle result")
	expect_equal(logged.select_index(50, &"fixture_choice"), plain.select_index(50), "Reasons do not affect random draw")
	expect_equal(logged.current_state, plain.current_state, "Logging consumes no additional RNG")
	expect_equal(logged.debug_reasons(), [&"fixture_shuffle", &"fixture_choice"], "Reasons remain in operation order")
	expect_true(plain.debug_reasons().is_empty(), "Logging is disabled by default")
	var detached: Array[StringName] = logged.debug_reasons()
	detached.clear()
	expect_equal(logged.debug_reasons().size(), 2, "Caller cannot mutate internal diagnostics")
	return true


func restored_logging_is_transient() -> bool:
	var original: RunRNG = RunRNG.new(600)
	original.debug_logging_enabled = true
	original.select_index(9, &"before_snapshot")
	var loaded: RunRNG = RunRNG.from_snapshot(original.original_seed, original.current_state, original.operation_count)
	expect_true(loaded.debug_reasons().is_empty(), "Prior debug reasons are not persistent state")
	loaded.debug_logging_enabled = true
	expect_equal(loaded.select_index(11, &"after_snapshot"), original.select_index(11), "Transient logging does not change restored stream")
	expect_equal(loaded.operation_count, 2, "Persistent counter continues despite transient log")
	expect_equal(loaded.debug_reasons(), [&"after_snapshot"], "Only new diagnostic entry is recorded")
	return true
