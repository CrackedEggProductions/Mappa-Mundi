extends "res://tests/framework/test_suite.gd"
## Canonical Phase-6 rulings: shape is not rewrite permission; Abbey keeps its enclosure.

const F = preload("res://tests/fixtures/phase_six_factory.gd")
const CENTER: Vector2i = Vector2i(0, 3)
const RING: Array[Vector2i] = [Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4),
	Vector2i(0, 4), Vector2i(-1, 4), Vector2i(-1, 3), Vector2i(-1, 2)]


func tests() -> Array[Callable]:
	return [bridge_shape_and_current_edges, bridge_stale_and_forged_intents,
		bridge_rejection_survives_load, field_dependent_stages_still_block,
		abbey_physical_and_enclosure_preservation, abbey_later_completion,
		abbey_stack_round_trip_and_continuation, completed_abbey_stays_completed,
		abbey_still_obeys_occupied_edge_legality]


func _facts(state: RunState) -> Array:
	return [StateNormalizer.fingerprint(state), state.next_runtime_id, state.current_rng_state,
		state.rng.operation_count, state.expansion.normal_placements,
		state.features.history.size(), state.features.completions.size(),
		state.features.tracks.values.duplicate(), state.expansion.board.revision,
		state.features.topology_revision, state.expansion.hand.duplicate()]


func _reject(state: RunState, content: ContentRegistry, command: PlaceTileCommand,
		code: StringName) -> void:
	var before: Array = _facts(state)
	var result: ValidationResult = RulesEngine.execute(state, content, command)
	expect_true(not result.is_valid, "Rejected intent returns structured failure")
	expect_equal(result.error_code, code, "Failure identifies canonical legality")
	expect_equal(_facts(state), before, "No copy movement, placements, geometry, topology, events, effects, IDs or RNG change")


func _load(state: RunState, content: ContentRegistry) -> RunState:
	var before: Array = _facts(state)
	var saved: SerializationResult = RunSerializer.serialize(state, content)
	expect_true(saved.validation.is_valid, "Stack serializes with all invariants valid")
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	expect_true(loaded.validation.is_valid, "Stack reconstructs without replay")
	if loaded.state != null:
		expect_equal(_facts(loaded.state), before, "Load creates zero effects, completions, scoring, events, allocations or RNG use")
	return loaded.state


func _abbey(content: ContentRegistry) -> RunState:
	var state: RunState = F.create(content)
	F.Previous.fields(state, content)
	F.Previous.play(state, content, &"tile.development.monastery", CENTER)
	F.Previous.play(state, content, &"tile.development.abbey", CENTER)
	return state


func _surround(state: RunState, content: ContentRegistry) -> void:
	for at: Vector2i in RING:
		var forest: bool = at.y == CENTER.y
		F.Previous.play(state, content, &"tile.forest_edge" if forest else &"tile.open_fields", at)


func bridge_shape_and_current_edges() -> bool:
	var content: ContentRegistry = F.content()
	for definition: StringName in [&"tile.river_run", &"tile.river_bend", &"tile.river_end"]:
		var state: RunState = F.create(content)
		F.Geography.add(state, content, definition, Vector2i.DOWN)
		var id: int = F.Previous.acquire_hand(state, F.BRIDGE)
		var shape: bool = TransformationPlacementQuery.underlying_bridge_target(state.expansion.board.get_cell(Vector2i.DOWN))
		expect_equal(shape, definition == &"tile.river_run", "Only underlying straight River Run meets shape prerequisite")
		expect_equal(F.option_at(state, content, id, Vector2i.DOWN, &"bridge") != null, shape, "Ordinary Field-bank Run legal; Bend/End illegal")
	return true


func bridge_stale_and_forged_intents() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.river(content)
	var id: int = F.Previous.acquire_hand(state, F.BRIDGE, 2)
	var option: PlacementOption = F.option_at(state, content, id, Vector2i.DOWN, &"bridge")
	var command: PlaceTileCommand = F.command(option)
	F.play(state, content, F.REWILD, Vector2i.DOWN, &"rewilding", 1)
	var cell: BoardCellState = state.expansion.board.get_cell(Vector2i.DOWN)
	expect_true(TransformationPlacementQuery.underlying_bridge_target(cell), "Rewilding preserves underlying straight River classification")
	expect_equal(cell.effective_edges, [2, 1, 2, 1], "Rewilding's Forest bank edges remain authoritative")
	expect_true(F.option_at(state, content, id, Vector2i.DOWN, &"bridge") == null, "Final query has no authorized Bridge intent")
	_reject(state, content, command, &"stale_preview")
	command.expected_board_revision = -1
	command.expected_state_revision = -1
	command.expected_signature = ""
	_reject(state, content, command, &"bridge_effective_edge_not_rewriteable")
	return true


func bridge_rejection_survives_load() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.river(content)
	F.play(state, content, F.REWILD, Vector2i.DOWN, &"rewilding", 1)
	var id: int = F.Previous.acquire_hand(state, F.BRIDGE)
	for iteration: int in range(3):
		state = _load(state, content)
		if state == null:
			return true
		var cell: BoardCellState = state.expansion.board.get_cell(Vector2i.DOWN)
		expect_true(TransformationPlacementQuery.underlying_bridge_target(cell), "Underlying River identity survives load")
		expect_equal(cell.transformations.size(), 1, "No duplicate Rewilding history")
		expect_equal(cell.effective_edges, [2, 1, 2, 1], "Forest banks persist")
		expect_true(F.option_at(state, content, id, Vector2i.DOWN, &"bridge") == null, "Loading cannot restore Field rewrite permission")
		var command: PlaceTileCommand = PlaceTileCommand.new(id, TileLocationState.Kind.ACTIVE_HAND, Vector2i.DOWN, 1)
		command.placement_mode = DomainTypes.PlacementMode.TRANSFORMATION
		_reject(state, content, command, &"bridge_effective_edge_not_rewriteable")
	return true


func field_dependent_stages_still_block() -> bool:
	var content: ContentRegistry = F.content()
	for stage: StringName in [&"mill", &"monastery"]:
		var state: RunState = F.create(content)
		F.Previous.fields(state, content)
		var id: int = F.Previous.acquire_hand(state, F.REWILD, 2)
		var option: PlacementOption = F.option_at(state, content, id, CENTER, &"rewilding", 1)
		expect_true(option != null, "Geography is eligible before Field-dependent Development")
		F.Previous.play(state, content, StringName("tile.development." + String(stage)), CENTER)
		expect_true(F.option_at(state, content, id, CENTER, &"rewilding") == null, "Current " + String(stage) + " stage blocks Rewilding")
		var command: PlaceTileCommand = F.command(option)
		command.expected_board_revision = -1
		command.expected_state_revision = -1
		command.expected_signature = ""
		_reject(state, content, command, &"invalid_transformation_intent")
	return true


func abbey_physical_and_enclosure_preservation() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = _abbey(content)
	var cell: BoardCellState = state.expansion.board.get_cell(CENTER)
	var base: int = cell.base_tile_copy_id
	var abbey: DevelopmentState = cell.developments[0]
	var enclosure: EnclosureState = state.features.enclosures[0]
	var identity: Array = [abbey.tile_copy_id, abbey.family_id, abbey.enclosure_id,
		enclosure.enclosure_id, enclosure.coordinate, enclosure.family_id,
		enclosure.stage, enclosure.completed_stages.duplicate(), enclosure.completion_ids.duplicate()]
	expect_true(abbey.replaced_copy_id in state.expansion.removed_ids, "Prerequisite Monastery physically removed")
	expect_equal(F.Previous.location(state, abbey.replaced_copy_id), TileLocationState.Kind.REMOVED_FROM_RUN, "Old Monastery never returns to active zones")
	var completions: int = state.features.completions.size()
	var tracks: Array[int] = state.features.tracks.values.duplicate()
	var effects: int = F.events(state, &"development_completion_trigger")
	var rewild: int = F.play(state, content, F.REWILD, CENTER, &"rewilding", 1)
	expect_equal(cell.base_tile_copy_id, base, "Original base is preserved")
	expect_equal(cell.effective_edges, [0, 1, 0, 1], "Eligible Field edges become Forest")
	expect_true(not cell.has_field_geography, "Field interior becomes Forest")
	expect_equal(F.Previous.location(state, abbey.tile_copy_id), TileLocationState.Kind.BOARD_DEVELOPMENT, "Abbey copy stays installed")
	expect_equal(F.Previous.location(state, rewild), TileLocationState.Kind.BOARD_TRANSFORMATION, "Rewilding copy occupies separate layer")
	expect_equal([abbey.tile_copy_id, abbey.family_id, abbey.enclosure_id,
		enclosure.enclosure_id, enclosure.coordinate, enclosure.family_id,
		enclosure.stage, enclosure.completed_stages, enclosure.completion_ids], identity,
		"Family, enclosure identity, position, stage and all prior history are preserved")
	expect_equal(state.features.completions.size(), completions, "Rewilding does not complete Abbey")
	expect_equal(F.events(state, &"development_completion_trigger"), effects, "No extra Development trigger")
	expect_equal(state.features.tracks.values, tracks, "No score from merely Rewilding Abbey's square")
	return true


func abbey_later_completion() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = _abbey(content)
	F.play(state, content, F.REWILD, CENTER, &"rewilding", 1)
	var enclosure: EnclosureState = state.features.enclosures[0]
	var id: int = enclosure.enclosure_id
	_surround(state, content)
	expect_equal(enclosure.enclosure_id, id, "Later occupancy uses original enclosure object")
	expect_equal(enclosure.completed_stages, [&"abbey"], "Only current Abbey stage completes; replaced Monastery never scores")
	expect_equal(enclosure.completion_ids.size(), 1, "Exactly one canonical stage completion")
	expect_equal(state.features.tracks.values[2], 16, "Abbey gives eight base Culture and eight natural neighbors")
	expect_true(InvariantValidator.validate(state, content).is_valid, "Completed Abbey on transformed Forest remains valid")
	return true


func abbey_stack_round_trip_and_continuation() -> bool:
	var content: ContentRegistry = F.content()
	var original: RunState = _abbey(content)
	F.play(original, content, F.REWILD, CENTER, &"rewilding", 1)
	var loaded: RunState = original
	for iteration: int in range(3):
		loaded = _load(loaded, content)
		if loaded == null:
			return true
	_surround(original, content)
	_surround(loaded, content)
	expect_equal(_facts(loaded), _facts(original), "Identical commands after loading preserve enclosure effects, draws, IDs and RNG continuation")
	for iteration: int in range(3):
		loaded = _load(loaded, content)
		if loaded == null:
			return true
		expect_equal(loaded.features.enclosures[0].completed_stages, [&"abbey"], "Completed Abbey stage is never replayed on load")
		var cell: BoardCellState = loaded.expansion.board.get_cell(CENTER)
		expect_equal(cell.transformations.size(), 1, "Exactly one physical Rewilding history")
		expect_equal(cell.developments[0].stage, &"abbey", "Abbey and removed prerequisite history survive load")
		expect_true(cell.developments[0].replaced_copy_id in loaded.expansion.removed_ids, "Old physical Monastery remains removed")
	return true


func completed_abbey_stays_completed() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = _abbey(content)
	F.play(state, content, F.REWILD, CENTER, &"rewilding", 1)
	_surround(state, content)
	var enclosure: EnclosureState = state.features.enclosures[0]
	var history: Array[int] = enclosure.completion_ids.duplicate()
	var culture: int = state.features.tracks.values[2]
	F.Previous.play(state, content, &"tile.open_fields", Vector2i(2, 4))
	F.play(state, content, F.REWILD, Vector2i(2, 4), &"rewilding", 0)
	expect_equal(enclosure.completed_stages, [&"abbey"], "Completed Abbey remains completed through later geometry changes")
	expect_equal(enclosure.completion_ids, history, "No new Abbey stage or history record")
	expect_equal(state.features.tracks.values[2], culture, "Later placements and Transformations do not replay Abbey Culture")
	return true


func abbey_still_obeys_occupied_edge_legality() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.create(content)
	F.Previous.fields(state, content, 8)
	F.Previous.play(state, content, &"tile.development.monastery", CENTER)
	F.Previous.play(state, content, &"tile.development.abbey", CENTER)
	var enclosure: EnclosureState = state.features.enclosures[0]
	var history: Array[int] = enclosure.completion_ids.duplicate()
	expect_equal(enclosure.completed_stages, [&"monastery", &"abbey"], "Both historical stages completed before this query")
	var id: int = F.Previous.acquire_hand(state, F.REWILD)
	expect_true(F.option_at(state, content, id, CENTER, &"rewilding") == null, "Abbey exemption cannot permit Forest against occupied Field edges")
	var command: PlaceTileCommand = PlaceTileCommand.new(id, TileLocationState.Kind.ACTIVE_HAND, CENTER, 1)
	command.placement_mode = DomainTypes.PlacementMode.TRANSFORMATION
	_reject(state, content, command, &"invalid_transformation_intent")
	expect_equal(enclosure.completion_ids, history, "Rejected conflicting geometry preserves both prior stage histories")
	return true
