extends RefCounted
## Revision-1 controlled player-tile acquisition and one initial training reward.
## Generated environment, overlays, scoring and all 66 placements use actual rules.
## This is a reproducible integration fixture, not a claim of naturally optimized play.

const RUN_SEED: int = 22
const Previous = preload("res://tests/fixtures/phase_eight_factory.gd")
const Acquisition = preload("res://tests/fixtures/phase_five_factory.gd")
const Intent = preload("res://tests/fixtures/phase_six_factory.gd")


static func content() -> ContentRegistry:
	var registry: ContentRegistry = ContentRegistry.new()
	var loaded: ValidationResult = registry.load_phase_nine()
	assert(loaded.is_valid, loaded.user_message)
	return registry


static func started(registry: ContentRegistry, seed_value: int = RUN_SEED) -> RunState:
	var state: RunState = HomesteadRunFactory.create(seed_value, registry)
	if state.pending_choice != null and state.pending_choice.kind == &"tile_draft":
		var accepted: ValidationResult = RulesEngine.execute(state, registry,
			ResolveTileDraftCommand.new(state.pending_choice.choice_id, 0))
		assert(accepted.is_valid, accepted.user_message + str(accepted.debug_details))
	assert(state.phase == GamePhase.Type.TURN_INPUT, "Starter selection must finish setup through its real command")
	return state


static func scripted(registry: ContentRegistry, seed_value: int, outcome: int = 0,
		reload_boundaries: bool = false, stop_after_act: int = 3) -> Dictionary:
	var state: RunState = HomesteadRunFactory.create(seed_value, registry)
	var trace: Dictionary = {"commands": [], "choices": [], "turns": [],
		"act_counts": [0, 0, 0], "round_trips": 0, "transition_entries": [],
		"midpoint_pending": [], "saved_choices": [], "initial_charter": state.charters.act_one_id}
	state = drain(state, registry, trace, reload_boundaries)
	train_naturalist(state, registry)
	for act: int in range(1, stop_after_act + 1):
		var recipe: Array[Dictionary] = placements(act, outcome, state)
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
		trace["choices"].append({"kind": choice.kind, "options": choice.options.duplicate(true), "context": choice.context.duplicate(true),
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
					"outgoing_act": state.act_transition.outgoing_act,
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
		&"tile_draft":
			return ResolveTileDraftCommand.new(choice.choice_id, 0)
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


static func placements(act: int, outcome: int = 0, state: RunState = null) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if act == 1:
		for x: int in range(1, 8):
			entries.append(_entry(&"tile.forest_belt", Vector2i(-x, 0), 1))
		entries.append(_entry(&"tile.forest_edge", Vector2i(-8, 0), 1))
		assert(state != null, "River overlays target the generated environment, never a presumed path")
		entries.append(_entry(&"tile.riverside_hamlet", Vector2i.DOWN, 1))
		for at: Vector2i in state.expansion.board.sorted_coordinates():
			var cell: BoardCellState = state.expansion.board.get_cell(at)
			if cell.definition_id == &"tile.river_bend":
				entries.append(_entry(&"tile.woodland_river", at, cell.rotation))
		entries.append(_entry(&"tile.hamlet_edge", Vector2i.UP, 2))
		entries.append(_entry(&"tile.road_junction", Vector2i.RIGHT, 3))
		_row(entries, -1)
		entries.append(_entry(&"tile.development.monastery", Vector2i(-3, -1)))
		entries.append(_entry(&"tile.forest_edge", Vector2i(-2, -2), 3))
	elif act == 2:
		entries.append(_entry(&"tile.forest_belt", Vector2i(-3, -2), 1))
		entries.append(_entry(&"tile.forest_edge", Vector2i(-4, -2), 1))
		entries.append(_entry(&"tile.forest_edge", Vector2i(-2, -3), 3))
		entries.append(_entry(&"tile.forest_belt", Vector2i(-3, -3), 1))
		# A real ordinary Development disqualifies Naturalist on this row;
		# subsequent training and reward offers remain ordinary engine outcomes.
		entries.append(_entry(&"tile.development.monastery", Vector2i(-3, -3)))
		entries.append(_entry(&"tile.forest_edge", Vector2i(-4, -3), 1))
		_row(entries, -4)
		entries.append(_entry(&"tile.forest_edge", Vector2i(-2, -5), 3))
		# The trained Architect is available: placement eleven creates a genuine
		# Settlement assignment pause, proving reveal waits for consequences.
		entries.append(_entry(&"tile.hamlet_edge", Vector2i(-8, -1)))
		_forest(entries, -6, -1, 7)
		entries.append(_entry(&"tile.forest_belt", Vector2i(-3, -5), 1))
		entries.append(_entry(&"tile.forest_edge", Vector2i(-4, -5), 1))
		entries.append(_entry(&"tile.forest_edge", Vector2i(-2, -6), 3))
		entries.append(_entry(&"tile.forest_belt", Vector2i(-3, -6), 1))
	else:
		entries.append(_entry(&"tile.forest_edge", Vector2i(-4, -6), 1))
		if outcome > 0:
			entries.append(_entry(&"tile.development.abbey", Vector2i(-3, -1)))
		if outcome > 1:
			entries.append(_entry(&"tile.development.abbey", Vector2i(-3, -3)))
		var remaining: int = 26 - entries.size()
		entries.append(_entry(&"tile.forest_edge", Vector2i(-6, -8), 3))
		for step: int in range(1, remaining - 1):
			entries.append(_entry(&"tile.forest_belt", Vector2i(-6 - step, -8), 1))
		entries.append(_entry(&"tile.forest_edge", Vector2i(-5 - remaining, -8), 1))
	assert(entries.size() == [18, 22, 26][act - 1])
	return entries


static func _row(entries: Array[Dictionary], y: int) -> void:
	entries.append(_entry(&"tile.forest_edge", Vector2i(-2, y), 3))
	entries.append(_entry(&"tile.forest_belt", Vector2i(-3, y), 1))
	entries.append(_entry(&"tile.forest_edge", Vector2i(-4, y), 1))


static func _forest(entries: Array[Dictionary], x: int, start_y: int, size: int) -> void:
	entries.append(_entry(&"tile.forest_edge", Vector2i(x, start_y)))
	for step: int in range(1, size - 1):
		entries.append(_entry(&"tile.forest_belt", Vector2i(x, start_y - step)))
	entries.append(_entry(&"tile.forest_edge", Vector2i(x, start_y - size + 1), 2))


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
	for option: Dictionary in choice.options:
		var piece: SpecialistPieceState = state.specialists.piece(int(option["piece_id"]))
		var type: int = int(option["target_type"])
		var naturalist: bool = type == DomainTypes.FeatureType.FOREST \
			and piece.role_definition_id == &"specialist.naturalist" \
			and _northwest_forest(state, int(option["target_id"]))
		var generic: bool = piece.role_definition_id.is_empty() \
			and type == 4
		if naturalist or generic:
			return ResolveSpecialistAssignmentCommand.new(choice.choice_id, piece.piece_id,
				type, int(option["target_id"]), false)
	return ResolveSpecialistAssignmentCommand.new(choice.choice_id, 0, -1, 0, true)


static func _northwest_forest(state: RunState, lineage_id: int) -> bool:
	for feature: CurrentFeature in TopologyService.rebuild(state):
		if feature.lineage_id == lineage_id:
			for at: Vector2i in feature.coordinates:
				if at.y > 0 or (at != Vector2i.ZERO and state.features.component_at(at, DomainTypes.FeatureType.RIVER) != null):
					return false
			return true
	return false
