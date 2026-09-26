extends "res://tests/framework/test_suite.gd"
## Initialization and generic bonus chains use the public gameplay command path.

const Fixture = preload("res://tests/fixtures/phase_nine_factory.gd")
const Acquisition = preload("res://tests/fixtures/phase_five_factory.gd")
const Intent = preload("res://tests/fixtures/phase_six_factory.gd")


func tests() -> Array[Callable]:
	return [initial_charter_rng_order, bonus_chain_no_normal_count,
		bonus_rejects_turn_actions, final_act_one_bonus_before_transition,
		midpoint_bonus_defers_reveal, final_score_headroom, debug_query_is_pure]


func initial_charter_rng_order() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = HomesteadRunFactory.create(907, content)
	var ids: Array[int] = []
	for copy: TileCopyState in state.tile_copies:
		if copy.acquisition_source == &"homestead_starting_bag":
			ids.append(copy.tile_copy_id)
	var expected: RunRNG = RunRNG.new(907)
	var bag: Array[int] = expected.shuffled_ids(ids, &"starting_bag_shuffle")
	var charter: StringName = expected.choose_definition_id(content.get_charter_ids(1), &"act_one_charter")
	expect_equal(state.charters.act_one_id, charter, "One uniform sorted Charter choice follows starting bag shuffle")
	expect_equal(state.expansion.hand, bag.slice(0, 3), "Opening draw uses the canonically shuffled physical bag")
	expect_equal(state.current_rng_state, expected.current_state, "Setup uses precisely shuffle then Charter RNG")
	expect_equal(state.rng.operation_count, 2, "No forecast or Grand selection during Act I")
	expect_true(state.charters.grand_id.is_empty(), "Grand remains unselected until Act II")
	return true


func final_score_headroom() -> bool:
	var state: RunState = HomesteadRunFactory.create(907, Fixture.content())
	# Each Track individually has ample headroom; their combined final score does not.
	state.features.tracks.values = [4611686018427387800, 4611686018427387800, 0, 0]
	var before: Array[int] = state.features.tracks.values.duplicate()
	expect_true(not FeatureResolutionService.has_resolution_capacity(state), "Reject before committing gains that could overflow the final aggregate")
	expect_equal(state.features.tracks.values, before, "Capacity query is read-only")
	state.features.tracks.values = [150, 200, 125, 180]
	expect_true(FeatureResolutionService.has_resolution_capacity(state), "Uncapped ordinary scores above 100 remain valid")
	return true


func debug_query_is_pure() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = HomesteadRunFactory.create(907, content)
	var before: String = StateNormalizer.fingerprint(state)
	var view: Dictionary = PhaseNineDebug.inspect(state, content)
	expect_equal(view["act"], 1, "Inspector exposes current Act")
	expect_equal(view["unlocked_act"], 1, "Inspector exposes current reward eligibility")
	expect_true(view["grand_charter"].is_empty(), "No early Grand details exposed")
	expect_true(not view.has("debug_secret_grand_id"), "Secret inspector requires explicit opt-in")
	expect_equal(StateNormalizer.fingerprint(state), before, "Inspection consumes no RNG and mutates nothing")
	return true


func _play(state: RunState, content: ContentRegistry, id: StringName,
		at: Vector2i, rotation: int = 0) -> int:
	var slot: int = 0
	while state.expansion.hand[slot] == 0:
		slot += 1
	var copy_id: int = Acquisition.acquire_hand(state, id, slot)
	for option: PlacementOption in PlacementQueryService.query_for_copy(state, content, copy_id):
		if option.coordinate == at and option.rotation == rotation:
			var accepted: ValidationResult = RulesEngine.execute(state, content, Intent.command(option))
			assert(accepted.is_valid, accepted.user_message + str(accepted.debug_details))
			return copy_id
	assert(false, "Missing legal fixture placement")
	return 0


func _drain(state: RunState, content: ContentRegistry) -> void:
	while state.pending_choice != null:
		var accepted: ValidationResult = RulesEngine.execute(state, content, Fixture.choice_command(state))
		assert(accepted.is_valid, accepted.user_message + str(accepted.debug_details))


func _bonus_start(content: ContentRegistry) -> RunState:
	var state: RunState = HomesteadRunFactory.create(907, content)
	var source: int = _play(state, content, &"tile.forest_belt", Vector2i.LEFT, 1)
	assert(state.pending_choice != null)
	assert(BonusPlacementRules.enqueue(state, source).is_valid)
	assert(BonusPlacementRules.enqueue(state, source).is_valid)
	_drain(state, content)
	return state


func bonus_chain_no_normal_count() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = _bonus_start(content)
	expect_equal(state.phase, GamePhase.Type.BONUS_INPUT, "Queued child placement waits after all parent consequences")
	state = Fixture.round_trip(state, content)
	var deferred: int = state.charters.deferred_refill_index
	_play(state, content, &"tile.open_fields", Vector2i(-1, 1))
	_drain(state, content)
	expect_equal(state.expansion.normal_placements, 1, "First bonus does not consume normal placement")
	expect_equal(state.expansion.hand.count(0), 1, "Bonus refills its own slot before next bonus")
	expect_equal(state.expansion.hand[deferred], 0, "Original normal refill remains deferred")
	state = Fixture.round_trip(state, content)
	_play(state, content, &"tile.open_fields", Vector2i(-2, 1))
	_drain(state, content)
	expect_equal(state.expansion.normal_placements, 1, "Chained bonus also preserves normal counter")
	expect_equal(state.charters.placement_history.size(), 3, "Three physical commits retained in exact order")
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Full chain resolves before next normal turn")
	expect_true(not state.expansion.hand.has(0), "Original refill occurs exactly once after chain")
	return true


func bonus_rejects_turn_actions() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = _bonus_start(content)
	var before: String = StateNormalizer.fingerprint(state)
	for command: PlayerCommand in [SurveyTileCommand.new(state.expansion.hand[1]),
		ReserveTileCommand.new(state.expansion.hand[1]), RecruitStewardCommand.new()]:
		expect_true(not RulesEngine.execute(state, content, command).is_valid, "Bonus is not a full turn")
		expect_equal(StateNormalizer.fingerprint(state), before, "Rejected start-of-turn action is atomic")
	return true


func final_act_one_bonus_before_transition() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = HomesteadRunFactory.create(907, content)
	for entry: Dictionary in Fixture.placements(1).slice(0, 17):
		_play(state, content, StringName(entry.definition_id), entry.coordinate, int(entry.rotation))
		_drain(state, content)
	var source: int = _play(state, content, &"tile.forest_edge", Vector2i(1, 8))
	expect_equal(state.expansion.normal_placements, 18, "Final normal placement committed")
	expect_true(BonusPlacementRules.enqueue(state, source).is_valid, "Final placement consequence can queue child work")
	_drain(state, content)
	expect_equal(state.expansion.current_act, 1, "Outgoing Act retained through bonus choice")
	expect_true(state.act_transition == null, "No early Charter evaluation/transition")
	state = Fixture.round_trip(state, content)
	var bonus_id: int = _play(state, content, &"tile.open_fields", Vector2i(2, 8))
	_drain(state, content)
	expect_equal(state.expansion.current_act, 2, "Transition follows exhausted bonus chain")
	expect_equal(state.expansion.normal_placements, 0, "Incoming normal counter reset")
	expect_equal(PhysicalTileRules.find_copy(state, bonus_id).acquired_act, 1, "Bonus remains outgoing Act content")
	expect_equal(state.charters.completed_act_placements[0], 18, "Only eighteen normal placements consumed")
	expect_true(not state.expansion.hand.has(0), "Seed/shuffle/selection precede original pending refill")
	return true


func midpoint_bonus_defers_reveal() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.scripted(content, 212, 0, false, 1).state
	for entry: Dictionary in Fixture.placements(2).slice(0, 10):
		_play(state, content, StringName(entry.definition_id), entry.coordinate, int(entry.rotation))
		_drain(state, content)
	var entry: Dictionary = Fixture.placements(2)[10]
	var source: int = _play(state, content, StringName(entry.definition_id), entry.coordinate, int(entry.rotation))
	expect_true(not state.charters.exact_revealed, "Placement eleven assignment consequences still conceal exact Grand")
	assert(BonusPlacementRules.enqueue(state, source).is_valid)
	_drain(state, content)
	expect_equal(state.phase, GamePhase.Type.BONUS_INPUT, "Midpoint child placement remains pending")
	expect_true(not state.charters.exact_revealed, "Exact Grand remains concealed through bonus chain")
	state = Fixture.round_trip(state, content)
	_play(state, content, &"tile.open_fields", Vector2i(2, 0))
	_drain(state, content)
	expect_equal(state.expansion.normal_placements, 11, "Midpoint bonus does not increment normal count")
	expect_true(state.charters.exact_revealed, "Reveal occurs before next normal input after full chain")
	return true
