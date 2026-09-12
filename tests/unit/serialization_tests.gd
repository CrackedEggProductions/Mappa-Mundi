extends "res://tests/framework/test_suite.gd"

const Factory = preload("res://tests/fixtures/phase_one_factory.gd")


func tests() -> Array[Callable]:
	return [
		save_envelope_uses_explicit_json_primitives,
		empty_setup_round_trips,
		normalization_ignores_registry_order_without_mutation,
		authoritative_changes_change_fingerprint,
		diagnostic_rng_reasons_do_not_affect_fingerprint,
		preserves_signed_64_bit_boundaries,
		rejects_malformed_json_and_envelope,
		rejects_missing_and_unknown_fields,
		rejects_incompatible_versions,
		rejects_version_type_coercion,
		rejects_noncanonical_int64_values,
		rejects_invalid_small_numeric_fields,
		rejects_corrupt_references_and_duplicate_ids,
		rejects_invalid_rng_counter_and_id_cursor,
		rejects_future_phase_and_locations,
		rejects_invalid_domain_state_before_serializing,
	]


func save_envelope_uses_explicit_json_primitives() -> bool:
	var state: RunState = Factory.representative()
	var saved: SerializationResult = RunSerializer.serialize(state, Factory.content())
	expect_true(saved.validation.is_valid, saved.validation.user_message)
	expect_true(saved.json_text.contains("\n\t"), "Human-readable indentation")
	var envelope: Dictionary = JSON.parse_string(saved.json_text)
	expect_equal(envelope["save_schema_version"], 1.0, "Schema header")
	expect_equal(envelope["game_rules_version"], "alpha-1", "Rules header")
	expect_equal(envelope["implementation_spec_version"], 1.0, "Implementation header")
	expect_equal(envelope["godot_version"], BuildVersions.godot_version(), "Engine build header")
	var data: Dictionary = envelope["run_state"]
	expect_equal(data["original_seed"], str(state.original_seed), "Seed is precision-safe string")
	expect_equal(data["current_rng_state"], str(state.current_rng_state), "RNG state string")
	expect_equal(data["tile_copies"][0]["definition_id"], "tile.open_fields", "StringName explicitly encoded")
	expect_equal(data["tile_locations"][0]["tile_copy_id"], "1", "Relationship uses stable decimal ID")
	return true


func empty_setup_round_trips() -> bool:
	var state: RunState = RunState.new(0)
	var content: ContentRegistry = Factory.content()
	var saved: SerializationResult = RunSerializer.serialize(state, content)
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	expect_true(loaded.validation.is_valid, loaded.validation.user_message)
	if loaded.state != null:
		expect_equal(StateNormalizer.fingerprint(loaded.state), StateNormalizer.fingerprint(state), "Empty foundation round-trip")
	return true


func normalization_ignores_registry_order_without_mutation() -> bool:
	var first: RunState = Factory.representative()
	var second: RunState = Factory.representative()
	second.tile_copies.reverse()
	second.tile_locations.reverse()
	expect_equal(StateNormalizer.normalize(first), StateNormalizer.normalize(second), "Incidental registry order excluded")
	expect_equal(StateNormalizer.fingerprint(first), StateNormalizer.fingerprint(second), "Equivalent digest")
	expect_equal(second.tile_copies[0].tile_copy_id, 5, "Normalizer did not reorder live copy registry")
	expect_equal(second.tile_locations[0].tile_copy_id, 5, "Normalizer did not reorder live location registry")
	return true


func authoritative_changes_change_fingerprint() -> bool:
	var state: RunState = Factory.representative()
	var before: String = StateNormalizer.fingerprint(state)
	expect_equal(before.length(), 64, "SHA-256 hex digest")
	state.tile_copies[0].acquisition_source = &"different_source"
	expect_true(StateNormalizer.fingerprint(state) != before, "Physical metadata affects digest")
	before = StateNormalizer.fingerprint(state)
	state.id_allocator.allocate()
	expect_true(StateNormalizer.fingerprint(state) != before, "ID cursor affects digest")
	before = StateNormalizer.fingerprint(state)
	state.rng.select_index(5)
	expect_true(StateNormalizer.fingerprint(state) != before, "RNG continuation affects digest")
	return true


func preserves_signed_64_bit_boundaries() -> bool:
	var content: ContentRegistry = Factory.content()
	for seed_value: int in [9223372036854775807, -9223372036854775807 - 1, 9007199254740993]:
		var state: RunState = Factory.representative(seed_value)
		state.rng = RunRNG.from_snapshot(state.original_seed, state.current_rng_state, 9007199254740993)
		state.tile_copies[0].tile_copy_id = 9223372036854775806
		state.tile_locations[0].tile_copy_id = 9223372036854775806
		state.id_allocator = RunIdAllocator.new(9223372036854775807)
		var saved: SerializationResult = RunSerializer.serialize(state, content)
		var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
		expect_true(loaded.validation.is_valid, loaded.validation.user_message)
		if loaded.state != null:
			expect_equal(loaded.state.original_seed, seed_value, "Full-width seed survives JSON")
			expect_equal(loaded.state.current_rng_state, state.current_rng_state, "Full-width RNG state survives JSON")
			expect_equal(loaded.state.rng.operation_count, 9007199254740993, "Full-width RNG counter survives JSON")
			expect_equal(loaded.state.tile_copies[0].tile_copy_id, 9223372036854775806, "Full-width physical ID")
			expect_equal(loaded.state.next_runtime_id, 9223372036854775807, "Full-width allocator cursor")
			expect_equal(StateNormalizer.fingerprint(loaded.state), StateNormalizer.fingerprint(state), "Full-width state fingerprint")
	return true


func diagnostic_rng_reasons_do_not_affect_fingerprint() -> bool:
	var first: RunState = Factory.representative()
	var second: RunState = Factory.representative()
	second.rng.debug_logging_enabled = true
	first.rng.integer_range(1, 100, &"first_reason")
	second.rng.integer_range(1, 100, &"second_reason")
	expect_equal(StateNormalizer.fingerprint(first), StateNormalizer.fingerprint(second), "Diagnostic logging and reasons excluded")
	return true


func rejects_malformed_json_and_envelope() -> bool:
	for text: String in ["{", "null", "[]", "true", "12", "{}", "{\"run_state\": {}}"]:
		var loaded: DeserializationResult = RunSerializer.deserialize(text, Factory.content())
		expect_true(not loaded.validation.is_valid and loaded.state == null, "Reject malformed input: %s" % text)
	return true


func rejects_missing_and_unknown_fields() -> bool:
	var envelope: Dictionary = _envelope()
	envelope.erase("godot_version")
	_expect_rejected(envelope, "Missing metadata")
	envelope = _envelope()
	envelope["run_state"]["board"] = {}
	_expect_rejected(envelope, "Unsupported future field cannot silently disappear")
	envelope = _envelope()
	envelope["run_state"]["tile_copies"][0].erase("definition_id")
	_expect_rejected(envelope, "Missing entity field")
	envelope = _envelope()
	envelope["run_state"]["tile_locations"] = {}
	_expect_rejected(envelope, "Wrong container type")
	envelope = _envelope()
	envelope["run_state"]["tile_copies"] = [null]
	_expect_rejected(envelope, "Null entity record")
	return true


func rejects_incompatible_versions() -> bool:
	var changes: Dictionary = {
		"save_schema_version": 2, "game_rules_version": "alpha-future",
		"implementation_spec_version": 2, "godot_version": "unverified-engine",
	}
	for key: String in changes:
		var envelope: Dictionary = _envelope()
		envelope[key] = changes[key]
		_expect_rejected(envelope, "Incompatible %s" % key, &"incompatible_version")
	return true


func rejects_version_type_coercion() -> bool:
	for value: Variant in [true, "1", 1.5, null, [], {}]:
		var envelope: Dictionary = _envelope()
		envelope["save_schema_version"] = value
		_expect_rejected(envelope, "Invalid schema type %s" % str(value))
	return true


func rejects_noncanonical_int64_values() -> bool:
	var invalid_values: Array = [
		1, true, null, "", "01", "+1", "-0", " 1", "1 ", "1.0", "1e3", "--1",
		"9223372036854775808", "-9223372036854775809", "99999999999999999999999999",
	]
	for value: Variant in invalid_values:
		var envelope: Dictionary = _envelope()
		envelope["run_state"]["current_rng_state"] = value
		_expect_rejected(envelope, "Invalid int64 %s" % str(value))
	return true


func rejects_invalid_small_numeric_fields() -> bool:
	for value: Variant in [true, "1", 1.5, null, 0, 4]:
		var envelope: Dictionary = _envelope()
		envelope["run_state"]["tile_copies"][0]["acquired_act"] = value
		_expect_rejected(envelope, "Invalid acquisition Act %s" % str(value))
	var envelope: Dictionary = _envelope()
	envelope["run_state"]["tile_locations"][0]["kind"] = 6.5
	_expect_rejected(envelope, "Fractional location enum")
	return true


func rejects_corrupt_references_and_duplicate_ids() -> bool:
	var envelope: Dictionary = _envelope()
	envelope["run_state"]["tile_copies"][0]["definition_id"] = "tile.unknown"
	_expect_rejected(envelope, "Unknown static reference", &"invalid_saved_state")
	envelope = _envelope()
	envelope["run_state"]["tile_locations"][0]["tile_copy_id"] = "99"
	_expect_rejected(envelope, "Unknown runtime reference", &"invalid_saved_state")
	envelope = _envelope()
	envelope["run_state"]["tile_copies"][1]["tile_copy_id"] = "1"
	_expect_rejected(envelope, "Duplicate runtime identity", &"invalid_saved_state")
	envelope = _envelope()
	envelope["run_state"]["tile_locations"].append(envelope["run_state"]["tile_locations"][0])
	_expect_rejected(envelope, "Multiple locations", &"invalid_saved_state")
	return true


func rejects_invalid_rng_counter_and_id_cursor() -> bool:
	var envelope: Dictionary = _envelope()
	envelope["run_state"]["rng_operation_count"] = "-1"
	_expect_rejected(envelope, "Negative RNG counter")
	envelope = _envelope()
	envelope["run_state"]["next_runtime_id"] = "0"
	_expect_rejected(envelope, "Zero cursor cannot be constructed")
	envelope = _envelope()
	envelope["run_state"]["next_runtime_id"] = "5"
	_expect_rejected(envelope, "Cursor collides with existing entity", &"invalid_saved_state")
	return true


func rejects_future_phase_and_locations() -> bool:
	var envelope: Dictionary = _envelope()
	envelope["run_state"]["phase"] = GamePhase.Type.TURN_INPUT
	_expect_rejected(envelope, "Unsupported gameplay phase")
	envelope = _envelope()
	envelope["run_state"]["tile_locations"][0]["kind"] = TileLocationState.Kind.BAG
	_expect_rejected(envelope, "No Phase-2 bag implementation yet", &"invalid_saved_state")
	return true


func rejects_invalid_domain_state_before_serializing() -> bool:
	var state: RunState = Factory.representative()
	state.tile_locations.clear()
	var saved: SerializationResult = RunSerializer.serialize(state, Factory.content())
	expect_true(not saved.validation.is_valid and saved.json_text.is_empty(), "No corrupt save published")
	expect_equal(saved.validation.error_code, &"invariant_failure", "Programming error differs from invalid external input")
	return true


func _envelope() -> Dictionary:
	return RunSerializer.to_envelope(Factory.representative())


func _expect_rejected(envelope: Dictionary, message: String, code: StringName = &"invalid_save") -> void:
	var loaded: DeserializationResult = RunSerializer.deserialize(JSON.stringify(envelope), Factory.content())
	expect_true(not loaded.validation.is_valid and loaded.state == null, message)
	expect_equal(loaded.validation.error_code, code, message + " diagnostic category")
