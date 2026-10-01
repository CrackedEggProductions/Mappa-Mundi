extends SceneTree
## Automated viewport mouse events, not a human/manual playtest.

var controller: GameController
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _frames() -> void:
	for index: int in range(3):
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)


func _mouse(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	root.warp_mouse(at)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.position = at
	press.button_index = button
	press.pressed = true
	root.push_input(press, true)
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)
	await _frames()


func _click(control: Control) -> void:
	await _mouse(control.get_global_rect().get_center())


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text and (node as Button).is_visible_in_tree():
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(int(args[0]), int(args[1])) if args.size() >= 2 else Vector2i(1280, 720)
	controller = GameController.new()
	root.add_child(controller)
	await _frames()
	controller._seed.text = "1"
	await _click(_find_button(controller, "New Run"))
	_check(controller.session != null, "Mouse New Run starts a session")
	if controller.session == null:
		quit(1)
		return
	_check(controller.session.state.pending_choice.kind == &"tile_draft", "New Run opens the starter draft")
	await _click(controller.choice_presenter.charter_button)
	_check(controller.charter_popout.visible and controller.choice_presenter.visible, "Starter draft keeps its presenter beneath Charter inspection")
	await _click(controller.charter_popout.close_button)
	await _click(controller.choice_presenter.option_buttons[0])
	_check(controller.session.state.phase == GamePhase.Type.TURN_INPUT, "One mouse draft choice draws the opening hand")
	await _click(controller.hand_buttons[0])
	_check(controller.selected_copy_id != 0 and not controller.options.is_empty(), "Mouse hand selection queries targets")
	await _click(controller.shell.rotate_right)
	var option: PlacementOption = controller.options[0]
	var board_point: Vector2 = controller.board.get_global_transform_with_canvas() * (Vector2(option.coordinate) * BoardView.TILE_SIZE)
	var point: Vector2 = controller.shell.board_container.get_global_rect().position + board_point
	await _mouse(point)
	_check(controller.preview != null, "Mouse board click creates a preview")
	var before: String = StateNormalizer.fingerprint(controller.session.state)
	await _click(controller.cancel_button)
	_check(controller.preview == null and StateNormalizer.fingerprint(controller.session.state) == before, "Mouse Cancel leaves run unchanged")
	await _mouse(point)
	await _click(controller.confirm_button)
	_check(controller.session.state.expansion.normal_placements == 1, "Mouse Confirm commits one placement")
	if controller.session.state.pending_choice != null:
		await _click(controller.choice_presenter.decline_button)
		_check(controller.session.state.pending_choice == null, "Mouse decline resolves optional assignment")
	var board_rect: Rect2 = controller.shell.board_container.get_global_rect()
	await _click(controller.shell.charter_button)
	_check(controller.shell.board_container.get_global_rect() == board_rect, "Charter opening does not reserve board width")
	_check(controller.charter_popout.visible, "Mouse opens authoritative Charter details")
	await _click(controller.charter_popout.close_button)
	_check(not controller.charter_popout.visible, "Mouse dismisses cosmetic Charter panel")
	await _click(controller.hand_buttons[0])
	await _click(controller.shell.reserve_actions[0])
	_check(controller.session.state.expansion.reserve_id != 0, "Mouse Reserve stores a physical tile")
	await _click(controller.hand_buttons[0])
	var charges: int = controller.session.state.expansion.survey_charges
	await _click(controller.shell.survey_button)
	_check(controller.session.state.expansion.survey_charges == charges - 1, "Mouse Survey spends one charge")
	var zoom_before: Vector2 = controller.board.camera.zoom
	await _mouse(controller.shell.board_container.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
	_check(controller.board.camera.zoom != zoom_before, "Mouse wheel zooms board camera")
	await _click(controller.shell.fit_button)
	_check(controller.board.camera.zoom.x > 0, "Mouse Fit Board remains available")
	var zoom: float = controller.board.camera.zoom.x
	await _click(controller.shell.zoom_in_button)
	_check(controller.board.camera.zoom.x > zoom, "Visible Zoom+ button")
	await _click(controller.shell.zoom_out_button)
	_check(is_equal_approx(controller.board.camera.zoom.x, zoom), "Visible Zoom− button")
	_check(controller.shell.relic_header.is_visible_in_tree() and controller.shell.steward_header.is_visible_in_tree(), "Compact Relic and Steward panels visible")
	_check(controller.shell.toast_panel.visible, "Recent meaningful action has event feedback")
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(root.size))
	for control: Control in [controller.shell.charter_button, controller.confirm_button, controller.hand_buttons[2], controller.shell.survey_button]:
		_check(viewport_rect.encloses(control.get_global_rect()), "Essential control fits responsive viewport")
	_check(controller.shell.board_container.size.x >= root.size.x - 30, "Closed Charter leaves full central width")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/ui-usability-%dx%d-mouse-smoke.png" % [root.size.x, root.size.y])
	print("MOUSE EVENT RESULT: %d checks, %d failures at %dx%d" % [checks, failures.size(), root.size.x, root.size.y])
	quit(0 if failures.is_empty() else 1)
