extends "res://tests/framework/test_suite.gd"


func tests() -> Array[Callable]:
	return [canonical_eight_roles, all_roles_have_canonical_targets, content_copies_are_passive,
		missing_role_rejected, deferred_role_rejected, duplicate_role_rejected,
		wrong_behavior_rejected, wrong_target_rejected, prior_profiles_preserved,
		starts_with_two_available, roster_round_trip, repeated_load_is_inert,
		full_width_piece_ids_round_trip, registry_order_normalizes, role_affects_fingerprint,
		codec_preserves_nested_full_width_ids, codec_rejects_lossy_ids, codec_rejects_duplicate_keys,
		codec_preserves_names_and_coordinates, codec_dictionary_order_normalizes,
		corrupted_piece_shape_rejected, duplicate_piece_id_rejected, fourth_piece_rejected,
		available_target_rejected, deferred_runtime_role_rejected, fake_training_history_rejected,
		pending_training_round_trip, forged_training_offer_rejected, pending_assignment_round_trip,
		forged_snapshot_rejected, forged_assignment_option_rejected, missing_resolution_rejected,
		trained_piece_round_trip, assigned_piece_round_trip, high_id_training_choice_round_trip,
		forged_training_event_rejected, forged_assignment_context_rejected,
		malformed_nested_choice_rejected, coordinate_extremes_are_lossless, removed_initial_piece_rejected]


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	expect_true(content.load_phase_seven().is_valid, "Canonical Phase-7 resources load")
	return content


func _state(content: ContentRegistry) -> RunState:
	return HomesteadRunFactory.create(47001, content)


func _manifest() -> ContentManifest:
	var manifest: ContentManifest = load(ContentRegistry.PHASE_SEVEN_MANIFEST_PATH).duplicate(true) as ContentManifest
	for index: int in range(manifest.specialists.size()):
		manifest.specialists[index] = manifest.specialists[index].duplicate(true) as SpecialistDefinition
	return manifest


func _validate_manifest(manifest: ContentManifest) -> bool:
	return ContentValidator.validate(manifest, _content().get_config()).is_valid


func canonical_eight_roles() -> bool:
	var ids: Array[StringName] = _content().get_specialist_ids()
	expect_equal(ids, [&"specialist.architect", &"specialist.cartographer", &"specialist.forester",
		&"specialist.harbormaster", &"specialist.homesteader", &"specialist.merchant",
		&"specialist.naturalist", &"specialist.riverkeeper"], "Exactly canonical alpha roles, sorted")
	return true


func all_roles_have_canonical_targets() -> bool:
	var content: ContentRegistry = _content()
	for id: StringName in content.get_specialist_ids():
		var definition: SpecialistDefinition = content.get_specialist(id)
		expect_equal(definition.eligible_feature_types, [SpecialistContentValidator.ROLES[id]], "One canonical target")
		expect_equal(String(definition.behavior_id), String(id).trim_prefix("specialist."), "Registered passive behavior ID")
	return true


func content_copies_are_passive() -> bool:
	var content: ContentRegistry = _content()
	content.get_specialist(&"specialist.merchant").behavior_id = &"mutated"
	expect_equal(content.get_specialist(&"specialist.merchant").behavior_id, &"merchant", "Returned content cannot mutate registry")
	expect_true(content.get_specialist(&"specialist.engineer") == null, "Deferred role unavailable")
	return true


func missing_role_rejected() -> bool:
	var manifest: ContentManifest = _manifest()
	manifest.specialists.pop_back()
	expect_true(not _validate_manifest(manifest), "Missing alpha role fails content load")
	return true


func deferred_role_rejected() -> bool:
	var manifest: ContentManifest = _manifest()
	manifest.specialists[0].definition_id = &"specialist.engineer"
	expect_true(not _validate_manifest(manifest), "Prototype role cannot enter alpha")
	return true


func duplicate_role_rejected() -> bool:
	var manifest: ContentManifest = _manifest()
	manifest.specialists[1] = manifest.specialists[0]
	expect_true(not _validate_manifest(manifest), "Duplicate definition ID fails")
	return true


func wrong_behavior_rejected() -> bool:
	var manifest: ContentManifest = _manifest()
	manifest.specialists[0].behavior_id = &"free_trade"
	expect_true(not _validate_manifest(manifest), "Arbitrary Specialist behavior fails")
	return true


func wrong_target_rejected() -> bool:
	var manifest: ContentManifest = _manifest()
	manifest.specialists[0].eligible_feature_types = [DomainTypes.FeatureType.RIVER]
	expect_true(not _validate_manifest(manifest), "Merchant cannot declare River assignment")
	return true


func prior_profiles_preserved() -> bool:
	var content: ContentRegistry = ContentRegistry.new()
	for profile: String in [ContentRegistry.ALPHA_MANIFEST_PATH, ContentRegistry.HOMESTEAD_MANIFEST_PATH,
		ContentRegistry.PHASE_FIVE_MANIFEST_PATH, ContentRegistry.PHASE_SIX_MANIFEST_PATH]:
		var config: String = ContentRegistry.ALPHA_CONFIG_PATH if profile == ContentRegistry.ALPHA_MANIFEST_PATH else ContentRegistry.HOMESTEAD_CONFIG_PATH
		expect_true(content.load_content(profile, config).is_valid, "Historical fixture profile still loads")
		expect_true(content.get_specialist_ids().is_empty(), "Legacy fixtures remain explicitly pre-Specialist")
	return true


func starts_with_two_available() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	expect_equal(state.specialists.pieces.size(), 2, "Two physical starting Stewards")
	for piece: SpecialistPieceState in state.specialists.pieces:
		expect_true(piece.role_definition_id.is_empty() and piece.status == SpecialistPieceState.Status.AVAILABLE, "Both generic and available")
	expect_true(InvariantValidator.validate(state, content).is_valid, "Standard setup valid")
	return true


func _round_trip(state: RunState, content: ContentRegistry) -> RunState:
	var saved: SerializationResult = RunSerializer.serialize(state, content)
	expect_true(saved.validation.is_valid, "Serialize valid: " + str(saved.validation.debug_details))
	if not saved.validation.is_valid:
		return null
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	expect_true(loaded.validation.is_valid, "Load valid: " + str(loaded.validation.debug_details))
	if loaded.state != null:
		expect_equal(StateNormalizer.fingerprint(loaded.state), StateNormalizer.fingerprint(state), "Exact normalized state")
	return loaded.state


func roster_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var loaded: RunState = _round_trip(state, content)
	if loaded != null:
		expect_true(loaded.specialists != state.specialists and loaded.specialists.pieces[0] != state.specialists.pieces[0], "Fresh independent runtime objects")
	return true


func repeated_load_is_inert() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var facts: Array = [state.next_runtime_id, state.current_rng_state, state.rng.operation_count,
		state.features.tracks.values.duplicate(), state.features.history.size(), state.specialists.history.size()]
	for iteration: int in range(4):
		state = _round_trip(state, content)
		if state == null:
			return true
		expect_equal([state.next_runtime_id, state.current_rng_state, state.rng.operation_count,
			state.features.tracks.values, state.features.history.size(), state.specialists.history.size()], facts,
			"Load allocates/trains/assigns/scores nothing and consumes zero RNG")
	return true


func full_width_piece_ids_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.specialists.pieces[0].piece_id = 9223372036854770000
	state.specialists.pieces[1].piece_id = 9223372036854770001
	state.id_allocator = RunIdAllocator.new(9223372036854770002)
	var loaded: RunState = _round_trip(state, content)
	if loaded != null:
		expect_equal(loaded.specialists.pieces[0].piece_id, 9223372036854770000, "No JSON double precision loss")
	return true


func registry_order_normalizes() -> bool:
	var state: RunState = _state(_content())
	var before: String = StateNormalizer.fingerprint(state)
	state.specialists.pieces.reverse()
	expect_equal(StateNormalizer.fingerprint(state), before, "Piece registry order has no rule meaning")
	return true


func role_affects_fingerprint() -> bool:
	var state: RunState = _state(_content())
	var before: String = StateNormalizer.fingerprint(state)
	state.specialists.pieces[0].role_definition_id = &"specialist.merchant"
	expect_true(StateNormalizer.fingerprint(state) != before, "Role is authoritative fingerprint data")
	return true


func codec_preserves_nested_full_width_ids() -> bool:
	var input: Dictionary = {9223372036854775807: {"ids": [9223372036854775807, -9223372036854775808], "name": &"snapshot"}}
	var encoded: Dictionary = SpecialistValueCodec.encode(input)
	var parsed: Variant = JSON.parse_string(JSON.stringify(encoded))
	expect_true(SpecialistValueCodec.valid(parsed), "Nested full-width IDs have canonical encodings")
	expect_equal(SpecialistValueCodec.decode(parsed), input, "Nested integer keys/values retain exact signed64 values")
	return true


func codec_rejects_lossy_ids() -> bool:
	for value: Variant in [1.0, "01", "-0", "9223372036854775808", "-9223372036854775809", "1.5"]:
		expect_true(not SpecialistValueCodec.valid({"type": "int", "value": value}), "Reject lossy/noncanonical nested ID")
	return true


func codec_rejects_duplicate_keys() -> bool:
	var encoded: Dictionary = SpecialistValueCodec.encode({"piece_id": 1})
	encoded["value"].append(encoded["value"][0].duplicate(true))
	expect_true(not SpecialistValueCodec.valid(encoded), "Duplicate dictionary records cannot overwrite authoritative facts")
	return true


func codec_preserves_names_and_coordinates() -> bool:
	var input: Dictionary = {Vector2i(-40, 80): [&"merchant", "merchant", true, null, 1.25]}
	var encoded: Dictionary = SpecialistValueCodec.encode(input)
	expect_true(SpecialistValueCodec.valid(encoded), "Allowed primitive tree")
	var output: Dictionary = SpecialistValueCodec.decode(encoded)
	expect_equal(output, input, "Coordinates/names and scalar types retained")
	expect_equal(typeof(output[Vector2i(-40, 80)][0]), TYPE_STRING_NAME, "StringName stays typed")
	return true


func codec_dictionary_order_normalizes() -> bool:
	var left: Dictionary = {"b": {"id": 12}, "a": 4}
	var right: Dictionary = {"a": 4, "b": {"id": 12}}
	expect_equal(JSON.stringify(SpecialistValueCodec.encode(left)), JSON.stringify(SpecialistValueCodec.encode(right)), "Recursive unordered maps have deterministic records")
	return true


func _reject_state(state: RunState, content: ContentRegistry, label: String) -> void:
	var loaded: DeserializationResult = RunSerializer.deserialize(JSON.stringify(RunSerializer.to_envelope(state)), content)
	expect_true(not loaded.validation.is_valid and loaded.state == null, label)


func corrupted_piece_shape_rejected() -> bool:
	var content: ContentRegistry = _content()
	var envelope: Dictionary = RunSerializer.to_envelope(_state(content))
	var data: Dictionary = SpecialistValueCodec.decode(envelope["run_state"]["specialists"])
	data["pieces"][0]["piece_id"] = 1.0
	envelope["run_state"]["specialists"] = SpecialistValueCodec.encode(data)
	expect_true(not RunSerializer.deserialize(JSON.stringify(envelope), content).validation.is_valid, "Float physical IDs cannot enter typed runtime")
	return true


func duplicate_piece_id_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.specialists.pieces[1].piece_id = state.specialists.pieces[0].piece_id
	_reject_state(state, content, "Duplicate physical Specialist identity rejected")
	return true


func fourth_piece_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	for index: int in range(2):
		var piece: SpecialistPieceState = SpecialistPieceState.new()
		piece.piece_id = state.id_allocator.allocate()
		state.specialists.pieces.append(piece)
	_reject_state(state, content, "Four physical pieces exceed alpha cap")
	return true


func available_target_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.specialists.pieces[0].assigned_target_id = state.features.lineages[0].lineage_id
	_reject_state(state, content, "Available piece cannot retain stale target")
	return true


func deferred_runtime_role_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.specialists.pieces[0].role_definition_id = &"specialist.courier"
	_reject_state(state, content, "Deferred prototype role rejected in save")
	return true


func fake_training_history_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.specialists.pieces[0].role_definition_id = &"specialist.merchant"
	_reject_state(state, content, "Trained identity requires permanent conversion audit")
	return true


func _training(content: ContentRegistry) -> RunState:
	var state: RunState = _state(content)
	var result: ValidationResult = RulesEngine.execute(state, content,
		RequestSpecialistTrainingCommand.new(state.specialists.pieces[0].piece_id))
	expect_true(result.is_valid, "Create canonical pending training offer")
	return state


func pending_training_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _training(content)
	var loaded: RunState = _round_trip(state, content)
	if loaded != null:
		expect_equal(loaded.pending_choice.options, state.pending_choice.options, "Exact offered role IDs and order, no reroll")
		expect_equal(loaded.current_rng_state, state.current_rng_state, "RNG continuation unchanged")
		expect_equal(loaded.next_runtime_id, state.next_runtime_id, "Loading choice allocates no ID")
	return true


func forged_training_offer_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _training(content)
	state.pending_choice.options[0]["role_definition_id"] = "specialist.engineer"
	_reject_state(state, content, "Pending offer cannot smuggle deferred role")
	return true


func _assignment(content: ContentRegistry) -> RunState:
	# Choose a real hand placement with unfinished local geometry, never inject a choice.
	for seed_value: int in range(1, 20):
		var original: RunState = HomesteadRunFactory.create(seed_value, content)
		for copy_id: int in original.expansion.hand:
			for option: PlacementOption in PlacementQueryService.query_for_copy(original, content, copy_id):
				var state: RunState = RunSerializer.deserialize(RunSerializer.serialize(original, content).json_text, content).state
				var result: ValidationResult = RulesEngine.execute(state, content,
					PlaceTileCommand.new(copy_id, TileLocationState.Kind.ACTIVE_HAND, option.coordinate, option.rotation))
				if result.is_valid and state.pending_choice != null:
					return state
	expect_true(false, "Fixture must find an ordinary local assignment")
	return null


func pending_assignment_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _assignment(content)
	if state == null:
		return true
	var loaded: RunState = _round_trip(state, content)
	if loaded != null:
		expect_equal(loaded.resolution.completion_snapshot, state.resolution.completion_snapshot, "Committed immutable snapshot retained")
		expect_equal(loaded.pending_choice.options, state.pending_choice.options, "Exact local assignment combinations retained")
		expect_equal(loaded.expansion.hand, state.expansion.hand, "Consumed slot stays empty through pending continuation")
	return true


func forged_snapshot_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _assignment(content)
	if state != null:
		state.resolution.completion_snapshot["tracks"][0] += 50
		_reject_state(state, content, "Saved continuation cannot forge pre-effect snapshot")
	return true


func forged_assignment_option_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _assignment(content)
	if state != null:
		state.pending_choice.options[0]["piece_id"] = 9223372036854770000
		_reject_state(state, content, "Pending choice cannot deploy an absent piece")
	return true


func missing_resolution_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _assignment(content)
	if state != null:
		state.resolution = null
		_reject_state(state, content, "Committed placement choice requires continuation")
	return true


func trained_piece_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _training(content)
	var id: int = state.specialists.pieces[0].piece_id
	var role: StringName = StringName(state.pending_choice.options[0]["role_definition_id"])
	expect_true(RulesEngine.execute(state, content,
		ResolveSpecialistTrainingCommand.new(state.pending_choice.choice_id, role)).is_valid, "Resolve training")
	var loaded: RunState = _round_trip(state, content)
	if loaded != null:
		expect_equal(loaded.specialists.pieces[0].piece_id, id, "Training preserves physical piece identity")
		expect_equal(loaded.specialists.pieces[0].role_definition_id, role, "Permanent trained role retained")
		expect_equal(loaded.specialists.pieces[0].training_history, state.specialists.pieces[0].training_history, "Training audit retained exactly")
	return true


func assigned_piece_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _assignment(content)
	if state == null:
		return true
	var option: Dictionary = state.pending_choice.options[0]
	expect_true(RulesEngine.execute(state, content, ResolveSpecialistAssignmentCommand.new(
		state.pending_choice.choice_id, option["piece_id"], option["target_type"], option["target_id"])).is_valid,
		"Assign through authoritative choice")
	var loaded: RunState = _round_trip(state, content)
	if loaded != null:
		var piece: SpecialistPieceState = loaded.specialists.piece(option["piece_id"])
		expect_equal(piece.status, SpecialistPieceState.Status.ASSIGNED, "Occupation retained")
		expect_equal(piece.assigned_target_id, option["target_id"], "Stable host lineage retained")
		expect_equal(piece.growth_baseline_component_ids, state.specialists.piece(option["piece_id"]).growth_baseline_component_ids, "Observed growth metadata retained")
	return true


func high_id_training_choice_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.id_allocator = RunIdAllocator.new(9223372036854770000)
	expect_true(RulesEngine.execute(state, content,
		RequestSpecialistTrainingCommand.new(state.specialists.pieces[0].piece_id)).is_valid, "Full-width pending choice allocated")
	var loaded: RunState = _round_trip(state, content)
	if loaded != null:
		expect_equal(loaded.pending_choice.choice_id, 9223372036854770000, "Choice identity exact beyond JSON numeric precision")
	return true


func forged_training_event_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _training(content)
	var role: StringName = StringName(state.pending_choice.options[0]["role_definition_id"])
	RulesEngine.execute(state, content, ResolveSpecialistTrainingCommand.new(state.pending_choice.choice_id, role))
	state.specialists.pieces[0].training_history[0]["event_id"] = 9223372036854770000
	_reject_state(state, content, "Training record must reference actual conversion event")
	return true


func forged_assignment_context_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _assignment(content)
	if state != null:
		state.pending_choice.context["decline_allowed"] = false
		_reject_state(state, content, "Optional assignment cannot lose canonical decline availability")
	return true


func malformed_nested_choice_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _training(content)
	state.pending_choice.context["piece_id"] = {"forged": 1}
	_reject_state(state, content, "Malformed nested context rejects before any unsafe conversion")
	return true


func coordinate_extremes_are_lossless() -> bool:
	var encoded: Dictionary = SpecialistValueCodec.encode(Vector2i(-2147483648, 2147483647))
	expect_true(SpecialistValueCodec.valid(encoded), "Inclusive signed32 board coordinate range")
	expect_equal(SpecialistValueCodec.decode(encoded), Vector2i(-2147483648, 2147483647), "Exact corner coordinates")
	expect_true(not SpecialistValueCodec.valid({"type": "coordinate", "value": ["-9223372036854775808", "0"]}), "Int64 minimum cannot overflow a coordinate bound check")
	return true


func removed_initial_piece_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.specialists.pieces.pop_back()
	_reject_state(state, content, "Canonical persistent roster cannot silently lose a starting piece")
	return true
