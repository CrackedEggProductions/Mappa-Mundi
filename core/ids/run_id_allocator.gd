class_name RunIdAllocator
extends RefCounted
## One monotonically increasing space per run, shared by all future entity kinds.
## The final signed integer is reserved as the exhausted cursor, never allocated.

const EXHAUSTED_CURSOR: int = 9223372036854775807

var _next_id: int = 1


func _init(next_id: int = 1) -> void:
	if next_id < 1:
		push_error("RunIdAllocator requires a positive validated continuation cursor.")
		assert(false, "Invalid runtime ID cursor")
		return
	_next_id = next_id


func allocate() -> int:
	if _next_id == EXHAUSTED_CURSOR:
		push_error("RunIdAllocator exhausted its run-local ID space.")
		assert(false, "Runtime ID space exhausted")
		return 0
	var allocated_id: int = _next_id
	_next_id += 1
	return allocated_id


func get_next_id() -> int:
	return _next_id
