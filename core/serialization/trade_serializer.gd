class_name TradeSerializer
extends RefCounted
## Persist historical identities and authorized inputs, never derived graph objects.

const KEYS: Array[String] = ["trade_revision", "topology_signature", "lineages", "history", "authorized_links"]
const LINEAGE_KEYS: Array[String] = ["lineage_id", "parent_ids", "active", "road_lineage_ids", "settlement_lineage_ids"]
const HISTORY_KEYS: Array[String] = ["event_id", "kind", "lineage_id", "act", "placement_index", "source_id", "parent_ids", "road_lineage_ids", "settlement_lineage_ids"]
const LINK_KEYS: Array[String] = ["from_lineage_id", "to_lineage_id", "source_id", "source_kind", "explicit_access"]


static func encode(state: TradeState) -> Dictionary:
	var data: Dictionary = {"trade_revision": str(state.trade_revision), "topology_signature": state.topology_signature,
		"lineages": [], "history": [], "authorized_links": []}
	for lineage: TradeNetworkLineageState in state.lineages:
		data["lineages"].append({"lineage_id": str(lineage.lineage_id), "active": lineage.active,
			"parent_ids": ExpansionSerializer._encode_ids(lineage.parent_ids),
			"road_lineage_ids": ExpansionSerializer._encode_ids(lineage.road_lineage_ids),
			"settlement_lineage_ids": ExpansionSerializer._encode_ids(lineage.settlement_lineage_ids)})
	for event: TradeHistoryRecord in state.history:
		data["history"].append({"event_id": str(event.event_id), "kind": String(event.kind),
			"lineage_id": str(event.lineage_id), "act": event.act, "placement_index": str(event.placement_index),
			"source_id": str(event.source_id), "parent_ids": ExpansionSerializer._encode_ids(event.parent_ids),
			"road_lineage_ids": ExpansionSerializer._encode_ids(event.road_lineage_ids),
			"settlement_lineage_ids": ExpansionSerializer._encode_ids(event.settlement_lineage_ids)})
	for link: TradeLinkState in state.authorized_links:
		data["authorized_links"].append({"from_lineage_id": str(link.from_lineage_id),
			"to_lineage_id": str(link.to_lineage_id), "source_id": str(link.source_id),
			"source_kind": String(link.source_kind), "explicit_access": link.explicit_access})
	return data


static func decode(data: Dictionary) -> TradeState:
	var state: TradeState = TradeState.new()
	state.trade_revision = String(data["trade_revision"]).to_int()
	state.topology_signature = data["topology_signature"]
	for entry: Dictionary in data["lineages"]:
		var lineage: TradeNetworkLineageState = TradeNetworkLineageState.new()
		lineage.lineage_id = String(entry["lineage_id"]).to_int()
		lineage.active = entry["active"]
		lineage.parent_ids = ExpansionSerializer._decode_ids(entry["parent_ids"])
		lineage.road_lineage_ids = ExpansionSerializer._decode_ids(entry["road_lineage_ids"])
		lineage.settlement_lineage_ids = ExpansionSerializer._decode_ids(entry["settlement_lineage_ids"])
		state.lineages.append(lineage)
	for entry: Dictionary in data["history"]:
		var event: TradeHistoryRecord = TradeHistoryRecord.new()
		event.event_id = String(entry["event_id"]).to_int()
		event.kind = StringName(entry["kind"])
		event.lineage_id = String(entry["lineage_id"]).to_int()
		event.act = int(entry["act"])
		event.placement_index = String(entry["placement_index"]).to_int()
		event.source_id = String(entry["source_id"]).to_int()
		event.parent_ids = ExpansionSerializer._decode_ids(entry["parent_ids"])
		event.road_lineage_ids = ExpansionSerializer._decode_ids(entry["road_lineage_ids"])
		event.settlement_lineage_ids = ExpansionSerializer._decode_ids(entry["settlement_lineage_ids"])
		state.history.append(event)
	for entry: Dictionary in data["authorized_links"]:
		var link: TradeLinkState = TradeLinkState.new()
		link.from_lineage_id = String(entry["from_lineage_id"]).to_int()
		link.to_lineage_id = String(entry["to_lineage_id"]).to_int()
		link.source_id = String(entry["source_id"]).to_int()
		link.source_kind = StringName(entry["source_kind"])
		link.explicit_access = entry["explicit_access"]
		state.authorized_links.append(link)
	return state


static func validate_shape(value: Variant) -> ValidationResult:
	if not RunSerializer._has_exact_keys(value, KEYS):
		return _invalid("Trade state requires the complete historical schema.")
	var data: Dictionary = value
	if not ExpansionSerializer._nonnegative_int64(data["trade_revision"]) or not data["topology_signature"] is String:
		return _invalid("Trade revision/signature must use canonical types.")
	for key: String in ["lineages", "history", "authorized_links"]:
		if not data[key] is Array:
			return _invalid("Trade registries must be arrays.")
	for entry: Variant in data["lineages"]:
		if not RunSerializer._has_exact_keys(entry, LINEAGE_KEYS):
			return _invalid("Malformed network lineage.")
		if not _ids(entry, ["lineage_id"]) or not _sets(entry) or not entry["active"] is bool:
			return _invalid("Invalid network lineage fields.")
	for entry: Variant in data["history"]:
		if not RunSerializer._has_exact_keys(entry, HISTORY_KEYS):
			return _invalid("Malformed Trade audit record.")
		if not _ids(entry, ["event_id", "lineage_id", "source_id", "placement_index"]) or not _sets(entry) \
			or not entry["kind"] is String or not RunSerializer._is_bounded_integer(entry["act"], 1, 3):
			return _invalid("Invalid Trade audit fields.")
	for entry: Variant in data["authorized_links"]:
		if not RunSerializer._has_exact_keys(entry, LINK_KEYS):
			return _invalid("Malformed authorized economic link.")
		if not _ids(entry, ["from_lineage_id", "to_lineage_id", "source_id"]) \
			or not entry["source_kind"] is String or not entry["explicit_access"] is bool:
			return _invalid("Invalid authorized economic link fields.")
	return ValidationResult.success()


static func _ids(data: Dictionary, keys: Array[String]) -> bool:
	for key: String in keys:
		if not ExpansionSerializer._nonnegative_int64(data[key]):
			return false
	return true


static func _sets(data: Dictionary) -> bool:
	for key: String in ["parent_ids", "road_lineage_ids", "settlement_lineage_ids"]:
		if not ExpansionSerializer._valid_id_array(data[key], false):
			return false
	return true


static func _invalid(message: String) -> ValidationResult:
	return ValidationResult.failure(&"invalid_save", message)
