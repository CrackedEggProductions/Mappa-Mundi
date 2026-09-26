class_name CharterProgress
extends RefCounted
## Pure evaluation output, suitable for presentation and a frozen historical record.

var charter_id: StringName = &""
var overall_state: StringName = &"failed"
var conditions: Array[ConditionProgress] = []


func add(key: StringName, current: int, target: int, source: StringName = &"current_state",
		exceed: bool = false, witnesses: Array[int] = []) -> void:
	var condition: ConditionProgress = ConditionProgress.new()
	condition.key = key
	condition.current = current
	condition.target = target
	condition.satisfied = current >= target
	condition.source = source
	condition.exceed = exceed
	condition.witness_ids = witnesses.duplicate()
	condition.witness_ids.sort()
	conditions.append(condition)


func finish() -> void:
	var fulfilled: bool = not conditions.is_empty()
	var exceeded: bool = true
	for condition: ConditionProgress in conditions:
		if condition.exceed:
			exceeded = exceeded and condition.satisfied
		else:
			fulfilled = fulfilled and condition.satisfied
	overall_state = &"failed" if not fulfilled else (&"exceeded" if exceeded else &"fulfilled")


func to_dict() -> Dictionary:
	var values: Array[Dictionary] = []
	for condition: ConditionProgress in conditions:
		values.append(condition.to_dict())
	return {"charter_id": String(charter_id), "overall_state": String(overall_state), "conditions": values}
