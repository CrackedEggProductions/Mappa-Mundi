class_name BoardView
extends Node2D
## Mouse camera and disposable views; legal positions come only from PlacementOption.

signal coordinate_clicked(coordinate: Vector2i)
signal coordinate_hovered(coordinate: Vector2i)
const TILE_SIZE: float = TileView.TILE_SIZE
const MIN_ZOOM: float = 0.05
var tiles: Dictionary[Vector2i, TileView] = {}
var camera: Camera2D
var options: Array[PlacementOption] = []
var preview_views: Array[TileView] = []
var highlighted_coordinates: Array[Vector2i] = []
var interaction_enabled: bool = true
var _panning: bool = false
var _hover: Vector2i = Vector2i(2147483647, 2147483647)


func _init() -> void:
	camera = Camera2D.new()
	camera.name = "BoardCamera"
	camera.position_smoothing_enabled = false
	add_child(camera)


func sync(state: RunState, content: ContentRegistry, registry: TileArtRegistry) -> void:
	clear_preview()
	for coordinate: Vector2i in tiles.keys():
		if not state.expansion.board.cells.has(coordinate):
			tiles[coordinate].free()
			tiles.erase(coordinate)
	for coordinate: Vector2i in state.expansion.board.sorted_coordinates():
		if not tiles.has(coordinate):
			var tile: TileView = TileView.new()
			tile.z_index = -1
			add_child(tile)
			tiles[coordinate] = tile
		tiles[coordinate].configure(state, content, coordinate, registry)
	queue_redraw()


func set_options(values: Array[PlacementOption]) -> void:
	options = values.duplicate()
	queue_redraw()


func clear_preview() -> void:
	for tile: TileView in preview_views:
		tile.free()
	preview_views.clear()
	queue_redraw()


func set_preview(option: PlacementOption, state: RunState, content: ContentRegistry,
		registry: TileArtRegistry) -> void:
	clear_preview()
	if option == null:
		return
	var copy: TileCopyState = PhysicalTileRules.find_copy(state, option.tile_copy_id)
	if copy == null:
		return
	var definition: TileDefinition = content.get_tile(copy.definition_id)
	if definition == null:
		return
	var host: BoardCellState = state.expansion.board.get_cell(option.coordinate)
	if host == null and option.placement_mode != DomainTypes.PlacementMode.TRANSFORMATION:
		var cell: BoardCellState = BoardCellState.from_definition(definition, copy.tile_copy_id,
			option.coordinate, option.rotation, state.expansion.current_act, 0)
		_preview_cell(cell, content, registry)
	elif host != null and option.placement_mode != DomainTypes.PlacementMode.TRANSFORMATION:
		var tile: TileView = _preview_cell(host, content, registry)
		tile.development_labels.append("Preview: " + definition.display_name)
		tile.queue_redraw()
	if option.transformation_plan != null:
		for change: TransformationChange in option.transformation_plan.changes:
			var original: BoardCellState = state.expansion.board.get_cell(change.coordinate)
			var visual: BoardCellState = BoardCellState.new()
			visual.coordinate = change.coordinate
			visual.definition_id = original.definition_id if original != null else definition.definition_id
			visual.effective_edges = change.after_edges.duplicate()
			visual.geometry_revision = 1
			# Transformation plans provide exact edge geometry; this drawing is no legality query.
			for edge: int in range(1, 5):
				var group: TileFeatureGroup = TileFeatureGroup.new()
				group.edge_type = edge
				for direction: int in range(4):
					if visual.effective_edges[direction] == edge:
						group.directions.append(direction)
				if not group.directions.is_empty():
					visual.feature_groups.append(group)
			var tile: TileView = _preview_cell(visual, content, registry)
			tile.transformation_labels.append("Preview: " + definition.display_name)
			tile.queue_redraw()


func _preview_cell(cell: BoardCellState, content: ContentRegistry, registry: TileArtRegistry) -> TileView:
	var tile: TileView = TileView.new()
	tile.is_preview = true
	tile.modulate.a = 0.82
	tile.z_index = 3
	add_child(tile)
	tile.configure_cell(cell, content, registry)
	preview_views.append(tile)
	return tile


func fit_board(viewport_size: Vector2) -> void:
	if tiles.is_empty() or viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	var bounds: Rect2 = Rect2(Vector2(tiles.keys()[0]) * TILE_SIZE, Vector2.ONE * TILE_SIZE)
	for coordinate: Vector2i in tiles:
		bounds = bounds.merge(Rect2(Vector2(coordinate) * TILE_SIZE, Vector2.ONE * TILE_SIZE))
	camera.position = bounds.get_center() - Vector2.ONE * TILE_SIZE * 0.5
	var scale_value: float = clampf(minf(viewport_size.x / (bounds.size.x + TILE_SIZE), viewport_size.y / (bounds.size.y + TILE_SIZE)), MIN_ZOOM, 2.0)
	camera.zoom = Vector2.ONE * scale_value


static func world_to_coordinate(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x + TILE_SIZE * 0.5) / TILE_SIZE), floori((point.y + TILE_SIZE * 0.5) / TILE_SIZE))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_panning = button.pressed
		elif button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor: float = 1.12 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
			camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, MIN_ZOOM, 3.5)
		elif button.pressed and button.button_index == MOUSE_BUTTON_LEFT and interaction_enabled:
			coordinate_clicked.emit(world_to_coordinate(get_global_mouse_position()))
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		# A release outside the SubViewport need not deliver its button event here.
		if (motion.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT)) == 0:
			_panning = false
		if _panning:
			camera.position -= motion.relative / camera.zoom
		var coordinate: Vector2i = world_to_coordinate(get_global_mouse_position())
		if coordinate != _hover:
			_hover = coordinate
			coordinate_hovered.emit(coordinate)


func _draw() -> void:
	var drawn: Dictionary[Vector2i, bool] = {}
	for option: PlacementOption in options:
		if drawn.has(option.coordinate):
			continue
		drawn[option.coordinate] = true
		var target: Rect2 = Rect2(Vector2(option.coordinate) * TILE_SIZE - Vector2.ONE * TILE_SIZE * 0.5, Vector2.ONE * TILE_SIZE)
		draw_rect(target, Color(0.40, 0.47, 0.29, 0.14))
		draw_rect(target.grow(-2), Color("66784a"), false, 2.0)
	for coordinate: Vector2i in highlighted_coordinates:
		draw_rect(Rect2(Vector2(coordinate) * TILE_SIZE - Vector2.ONE * TILE_SIZE * 0.5, Vector2.ONE * TILE_SIZE).grow(-3), Color("c69a43"), false, 4.0)
