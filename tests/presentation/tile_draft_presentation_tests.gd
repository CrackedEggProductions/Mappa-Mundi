extends "res://tests/framework/test_suite.gd"
## Draft choices use the same one-click command path as the mouse interface.


func tests() -> Array[Callable]:
	return [new_run_waits_before_hand_draw, starter_charter_inspection_is_pure,
		one_click_starter_resolves_once, exact_options_and_mechanical_help,
		cadence_title, entry_title, entry_draft_hud_starts_at_two, next_draft_hud_uses_rules_query,
		final_act_has_no_placement_26_draft, pending_draft_locks_gameplay,
		draft_rendering_does_not_reroll, no_reward_threshold_has_no_reward_cue]


func _controller() -> GameController:
	var controller: GameController = GameController.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(controller)
	controller.start_run(1010)
	return controller


func new_run_waits_before_hand_draw() -> bool:
	var controller: GameController = _controller()
	var state: RunState = controller.session.state
	expect_equal(state.phase, GamePhase.Type.PENDING_CHOICE, "New Run waits on an authoritative starter draft")
	expect_equal(state.pending_choice.kind, &"tile_draft", "Typed draft is rendered")
	expect_equal(state.expansion.hand, [0, 0, 0], "Opening hand has not been drawn")
	expect_equal(controller.choice_presenter.title_label.text, "Choose Your First Addition", "Starter title explains the first decision")
	expect_equal(controller.board.tiles.size(), 9, "Generated River and Founding remain visible")
	expect_true(not state.charters.act_one_id.is_empty(), "Charter is selected before drafting")
	expect_true(controller.choice_presenter.charter_button.visible, "Charter inspection is available inside the modal")
	controller.free()
	return true


func starter_charter_inspection_is_pure() -> bool:
	var controller: GameController = _controller()
	var state: RunState = controller.session.state
	var before: String = StateNormalizer.fingerprint(state)
	var choice_id: int = state.pending_choice.choice_id
	var buttons: Array[Button] = controller.choice_presenter.option_buttons.duplicate()
	controller.choice_presenter.charter_button.pressed.emit()
	expect_true(controller.charter_popout.visible and controller.choice_presenter.visible, "Inspect overlays the still-present draft")
	expect_true(controller.shell.notice_text.text.contains(controller.session.content.get_charter(state.charters.act_one_id).display_name), "Selected Charter can inform starter choice")
	controller.shell.notice_button.pressed.emit()
	expect_true(not controller.notice_active and controller.choice_presenter.visible, "Back returns to the pending draft")
	expect_equal(state.pending_choice.choice_id, choice_id, "Inspection preserves the exact authoritative choice")
	expect_equal(controller.choice_presenter.option_buttons, buttons, "Inspection does not rebuild or reorder options")
	expect_equal(StateNormalizer.fingerprint(state), before, "Inspection and dismissal consume no RNG or state changes")
	controller.free()
	return true


func one_click_starter_resolves_once() -> bool:
	var controller: GameController = _controller()
	var state: RunState = controller.session.state
	var copies_before: int = state.tile_copies.size()
	var button: Button = controller.choice_presenter.option_buttons[0]
	var design_id: StringName = StringName(state.pending_choice.options[0]["definition_id"])
	var tile_name: String = controller.session.content.get_tile(design_id).display_name
	button.pressed.emit()
	expect_true(controller.shell.feedback_label.text.contains("%s added to the bag." % tile_name), "Draft feedback names the acquired design")
	expect_equal(state.tile_copies.size(), copies_before + 1, "One draft choice adds exactly one physical copy")
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Starter choice continues to ordinary input")
	for id: int in state.expansion.hand:
		expect_true(id > 0, "Opening hand draws only after the starter choice")
	expect_equal(state.expansion.normal_placements, 0, "Draft is not a placement")
	var after: String = StateNormalizer.fingerprint(state)
	button.pressed.emit()
	expect_equal(StateNormalizer.fingerprint(state), after, "Repeated click cannot grant another tile")
	controller.free()
	return true


func exact_options_and_mechanical_help() -> bool:
	var controller: GameController = _controller()
	var choice: PendingChoice = controller.session.state.pending_choice
	for index: int in range(choice.options.size()):
		var tile: TileDefinition = controller.session.content.get_tile(StringName(choice.options[index]["definition_id"]))
		var button: Button = controller.choice_presenter.option_buttons[index]
		expect_true(button.text.begins_with(tile.display_name), "Saved offer order and design names remain exact")
		expect_true(button.text.contains("1 copy") and not button.text.contains("2 copies"), "Draft quantity differs visibly from a Normal Tile Reward")
		expect_true(button.text.contains(ChoiceText.tile_help(tile)), "Each choice supplies mechanical help")
		var command: PlayerCommand = controller.choice_presenter.command_for_option(index)
		expect_true(command is ResolveTileDraftCommand, "One click submits dedicated typed intent")
		expect_equal(command.get("option_index"), index, "Exact persisted option selected")
	controller.free()
	return true


func _title(kind: String, expected: String) -> bool:
	var controller: GameController = _controller()
	controller.session.state.pending_choice.context["draft_type"] = kind
	controller.choice_presenter.sync(controller.session.state, controller.session.content)
	expect_equal(controller.choice_presenter.title_label.text, expected, "Subtype has a clear compact heading")
	controller.free()
	return true


func cadence_title() -> bool:
	return _title("cadence", "Tile Draft")


func entry_title() -> bool:
	return _title("act_entry", "New possibilities")


func next_draft_hud_uses_rules_query() -> bool:
	var controller: GameController = _controller()
	controller.choice_presenter.option_buttons[0].pressed.emit()
	var state: RunState = controller.session.state
	var next: int = TileDraftService.next_draft_placement(state, controller.session.content.get_config())
	expect_equal(next, 2, "First cadence follows placement two")
	expect_true(controller.shell.side_label.text.contains("Next Tile Draft: after placement %d" % next), "HUD displays the authoritative next-draft query")
	controller.free()
	return true


func final_act_has_no_placement_26_draft() -> bool:
	var controller: GameController = _controller()
	controller.choice_presenter.option_buttons[0].pressed.emit()
	var state: RunState = controller.session.state
	state.expansion.current_act = 3
	state.expansion.normal_placements = 24
	controller._sync()
	expect_equal(TileDraftService.next_draft_placement(state, controller.session.content.get_config()), 0, "No new draft follows the final normal placement")
	expect_true(controller.shell.side_label.text.contains("No more Tile Drafts this Act"), "HUD does not promise a placement-26 draft")
	controller.free()
	return true


func pending_draft_locks_gameplay() -> bool:
	var controller: GameController = _controller()
	expect_true(controller.confirm_button.disabled and controller.shell.survey_button.disabled, "Draft blocks unrelated gameplay")
	for button: Button in controller.hand_buttons:
		expect_true(button.disabled, "Empty opening hand cannot issue commands")
	expect_true(not controller.choice_presenter.option_buttons[0].disabled, "One-click draft choice remains available")
	controller.free()
	return true


func draft_rendering_does_not_reroll() -> bool:
	var controller: GameController = _controller()
	var state: RunState = controller.session.state
	var before: String = StateNormalizer.fingerprint(state)
	for iteration: int in range(3):
		controller.choice_presenter.sync(state, controller.session.content)
		controller.choice_presenter.command_for_option(0)
	expect_equal(StateNormalizer.fingerprint(state), before, "Rendering saved options never rolls another offer")
	controller.free()
	return true


func entry_draft_hud_starts_at_two() -> bool:
	var controller: GameController = _controller()
	var state: RunState = controller.session.state
	state.expansion.current_act = 2
	state.expansion.normal_placements = 18
	state.act_transition = ActTransitionState.new()
	state.act_transition.incoming_act = 2
	state.act_transition.advanced = true
	state.pending_choice.context["draft_type"] = "act_entry"
	controller._sync()
	expect_equal(controller.shell.act_label.text, "Entering Act II", "Transition does not label outgoing placements as incoming play")
	expect_true(controller.shell.side_label.text.contains("Next Tile Draft: after placement 2"), "Authoritative transition-aware query starts the new cadence at two")
	controller.free()
	return true


func no_reward_threshold_has_no_reward_cue() -> bool:
	var controller: GameController = _controller()
	var config: RunConfig = controller.session.content.get_config()
	var no_reward_index: int = config.track_threshold_reward_kinds.find(&"none")
	var report: ResolutionResult = ResolutionResult.new()
	report.cues.append({"kind": "track_threshold_crossed", "details": {"threshold": config.track_thresholds[no_reward_index]}})
	controller._play_cues(report)
	expect_true(not controller.shell.feedback_label.text.to_lower().contains("threshold"), "No-reward thresholds do not announce reward-like feedback")
	var rewarded_index: int = config.track_threshold_reward_kinds.find(&"training_reward")
	report.cues[0]["details"]["threshold"] = config.track_thresholds[rewarded_index]
	controller._play_cues(report)
	expect_true(controller.shell.feedback_label.text.to_lower().contains("threshold"), "Reward-bearing thresholds retain feedback")
	controller.free()
	return true
