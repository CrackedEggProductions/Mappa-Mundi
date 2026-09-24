class_name StewardRelayRules
extends RefCounted
## Same-piece return exception. Contact comes from board topology, never UI proximity.


static func begin_next(state: RunState) -> bool:
	var resolution: ResolutionState = state.resolution
	var queue: Array = resolution.context.get("relay_queue", [])
	while not queue.is_empty():
		var returned: Dictionary = queue[0]
		var options: Array[Dictionary] = options_for(state, returned)
		if options.is_empty():
			queue.pop_front()
			continue
		var choice: PendingChoice = PendingChoice.new()
		choice.choice_id = state.id_allocator.allocate()
		choice.kind = &"specialist_relay"
		choice.options = options
		choice.context = {"returned": returned.duplicate(true), "decline_allowed": true}
		state.pending_choice = choice
		state.phase = GamePhase.Type.PENDING_CHOICE
		return true
	return false


static func options_for(state: RunState, returned: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var piece: SpecialistPieceState = state.specialists.piece(int(returned.get("piece_id", 0)))
	if piece == null or piece.status != SpecialistPieceState.Status.AVAILABLE:
		return result
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	var source_type: int = int(returned.get("target_type", -1))
	var source_id: int = int(returned.get("target_id", 0))
	var targets: Array[Dictionary] = []
	for feature: CurrentFeature in current:
		if touches(state, source_type, source_id, feature.feature_type, feature.lineage_id, current):
			targets.append({"target_type": feature.feature_type, "target_id": feature.lineage_id})
	for enclosure: EnclosureState in state.features.enclosures:
		if touches(state, source_type, source_id, SpecialistRules.ENCLOSURE, enclosure.enclosure_id, current):
			targets.append({"target_type": SpecialistRules.ENCLOSURE, "target_id": enclosure.enclosure_id})
	for option: Dictionary in SpecialistRules.assignment_options(state, targets):
		if option["piece_id"] == piece.piece_id:
			result.append(option)
	return result


static func touches(state: RunState, source_type: int, source_id: int, target_type: int,
		target_id: int, current: Array[CurrentFeature]) -> bool:
	if source_type == target_type and source_id == target_id:
		return false
	var from_coordinates: Array[Vector2i] = _coordinates(state, source_type, source_id, current)
	var to_coordinates: Array[Vector2i] = _coordinates(state, target_type, target_id, current)
	for origin: Vector2i in from_coordinates:
		for target: Vector2i in to_coordinates:
			var delta: Vector2i = target - origin
			if source_type == SpecialistRules.ENCLOSURE or target_type == SpecialistRules.ENCLOSURE:
				# Only the enclosure relation has the canonical eight-neighbor exception.
				if maxi(absi(delta.x), absi(delta.y)) <= 1:
					return true
			elif absi(delta.x) + absi(delta.y) == 1:
				return true
			elif delta == Vector2i.ZERO:
				var cell: BoardCellState = state.expansion.board.get_cell(origin)
				for relation: TileFeatureRelationship in cell.relationships:
					var a: int = FeatureState.type_for_edge(relation.from_edge_type)
					var b: int = FeatureState.type_for_edge(relation.to_edge_type)
					if (a == source_type and b == target_type) or (a == target_type and b == source_type):
						return true
	return false


static func _coordinates(state: RunState, type: int, id: int,
		current: Array[CurrentFeature]) -> Array[Vector2i]:
	var coordinates: Array[Vector2i] = []
	if type == SpecialistRules.ENCLOSURE:
		var enclosure: EnclosureState = SpecialistRules.find_enclosure(state, id)
		if enclosure != null:
			coordinates.append(enclosure.coordinate)
	else:
		var feature: CurrentFeature = SpecialistRules.find_feature(current, id)
		if feature != null:
			coordinates.assign(feature.coordinates)
	return coordinates


static func validate_command(state: RunState, command: ResolveRelayCommand) -> ValidationResult:
	if state.relics == null or state.phase != GamePhase.Type.PENDING_CHOICE \
			or state.pending_choice == null or state.pending_choice.kind != &"specialist_relay" \
			or state.resolution == null or state.resolution.stage != &"specialist_relay":
		return ValidationResult.failure(&"wrong_relay_phase", "No returned-piece Relay choice is pending.")
	if command.choice_id != state.pending_choice.choice_id \
			or (command.expected_state_revision != -1 and command.expected_state_revision != state.expansion.state_revision):
		return ValidationResult.failure(&"stale_relay_choice", "The persisted Relay opportunity changed.")
	if command.option_index < -1 or command.option_index >= state.pending_choice.options.size():
		return ValidationResult.failure(&"invalid_relay_option", "Choose a persisted target or decline.")
	if not valid_choice(state):
		return ValidationResult.failure(&"stale_relay_targets", "Relay targets no longer match authoritative touching features.")
	return ValidationResult.success()


static func valid_choice(state: RunState) -> bool:
	var choice: PendingChoice = state.pending_choice
	if choice == null or state.resolution == null or state.resolution.stage != &"specialist_relay":
		return false
	if not RunSerializer._has_exact_keys(choice.context, ["returned", "decline_allowed"]) \
			or not choice.context["returned"] is Dictionary or choice.context["decline_allowed"] != true:
		return false
	var queue: Variant = state.resolution.context.get("relay_queue", [])
	if not queue is Array or queue.is_empty() or queue[0] != choice.context["returned"]:
		return false
	var returned: Dictionary = choice.context["returned"]
	for key: String in ["piece_id", "target_type", "target_id"]:
		if not returned.get(key) is int:
			return false
	var snapshot: CompletionSnapshot = CompletionSnapshot.new(state.resolution.completion_snapshot)
	if not RelicRules.snapshot_active(snapshot, &"relic.stewards_relay"):
		return false
	if returned not in SpecialistRules.calculate(snapshot):
		return false
	var genuine_return: bool = false
	for event: Dictionary in state.specialists.history:
		if event.get("kind") == "specialist_returned" and event.get("piece_id") == returned["piece_id"] \
				and event.get("target_type") == returned["target_type"] and event.get("target_id") == returned["target_id"]:
			for history: FeatureHistoryRecord in state.features.history:
				if history.event_id == event.get("event_id") and history.parent_event_id == state.resolution.context.get("snapshot_event_id", 0):
					genuine_return = true
	if not genuine_return:
		return false
	return not choice.options.is_empty() and choice.options == options_for(state, returned)


static func execute_command(state: RunState, command: ResolveRelayCommand) -> void:
	if command.option_index >= 0:
		var option: Dictionary = state.pending_choice.options[command.option_index]
		# Reuse the canonical assignment mutation; only the validated opportunity differs.
		SpecialistCommands._assign(state, ResolveSpecialistAssignmentCommand.new(
			command.choice_id, option["piece_id"], option["target_type"], option["target_id"]))
	else:
		state.pending_choice = null
		state.phase = GamePhase.Type.RESOLVING_PLACEMENT
	state.resolution.context["relay_queue"].pop_front()
