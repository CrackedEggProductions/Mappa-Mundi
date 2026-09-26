extends "res://tests/framework/test_suite.gd"
## Service fixtures isolate ordering; full-run integration supplies real placement journals.

const Graph = preload("res://tests/fixtures/topology_fixture.gd")


func tests() -> Array[Callable]:
	var result: Array[Callable] = [failed_charter_no_rewards, outgoing_reward_order,
		outgoing_relic_capacity, outgoing_reward_frozen_pool, transition_records_order,
		seed_before_refill, reserve_final_placement_no_draw, survey_expires,
		relic_refresh_order, entering_three_preserves_grand_rng, civilization_persists,
		final_score_uncapped, final_no_refill, final_statistics_histories,
		finalization_no_rng, finalization_rejects_pending, begin_rejects_incomplete,
		transition_rejects_bonus, finalization_rejects_bonus, finalization_once]
	result.append(act_two_fulfilled_rewards)
	result.append(act_two_exceeded_rewards)
	result.append(act_two_outgoing_capacity)
	result.append(final_score_overflow_atomic)
	for act: int in [2, 3]:
		result.append(seed_identity_counts.bind(act))
	for step: int in range(1, 15):
		result.append(single_step_progress.bind(step))
	return result


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	assert(content.load_phase_nine().is_valid)
	return content


func _state(content: ContentRegistry, act: int = 1) -> RunState:
	var state: RunState = HomesteadRunFactory.create(9009, content)
	state.charters.act_one_id = &"charter.a1_growing_realm"
	if act > 1:
		state.expansion.current_act = act
		assert(RelicRules.refresh_act(state, act).is_valid)
		state.charters.act_two_id = &"charter.a2_growing_communities"
		state.charters.grand_id = &"charter.grand_great_metropolis"
		state.charters.forecast_visible = true
		state.charters.exact_revealed = act == 3
	state.expansion.normal_placements = content.get_config().act_placement_limits[act - 1]
	state.phase = GamePhase.Type.RESOLVING_ACT_TRANSITION
	return state


func _hole(state: RunState) -> void:
	var copy_id: int = state.expansion.hand[0]
	state.expansion.removed_ids.append(copy_id)
	PhysicalTileRules.set_location(state, copy_id, TileLocationState.Kind.REMOVED_FROM_RUN)
	state.expansion.hand[0] = 0
	state.expansion.pending_refill_index = 0


func _through(state: RunState, content: ContentRegistry, step: int) -> void:
	if state.act_transition == null:
		assert(ActRules.begin_transition(state, content).is_valid)
	while state.act_transition != null and state.act_transition.step <= step:
		assert(ActRules.advance_one(state, content).is_valid)
		assert(state.pending_choice == null, "This fixture expects a failed Charter")


func _fulfilled(state: RunState, exceeded: bool) -> void:
	state.features.tracks.values[0] = 30 if exceeded else 20
	for index: int in range(2):
		var record: FeatureCompletionRecord = FeatureCompletionRecord.new()
		record.feature_type = DomainTypes.FeatureType.SETTLEMENT
		state.features.completions.append(record)


func failed_charter_no_rewards() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_through(state, content, 2)
	expect_equal(state.act_transition.charter_result.overall_state, "failed", "Failed Charter recorded")
	expect_true(state.rewards.queue.is_empty() and state.pending_choice == null, "Failure grants no rewards")
	expect_equal(state.expansion.current_act, 1, "Failure does not advance until step four")
	return true


func outgoing_reward_order() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_fulfilled(state, true)
	assert(ActRules.begin_transition(state, content).is_valid)
	assert(ActRules.advance(state, content).is_valid)
	expect_equal(state.pending_choice.kind, &"tile_reward", "Act I first offers Tile Reward")
	RewardCommands.execute_command(state, content, ResolveRewardCommand.new(state.pending_choice.choice_id, 0))
	assert(ActRules.advance(state, content).is_valid)
	expect_equal(state.pending_choice.kind, &"relic_offer", "Exceeded adds Relic after Tile Reward resolves")
	expect_equal(state.act_transition.pending_charter_reward_index, 1, "One ordered reward completed")
	RewardCommands.execute_command(state, content, ResolveRewardCommand.new(state.pending_choice.choice_id, 0))
	assert(ActRules.advance(state, content).is_valid)
	expect_equal(state.expansion.current_act, 2, "Full reward chain precedes advancement")
	expect_true(not state.charters.evaluations[0].rewards_resolved.is_empty(), "Resolved choices retained in Charter audit")
	return true


func outgoing_relic_capacity() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	assert(RelicRules.acquire(state, content, RelicRules.BOUNDARY).is_valid)
	assert(RelicRules.acquire(state, content, RelicRules.GREEN).is_valid)
	_fulfilled(state, true)
	assert(ActRules.begin_transition(state, content).is_valid)
	assert(ActRules.advance(state, content).is_valid)
	RewardCommands.execute_command(state, content, ResolveRewardCommand.new(state.pending_choice.choice_id, 0))
	assert(ActRules.advance(state, content).is_valid)
	RewardCommands.execute_command(state, content, ResolveRewardCommand.new(state.pending_choice.choice_id, 0))
	expect_equal(state.pending_choice.kind, &"relic_replacement", "Outgoing full capacity still requires replacement")
	expect_equal(state.relics.capacity, 2, "Act II slots not granted early")
	expect_equal(state.expansion.current_act, 1, "Replacement remains in outgoing Act")
	return true


func outgoing_reward_frozen_pool() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_fulfilled(state, false)
	assert(ActRules.begin_transition(state, content).is_valid)
	assert(ActRules.advance(state, content).is_valid)
	expect_equal(state.pending_choice.context.eligibility_act, 1, "Outgoing eligibility persisted")
	for option: Dictionary in state.pending_choice.options:
		expect_true(content.get_tile(StringName(option.definition_id)).unlock_act <= 1, "No Act II reward leak")
	return true


func transition_records_order() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_through(state, content, 14)
	var steps: Array[int] = []
	for event: Dictionary in state.charters.history:
		if event.kind == "act_transition_step":
			steps.append(int(event.details.step))
	expect_equal(steps, range(1, 15), "All fourteen steps audited in canonical order")
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Final transition step enters input")
	expect_equal(state.expansion.normal_placements, 0, "Incoming counter reset")
	return true


func single_step_progress(step: int) -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_through(state, content, step)
	if step < 14:
		expect_equal(state.act_transition.step, step + 1, "One-step API saves the exact next operation")
		expect_equal(state.act_transition.advanced, step >= 4, "Advance flag follows operation")
		expect_equal(state.act_transition.seeded, step >= 9, "Seeding flag follows operation")
		expect_equal(state.act_transition.shuffled, step >= 10, "Shuffle flag follows operation")
		expect_equal(state.act_transition.information_selected, step >= 11, "Information flag follows operation")
		expect_equal(state.act_transition.refill_done, step >= 13, "Refill flag follows operation")
		expect_equal(ActRules.unlocked_act(state), 2 if step >= 8 else 1, "Queries distinguish advancement from unlock step")
	else:
		expect_true(state.act_transition == null, "Completed transition clears continuation")
	return true


func seed_identity_counts(incoming: int) -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, incoming - 1)
	var previous: int = state.tile_copies.size()
	var before_rng: int = state.rng.operation_count
	_through(state, content, 9)
	var copies: Array[int] = state.act_transition.seeded_copy_ids
	expect_equal(copies.size(), 10 if incoming == 2 else 6, "Exact automatic seed total")
	expect_equal(state.tile_copies.size(), previous + copies.size(), "Every seed is a physical copy")
	expect_equal(state.rng.operation_count, before_rng, "Seeding waits for separate shuffle step")
	for definition: StringName in ActRules.seed_definitions(incoming):
		var count: int = 0
		for id: int in copies:
			var tile: TileCopyState = PhysicalTileRules.find_copy(state, id)
			expect_equal(tile.acquired_act, incoming, "Correct acquisition Act")
			expect_equal(tile.acquisition_source, &"act_transition_seed", "Explicit seed provenance")
			expect_true(state.expansion.bag.has(id), "Seeded copy enters bag")
			if tile.definition_id == definition:
				count += 1
		expect_equal(count, 2, "Exactly two of each canonical seeded design")
	return true


func seed_before_refill() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_hole(state)
	# Empty source bag guarantees the real shuffle/refill must draw a new seed.
	for id: int in state.expansion.bag:
		state.expansion.removed_ids.append(id)
		PhysicalTileRules.set_location(state, id, TileLocationState.Kind.REMOVED_FROM_RUN)
	state.expansion.bag.clear()
	_through(state, content, 12)
	expect_equal(state.expansion.hand[0], 0, "Hole persists through seeding, shuffle and information")
	var seeds: Array[int] = state.act_transition.seeded_copy_ids.duplicate()
	assert(ActRules.advance_one(state, content).is_valid)
	expect_true(seeds.has(state.expansion.hand[0]), "Incoming seed can be the outgoing pending refill")
	expect_equal(state.expansion.bag.size(), 9, "Exactly one pending draw")
	return true


func reserve_final_placement_no_draw() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var hand: Array[int] = state.expansion.hand.duplicate()
	var bag_size: int = state.expansion.bag.size()
	_through(state, content, 14)
	expect_equal(state.expansion.hand, hand, "Reserve final placement has no active-hand refill")
	expect_equal(state.expansion.bag.size(), bag_size + 10, "Seeding does not cause unsolicited draw")
	return true


func survey_expires() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.expansion.survey_charges = 4
	_through(state, content, 5)
	expect_equal(state.expansion.survey_charges, 4, "Charges stay until canonical refresh")
	assert(ActRules.advance_one(state, content).is_valid)
	expect_equal(state.expansion.survey_charges, 1, "Prior unused/Grand Survey charges expire")
	return true


func relic_refresh_order() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	assert(RelicRules.acquire(state, content, RelicRules.BOUNDARY).is_valid)
	assert(RelicRules.consume_use(state, RelicRules.BOUNDARY).is_valid)
	state.relics.normal_surveys_used = 1
	_through(state, content, 4)
	expect_equal(state.relics.capacity, 2, "Advance alone does not increase capacity")
	_through(state, content, 6)
	expect_equal(state.relics.capacity, 4, "Capacity follows step five")
	expect_equal(state.relics.current_act, 1, "Relic epoch waits until after Survey refresh")
	expect_true(not RelicRules.use_available(state, RelicRules.BOUNDARY), "Spent use stays spent until refresh")
	assert(ActRules.advance_one(state, content).is_valid)
	expect_true(RelicRules.use_available(state, RelicRules.BOUNDARY), "New Act grants fresh use")
	expect_equal(state.relics.normal_surveys_used, 0, "Compass history resets with Relic epoch")
	return true


func entering_three_preserves_grand_rng() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, 2)
	var grand: StringName = state.charters.grand_id
	_through(state, content, 10)
	var rng: int = state.rng.operation_count
	assert(ActRules.advance_one(state, content).is_valid)
	expect_equal(state.rng.operation_count, rng, "Act III information step consumes no Charter RNG")
	expect_equal(state.charters.grand_id, grand, "Grand selection preserved")
	return true


func civilization_persists() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.features.tracks.values = [7, 8, 9, 10]
	state.rewards.threshold_flags.append("0:20")
	state.rewards.milestone_flags.append(&"forest")
	var board: BoardState = state.expansion.board
	var features: FeatureState = state.features
	var trade: TradeState = state.trade
	var specialists: SpecialistState = state.specialists
	var hand: Array[int] = state.expansion.hand.duplicate()
	var bag: Array[int] = state.expansion.bag.duplicate()
	_through(state, content, 14)
	expect_true(state.expansion.board == board and state.features == features and state.trade == trade,
		"Board, feature histories and network genealogy retain same authoritative objects")
	expect_true(state.specialists == specialists, "Piece identities/assignments not replaced")
	expect_equal(state.expansion.hand, hand, "Existing active hand retained")
	expect_equal(state.features.tracks.values, [7, 8, 9, 10], "Tracks cumulative")
	expect_true(state.rewards.threshold_flags.has("0:20") and state.rewards.milestone_flags.has(&"forest"), "Reward histories retained")
	for id: int in bag:
		expect_true(state.expansion.bag.has(id), "Old bag copy retained alongside seeds")
	return true


func final_score_uncapped() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, 3)
	state.features.tracks.values = [120, 143, 99, 202]
	assert(ActRules.finalize(state, content).is_valid)
	expect_equal(state.final_result.score, 564, "All uncapped Tracks sum without multipliers")
	expect_equal(state.final_result.victory_result, &"completed_no_victory", "Failure still receives numeric score")
	return true


func final_no_refill() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, 3)
	_hole(state)
	var bag: Array[int] = state.expansion.bag.duplicate()
	assert(ActRules.finalize(state, content).is_valid)
	expect_equal(state.expansion.hand[0], 0, "Final hand hole remains empty")
	expect_equal(state.expansion.pending_refill_index, -1, "No deferred draw can resume after completion")
	expect_equal(state.expansion.bag, bag, "No final draw or shuffle")
	expect_equal(state.phase, GamePhase.Type.RUN_COMPLETE, "Finalization ends input")
	expect_true(state.act_transition == null, "Final Act has no ordinary transition")
	return true


func final_statistics_histories() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, 3)
	state.features.largest_completed_sizes = [15, 12, 11, 17]
	assert(RelicRules.acquire(state, content, RelicRules.BOUNDARY).is_valid)
	state.relics.capacity = 1
	assert(RelicRules.acquire(state, content, RelicRules.GREEN, RelicRules.BOUNDARY).is_valid)
	state.relics.capacity = 5
	state.specialists.pieces[0].role_definition_id = &"specialist.merchant"
	state.specialists.pieces[0].training_history.append({"role_definition_id": "specialist.merchant", "act": 1})
	assert(ActRules.finalize(state, content).is_valid)
	var stats: Dictionary = state.final_result.statistics
	expect_equal(stats.largest_settlement_established, 12, "Historical largest Settlement, not current board")
	expect_equal(stats.longest_road_completed, 15, "Historical longest Road")
	expect_equal(stats.largest_forest_completed, 11, "Historical largest Forest")
	expect_equal(stats.longest_river_completed, 17, "Historical longest River")
	expect_equal(stats.relics_acquired.size(), 2, "Acquired history includes replacement")
	expect_equal(stats.relics_replaced, [String(RelicRules.BOUNDARY)], "Replaced history retained")
	expect_equal(stats.relics_equipped, [String(RelicRules.GREEN)], "Currently equipped separate")
	expect_equal(stats.specialist_training[0].history.size(), 1, "Training choices retained")
	expect_equal(stats.run_seed, state.original_seed, "Seed retained")
	expect_equal(stats.charters.back().overall_state, "failed", "Final Grand evaluation retained")
	return true


func finalization_no_rng() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, 3)
	var rng: int = state.current_rng_state
	var operations: int = state.rng.operation_count
	assert(ActRules.finalize(state, content).is_valid)
	expect_equal(state.current_rng_state, rng, "Evaluation/final statistics have no randomness")
	expect_equal(state.rng.operation_count, operations, "No hidden RNG operation")
	return true


func finalization_rejects_pending() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, 3)
	RewardRules.enqueue(state, &"tile_reward")
	expect_true(not ActRules.finalize(state, content).is_valid, "Queued reward blocks finalization")
	state.rewards.queue.clear()
	state.pending_choice = PendingChoice.new()
	expect_true(not ActRules.finalize(state, content).is_valid, "Pending choice blocks finalization")
	state.pending_choice = null
	state.resolution = ResolutionState.new()
	expect_true(not ActRules.finalize(state, content).is_valid, "Completion consequences block finalization")
	expect_true(state.final_result == null, "No premature result")
	return true


func begin_rejects_incomplete() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.expansion.normal_placements -= 1
	var rng: int = state.current_rng_state
	var next_id: int = state.next_runtime_id
	expect_true(not ActRules.begin_transition(state, content).is_valid, "Act requires final normal placement")
	expect_equal(state.current_rng_state, rng, "Invalid transition no RNG")
	expect_equal(state.next_runtime_id, next_id, "Invalid transition no allocations")
	return true


func transition_rejects_bonus() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.charters.bonus_queue.append({"source_id": 1, "act": 1})
	expect_true(not ActRules.begin_transition(state, content).is_valid, "Queued bonus stays in outgoing Act")
	state.charters.bonus_queue.clear()
	state.charters.bonus_active = true
	expect_true(not ActRules.begin_transition(state, content).is_valid, "Active bonus blocks transition")
	return true


func finalization_rejects_bonus() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, 3)
	state.charters.bonus_queue.append({"source_id": 1, "act": 3})
	expect_true(not ActRules.finalize(state, content).is_valid, "Final queued bonus must resolve first")
	state.charters.bonus_queue.clear()
	state.charters.bonus_active = true
	expect_true(not ActRules.finalize(state, content).is_valid, "Final active bonus must resolve first")
	return true


func finalization_once() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, 3)
	assert(ActRules.finalize(state, content).is_valid)
	var history: int = state.charters.history.size()
	var ids: int = state.next_runtime_id
	expect_true(not ActRules.finalize(state, content).is_valid, "Already complete cannot finalize again")
	expect_equal(state.charters.history.size(), history, "Final audit not duplicated")
	expect_equal(state.next_runtime_id, ids, "Repeated finalization is atomic")
	return true


func _act_two_success(content: ContentRegistry, exceeded: bool) -> RunState:
	var state: RunState = _state(content, 2)
	state.charters.act_two_id = &"charter.a2_stewardship_of_land"
	state.features.tracks.values[3] = 55 if exceeded else 40
	for index: int in range(6):
		Graph.add(state, Vector2i(10, index), [DomainTypes.EdgeType.FOREST,
			DomainTypes.EdgeType.FIELD, DomainTypes.EdgeType.FOREST, DomainTypes.EdgeType.FIELD])
		Graph.add(state, Vector2i(20, index), [DomainTypes.EdgeType.RIVER,
			DomainTypes.EdgeType.FIELD, DomainTypes.EdgeType.RIVER, DomainTypes.EdgeType.FIELD])
	Graph.reconcile(state)
	return state


func act_two_fulfilled_rewards() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _act_two_success(content, false)
	assert(ActRules.begin_transition(state, content).is_valid)
	assert(ActRules.advance(state, content).is_valid)
	expect_equal(state.pending_choice.kind, &"relic_offer", "Act II fulfillment starts with Relic")
	expect_equal(state.act_transition.rewards, [&"relic_offer", &"tile_reward"], "Act II fulfillment order")
	for option: Dictionary in state.pending_choice.options:
		expect_true(content.get_relic(StringName(option.definition_id)).unlock_act <= 2, "Legacy Relics remain locked")
	RewardCommands.execute_command(state, content, ResolveRewardCommand.new(state.pending_choice.choice_id, 0))
	assert(ActRules.advance(state, content).is_valid)
	expect_equal(state.pending_choice.kind, &"tile_reward", "Act II Tile Reward follows resolved Relic")
	expect_equal(state.pending_choice.context.eligibility_act, 2, "Tile pool frozen to outgoing Act II")
	for option: Dictionary in state.pending_choice.options:
		expect_true(content.get_tile(StringName(option.definition_id)).unlock_act <= 2, "Act III tiles not offered early")
	RewardCommands.execute_command(state, content, ResolveRewardCommand.new(state.pending_choice.choice_id, 0))
	assert(ActRules.advance(state, content).is_valid)
	expect_equal(state.expansion.current_act, 3, "Fulfilled rewards finish before incoming Act")
	expect_equal(state.relics.capacity, 5, "Act III capacity applies afterward")
	return true


func act_two_exceeded_rewards() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _act_two_success(content, true)
	assert(ActRules.begin_transition(state, content).is_valid)
	assert(ActRules.advance(state, content).is_valid)
	RewardCommands.execute_command(state, content, ResolveRewardCommand.new(state.pending_choice.choice_id, 0))
	assert(ActRules.advance(state, content).is_valid)
	RewardCommands.execute_command(state, content, ResolveRewardCommand.new(state.pending_choice.choice_id, 0))
	assert(ActRules.advance(state, content).is_valid)
	expect_equal(state.pending_choice.kind, &"major_reward", "Exceed adds Major only after Relic and Tile")
	expect_equal(state.pending_choice.context.eligibility_act, 2, "Nested Major keeps outgoing eligibility")
	expect_equal(state.expansion.current_act, 2, "Act remains II while Major waits")
	expect_equal(state.relics.capacity, 4, "Major chain retains outgoing capacity")
	expect_equal(state.act_transition.pending_charter_reward_index, 2, "Continuation records third reward")
	return true


func act_two_outgoing_capacity() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _act_two_success(content, false)
	for id: StringName in [RelicRules.BOUNDARY, RelicRules.GREEN, RelicRules.COMPASS, RelicRules.SATCHEL]:
		assert(RelicRules.acquire(state, content, id).is_valid)
	assert(ActRules.begin_transition(state, content).is_valid)
	assert(ActRules.advance(state, content).is_valid)
	RewardCommands.execute_command(state, content, ResolveRewardCommand.new(state.pending_choice.choice_id, 0))
	expect_equal(state.pending_choice.kind, &"relic_replacement", "Outgoing four slots full requires replacement")
	expect_equal(state.relics.capacity, 4, "Fifth slot waits until all Charter rewards resolve")
	expect_equal(state.expansion.current_act, 2, "Replacement choice freezes outgoing Act")
	return true


func final_score_overflow_atomic() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content, 3)
	state.features.tracks.values = [9223372036854775807, 1, 0, 0]
	var next_id: int = state.next_runtime_id
	var history: int = state.charters.history.size()
	expect_true(not ActRules.finalize(state, content).is_valid, "Unrepresentable total rejected before final mutation")
	expect_true(state.final_result == null, "No overflowed final score stored")
	expect_equal(state.next_runtime_id, next_id, "No event allocation on rejected total")
	expect_equal(state.charters.history.size(), history, "No partial final audit")
	return true
