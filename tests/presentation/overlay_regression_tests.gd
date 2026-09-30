extends "res://tests/framework/test_suite.gd"
## Information is a presentation layer, never a PendingChoice continuation.


func tests() -> Array[Callable]:
	return [tooltip_and_popup_contrast, information_surface_contrast, dark_information_contrast,
		starter_inspection_preserves_choice, repeated_toggles_acquire_once,
		escape_preserves_required_choice, normal_turn_inspection_is_pure,
		inspection_save_restores_exact_draft, inspection_blocks_choice_submission]


func _controller() -> GameController:
	var c: GameController = GameController.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(c)
	c.start_run(1)
	return c


func _contrast(a: Color, b: Color) -> float:
	var first: float = a.srgb_to_linear().get_luminance()
	var second: float = b.srgb_to_linear().get_luminance()
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)


func tooltip_and_popup_contrast() -> bool:
	var c: GameController = _controller()
	for kind: String in ["TooltipPanel", "PopupPanel", "PopupMenu"]:
		var panel: StyleBoxFlat = c.shell.get_theme_stylebox("panel", kind) as StyleBoxFlat
		expect_true(panel != null and panel.bg_color.a == 1.0 and panel.bg_color.r > 0.8, "Opaque parchment: " + kind)
		var label_type: String = "PopupMenu" if kind == "PopupMenu" else "TooltipLabel"
		var ink: Color = c.shell.get_theme_color("font_color", label_type)
		expect_equal(ink, AlphaTheme.INK, "Explicit dark informational ink")
		expect_true(_contrast(ink, panel.bg_color) >= 4.5, "Readable body/headings")
		var secondary: Color = c.shell.get_theme_color("font_disabled_color", label_type)
		expect_true(_contrast(secondary, panel.bg_color) >= 4.5, "Readable secondary/disabled popup text")
	c.free()
	return true


func information_surface_contrast() -> bool:
	var c: GameController = _controller()
	for panel: PanelContainer in [c.shell.inspection_panel, c.shell.toast_panel, c.shell.notice_panel, c.charter_popout]:
		expect_equal(panel.theme_type_variation, &"ParchmentInfoOverlay", "Explicit information surface")
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		expect_equal(style.bg_color, AlphaTheme.PARCHMENT, "Parchment background")
		expect_equal(panel.get_theme_color("font_color", "Label"), AlphaTheme.INK, "Child labels resolve dark ink")
		expect_equal(panel.get_theme_color("default_color", "RichTextLabel"), AlphaTheme.INK, "Rich text resolves dark ink")
	var close: Button = c.charter_popout.close_button
	expect_equal(close.get_theme_color("font_focus_color"), AlphaTheme.INK, "Focused close glyph stays dark on parchment")
	var disabled: StyleBoxFlat = close.get_theme_stylebox("disabled") as StyleBoxFlat
	expect_true(_contrast(close.get_theme_color("font_disabled_color"), disabled.bg_color) >= 4.5, "Disabled information actions remain readable")
	c.free()
	return true


func dark_information_contrast() -> bool:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme = AlphaTheme.information(true)
	panel.theme_type_variation = &"DarkInfoOverlay"
	var label: Label = Label.new()
	panel.add_child(label)
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	expect_equal(label.get_theme_color("font_color"), AlphaTheme.LIGHT_INK, "Dark surface pairs with light inherited text")
	expect_true(_contrast(label.get_theme_color("font_color"), style.bg_color) >= 4.5, "Readable intentional dark overlay")
	panel.free()
	return true


func starter_inspection_preserves_choice() -> bool:
	var c: GameController = _controller()
	var state: RunState = c.session.state
	var before: String = StateNormalizer.fingerprint(state)
	var offered: Array[Dictionary] = state.pending_choice.options.duplicate(true)
	var buttons: Array[Button] = c.choice_presenter.option_buttons.duplicate()
	c.choice_presenter.charter_button.pressed.emit()
	expect_true(c.charter_popout.is_visible_in_tree(), "Charter visible")
	expect_true(c.choice_presenter.is_visible_in_tree() and c.shell.modal_layer.visible, "Same mandatory choice stays underneath")
	expect_true(c.shell.charter_layer.get_index() > c.shell.modal_layer.get_index(), "Information receives input above the modal")
	expect_true(not c.board.interaction_enabled and not c._input_available(), "No normal board input")
	for button: Button in c.hand_buttons + c.shell.reserve_actions + [c.shell.survey_button, c.confirm_button]:
		expect_true(button.disabled, "Ordinary action disabled")
	expect_equal(state.expansion.hand, [0, 0, 0], "No early opening hand")
	c.charter_popout.close_button.pressed.emit()
	expect_equal(c.choice_presenter.option_buttons, buttons, "No rebuilding/duplicate presenter")
	expect_equal(state.pending_choice.options, offered, "Exact persisted offer and order")
	expect_equal(StateNormalizer.fingerprint(state), before, "No IDs, inventory, phase or RNG changes")
	expect_true(c.choice_presenter.charter_button.has_focus(), "Focus returns to pending choice")
	buttons[0].pressed.emit()
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Only choosing resumes setup")
	expect_equal(state.expansion.hand.count(0), 0, "Opening hand drawn after choice")
	c.free()
	return true


func repeated_toggles_acquire_once() -> bool:
	var c: GameController = _controller()
	var before: String = StateNormalizer.fingerprint(c.session.state)
	var copy_count: int = c.session.state.tile_copies.size()
	var buttons: Array[Button] = c.choice_presenter.option_buttons.duplicate()
	for index: int in range(3):
		c.shell.charter_button.pressed.emit()
		c.shell.charter_button.pressed.emit()
		expect_equal(StateNormalizer.fingerprint(c.session.state), before, "Repeated informational toggles are pure")
		expect_equal(c.choice_presenter.option_buttons, buttons, "Identical choice buttons")
	buttons[0].pressed.emit()
	buttons[0].pressed.emit()
	expect_equal(c.session.state.tile_copies.size(), copy_count + 1, "One physical acquisition despite repeat submit")
	c.free()
	return true


func escape_preserves_required_choice() -> bool:
	var c: GameController = _controller()
	var before: String = StateNormalizer.fingerprint(c.session.state)
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	c.show_charter()
	c._unhandled_key_input(event)
	expect_true(not c.charter_popout.visible and c.choice_presenter.visible, "Escape closes Charter only")
	c._unhandled_key_input(event)
	expect_true(c.choice_presenter.visible and c.shell.modal_layer.visible, "Second Escape cannot dismiss mandatory choice")
	expect_equal(StateNormalizer.fingerprint(c.session.state), before, "Escape preserves state and RNG")
	c.free()
	return true


func normal_turn_inspection_is_pure() -> bool:
	var c: GameController = _controller()
	c.choice_presenter.option_buttons[0].pressed.emit()
	var before: String = StateNormalizer.fingerprint(c.session.state)
	c.show_charter()
	expect_true(c.board.interaction_enabled, "Ordinary board remains available outside popout")
	c.close_charter()
	expect_true(c._input_available(), "Normal turn input restored")
	expect_equal(StateNormalizer.fingerprint(c.session.state), before, "No gameplay side effects")
	c.free()
	return true


func inspection_save_restores_exact_draft() -> bool:
	var c: GameController = _controller()
	c.show_charter()
	var before: String = StateNormalizer.fingerprint(c.session.state)
	var saved: SerializationResult = RunSerializer.serialize(c.session.state, c.session.content)
	var restored: DeserializationResult = RunSerializer.deserialize(saved.json_text, c.session.content)
	expect_true(restored.validation.is_valid, "Pending inspection snapshot loads")
	expect_equal(StateNormalizer.fingerprint(restored.state), before, "Save/load preserves offer, RNG and undrawn hand")
	var loaded: GameController = _controller()
	loaded.session = GameSession.new(restored.state, c.session.content)
	loaded._sync()
	expect_true(loaded.choice_presenter.visible and not loaded.charter_popout.visible, "Cosmetic overlay need not persist")
	expect_equal(loaded.session.state.pending_choice.options, c.session.state.pending_choice.options, "Restored exact offer")
	loaded.free()
	c.free()
	return true


func inspection_blocks_choice_submission() -> bool:
	var c: GameController = _controller()
	var before: String = StateNormalizer.fingerprint(c.session.state)
	c.show_charter()
	c.choice_presenter.option_buttons[0].pressed.emit()
	expect_true(not c.submit(c.choice_presenter.command_for_option(0)).is_valid, "Controller also rejects commands behind inspection")
	expect_equal(StateNormalizer.fingerprint(c.session.state), before, "Underlying suspended choice cannot submit")
	c.close_charter()
	c.choice_presenter.option_buttons[0].pressed.emit()
	expect_equal(c.session.state.phase, GamePhase.Type.TURN_INPUT, "Inspection does not poison the next real selection")
	c.free()
	return true
