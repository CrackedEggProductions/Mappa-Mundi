extends "res://tests/framework/test_suite.gd"

const Factory = preload("res://tests/fixtures/phase_one_factory.gd")


func tests() -> Array[Callable]:
	return [advanced_state_round_trip_continues_rng_and_ids, restored_objects_are_independent]


func advanced_state_round_trip_continues_rng_and_ids() -> bool:
	var content: ContentRegistry = Factory.content()
	var original: RunState = Factory.representative()
	var fresh: RunState = RunState.new(original.original_seed)
	expect_true(original.current_rng_state != fresh.current_rng_state, "Fixture advances beyond seed initialization")
	var saved: SerializationResult = RunSerializer.serialize(original, content)
	expect_true(saved.validation.is_valid, saved.validation.user_message)
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	expect_true(loaded.validation.is_valid, loaded.validation.user_message)
	if loaded.state == null:
		return true
	expect_true(InvariantValidator.validate(loaded.state, content).is_valid, "Loaded invariants pass")
	expect_equal(loaded.state.current_rng_state, original.current_rng_state, "Current RNG state restored exactly")
	expect_equal(loaded.state.rng.operation_count, original.rng.operation_count, "RNG count restored")
	expect_equal(StateNormalizer.normalize(loaded.state), StateNormalizer.normalize(original), "Normalized round-trip equality")
	expect_equal(StateNormalizer.fingerprint(loaded.state), StateNormalizer.fingerprint(original), "Fingerprint round-trip equality")
	for index: int in range(30):
		expect_equal(loaded.state.rng.integer_range(-1000, 1000), original.rng.integer_range(-1000, 1000), "Continued range %d" % index)
		expect_equal(loaded.state.rng.select_index(17), original.rng.select_index(17), "Continued selection %d" % index)
	expect_equal(loaded.state.rng.shuffled_ids([1, 3, 5, 7, 9]), original.rng.shuffled_ids([1, 3, 5, 7, 9]), "Continued shuffle")
	for expected_id: int in range(7, 12):
		expect_equal(original.id_allocator.allocate(), expected_id, "Original cursor never reuses allocated gaps")
		expect_equal(loaded.state.id_allocator.allocate(), expected_id, "Loaded allocation continues without collision")
	expect_true(InvariantValidator.validate(loaded.state, content).is_valid, "Continued loaded state stays valid")
	expect_equal(StateNormalizer.fingerprint(loaded.state), StateNormalizer.fingerprint(original), "Continuation preserves fingerprint equality")
	return true


func restored_objects_are_independent() -> bool:
	var content: ContentRegistry = Factory.content()
	var original: RunState = Factory.representative()
	var saved: SerializationResult = RunSerializer.serialize(original, content)
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	if loaded.state == null:
		expect_true(false, loaded.validation.user_message)
		return true
	expect_true(loaded.state != original, "Fresh RunState")
	expect_true(loaded.state.rng != original.rng, "Fresh RNG owner")
	expect_true(loaded.state.id_allocator != original.id_allocator, "Fresh allocator")
	expect_true(loaded.state.tile_copies[0] != original.tile_copies[0], "Fresh physical copy object")
	expect_true(loaded.state.tile_locations[0] != original.tile_locations[0], "Fresh typed location")
	loaded.state.tile_copies[0].acquisition_source = &"changed_fixture_source"
	expect_equal(original.tile_copies[0].acquisition_source, &"phase_one_fixture", "Mutating loaded copy cannot mutate original")
	return true
