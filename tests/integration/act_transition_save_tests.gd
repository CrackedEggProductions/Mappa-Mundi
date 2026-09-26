extends "res://tests/framework/test_suite.gd"
## Real 18/22-placement journals, real Charter choices, then single-step snapshots.
## Preparation uses internal resolution primitives; restored saves resume by command.

const F = preload("res://tests/fixtures/phase_nine_factory.gd")
var _content: ContentRegistry
var _trace: Dictionary = {}
var _checkpoints: Dictionary = {}
var _expected: Dictionary = {}


func tests() -> Array[Callable]:
	var result: Array[Callable] = [real_outgoing_choice_coverage]
	for act: int in [1, 2]:
		result.append(nested_choices_resume_once.bind(act))
		for step: int in range(2, 15):
			result.append(stable_checkpoint_resume_once.bind(act, step))
	return result


func _prepare() -> void:
	if not _trace.is_empty():
		return
	_content = F.content()
	_trace = F.scripted(_content, 212, 1, true, 2)
	for act: int in [1, 2]:
		var initial: String = ""
		for saved: Dictionary in _trace["saved_choices"]:
			if int(saved["act"]) == act:
				initial = saved["json"]
				break
		assert(not initial.is_empty(), "Fixture must pause in each outgoing Charter reward")
		var state: RunState = _load(initial)
		_checkpoints["%d:2" % act] = initial
		var reference: RunState = _load(initial)
		_finish_public(reference)
		_expected[act] = _semantic_fingerprint(reference)
		var guard: int = 0
		while state.act_transition != null:
			guard += 1
			assert(guard < 100, "Transition preparation must finish")
			if state.pending_choice != null:
				_execute_choice_only(state)
			assert(ActRules.advance_one(state, _content).is_valid)
			if state.act_transition != null and state.act_transition.step > 2:
				_checkpoints["%d:%d" % [act, state.act_transition.step]] = _save(state)


func _save(state: RunState) -> String:
	var saved: SerializationResult = RunSerializer.serialize(state, _content)
	assert(saved.validation.is_valid, saved.validation.user_message + str(saved.validation.debug_details))
	return saved.json_text


func _load(json: String) -> RunState:
	var loaded: DeserializationResult = RunSerializer.deserialize(json, _content)
	assert(loaded.validation.is_valid, loaded.validation.user_message + str(loaded.validation.debug_details))
	return loaded.state


func _execute_choice_only(state: RunState) -> void:
	var command: PlayerCommand = F.choice_command(state)
	if RewardCommands.handles(command):
		assert(RewardCommands.validate_command(state, _content, command).is_valid)
		RewardCommands.execute_command(state, _content, command)
	elif RelicHandRules.handles(command):
		assert(RelicHandRules.validate_command(state, _content, command).is_valid)
		RelicHandRules.execute_command(state, _content, command)
	else:
		assert(SpecialistCommands.validate_command(state, _content, command).is_valid)
		SpecialistCommands.execute_command(state, _content, command)


func _finish_public(state: RunState) -> void:
	var guard: int = 0
	while state.pending_choice != null or state.act_transition != null:
		guard += 1
		assert(guard < 100, "Saved continuation must finish without replaying a turn")
		var command: PlayerCommand = F.choice_command(state) if state.pending_choice != null else ResumeActTransitionCommand.new()
		var accepted: ValidationResult = RulesEngine.execute(state, _content, command)
		assert(accepted.is_valid, accepted.user_message + str(accepted.debug_details))


func _semantic_fingerprint(state: RunState) -> String:
	# Different checkpoint positions need different numbers of resume commands.
	# Only this command-count revision differs; every gameplay/history field must match.
	var data: Dictionary = RunSerializer.to_envelope(state)
	data["run_state"]["expansion"].erase("state_revision")
	return JSON.stringify(data, "", true).sha256_text()


func stable_checkpoint_resume_once(act: int, step: int) -> bool:
	_prepare()
	var state: RunState = _load(_checkpoints["%d:%d" % [act, step]])
	expect_equal(state.act_transition.step, step, "Exact transition cursor restored")
	var fingerprint: String = StateNormalizer.fingerprint(state)
	var rng: int = state.current_rng_state
	var operations: int = state.rng.operation_count
	var ids: int = state.next_runtime_id
	for repeat: int in range(3):
		state = _load(_save(state))
		expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Repeated load preserves complete authoritative state")
		expect_equal(state.current_rng_state, rng, "Load consumes no random draw")
		expect_equal(state.rng.operation_count, operations, "Load performs no shuffle or offer selection")
		expect_equal(state.next_runtime_id, ids, "Load allocates no seed, event, or reward copy")
	if step <= 13:
		expect_equal(state.expansion.hand[state.act_transition.pending_hand_refill], 0, "Pending outgoing hand slot stays empty until step thirteen")
	_finish_public(state)
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Public continuation enters next Act input")
	expect_equal(state.expansion.current_act, act + 1, "Act advances exactly once")
	expect_equal(_semantic_fingerprint(state), _expected[act], "Every resume boundary gives identical histories, seeds, shuffle, choices and refill")
	var ended: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, _content, ResumeActTransitionCommand.new()).is_valid, "Completed transition cannot resume again")
	expect_equal(StateNormalizer.fingerprint(state), ended, "Rejected repeated resume has zero side effects")
	return true


func real_outgoing_choice_coverage() -> bool:
	_prepare()
	var by_act: Dictionary = {1: [], 2: []}
	for saved: Dictionary in _trace["saved_choices"]:
		by_act[int(saved["act"])].append(String(saved["kind"]))
	expect_true(by_act[1].has("tile_reward"), "Real Act I fulfillment pauses for its Tile Reward")
	expect_true(by_act[2].has("relic_offer"), "Real Act II fulfillment pauses for its Relic")
	expect_true(by_act[2].has("tile_reward"), "Real Act II resolves its ordered Tile Reward")
	expect_true(by_act[2].has("major_reward"), "Real Act II exceed pauses for its Major Reward")
	expect_equal(_checkpoints.size(), 26, "Both Acts supply each actual step-two-through-fourteen snapshot")
	return true


func nested_choices_resume_once(act: int) -> bool:
	_prepare()
	var examined: int = 0
	for saved: Dictionary in _trace["saved_choices"]:
		if int(saved["act"]) != act:
			continue
		examined += 1
		var state: RunState = _load(saved["json"])
		var choice_id: int = state.pending_choice.choice_id
		var options: Array[Dictionary] = state.pending_choice.options.duplicate(true)
		var fingerprint: String = StateNormalizer.fingerprint(state)
		state = _load(_save(state))
		expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Nested reward load does not replay prior rewards")
		expect_equal(state.pending_choice.choice_id, choice_id, "Choice identity remains exact")
		expect_equal(state.pending_choice.options, options, "Exact offered IDs and order never reroll")
		expect_equal(state.expansion.current_act, act, "Outgoing choice still has outgoing Act")
		expect_equal(state.relics.capacity, 2 if act == 1 else 4, "Outgoing choice retains old capacity")
		_finish_public(state)
		expect_equal(_semantic_fingerprint(state), _expected[act], "Resuming any nested choice converges without duplicate rewards or seeds")
	expect_true(examined > 0, "At least one actual nested boundary was exercised")
	return true
