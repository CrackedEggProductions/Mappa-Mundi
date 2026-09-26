class_name TileArtRegistry
extends RefCounted
## Presentation assets only. Source pixels stay untouched under art/.gdignore.

const ROOT: String = "res://art/references/"
const ANCHORS: Array[String] = ["forest_bend", "forest_edge", "forest_belt",
	"settlement_corner", "settlement_throughway", "road_junction", "woodland_road",
	"woodland_river", "settlement_corner_gate", "settlement_road_bend",
	"settlement_gate", "riverside_hamlet", "settlement_road_throughway"]
const REFERENCES: Dictionary = {
	"open_fields": "approved_mechanical/ref_04_open_fields.png",
	"hamlet_edge": "approved_mechanical/ref_03_hamlet_edge.png",
	"straight_road": "approved_mechanical/ref_05_straight_road.png",
	"bending_road": "approved_mechanical/ref_09_bending_road.png",
	"river_end": "approved_mechanical/ref_15_river_end.png",
	"river_run": "approved_style/ref_10_river_run.png",
	"river_bend": "approved_mechanical/ref_13_river_bend.png",
}
const COLORS: Array[Color] = [Color("c4b87c"), Color("66784a"),
	Color("628f92"), Color("b68a56"), Color("a55e48")]
static var _textures: Dictionary[StringName, Texture2D] = {}
static var _thumbnails: Dictionary[StringName, Texture2D] = {}


func source_path(definition_id: StringName) -> String:
	var stem: String = String(definition_id).trim_prefix("tile.")
	if stem in ANCHORS:
		return ROOT + "production_anchors/" + stem + "_anchor.png"
	return ROOT + String(REFERENCES[stem]) if REFERENCES.has(stem) else ""


func art_rotation(definition_id: StringName) -> int:
	# Source studies are E/W and N/W; canonical designs are N/S and N/E.
	return 1 if definition_id in [&"tile.straight_road", &"tile.bending_road"] else 0


func texture(definition_id: StringName) -> Texture2D:
	if _textures.has(definition_id):
		return _textures[definition_id]
	var path: String = source_path(definition_id)
	var result: Texture2D = null
	if not path.is_empty() and FileAccess.file_exists(path):
		var pixels: Image = Image.load_from_file(path)
		if pixels != null and not pixels.is_empty():
			pixels.generate_mipmaps()
			result = ImageTexture.create_from_image(pixels)
	_textures[definition_id] = result
	return result


func thumbnail(definition_id: StringName, content: ContentRegistry) -> Texture2D:
	if _thumbnails.has(definition_id):
		return _thumbnails[definition_id]
	var art: Texture2D = texture(definition_id)
	var pixels: Image
	if art != null:
		pixels = art.get_image()
		pixels.clear_mipmaps()
		pixels.resize(192, 192, Image.INTERPOLATE_LANCZOS)
		for turn: int in range(art_rotation(definition_id)):
			pixels.rotate_90(CLOCKWISE)
	else:
		pixels = fallback_image(content.get_tile(definition_id))
	var result: Texture2D = ImageTexture.create_from_image(pixels)
	_thumbnails[definition_id] = result
	return result


static func fallback_image(definition: TileDefinition) -> Image:
	var pixels: Image = Image.create(192, 192, false, Image.FORMAT_RGBA8)
	pixels.fill(Color("e5d4aa"))
	if definition == null:
		return pixels
	if definition.canonical_edges.size() != 4:
		# Overlay design thumbnails remain recognizable badges, not false geography.
		pixels.fill_rect(Rect2i(48, 48, 96, 96), Color("a55e48"))
		pixels.fill_rect(Rect2i(62, 62, 68, 68), Color("e5d4aa"))
		return pixels
	for y: int in range(192):
		for x: int in range(192):
			var point: Vector2 = Vector2(x, y) - Vector2(95.5, 95.5)
			var direction: int = (1 if point.x > 0 else 3) if absf(point.x) > absf(point.y) else (2 if point.y > 0 else 0)
			var edge: int = definition.canonical_edges[direction]
			if edge in [DomainTypes.EdgeType.FOREST, DomainTypes.EdgeType.SETTLEMENT]:
				pixels.set_pixel(x, y, COLORS[edge])
			elif edge in [DomainTypes.EdgeType.ROAD, DomainTypes.EdgeType.RIVER]:
				var offset: float = absf(point.x) if direction % 2 == 0 else absf(point.y)
				var half_width: float = 9.6 if edge == DomainTypes.EdgeType.ROAD else 19.2
				if offset <= half_width:
					pixels.set_pixel(x, y, COLORS[edge])
	return pixels


func mapping_report(content: ContentRegistry) -> Dictionary:
	var report: Dictionary = {"production_anchors": [], "references": [], "fallbacks": [], "missing": []}
	for definition_id: StringName in content.get_tile_ids():
		var path: String = source_path(definition_id)
		if path.is_empty():
			report.fallbacks.append(String(definition_id))
		elif not FileAccess.file_exists(path):
			report.missing.append(path)
			report.fallbacks.append(String(definition_id))
		elif path.contains("production_anchors"):
			report.production_anchors.append(String(definition_id))
		else:
			report.references.append(String(definition_id))
	return report
