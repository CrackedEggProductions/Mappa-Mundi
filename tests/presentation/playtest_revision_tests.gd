extends "res://tests/framework/test_suite.gd"
## Revised geography stays authoritative; panels use the actual inherited theme.

const Acquisition = preload("res://tests/fixtures/phase_five_factory.gd")


func tests() -> Array[Callable]:
	return [parchment_body_contrast, opening_environment_visible, environment_inspection,
		riverside_occupied_preview, woodland_occupied_preview, junction_inspection,
		revised_specialist_descriptions]


func _controller() -> GameController:
	var controller: GameController = GameController.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(controller)
	controller.start_run(1010)
	return controller


func parchment_body_contrast() -> bool:
	var controller: GameController = _controller()
	controller.show_charter()
	var body: RichTextLabel = controller.shell.notice_text
	expect_equal(body.get_theme_color("default_color"), Color("30271e"), "Charter body inherits dark ink")
	controller.dismiss_notice()
	var state: RunState = controller.session.state
	state.expansion.current_act = 2
	CharterRules.select_ordinary(state, controller.session.content, 2)
	CharterRules.select_grand(state, controller.session.content)
	controller.show_charter()
	expect_equal(body.get_theme_color("default_color"), Color("30271e"), "Act II and forecast use dark ink")
	controller.dismiss_notice()
	CharterRules.reveal_grand(state)
	controller.show_charter()
	expect_equal(body.get_theme_color("default_color"), Color("30271e"), "Exact Grand requirements use dark ink")
	controller.free()
	return true


func opening_environment_visible() -> bool:
	var controller: GameController = _controller()
	var state: RunState = controller.session.state
	expect_equal(controller.board.tiles.size(), 9, "New Run renders the full environment")
	controller.fit_board()
	for id: int in state.expansion.hand:
		var definition: TileDefinition = controller.session.content.get_tile(PhysicalTileRules.find_copy(state, id).definition_id)
		expect_true(definition.player_drawable and not definition.setup_environment, "Opening hand excludes environmental River")
	expect_equal(state.expansion.normal_placements, 0, "Displaying environment consumes no turn")
	controller.free()
	return true


func environment_inspection() -> bool:
	var controller: GameController = _controller()
	var text: String = PresentationQueries.inspect_tile(controller.session.state, controller.session.content, Vector2i.DOWN)
	expect_true(text.contains("Setup environment") and text.contains("9 tiles"), "Inspection identifies environment and connected size")
	expect_true(not text.contains("River · 9 tiles · unfinished"), "River is not an unfinished obligation")
	controller.free()
	return true


func _overlay_preview(id: StringName, expected_edge: int) -> bool:
	var controller: GameController = _controller()
	var state: RunState = controller.session.state
	var copy_id: int = Acquisition.acquire_hand(state, id)
	controller.select_copy(copy_id)
	expect_true(not controller.options.is_empty(), "Generated environment offers legal overlay targets")
	if controller.options.is_empty():
		controller.free()
		return true
	controller.select_option(0)
	var option: PlacementOption = controller.preview
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(state.expansion.board.get_cell(option.coordinate) != null, "River interaction targets occupied environment")
	expect_equal(option.placement_mode, DomainTypes.PlacementMode.TRANSFORMATION, "Overlay uses authoritative Transformation mode")
	controller.cancel_preview()
	expect_equal(StateNormalizer.fingerprint(state), before, "Overlay cancellation is pure")
	controller.select_option(0)
	expect_true(controller.confirm_preview().is_valid, "Exact overlay intent commits through controller")
	var cell: BoardCellState = state.expansion.board.get_cell(option.coordinate)
	expect_true(expected_edge in cell.effective_edges, "Added bank geography appears")
	expect_true(DomainTypes.EdgeType.RIVER in cell.effective_edges, "River stays visible")
	expect_equal(state.expansion.normal_placements, 1, "One normal placement consumed")
	controller.free()
	return true


func riverside_occupied_preview() -> bool:
	return _overlay_preview(&"tile.riverside_hamlet", DomainTypes.EdgeType.SETTLEMENT)


func woodland_occupied_preview() -> bool:
	return _overlay_preview(&"tile.woodland_river", DomainTypes.EdgeType.FOREST)


func junction_inspection() -> bool:
	var controller: GameController = _controller()
	var state: RunState = controller.session.state
	var id: int = Acquisition.acquire_hand(state, &"tile.road_junction")
	controller.select_copy(id)
	expect_true(not controller.options.is_empty(), "Junction can terminate Founding Road")
	if not controller.options.is_empty():
		controller.select_option(0)
		var coordinate: Vector2i = controller.preview.coordinate
		expect_true(controller.confirm_preview().is_valid, "Junction commits")
		var text: String = PresentationQueries.inspect_tile(state, controller.session.content, coordinate)
		expect_true(text.contains("Roads terminate here") and text.contains("Trade continues"), "Inspection explains physical/commercial distinction")
	controller.free()
	return true


func revised_specialist_descriptions() -> bool:
	expect_true(ChoiceText.description(&"specialist.riverkeeper").begins_with("Forest touching River"), "Riverkeeper explains revised host")
	expect_true(ChoiceText.description(&"specialist.harbormaster").begins_with("Settlement touching River"), "Harbormaster explains revised host")
	expect_true(not ChoiceText.description(&"").contains("Forest or River"), "Generic Steward no longer claims River eligibility")
	return true
