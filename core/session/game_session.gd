class_name GameSession
extends RefCounted
## Run-scoped facade over the existing authoritative engine; usable headlessly.

var state: RunState
var content: ContentRegistry
var _executing: bool = false


func _init(run: RunState, registry: ContentRegistry) -> void:
	state = run
	content = registry


static func start(seed_value: int, registry: ContentRegistry) -> GameSession:
	return GameSession.new(HomesteadRunFactory.create(seed_value, registry), registry)


func validate(command: PlayerCommand) -> ValidationResult:
	return RulesEngine.validate(state, content, command)


func options(copy_id: int) -> Array[PlacementOption]:
	return PlacementQueryService.query_for_copy(state, content, copy_id)


func execute(command: PlayerCommand) -> ResolutionResult:
	var report: ResolutionResult = ResolutionResult.new()
	if _executing:
		report.validation = ValidationResult.failure(&"command_in_progress", "Please wait for the current action.")
		return report
	_executing = true
	report.previous_act = state.expansion.current_act
	report.previous_grand_revealed = state.charters != null and state.charters.exact_revealed
	var tracks: Array[int] = state.features.tracks.values.duplicate()
	var lengths: Array[int] = [state.features.history.size()]
	var histories: Array[Array] = _histories()
	for records: Array in histories:
		lengths.append(records.size())
	report.validation = RulesEngine.execute(state, content, command)
	report.phase = state.phase
	if report.validation.is_valid:
		for index: int in range(4):
			report.track_deltas[index] = state.features.tracks.values[index] - tracks[index]
		var seen: Dictionary = {}
		for index: int in range(lengths[0], state.features.history.size()):
			var record: FeatureHistoryRecord = state.features.history[index]
			report.cues.append({"event_id": record.event_id, "kind": String(record.kind),
				"lineage_id": record.lineage_id, "amount": record.amount, "track": record.track})
			seen[record.event_id] = true
		for history_index: int in range(histories.size()):
			var records: Array = histories[history_index]
			for index: int in range(lengths[history_index + 1], records.size()):
				var record: Dictionary = records[index]
				var event_id: int = record.get("event_id", 0)
				if event_id != 0 and seen.has(event_id):
					continue
				seen[event_id] = true
				report.cues.append(record.duplicate(true))
		report.cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("event_id", 0)) < int(b.get("event_id", 0)))
	_executing = false
	return report


func _histories() -> Array[Array]:
	var result: Array[Array] = []
	if state.specialists != null:
		result.append(state.specialists.history)
	if state.relics != null:
		result.append(state.relics.history)
	if state.rewards != null:
		result.append(state.rewards.history)
	if state.charters != null:
		result.append(state.charters.history)
	return result
