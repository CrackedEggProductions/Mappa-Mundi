extends "res://tests/framework/test_suite.gd"
## Real starting bag; every play/choice uses the same controller path as mouse input.
## No tile acquisition fixtures, Track edits, or RunState mutations are used here.

static var _runs: Array[Dictionary] = []


func tests() -> Array[Callable]:
	return [natural_bag_completes_three_acts, exact_limits_and_real_transitions,
		midpoint_reveal_waits_for_input, final_placement_does_not_refill,
		complete_controller_replay_is_deterministic, all_choice_buttons_make_progress,
		completed_map_results_navigation]


static func play(seed_value: int = 1010) -> Dictionary:
	var controller: GameController = GameController.new()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(controller)
	controller.start_run(seed_value)
	var counts: Array[int] = [0, 0, 0]
	var turns: Array[Dictionary] = []
	var choices: Array[StringName] = []
	var errors: Array[String] = []
	var transitions: Array[int] = []
	var cycles: int = 0
	var guard: int = 0
	while controller.session.state.phase != GamePhase.Type.RUN_COMPLETE and guard < 300:
		guard += 1
		_drain(controller, choices, errors)
		if not errors.is_empty() or controller.session.state.phase == GamePhase.Type.RUN_COMPLETE:
			break
		var state: RunState = controller.session.state
		var act: int = state.expansion.current_act
		var chosen: bool = false
		for copy_id: int in state.expansion.hand:
			if copy_id != 0 and controller.select_copy(copy_id) and not controller.options.is_empty():
				controller.select_option(_compact_option(controller.options))
				chosen = true
				break
		if not chosen:
			var cycled: ValidationResult = controller.cycle_dead_hand()
			if not cycled.is_valid:
				errors.append("No playable hand and cycling failed: " + cycled.user_message)
				break
			cycles += 1
			continue
		var before_count: int = state.charters.placement_history.size()
		controller.confirm_button.pressed.emit()
		if state.charters.placement_history.size() != before_count + 1:
			errors.append("Confirm button did not commit exactly one selected placement")
			break
		counts[act - 1] += 1
		_drain(controller, choices, errors)
		if state.expansion.current_act != act:
			transitions.append(state.expansion.current_act)
		turns.append({"act": act, "index": counts[act - 1],
			"grand_revealed": state.charters.exact_revealed,
			"phase": state.phase, "hand_empty": state.expansion.hand.count(0)})
	var final_state: RunState = controller.session.state
	if guard >= 300:
		errors.append("Controller run exhausted bounded action budget")
	var trace: Dictionary = {"state": final_state, "counts": counts, "turns": turns,
		"choices": choices, "errors": errors, "transitions": transitions, "cycles": cycles,
		"fingerprint": StateNormalizer.fingerprint(final_state),
		"results_visible": controller.results_active}
	controller.free()
	return trace


static func _drain(controller: GameController, choices: Array[StringName], errors: Array[String]) -> void:
	var guard: int = 0
	while guard < 200:
		guard += 1
		if controller.notice_active:
			var before_notice: String = StateNormalizer.fingerprint(controller.session.state)
			controller.dismiss_notice()
			if StateNormalizer.fingerprint(controller.session.state) != before_notice:
				errors.append("Dismissing cosmetic notice mutated authoritative state")
				return
			continue
		var pending: PendingChoice = controller.session.state.pending_choice
		if pending == null:
			return
		choices.append(pending.kind)
		var before: String = StateNormalizer.fingerprint(controller.session.state)
		var decline: Button = controller.choice_presenter.decline_button
		if pending.kind in [&"specialist_relay", &"grand_survey", &"relic_replacement"] \
				and decline != null and not decline.disabled:
			decline.pressed.emit()
		elif not controller.choice_presenter.option_buttons.is_empty():
			controller.choice_presenter.option_buttons[0].pressed.emit()
		elif decline != null and not decline.disabled:
			decline.pressed.emit()
		else:
			errors.append("Pending choice has no mouse control: " + String(pending.kind))
			return
		if StateNormalizer.fingerprint(controller.session.state) == before:
			errors.append("Pending choice button made no authoritative progress: " + String(pending.kind))
			return
	errors.append("Pending choices or cosmetic notices did not drain")


static func _compact_option(options: Array[PlacementOption]) -> int:
	var chosen: int = 0
	var distance: int = 2147483647
	for index: int in range(options.size()):
		var at: Vector2i = options[index].coordinate
		var candidate: int = at.x * at.x + at.y * at.y
		if candidate < distance:
			distance = candidate
			chosen = index
	return chosen


func _run(index: int = 0) -> Dictionary:
	while _runs.size() <= index:
		_runs.append(play())
	return _runs[index]


func natural_bag_completes_three_acts() -> bool:
	var trace: Dictionary = _run()
	expect_equal(trace.errors, [], "Natural bag can finish via visible controller actions")
	expect_equal(trace.state.phase, GamePhase.Type.RUN_COMPLETE, "Real rules finalize the complete run")
	expect_true(trace.results_visible, "Controller presents results after authoritative finalization")
	return true


func exact_limits_and_real_transitions() -> bool:
	var trace: Dictionary = _run()
	expect_equal(trace.counts, [18, 22, 26], "All sixty-six placements use actual confirm controls")
	expect_equal(trace.transitions, [2, 3], "Both actual transitions execute exactly once")
	expect_equal(trace.state.charters.evaluations.size(), 3, "Two outgoing Charters and final Grand evaluate")
	return true


func midpoint_reveal_waits_for_input() -> bool:
	for turn: Dictionary in _run().turns:
		if turn.act == 2 and turn.index == 10:
			expect_true(not turn.grand_revealed, "Exact Grand remains secret through placement ten")
		if turn.act == 2 and turn.index == 11:
			expect_true(turn.grand_revealed, "Exact Grand visible after all placement-eleven choices")
	return true


func final_placement_does_not_refill() -> bool:
	var trace: Dictionary = _run()
	expect_equal(trace.state.expansion.hand.count(0), 1, "Final active-hand placement stays empty")
	expect_equal(trace.state.expansion.normal_placements, 26, "No new input turn starts after final placement")
	expect_true(trace.state.final_result != null, "Structured rules result is retained")
	return true


func complete_controller_replay_is_deterministic() -> bool:
	var first: Dictionary = _run(0)
	var replay: Dictionary = _run(1)
	expect_equal(replay.errors, [], "Repeated complete controller run remains playable")
	expect_equal(replay.fingerprint, first.fingerprint, "Same seed and button decisions reproduce all authoritative state")
	expect_equal(replay.choices, first.choices, "Persisted choice sequence reproduces")
	return true


func all_choice_buttons_make_progress() -> bool:
	var trace: Dictionary = _run()
	expect_true(not trace.choices.is_empty(), "Natural game actually exercises pending choices")
	expect_true(trace.choices.has(&"specialist_assignment"), "Real local Specialist choice is clickable")
	expect_equal(trace.errors, [], "No invisible or unhandled choice blocks the run")
	return true


func completed_map_results_navigation() -> bool:
	var trace: Dictionary = _run()
	var state: RunState = trace.state
	var controller: GameController = GameController.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(controller)
	var content: ContentRegistry = ContentRegistry.new()
	assert(content.load_phase_nine().is_valid)
	controller.attach_session(GameSession.new(state, content))
	var before: String = StateNormalizer.fingerprint(state)
	var board: BoardView = controller.board
	expect_true(controller.results_active, "Natural completed run opens results")
	for button: Button in controller.hand_buttons:
		expect_true(button.disabled, "No playable hand controls in completed run")
	expect_true(controller.confirm_button.disabled, "Confirm disabled after finalization")
	controller.shell.notice_button.pressed.emit()
	expect_true(not controller.results_active, "Mouse control switches to final map")
	expect_true(controller.board == board, "Final map remains the same rendered realm")
	expect_equal(state.phase, GamePhase.Type.RUN_COMPLETE, "Map viewing keeps rules complete")
	controller.shell.results_button.pressed.emit()
	expect_true(controller.results_active, "Mouse Results control restores final overlay")
	expect_equal(StateNormalizer.fingerprint(state), before, "Both views preserve final state exactly")
	controller.free()
	return true
