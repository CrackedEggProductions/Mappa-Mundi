class_name StateNormalizer
extends RefCounted
## Development diagnostics, never gameplay decisions. Expects invariant-valid state.
## The save schema is the single mapping of authoritative fields at this phase.


static func normalize(state: RunState) -> String:
	var envelope: Dictionary = RunSerializer.to_envelope(state)
	var data: Dictionary = envelope["run_state"]
	var tiles: Array = data["tile_copies"]
	var locations: Array = data["tile_locations"]
	tiles.sort_custom(_runtime_id_before)
	locations.sort_custom(_runtime_id_before)
	if data.has("features"):
		_normalize_features(data["features"])
	if data.has("trade"):
		_normalize_trade(data["trade"])
	# SpecialistSerializer sorts roster IDs and growth identity sets on fresh values.
	# Exact choice option order, immutable snapshot data and history stay authoritative.
	if data.has("expansion"):
		var expansion: Dictionary = data["expansion"]
		expansion["removed_ids"].sort_custom(_decimal_id_before)
		# Board encoding already sorts sparse coordinates. Internal group/relationship
		# order has no rules meaning, unlike bag order and active-hand slots.
		for cell: Dictionary in expansion["board"]["cells"]:
			cell["developments"].sort_custom(_runtime_id_before)
			cell["transformations"].sort_custom(_runtime_id_before)
			for transformation: Dictionary in cell["transformations"]:
				transformation["changes"].sort_custom(_record_before)
				for change: Dictionary in transformation["changes"]:
					change["target_lineage_ids"].sort_custom(_decimal_id_before)
					change["created_component_ids"].sort_custom(_decimal_id_before)
			for group: Dictionary in cell["feature_groups"]:
				group["directions"].sort()
			cell["feature_groups"].sort_custom(_record_before)
			cell["relationships"].sort_custom(_record_before)
	# JSON recursively sorts dictionary keys; registry arrays have no gameplay order.
	# Future ordered zones (bag/hand/etc.) must retain their authoritative order.
	return JSON.stringify(envelope, "", true)


static func fingerprint(state: RunState) -> String:
	return normalize(state).sha256_text()


static func _runtime_id_before(left: Dictionary, right: Dictionary) -> bool:
	return String(left["tile_copy_id"]).to_int() < String(right["tile_copy_id"]).to_int()


static func _decimal_id_before(left: String, right: String) -> bool:
	return left.to_int() < right.to_int()


static func _record_before(left: Dictionary, right: Dictionary) -> bool:
	return JSON.stringify(left, "", true) < JSON.stringify(right, "", true)


static func _normalize_features(data: Dictionary) -> void:
	# Histories/completions preserve FIFO order. Registries and identity sets do not.
	for pair: Array in [["components", "component_id"], ["lineages", "lineage_id"], ["enclosures", "enclosure_id"]]:
		var key: String = pair[1]
		data[pair[0]].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a[key]).to_int() < String(b[key]).to_int())
	for lineage: Dictionary in data["lineages"]:
		for key: String in ["parent_ids", "member_ids", "scored_component_ids", "scored_field_ids", "scored_river_ids", "scored_forest_ids", "scored_settlement_ids", "completion_ids"]:
			lineage[key].sort_custom(_decimal_id_before)
	for enclosure: Dictionary in data["enclosures"]:
		enclosure["completed_stages"].sort()
		enclosure["completion_ids"].sort_custom(_decimal_id_before)
	for record: Dictionary in data["completions"]:
		record["development_families"].sort()
		for key: String in ["component_ids", "new_component_ids", "field_support_ids", "river_support_ids", "forest_contact_ids", "new_field_ids", "new_river_ids", "new_forest_ids", "network_road_ids", "network_settlement_ids", "new_settlement_ids"]:
			record[key].sort_custom(_decimal_id_before)
	for event: Dictionary in data["history"]:
		event["component_ids"].sort_custom(_decimal_id_before)
		event["parent_ids"].sort_custom(_decimal_id_before)


static func _normalize_trade(data: Dictionary) -> void:
	data["lineages"].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["lineage_id"]).to_int() < String(b["lineage_id"]).to_int())
	data["authorized_links"].sort_custom(_record_before)
	for key: String in ["lineages", "history"]:
		for record: Dictionary in data[key]:
			for set_key: String in ["parent_ids", "road_lineage_ids", "settlement_lineage_ids"]:
				record[set_key].sort_custom(_decimal_id_before)
