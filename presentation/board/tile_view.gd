class_name TileView
extends Node2D
## Disposable visual snapshot. Never writes into BoardCellState or RunState.

const TILE_SIZE: float = 192.0
const INK: Color = Color("30271e")
var artwork: Sprite2D
var coordinate: Vector2i
var displayed_edges: Array[DomainTypes.EdgeType] = []
var displayed_groups: Array[TileFeatureGroup] = []
var development_labels: Array[String] = []
var specialist_labels: Array[String] = []
var transformation_labels: Array[String] = []
var tile_name: String = ""
var mechanical_visible: bool = false
var is_preview: bool = false


func configure(state: RunState, content: ContentRegistry, at: Vector2i,
		registry: TileArtRegistry) -> void:
	var cell: BoardCellState = state.expansion.board.get_cell(at)
	assert(cell != null)
	configure_cell(cell, content, registry)
	specialist_labels.clear()
	if state.specialists != null and state.features != null:
		for piece: SpecialistPieceState in state.specialists.pieces:
			if piece.status != SpecialistPieceState.Status.ASSIGNED:
				continue
			var location: Vector2i = Vector2i.MAX
			if piece.assigned_target_type == SpecialistRules.ENCLOSURE:
				var enclosure: EnclosureState = SpecialistRules.find_enclosure(state, piece.assigned_target_id)
				if enclosure != null:
					location = enclosure.coordinate
			else:
				for component: FeatureComponentState in state.features.components:
					if component.lineage_id == piece.assigned_target_id:
						if location == Vector2i.MAX or BoardState.coordinate_before(component.coordinate, location):
							location = component.coordinate
			if location == at:
				var role: String = "Steward" if piece.role_definition_id == &"" else String(piece.role_definition_id).get_slice(".", 1).capitalize()
				specialist_labels.append(role)
	queue_redraw()


func configure_cell(cell: BoardCellState, content: ContentRegistry, registry: TileArtRegistry) -> void:
	coordinate = cell.coordinate
	position = Vector2(coordinate) * TILE_SIZE
	displayed_edges = cell.effective_edges.duplicate()
	displayed_groups = cell.feature_groups.duplicate()
	var definition: TileDefinition = content.get_tile(cell.definition_id)
	tile_name = definition.display_name if definition != null else String(cell.definition_id)
	if artwork == null:
		artwork = Sprite2D.new()
		# Sprite children normally draw after _draw; badges must remain in front.
		artwork.show_behind_parent = true
		artwork.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(artwork)
	artwork.texture = registry.texture(cell.definition_id)
	artwork.rotation = float(posmod(cell.rotation + registry.art_rotation(cell.definition_id), 4)) * PI / 2.0
	if artwork.texture != null:
		artwork.scale = Vector2.ONE * TILE_SIZE / float(artwork.texture.get_width())
	mechanical_visible = artwork.texture == null or cell.geometry_revision > 0 or not cell.transformations.is_empty()
	# A transformed cell's current geometry must replace misleading old artwork.
	artwork.visible = not mechanical_visible
	development_labels.clear()
	for development: DevelopmentState in cell.developments:
		development_labels.append(String(development.stage if development.stage != &"" else development.family_id).replace("_", " ").capitalize())
	transformation_labels.clear()
	for transformation: TransformationState in cell.transformations:
		transformation_labels.append(String(transformation.definition_id).get_slice(".", 1).replace("_", " ").capitalize())
	queue_redraw()


func _draw() -> void:
	var half: float = TILE_SIZE / 2.0
	if mechanical_visible:
		draw_rect(Rect2(-Vector2.ONE * half, Vector2.ONE * TILE_SIZE), Color("e5d4aa"))
		_draw_geography()
		_badge(tile_name, Vector2(-half + 5, half - 19), Color("e5d4aa"), 11)
	# These badges remain upright, separate from the quarter-turned base image.
	var row: int = 0
	for label: String in development_labels + transformation_labels:
		_badge(label, Vector2(-half + 5, -half + 5 + row * 21), Color("eee2c5"), 12)
		row += 1
	row = 0
	for label: String in specialist_labels:
		_badge("● " + label, Vector2(-half + 6, half - 43 - row * 21), Color("c69a43"), 12)
		row += 1
	if is_preview:
		draw_rect(Rect2(-Vector2.ONE * half, Vector2.ONE * TILE_SIZE), Color("c69a43"), false, 3.0)


func _draw_geography() -> void:
	var half: float = TILE_SIZE / 2.0
	var corners: Array[Vector2] = [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	for direction: int in range(displayed_edges.size()):
		var edge: int = displayed_edges[direction]
		if edge in [DomainTypes.EdgeType.FOREST, DomainTypes.EdgeType.SETTLEMENT]:
			draw_colored_polygon(PackedVector2Array([corners[direction], corners[(direction + 1) % 4], Vector2.ZERO]), TileArtRegistry.COLORS[edge])
	for group: TileFeatureGroup in displayed_groups:
		if group.edge_type not in [DomainTypes.EdgeType.ROAD, DomainTypes.EdgeType.RIVER]:
			continue
		var width: float = TILE_SIZE * (0.1 if group.edge_type == DomainTypes.EdgeType.ROAD else 0.2)
		for direction: int in group.directions:
			var end: Vector2 = Vector2(BoardState.ORTHOGONAL_OFFSETS[direction]) * half
			draw_line(Vector2.ZERO, end, INK.lightened(0.2), width + 2.0)
			draw_line(Vector2.ZERO, end, TileArtRegistry.COLORS[group.edge_type], width)
		if group.directions.size() == 1:
			draw_circle(Vector2.ZERO, width * 0.5, TileArtRegistry.COLORS[group.edge_type])


func _badge(text: String, at: Vector2, color: Color, size: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var width: float = minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 9.0, TILE_SIZE - 10.0)
	draw_rect(Rect2(at, Vector2(width, 19)), color)
	draw_string(font, at + Vector2(4, 14), text, HORIZONTAL_ALIGNMENT_LEFT, width - 8, size, INK)
