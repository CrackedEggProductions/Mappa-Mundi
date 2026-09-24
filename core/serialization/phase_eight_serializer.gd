class_name PhaseEightSerializer
extends RefCounted
## Pure lossless snapshot conversion. No acquisition, offers, RNG or event replay.

const INSTANCE_KEYS: Array[String] = ["runtime_id", "definition_id", "acquisition_order",
	"acquired_act", "equipped_slot", "use_act", "uses_remaining", "removed_act", "once_per_act"]
const RELIC_KEYS: Array[String] = ["instances", "capacity", "current_act", "normal_surveys_used", "history"]
const REWARD_KEYS: Array[String] = ["threshold_flags", "milestone_flags", "queue", "history"]


static func encode_relics(state: RelicState) -> Dictionary:
	var instances: Array[Dictionary] = []
	for instance: RelicInstanceState in state.instances:
		var data: Dictionary = {}
		for key: String in INSTANCE_KEYS:
			data[key] = instance.get(key)
		instances.append(data)
	instances.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["acquisition_order"] < b["acquisition_order"])
	return SpecialistValueCodec.encode({"instances": instances, "capacity": state.capacity,
		"current_act": state.current_act, "normal_surveys_used": state.normal_surveys_used,
		"history": state.history})


static func encode_rewards(state: RewardState) -> Dictionary:
	var flags: Array[String] = state.threshold_flags.duplicate()
	flags.sort()
	var milestones: Array[StringName] = state.milestone_flags.duplicate()
	milestones.sort()
	return SpecialistValueCodec.encode({"threshold_flags": flags, "milestone_flags": milestones,
		"queue": state.queue, "history": state.history})


static func decode_relics(value: Dictionary) -> RelicState:
	var data: Dictionary = SpecialistValueCodec.decode(value)
	var state: RelicState = RelicState.new()
	for record: Dictionary in data["instances"]:
		var instance: RelicInstanceState = RelicInstanceState.new()
		for key: String in INSTANCE_KEYS:
			instance.set(key, record[key])
		state.instances.append(instance)
	state.capacity = data["capacity"]
	state.current_act = data["current_act"]
	state.normal_surveys_used = data["normal_surveys_used"]
	state.history.assign(data["history"])
	return state


static func decode_rewards(value: Dictionary) -> RewardState:
	var data: Dictionary = SpecialistValueCodec.decode(value)
	var state: RewardState = RewardState.new()
	state.threshold_flags.assign(data["threshold_flags"])
	state.milestone_flags.assign(data["milestone_flags"])
	state.queue.assign(data["queue"])
	state.history.assign(data["history"])
	return state


static func validate_shape(value: Variant, kind: StringName) -> ValidationResult:
	if not SpecialistValueCodec.valid(value):
		return _invalid("Malformed lossless Relic/reward value tree.")
	var data: Variant = SpecialistValueCodec.decode(value)
	if kind == &"relics":
		if not RunSerializer._has_exact_keys(data, RELIC_KEYS) \
				or not SpecialistSerializer._dictionaries(data["instances"]) \
				or not SpecialistSerializer._dictionaries(data["history"]):
			return _invalid("Malformed Relic registry.")
		for key: String in ["capacity", "current_act", "normal_surveys_used"]:
			if not data[key] is int:
				return _invalid("Relic counters must be exact integers.")
		for instance: Dictionary in data["instances"]:
			if not RunSerializer._has_exact_keys(instance, INSTANCE_KEYS) \
					or not instance["definition_id"] is StringName or not instance["once_per_act"] is bool:
				return _invalid("Malformed Relic instance.")
			for key: String in INSTANCE_KEYS:
				if key not in ["definition_id", "once_per_act"] and not instance[key] is int:
					return _invalid("Relic identity and counters must be exact integers.")
	elif kind == &"rewards":
		if not RunSerializer._has_exact_keys(data, REWARD_KEYS) \
				or not _strings(data["threshold_flags"], false) or not _strings(data["milestone_flags"], true) \
				or not SpecialistSerializer._dictionaries(data["queue"]) \
				or not SpecialistSerializer._dictionaries(data["history"]):
			return _invalid("Malformed reward queue/history.")
	else:
		return _invalid("Unknown Phase-8 save record.")
	return ValidationResult.success()


static func _strings(value: Variant, names: bool) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if (names and not entry is StringName) or (not names and not entry is String):
			return false
	return true


static func _invalid(message: String) -> ValidationResult:
	return ValidationResult.failure(&"invalid_save", message)
