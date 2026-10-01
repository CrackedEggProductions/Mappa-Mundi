extends "res://tests/scenarios/presentation_mouse_smoke.gd"
## Actual viewport input and captures; no human manual-play claim.

var capture_prefix: String


func _capture(suffix: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	var path: String = capture_prefix + "-" + suffix + ".png"
	if FileAccess.file_exists(path):
		var backup: String = path + ".bak-" + str(Time.get_unix_time_from_system())
		assert(DirAccess.rename_absolute(path, backup) == OK, "Prior capture must be backed up")
	_check(root.get_texture().get_image().save_png(path) == OK, "Capture " + suffix)


func _escape() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key, true)
	key = key.duplicate() as InputEventKey
	key.pressed = false
	root.push_input(key, true)
	await _frames()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(int(args[0]), int(args[1])) if args.size() >= 2 else Vector2i(1280, 720)
	capture_prefix = "res://builds/overlay-fix-%dx%d" % [root.size.x, root.size.y]
	controller = GameController.new()
	root.add_child(controller)
	await _frames()
	controller._seed.text = "1"
	await _click(_find_button(controller, "New Run"))
	var state: RunState = controller.session.state
	var before: String = StateNormalizer.fingerprint(state)
	var options: Array[Dictionary] = state.pending_choice.options.duplicate(true)
	var buttons: Array[Button] = controller.choice_presenter.option_buttons.duplicate()
	_check(controller.choice_presenter.is_visible_in_tree(), "Starter Draft visible")
	await _capture("starter")
	await _click(controller.choice_presenter.charter_button)
	_check(controller.charter_popout.is_visible_in_tree(), "Mouse Inspect Charter opens details")
	_check(controller.choice_presenter.is_visible_in_tree() and controller.shell.modal_layer.visible, "Pending presenter stays under information layer")
	_check(not controller.board.interaction_enabled and controller.shell.survey_button.disabled, "No ordinary actions")
	_check(controller.charter_popout.get_global_rect().size.y > 200, "Charter has real visible bounds")
	await _capture("starter-charter")
	await _click(buttons[0])
	_check(StateNormalizer.fingerprint(state) == before, "Information layer blocks clicks into the underlying draft")
	await _click(controller.charter_popout.close_button)
	_check(not controller.charter_popout.visible, "Mouse close reaches top layer")
	_check(controller.choice_presenter.is_visible_in_tree(), "Draft immediately visible after close")
	_check(controller.choice_presenter.option_buttons == buttons and state.pending_choice.options == options, "Exact same buttons and offer")
	await _capture("starter-returned")
	await _click(controller.choice_presenter.charter_button)
	await _escape()
	_check(not controller.charter_popout.visible and controller.choice_presenter.visible, "Escape closes Charter only")
	await _escape()
	_check(controller.choice_presenter.visible and state.pending_choice != null, "Escape cannot dismiss required choice")
	_check(StateNormalizer.fingerprint(state) == before and state.expansion.hand == [0, 0, 0], "Inspection leaves RNG, copies and hand untouched")
	await _click(buttons[0])
	_check(state.phase == GamePhase.Type.TURN_INPUT and state.expansion.hand.count(0) == 0, "Real choice alone continues setup")
	before = StateNormalizer.fingerprint(state)
	await _click(controller.shell.charter_button)
	_check(controller.charter_popout.visible, "Normal turn Charter opens")
	await _click(controller.charter_popout.close_button)
	_check(controller._input_available() and StateNormalizer.fingerprint(state) == before, "Normal turn returns unchanged")
	# Mouse-accessible rules/details card, followed by Godot's real automatic tooltip.
	await _click(controller.shell.steward_slot_buttons[0])
	_check(controller.shell.inspection_panel.visible, "Contextual detail card opens")
	await _capture("information-card")
	await _click(_find_button(controller.shell.inspection_panel, "Close details"))
	var point: Vector2 = controller.hand_buttons[0].get_global_rect().get_center()
	root.warp_mouse(point)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await create_timer(1.2).timeout
	await _capture("tooltip")
	print("OVERLAY MOUSE RESULT: ", checks, " checks, ", failures.size(), " failures at ", root.size)
	quit(0 if failures.is_empty() else 1)
