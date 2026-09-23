class_name FeatureSerializer
extends RefCounted
## Explicit Phase-3 boundary. All persistent IDs and counters retain signed 64-bit precision.

const COMPONENT_KEYS: Array[String] = [ "component_id", "feature_type", "coordinate", "origin_act", "origin_source_type", "origin_source_runtime_id", "lineage_id" ]
const LINEAGE_KEYS: Array[String] = [ "lineage_id", "feature_type", "parent_ids", "active", "completed", "growth_phase", "member_ids", "scored_component_ids", "scored_field_ids", "scored_river_ids", "scored_forest_ids", "scored_settlement_ids", "completion_ids", "highest_settlement_class" ]
const HISTORY_KEYS: Array[String] = [ "event_id", "kind", "lineage_id", "feature_type", "act", "placement_index", "source_id", "parent_event_id", "component_ids", "parent_ids", "track", "amount" ]
const COMPLETION_KEYS: Array[String] = [ "record_id", "snapshot_id", "lineage_id", "feature_type", "enclosure_id", "act", "placement_index", "source_id", "first_completion", "growth_phase", "total_size", "component_ids", "new_component_ids", "field_support_ids", "river_support_ids", "forest_contact_ids", "new_field_ids", "new_river_ids", "new_forest_ids", "gains", "settlement_class", "trade_network_id", "network_road_ids", "network_settlement_ids", "new_settlement_ids", "development_families", "forest_undeveloped", "enclosure_stage", "natural_neighbor_count", "settlement_neighbor_count", "highest_class_before_completion" ]
const ENCLOSURE_KEYS: Array[String] = [ "enclosure_id", "coordinate", "development_tile_copy_id", "family_id", "stage", "completed_stages", "assigned_steward_id", "completion_ids" ]


static func encode(state: FeatureState) -> Dictionary:
	var data: Dictionary = {
		"topology_revision": str(state.topology_revision),
		"tracks": ExpansionSerializer._encode_ids(state.tracks.values),
		"largest_completed_sizes": ExpansionSerializer._encode_ids(state.largest_completed_sizes),
	}
	data["components"] = []
	for value: FeatureComponentState in state.components:
		data["components"].append(_encode_component(value))
	data["lineages"] = []
	for value: FeatureLineageState in state.lineages:
		data["lineages"].append(_encode_lineage(value))
	data["history"] = []
	for value: FeatureHistoryRecord in state.history:
		data["history"].append(_encode_history(value))
	data["completions"] = []
	for value: FeatureCompletionRecord in state.completions:
		data["completions"].append(_encode_completion(value))
	data["enclosures"] = []
	for value: EnclosureState in state.enclosures:
		data["enclosures"].append(_encode_enclosure(value))
	return data


static func decode(data: Dictionary) -> FeatureState:
	var state: FeatureState = FeatureState.new()
	state.topology_revision = String(data["topology_revision"]).to_int()
	state.tracks.values = ExpansionSerializer._decode_ids(data["tracks"])
	state.largest_completed_sizes = ExpansionSerializer._decode_ids(data["largest_completed_sizes"])
	for entry: Dictionary in data["components"]:
		state.components.append(_decode_component(entry))
	for entry: Dictionary in data["lineages"]:
		state.lineages.append(_decode_lineage(entry))
	for entry: Dictionary in data["history"]:
		state.history.append(_decode_history(entry))
	for entry: Dictionary in data["completions"]:
		state.completions.append(_decode_completion(entry))
	for entry: Dictionary in data["enclosures"]:
		state.enclosures.append(_decode_enclosure(entry))
	return state


static func validate_shape(value: Variant) -> ValidationResult:
	if not RunSerializer._has_exact_keys(value, ["topology_revision", "tracks", "largest_completed_sizes", "components", "lineages", "history", "completions", "enclosures"]):
		return _invalid("Feature state has missing or unsupported fields.")
	var data: Dictionary = value
	if not ExpansionSerializer._nonnegative_int64(data["topology_revision"]) or not _counts(data["tracks"]) or not _counts(data["largest_completed_sizes"]):
		return _invalid("Feature counters must be canonical nonnegative decimal strings.")
	if not data["components"] is Array:
		return _invalid("components must be a record array.")
	for entry: Variant in data["components"]:
		if not _valid_component(entry):
			return _invalid("Malformed component record.")
	if not data["lineages"] is Array:
		return _invalid("lineages must be a record array.")
	for entry: Variant in data["lineages"]:
		if not _valid_lineage(entry):
			return _invalid("Malformed lineage record.")
	if not data["history"] is Array:
		return _invalid("history must be a record array.")
	for entry: Variant in data["history"]:
		if not _valid_history(entry):
			return _invalid("Malformed history record.")
	if not data["completions"] is Array:
		return _invalid("completions must be a record array.")
	for entry: Variant in data["completions"]:
		if not _valid_completion(entry):
			return _invalid("Malformed completion record.")
	if not data["enclosures"] is Array:
		return _invalid("enclosures must be a record array.")
	for entry: Variant in data["enclosures"]:
		if not _valid_enclosure(entry):
			return _invalid("Malformed enclosure record.")
	return ValidationResult.success()


static func _encode_component(value: FeatureComponentState) -> Dictionary:
	return {
		"component_id": str(value.component_id),
		"feature_type": value.feature_type,
		"coordinate": [value.coordinate.x, value.coordinate.y],
		"origin_act": value.origin_act,
		"origin_source_type": String(value.origin_source_type),
		"origin_source_runtime_id": str(value.origin_source_runtime_id),
		"lineage_id": str(value.lineage_id),
	}


static func _decode_component(data: Dictionary) -> FeatureComponentState:
	var value: FeatureComponentState = FeatureComponentState.new()
	value.component_id = String(data["component_id"]).to_int()
	value.feature_type = int(data["feature_type"]) as DomainTypes.FeatureType
	value.coordinate = Vector2i(int(data["coordinate"][0]), int(data["coordinate"][1]))
	value.origin_act = int(data["origin_act"])
	value.origin_source_type = StringName(data["origin_source_type"])
	value.origin_source_runtime_id = String(data["origin_source_runtime_id"]).to_int()
	value.lineage_id = String(data["lineage_id"]).to_int()
	return value


static func _valid_component(value: Variant) -> bool:
	if not RunSerializer._has_exact_keys(value, COMPONENT_KEYS):
		return false
	var data: Dictionary = value
	if not (ExpansionSerializer._nonnegative_int64(data["component_id"])):
		return false
	if not (RunSerializer._is_bounded_integer(data["feature_type"], 0, 3)):
		return false
	if not (_coordinate(data["coordinate"])):
		return false
	if not (RunSerializer._is_bounded_integer(data["origin_act"], 1, 3)):
		return false
	if not (data["origin_source_type"] is String):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["origin_source_runtime_id"])):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["lineage_id"])):
		return false
	return true


static func _encode_lineage(value: FeatureLineageState) -> Dictionary:
	return {
		"lineage_id": str(value.lineage_id),
		"feature_type": value.feature_type,
		"parent_ids": ExpansionSerializer._encode_ids(value.parent_ids),
		"active": value.active,
		"completed": value.completed,
		"growth_phase": str(value.growth_phase),
		"member_ids": ExpansionSerializer._encode_ids(value.member_ids),
		"scored_component_ids": ExpansionSerializer._encode_ids(value.scored_component_ids),
		"scored_field_ids": ExpansionSerializer._encode_ids(value.scored_field_ids),
		"scored_river_ids": ExpansionSerializer._encode_ids(value.scored_river_ids),
		"scored_forest_ids": ExpansionSerializer._encode_ids(value.scored_forest_ids),
		"scored_settlement_ids": ExpansionSerializer._encode_ids(value.scored_settlement_ids),
		"completion_ids": ExpansionSerializer._encode_ids(value.completion_ids),
		"highest_settlement_class": value.highest_settlement_class,
	}


static func _decode_lineage(data: Dictionary) -> FeatureLineageState:
	var value: FeatureLineageState = FeatureLineageState.new()
	value.lineage_id = String(data["lineage_id"]).to_int()
	value.feature_type = int(data["feature_type"]) as DomainTypes.FeatureType
	value.parent_ids = ExpansionSerializer._decode_ids(data["parent_ids"])
	value.active = data["active"]
	value.completed = data["completed"]
	value.growth_phase = String(data["growth_phase"]).to_int()
	value.member_ids = ExpansionSerializer._decode_ids(data["member_ids"])
	value.scored_component_ids = ExpansionSerializer._decode_ids(data["scored_component_ids"])
	value.scored_field_ids = ExpansionSerializer._decode_ids(data["scored_field_ids"])
	value.scored_river_ids = ExpansionSerializer._decode_ids(data["scored_river_ids"])
	value.scored_forest_ids = ExpansionSerializer._decode_ids(data["scored_forest_ids"])
	value.scored_settlement_ids = ExpansionSerializer._decode_ids(data["scored_settlement_ids"])
	value.completion_ids = ExpansionSerializer._decode_ids(data["completion_ids"])
	value.highest_settlement_class = int(data["highest_settlement_class"])
	return value


static func _valid_lineage(value: Variant) -> bool:
	if not RunSerializer._has_exact_keys(value, LINEAGE_KEYS):
		return false
	var data: Dictionary = value
	if not (ExpansionSerializer._nonnegative_int64(data["lineage_id"])):
		return false
	if not (RunSerializer._is_bounded_integer(data["feature_type"], 0, 3)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["parent_ids"], false)):
		return false
	if not (data["active"] is bool):
		return false
	if not (data["completed"] is bool):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["growth_phase"])):
		return false
	if not (ExpansionSerializer._valid_id_array(data["member_ids"], false)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["scored_component_ids"], false)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["scored_field_ids"], false)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["scored_river_ids"], false)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["scored_forest_ids"], false)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["scored_settlement_ids"], false)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["completion_ids"], false)):
		return false
	if not (RunSerializer._is_bounded_integer(data["highest_settlement_class"], 0, 4)):
		return false
	return true


static func _encode_history(value: FeatureHistoryRecord) -> Dictionary:
	return {
		"event_id": str(value.event_id),
		"kind": String(value.kind),
		"lineage_id": str(value.lineage_id),
		"feature_type": value.feature_type,
		"act": value.act,
		"placement_index": str(value.placement_index),
		"source_id": str(value.source_id),
		"parent_event_id": str(value.parent_event_id),
		"component_ids": ExpansionSerializer._encode_ids(value.component_ids),
		"parent_ids": ExpansionSerializer._encode_ids(value.parent_ids),
		"track": value.track,
		"amount": str(value.amount),
	}


static func _decode_history(data: Dictionary) -> FeatureHistoryRecord:
	var value: FeatureHistoryRecord = FeatureHistoryRecord.new()
	value.event_id = String(data["event_id"]).to_int()
	value.kind = StringName(data["kind"])
	value.lineage_id = String(data["lineage_id"]).to_int()
	value.feature_type = int(data["feature_type"])
	value.act = int(data["act"])
	value.placement_index = String(data["placement_index"]).to_int()
	value.source_id = String(data["source_id"]).to_int()
	value.parent_event_id = String(data["parent_event_id"]).to_int()
	value.component_ids = ExpansionSerializer._decode_ids(data["component_ids"])
	value.parent_ids = ExpansionSerializer._decode_ids(data["parent_ids"])
	value.track = int(data["track"])
	value.amount = String(data["amount"]).to_int()
	return value


static func _valid_history(value: Variant) -> bool:
	if not RunSerializer._has_exact_keys(value, HISTORY_KEYS):
		return false
	var data: Dictionary = value
	if not (ExpansionSerializer._nonnegative_int64(data["event_id"])):
		return false
	if not (data["kind"] is String):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["lineage_id"])):
		return false
	if not (RunSerializer._is_bounded_integer(data["feature_type"], -1, 3)):
		return false
	if not (RunSerializer._is_bounded_integer(data["act"], 1, 3)):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["placement_index"])):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["source_id"])):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["parent_event_id"])):
		return false
	if not (ExpansionSerializer._valid_id_array(data["component_ids"], false)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["parent_ids"], false)):
		return false
	if not (RunSerializer._is_bounded_integer(data["track"], -1, 3)):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["amount"])):
		return false
	return true


static func _encode_completion(value: FeatureCompletionRecord) -> Dictionary:
	return {
		"record_id": str(value.record_id),
		"snapshot_id": str(value.snapshot_id),
		"lineage_id": str(value.lineage_id),
		"feature_type": value.feature_type,
		"enclosure_id": str(value.enclosure_id),
		"act": value.act,
		"placement_index": str(value.placement_index),
		"source_id": str(value.source_id),
		"first_completion": value.first_completion,
		"growth_phase": str(value.growth_phase),
		"total_size": str(value.total_size),
		"component_ids": ExpansionSerializer._encode_ids(value.component_ids),
		"new_component_ids": ExpansionSerializer._encode_ids(value.new_component_ids),
		"field_support_ids": ExpansionSerializer._encode_ids(value.field_support_ids),
		"river_support_ids": ExpansionSerializer._encode_ids(value.river_support_ids),
		"forest_contact_ids": ExpansionSerializer._encode_ids(value.forest_contact_ids),
		"new_field_ids": ExpansionSerializer._encode_ids(value.new_field_ids),
		"new_river_ids": ExpansionSerializer._encode_ids(value.new_river_ids),
		"new_forest_ids": ExpansionSerializer._encode_ids(value.new_forest_ids),
		"gains": ExpansionSerializer._encode_ids(value.gains),
		"settlement_class": value.settlement_class,
		"highest_class_before_completion": value.highest_class_before_completion,
		"trade_network_id": str(value.trade_network_id),
		"network_road_ids": ExpansionSerializer._encode_ids(value.network_road_ids),
		"network_settlement_ids": ExpansionSerializer._encode_ids(value.network_settlement_ids),
		"new_settlement_ids": ExpansionSerializer._encode_ids(value.new_settlement_ids),
		"development_families": value.development_families.duplicate(),
		"forest_undeveloped": value.forest_undeveloped,
		"enclosure_stage": String(value.enclosure_stage),
		"natural_neighbor_count": value.natural_neighbor_count,
		"settlement_neighbor_count": value.settlement_neighbor_count,
	}


static func _decode_completion(data: Dictionary) -> FeatureCompletionRecord:
	var value: FeatureCompletionRecord = FeatureCompletionRecord.new()
	value.record_id = String(data["record_id"]).to_int()
	value.snapshot_id = String(data["snapshot_id"]).to_int()
	value.lineage_id = String(data["lineage_id"]).to_int()
	value.feature_type = int(data["feature_type"])
	value.enclosure_id = String(data["enclosure_id"]).to_int()
	value.act = int(data["act"])
	value.placement_index = String(data["placement_index"]).to_int()
	value.source_id = String(data["source_id"]).to_int()
	value.first_completion = data["first_completion"]
	value.growth_phase = String(data["growth_phase"]).to_int()
	value.total_size = String(data["total_size"]).to_int()
	value.component_ids = ExpansionSerializer._decode_ids(data["component_ids"])
	value.new_component_ids = ExpansionSerializer._decode_ids(data["new_component_ids"])
	value.field_support_ids = ExpansionSerializer._decode_ids(data["field_support_ids"])
	value.river_support_ids = ExpansionSerializer._decode_ids(data["river_support_ids"])
	value.forest_contact_ids = ExpansionSerializer._decode_ids(data["forest_contact_ids"])
	value.new_field_ids = ExpansionSerializer._decode_ids(data["new_field_ids"])
	value.new_river_ids = ExpansionSerializer._decode_ids(data["new_river_ids"])
	value.new_forest_ids = ExpansionSerializer._decode_ids(data["new_forest_ids"])
	value.gains = ExpansionSerializer._decode_ids(data["gains"])
	value.settlement_class = int(data["settlement_class"])
	value.highest_class_before_completion = int(data["highest_class_before_completion"])
	value.trade_network_id = String(data["trade_network_id"]).to_int()
	value.network_road_ids = ExpansionSerializer._decode_ids(data["network_road_ids"])
	value.network_settlement_ids = ExpansionSerializer._decode_ids(data["network_settlement_ids"])
	value.new_settlement_ids = ExpansionSerializer._decode_ids(data["new_settlement_ids"])
	for family: String in data["development_families"]:
		value.development_families.append(StringName(family))
	value.forest_undeveloped = data["forest_undeveloped"]
	value.enclosure_stage = StringName(data["enclosure_stage"])
	value.natural_neighbor_count = int(data["natural_neighbor_count"])
	value.settlement_neighbor_count = int(data["settlement_neighbor_count"])
	return value


static func _valid_completion(value: Variant) -> bool:
	if not RunSerializer._has_exact_keys(value, COMPLETION_KEYS):
		return false
	var data: Dictionary = value
	if not _strings(data["development_families"]) or not data["forest_undeveloped"] is bool \
		or not data["enclosure_stage"] is String \
		or not RunSerializer._is_bounded_integer(data["natural_neighbor_count"], 0, 8) \
		or not RunSerializer._is_bounded_integer(data["settlement_neighbor_count"], 0, 8):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["record_id"])):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["snapshot_id"])):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["lineage_id"])):
		return false
	if not (RunSerializer._is_bounded_integer(data["feature_type"], -1, 3)):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["enclosure_id"])):
		return false
	if not (RunSerializer._is_bounded_integer(data["act"], 1, 3)):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["placement_index"])):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["source_id"])):
		return false
	if not (data["first_completion"] is bool):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["growth_phase"])):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["total_size"])):
		return false
	if not (ExpansionSerializer._valid_id_array(data["component_ids"], false)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["new_component_ids"], false)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["field_support_ids"], false)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["river_support_ids"], false)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["forest_contact_ids"], false)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["new_field_ids"], false)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["new_river_ids"], false)):
		return false
	if not (ExpansionSerializer._valid_id_array(data["new_forest_ids"], false)):
		return false
	if not (_counts(data["gains"])):
		return false
	if not ExpansionSerializer._nonnegative_int64(data["trade_network_id"]):
		return false
	for key: String in ["network_road_ids", "network_settlement_ids", "new_settlement_ids"]:
		if not ExpansionSerializer._valid_id_array(data[key], false):
			return false
	if not RunSerializer._is_bounded_integer(data["highest_class_before_completion"], 0, 4):
		return false
	if not (RunSerializer._is_bounded_integer(data["settlement_class"], 0, 4)):
		return false
	return true


static func _encode_enclosure(value: EnclosureState) -> Dictionary:
	return {
		"enclosure_id": str(value.enclosure_id),
		"coordinate": [value.coordinate.x, value.coordinate.y],
		"development_tile_copy_id": str(value.development_tile_copy_id),
		"family_id": String(value.family_id),
		"stage": String(value.stage),
		"completed_stages": value.completed_stages.duplicate(),
		"assigned_steward_id": str(value.assigned_steward_id),
		"completion_ids": ExpansionSerializer._encode_ids(value.completion_ids),
	}


static func _decode_enclosure(data: Dictionary) -> EnclosureState:
	var value: EnclosureState = EnclosureState.new()
	value.enclosure_id = String(data["enclosure_id"]).to_int()
	value.coordinate = Vector2i(int(data["coordinate"][0]), int(data["coordinate"][1]))
	value.development_tile_copy_id = String(data["development_tile_copy_id"]).to_int()
	value.family_id = StringName(data["family_id"])
	value.stage = StringName(data["stage"])
	for stage: String in data["completed_stages"]:
		value.completed_stages.append(StringName(stage))
	value.assigned_steward_id = String(data["assigned_steward_id"]).to_int()
	value.completion_ids = ExpansionSerializer._decode_ids(data["completion_ids"])
	return value


static func _valid_enclosure(value: Variant) -> bool:
	if not RunSerializer._has_exact_keys(value, ENCLOSURE_KEYS):
		return false
	var data: Dictionary = value
	if not (ExpansionSerializer._nonnegative_int64(data["enclosure_id"])):
		return false
	if not (_coordinate(data["coordinate"])):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["development_tile_copy_id"])):
		return false
	if not (data["family_id"] is String):
		return false
	if not (data["stage"] is String):
		return false
	if not (_strings(data["completed_stages"])):
		return false
	if not (ExpansionSerializer._nonnegative_int64(data["assigned_steward_id"])):
		return false
	if not (ExpansionSerializer._valid_id_array(data["completion_ids"], false)):
		return false
	return true


static func _counts(value: Variant) -> bool:
	return value is Array and value.size() == 4 and ExpansionSerializer._valid_id_array(value, true)


static func _coordinate(value: Variant) -> bool:
	return value is Array and value.size() == 2 \
		and RunSerializer._is_bounded_integer(value[0], -2147483648, 2147483647) \
		and RunSerializer._is_bounded_integer(value[1], -2147483648, 2147483647)


static func _strings(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not entry is String:
			return false
	return true


static func _invalid(message: String) -> ValidationResult:
	return ValidationResult.failure(&"invalid_save", message)
