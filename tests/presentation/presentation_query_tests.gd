extends "res://tests/framework/test_suite.gd"

const Queries = preload("res://presentation/queries/presentation_queries.gd")


func tests() -> Array[Callable]:
	return [ordinary_charter_progress, grand_forecast_is_secret, exact_grand_visible,
		available_specialists, assigned_specialist_target, relic_slots_and_effects, tile_inspection,
		development_and_transformation_inspection,
		results_no_victory, results_victory, results_exemplary, transition_summary, queries_are_inert]


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	expect_true(content.load_phase_nine().is_valid, "Canonical content loads")
	return content


func ordinary_charter_progress() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = HomesteadRunFactory.create(212, content)
	var text: String = Queries.charter_text(state, content)
	expect_true(text.contains(content.get_charter(state.charters.act_one_id).display_name), "Selected Charter shown")
	expect_true(text.contains("Fulfill:") and text.contains("Exceed"), "Both condition groups shown")
	expect_true(text.contains("(history)") and text.contains("(current)"), "Condition sources shown")
	return true


func _act_two(state: RunState, content: ContentRegistry) -> void:
	state.expansion.current_act = 2
	CharterRules.select_ordinary(state, content, 2)
	CharterRules.select_grand(state, content)


func grand_forecast_is_secret() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = HomesteadRunFactory.create(212, content)
	_act_two(state, content)
	var text: String = Queries.charter_text(state, content)
	var definition: CharterDefinition = content.get_charter(state.charters.grand_id)
	expect_true(text.contains(definition.forecast_text), "Forecast is visible")
	expect_true(not text.contains(definition.display_name), "Hidden Grand name never exposed")
	expect_true(not text.contains(String(definition.definition_id)), "Hidden Grand ID never exposed")
	expect_true(text.contains(content.get_charter(state.charters.act_two_id).display_name), "Act II ordinary Charter shown")
	return true


func exact_grand_visible() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = HomesteadRunFactory.create(212, content)
	_act_two(state, content)
	CharterRules.reveal_grand(state)
	state.expansion.current_act = 3
	var text: String = Queries.charter_text(state, content)
	expect_true(text.contains(content.get_charter(state.charters.grand_id).display_name), "Exact Grand name now visible")
	expect_true(not text.contains(content.get_charter(state.charters.act_two_id).display_name), "No ordinary Act III Charter")
	return true


func available_specialists() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = HomesteadRunFactory.create(212, content)
	var text: String = Queries.specialists_text(state, content)
	expect_equal(text.count("AVAILABLE"), 2, "Both starting physical pieces shown")
	expect_true(text.contains("piece 1") and text.contains("piece 2"), "Friendly physical-piece labels")
	return true


func relic_slots_and_effects() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = HomesteadRunFactory.create(212, content)
	expect_equal(Queries.relics_text(state, content).count("empty"), 2, "Two empty slots shown")
	var relic: RelicInstanceState = RelicInstanceState.new()
	relic.definition_id = &"relic.boundary_stones"
	relic.equipped_slot = 0
	relic.once_per_act = true
	relic.uses_remaining = 1
	state.relics.instances.append(relic)
	var text: String = Queries.relics_text(state, content)
	expect_true(text.contains("Boundary Stones") and text.contains("1 use(s)"), "Equipped name and actual use state")
	expect_true(text.contains("Field/Forest mismatch"), "Effect help included")
	return true


func tile_inspection() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = HomesteadRunFactory.create(212, content)
	var text: String = Queries.inspect_tile(state, content, Vector2i.ZERO)
	expect_true(text.contains("(0, 0)") and text.contains("placed Act 1"), "Coordinate and Act displayed")
	expect_true(text.contains("N:") and text.contains("Trade Network"), "Effective geography and queried reach displayed")
	expect_true(text.contains("unfinished"), "Feature completion state shown")
	expect_true(Queries.inspect_tile(state, content, Vector2i(-4, 7)).contains("(-4, 7)"), "Empty negative coordinates supported")
	return true


func _results(outcome: StringName, expected: String) -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = HomesteadRunFactory.create(212, content)
	state.final_result = RunResult.new()
	state.final_result.victory_result = outcome
	state.final_result.score = 987
	state.final_result.tracks = [123, 234, 345, 174]
	state.final_result.grand_charter_id = &"charter.grand_living_heritage"
	state.final_result.statistics = {"largest_settlement_established": 8, "longest_road_completed": 9,
		"largest_forest_completed": 10, "longest_river_size": 11, "run_seed": 999,
		"relics_acquired": ["relic.boundary_stones"], "relics_equipped": [], "relics_replaced": ["relic.boundary_stones"],
		"specialist_training": [{"role_definition_id": "specialist.merchant", "history": [{"act": 2}]}],
		"charters": [{"charter_id": "charter.a1_growing_realm", "overall_state": "fulfilled"}]}
	var text: String = Queries.results_text(state, content)
	expect_true(text.contains(expected), "Authoritative outcome displayed")
	for required: String in ["Final score: 987", "Population: 123", "Trade: 234", "Culture: 345", "Ecology: 174",
		"Largest Settlement established: 8", "Longest Road completed: 9", "Largest Forest completed: 10",
		"Longest connected River: 11", "Run seed: 999", "Merchant", "Growing Realm", "Relics replaced: Boundary Stones"]:
		expect_true(text.contains(required), "Stored result field shown: " + required)
	return true


func results_no_victory() -> bool:
	return _results(&"completed_no_victory", "No Victory")


func results_victory() -> bool:
	return _results(&"victory", "Victory")


func results_exemplary() -> bool:
	return _results(&"exemplary_victory", "Exemplary Victory")


func transition_summary() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = HomesteadRunFactory.create(212, content)
	state.expansion.current_act = 2
	state.relics.capacity = 4
	state.charters.evaluations.append({"evaluation_act": 1, "charter_id": "charter.a1_growing_realm", "overall_state": "fulfilled"})
	var text: String = Queries.transition_text(state, content, 1)
	expect_true(text.contains("Act 1 completed") and text.contains("Entering Act 2"), "Transition summary uses current state")
	expect_true(text.contains("Abbey") and text.contains("Relic capacity 4"), "Canonical incoming seed definitions and capacity")
	expect_true(text.contains("Fulfilled"), "Frozen outgoing result shown")
	return true


func queries_are_inert() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = HomesteadRunFactory.create(212, content)
	var fingerprint: String = StateNormalizer.fingerprint(state)
	var rng_operations: int = state.rng.operation_count
	for iteration: int in range(3):
		Queries.charter_text(state, content)
		Queries.specialists_text(state, content)
		Queries.relics_text(state, content)
		Queries.inspect_tile(state, content, Vector2i.ZERO)
		Queries.results_text(state, content)
		Queries.transition_text(state, content, 1)
	expect_equal(StateNormalizer.fingerprint(state), fingerprint, "No display helper mutates authoritative state")
	expect_equal(state.rng.operation_count, rng_operations, "No display helper consumes RNG")
	return true


func assigned_specialist_target() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = HomesteadRunFactory.create(212, content)
	var feature: CurrentFeature = TopologyService.rebuild(state)[0]
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	piece.status = SpecialistPieceState.Status.ASSIGNED
	piece.assigned_target_type = feature.feature_type
	piece.assigned_target_id = feature.lineage_id
	var text: String = Queries.specialists_text(state, content)
	expect_true(text.contains("ASSIGNED") and text.contains("near (0, 0)"), "Friendly assigned target summary")
	expect_true(Queries.inspect_tile(state, content, Vector2i.ZERO).contains("piece 1 assigned"), "Assigned piece shown in feature inspection")
	return true


func development_and_transformation_inspection() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = HomesteadRunFactory.create(212, content)
	var cell: BoardCellState = state.expansion.board.get_cell(Vector2i.ZERO)
	var development: DevelopmentState = DevelopmentState.new()
	development.stage = &"abbey"
	cell.developments.append(development)
	var transformation: TransformationState = TransformationState.new()
	transformation.definition_id = &"tile.bridge"
	transformation.mode = &"bridge"
	cell.transformations.append(transformation)
	cell.effective_edges[0] = DomainTypes.EdgeType.FOREST
	var text: String = Queries.inspect_tile(state, content, Vector2i.ZERO)
	expect_true(text.contains("Development: Abbey"), "Current upgrade stage shown")
	expect_true(text.contains("Transformation: Bridge"), "Transformation history shown")
	expect_true(text.contains("N: Forest"), "Effective edge state outranks original art")
	return true
