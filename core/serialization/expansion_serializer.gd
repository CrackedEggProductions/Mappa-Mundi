class_name ExpansionSerializer
extends RefCounted
## Explicit Phase-2 boundary. Coordinates are signed 32-bit pairs; IDs/cursors are strings.

const KEYS: Array[String] = [
	"board", "bag", "hand", "reserve_id", "removed_ids", "current_act",
	"normal_placements", "survey_charges", "state_revision", "pending_refill_index",
]
const BOARD_KEYS: Array[String] = ["revision", "cells"]
const CELL_KEYS: Array[String] = [
	"coordinate", "base_tile_copy_id", "definition_id", "rotation", "act_placed",
	"normal_placement_index", "effective_edges", "feature_groups", "relationships",
	"field_supports_settlement", "geometry_revision",
]
const GROUP_KEYS: Array[String] = ["edge_type", "directions"]
const RELATION_KEYS: Array[String] = ["from_edge_type", "to_edge_type", "kind"]


static func encode(state: ExpansionState) -> Dictionary:
	var cells: Array[Dictionary] = []
	for coordinate: Vector2i in state.board.sorted_coordinates():
		var cell: BoardCellState = state.board.cells[coordinate]
		var groups: Array[Dictionary] = []
		for group: TileFeatureGroup in cell.feature_groups:
			groups.append({"edge_type": group.edge_type, "directions": group.directions.duplicate()})
		var relationships: Array[Dictionary] = []
		for relation: TileFeatureRelationship in cell.relationships:
			relationships.append({"from_edge_type": relation.from_edge_type,
				"to_edge_type": relation.to_edge_type, "kind": relation.kind})
		cells.append({
			"coordinate": [coordinate.x, coordinate.y],
			"base_tile_copy_id": str(cell.base_tile_copy_id),
			"definition_id": String(cell.definition_id), "rotation": cell.rotation,
			"act_placed": cell.act_placed, "normal_placement_index": cell.normal_placement_index,
			"effective_edges": cell.effective_edges.duplicate(),
			"feature_groups": groups, "relationships": relationships,
			"field_supports_settlement": cell.field_supports_settlement,
			"geometry_revision": str(cell.geometry_revision),
		})
	return {
		"board": {"revision": str(state.board.revision), "cells": cells},
		"bag": _encode_ids(state.bag), "hand": _encode_ids(state.hand),
		"reserve_id": str(state.reserve_id), "removed_ids": _encode_ids(state.removed_ids),
		"current_act": state.current_act, "normal_placements": state.normal_placements,
		"survey_charges": state.survey_charges, "state_revision": str(state.state_revision),
		"pending_refill_index": state.pending_refill_index,
	}


static func decode(data: Dictionary) -> ExpansionState:
	# Called only after complete shape validation; never invokes gameplay services.
	var state: ExpansionState = ExpansionState.new()
	state.board.revision = String(data["board"]["revision"]).to_int()
	for entry: Dictionary in data["board"]["cells"]:
		var cell: BoardCellState = BoardCellState.new()
		cell.coordinate = Vector2i(int(entry["coordinate"][0]), int(entry["coordinate"][1]))
		cell.base_tile_copy_id = String(entry["base_tile_copy_id"]).to_int()
		cell.definition_id = StringName(entry["definition_id"])
		cell.rotation = int(entry["rotation"])
		cell.act_placed = int(entry["act_placed"])
		cell.normal_placement_index = int(entry["normal_placement_index"])
		cell.field_supports_settlement = entry["field_supports_settlement"]
		cell.geometry_revision = String(entry["geometry_revision"]).to_int()
		for edge: Variant in entry["effective_edges"]:
			cell.effective_edges.append(int(edge) as DomainTypes.EdgeType)
		for encoded_group: Dictionary in entry["feature_groups"]:
			var group: TileFeatureGroup = TileFeatureGroup.new()
			group.edge_type = int(encoded_group["edge_type"])
			for direction: Variant in encoded_group["directions"]:
				group.directions.append(int(direction))
			cell.feature_groups.append(group)
		for encoded_relation: Dictionary in entry["relationships"]:
			var relation: TileFeatureRelationship = TileFeatureRelationship.new()
			relation.from_edge_type = int(encoded_relation["from_edge_type"])
			relation.to_edge_type = int(encoded_relation["to_edge_type"])
			relation.kind = int(encoded_relation["kind"])
			cell.relationships.append(relation)
		state.board.cells[cell.coordinate] = cell
	state.bag = _decode_ids(data["bag"])
	state.hand = _decode_ids(data["hand"])
	state.reserve_id = String(data["reserve_id"]).to_int()
	state.removed_ids = _decode_ids(data["removed_ids"])
	state.current_act = int(data["current_act"])
	state.normal_placements = int(data["normal_placements"])
	state.survey_charges = int(data["survey_charges"])
	state.state_revision = String(data["state_revision"]).to_int()
	state.pending_refill_index = int(data["pending_refill_index"])
	return state


static func validate_shape(value: Variant) -> ValidationResult:
	if not RunSerializer._has_exact_keys(value, KEYS):
		return _invalid("Expansion state has missing or unsupported fields.")
	var data: Dictionary = value
	if not _valid_id_array(data["bag"], false) or not _valid_id_array(data["hand"], true) \
		or not _valid_id_array(data["removed_ids"], false) \
		or not _nonnegative_int64(data["reserve_id"]) \
		or not _nonnegative_int64(data["state_revision"]):
		return _invalid("Expansion zones and revisions require canonical decimal IDs/counters.")
	if not RunSerializer._is_bounded_integer(data["current_act"], 1, 1) \
		or not RunSerializer._is_bounded_integer(data["normal_placements"], 0, 2147483647) \
		or not RunSerializer._is_bounded_integer(data["survey_charges"], 0, 2147483647) \
		or not RunSerializer._is_bounded_integer(data["pending_refill_index"], -1, 2147483647):
		return _invalid("Invalid Phase-2 Act, placement, Survey or pending refill field.")
	if not RunSerializer._has_exact_keys(data["board"], BOARD_KEYS):
		return _invalid("Malformed board record.")
	var board: Dictionary = data["board"]
	if not _nonnegative_int64(board["revision"]) or not board["cells"] is Array:
		return _invalid("Malformed board revision or cell collection.")
	var coordinates: Array[Vector2i] = []
	for entry: Variant in board["cells"]:
		var checked: ValidationResult = _validate_cell(entry)
		if not checked.is_valid:
			return checked
		var cell: Dictionary = entry
		var coordinate: Vector2i = Vector2i(int(cell["coordinate"][0]), int(cell["coordinate"][1]))
		if coordinate in coordinates:
			return _invalid("Duplicate occupied coordinate cannot be collapsed during loading.")
		coordinates.append(coordinate)
	return ValidationResult.success()


static func _validate_cell(value: Variant) -> ValidationResult:
	if not RunSerializer._has_exact_keys(value, CELL_KEYS):
		return _invalid("Malformed board cell record.")
	var cell: Dictionary = value
	if not cell["field_supports_settlement"] is bool or not _nonnegative_int64(cell["geometry_revision"]):
		return _invalid("Invalid explicit Field support or geometry revision.")
	if not cell["coordinate"] is Array or cell["coordinate"].size() != 2:
		return _invalid("Coordinates must be explicit two-element arrays.")
	for axis: Variant in cell["coordinate"]:
		if not RunSerializer._is_bounded_integer(axis, -2147483648, 2147483647):
			return _invalid("Coordinate axes must be signed 32-bit integers.")
	if not _nonnegative_int64(cell["base_tile_copy_id"]) \
		or String(cell["base_tile_copy_id"]).to_int() == 0 \
		or not cell["definition_id"] is String \
		or not RunSerializer._is_bounded_integer(cell["rotation"], 0, 3) \
		or not RunSerializer._is_bounded_integer(cell["act_placed"], 1, 1) \
		or not RunSerializer._is_bounded_integer(cell["normal_placement_index"], 0, 2147483647):
		return _invalid("Invalid board identity, placement metadata or rotation.")
	if not cell["effective_edges"] is Array or cell["effective_edges"].size() != 4:
		return _invalid("Board cells require four effective edges.")
	for edge: Variant in cell["effective_edges"]:
		if not RunSerializer._is_bounded_integer(edge, 0, DomainTypes.EdgeType.SETTLEMENT):
			return _invalid("Invalid effective edge value.")
	if not cell["feature_groups"] is Array or not cell["relationships"] is Array:
		return _invalid("Internal geometry must use explicit record arrays.")
	for group_value: Variant in cell["feature_groups"]:
		if not RunSerializer._has_exact_keys(group_value, GROUP_KEYS):
			return _invalid("Malformed feature group.")
		var group: Dictionary = group_value
		if not RunSerializer._is_bounded_integer(group["edge_type"], 1, DomainTypes.EdgeType.SETTLEMENT) \
			or not group["directions"] is Array:
			return _invalid("Invalid feature group type or directions.")
		for direction: Variant in group["directions"]:
			if not RunSerializer._is_bounded_integer(direction, 0, 3):
				return _invalid("Invalid internal feature direction.")
	for relation_value: Variant in cell["relationships"]:
		if not RunSerializer._has_exact_keys(relation_value, RELATION_KEYS):
			return _invalid("Malformed internal relationship.")
		var relation: Dictionary = relation_value
		if not RunSerializer._is_bounded_integer(relation["from_edge_type"], 1, DomainTypes.EdgeType.SETTLEMENT) \
			or not RunSerializer._is_bounded_integer(relation["to_edge_type"], 1, DomainTypes.EdgeType.SETTLEMENT) \
			or not RunSerializer._is_bounded_integer(relation["kind"], 0, 2147483647):
			return _invalid("Invalid internal relationship fields.")
	return ValidationResult.success()


static func _encode_ids(ids: Array[int]) -> Array[String]:
	var encoded: Array[String] = []
	for tile_id: int in ids:
		encoded.append(str(tile_id))
	return encoded


static func _decode_ids(ids: Array) -> Array[int]:
	var decoded: Array[int] = []
	for tile_id: String in ids:
		decoded.append(tile_id.to_int())
	return decoded


static func _valid_id_array(value: Variant, allow_empty_slot: bool) -> bool:
	if not value is Array:
		return false
	for tile_id: Variant in value:
		if not _nonnegative_int64(tile_id):
			return false
		if not allow_empty_slot and String(tile_id).to_int() == 0:
			return false
	return true


static func _nonnegative_int64(value: Variant) -> bool:
	return RunSerializer._is_decimal_int64(value) and String(value).to_int() >= 0


static func _invalid(message: String) -> ValidationResult:
	return ValidationResult.failure(&"invalid_save", message)
