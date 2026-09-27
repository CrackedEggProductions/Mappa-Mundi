extends "res://tests/framework/test_suite.gd"
## Visual snapshots and camera state are intentionally separate from rules state.

func tests() -> Array[Callable]:
	return [founding_view, negative_coordinates, exact_rotation, source_correction,
		development_badge, upgrade_badge, transformed_geometry, specialist_marker,
		view_rebuild_is_pure, authoritative_targets, expansion_preview_is_pure,
		development_preview_is_pure, transformation_preview, camera_fit,
		coordinate_roundtrip, mapping_and_cache, fallback_thumbnail,
		artwork_stays_behind_badges, long_board_fits, released_pan_does_not_stick]


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	assert(content.load_phase_nine().is_valid)
	return content


func _cell(state: RunState, content: ContentRegistry, at: Vector2i,
		definition_id: StringName = &"tile.open_fields", rotation: int = 0) -> BoardCellState:
	var cell: BoardCellState = BoardCellState.from_definition(content.get_tile(definition_id),
		state.id_allocator.allocate(), at, rotation, 1, 1)
	state.expansion.board.add_cell(cell)
	return cell


func founding_view() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	var board: BoardView = BoardView.new()
	board.sync(state, content, TileArtRegistry.new())
	expect_equal(board.tiles.size(), 9, "Founding and eight environmental River squares are visible")
	expect_equal(board.tiles[Vector2i.ZERO].position, Vector2.ZERO, "Founding origin is centered")
	expect_true(board.tiles[Vector2i.ZERO].mechanical_visible, "Founding uses readable fallback")
	board.free()
	return true


func negative_coordinates() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	_cell(state, content, Vector2i(-2, -3))
	var board: BoardView = BoardView.new()
	board.sync(state, content, TileArtRegistry.new())
	expect_equal(board.tiles[Vector2i(-2, -3)].position, Vector2(-384, -576), "Sparse negatives render directly")
	board.free()
	return true


func exact_rotation() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	_cell(state, content, Vector2i(1, 0), &"tile.forest_edge", 3)
	var tile: TileView = TileView.new()
	tile.configure(state, content, Vector2i(1, 0), TileArtRegistry.new())
	expect_true(is_equal_approx(tile.artwork.rotation, 3.0 * PI / 2.0), "Artwork follows authoritative quarter turns at transform precision")
	expect_equal(tile.displayed_edges, state.expansion.board.get_cell(Vector2i(1, 0)).effective_edges, "Effective overlay is already rotated")
	tile.free()
	return true


func source_correction() -> bool:
	var registry: TileArtRegistry = TileArtRegistry.new()
	expect_equal(registry.art_rotation(&"tile.bending_road"), 1, "N/W study rotates to canonical N/E")
	expect_equal(registry.art_rotation(&"tile.straight_road"), 1, "E/W study rotates to canonical N/S")
	return true


func _badge_case(stage: StringName, expected: String) -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	var development: DevelopmentState = DevelopmentState.new()
	development.stage = stage
	state.expansion.board.get_cell(Vector2i.ZERO).developments.append(development)
	var tile: TileView = TileView.new()
	tile.configure(state, content, Vector2i.ZERO, TileArtRegistry.new())
	expect_equal(tile.development_labels, [expected], "Current Development stage displayed")
	tile.free()
	return true


func development_badge() -> bool:
	return _badge_case(&"market", "Market")


func upgrade_badge() -> bool:
	return _badge_case(&"grand_market", "Grand Market")


func transformed_geometry() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	var cell: BoardCellState = _cell(state, content, Vector2i(1, 0), &"tile.forest_edge")
	cell.geometry_revision = 1
	cell.effective_edges = [DomainTypes.EdgeType.FOREST, DomainTypes.EdgeType.FOREST, DomainTypes.EdgeType.FOREST, DomainTypes.EdgeType.FOREST]
	var tile: TileView = TileView.new()
	tile.configure(state, content, cell.coordinate, TileArtRegistry.new())
	expect_true(tile.mechanical_visible and not tile.artwork.visible, "Current geometry overrides old source artwork")
	expect_equal(tile.displayed_edges, cell.effective_edges, "Uses actual runtime edges")
	tile.free()
	return true


func specialist_marker() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	piece.status = SpecialistPieceState.Status.ASSIGNED
	piece.assigned_target_type = state.features.components[0].feature_type
	piece.assigned_target_id = state.features.components[0].lineage_id
	var tile: TileView = TileView.new()
	tile.configure(state, content, Vector2i.ZERO, TileArtRegistry.new())
	expect_equal(tile.specialist_labels, ["Steward"], "Physical assigned piece is visible")
	tile.free()
	return true


func view_rebuild_is_pure() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	var before: String = StateNormalizer.fingerprint(state)
	var board: BoardView = BoardView.new()
	board.sync(state, content, TileArtRegistry.new())
	board.sync(state, content, TileArtRegistry.new())
	board.free()
	expect_equal(StateNormalizer.fingerprint(state), before, "Rebuild and cleanup do not change rules")
	return true


func authoritative_targets() -> bool:
	var board: BoardView = BoardView.new()
	var option: PlacementOption = PlacementOption.new()
	option.coordinate = Vector2i(-3, 2)
	board.set_options([option])
	expect_true(board.options[0] == option, "Retains complete authoritative intent")
	expect_equal(board.options[0].coordinate, Vector2i(-3, 2), "No presentation legality recomputation")
	board.free()
	return true


func expansion_preview_is_pure() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	var before: String = StateNormalizer.fingerprint(state)
	var options: Array[PlacementOption] = PlacementQueryService.query_for_copy(state, content, state.expansion.hand[0])
	expect_true(not options.is_empty(), "Fixture offers legal options")
	var board: BoardView = BoardView.new()
	board.set_preview(options[0], state, content, TileArtRegistry.new())
	expect_equal(board.preview_views.size(), 1, "One ghost preview")
	expect_equal(board.preview_views[0].coordinate, options[0].coordinate, "Exact option location")
	board.clear_preview()
	expect_equal(board.preview_views.size(), 0, "Cancel clears local ghosts")
	expect_equal(StateNormalizer.fingerprint(state), before, "Preview and cancel consume nothing")
	board.free()
	return true


func development_preview_is_pure() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	var id: int = PhysicalTileRules.acquire(state, &"tile.development.housing", &"test", TileLocationState.Kind.BAG)
	var before: String = StateNormalizer.fingerprint(state)
	var option: PlacementOption = PlacementOption.new()
	option.placement_mode = DomainTypes.PlacementMode.DEVELOPMENT
	option.tile_copy_id = id
	var board: BoardView = BoardView.new()
	board.set_preview(option, state, content, TileArtRegistry.new())
	expect_true(board.preview_views[0].development_labels.has("Preview: Housing"), "Host keeps geography and shows proposed badge")
	expect_equal(StateNormalizer.fingerprint(state), before, "Development preview does not install overlay")
	board.free()
	return true


func transformation_preview() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	var id: int = PhysicalTileRules.acquire(state, &"tile.transformation.bridge", &"test", TileLocationState.Kind.BAG)
	var before: String = StateNormalizer.fingerprint(state)
	var option: PlacementOption = PlacementOption.new()
	option.placement_mode = DomainTypes.PlacementMode.TRANSFORMATION
	option.tile_copy_id = id
	option.transformation_plan = TransformationState.new()
	var change: TransformationChange = TransformationChange.new()
	change.after_edges = [DomainTypes.EdgeType.RIVER, DomainTypes.EdgeType.ROAD, DomainTypes.EdgeType.RIVER, DomainTypes.EdgeType.ROAD]
	option.transformation_plan.changes.append(change)
	var board: BoardView = BoardView.new()
	board.set_preview(option, state, content, TileArtRegistry.new())
	expect_equal(board.preview_views[0].displayed_edges, change.after_edges, "Ghost reads exact plan result")
	expect_true(board.preview_views[0].mechanical_visible, "Transformation ghost uses effective geometry")
	expect_equal(StateNormalizer.fingerprint(state), before, "Plan display remains pure")
	board.free()
	return true


func camera_fit() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	_cell(state, content, Vector2i(-2, -3))
	var board: BoardView = BoardView.new()
	board.sync(state, content, TileArtRegistry.new())
	board.fit_board(Vector2(800, 600))
	for tile: TileView in board.tiles.values():
		var center: Vector2 = (tile.position - board.camera.position) * board.camera.zoom + Vector2(400, 300)
		var half: float = BoardView.TILE_SIZE * board.camera.zoom.x / 2.0
		expect_true(center.x - half >= 0 and center.x + half <= 800 and center.y - half >= 0 and center.y + half <= 600,
			"Fit includes every environmental tile and negative board extent")
	expect_true(board.camera.zoom.x >= BoardView.MIN_ZOOM and board.camera.zoom.x <= 2.0, "Fit uses bounded zoom")
	board.free()
	return true


func coordinate_roundtrip() -> bool:
	for coordinate: Vector2i in [Vector2i(-3, 7), Vector2i.ZERO, Vector2i(2, -5)]:
		expect_equal(BoardView.world_to_coordinate(Vector2(coordinate) * BoardView.TILE_SIZE), coordinate, "Signed grid centers round trip")
	return true


func mapping_and_cache() -> bool:
	var registry: TileArtRegistry = TileArtRegistry.new()
	var report: Dictionary = registry.mapping_report(_content())
	expect_equal(report.production_anchors.size(), 13, "Thirteen accepted anchors")
	expect_equal(report.references.size(), 7, "Seven existing references")
	expect_true(report.missing.is_empty(), "All mapped art paths exist")
	expect_true(registry.texture(&"tile.forest_edge") == registry.texture(&"tile.forest_edge"), "Textures cached, not loaded each frame")
	expect_true(registry.texture(&"tile.road_end") == null, "Unresolved Road End uses fallback")
	return true


func fallback_thumbnail() -> bool:
	var registry: TileArtRegistry = TileArtRegistry.new()
	var content: ContentRegistry = _content()
	var thumbnail: Texture2D = registry.thumbnail(&"tile.founding.homestead", content)
	expect_equal(thumbnail.get_size(), Vector2(192, 192), "Readable canonical fallback thumbnail")
	expect_true(thumbnail == registry.thumbnail(&"tile.founding.homestead", content), "Fallback thumbnails cached")
	var pixels: Image = thumbnail.get_image()
	expect_equal(pixels.get_pixel(96, 0).to_html(), TileArtRegistry.COLORS[4].to_html(), "North Settlement rendered")
	expect_equal(pixels.get_pixel(191, 96).to_html(), TileArtRegistry.COLORS[3].to_html(), "East Road rendered")
	return true


func artwork_stays_behind_badges() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	var cell: BoardCellState = _cell(state, content, Vector2i(1, 0), &"tile.settlement_corner")
	var housing: DevelopmentState = DevelopmentState.new()
	housing.stage = &"housing"
	cell.developments.append(housing)
	var tile: TileView = TileView.new()
	tile.configure(state, content, cell.coordinate, TileArtRegistry.new())
	expect_true(tile.artwork.visible and tile.artwork.texture != null, "Opaque anchor is displayed")
	expect_true(tile.artwork.show_behind_parent, "Opaque artwork cannot cover badges or preview border")
	expect_true(not tile.mechanical_visible, "No fallback background masks anchored artwork")
	expect_equal(tile.development_labels, ["Housing"], "Housing draws in foreground")
	tile.free()
	return true


func long_board_fits() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	for x: int in range(1, 67):
		_cell(state, content, Vector2i(x, 0))
	var board: BoardView = BoardView.new()
	board.sync(state, content, TileArtRegistry.new())
	board.fit_board(Vector2(800, 600))
	var extent: float = 67.0 * BoardView.TILE_SIZE * board.camera.zoom.x
	expect_true(extent < 800, "Fit frames all 66 additions plus founding tile with margin")
	expect_true(board.camera.zoom.x < 0.15, "Long board can zoom beyond old clipping minimum")
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	for index: int in range(100):
		board._unhandled_input(wheel)
	expect_true(is_equal_approx(board.camera.zoom.x, BoardView.MIN_ZOOM), "Wheel shares fit minimum")
	board.free()
	return true


func released_pan_does_not_stick() -> bool:
	var board: BoardView = BoardView.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(board)
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	board._unhandled_input(press)
	# Simulate returning into viewport after button was released outside it.
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(80, 40)
	motion.button_mask = 0
	board._unhandled_input(motion)
	expect_equal(board.camera.position, Vector2.ZERO, "Lost external release cannot leave camera dragging")
	board.free()
	return true


func _new_run(content: ContentRegistry) -> RunState:
	var state: RunState = HomesteadRunFactory.create(10, content)
	assert(state.pending_choice != null and state.pending_choice.kind == &"tile_draft")
	assert(RulesEngine.execute(state, content, ResolveTileDraftCommand.new(state.pending_choice.choice_id, 0)).is_valid)
	return state
