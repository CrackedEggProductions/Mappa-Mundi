class_name SpecialistSerializer
extends RefCounted
## Pure value conversion. No ID allocation, topology reconciliation or rules on load.

const PIECE_KEYS: Array[String] = ["piece_id", "role_definition_id", "status",
	"assigned_target_type", "assigned_target_id", "assigned_act", "assigned_placement_index",
	"growth_baseline_component_ids", "qualifying_component_ids", "training_history"]
const CHOICE_KEYS: Array[String] = ["choice_id", "kind", "options", "context"]
const RESOLUTION_KEYS: Array[String] = ["source_id", "stage", "affected_targets",
	"completion_snapshot", "immediate_development_copy_id", "immediate_parent_event_id"]


static func encode(state: SpecialistState) -> Dictionary:
	var pieces: Array[Dictionary] = []
	for piece: SpecialistPieceState in state.pieces:
		var record: Dictionary = {}
		for key: String in PIECE_KEYS:
			record[key] = piece.get(key)
		for key: String in ["growth_baseline_component_ids", "qualifying_component_ids"]:
			record[key] = record[key].duplicate()
			record[key].sort()
		pieces.append(record)
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["piece_id"] < b["piece_id"])
	return SpecialistValueCodec.encode({"pieces": pieces, "history": state.history,
		"deferred_rewards": state.deferred_rewards})


static func encode_choice(choice: PendingChoice) -> Dictionary:
	return _encode_fields(choice, CHOICE_KEYS)


static func encode_resolution(resolution: ResolutionState) -> Dictionary:
	return _encode_fields(resolution, RESOLUTION_KEYS)


static func _encode_fields(object: RefCounted, keys: Array[String]) -> Dictionary:
	var record: Dictionary = {}
	for key: String in keys:
		record[key] = object.get(key)
	return SpecialistValueCodec.encode(record)


static func decode(value: Dictionary) -> SpecialistState:
	var data: Dictionary = SpecialistValueCodec.decode(value)
	var state: SpecialistState = SpecialistState.new()
	for record: Dictionary in data["pieces"]:
		var piece: SpecialistPieceState = SpecialistPieceState.new()
		for key: String in PIECE_KEYS:
			if key not in ["growth_baseline_component_ids", "qualifying_component_ids", "training_history"]:
				piece.set(key, record[key])
		piece.growth_baseline_component_ids.assign(record["growth_baseline_component_ids"])
		piece.qualifying_component_ids.assign(record["qualifying_component_ids"])
		piece.training_history.assign(record["training_history"])
		state.pieces.append(piece)
	state.history.assign(data["history"])
	state.deferred_rewards.assign(data["deferred_rewards"])
	return state


static func decode_choice(value: Dictionary) -> PendingChoice:
	var data: Dictionary = SpecialistValueCodec.decode(value)
	var choice: PendingChoice = PendingChoice.new()
	choice.choice_id = data["choice_id"]
	choice.kind = data["kind"]
	choice.options.assign(data["options"])
	choice.context = data["context"]
	return choice


static func decode_resolution(value: Dictionary) -> ResolutionState:
	var data: Dictionary = SpecialistValueCodec.decode(value)
	var resolution: ResolutionState = ResolutionState.new()
	for key: String in RESOLUTION_KEYS:
		if key != "affected_targets":
			resolution.set(key, data[key])
	resolution.affected_targets.assign(data["affected_targets"])
	return resolution


static func validate_shape(value: Variant, kind: StringName) -> ValidationResult:
	if not SpecialistValueCodec.valid(value):
		return _invalid("Malformed typed Specialist save tree.")
	var data: Variant = SpecialistValueCodec.decode(value)
	if kind == &"specialists":
		if not RunSerializer._has_exact_keys(data, ["pieces", "history", "deferred_rewards"]) \
				or not _dictionaries(data["pieces"]) or not _dictionaries(data["history"]) \
				or not _dictionaries(data["deferred_rewards"]):
			return _invalid("Malformed Specialist registry.")
		for record: Dictionary in data["pieces"]:
			if not RunSerializer._has_exact_keys(record, PIECE_KEYS):
				return _invalid("Malformed Specialist piece.")
			for key: String in ["piece_id", "status", "assigned_target_type", "assigned_target_id", "assigned_act", "assigned_placement_index"]:
				if not record[key] is int:
					return _invalid("Specialist IDs and counters must be integers.")
			if not record["role_definition_id"] is StringName \
					or not _integers(record["growth_baseline_component_ids"]) \
					or not _integers(record["qualifying_component_ids"]) \
					or not _dictionaries(record["training_history"]):
				return _invalid("Invalid Specialist role, growth or history type.")
	elif kind == &"pending_choice":
		if not RunSerializer._has_exact_keys(data, CHOICE_KEYS) \
				or not data["choice_id"] is int or not data["kind"] is StringName \
				or not _dictionaries(data["options"]) or not data["context"] is Dictionary:
			return _invalid("Malformed pending Specialist choice.")
	elif kind == &"resolution":
		if not RunSerializer._has_exact_keys(data, RESOLUTION_KEYS) \
				or not data["stage"] is StringName or not _dictionaries(data["affected_targets"]) \
				or not data["completion_snapshot"] is Dictionary \
				or not valid_snapshot_collections(data["completion_snapshot"]):
			return _invalid("Malformed Specialist continuation.")
		for key: String in ["source_id", "immediate_development_copy_id", "immediate_parent_event_id"]:
			if not data[key] is int:
				return _invalid("Continuation IDs must be integers.")
	else:
		return _invalid("Unknown Specialist save record.")
	return ValidationResult.success()


static func _dictionaries(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not entry is Dictionary:
			return false
	return true


static func _integers(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not entry is int:
			return false
	return true


static func _invalid(message: String) -> ValidationResult:
	return ValidationResult.failure(&"invalid_save", message)


static func valid_snapshot_collections(snapshot: Dictionary) -> bool:
	# These collections are read by feature invariants before exact snapshot comparison.
	for key: String in ["features", "enclosures", "specialists", "developments"]:
		if not _dictionaries(snapshot.get(key)):
			return false
	for facts: Dictionary in snapshot["features"]:
		if not facts.get("lineage_id") is int:
			return false
	for facts: Dictionary in snapshot["enclosures"]:
		if not facts.get("enclosure_id") is int or not facts.get("stage") is String:
			return false
	return true
