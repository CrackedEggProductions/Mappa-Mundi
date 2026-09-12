class_name RunRNG
extends RefCounted
## The single run-owned gameplay stream. Cosmetic effects must use another service.
## Replays are engine-version-specific; restore seed first, then native state.

const MIN_RANGE_VALUE: int = -2147483648
const MAX_RANGE_VALUE: int = 2147483647
const MAX_OPERATION_COUNT: int = 9223372036854775807

var original_seed: int:
	get:
		return _original_seed
var current_state: int:
	get:
		return _engine.state
var operation_count: int:
	get:
		return _operation_count
## Optional transient diagnostics; enabling logging never changes random draws.
var debug_logging_enabled: bool = false

var _engine: RandomNumberGenerator = RandomNumberGenerator.new()
var _original_seed: int
var _operation_count: int = 0
var _debug_reasons: Array[StringName] = []


func _init(seed_value: int) -> void:
	_original_seed = seed_value
	_engine.seed = seed_value


static func from_snapshot(seed_value: int, state_value: int, count: int) -> RunRNG:
	if count < 0:
		_reject("RNG operation count must be nonnegative")
		return null
	var restored: RunRNG = RunRNG.new(seed_value)
	restored._engine.state = state_value
	restored._operation_count = count
	return restored


static func is_valid_range(minimum: int, maximum: int) -> bool:
	return minimum >= MIN_RANGE_VALUE and maximum <= MAX_RANGE_VALUE and minimum <= maximum


static func are_ordered_candidates_valid(ordered_candidates: Array[StringName]) -> bool:
	if ordered_candidates.is_empty():
		return false
	for index: int in range(ordered_candidates.size()):
		if ordered_candidates[index] == &"":
			return false
		if index > 0 and String(ordered_candidates[index - 1]) >= String(ordered_candidates[index]):
			return false
	return true


func integer_range(minimum: int, maximum: int, reason: StringName = &"range") -> int:
	if not is_valid_range(minimum, maximum):
		_reject("RNG range must be ordered and fit signed 32-bit bounds")
		return 0
	if not _record_operation(reason):
		return 0
	return _engine.randi_range(minimum, maximum)


func select_index(size: int, reason: StringName = &"index") -> int:
	if size <= 0 or size - 1 > MAX_RANGE_VALUE:
		_reject("RNG index selection requires a positive supported collection size")
		return -1
	if not _record_operation(reason):
		return -1
	return _engine.randi_range(0, size - 1)


func shuffled_ids(values: Array[int], reason: StringName = &"shuffle") -> Array[int]:
	var shuffled: Array[int] = values.duplicate()
	if not _record_operation(reason):
		return shuffled
	# Fisher-Yates: one public operation, multiple native draws; never mutate input.
	for index: int in range(shuffled.size() - 1, 0, -1):
		var selected: int = _engine.randi_range(0, index)
		var previous: int = shuffled[index]
		shuffled[index] = shuffled[selected]
		shuffled[selected] = previous
	return shuffled


func choose_definition_id(
	ordered_candidates: Array[StringName], reason: StringName = &"choice"
) -> StringName:
	if not are_ordered_candidates_valid(ordered_candidates):
		_reject("RNG candidates must be nonempty, unique and lexically sorted definition IDs")
		return &""
	if not _record_operation(reason):
		return &""
	return ordered_candidates[_engine.randi_range(0, ordered_candidates.size() - 1)]


func debug_reasons() -> Array[StringName]:
	return _debug_reasons.duplicate()


func _record_operation(reason: StringName) -> bool:
	if _operation_count == MAX_OPERATION_COUNT:
		_reject("RNG operation counter is exhausted")
		return false
	_operation_count += 1
	if debug_logging_enabled:
		_debug_reasons.append(reason)
	return true


static func _reject(message: String) -> void:
	push_error(message)
	assert(false, message)
