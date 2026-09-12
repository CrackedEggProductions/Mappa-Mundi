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
	if data.has("expansion"):
		var expansion: Dictionary = data["expansion"]
		expansion["removed_ids"].sort_custom(_decimal_id_before)
		# Board encoding already sorts sparse coordinates. Internal group/relationship
		# order has no rules meaning, unlike bag order and active-hand slots.
		for cell: Dictionary in expansion["board"]["cells"]:
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
