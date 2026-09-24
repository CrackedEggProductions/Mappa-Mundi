class_name RunSerializer
extends RefCounted
## JSON boundary only: no files, scenes, commands, events or autosaves.
## Signed 64-bit values use canonical decimal strings; JSON numbers lose precision.

const ENVELOPE_KEYS: Array[String] = [
	"save_schema_version", "game_rules_version", "implementation_spec_version",
	"godot_version", "run_state",
]
const RUN_KEYS: Array[String] = [
	"original_seed", "current_rng_state", "rng_operation_count", "next_runtime_id",
	"phase", "tile_copies", "tile_locations",
]
const TILE_KEYS: Array[String] = [
	"tile_copy_id", "definition_id", "acquired_act", "acquisition_source",
]
const LOCATION_KEYS: Array[String] = ["tile_copy_id", "kind"]


static func serialize(state: RunState, content: ContentRegistry) -> SerializationResult:
	var report: InvariantReport = InvariantValidator.validate(state, content)
	if not report.is_valid:
		return SerializationResult.new(ValidationResult.failure(
			&"invariant_failure", "Cannot serialize invalid authoritative state.",
			{"invariants": report.describe()}
		))
	return SerializationResult.new(
		ValidationResult.success(), JSON.stringify(to_envelope(state), "\t", true)
	)


static func deserialize(text: String, content: ContentRegistry) -> DeserializationResult:
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return _rejected(&"invalid_save", "Malformed JSON.", {
			"line": parser.get_error_line(), "detail": parser.get_error_message(),
		})
	var shape: ValidationResult = _validate_envelope(parser.data)
	if not shape.is_valid:
		return DeserializationResult.new(shape)
	var envelope: Dictionary = parser.data
	var data: Dictionary = envelope["run_state"]
	var state: RunState = RunState.new(String(data["original_seed"]).to_int())
	state.save_schema_version = int(envelope["save_schema_version"])
	state.game_rules_version = String(envelope["game_rules_version"])
	state.implementation_spec_version = int(envelope["implementation_spec_version"])
	state.godot_version = String(envelope["godot_version"])
	state.phase = int(data["phase"]) as GamePhase.Type
	state.id_allocator = RunIdAllocator.new(String(data["next_runtime_id"]).to_int())
	state.rng = RunRNG.from_snapshot(
		String(data["original_seed"]).to_int(),
		String(data["current_rng_state"]).to_int(),
		String(data["rng_operation_count"]).to_int()
	)
	for entry: Dictionary in data["tile_copies"]:
		state.tile_copies.append(TileCopyState.new(
			String(entry["tile_copy_id"]).to_int(), StringName(entry["definition_id"]),
			int(entry["acquired_act"]), StringName(entry["acquisition_source"])
		))
	for entry: Dictionary in data["tile_locations"]:
		state.tile_locations.append(TileLocationState.new(
			String(entry["tile_copy_id"]).to_int(), int(entry["kind"]) as TileLocationState.Kind
		))
	if data.has("expansion"):
		state.expansion = ExpansionSerializer.decode(data["expansion"])
	if data.has("features"):
		state.features = FeatureSerializer.decode(data["features"])
	if data.has("trade"):
		state.trade = TradeSerializer.decode(data["trade"])
	if data.has("specialists"):
		state.specialists = SpecialistSerializer.decode(data["specialists"])
	if data.has("pending_choice"):
		state.pending_choice = SpecialistSerializer.decode_choice(data["pending_choice"])
	if data.has("resolution"):
		state.resolution = SpecialistSerializer.decode_resolution(data["resolution"])
	# The invariant boundary reconstructs topology purely; never reconcile or score on load.
	var report: InvariantReport = InvariantValidator.validate(state, content)
	if not report.is_valid:
		return _rejected(&"invalid_saved_state", "Saved state violates domain invariants.", {
			"invariants": report.describe(),
		})
	return DeserializationResult.new(ValidationResult.success(), state)


static func to_envelope(state: RunState) -> Dictionary:
	# Fresh boundary collections also let normalization reorder without state mutation.
	var tiles: Array[Dictionary] = []
	for tile: TileCopyState in state.tile_copies:
		tiles.append({
			"tile_copy_id": str(tile.tile_copy_id), "definition_id": String(tile.definition_id),
			"acquired_act": tile.acquired_act, "acquisition_source": String(tile.acquisition_source),
		})
	var locations: Array[Dictionary] = []
	for location: TileLocationState in state.tile_locations:
		locations.append({"tile_copy_id": str(location.tile_copy_id), "kind": location.kind})
	var envelope: Dictionary = {
		"save_schema_version": state.save_schema_version,
		"game_rules_version": state.game_rules_version,
		"implementation_spec_version": state.implementation_spec_version,
		"godot_version": state.godot_version,
		"run_state": {
			"original_seed": str(state.original_seed),
			"current_rng_state": str(state.current_rng_state),
			"rng_operation_count": str(state.rng.operation_count),
			"next_runtime_id": str(state.next_runtime_id), "phase": state.phase,
			"tile_copies": tiles, "tile_locations": locations,
		},
	}
	if state.expansion != null:
		envelope["run_state"]["expansion"] = ExpansionSerializer.encode(state.expansion)
	if state.features != null:
		envelope["run_state"]["features"] = FeatureSerializer.encode(state.features)
	if state.trade != null:
		envelope["run_state"]["trade"] = TradeSerializer.encode(state.trade)
	if state.specialists != null:
		envelope["run_state"]["specialists"] = SpecialistSerializer.encode(state.specialists)
	if state.pending_choice != null:
		envelope["run_state"]["pending_choice"] = SpecialistSerializer.encode_choice(state.pending_choice)
	if state.resolution != null:
		envelope["run_state"]["resolution"] = SpecialistSerializer.encode_resolution(state.resolution)
	return envelope


static func _validate_envelope(value: Variant) -> ValidationResult:
	if not _has_exact_keys(value, ENVELOPE_KEYS):
		return _invalid("Envelope must contain exactly the version headers and run_state.")
	var envelope: Dictionary = value
	if not _is_bounded_integer(envelope["save_schema_version"], 1, 2147483647) \
		or not _is_bounded_integer(envelope["implementation_spec_version"], 1, 2147483647) \
		or not envelope["game_rules_version"] is String \
		or not envelope["godot_version"] is String:
		return _invalid("Invalid version metadata types.")
	if int(envelope["save_schema_version"]) != BuildVersions.SAVE_SCHEMA_VERSION \
		or int(envelope["implementation_spec_version"]) != BuildVersions.IMPLEMENTATION_SPEC_VERSION \
		or envelope["game_rules_version"] != BuildVersions.GAME_RULES_VERSION \
		or envelope["godot_version"] != BuildVersions.godot_version():
		return ValidationResult.failure(&"incompatible_version", "Save requires different rules, schema or engine.")
	var run_keys: Array[String] = RUN_KEYS.duplicate()
	if envelope["run_state"] is Dictionary and envelope["run_state"].has("expansion"):
		run_keys.append("expansion")
	if envelope["run_state"] is Dictionary and envelope["run_state"].has("features"):
		run_keys.append("features")
	if envelope["run_state"] is Dictionary and envelope["run_state"].has("trade"):
		run_keys.append("trade")
	for key: String in ["specialists", "pending_choice", "resolution"]:
		if envelope["run_state"] is Dictionary and envelope["run_state"].has(key):
			run_keys.append(key)
	if not _has_exact_keys(envelope["run_state"], run_keys):
		return _invalid("run_state has missing or unsupported fields.")
	var data: Dictionary = envelope["run_state"]
	for key: String in ["original_seed", "current_rng_state", "rng_operation_count", "next_runtime_id"]:
		if not _is_decimal_int64(data[key]):
			return _invalid("%s must be a canonical signed 64-bit decimal string." % key)
	if String(data["next_runtime_id"]).to_int() < 1 \
		or String(data["rng_operation_count"]).to_int() < 0:
		return _invalid("ID cursor must be positive and RNG operation count nonnegative.")
	if data.has("expansion"):
		if not _is_bounded_integer(data["phase"], GamePhase.Type.TURN_INPUT, GamePhase.Type.PENDING_CHOICE) \
			or int(data["phase"]) == GamePhase.Type.RESOLVING_PLACEMENT:
			return _invalid("Expansion saves require a stable turn, choice or deferred Act boundary.")
		var expansion_shape: ValidationResult = ExpansionSerializer.validate_shape(data["expansion"])
		if not expansion_shape.is_valid:
			return expansion_shape
	elif not _is_bounded_integer(data["phase"], GamePhase.Type.SETUP, GamePhase.Type.SETUP):
		return _invalid("A gameplay phase requires initialized expansion state.")
	if data.has("features"):
		if not data.has("expansion"):
			return _invalid("Feature state requires a board.")
		var feature_shape: ValidationResult = FeatureSerializer.validate_shape(data["features"])
		if not feature_shape.is_valid:
			return feature_shape
	if data.has("trade"):
		if not data.has("features"):
			return _invalid("Trade state requires feature identity.")
		var trade_shape: ValidationResult = TradeSerializer.validate_shape(data["trade"])
		if not trade_shape.is_valid:
			return trade_shape
	for key: String in ["specialists", "pending_choice", "resolution"]:
		if data.has(key):
			if not data.has("features") or (key != "specialists" and not data.has("specialists")):
				return _invalid("Specialist continuation requires a roster and feature state.")
			var specialist_shape: ValidationResult = SpecialistSerializer.validate_shape(data[key], StringName(key))
			if not specialist_shape.is_valid:
				return specialist_shape
	if not data["tile_copies"] is Array or not data["tile_locations"] is Array:
		return _invalid("Physical tile registries must be arrays.")
	for entry: Variant in data["tile_copies"]:
		if not _has_exact_keys(entry, TILE_KEYS):
			return _invalid("Malformed physical tile record.")
		var tile: Dictionary = entry
		if not _is_decimal_int64(tile["tile_copy_id"]) \
			or not tile["definition_id"] is String \
			or not tile["acquisition_source"] is String \
			or not _is_bounded_integer(tile["acquired_act"], 1, 3):
			return _invalid("Invalid physical tile field type or range.")
	for entry: Variant in data["tile_locations"]:
		if not _has_exact_keys(entry, LOCATION_KEYS):
			return _invalid("Malformed physical tile location record.")
		var location: Dictionary = entry
		if not _is_decimal_int64(location["tile_copy_id"]) \
			or not _is_bounded_integer(location["kind"], 0, TileLocationState.Kind.REMOVED_FROM_RUN):
			return _invalid("Invalid physical tile location field type or range.")
	return ValidationResult.success()


static func _has_exact_keys(value: Variant, keys: Array[String]) -> bool:
	if not value is Dictionary:
		return false
	var dictionary: Dictionary = value
	if dictionary.size() != keys.size():
		return false
	for key: String in keys:
		if not dictionary.has(key):
			return false
	return true


static func _is_bounded_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = float(value)
	return is_finite(number) and number == floor(number) \
		and number >= float(minimum) and number <= float(maximum)


static func _is_decimal_int64(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	if text.is_empty():
		return false
	var negative: bool = text.begins_with("-")
	var digits: String = text.substr(1) if negative else text
	if digits.is_empty() or (digits.length() > 1 and digits.begins_with("0")) \
		or (negative and digits == "0"):
		return false
	for index: int in range(digits.length()):
		var character: int = digits.unicode_at(index)
		if character < 48 or character > 57:
			return false
	var limit: String = "9223372036854775808" if negative else "9223372036854775807"
	return digits.length() < limit.length() \
		or (digits.length() == limit.length() and digits <= limit)


static func _invalid(message: String) -> ValidationResult:
	return ValidationResult.failure(&"invalid_save", message)


static func _rejected(code: StringName, message: String, details: Dictionary = {}) -> DeserializationResult:
	return DeserializationResult.new(ValidationResult.failure(code, message, details))
