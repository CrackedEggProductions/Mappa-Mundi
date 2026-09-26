class_name ConditionProgress
extends RefCounted
## Numeric progress plus stable witness IDs; prose is never rule authority.

var key: StringName = &""
var current: int = 0
var target: int = 0
var satisfied: bool = false
var source: StringName = &"current_state"
var exceed: bool = false
var witness_ids: Array[int] = []


func to_dict() -> Dictionary:
	return {"key": String(key), "current": current, "target": target,
		"satisfied": satisfied, "source": String(source), "exceed": exceed,
		"witness_ids": witness_ids.duplicate()}
