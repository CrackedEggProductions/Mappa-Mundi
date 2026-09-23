class_name DevelopmentSerializer
extends RefCounted
## Data-only overlay boundary. Never resolves hosts or triggers placement effects.

const IDS: Array[String] = ["tile_copy_id", "host_lineage_id", "river_lineage_id",
	"enclosure_id", "placement_index", "replaced_copy_id"]
const NAMES: Array[String] = ["family_id", "host_kind", "stage"]


static func encode(overlays: Array[DevelopmentState]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for overlay: DevelopmentState in overlays:
		var entry: Dictionary = {"act_placed": overlay.act_placed}
		for key: String in IDS:
			entry[key] = str(overlay.get(key))
		for key: String in NAMES:
			entry[key] = String(overlay.get(key))
		result.append(entry)
	return result


static func decode(entries: Array) -> Array[DevelopmentState]:
	var result: Array[DevelopmentState] = []
	for entry: Dictionary in entries:
		var overlay: DevelopmentState = DevelopmentState.new()
		overlay.act_placed = int(entry["act_placed"])
		for key: String in IDS:
			overlay.set(key, String(entry[key]).to_int())
		for key: String in NAMES:
			overlay.set(key, StringName(entry[key]))
		result.append(overlay)
	return result


static func valid_shape(value: Variant) -> bool:
	if not value is Array:
		return false
	var keys: Array[String] = IDS + NAMES
	keys.append("act_placed")
	for entry: Variant in value:
		if not RunSerializer._has_exact_keys(entry, keys):
			return false
		for key: String in IDS:
			if not ExpansionSerializer._nonnegative_int64(entry[key]):
				return false
		for key: String in NAMES:
			if not entry[key] is String:
				return false
		if not RunSerializer._is_bounded_integer(entry["act_placed"], 1, 3):
			return false
	return true
