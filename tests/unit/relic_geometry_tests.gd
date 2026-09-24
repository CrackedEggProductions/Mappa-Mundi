extends "res://tests/framework/test_suite.gd"
## Live Relic geometry exceptions, immutable intent, and narrow overlay coexistence.

const Fixture = preload("res://tests/fixtures/phase_five_factory.gd")
const Previous = preload("res://tests/fixtures/phase_six_factory.gd")
const Specialist = preload("res://tests/fixtures/phase_seven_factory.gd")
const EDGE = DomainTypes.EdgeType


func tests() -> Array[Callable]:
	return [boundary_query_pure, boundary_intent_required, boundary_consumed_on_commit,
		boundary_cannot_ignore_two_mismatches, boundary_cannot_ignore_built_edges,
		boundary_signature_distinguishes_choice, hard_boundary_closes_forest,
		hard_boundary_round_trip, hard_boundary_survives_removal,
		urban_boundary_expansion, rewild_boundary_expansion, occupied_transform_cannot_use_boundary,
		mixed_housing_then_market, mixed_market_then_housing, mixed_rejects_duplicates,
		mixed_rejects_unrelated_pair, mixed_upgrade_keeps_pair, mixed_removal_blocked,
		mixed_pair_round_trip, forged_boundary_history_rejected, missing_boundary_history_rejected,
		boundary_cannot_be_reused, exact_placement_preserves_use]


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	assert(content.load_phase_eight().is_valid)
	return content


func _state(content: ContentRegistry, relic: StringName = RelicGeometry.BOUNDARY, act: int = 3) -> RunState:
	var state: RunState = Fixture.create(content, act)
	SpecialistRules.initialize(state)
	state.relics = RelicState.new()
	state.rewards = RewardState.new()
	assert(RelicRules.refresh_act(state, act).is_valid)
	assert(RelicRules.acquire(state, content, relic).is_valid)
	return state


func _option(state: RunState, content: ContentRegistry, id: StringName,
		at: Vector2i, boundary: int = -1, rotation: int = -1) -> PlacementOption:
	var copy_id: int = Fixture.acquire_hand(state, id)
	for option: PlacementOption in PlacementQueryService.query_for_copy(state, content, copy_id):
		if option.coordinate == at and option.boundary_direction == boundary and (rotation == -1 or option.rotation == rotation):
			return option
	assert(false, "Missing controlled geometry option: %s at %s boundary %d" % [id, at, boundary])
	return null


func _command(option: PlacementOption) -> PlaceTileCommand:
	var command: PlaceTileCommand = Previous.command(option)
	command.boundary_direction = option.boundary_direction
	return command


func _play(state: RunState, content: ContentRegistry, option: PlacementOption) -> void:
	var result: ValidationResult = RulesEngine.execute(state, content, _command(option))
	assert(result.is_valid, result.user_message + str(result.debug_details))
	if state.pending_choice != null and state.pending_choice.kind == &"specialist_assignment":
		Specialist.decline(state, content)


func boundary_query_pure() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var copy_id: int = Fixture.acquire_hand(state, &"tile.open_fields")
	var before: String = StateNormalizer.fingerprint(state)
	var first: Array[PlacementOption] = PlacementQueryService.query_for_copy(state, content, copy_id)
	var second: Array[PlacementOption] = PlacementQueryService.query_for_copy(state, content, copy_id)
	expect_equal(first.size(), second.size(), "Deterministic option count")
	for index: int in range(first.size()):
		expect_equal(first[index].signature, second[index].signature, "Stable explicit intent")
	expect_equal(StateNormalizer.fingerprint(state), before, "Query changes no use, history, ID or RNG")
	return true


func boundary_intent_required() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var option: PlacementOption = _option(state, content, &"tile.open_fields", Vector2i.LEFT, 1)
	var command: PlaceTileCommand = _command(option)
	command.boundary_direction = -1
	command.expected_signature = ""
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, content, command).is_valid, "Equipping does not silently forgive a mismatch")
	expect_equal(StateNormalizer.fingerprint(state), before, "Invalid intent is fully atomic")
	return true


func boundary_consumed_on_commit() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var option: PlacementOption = _option(state, content, &"tile.open_fields", Vector2i.LEFT, 1)
	expect_true(RulesEngine.validate(state, content, _command(option)).is_valid, "Query revalidates")
	expect_true(RelicRules.use_available(state, RelicGeometry.BOUNDARY), "Validation does not consume use")
	_play(state, content, option)
	expect_true(not RelicRules.use_available(state, RelicGeometry.BOUNDARY), "Committed boundary spends exactly one Act use")
	expect_true(RelicGeometry.is_hard_boundary(state.expansion.board, Vector2i.LEFT, 1), "Both cells retain hard seam")
	return true


func boundary_cannot_ignore_two_mismatches() -> bool:
	var board: BoardState = BoardState.new()
	for at: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: BoardCellState = BoardCellState.new()
		cell.coordinate = at
		cell.effective_edges = [EDGE.FOREST, EDGE.FOREST, EDGE.FOREST, EDGE.FOREST]
		board.cells[at] = cell
	expect_equal(RelicGeometry.boundary_mismatch(board, [EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD], Vector2i.ZERO), -1, "Two mismatches cannot share one use")
	return true


func boundary_cannot_ignore_built_edges() -> bool:
	for edge: int in [EDGE.ROAD, EDGE.RIVER, EDGE.SETTLEMENT]:
		var board: BoardState = BoardState.new()
		var cell: BoardCellState = BoardCellState.new()
		cell.effective_edges.assign([edge, edge, edge, edge])
		board.cells[Vector2i.LEFT] = cell
		expect_equal(RelicGeometry.boundary_mismatch(board, [EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD], Vector2i.ZERO), -1, "Built/water mismatches remain illegal")
	return true


func boundary_signature_distinguishes_choice() -> bool:
	var option: PlacementOption = PlacementOption.new()
	var ordinary: String = option.canonical_signature()
	option.boundary_direction = 1
	expect_true(ordinary != option.canonical_signature(), "Boundary use belongs to complete placement signature")
	return true


func hard_boundary_closes_forest() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var lineage: FeatureLineageState = state.features.lineage(state.features.component_at(Vector2i.ZERO, DomainTypes.FeatureType.FOREST).lineage_id)
	_play(state, content, _option(state, content, &"tile.open_fields", Vector2i.LEFT, 1))
	expect_true(lineage.completed, "Hard Field/Forest seam closes existing Forest exit without connection")
	expect_equal(lineage.member_ids.size(), 1, "Field neighbor never becomes Forest component")
	return true


func hard_boundary_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_play(state, content, _option(state, content, &"tile.open_fields", Vector2i.LEFT, 1))
	return _round_trip(state, content)


func hard_boundary_survives_removal() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, RelicGeometry.BOUNDARY, 1)
	_play(state, content, _option(state, content, &"tile.open_fields", Vector2i.LEFT, 1))
	assert(RelicRules.acquire(state, content, RelicRules.COMPASS).is_valid)
	assert(RelicRules.acquire(state, content, RelicRules.SATCHEL, RelicGeometry.BOUNDARY).is_valid)
	expect_true(RelicGeometry.is_hard_boundary(state.expansion.board, Vector2i.ZERO, 3), "Hard seam never relies on active Relic")
	expect_true(not RelicRules.active(state, RelicGeometry.BOUNDARY), "Boundary Stones is now historically removed")
	return _round_trip(state, content)


func urban_boundary_expansion() -> bool:
	return _transformation_boundary(&"tile.transformation.urban_expansion", 2)


func rewild_boundary_expansion() -> bool:
	return _transformation_boundary(&"tile.transformation.rewilding", 0)


func _transformation_boundary(definition: StringName, rotation: int) -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var before: String = StateNormalizer.fingerprint(state)
	var option: PlacementOption = _option(state, content, definition, Vector2i.LEFT, 1, rotation)
	var queried: String = StateNormalizer.fingerprint(state)
	TransformationPlacementQuery.query(state, content, option.tile_copy_id)
	expect_equal(StateNormalizer.fingerprint(state), queried, "Projected boundary cannot mutate shared neighboring cell")
	expect_true(before != queried, "Only controlled physical acquisition changes state")
	_play(state, content, option)
	expect_true(RelicGeometry.is_hard_boundary(state.expansion.board, Vector2i.LEFT, 1), "Empty Transformation mode can invoke Boundary Stones")
	expect_true(not RelicRules.use_available(state, RelicGeometry.BOUNDARY), "Transformation consumes once")
	return _round_trip(state, content)


func occupied_transform_cannot_use_boundary() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var copy_id: int = Fixture.acquire_hand(state, &"tile.transformation.rewilding")
	for option: PlacementOption in TransformationPlacementQuery.query(state, content, copy_id):
		if option.transformation_mode == &"rewilding":
			expect_equal(option.boundary_direction, -1, "Occupied Rewilding never receives Boundary exception")
	var forged: PlaceTileCommand = PlaceTileCommand.new(copy_id, TileLocationState.Kind.ACTIVE_HAND, Vector2i.ZERO)
	forged.placement_mode = DomainTypes.PlacementMode.TRANSFORMATION
	forged.transformation_mode = &"rewilding"
	forged.boundary_direction = 1
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, content, forged).is_valid, "Forged occupied boundary intent rejected")
	expect_equal(StateNormalizer.fingerprint(state), before, "Occupied rejection changes nothing")
	return true


func _develop(state: RunState, content: ContentRegistry, id: StringName) -> void:
	_play(state, content, _option(state, content, id, Vector2i.ZERO))


func mixed_housing_then_market() -> bool:
	return _mixed_order(&"tile.development.housing", &"tile.development.market")


func mixed_market_then_housing() -> bool:
	return _mixed_order(&"tile.development.market", &"tile.development.housing")


func _mixed_order(first: StringName, second: StringName) -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, RelicGeometry.MIXED)
	_develop(state, content, first)
	_develop(state, content, second)
	expect_equal(state.expansion.board.get_cell(Vector2i.ZERO).developments.size(), 2, "Exactly permitted family pair shares Settlement cell")
	expect_true(InvariantValidator.validate(state, content).is_valid, "Pair satisfies physical overlay invariants")
	return true


func mixed_rejects_duplicates() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, RelicGeometry.MIXED)
	_develop(state, content, &"tile.development.housing")
	var copy_id: int = Fixture.acquire_hand(state, &"tile.development.housing")
	expect_true(PlacementQueryService.query_for_copy(state, content, copy_id).is_empty(), "Second Housing is not a permitted pair")
	return true


func mixed_rejects_unrelated_pair() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, RelicGeometry.MIXED)
	_develop(state, content, &"tile.development.housing")
	for id: StringName in [&"tile.development.town_square", &"tile.development.port", &"tile.development.foresters_lodge"]:
		var copy_id: int = Fixture.acquire_hand(state, id)
		for option: PlacementOption in PlacementQueryService.query_for_copy(state, content, copy_id):
			expect_true(option.coordinate != Vector2i.ZERO, "Mixed Use never authorizes another family pair")
	return true


func mixed_upgrade_keeps_pair() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, RelicGeometry.MIXED)
	_develop(state, content, &"tile.development.market")
	var market: int = state.expansion.board.get_cell(Vector2i.ZERO).developments[0].tile_copy_id
	_develop(state, content, &"tile.development.housing")
	_develop(state, content, &"tile.development.grand_market")
	var cell: BoardCellState = state.expansion.board.get_cell(Vector2i.ZERO)
	expect_equal(cell.developments.size(), 2, "Grand Market replaces original Market slot")
	expect_true(market in state.expansion.removed_ids, "Physical base Market removed")
	expect_true(RelicGeometry.slot_pair_valid(state, cell), "Grand Market retains Market family permission")
	return true


func mixed_removal_blocked() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, RelicGeometry.MIXED)
	_develop(state, content, &"tile.development.housing")
	_develop(state, content, &"tile.development.market")
	expect_true(not RelicRules.removal_validation(state, content, RelicGeometry.MIXED).is_valid, "Cannot strand a pair by removing its permission")
	return true


func mixed_pair_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, RelicGeometry.MIXED)
	_develop(state, content, &"tile.development.housing")
	_develop(state, content, &"tile.development.market")
	return _round_trip(state, content)


func _round_trip(state: RunState, content: ContentRegistry) -> bool:
	var before: String = StateNormalizer.fingerprint(state)
	var saved: SerializationResult = RunSerializer.serialize(state, content)
	assert(saved.validation.is_valid, saved.validation.user_message + str(saved.validation.debug_details))
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	assert(loaded.validation.is_valid, loaded.validation.user_message + str(loaded.validation.debug_details))
	expect_equal(StateNormalizer.fingerprint(loaded.state), before, "Save/load preserves boundary/pair/use/history/RNG/ID state without effects")
	return true


func forged_boundary_history_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_play(state, content, _option(state, content, &"tile.open_fields", Vector2i.LEFT, 1))
	for event: Dictionary in state.relics.history:
		if event.kind == "boundary_stones_applied":
			event.source_id = state.expansion.board.get_cell(Vector2i.ZERO).base_tile_copy_id
	var report: InvariantReport = InvariantReport.new()
	RelicGeometry.validate_boundaries(state, report)
	expect_true(not report.is_valid, "Boundary audit cannot borrow an older unrelated base copy")
	return true


func missing_boundary_history_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_play(state, content, _option(state, content, &"tile.open_fields", Vector2i.LEFT, 1))
	for index: int in range(state.relics.history.size() - 1, -1, -1):
		if state.relics.history[index].kind == "boundary_stones_applied":
			state.relics.history.remove_at(index)
	var report: InvariantReport = InvariantReport.new()
	RelicGeometry.validate_boundaries(state, report)
	expect_true(not report.is_valid, "Reciprocal flags alone cannot authorize a forged saved mismatch")
	return true


func boundary_cannot_be_reused() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var option: PlacementOption = _option(state, content, &"tile.open_fields", Vector2i.LEFT, 1)
	assert(RelicRules.consume_use(state, RelicGeometry.BOUNDARY).is_valid)
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, content, _command(option)).is_valid, "Spent Act use cannot commit a cached intent")
	expect_equal(StateNormalizer.fingerprint(state), before, "Spent-use rejection is atomic")
	return true


func exact_placement_preserves_use() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_play(state, content, _option(state, content, &"tile.straight_road", Vector2i.RIGHT, -1, 1))
	expect_true(RelicRules.use_available(state, RelicGeometry.BOUNDARY), "Normal exact placement never spends optional Boundary use")
	return true
