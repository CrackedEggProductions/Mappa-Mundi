extends SceneTree
## Command-driven Phase-7 demonstration; no presentation scenes or reward offers.

const Scenarios = preload("res://tests/integration/specialist_scenario_tests.gd")
const Fixture = preload("res://tests/fixtures/phase_seven_factory.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_trace_lifecycle()
	var suite: RefCounted = Scenarios.new()
	var completed: int = 0
	for scenario: Callable in suite.tests():
		if scenario.call() != true:
			suite.failures.append("Scenario did not finish: " + scenario.get_method())
		else:
			completed += 1
		print("SPECIALIST SCENARIO: ", scenario.get_method())
	for failure: String in suite.failures:
		printerr("FAIL: " + failure)
	if suite.failures.is_empty():
		print("DEMO RESULT: %d Specialist scenarios passed: generic bonuses/returns; local serializable assignment; Development and Transformation integration; atomic occupied merge rejection; stable growth attribution; inert load and deterministic continuation." % completed)
	quit(0 if suite.failures.is_empty() else 1)


func _trace_lifecycle() -> void:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	print("ROSTER: ", state.specialists.pieces.size(), " generic Stewards; first stable ID=", piece.piece_id,
		" status=", piece.status)
	print("AVAILABLE TRAINING POOL: ", SpecialistRules.training_pool(state, piece))
	Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	print("PENDING LOCAL ASSIGNMENT: id=", state.pending_choice.choice_id,
		" pairs=", state.pending_choice.options, " hand=", state.expansion.hand)
	Fixture.assign(state, content, DomainTypes.FeatureType.ROAD)
	print("ASSIGNED: piece=", piece.piece_id, " target=", piece.assigned_target_id,
		" act=", piece.assigned_act, " placement=", piece.assigned_placement_index,
		" baseline=", piece.growth_baseline_component_ids, " growth=", piece.qualifying_component_ids)
	print("COMMITTED TRAINING POOL: ", SpecialistRules.training_pool(state, piece))
	assert(RulesEngine.execute(state, content, RequestSpecialistTrainingCommand.new(piece.piece_id)).is_valid)
	print("PERSISTED TRAINING OFFER: ", state.pending_choice.options,
		" rng_operations=", state.rng.operation_count)
	assert(RulesEngine.execute(state, content, ResolveSpecialistTrainingCommand.new(
		state.pending_choice.choice_id, &"specialist.cartographer")).is_valid)
	print("TRAINED IN PLACE: ", piece.role_definition_id, " unchanged piece=", piece.piece_id,
		" unchanged target=", piece.assigned_target_id)
	Fixture.play(state, content, &"tile.straight_road", Vector2i(2, 0), 1)
	Fixture.decline(state, content)
	print("GENUINE NEW ROAD GROWTH: ", piece.qualifying_component_ids)
	Fixture.play(state, content, &"tile.road_end", Vector2i(3, 0), 3)
	for event: Dictionary in state.specialists.history:
		if event.get("kind") in [&"specialist_triggered", &"specialist_returned"]:
			print("SPECIALIST AUDIT: ", event)
	print("RETURNED: piece=", piece.piece_id, " role=", piece.role_definition_id,
		" status=", piece.status, " target=", piece.assigned_target_id,
		" pending_choice=", state.pending_choice)
