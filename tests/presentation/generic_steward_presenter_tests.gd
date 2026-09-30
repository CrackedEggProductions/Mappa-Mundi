extends "res://tests/framework/test_suite.gd"
## Real opening hand and settled Control layout, not just button existence.


func tests() -> Array[Callable]:
	return [generic_settlement_actions_at_720p, generic_settlement_actions_at_1080p,
		decline_keeps_both_generics_available, saved_generic_offer_remains_actionable,
		completed_settlement_has_no_assignment_modal]


func _opening(size: Vector2i = Vector2i(1280, 720)) -> GameController:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.content_scale_size = Vector2i.ZERO
	tree.root.size = size
	var c: GameController = GameController.new()
	tree.root.add_child(c)
	c.start_run(1)
	c.choice_presenter.option_buttons[0].pressed.emit()
	return c


func _place_hamlet(c: GameController, at: Vector2i = Vector2i(1, 1), rotation: int = 0) -> void:
	for index: int in range(3):
		var copy: TileCopyState = PhysicalTileRules.find_copy(c.session.state, c.session.state.expansion.hand[index])
		if copy.definition_id != &"tile.hamlet_edge":
			continue
		c.hand_buttons[index].pressed.emit()
		for option_index: int in range(c.options.size()):
			if c.options[option_index].coordinate == at and c.options[option_index].rotation == rotation:
				c.select_option(option_index)
				c.confirm_button.pressed.emit()
				return
	assert(false, "Natural seed1 opening must support the exact Hamlet reproduction")


func _layout() -> void:
	for frame: int in range(3):
		await (Engine.get_main_loop() as SceneTree).process_frame


func _readable_options(c: GameController) -> void:
	var choice: PendingChoice = c.session.state.pending_choice
	expect_equal(choice.kind, &"specialist_assignment", "Generic pieces share typed assignment infrastructure")
	expect_equal(c.choice_presenter.option_buttons.size(), 2, "Both physical generic pieces are actionable")
	for index: int in range(c.choice_presenter.option_buttons.size()):
		var button: Button = c.choice_presenter.option_buttons[index]
		expect_true(button.is_visible_in_tree() and not button.disabled, "Action visible and enabled")
		expect_true(button.size.x >= 300 and button.size.y <= 100, "Wrapped text must not collapse to padding width")
		expect_true(c.choice_presenter.get_global_rect().encloses(button.get_global_rect()), "Entire option remains inside visible modal")
		expect_true(button.text.begins_with("Steward") and button.text.contains("Settlement"), "Generic label needs no trained role definition")
		var command: ResolveSpecialistAssignmentCommand = c.choice_presenter.command_for_option(index) as ResolveSpecialistAssignmentCommand
		expect_equal(command.piece_id, choice.options[index].piece_id, "Exact persisted physical piece")
		expect_equal(command.target_id, choice.options[index].target_id, "Exact persisted local target")
	expect_true(c.choice_presenter.decline_button.is_visible_in_tree(), "Optional assignment retains Decline")


func _assign_at_size(size: Vector2i) -> bool:
	var c: GameController = _opening(size)
	_place_hamlet(c)
	var before: String = StateNormalizer.fingerprint(c.session.state)
	await _layout()
	_readable_options(c)
	expect_equal(StateNormalizer.fingerprint(c.session.state), before, "Rendering consumes no RNG or gameplay state")
	var selected: Dictionary = c.session.state.pending_choice.options[0].duplicate()
	c.choice_presenter.option_buttons[0].pressed.emit()
	var pieces: Array[SpecialistPieceState] = c.session.state.specialists.pieces
	expect_equal(pieces[0].piece_id, selected.piece_id, "Chosen physical identity retained")
	expect_equal(pieces[0].assigned_target_id, selected.target_id, "Assigned to exact Settlement lineage")
	expect_equal(pieces[0].status, SpecialistPieceState.Status.ASSIGNED, "Chosen generic assigned")
	expect_equal(pieces[1].status, SpecialistPieceState.Status.AVAILABLE, "Other generic remains available")
	expect_equal(c.shell.steward_header.text, "Stewards (1/2)", "HUD available/total reflects actual assignment")
	expect_equal(c.session.state.phase, GamePhase.Type.TURN_INPUT, "Assignment resumes placement pipeline")
	expect_equal(c.session.state.expansion.hand.count(0), 0, "Refill follows assignment")
	c.free()
	return true


func generic_settlement_actions_at_720p() -> bool:
	return await _assign_at_size(Vector2i(1280, 720))


func generic_settlement_actions_at_1080p() -> bool:
	return await _assign_at_size(Vector2i(1920, 1080))


func decline_keeps_both_generics_available() -> bool:
	var c: GameController = _opening()
	_place_hamlet(c)
	await _layout()
	_readable_options(c)
	c.choice_presenter.decline_button.pressed.emit()
	for piece: SpecialistPieceState in c.session.state.specialists.pieces:
		expect_equal(piece.status, SpecialistPieceState.Status.AVAILABLE, "Decline leaves generic available")
		expect_equal(piece.assigned_target_id, 0, "No hidden assignment")
	expect_equal(c.shell.steward_header.text, "Stewards (2/2)", "HUD preserves both available pieces")
	expect_true(c.session.state.pending_choice == null and not c.choice_presenter.visible, "No duplicate or Decline-only modal")
	expect_equal(c.session.state.phase, GamePhase.Type.TURN_INPUT, "Decline resumes normally")
	c.free()
	return true


func saved_generic_offer_remains_actionable() -> bool:
	var c: GameController = _opening()
	_place_hamlet(c)
	var before: String = StateNormalizer.fingerprint(c.session.state)
	var saved: SerializationResult = RunSerializer.serialize(c.session.state, c.session.content)
	var restored: DeserializationResult = RunSerializer.deserialize(saved.json_text, c.session.content)
	expect_true(restored.validation.is_valid, "Legal generic assignment save loads")
	c.attach_session(GameSession.new(restored.state, c.session.content))
	await _layout()
	_readable_options(c)
	expect_equal(StateNormalizer.fingerprint(c.session.state), before, "Load/render preserves exact offer and RNG")
	c.choice_presenter.option_buttons[1].pressed.emit()
	expect_equal(c.session.state.specialists.pieces[1].status, SpecialistPieceState.Status.ASSIGNED, "Restored second physical option submits")
	expect_equal(c.session.state.specialists.pieces[0].status, SpecialistPieceState.Status.AVAILABLE, "First piece not substituted")
	c.free()
	return true


func completed_settlement_has_no_assignment_modal() -> bool:
	var c: GameController = _opening()
	_place_hamlet(c, Vector2i(0, -1), 2)
	await _layout()
	expect_true(c.session.state.pending_choice == null and not c.choice_presenter.visible, "Genuine zero-option case skips modal in engine")
	expect_equal(c.session.state.phase, GamePhase.Type.TURN_INPUT, "Immediate completion continues to input")
	for piece: SpecialistPieceState in c.session.state.specialists.pieces:
		expect_equal(piece.status, SpecialistPieceState.Status.AVAILABLE, "No last-second assignment")
	c.free()
	return true
