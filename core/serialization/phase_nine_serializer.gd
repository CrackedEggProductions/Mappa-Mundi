class_name PhaseNineSerializer
extends RefCounted
## Lossless direct snapshots only. Decoding never selects, seeds, or resumes work.

const CHARTER_NAMES: Array[String] = ["act_one_id", "act_two_id", "grand_id"]
const CHARTER_INTS: Array[String] = ["exact_revealed_act", "exact_revealed_index", "deferred_refill_index"]
const CHARTER_BOOLS: Array[String] = ["forecast_visible", "exact_revealed", "bonus_active"]
const CHARTER_ARRAYS: Array[String] = ["evaluations", "history", "placement_history", "bonus_queue"]
const TRANSITION_INTS: Array[String] = ["transition_id", "outgoing_act", "incoming_act", "step",
	"pending_charter_reward_index", "reward_history_start", "pending_hand_refill"]
const TRANSITION_BOOLS: Array[String] = ["rewards_queued", "advanced", "capacity_refreshed",
	"survey_refreshed", "relics_refreshed", "unlocked", "seeded", "shuffled",
	"information_selected", "counter_reset", "refill_done"]
const RESULT_NAMES: Array[String] = ["grand_charter_id", "grand_charter_result", "victory_result"]


static func keys(kind: StringName) -> Array[String]:
	var result: Array[String] = []
	match kind:
		&"charters":
			result.append_array(CHARTER_NAMES + CHARTER_INTS + CHARTER_BOOLS + CHARTER_ARRAYS)
			result.append("completed_act_placements")
		&"act_transition":
			result.append_array(TRANSITION_INTS + TRANSITION_BOOLS)
			result.append_array(["charter_result", "rewards", "seeded_copy_ids"])
		&"final_result":
			result.append_array(RESULT_NAMES)
			result.append_array(["score", "tracks", "statistics"])
	return result


static func encode(value: RefCounted, kind: StringName) -> Dictionary:
	var data: Dictionary = {}
	for key: String in keys(kind):
		data[key] = value.get(key)
	return SpecialistValueCodec.encode(data)


static func decode(value: Dictionary, kind: StringName) -> RefCounted:
	var data: Dictionary = SpecialistValueCodec.decode(value)
	var result: RefCounted
	match kind:
		&"charters": result = CharterState.new()
		&"act_transition": result = ActTransitionState.new()
		_: result = RunResult.new()
	for key: String in keys(kind):
		if data[key] is Array:
			var destination: Array = result.get(key)
			destination.assign(data[key])
		else:
			result.set(key, data[key])
	return result


static func validate_shape(value: Variant, kind: StringName) -> ValidationResult:
	if not SpecialistValueCodec.valid(value):
		return _invalid()
	var data: Variant = SpecialistValueCodec.decode(value)
	if keys(kind).is_empty() or not RunSerializer._has_exact_keys(data, keys(kind)):
		return _invalid()
	match kind:
		&"charters":
			if not _types(data, CHARTER_NAMES, TYPE_STRING_NAME) or not _types(data, CHARTER_INTS, TYPE_INT) \
					or not _types(data, CHARTER_BOOLS, TYPE_BOOL) or not _array_of(data["completed_act_placements"], TYPE_INT):
				return _invalid()
			for key: String in CHARTER_ARRAYS:
				if not _array_of(data[key], TYPE_DICTIONARY):
					return _invalid()
		&"act_transition":
			if not _types(data, TRANSITION_INTS, TYPE_INT) or not _types(data, TRANSITION_BOOLS, TYPE_BOOL) \
					or not data["charter_result"] is Dictionary or not _array_of(data["rewards"], TYPE_STRING_NAME) \
					or not _array_of(data["seeded_copy_ids"], TYPE_INT):
				return _invalid()
		&"final_result":
			if not _types(data, RESULT_NAMES, TYPE_STRING_NAME) or not data["score"] is int \
					or not _array_of(data["tracks"], TYPE_INT) or not data["statistics"] is Dictionary:
				return _invalid()
	return ValidationResult.success()


static func _types(data: Dictionary, fields: Array[String], type: int) -> bool:
	for field: String in fields:
		if typeof(data[field]) != type:
			return false
	return true


static func _array_of(value: Variant, type: int) -> bool:
	if not value is Array:
		return false
	for item: Variant in value:
		if typeof(item) != type:
			return false
	return true


static func _invalid() -> ValidationResult:
	return ValidationResult.failure(&"invalid_save", "Malformed Charter, Act transition, or final result snapshot.")
