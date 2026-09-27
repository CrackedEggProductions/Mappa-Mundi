extends "res://tests/framework/test_suite.gd"
## Initialization and generic bonus chains use the public gameplay command path.

const Fixture = preload("res://tests/fixtures/phase_nine_factory.gd")
const Acquisition = preload("res://tests/fixtures/phase_five_factory.gd")
const Intent = preload("res://tests/fixtures/phase_six_factory.gd")


func tests() -> Array[Callable]:
	return [initial_charter_rng_order, bonus_chain_no_normal_count,
		bonus_rejects_turn_actions, final_act_one_bonus_before_transition,
		midpoint_bonus_defers_reveal, final_score_headroom, debug_query_is_pure,
		even_reserve_draft_has_no_refill, even_bonus_chain_precedes_draft,
		milestone_and_training_precede_cadence]


func initial_charter_rng_order() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = HomesteadRunFactory.create(Fixture.RUN_SEED, content)
	var expected: RunRNG = RunRNG.new(Fixture.RUN_SEED)
	expected.select_index(EnvironmentalRiverService.templates().size(), &"environmental_river_path")
	var charter: StringName = expected.choose_definition_id(content.get_charter_ids(1), &"act_one_charter")
	var candidates: Array[StringName] = TileDraftService.pool(content, &"starter", 1)
	candidates.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var offers: Array[Dictionary] = []
	for index: int in range(3):
		var id: StringName = expected.choose_definition_id(candidates, &"tile_draft_offer")
		offers.append({"definition_id": String(id)})
		candidates.erase(id)
	expect_equal(state.charters.act_one_id, charter, "Charter follows generated environment before Starter offer")
	expect_equal(state.pending_choice.options, offers, "Starter offers use the next three uniform selections")
	expect_equal(state.expansion.hand, [0, 0, 0], "Opening draw waits for real Starter selection")
	expect_equal(state.current_rng_state, expected.current_state, "No bag shuffle occurs before Starter choice")
	var bag: Array[int] = state.expansion.bag.duplicate()
	bag.append(state.next_runtime_id)
	bag = expected.shuffled_ids(bag, &"tile_draft_bag_shuffle")
	var accepted: ValidationResult = RulesEngine.execute(state, content, ResolveTileDraftCommand.new(state.pending_choice.choice_id, 0))
	expect_true(accepted.is_valid, "Starter command resolves setup")
	expect_equal(state.expansion.hand, bag.slice(0, 3), "Opening draw follows full nineteen-copy shuffle")
	expect_equal(state.current_rng_state, expected.current_state, "Selection plus shuffle is the exact setup RNG stream")
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
	var state: RunState = Fixture.started(content, Fixture.RUN_SEED)
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
	var state: RunState = Fixture.started(content, Fixture.RUN_SEED)
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
	_play(state, content, &"tile.forest_belt", Vector2i(-2, 0), 1)
	_drain(state, content)
	expect_equal(state.expansion.normal_placements, 1, "First bonus does not consume normal placement")
	expect_equal(state.expansion.hand.count(0), 1, "Bonus refills its own slot before next bonus")
	expect_equal(state.expansion.hand[deferred], 0, "Original normal refill remains deferred")
	state = Fixture.round_trip(state, content)
	_play(state, content, &"tile.forest_edge", Vector2i(-3, 0), 1)
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
	var state: RunState = Fixture.started(content, Fixture.RUN_SEED)
	for entry: Dictionary in Fixture.placements(1, 0, state).slice(0, 17):
		_play(state, content, StringName(entry.definition_id), entry.coordinate, int(entry.rotation))
		_drain(state, content)
	var source: int = _play(state, content, &"tile.forest_edge", Vector2i(-2, -2), 3)
	expect_equal(state.expansion.normal_placements, 18, "Final normal placement committed")
	expect_true(BonusPlacementRules.enqueue(state, source).is_valid, "Final placement consequence can queue child work")
	_drain(state, content)
	expect_equal(state.expansion.current_act, 1, "Outgoing Act retained through bonus choice")
	expect_true(state.act_transition == null, "No early Charter evaluation/transition")
	state = Fixture.round_trip(state, content)
	var bonus_id: int = _play(state, content, &"tile.forest_belt", Vector2i(-3, -2), 1)
	_drain(state, content)
	expect_equal(state.expansion.current_act, 2, "Transition follows exhausted bonus chain")
	expect_equal(state.expansion.normal_placements, 0, "Incoming normal counter reset")
	expect_equal(PhysicalTileRules.find_copy(state, bonus_id).acquired_act, 1, "Bonus remains outgoing Act content")
	expect_equal(state.charters.completed_act_placements[0], 18, "Only eighteen normal placements consumed")
	expect_true(not state.expansion.hand.has(0), "Entry draft and shuffle precede original pending refill")
	return true


func midpoint_bonus_defers_reveal() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.scripted(content, Fixture.RUN_SEED, 0, false, 1).state
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
	_play(state, content, &"tile.forest_edge", Vector2i(-9, -1))
	_drain(state, content)
	expect_equal(state.expansion.normal_placements, 11, "Midpoint bonus does not increment normal count")
	expect_true(state.charters.exact_revealed, "Reveal occurs before next normal input after full chain")
	return true


func even_reserve_draft_has_no_refill() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.started(content)
	_play(state, content, &"tile.forest_belt", Vector2i.LEFT, 1)
	_drain(state, content)
	var copy_id: int = Acquisition.acquire_hand(state, &"tile.forest_edge")
	assert(RulesEngine.execute(state, content, ReserveTileCommand.new(copy_id)).is_valid)
	var hand: Array[int] = state.expansion.hand.duplicate()
	var selected: PlacementOption
	for option: PlacementOption in PlacementQueryService.query_for_copy(state, content, copy_id):
		if option.coordinate == Vector2i(-2, 0) and option.rotation == 1:
			selected = option
	assert(selected != null)
	var command: PlaceTileCommand = Intent.command(selected)
	command.source_zone = TileLocationState.Kind.RESERVE
	assert(RulesEngine.execute(state, content, command).is_valid)
	_pause_at_draft(state, content)
	expect_equal(state.pending_choice.kind, &"tile_draft", "Even Reserve placement still earns its cadence draft")
	expect_equal(state.expansion.hand, hand, "Reserve placement leaves occupied active hand intact")
	expect_equal(state.expansion.pending_refill_index, -1, "Reserve draft carries no active-hand replacement work")
	assert(RulesEngine.execute(state, content, Fixture.choice_command(state)).is_valid)
	expect_equal(state.expansion.hand, hand, "Resolving Reserve cadence adds to bag without replacing a hand tile")
	expect_true(TileDraftService.completed(state, &"cadence", 1, 2), "Actual Reserve command records the even-placement draft once")
	return true


func even_bonus_chain_precedes_draft() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.started(content)
	_play(state, content, &"tile.forest_belt", Vector2i.LEFT, 1)
	_drain(state, content)
	var source: int = _play(state, content, &"tile.forest_belt", Vector2i(-2, 0), 1)
	assert(state.pending_choice != null)
	assert(BonusPlacementRules.enqueue(state, source).is_valid)
	_drain(state, content)
	expect_equal(state.phase, GamePhase.Type.BONUS_INPUT, "Even-placement bonus starts before drafting")
	expect_true(not TileDraftService.completed(state, &"cadence", 1, 2), "No cadence resolved while bonus remains")
	_play(state, content, &"tile.forest_edge", Vector2i(-3, 0), 1)
	_pause_at_draft(state, content)
	expect_equal(state.pending_choice.context.draft_type, "cadence", "Draft follows bonus completion consequences")
	expect_equal(state.expansion.normal_placements, 2, "Bonus adds no normal count or extra cadence")
	expect_equal(state.features.completions.size(), 1, "Bonus Forest completion resolves before draft opens")
	assert(RulesEngine.execute(state, content, Fixture.choice_command(state)).is_valid)
	expect_true(TileDraftService.completed(state, &"cadence", 1, 2), "One even-placement cadence finishes after entire bonus chain")
	expect_true(not state.expansion.hand.has(0), "Deferred normal and bonus refills both finish")
	return true


func milestone_and_training_precede_cadence() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.started(content)
	Fixture.train_naturalist(state, content)
	for x: int in range(1, 20):
		_play(state, content, &"tile.forest_belt", Vector2i(-x, 0), 1)
		_drain(state, content)
	# A real Naturalist doubles Forest-tile Ecology; this first completion crosses 40.
	_play(state, content, &"tile.forest_edge", Vector2i(-20, 0), 1)
	var kinds: Array[StringName] = []
	while state.pending_choice != null:
		kinds.append(state.pending_choice.kind)
		if state.pending_choice.kind == &"tile_draft":
			break
		assert(RulesEngine.execute(state, content, Fixture.choice_command(state)).is_valid)
	expect_equal(kinds, [&"relic_offer", &"training_piece", &"specialist_training", &"tile_draft"], "Milestone then 40-point piece/role training finish before cadence")
	expect_equal(state.expansion.hand.count(0), 1, "All choices precede pending active-hand refill")
	assert(RulesEngine.execute(state, content, Fixture.choice_command(state)).is_valid)
	expect_true(not state.expansion.hand.has(0), "Only completed draft permits refill")
	return true


func _pause_at_draft(state: RunState, content: ContentRegistry) -> void:
	var guard: int = 0
	while state.pending_choice != null and state.pending_choice.kind != &"tile_draft":
		guard += 1
		assert(guard < 100)
		assert(RulesEngine.execute(state, content, Fixture.choice_command(state)).is_valid)
	assert(state.pending_choice != null, "Expected real cadence boundary")
