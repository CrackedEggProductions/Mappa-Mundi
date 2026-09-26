extends RefCounted
## Controlled acquisition and one initial training reward; all scoring is canonical.
## This is a reproducible integration fixture, not a claim of naturally optimized play.

const Previous = preload("res://tests/fixtures/phase_eight_factory.gd")
const Acquisition = preload("res://tests/fixtures/phase_five_factory.gd")
const Intent = preload("res://tests/fixtures/phase_six_factory.gd")


static func content() -> ContentRegistry:
	var registry: ContentRegistry = ContentRegistry.new()
	var loaded: ValidationResult = registry.load_phase_nine()
	assert(loaded.is_valid, loaded.user_message)
	return registry


static func scripted(registry: ContentRegistry, seed_value: int, outcome: int = 0,
		reload_boundaries: bool = false, stop_after_act: int = 3) -> Dictionary:
	var state: RunState = HomesteadRunFactory.create(seed_value, registry)
	train_naturalist(state, registry)
	var trace: Dictionary = {"commands": [], "choices": [], "turns": [],
		"act_counts": [0, 0, 0], "round_trips": 0, "transition_entries": [],
		"midpoint_pending": [], "saved_choices": [], "initial_charter": state.charters.act_one_id}
	for act: int in range(1, stop_after_act + 1):
		var recipe: Array[Dictionary] = placements(act, outcome)
		for index: int in range(recipe.size()):
			assert(state.phase == GamePhase.Type.TURN_INPUT, "A scripted placement requires normal input")
			assert(state.expansion.current_act == act, "Transition must advance through the real rules path")
			assert(state.expansion.normal_placements == index, "Only actual commands increment placements")
			var entry: Dictionary = recipe[index]
			var copy_id: int = Acquisition.acquire_hand(state, StringName(entry["definition_id"]))
			var command: PlaceTileCommand = _intent(state, registry, copy_id, entry)
			var accepted: ValidationResult = RulesEngine.execute(state, registry, command)
			assert(accepted.is_valid, accepted.user_message + str(accepted.debug_details))
			trace["commands"].append({"act": act, "placement": index + 1,
				"definition_id": entry["definition_id"], "copy_id": copy_id,
				"coordinate": entry["coordinate"], "rotation": entry["rotation"]})
			trace["act_counts"][act - 1] += 1
			state = drain(state, registry, trace, reload_boundaries)
			trace["turns"].append({"outgoing_act": act, "placement": index + 1,
				"act": state.expansion.current_act, "phase": state.phase,
				"counter": state.expansion.normal_placements,
				"grand_id": state.charters.grand_id,
				"exact_revealed": state.charters.exact_revealed,
				"hand": state.expansion.hand.duplicate(), "rng_operations": state.rng.operation_count})
			if state.expansion.current_act != act:
				trace["transition_entries"].append({"act": state.expansion.current_act,
					"capacity": state.relics.capacity, "survey_charges": state.expansion.survey_charges,
					"board_size": state.expansion.board.cells.size(), "hand": state.expansion.hand.duplicate(),
					"grand_id": state.charters.grand_id, "exact_revealed": state.charters.exact_revealed})
			if reload_boundaries:
				state = round_trip(state, registry)
				trace["round_trips"] += 1
	trace["state"] = state
	trace["fingerprint"] = StateNormalizer.fingerprint(state)
	return trace


static func drain(state: RunState, registry: ContentRegistry, trace: Dictionary,
		reload_boundaries: bool = false) -> RunState:
	var guard: int = 0
	while state.pending_choice != null:
		guard += 1
		assert(guard < 100, "A consequence queue must make bounded progress")
		var choice: PendingChoice = state.pending_choice
		trace["choices"].append({"kind": choice.kind, "options": choice.options.duplicate(true),
			"act": state.expansion.current_act, "placement": state.expansion.normal_placements,
			"grand_revealed": state.charters.exact_revealed, "rng_operations": state.rng.operation_count,
			"in_transition": state.act_transition != null, "capacity": state.relics.capacity})
		if state.expansion.current_act == 2 and state.expansion.normal_placements == 11:
			trace["midpoint_pending"].append(state.charters.exact_revealed)
		if reload_boundaries:
			if state.act_transition != null:
				var snapshot: SerializationResult = RunSerializer.serialize(state, registry)
				assert(snapshot.validation.is_valid, str(snapshot.validation.debug_details))
				trace["saved_choices"].append({"kind": choice.kind, "act": state.expansion.current_act,
					"step": state.act_transition.step, "json": snapshot.json_text})
			state = round_trip(state, registry)
			trace["round_trips"] += 1
		var command: PlayerCommand = choice_command(state)
		var accepted: ValidationResult = RulesEngine.execute(state, registry, command)
		assert(accepted.is_valid, accepted.user_message + str(accepted.debug_details))
	return state


static func choice_command(state: RunState) -> PlayerCommand:
	var choice: PendingChoice = state.pending_choice
	match choice.kind:
		&"specialist_assignment":
			return _assignment_command(state)
		&"specialist_training":
			return ResolveSpecialistTrainingCommand.new(choice.choice_id,
				StringName(choice.options[0]["role_definition_id"]))
		&"specialist_relay":
			return ResolveRelayCommand.new(choice.choice_id)
		&"grand_survey":
			return ResolveGrandSurveyCommand.new(choice.choice_id, 0, true)
		_:
			assert(RewardCommands.KINDS.has(choice.kind), "Unexpected scripted choice: " + String(choice.kind))
			return ResolveRewardCommand.new(choice.choice_id, 0)


static func round_trip(state: RunState, registry: ContentRegistry) -> RunState:
	var before: String = StateNormalizer.fingerprint(state)
	var restored: RunState = Previous.load_copy(state, registry)
	assert(StateNormalizer.fingerprint(restored) == before, "Loading must be a pure snapshot restoration")
	return restored


static func placements(act: int, outcome: int = 0) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if act == 1:
		for x: int in range(1, 8):
			entries.append(_entry(&"tile.forest_belt", Vector2i(-x, 0), 1))
		entries.append(_entry(&"tile.forest_edge", Vector2i(-8, 0), 1))
		for y: int in range(1, 8):
			entries.append(_entry(&"tile.river_run", Vector2i(0, y)))
		entries.append(_entry(&"tile.river_end", Vector2i(0, 8)))
		entries.append(_entry(&"tile.hamlet_edge", Vector2i.UP, 2))
		entries.append(_entry(&"tile.road_end", Vector2i.RIGHT, 3))
	elif act == 2:
		for coordinate: Vector2i in [Vector2i(-3, -1), Vector2i(-3, -2), Vector2i(-3, -3),
				Vector2i(-4, -3), Vector2i(-4, -2), Vector2i(-4, -4), Vector2i(-3, -4)]:
			entries.append(_entry(&"tile.open_fields", coordinate))
		entries.append(_entry(&"tile.development.monastery", Vector2i(-3, -3)))
		_forest(entries, -1, -1, 8)
		_forest(entries, -2, -1, 6)
	else:
		if outcome > 0:
			entries.append(_entry(&"tile.development.abbey", Vector2i(-3, -3)))
			entries.append(_entry(&"tile.development.foresters_lodge", Vector2i(-1, 0)))
			entries.append(_entry(&"tile.development.foresters_lodge", Vector2i(-2, 0)))
			_monastery(entries, -5)
		var final_cap: Dictionary = {}
		if outcome > 1:
			_forest(entries, -2, -7, 9)
			final_cap = entries.pop_back()
			_monastery(entries, -7)
		var remaining: int = 26 - entries.size() - (0 if final_cap.is_empty() else 1)
		for x: int in range(remaining):
			entries.append(_entry(&"tile.open_fields", Vector2i(-5 - x, -3)))
		if not final_cap.is_empty():
			entries.append(final_cap)
	return entries


static func _forest(entries: Array[Dictionary], x: int, start_y: int, size: int) -> void:
	entries.append(_entry(&"tile.forest_edge", Vector2i(x, start_y)))
	for step: int in range(1, size - 1):
		entries.append(_entry(&"tile.forest_belt", Vector2i(x, start_y - step)))
	entries.append(_entry(&"tile.forest_edge", Vector2i(x, start_y - size + 1), 2))


static func _monastery(entries: Array[Dictionary], y: int) -> void:
	entries.append(_entry(&"tile.open_fields", Vector2i(-3, y)))
	entries.append(_entry(&"tile.development.monastery", Vector2i(-3, y)))
	for coordinate: Vector2i in [Vector2i(-4, y), Vector2i(-4, y - 1), Vector2i(-3, y - 1)]:
		entries.append(_entry(&"tile.open_fields", coordinate))
	entries.append(_entry(&"tile.development.abbey", Vector2i(-3, y)))


static func _entry(id: StringName, coordinate: Vector2i, rotation: int = 0) -> Dictionary:
	return {"definition_id": id, "coordinate": coordinate, "rotation": rotation}


static func _intent(state: RunState, registry: ContentRegistry, copy_id: int,
		entry: Dictionary) -> PlaceTileCommand:
	for option: PlacementOption in PlacementQueryService.query_for_copy(state, registry, copy_id):
		if option.coordinate == entry["coordinate"] and option.rotation == entry["rotation"]:
			return Intent.command(option)
	assert(false, "No legal integration intent: " + str(entry))
	return null


static func naturalist_offered(state: RunState) -> bool:
	for option: Dictionary in state.pending_choice.options:
		if StringName(option["role_definition_id"]) == &"specialist.naturalist":
			return true
	return false


static func train_naturalist(state: RunState, registry: ContentRegistry) -> void:
	# A controlled training reward provides a tractable strategy. It still uses the
	# real uniformly sampled offer and preserves the same generic piece identity.
	var piece_id: int = state.specialists.pieces[0].piece_id
	assert(RulesEngine.execute(state, registry, RequestSpecialistTrainingCommand.new(piece_id)).is_valid)
	assert(naturalist_offered(state), "Choose a fixed integration seed with Naturalist in the real offer")
	assert(RulesEngine.execute(state, registry, ResolveSpecialistTrainingCommand.new(
		state.pending_choice.choice_id, &"specialist.naturalist")).is_valid)


static func _assignment_command(state: RunState) -> PlayerCommand:
	var choice: PendingChoice = state.pending_choice
	var act: int = state.expansion.current_act
	var index: int = state.expansion.normal_placements
	for option: Dictionary in choice.options:
		var piece: SpecialistPieceState = state.specialists.piece(int(option["piece_id"]))
		var type: int = int(option["target_type"])
		var naturalist: bool = type == DomainTypes.FeatureType.FOREST \
			and piece.role_definition_id == &"specialist.naturalist" \
			and (act != 2 or index >= 11)
		var generic: bool = piece.role_definition_id.is_empty() \
			and (type == 4 or (act == 1 and type == DomainTypes.FeatureType.RIVER))
		if naturalist or generic:
			return ResolveSpecialistAssignmentCommand.new(choice.choice_id, piece.piece_id,
				type, int(option["target_id"]), false)
	return ResolveSpecialistAssignmentCommand.new(choice.choice_id, 0, -1, 0, true)
