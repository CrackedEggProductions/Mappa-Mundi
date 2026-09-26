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
	root.size = Vector2i(1280, 720)
	controller = GameController.new()
	root.add_child(controller)
	await _frames()
	await _click(_find_button(controller, "New Run"))
	_check(controller.session != null, "Mouse New Run starts a session")
	if controller.session == null:
		quit(1)
		return
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
	await _click(controller.shell.charter_button)
	_check(controller.notice_active, "Mouse opens authoritative Charter details")
	await _click(controller.shell.notice_button)
	_check(not controller.notice_active, "Mouse dismisses cosmetic Charter panel")
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
	print("MOUSE EVENT RESULT: %d checks, %d failures at 1280x720" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
