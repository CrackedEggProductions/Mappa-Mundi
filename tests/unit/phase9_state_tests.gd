extends "res://tests/framework/test_suite.gd"


func tests() -> Array[Callable]:
	return [fresh_round_trip, repeated_load_is_inert, charter_codec_preserves_full_width_ids,
		transition_codec_preserves_every_step, result_codec_preserves_statistics,
		malformed_charter_tree_rejected, missing_charter_key_rejected,
		wrong_charter_id_type_rejected, malformed_transition_shape_rejected,
		malformed_result_shape_rejected, unknown_first_charter_rejected,
		missing_selection_audit_rejected, duplicate_selection_audit_rejected,
		charter_event_identity_collision_rejected, premature_forecast_rejected,
		premature_exact_reveal_rejected, invalid_completed_counts_rejected,
		invalid_journal_shape_rejected, fake_physical_commit_rejected,
		future_bonus_rejected, invalid_bonus_source_rejected, premature_result_rejected,
		completed_without_result_rejected, transition_without_charters_rejected,
		transition_flag_step_disagreement_rejected, phase_eight_profile_stays_supported,
		stripped_charter_state_rejected, orphan_active_bonus_rejected,
		malformed_selection_identity_rejected, malformed_progress_result_rejected,
		malformed_transition_progress_rejected, malformed_prior_audit_rejected,
		active_aggregate_score_overflow_rejected, representable_aggregate_score_boundary]


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	expect_true(content.load_phase_nine().is_valid, "Canonical Phase-9 content loads")
	return content


func _state(content: ContentRegistry) -> RunState:
	return HomesteadRunFactory.create(909, content)


func _reject(state: RunState, content: ContentRegistry) -> void:
	var loaded: DeserializationResult = RunSerializer.deserialize(JSON.stringify(RunSerializer.to_envelope(state)), content)
	expect_true(not loaded.validation.is_valid and loaded.state == null, "Malformed authoritative snapshot rejected safely")


func fresh_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var saved: SerializationResult = RunSerializer.serialize(state, content)
	expect_true(saved.validation.is_valid, str(saved.validation.debug_details))
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	expect_true(loaded.validation.is_valid, str(loaded.validation.debug_details))
	if loaded.state != null:
		expect_equal(StateNormalizer.fingerprint(loaded.state), StateNormalizer.fingerprint(state), "Exact selected Charter and RNG survive save/load")
	return true


func repeated_load_is_inert() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var fingerprint: String = StateNormalizer.fingerprint(state)
	var operations: int = state.rng.operation_count
	for iteration: int in range(5):
		var saved: SerializationResult = RunSerializer.serialize(state, content)
		var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
		expect_true(loaded.validation.is_valid, "Repeated snapshot restores without selecting again")
		if loaded.state == null:
			return true
		state = loaded.state
		expect_equal(state.rng.operation_count, operations, "Load consumes no gameplay RNG")
		expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Load creates no history, rewards, or selections")
	return true


func charter_codec_preserves_full_width_ids() -> bool:
	var state: CharterState = CharterState.new()
	state.history.append({"event_id": 9223372036854775806, "kind": "test", "act": 1})
	state.placement_history.append({"copy_id": 9007199254740993, "act": 2, "normal_index": 22, "is_bonus": true})
	state.bonus_queue.append({"source_id": 9007199254740993, "act": 2})
	var encoded: Dictionary = PhaseNineSerializer.encode(state, &"charters")
	expect_true(PhaseNineSerializer.validate_shape(encoded, &"charters").is_valid, "Typed trees retain all integers")
	var loaded: CharterState = PhaseNineSerializer.decode(encoded, &"charters") as CharterState
	expect_equal(loaded.history, state.history, "Audit IDs never round through JSON doubles")
	expect_equal(loaded.placement_history, state.placement_history, "Physical bonus chronology persists")
	expect_equal(loaded.bonus_queue, state.bonus_queue, "Pending bonus authorization persists")
	return true


func transition_codec_preserves_every_step() -> bool:
	for step: int in range(1, 15):
		var state: ActTransitionState = ActTransitionState.new()
		state.step = step
		state.transition_id = 9007199254740993
		state.pending_hand_refill = 2
		state.rewards.assign([&"tile", &"relic"])
		state.charter_result = {"nested": [{"source_id": 9223372036854775806}]}
		for flag: String in PhaseNineInvariantValidator.STEP_FLAGS:
			state.set(flag, step > PhaseNineInvariantValidator.STEP_FLAGS[flag])
		var encoded: Dictionary = PhaseNineSerializer.encode(state, &"act_transition")
		expect_true(PhaseNineSerializer.validate_shape(encoded, &"act_transition").is_valid, "Stable step has exact typed fields")
		var loaded: ActTransitionState = PhaseNineSerializer.decode(encoded, &"act_transition") as ActTransitionState
		expect_equal(PhaseNineSerializer.encode(loaded, &"act_transition"), encoded, "Every transition checkpoint round-trips directly")
	return true


func result_codec_preserves_statistics() -> bool:
	var result: RunResult = RunResult.new()
	result.grand_charter_id = &"charter.grand_living_heritage"
	result.tracks.assign([125, 88, 60, 80])
	result.score = 353
	result.statistics = {"run_seed": -9223372036854775807, "training": [{"piece_id": 9007199254740993}]}
	var encoded: Dictionary = PhaseNineSerializer.encode(result, &"final_result")
	expect_true(PhaseNineSerializer.validate_shape(encoded, &"final_result").is_valid, "Structured uncapped result is serializable")
	var loaded: RunResult = PhaseNineSerializer.decode(encoded, &"final_result") as RunResult
	expect_equal(loaded.statistics, result.statistics, "Seed and training history retain exact identity")
	expect_equal(loaded.tracks, result.tracks, "Final Tracks remain uncapped")
	return true


func malformed_charter_tree_rejected() -> bool:
	expect_true(not PhaseNineSerializer.validate_shape({"type": "array", "value": [false]}, &"charters").is_valid, "Malformed nested lossless tree rejected")
	return true


func missing_charter_key_rejected() -> bool:
	var value: Dictionary = SpecialistValueCodec.decode(PhaseNineSerializer.encode(CharterState.new(), &"charters"))
	value.erase("grand_id")
	expect_true(not PhaseNineSerializer.validate_shape(SpecialistValueCodec.encode(value), &"charters").is_valid, "Required hidden selection field cannot disappear")
	return true


func wrong_charter_id_type_rejected() -> bool:
	var value: Dictionary = SpecialistValueCodec.decode(PhaseNineSerializer.encode(CharterState.new(), &"charters"))
	value["act_one_id"] = 1
	expect_true(not PhaseNineSerializer.validate_shape(SpecialistValueCodec.encode(value), &"charters").is_valid, "Definition identity remains typed")
	return true


func malformed_transition_shape_rejected() -> bool:
	var value: Dictionary = SpecialistValueCodec.decode(PhaseNineSerializer.encode(ActTransitionState.new(), &"act_transition"))
	value["seeded_copy_ids"] = ["1"]
	expect_true(not PhaseNineSerializer.validate_shape(SpecialistValueCodec.encode(value), &"act_transition").is_valid, "Physical IDs must be exact integers")
	return true


func malformed_result_shape_rejected() -> bool:
	var value: Dictionary = SpecialistValueCodec.decode(PhaseNineSerializer.encode(RunResult.new(), &"final_result"))
	value["tracks"] = [1, false, 3, 4]
	expect_true(not PhaseNineSerializer.validate_shape(SpecialistValueCodec.encode(value), &"final_result").is_valid, "Final Tracks cannot contain booleans")
	return true


func unknown_first_charter_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.charters.act_one_id = &"charter.prototype"
	_reject(state, content)
	return true


func missing_selection_audit_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.charters.history.clear()
	_reject(state, content)
	return true


func duplicate_selection_audit_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var duplicate: Dictionary = state.charters.history[0].duplicate(true)
	duplicate["event_id"] = state.id_allocator.allocate()
	state.charters.history.append(duplicate)
	_reject(state, content)
	return true


func charter_event_identity_collision_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.charters.history[0]["event_id"] = state.specialists.pieces[0].piece_id
	_reject(state, content)
	return true


func premature_forecast_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.charters.forecast_visible = true
	_reject(state, content)
	return true


func premature_exact_reveal_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.charters.exact_revealed = true
	state.charters.exact_revealed_act = 2
	state.charters.exact_revealed_index = 11
	_reject(state, content)
	return true


func invalid_completed_counts_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.charters.completed_act_placements[0] = 18
	_reject(state, content)
	return true


func invalid_journal_shape_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.charters.placement_history.append({"copy_id": true})
	_reject(state, content)
	return true


func fake_physical_commit_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.charters.placement_history.append({"copy_id": state.expansion.hand[0], "act": 1, "normal_index": 1, "is_bonus": false})
	state.expansion.normal_placements = 1
	_reject(state, content)
	return true


func future_bonus_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.charters.bonus_queue.append({"source_id": state.expansion.hand[0], "act": 2})
	_reject(state, content)
	return true


func invalid_bonus_source_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.charters.bonus_queue.append({"source_id": state.next_runtime_id, "act": 1})
	_reject(state, content)
	return true


func premature_result_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.final_result = RunResult.new()
	_reject(state, content)
	return true


func completed_without_result_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.phase = GamePhase.Type.RUN_COMPLETE
	_reject(state, content)
	return true


func transition_without_charters_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.charters = null
	state.act_transition = ActTransitionState.new()
	_reject(state, content)
	return true


func transition_flag_step_disagreement_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.act_transition = ActTransitionState.new()
	state.act_transition.transition_id = state.id_allocator.allocate()
	state.act_transition.step = 5
	state.act_transition.advanced = false
	state.phase = GamePhase.Type.RESOLVING_ACT_TRANSITION
	_reject(state, content)
	return true


func phase_eight_profile_stays_supported() -> bool:
	var content: ContentRegistry = ContentRegistry.new()
	expect_true(content.load_phase_eight().is_valid, "Preserved Phase-8 content loads")
	var state: RunState = HomesteadRunFactory.create(808, content)
	expect_true(state.charters == null and state.act_transition == null and state.final_result == null, "Legacy profiles do not gain invented Charter state")
	var saved: SerializationResult = RunSerializer.serialize(state, content)
	expect_true(saved.validation.is_valid, "Existing Phase-8 snapshot remains valid")
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	expect_true(loaded.validation.is_valid, "Existing snapshot decodes without Charter selection")
	return true


func stripped_charter_state_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.charters = null
	_reject(state, content)
	return true


func orphan_active_bonus_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.charters.bonus_active = true
	_reject(state, content)
	return true


func _malformed_leaves() -> Array:
	return [{"nested": "value"}, ["value"], 1, 1.25, true, null, Vector2i.ONE]


func malformed_selection_identity_rejected() -> bool:
	var content: ContentRegistry = _content()
	for leaf: Variant in _malformed_leaves():
		var state: RunState = _state(content)
		state.charters.history[0]["charter_id"] = leaf
		_reject(state, content)
	return true


func malformed_progress_result_rejected() -> bool:
	var content: ContentRegistry = _content()
	for leaf: Variant in _malformed_leaves():
		var state: RunState = _state(content)
		state.charters.evaluations.append({"charter_id": String(state.charters.act_one_id),
			"overall_state": leaf, "conditions": [], "evaluation_act": 1})
		_reject(state, content)
	return true


func malformed_transition_progress_rejected() -> bool:
	var content: ContentRegistry = _content()
	for leaf: Variant in _malformed_leaves():
		var state: RunState = _state(content)
		state.act_transition = ActTransitionState.new()
		state.act_transition.transition_id = state.id_allocator.allocate()
		state.act_transition.step = 2
		state.act_transition.charter_result = {"charter_id": String(state.charters.act_one_id),
			"overall_state": leaf, "conditions": []}
		state.phase = GamePhase.Type.RESOLVING_ACT_TRANSITION
		_reject(state, content)
	return true


func malformed_prior_audit_rejected() -> bool:
	var content: ContentRegistry = _content()
	for collection: String in ["relics", "rewards"]:
		for leaf: Variant in _malformed_leaves():
			var state: RunState = _state(content)
			var history: Array = state.get(collection).history
			history.append({"event_id": leaf, "act": 1, "kind": "invalid"})
			_reject(state, content)
	return true


func active_aggregate_score_overflow_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.features.tracks.values.assign([9223372036854775807, 1, 0, 0])
	var before: String = StateNormalizer.fingerprint(state)
	var saved: SerializationResult = RunSerializer.serialize(state, content)
	expect_true(not saved.validation.is_valid, "Active state cannot save an unrepresentable future score")
	expect_true(str(saved.validation.debug_details).contains("unrepresentable_final_score"), "Aggregate overflow has a specific invariant diagnostic")
	var loaded: DeserializationResult = RunSerializer.deserialize(JSON.stringify(RunSerializer.to_envelope(state)), content)
	expect_true(not loaded.validation.is_valid and loaded.state == null, "Individually valid Track values cannot overflow their total on load")
	expect_true(str(loaded.validation.debug_details).contains("unrepresentable_final_score"), "Public load rejects total overflow before later scoring queries")
	expect_equal(StateNormalizer.fingerprint(state), before, "Validation never mutates state or consumes RNG")
	return true


func representable_aggregate_score_boundary() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.features.tracks.values.assign([9223372036854775804, 1, 1, 1])
	var report: InvariantReport = InvariantReport.new()
	PhaseNineInvariantValidator._validate_track_total(state, report)
	expect_true(report.is_valid, "Exact signed-64-bit maximum remains representable and is not capped")
	state.features.tracks.values[3] = 2
	PhaseNineInvariantValidator._validate_track_total(state, report)
	expect_true(not report.is_valid, "One additional point is rejected without overflowing the sum")
	return true
