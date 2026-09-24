class_name TransformationSerializer
extends RefCounted
## Strict, data-only physical Transformation and geometry history boundary.

const KEYS: Array[String] = ["tile_copy_id", "definition_id", "act_applied", "placement_index",
	"mode", "orientation", "target_base_copy_id", "changes"]
const CHANGE_KEYS: Array[String] = ["coordinate", "before_edges", "after_edges", "field_before",
	"field_after", "target_lineage_ids", "created_component_ids"]


static func encode(values: Array[TransformationState]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: TransformationState in values:
		var changes: Array[Dictionary] = []
		for change: TransformationChange in value.changes:
			changes.append({"coordinate": [change.coordinate.x, change.coordinate.y],
				"before_edges": change.before_edges.duplicate(), "after_edges": change.after_edges.duplicate(),
				"field_before": change.field_before, "field_after": change.field_after,
				"target_lineage_ids": ExpansionSerializer._encode_ids(change.target_lineage_ids),
				"created_component_ids": ExpansionSerializer._encode_ids(change.created_component_ids)})
		result.append({"tile_copy_id": str(value.tile_copy_id), "definition_id": String(value.definition_id),
			"act_applied": value.act_applied, "placement_index": str(value.placement_index),
			"mode": String(value.mode), "orientation": value.orientation,
			"target_base_copy_id": str(value.target_base_copy_id), "changes": changes})
	return result


static func decode(entries: Array) -> Array[TransformationState]:
	var result: Array[TransformationState] = []
	for entry: Dictionary in entries:
		var value: TransformationState = TransformationState.new()
		value.tile_copy_id = String(entry["tile_copy_id"]).to_int()
		value.definition_id = StringName(entry["definition_id"])
		value.act_applied = int(entry["act_applied"])
		value.placement_index = String(entry["placement_index"]).to_int()
		value.mode = StringName(entry["mode"])
		value.orientation = int(entry["orientation"])
		value.target_base_copy_id = String(entry["target_base_copy_id"]).to_int()
		for encoded: Dictionary in entry["changes"]:
			var change: TransformationChange = TransformationChange.new()
			change.coordinate = Vector2i(int(encoded["coordinate"][0]), int(encoded["coordinate"][1]))
			for edge: Variant in encoded["before_edges"]:
				change.before_edges.append(int(edge) as DomainTypes.EdgeType)
			for edge: Variant in encoded["after_edges"]:
				change.after_edges.append(int(edge) as DomainTypes.EdgeType)
			change.field_before = encoded["field_before"]
			change.field_after = encoded["field_after"]
			change.target_lineage_ids = ExpansionSerializer._decode_ids(encoded["target_lineage_ids"])
			change.created_component_ids = ExpansionSerializer._decode_ids(encoded["created_component_ids"])
			value.changes.append(change)
		result.append(value)
	return result


static func valid_shape(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not RunSerializer._has_exact_keys(entry, KEYS):
			return false
		for key: String in ["tile_copy_id", "placement_index", "target_base_copy_id"]:
			if not ExpansionSerializer._nonnegative_int64(entry[key]) or String(entry[key]).to_int() == 0:
				return false
		if not entry["definition_id"] is String or not entry["mode"] is String \
			or not RunSerializer._is_bounded_integer(entry["act_applied"], 1, 3) \
			or not RunSerializer._is_bounded_integer(entry["orientation"], 0, 3) or not entry["changes"] is Array:
			return false
		for change: Variant in entry["changes"]:
			if not RunSerializer._has_exact_keys(change, CHANGE_KEYS):
				return false
			if not FeatureSerializer._coordinate(change["coordinate"]) \
				or not _edges(change["before_edges"], true) or not _edges(change["after_edges"], false) \
				or not change["field_before"] is bool or not change["field_after"] is bool \
				or not ExpansionSerializer._valid_id_array(change["target_lineage_ids"], false) \
				or not ExpansionSerializer._valid_id_array(change["created_component_ids"], false):
				return false
	return true


static func _edges(value: Variant, allow_empty: bool) -> bool:
	if not value is Array or (value.size() != 4 and not (allow_empty and value.is_empty())):
		return false
	for edge: Variant in value:
		if not RunSerializer._is_bounded_integer(edge, 0, DomainTypes.EdgeType.SETTLEMENT):
			return false
	return true
