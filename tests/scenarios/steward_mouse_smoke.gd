extends "res://tests/scenarios/presentation_mouse_smoke.gd"
## Natural seed/hand and real viewport mouse events; no gameplay fixture mutations.


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(int(args[0]), int(args[1])) if args.size() >= 2 else Vector2i(1280, 720)
	var suffix: String = args[2] if args.size() >= 3 else str(Time.get_unix_time_from_system())
	for decline: bool in [false, true]:
		controller = GameController.new()
		root.add_child(controller)
		await _frames()
		controller._seed.text = "1"
		await _click(_find_button(controller, "New Run"))
		await _click(controller.choice_presenter.option_buttons[0])
		var state: RunState = controller.session.state
		_check(state.specialists.pieces.size() == 2, "Two starting physical Stewards")
		for piece: SpecialistPieceState in state.specialists.pieces:
			_check(piece.role_definition_id == &"" and piece.status == SpecialistPieceState.Status.AVAILABLE,
				"Starting piece is generic and available")
			print("STEWARD BEFORE: id=", piece.piece_id, " role=generic status=AVAILABLE target=", piece.assigned_target_id)
		var slot: int = -1
		for index: int in range(state.expansion.hand.size()):
			if PhysicalTileRules.find_copy(state, state.expansion.hand[index]).definition_id == &"tile.hamlet_edge":
				slot = index
		_check(slot >= 0, "Natural opening hand contains Hamlet Edge")
		if slot < 0:
			quit(1)
			return
		await _click(controller.hand_buttons[slot])
		for rotation: int in range(4):
			if controller.selected_rotation == 0:
				break
			await _click(controller.shell.rotate_right)
		var coordinate: Vector2i = Vector2i(1, 1)
		var board_point: Vector2 = controller.board.get_global_transform_with_canvas() * (Vector2(coordinate) * BoardView.TILE_SIZE)
		await _mouse(controller.shell.board_container.get_global_rect().position + board_point)
		_check(controller.preview != null and controller.preview.coordinate == coordinate and controller.preview.rotation == 0,
			"Mouse previews Hamlet Edge at (1,1), rotation 0")
		await _click(controller.confirm_button)
		_check(state.pending_choice != null and state.pending_choice.kind == &"specialist_assignment", "Local assignment pending")
		if state.pending_choice == null:
			quit(1)
			return
		var target: int = state.features.component_at(coordinate, DomainTypes.FeatureType.SETTLEMENT).lineage_id
		var feature: CurrentFeature = SpecialistRules.find_feature(TopologyService.rebuild(state), target)
		print("SETTLEMENT: tile=tile.hamlet_edge coordinate=(1,1) rotation=0 lineage=", target,
			" open_exits=", feature.open_exits, " occupied=", SpecialistRules.occupied(state, 1, target))
		print("AFFECTED: ", state.resolution.affected_targets)
		print("CANDIDATES: ", SpecialistRules.assignment_options(state, state.resolution.affected_targets))
		print("PENDING OPTIONS: ", state.pending_choice.options)
		_check(feature.open_exits == 1 and not SpecialistRules.occupied(state, 1, target), "Unfinished unoccupied Settlement")
		_check(state.pending_choice.options.size() == 2 and controller.choice_presenter.option_buttons.size() == 2,
			"Both authoritative generic options reach presenter")
		var readable: bool = true
		for button: Button in controller.choice_presenter.option_buttons:
			print("RENDERED OPTION: ", button.text, " rect=", button.get_global_rect())
			var usable: bool = button.is_visible_in_tree() and not button.disabled and button.size.x >= 300 and button.size.y <= 100
			readable = readable and usable
			_check(usable and button.text.begins_with("Steward") and button.text.contains("Settlement"), "Visible readable generic Steward action")
		_check(controller.choice_presenter.decline_button.is_visible_in_tree(), "Decline remains visible")
		await RenderingServer.frame_post_draw
		var path: String = "res://builds/steward-%dx%d-%s-%s.png" % [root.size.x, root.size.y, suffix, "decline" if decline else "assign"]
		assert(not FileAccess.file_exists(path), "Use a fresh capture suffix")
		_check(root.get_texture().get_image().save_png(path) == OK, "Assignment capture saved")
		if readable:
			await _click(controller.choice_presenter.decline_button if decline else controller.choice_presenter.option_buttons[0])
			_check(state.phase == GamePhase.Type.TURN_INPUT and state.pending_choice == null, "Real mouse choice resumes resolution")
			_check(state.specialists.pieces[0].status == (0 if decline else 1) and state.specialists.pieces[1].status == 0,
				"Exactly chosen physical piece assigned, or both available on Decline")
			_check(controller.shell.steward_header.text == ("Stewards (2/2)" if decline else "Stewards (1/2)"), "HUD reflects available/total")
			_check(state.expansion.hand.count(0) == 0 and state.expansion.normal_placements == 1, "First placement refills without cadence draft")
		controller.free()
		await _frames()
	print("STEWARD MOUSE RESULT: %d checks, %d failures at %dx%d" % [checks, failures.size(), root.size.x, root.size.y])
	quit(0 if failures.is_empty() else 1)
