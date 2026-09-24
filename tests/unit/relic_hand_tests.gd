extends "res://tests/framework/test_suite.gd"


func tests() -> Array[Callable]:
	return [baseline_reserve_capacity, satchel_second_slot, explicit_second_slot,
		occupied_slot_rejected, invalid_slot_rejected, nonhand_reservation_rejected,
		remove_either_reserve_independently, satchel_removal_guard, reserve_round_trip,
		compass_first_survey, compass_physical_next_three, compass_one_choice,
		compass_invalid_choice_atomic, compass_fewer_than_three, compass_empty_bag,
		compass_later_survey, compass_acquired_after_survey, compass_act_refresh,
		compass_round_trip, compass_reload_no_effects, compass_empty_slot_not_refill,
		grand_survey_decline, grand_survey_one_removal, grand_survey_two_removals,
		grand_survey_sequential_replacement, grand_survey_excludes_empty_slot,
		grand_survey_excludes_reserve, grand_survey_excludes_replacements,
		grand_survey_emergency, grand_survey_no_compass, grand_survey_pending_refill,
		grand_survey_round_trip, grand_survey_invalid_choice_atomic,
		grand_survey_charge_above_initial, malformed_compass_set_rejected,
		stranded_inspected_copy_rejected, compass_engine_commands, grand_survey_engine_commands,
		satchel_engine_two_slots, satchel_engine_place_extra, stale_hand_choice_rejected,
		malformed_compass_index_rejected, grand_survey_reload_finish_not_repeated,
		normal_survey_counter_overflow_atomic]


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	expect_true(content.load_phase_eight().is_valid, "Phase8 content loads")
	return content


func _state(content: ContentRegistry) -> RunState:
	return HomesteadRunFactory.create(80808, content)


func _equip(state: RunState, content: ContentRegistry, id: StringName) -> void:
	expect_true(RelicRules.acquire(state, content, id).is_valid, "Equip test Relic")


func _compass(state: RunState, content: ContentRegistry) -> void:
	_equip(state, content, &"relic.surveyors_compass")
	RelicHandRules.survey(state, content, state.expansion.hand[0])


func _resolve_compass(state: RunState, content: ContentRegistry, index: int = 0) -> void:
	var command: ResolveCompassCommand = ResolveCompassCommand.new(state.pending_choice.choice_id, state.expansion.inspected_ids[index])
	expect_true(RelicHandRules.validate_command(state, content, command).is_valid, "Compass choice legal")
	RelicHandRules.execute_command(state, content, command)


func _grand(state: RunState, content: ContentRegistry) -> void:
	state.resolution = ResolutionState.new()
	state.resolution.stage = &"reward_queue"
	state.resolution.context = {"mode": "reward"}
	RelicHandRules.begin_grand_survey(state, content)


func _choose_grand(state: RunState, content: ContentRegistry, copy_id: int = 0, finish: bool = false) -> void:
	var command: ResolveGrandSurveyCommand = ResolveGrandSurveyCommand.new(state.pending_choice.choice_id, copy_id, finish)
	expect_true(RelicHandRules.validate_command(state, content, command).is_valid, "Grand Survey choice legal")
	RelicHandRules.execute_command(state, content, command)


func _keep_bag(state: RunState, count: int) -> void:
	while state.expansion.bag.size() > count:
		var copy_id: int = state.expansion.bag.pop_back()
		state.expansion.removed_ids.append(copy_id)
		PhysicalTileRules.set_location(state, copy_id, TileLocationState.Kind.REMOVED_FROM_RUN)


func _round_trip(state: RunState, content: ContentRegistry) -> RunState:
	var saved: SerializationResult = RunSerializer.serialize(state, content)
	expect_true(saved.validation.is_valid, saved.validation.user_message + " " + str(saved.validation.debug_details))
	if not saved.validation.is_valid:
		return null
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	expect_true(loaded.validation.is_valid, loaded.validation.user_message + " " + str(loaded.validation.debug_details))
	return loaded.state


func baseline_reserve_capacity() -> bool:
	var content: ContentRegistry = _content()
	expect_equal(RelicHandRules.reserve_capacity(_state(content)), 1, "Baseline remains one")
	return true


func satchel_second_slot() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_equip(state, content, &"relic.wayfarers_satchel")
	var first: int = state.expansion.hand[0]
	RelicHandRules.reserve(state, content, ReserveTileCommand.new(first))
	var second: int = state.expansion.hand[0]
	RelicHandRules.reserve(state, content, ReserveTileCommand.new(second))
	expect_equal(RelicHandRules.reserve_ids(state), [first, second], "Both original copies retained")
	expect_equal(state.expansion.hand.size(), 3, "Each reservation immediately replaces hand tile")
	expect_true(0 not in state.expansion.hand, "No empty hand slots")
	return true


func explicit_second_slot() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_equip(state, content, &"relic.wayfarers_satchel")
	var copy_id: int = state.expansion.hand[1]
	var command: ReserveTileCommand = ReserveTileCommand.new(copy_id, 1)
	expect_true(RelicHandRules.validate_reserve(state, command).is_valid, "Explicit second slot legal")
	RelicHandRules.reserve(state, content, command)
	expect_equal(state.expansion.reserve_id, 0, "First slot remains empty")
	expect_equal(state.expansion.reserve_extra_id, copy_id, "Second slot gets chosen copy")
	return true


func occupied_slot_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	RelicHandRules.reserve(state, content, ReserveTileCommand.new(state.expansion.hand[0]))
	expect_true(not RelicHandRules.validate_reserve(state, ReserveTileCommand.new(state.expansion.hand[0])).is_valid, "Occupied baseline rejected")
	return true


func invalid_slot_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	for slot: int in [-2, 1, 2]:
		expect_true(not RelicHandRules.validate_reserve(state, ReserveTileCommand.new(state.expansion.hand[0], slot)).is_valid, "Invalid slot rejected")
	return true


func nonhand_reservation_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	expect_true(not RelicHandRules.validate_reserve(state, ReserveTileCommand.new(state.expansion.bag[0])).is_valid, "Bag is not active hand")
	return true


func remove_either_reserve_independently() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.expansion.reserve_id = 101
	state.expansion.reserve_extra_id = 202
	RelicHandRules.remove_reserved(state, 202)
	expect_equal(RelicHandRules.reserve_ids(state), [101], "Removing extra preserves first")
	state.expansion.reserve_extra_id = 202
	RelicHandRules.remove_reserved(state, 101)
	expect_equal(RelicHandRules.reserve_ids(state), [202], "Removing first preserves extra")
	return true


func satchel_removal_guard() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_equip(state, content, &"relic.wayfarers_satchel")
	expect_true(RelicRules.removal_validation(state, content, &"relic.wayfarers_satchel").is_valid, "Empty extra removable")
	RelicHandRules.reserve(state, content, ReserveTileCommand.new(state.expansion.hand[0], 1))
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RelicRules.removal_validation(state, content, &"relic.wayfarers_satchel").is_valid, "Occupied extra blocks removal")
	expect_equal(StateNormalizer.fingerprint(state), before, "Validation atomic")
	return true


func reserve_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_equip(state, content, &"relic.wayfarers_satchel")
	RelicHandRules.reserve(state, content, ReserveTileCommand.new(state.expansion.hand[0]))
	RelicHandRules.reserve(state, content, ReserveTileCommand.new(state.expansion.hand[0]))
	var loaded: RunState = _round_trip(state, content)
	if loaded != null:
		expect_equal(RelicHandRules.reserve_ids(loaded), RelicHandRules.reserve_ids(state), "Both slots survive exactly")
	return true


func compass_first_survey() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var removed: int = state.expansion.hand[0]
	_compass(state, content)
	expect_equal(state.pending_choice.kind, &"compass", "First normal Survey pauses for Compass")
	expect_equal(state.relics.normal_surveys_used, 1, "Normal Survey counted")
	expect_equal(state.expansion.survey_charges, 0, "Normal charge spent")
	expect_true(removed in state.expansion.removed_ids, "Original physical tile permanently removed")
	return true


func compass_physical_next_three() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var expected: Array[int] = state.expansion.bag.slice(0, 3)
	var operations: int = state.rng.operation_count
	_compass(state, content)
	expect_equal(state.expansion.inspected_ids, expected, "Next three physical copies in exact draw order")
	expect_equal(state.rng.operation_count, operations, "Inspection consumes no RNG")
	return true


func compass_one_choice() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_compass(state, content)
	var inspected: Array[int] = state.expansion.inspected_ids.duplicate()
	var operations: int = state.rng.operation_count
	_resolve_compass(state, content, 1)
	expect_equal(state.expansion.hand[0], inspected[1], "Chosen physical copy fills same slot")
	expect_true(inspected[0] in state.expansion.bag and inspected[2] in state.expansion.bag, "Unchosen returned")
	expect_equal(state.rng.operation_count, operations + 1, "Entire remaining bag shuffled once")
	expect_true(state.pending_choice == null and state.resolution == null, "Continuation consumed")
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Normal input resumes")
	return true


func compass_invalid_choice_atomic() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_compass(state, content)
	var before: String = StateNormalizer.fingerprint(state)
	var result: ValidationResult = RelicHandRules.validate_command(state, content, ResolveCompassCommand.new(state.pending_choice.choice_id, state.expansion.hand[1]))
	expect_true(not result.is_valid, "Non-inspected rejected")
	expect_equal(StateNormalizer.fingerprint(state), before, "Invalid choice leaves RNG, history and state alone")
	return true


func compass_fewer_than_three() -> bool:
	var content: ContentRegistry = _content()
	for count: int in [1, 2]:
		var state: RunState = _state(content)
		_keep_bag(state, count)
		_compass(state, content)
		expect_equal(state.expansion.inspected_ids.size(), count, "Inspect all remaining without padding")
	return true


func compass_empty_bag() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_keep_bag(state, 0)
	var count: int = state.tile_copies.size()
	_compass(state, content)
	expect_equal(state.expansion.inspected_ids.size(), 3, "Emergency replenishment supplies inspected set")
	expect_equal(state.tile_copies.size(), count + content.get_config().emergency_definitions.size(), "One canonical emergency injection")
	return true


func compass_later_survey() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_compass(state, content)
	_resolve_compass(state, content)
	state.expansion.survey_charges = 1
	RelicHandRules.survey(state, content, state.expansion.hand[0])
	expect_true(state.pending_choice == null, "Second normal Survey does not inspect")
	expect_equal(state.relics.normal_surveys_used, 2, "Survey history advances")
	return true


func compass_acquired_after_survey() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	RelicHandRules.survey(state, content, state.expansion.hand[0])
	state.expansion.survey_charges = 1
	_equip(state, content, &"relic.surveyors_compass")
	RelicHandRules.survey(state, content, state.expansion.hand[0])
	expect_true(state.pending_choice == null, "Acquisition cannot replay first Survey")
	return true


func compass_act_refresh() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_compass(state, content)
	_resolve_compass(state, content)
	expect_true(RelicRules.refresh_act(state, 2).is_valid, "Next Act refresh accepted")
	state.expansion.current_act = 2
	state.expansion.survey_charges = 1
	RelicHandRules.survey(state, content, state.expansion.hand[0])
	expect_equal(state.pending_choice.kind, &"compass", "First later-Act Survey inspects again")
	return true


func compass_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_compass(state, content)
	var loaded: RunState = _round_trip(state, content)
	if loaded != null:
		expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Pending set and all continuation state exact")
		_resolve_compass(loaded, content, 2)
		_resolve_compass(state, content, 2)
		expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Same choice continues same shuffle")
	return true


func compass_reload_no_effects() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_compass(state, content)
	var before: String = StateNormalizer.fingerprint(state)
	for repeat: int in range(3):
		var loaded: RunState = _round_trip(state, content)
		if loaded != null:
			state = loaded
		expect_equal(StateNormalizer.fingerprint(state), before, "Repeated load allocates, scores, draws and consumes nothing")
	return true


func compass_empty_slot_not_refill() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_compass(state, content)
	expect_equal(state.expansion.pending_refill_index, -1, "Compass is not pending ordinary placement refill")
	expect_equal(state.expansion.hand.count(0), 1, "Exactly chosen hand slot is empty")
	return true


func grand_survey_decline() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var hand: Array[int] = state.expansion.hand.duplicate()
	_grand(state, content)
	_choose_grand(state, content, 0, true)
	expect_equal(state.expansion.hand, hand, "Zero removals legal")
	expect_equal(state.expansion.survey_charges, 2, "One charge granted even when no tile removed")
	expect_true(state.pending_choice == null, "Grand Survey finished")
	return true


func grand_survey_one_removal() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var copy_id: int = state.expansion.hand[1]
	_grand(state, content)
	_choose_grand(state, content, copy_id)
	expect_true(copy_id in state.expansion.removed_ids, "Chosen copy permanently removed")
	expect_true(state.pending_choice != null, "Can choose second or stop")
	_choose_grand(state, content, 0, true)
	expect_equal(state.expansion.survey_charges, 2, "One completion grant")
	return true


func grand_survey_two_removals() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var first: int = state.expansion.hand[0]
	var second: int = state.expansion.hand[2]
	_grand(state, content)
	_choose_grand(state, content, first)
	_choose_grand(state, content, second)
	expect_true(state.pending_choice == null, "Second removal completes sequence")
	expect_true(first in state.expansion.removed_ids and second in state.expansion.removed_ids, "Both permanent removals recorded")
	expect_equal(state.expansion.survey_charges, 2, "Exactly one charge despite two removals")
	return true


func grand_survey_sequential_replacement() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var first: int = state.expansion.hand[0]
	var second: int = state.expansion.hand[1]
	var expected: Array[int] = state.expansion.bag.slice(0, 2)
	_grand(state, content)
	_choose_grand(state, content, first)
	expect_equal(state.expansion.hand[0], expected[0], "First replacement drawn before second choice")
	expect_equal(state.pending_choice.context["chosen_removals"], [first], "Progress persisted")
	_choose_grand(state, content, second)
	expect_equal(state.expansion.hand[1], expected[1], "Second replacement next physical copy")
	return true


func grand_survey_excludes_empty_slot() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.expansion.hand[0] = 0
	state.expansion.pending_refill_index = 0
	_grand(state, content)
	expect_true(0 not in state.pending_choice.context["eligible_ids"], "Empty pending-refill slot not a tile")
	var command: ResolveGrandSurveyCommand = ResolveGrandSurveyCommand.new(state.pending_choice.choice_id, 0)
	expect_true(not RelicHandRules.validate_command(state, content, command).is_valid, "Cannot select empty slot")
	return true


func grand_survey_excludes_reserve() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	RelicHandRules.reserve(state, content, ReserveTileCommand.new(state.expansion.hand[0]))
	_grand(state, content)
	var command: ResolveGrandSurveyCommand = ResolveGrandSurveyCommand.new(state.pending_choice.choice_id, state.expansion.reserve_id)
	expect_true(not RelicHandRules.validate_command(state, content, command).is_valid, "Committed Reserve excluded")
	return true


func grand_survey_excludes_replacements() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var first: int = state.expansion.hand[0]
	_grand(state, content)
	_choose_grand(state, content, first)
	var command: ResolveGrandSurveyCommand = ResolveGrandSurveyCommand.new(state.pending_choice.choice_id, state.expansion.hand[0])
	expect_true(not RelicHandRules.validate_command(state, content, command).is_valid, "Only original offered physical tiles can be removed")
	return true


func grand_survey_emergency() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_keep_bag(state, 1)
	var first: int = state.expansion.hand[0]
	var second: int = state.expansion.hand[1]
	var count: int = state.tile_copies.size()
	_grand(state, content)
	_choose_grand(state, content, first)
	_choose_grand(state, content, second)
	expect_equal(state.tile_copies.size(), count + content.get_config().emergency_definitions.size(), "Second replacement replenishes empty bag exactly once")
	expect_true(0 not in state.expansion.hand, "Both replacements complete")
	return true


func grand_survey_no_compass() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_equip(state, content, &"relic.surveyors_compass")
	_grand(state, content)
	_choose_grand(state, content, state.expansion.hand[0])
	expect_equal(state.pending_choice.kind, &"grand_survey", "No Compass choice during Major Reward")
	expect_equal(state.relics.normal_surveys_used, 0, "Does not spend first normal Survey")
	_choose_grand(state, content, 0, true)
	state.resolution = null
	state.phase = GamePhase.Type.TURN_INPUT
	RelicHandRules.survey(state, content, state.expansion.hand[0])
	expect_equal(state.pending_choice.kind, &"compass", "Later first normal Survey still triggers Compass")
	return true


func grand_survey_pending_refill() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.expansion.hand[0] = 0
	state.expansion.pending_refill_index = 0
	_grand(state, content)
	_choose_grand(state, content, state.expansion.hand[1])
	_choose_grand(state, content, 0, true)
	expect_equal(state.expansion.pending_refill_index, 0, "Ordinary placement refill remains pending")
	expect_equal(state.expansion.hand[0], 0, "Grand Survey did not fill pending placement slot")
	expect_true(state.resolution != null, "Outer reward continuation retained")
	return true


func grand_survey_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_grand(state, content)
	_choose_grand(state, content, state.expansion.hand[0])
	var loaded: RunState = _round_trip(state, content)
	if loaded != null:
		expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Mid-sequence progress and RNG survive")
		_choose_grand(loaded, content, 0, true)
		expect_equal(loaded.expansion.survey_charges, 2, "Charge granted only when resumed sequence finishes")
	return true


func grand_survey_invalid_choice_atomic() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_grand(state, content)
	var before: String = StateNormalizer.fingerprint(state)
	var command: ResolveGrandSurveyCommand = ResolveGrandSurveyCommand.new(state.pending_choice.choice_id, state.expansion.bag[0])
	expect_true(not RelicHandRules.validate_command(state, content, command).is_valid, "Bag selection rejected")
	expect_equal(StateNormalizer.fingerprint(state), before, "Invalid Grand Survey choice atomic")
	return true


func grand_survey_charge_above_initial() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_grand(state, content)
	_choose_grand(state, content, 0, true)
	state.resolution = null
	state.phase = GamePhase.Type.TURN_INPUT
	expect_true(InvariantValidator.validate(state, content).is_valid, "Major Reward can exceed initial Survey charge count")
	return true


func malformed_compass_set_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_compass(state, content)
	state.pending_choice.context["inspected_ids"] = []
	expect_true(not InvariantValidator.validate(state, content).is_valid, "Forged inspected set rejected")
	return true


func stranded_inspected_copy_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_compass(state, content)
	state.pending_choice = null
	state.resolution = null
	state.phase = GamePhase.Type.TURN_INPUT
	expect_true(not InvariantValidator.validate(state, content).is_valid, "Inspected copy cannot survive outside Compass continuation")
	return true


func compass_engine_commands() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_equip(state, content, &"relic.surveyors_compass")
	var result: ValidationResult = RulesEngine.execute(state, content, SurveyTileCommand.new(state.expansion.hand[0]))
	expect_true(result.is_valid, "Normal Survey command enters Compass")
	if state.pending_choice != null:
		result = RulesEngine.execute(state, content, ResolveCompassCommand.new(state.pending_choice.choice_id, state.expansion.inspected_ids[0]))
		expect_true(result.is_valid, "Compass resolution passes command boundary")
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Engine resumes normal input")
	expect_true(InvariantValidator.validate(state, content).is_valid, "Engine hand state valid")
	return true


func grand_survey_engine_commands() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_grand(state, content)
	var result: ValidationResult = RulesEngine.execute(state, content, ResolveGrandSurveyCommand.new(state.pending_choice.choice_id, state.expansion.hand[0]))
	expect_true(result.is_valid, result.user_message)
	if state.pending_choice != null:
		result = RulesEngine.execute(state, content, ResolveGrandSurveyCommand.new(state.pending_choice.choice_id, 0, true))
		expect_true(result.is_valid, result.user_message)
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Outer standalone reward continuation drained")
	expect_equal(state.expansion.survey_charges, 2, "One charge awarded through command engine")
	return true


func satchel_engine_two_slots() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_equip(state, content, &"relic.wayfarers_satchel")
	var operations: int = state.rng.operation_count
	var next_draws: Array[int] = state.expansion.bag.slice(0, 2)
	for repeat: int in range(2):
		expect_true(RulesEngine.execute(state, content, ReserveTileCommand.new(state.expansion.hand[0])).is_valid, "Normal command fills a legal empty slot")
	expect_equal(RelicHandRules.reserve_ids(state).size(), 2, "Both slots filled within same normal turn")
	expect_equal(state.expansion.reserve_extra_id, next_draws[0], "First reservation immediately draws the next physical copy")
	expect_equal(state.expansion.hand[0], next_draws[1], "Second reservation immediately refills from the next copy")
	expect_equal(state.rng.operation_count, operations, "Ordinary Reserve draws do not consume RNG")
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, content, ReserveTileCommand.new(state.expansion.hand[0])).is_valid, "Third reservation rejected")
	expect_equal(StateNormalizer.fingerprint(state), before, "Rejected reservation atomic")
	return true


func satchel_engine_place_extra() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_equip(state, content, &"relic.wayfarers_satchel")
	expect_true(RulesEngine.execute(state, content, ReserveTileCommand.new(state.expansion.hand[0])).is_valid, "First slot filled")
	var first: int = state.expansion.reserve_id
	var selected: int = 0
	for copy_id: int in state.expansion.hand:
		if not PlacementQueryService.query_for_copy(state, content, copy_id).is_empty():
			selected = copy_id
			break
	expect_true(selected > 0, "Fixture has a placeable second reservation")
	if selected == 0:
		return true
	expect_true(RulesEngine.execute(state, content, ReserveTileCommand.new(selected, 1)).is_valid, "Placeable copy reserved in second slot")
	var option: PlacementOption = PlacementQueryService.query_for_copy(state, content, selected)[0]
	var command: PlaceTileCommand = PlaceTileCommand.new(selected, TileLocationState.Kind.RESERVE, option.coordinate, option.rotation)
	var result: ValidationResult = RulesEngine.execute(state, content, command)
	expect_true(result.is_valid, result.user_message)
	expect_equal(state.expansion.reserve_extra_id, 0, "Only placed slot emptied")
	expect_equal(state.expansion.reserve_id, first, "Other reservation preserved")
	return true


func stale_hand_choice_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_compass(state, content)
	var command: ResolveCompassCommand = ResolveCompassCommand.new(state.pending_choice.choice_id, state.expansion.inspected_ids[0])
	command.expected_state_revision = state.expansion.state_revision + 1
	expect_true(not RelicHandRules.validate_command(state, content, command).is_valid, "Stale revision rejected")
	command.expected_state_revision = -1
	command.choice_id += 1
	expect_true(not RelicHandRules.validate_command(state, content, command).is_valid, "Stale physical choice ID rejected")
	return true


func malformed_compass_index_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_compass(state, content)
	state.pending_choice.context["hand_index"] = {"bad": true}
	expect_true(not InvariantValidator.validate(state, content).is_valid, "Malformed slot rejected without an invalid cast")
	return true


func grand_survey_reload_finish_not_repeated() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_grand(state, content)
	expect_true(RulesEngine.execute(state, content, ResolveGrandSurveyCommand.new(state.pending_choice.choice_id, 0, true)).is_valid, "Finish command commits charge")
	var before: String = StateNormalizer.fingerprint(state)
	for repeat: int in range(3):
		var loaded: RunState = _round_trip(state, content)
		if loaded != null:
			expect_equal(StateNormalizer.fingerprint(loaded), before, "Repeated resolved Grand Survey load does not repeat charge/history")
			expect_equal(loaded.expansion.survey_charges, 2, "Exactly one Survey charge remains awarded")
			state = loaded
	return true


func normal_survey_counter_overflow_atomic() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.relics.normal_surveys_used = 9223372036854775807
	var before: String = StateNormalizer.fingerprint(state)
	var operations: int = state.rng.operation_count
	var result: ValidationResult = RulesEngine.execute(state, content, SurveyTileCommand.new(state.expansion.hand[0]))
	expect_true(not result.is_valid, "A normal Survey must not overflow its Act history counter")
	expect_equal(StateNormalizer.fingerprint(state), before, "Rejected overflow leaves hand, charge, history and state unchanged")
	expect_equal(state.rng.operation_count, operations, "Rejected overflow consumes no RNG")
	return true
