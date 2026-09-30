extends "res://tests/framework/test_suite.gd"


func tests() -> Array[Callable]:
	return [act_hud_and_progress, four_tracks_and_active_thresholds, fulfilled_condition_summary,
		charter_popout_toggles_without_domain_changes, charter_overlay_does_not_reserve_column,
		charter_uses_structured_progress, forecast_keeps_secret, exact_grand_reveal,
		parchment_dark_ink, relic_slots_and_details, steward_statuses_and_details,
		hand_art_and_selected_border, reserve_and_bag_status, camera_buttons,
		preview_action_states, toast_dismissal_is_pure, toast_has_automatic_timeout,
		draft_cards_are_one_click, no_debug_sidebar, typography_is_shared]


func _controller() -> GameController:
	var result: GameController = GameController.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(result)
	result.start_run(1)
	result.choice_presenter.option_buttons[0].pressed.emit()
	return result


func act_hud_and_progress() -> bool:
	var c: GameController = _controller()
	expect_equal(c.shell.act_label.text, "Act I", "Act comes from live state")
	expect_equal(c.shell.act_progress.max_value, 18.0, "Limit from RunConfig")
	expect_equal(c.shell.act_progress.value, 0.0, "Normal placements represented")
	expect_true(c.shell.next_draft_label.text.contains("2 placements"), "Next draft from canonical query")
	c.free()
	return true


func four_tracks_and_active_thresholds() -> bool:
	var c: GameController = _controller()
	c.session.state.features.tracks.values = [19, 40, 70, 120]
	c._sync()
	for index: int in range(4):
		expect_equal(c.shell.track_value_labels[index].text, str(c.session.state.features.tracks.values[index]), "Uncapped actual value")
	for index: int in range(3):
		expect_true(c.shell.track_reward_labels[index].text.begins_with(["40", "70", "100"][index]), "Only next active reward")
	expect_equal(c.shell.track_reward_labels[3].text, "Rewards complete", "No fictitious post100 reward")
	c.free()
	return true


func fulfilled_condition_summary() -> bool:
	var c: GameController = _controller()
	c.session.state.charters.act_one_id = &"charter.a1_growing_realm"
	c.session.state.features.tracks.values[0] = 20
	c._sync()
	expect_equal(c.shell.charter_summary.text, "Growing Realm", "Objective title")
	expect_equal(c.shell.charter_conditions_label.text, "1 / 2 conditions", "Counts Fulfill conditions, not Exceed")
	c.free()
	return true


func charter_popout_toggles_without_domain_changes() -> bool:
	var c: GameController = _controller()
	var before: String = StateNormalizer.fingerprint(c.session.state)
	c.shell.charter_button.pressed.emit()
	expect_true(c.charter_popout.visible, "Book opens popout")
	c.charter_popout.close_button.pressed.emit()
	expect_true(not c.charter_popout.visible, "Close dismisses it")
	c.show_charter()
	c.shell.charter_button.pressed.emit()
	expect_true(not c.charter_popout.visible, "Book toggles closed")
	expect_equal(StateNormalizer.fingerprint(c.session.state), before, "No gameplay command or RNG")
	c.free()
	return true


func charter_overlay_does_not_reserve_column() -> bool:
	var c: GameController = _controller()
	expect_equal(c.shell.board_container.anchor_right, 1.0, "Board fills central workspace")
	expect_equal(c.shell.charter_layer.get_parent(), c.shell, "Information layer sits above modal input without reserving workspace")
	expect_equal(c.charter_popout.anchor_left, 1.0, "Right anchored popout")
	c.show_charter()
	expect_equal(c.shell.board_container.anchor_right, 1.0, "Opening never shrinks layout")
	c.free()
	return true


func charter_uses_structured_progress() -> bool:
	var c: GameController = _controller()
	c.show_charter()
	var expected: Dictionary = CharterRules.visible_ordinary(c.session.state, c.session.content)
	expect_equal(c.charter_popout.displayed_sections[0], expected, "Exact read-only query data")
	for row: Dictionary in c.charter_popout.condition_rows:
		expect_equal(row.bar.value, minf(row.current, row.target), "Numeric progress maps to bar")
	c.free()
	return true


func _act_two(c: GameController) -> void:
	c.session.state.expansion.current_act = 2
	CharterRules.select_ordinary(c.session.state, c.session.content, 2)
	CharterRules.select_grand(c.session.state, c.session.content)


func forecast_keeps_secret() -> bool:
	var c: GameController = _controller()
	_act_two(c)
	c.show_charter()
	var visible: Dictionary = c.charter_popout.displayed_sections.back()
	expect_true(visible.has("forecast") and not visible.has("charter_id") and not visible.has("progress"), "Forecast model cannot leak hidden ID/requirements")
	c.free()
	return true


func exact_grand_reveal() -> bool:
	var c: GameController = _controller()
	_act_two(c)
	c.session.state.expansion.normal_placements = 11
	CharterRules.reveal_grand(c.session.state)
	c.show_charter()
	expect_true(c.charter_popout.displayed_sections.back().has("progress"), "Exact conditions after authoritative reveal")
	c.free()
	return true


func parchment_dark_ink() -> bool:
	var c: GameController = _controller()
	c.show_charter()
	expect_equal(c.charter_popout.close_button.get_theme_color("font_color"), AlphaTheme.INK, "Parchment uses dark ink")
	for child: Node in c.charter_popout.sections.get_children():
		if child is Label:
			expect_equal((child as Label).get_theme_color("font_color"), AlphaTheme.INK, "Every objective row inherits ink")
	c.free()
	return true


func relic_slots_and_details() -> bool:
	var c: GameController = _controller()
	expect_equal(c.shell.relic_header.text, "Relics (0/2)", "Equipped count and capacity")
	expect_true(c.shell.relic_slot_buttons[0].visible and not c.shell.relic_slot_buttons[2].visible, "Only active slots shown")
	c.shell.relic_slot_buttons[0].pressed.emit()
	expect_true(c.shell.inspection_panel.visible, "Slot inspection by mouse")
	c.free()
	return true


func steward_statuses_and_details() -> bool:
	var c: GameController = _controller()
	expect_equal(c.shell.steward_header.text, "Stewards (2/2)", "Available and total")
	expect_true(c.shell.steward_slot_buttons[0].tooltip_text.contains("Available"), "Status inspectable")
	var piece: SpecialistPieceState = c.session.state.specialists.pieces[0]
	piece.status = SpecialistPieceState.Status.ASSIGNED
	piece.assigned_target_type = DomainTypes.FeatureType.SETTLEMENT
	piece.assigned_target_id = c.session.state.features.components[0].lineage_id
	c._sync_pieces()
	expect_equal(c.shell.steward_header.text, "Stewards (1/2)", "Assigned piece excluded from available")
	expect_true(c.shell.steward_slot_buttons[0].tooltip_text.contains("Assigned:"), "Assignment available without permanent sidebar")
	c.free()
	return true


func hand_art_and_selected_border() -> bool:
	var c: GameController = _controller()
	c.hand_buttons[0].pressed.emit()
	expect_true(c.hand_buttons[0].icon != null, "Existing art or fallback")
	expect_true(c.hand_buttons[0].get_meta("selected"), "Selected state explicit")
	expect_true(c.hand_buttons[0].has_theme_stylebox_override("normal"), "Strong selected border")
	expect_true(not c.hand_buttons[1].get_meta("selected"), "Only selected copy highlighted")
	c.free()
	return true


func reserve_and_bag_status() -> bool:
	var c: GameController = _controller()
	expect_equal(c.shell.reserve_header.text, "Reserve (0/1)", "Baseline capacity")
	c.hand_buttons[0].pressed.emit()
	c.shell.reserve_actions[0].pressed.emit()
	expect_equal(c.shell.reserve_header.text, "Reserve (1/1)", "Live command updates Reserve")
	expect_equal(c.shell.bag_label.text, "Bag\n%d" % c.session.state.expansion.bag.size(), "Bag count actual")
	expect_true(c.shell.survey_button.text.contains(str(c.session.state.expansion.survey_charges)), "Survey charge actual")
	c.free()
	return true


func camera_buttons() -> bool:
	var c: GameController = _controller()
	var before: float = c.board.camera.zoom.x
	c.shell.zoom_in_button.pressed.emit()
	expect_true(c.board.camera.zoom.x > before, "Zoom in by mouse button")
	c.shell.zoom_out_button.pressed.emit()
	expect_true(is_equal_approx(c.board.camera.zoom.x, before), "Zoom out restores scale")
	c.shell.fit_button.pressed.emit()
	c.free()
	return true


func preview_action_states() -> bool:
	var c: GameController = _controller()
	expect_true(c.confirm_button.disabled and c.cancel_button.disabled, "No preview no confirmation")
	c.hand_buttons[0].pressed.emit()
	c.select_option(0)
	expect_true(not c.confirm_button.disabled and not c.cancel_button.disabled, "Authoritative option permits confirmation")
	c.cancel_button.pressed.emit()
	expect_true(c.confirm_button.disabled, "Cancel disables commit")
	c.free()
	return true


func toast_dismissal_is_pure() -> bool:
	var c: GameController = _controller()
	var before: String = StateNormalizer.fingerprint(c.session.state)
	c.shell.show_feedback("Settlement completed!\n+12 Population")
	expect_true(c.shell.toast_panel.visible, "Transient consequence card")
	c.shell.dismiss_feedback()
	expect_true(not c.shell.toast_panel.visible, "Dismissible")
	expect_equal(StateNormalizer.fingerprint(c.session.state), before, "Feedback cannot drive rules")
	c.free()
	return true


func toast_has_automatic_timeout() -> bool:
	var c: GameController = _controller()
	c.shell.show_feedback("Market added to the bag.")
	expect_true(c.shell.toast_timer.one_shot and not c.shell.toast_timer.is_stopped(), "Automatic one-shot expiry")
	c.shell.toast_timer.timeout.emit()
	expect_true(not c.shell.toast_panel.visible, "Expiry hides card")
	c.free()
	return true


func draft_cards_are_one_click() -> bool:
	var c: GameController = GameController.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(c)
	c.start_run(1)
	var count: int = c.session.state.tile_copies.size()
	expect_equal(c.choice_presenter.option_buttons.size(), 3, "Exact offered choices")
	c.choice_presenter.option_buttons[0].pressed.emit()
	expect_equal(c.session.state.tile_copies.size(), count + 1, "One click adds one copy without extra confirmation")
	c.free()
	return true


func no_debug_sidebar() -> bool:
	var c: GameController = _controller()
	expect_true(not c.shell.side_label.visible and not c.shell.tracks_label.visible, "Old flat debug status blocks not displayed")
	expect_true(not c.shell.inspection_panel.visible, "Contextual details start closed")
	c.free()
	return true


func typography_is_shared() -> bool:
	var c: GameController = _controller()
	expect_true(c.shell.theme.default_font is SystemFont, "Shared readable serif with system fallback")
	expect_true(c.shell.theme.has_stylebox("normal", "ConfirmButton"), "Shared action hierarchy")
	c.free()
	return true
