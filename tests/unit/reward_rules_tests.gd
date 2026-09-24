extends "res://tests/framework/test_suite.gd"
## Reward tests isolate persisted jobs and physical-copy effects from presentation.


func tests() -> Array[Callable]:
	var result: Array[Callable] = [threshold_order, thresholds_never_duplicate,
		milestones_before_thresholds, milestone_order, milestone_once, no_completion_no_milestone,
		tile_pool_cumulative, tile_pool_ignores_playability, offers_distinct_deterministic,
		small_offer_no_padding, invalid_choice_atomic, stale_choice_atomic,
		frozen_outgoing_act, masterwork_quantity, major_cap_filter,
		recruit_uses_existing_identity, training_uses_existing_offer, training_fallback,
		deferred_training_handoff, relic_exhaustion_fallback, relic_cache_chain,
		relic_full_replacement_choice, relic_decline_not_exhausted,
		queue_choice_pauses, copies_before_refill, reward_source_audit, public_reward_command_finishes,
		public_training_reward_finishes, cache_replacement_roundtrip, bag_shuffle_matches_rng,
		reward_copy_can_be_next_draw]
	for track: int in range(4):
		for threshold: int in [20, 40, 70, 100]:
			result.append(threshold_crossing.bind(track, threshold))
	for kind: StringName in [&"tile_reward", &"masterwork", &"major_reward", &"relic_offer", &"training_reward"]:
		result.append(pending_offer_roundtrip.bind(kind))
	for reward_class: int in [1, 2, 3, 4]:
		result.append(quantity_by_class.bind(reward_class))
	return result


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = content.load_phase_eight()
	assert(result.is_valid, result.user_message)
	return content


func _state(content: ContentRegistry) -> RunState:
	return HomesteadRunFactory.create(8158, content)


func _start(state: RunState, content: ContentRegistry, kind: StringName, act: int = 1) -> void:
	state.resolution = ResolutionState.new()
	state.resolution.stage = &"reward_queue"
	state.resolution.context = {"mode": "reward"}
	state.phase = GamePhase.Type.RESOLVING_PLACEMENT
	RewardRules.enqueue(state, kind, 0, act)
	RewardRules.advance(state, content)


func _choose(state: RunState, content: ContentRegistry, index: int = 0) -> void:
	var command: ResolveRewardCommand = ResolveRewardCommand.new(state.pending_choice.choice_id, index)
	var validation: ValidationResult = RewardCommands.validate_command(state, content, command)
	assert(validation.is_valid, validation.user_message)
	RewardCommands.execute_command(state, content, command)


func threshold_crossing(track: int, threshold: int) -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.features.tracks.values[track] = threshold
	RewardRules.queue_thresholds(state)
	expect_true(state.rewards.threshold_flags.has("%d:%d" % [track, threshold]), "Every threshold exists on every track")
	var count: int = state.rewards.queue.size()
	RewardRules.queue_thresholds(state)
	expect_equal(state.rewards.queue.size(), count, "Threshold marked exactly once")
	return true


func threshold_order() -> bool:
	var state: RunState = _state(_content())
	state.features.tracks.values = [120, 101, 70, 40]
	RewardRules.queue_thresholds(state)
	var actual: Array[String] = []
	for job: Dictionary in state.rewards.queue:
		actual.append("%d:%d" % [job.track, job.threshold])
	expect_equal(actual, ["0:20", "0:40", "0:70", "0:100", "1:20", "1:40", "1:70", "1:100", "2:20", "2:40", "2:70", "3:20", "3:40"], "Track order precedes threshold order, no cap")
	return true


func thresholds_never_duplicate() -> bool:
	var state: RunState = _state(_content())
	state.features.tracks.values = [200, 200, 200, 200]
	RewardRules.queue_thresholds(state)
	state.rewards.queue.clear()
	state.features.tracks.values = [300, 300, 300, 300]
	RewardRules.queue_thresholds(state)
	expect_true(state.rewards.queue.is_empty(), "Further gains never repeat any of sixteen thresholds")
	return true


func _milestone_snapshot() -> CompletionSnapshot:
	var facts: Array[Dictionary] = []
	for type: int in [3, 2, 0, 1]:
		facts.append({"feature_type": type, "lineage_id": type + 100, "total_size": 10,
			"network_settlement_ids": [1, 2, 3, 4, 5]})
	return CompletionSnapshot.new({"act": 1, "source_id": 0, "features": facts})


func milestones_before_thresholds() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.features.tracks.values = [100, 100, 100, 100]
	RewardRules.queue_completion(state, _milestone_snapshot())
	expect_equal(state.rewards.queue.size(), 5, "Four milestones then deferred threshold scan")
	expect_equal(state.rewards.queue[4].kind, "scan_thresholds", "Threshold scan waits behind all milestone offers")
	RewardRules.advance(state, content)
	expect_equal(state.pending_choice.kind, &"relic_offer", "First milestone pauses before thresholds")
	expect_true(state.rewards.threshold_flags.is_empty(), "No threshold is processed through pending milestone")
	return true


func milestone_order() -> bool:
	var state: RunState = _state(_content())
	RewardRules.queue_completion(state, _milestone_snapshot())
	expect_equal(state.rewards.milestone_flags, [&"settlement", &"road", &"forest", &"river"], "Input Dictionary/feature order cannot change milestone ordering")
	return true


func milestone_once() -> bool:
	var state: RunState = _state(_content())
	RewardRules.queue_completion(state, _milestone_snapshot())
	state.rewards.queue.clear()
	RewardRules.queue_completion(state, _milestone_snapshot())
	expect_equal(state.rewards.queue.size(), 1, "Recompletion only queues threshold scan")
	return true


func no_completion_no_milestone() -> bool:
	var state: RunState = _state(_content())
	RewardRules.queue_completion(state, CompletionSnapshot.new({"features": [], "act": 1}))
	expect_true(state.rewards.milestone_flags.is_empty(), "Unfinished large topology not inspected without genuine completion facts")
	return true


func tile_pool_cumulative() -> bool:
	var content: ContentRegistry = _content()
	var one: Array[StringName] = RewardRules.tile_pool(content, 1)
	var two: Array[StringName] = RewardRules.tile_pool(content, 2)
	var three: Array[StringName] = RewardRules.tile_pool(content, 3)
	for id: StringName in one:
		expect_true(two.has(id) and three.has(id), "Earlier content remains unlocked")
	expect_true(two.size() > one.size() and three.size() >= two.size(), "Unlock tiers are cumulative")
	expect_true(not one.has(&"tile.founding.homestead"), "Founding is not a reward design")
	return true


func tile_pool_ignores_playability() -> bool:
	var content: ContentRegistry = _content()
	var pool: Array[StringName] = RewardRules.tile_pool(content, 2)
	for id: StringName in content.get_tile_ids():
		var tile: TileDefinition = content.get_tile(id)
		if tile.tile_class == DomainTypes.TileClass.UPGRADE and tile.unlock_act <= 2:
			expect_true(pool.has(id), "Upgrade eligible even without its base Development on board")
	return true


func offers_distinct_deterministic() -> bool:
	var content: ContentRegistry = _content()
	var first: RunState = _state(content)
	var second: RunState = _state(content)
	_start(first, content, &"tile_reward")
	_start(second, content, &"tile_reward")
	expect_equal(first.pending_choice.options, second.pending_choice.options, "Same seed and choices produce exact offer")
	expect_equal(first.current_rng_state, second.current_rng_state, "Same RNG continuation")
	expect_equal(first.pending_choice.options.size(), 3, "Three designs")
	expect_true(first.pending_choice.options[0] != first.pending_choice.options[1] and first.pending_choice.options[0] != first.pending_choice.options[2] and first.pending_choice.options[1] != first.pending_choice.options[2], "Distinct without padding")
	return true


func small_offer_no_padding() -> bool:
	var state: RunState = _state(_content())
	var before: int = state.rng.operation_count
	expect_equal(RewardRules.sample(state, [&"b", &"a"], &"test"), [&"a", &"b"], "Show every small pool option sorted")
	expect_equal(state.rng.operation_count, before, "No random selection needed when every option is offered")
	return true


func invalid_choice_atomic() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_start(state, content, &"tile_reward")
	var before: Array = [state.next_runtime_id, state.current_rng_state, state.rewards.history.duplicate(true), state.tile_copies.size()]
	var result: ValidationResult = RewardCommands.validate_command(state, content, ResolveRewardCommand.new(state.pending_choice.choice_id, 9))
	expect_true(not result.is_valid, "Out-of-range option rejected")
	expect_equal([state.next_runtime_id, state.current_rng_state, state.rewards.history, state.tile_copies.size()], before, "Invalid choice allocates, scores and consumes nothing")
	return true


func stale_choice_atomic() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_start(state, content, &"tile_reward")
	var command: ResolveRewardCommand = ResolveRewardCommand.new(state.pending_choice.choice_id, 0)
	command.expected_state_revision = state.expansion.state_revision + 1
	expect_true(not RewardCommands.validate_command(state, content, command).is_valid, "Stale display revision rejected")
	return true


func frozen_outgoing_act() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.expansion.current_act = 3
	_start(state, content, &"tile_reward", 1)
	for option: Dictionary in state.pending_choice.options:
		expect_equal(content.get_tile(StringName(option.definition_id)).unlock_act, 1, "Outgoing eligibility Act stays frozen independently of current Act")
	return true


func quantity_by_class(reward_class: int) -> bool:
	var tile: TileDefinition = TileDefinition.new()
	tile.reward_class = reward_class as DomainTypes.RewardClass
	expect_equal(RewardRules.copy_quantity(tile), [0, 3, 2, 2, 1][reward_class], "Canonical reward quantity")
	return true


func masterwork_quantity() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_start(state, content, &"masterwork", 3)
	var before: int = state.tile_copies.size()
	_choose(state, content)
	expect_equal(state.tile_copies.size() - before, 3, "Masterwork always grants three physical copies")
	return true


func major_cap_filter() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	expect_true(RewardRules.major_pool(state, content, 1).has(&"recruit_steward"), "Recruit valid below cap")
	SpecialistCommands.recruit(state)
	expect_true(not RewardRules.major_pool(state, content, 1).has(&"recruit_steward"), "Cap filters before RNG")
	return true


func recruit_uses_existing_identity() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var first_id: int = state.specialists.pieces[0].piece_id
	RewardCommands._major(state, content, &"recruit_steward", {"eligibility_act": 1})
	expect_equal(state.specialists.pieces.size(), 3, "Third Steward uses existing runtime roster")
	expect_equal(state.specialists.pieces[0].piece_id, first_id, "Existing identity preserved")
	expect_equal(state.specialists.pieces[2].role_definition_id, &"", "New piece generic")
	return true


func training_uses_existing_offer() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_start(state, content, &"training_reward")
	expect_equal(state.pending_choice.kind, &"training_piece", "Player chooses eligible generic first")
	_choose(state, content)
	expect_equal(state.pending_choice.kind, &"specialist_training", "Existing Phase7 role offer reused")
	expect_equal(state.pending_choice.context.resume_phase, GamePhase.Type.RESOLVING_PLACEMENT, "Training resumes same reward queue")
	return true


func training_fallback() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	for piece: SpecialistPieceState in state.specialists.pieces:
		piece.role_definition_id = &"specialist.merchant"
	_start(state, content, &"training_reward")
	expect_equal(state.pending_choice.kind, &"tile_reward", "Untrainable reward becomes real Tile Reward")
	return true


func deferred_training_handoff() -> bool:
	var state: RunState = _state(_content())
	state.specialists.deferred_rewards.append({"event_id": 99, "reward_kind": "normal_tile_reward", "quantity": 1})
	RewardRules.claim_deferred_training(state)
	RewardRules.claim_deferred_training(state)
	expect_equal(state.rewards.queue.size(), 1, "Typed deferred reward consumed once")
	expect_equal(state.rewards.queue[0].source_id, 99, "Audit source survives handoff")
	return true


func _exhaust(state: RunState, content: ContentRegistry) -> void:
	while not RelicRules.eligible_ids(state, content, 1).is_empty():
		var id: StringName = RelicRules.eligible_ids(state, content, 1)[0]
		var replacement: StringName = &""
		if RelicRules.equipped(state).size() == state.relics.capacity:
			replacement = RelicRules.equipped(state)[0].definition_id
		assert(RelicRules.acquire(state, content, id, replacement).is_valid)


func relic_exhaustion_fallback() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_exhaust(state, content)
	expect_true(not RewardRules.major_pool(state, content, 1).has(&"relic_cache"), "No unowned Relics excludes Cache")
	_start(state, content, &"relic_offer")
	expect_equal(state.pending_choice.kind, &"tile_reward", "Exhausted Relic offer converts to normal Tile Reward")
	return true


func relic_cache_chain() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	RewardCommands._major(state, content, &"relic_cache", {"eligibility_act": 1, "source_id": 0})
	expect_equal(state.rewards.queue[0].kind, "relic_offer", "Relic goes first")
	expect_equal(state.rewards.queue[1].kind, "tile_reward", "Tile reward waits for entire Relic sequence")
	RewardRules.advance(state, content)
	_choose(state, content)
	RewardRules.advance(state, content)
	expect_equal(state.pending_choice.kind, &"tile_reward", "Acquired Relic continues into Tile Reward")
	return true


func relic_full_replacement_choice() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	assert(RelicRules.acquire(state, content, &"relic.boundary_stones").is_valid)
	assert(RelicRules.acquire(state, content, &"relic.surveyors_compass").is_valid)
	_start(state, content, &"relic_offer")
	_choose(state, content)
	expect_equal(state.pending_choice.kind, &"relic_replacement", "Full capacity pauses acquisition")
	expect_equal(state.pending_choice.options.size(), 3, "Decline and both legally removable slots")
	return true


func relic_decline_not_exhausted() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	assert(RelicRules.acquire(state, content, &"relic.boundary_stones").is_valid)
	assert(RelicRules.acquire(state, content, &"relic.surveyors_compass").is_valid)
	_start(state, content, &"relic_offer")
	_choose(state, content)
	var offered: StringName = StringName(state.pending_choice.context.definition_id)
	_choose(state, content, 0)
	expect_true(RelicRules.eligible_ids(state, content, 1).has(offered), "Declined Relic remains eligible")
	return true


func queue_choice_pauses() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	RewardRules.enqueue(state, &"tile_reward")
	RewardRules.enqueue(state, &"tile_reward")
	RewardRules.advance(state, content)
	var rng: int = state.current_rng_state
	var choice_id: int = state.pending_choice.choice_id
	RewardRules.advance(state, content)
	expect_equal(state.pending_choice.choice_id, choice_id, "Pending choice never regenerated")
	expect_equal(state.current_rng_state, rng, "Paused queue consumes no further RNG")
	expect_equal(state.rewards.queue.size(), 1, "Next reward waits")
	return true


func copies_before_refill() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	var original: int = state.expansion.hand[0]
	state.expansion.hand[0] = 0
	state.expansion.removed_ids.append(original)
	PhysicalTileRules.set_location(state, original, TileLocationState.Kind.REMOVED_FROM_RUN)
	state.expansion.pending_refill_index = 0
	_start(state, content, &"tile_reward")
	var before: int = state.expansion.bag.size()
	var quantity: int = RewardRules.copy_quantity(content.get_tile(StringName(state.pending_choice.options[0].definition_id)))
	_choose(state, content)
	expect_equal(state.expansion.bag.size(), before + quantity, "Reward copies enter full bag before final replacement draw")
	expect_equal(state.expansion.hand[0], 0, "Reward layer does not steal outer placement refill")
	expect_equal(state.expansion.pending_refill_index, 0, "Pending placement work preserved")
	return true


func reward_source_audit() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_start(state, content, &"tile_reward")
	_choose(state, content)
	var record: Dictionary = state.rewards.history.back()
	expect_equal(record.kind, "reward_tiles_acquired", "Physical acquisition auditable")
	for id: int in record.details.tile_copy_ids:
		var tile: TileCopyState = PhysicalTileRules.find_copy(state, id)
		expect_equal(tile.acquired_act, 1, "Physical copy remembers acquisition Act")
		expect_equal(tile.acquisition_source, &"normal_tile_reward", "Physical copy remembers reward source")
	return true


func _load_copy(state: RunState, content: ContentRegistry) -> RunState:
	var saved: SerializationResult = RunSerializer.serialize(state, content)
	assert(saved.validation.is_valid, str(saved.validation.debug_details))
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	assert(loaded.validation.is_valid, str(loaded.validation.debug_details))
	return loaded.state


func pending_offer_roundtrip(kind: StringName) -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_start(state, content, kind)
	var original: String = RunSerializer.serialize(state, content).json_text
	var restored: RunState = _load_copy(_load_copy(state, content), content)
	expect_equal(RunSerializer.serialize(restored, content).json_text, original, "Repeated saved offer has zero effects, RNG or offer regeneration")
	expect_equal(restored.pending_choice.options, state.pending_choice.options, "Exact selected offer retained")
	return true


func public_reward_command_finishes() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_start(state, content, &"tile_reward")
	var command: ResolveRewardCommand = ResolveRewardCommand.new(state.pending_choice.choice_id, 0)
	var result: ValidationResult = RulesEngine.execute(state, content, command)
	expect_true(result.is_valid, "Public reward command validates saved queue: " + str(result.debug_details))
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Standalone reward resumes turn input")
	expect_true(state.resolution == null and state.pending_choice == null, "Resolved continuation clears exactly once")
	expect_true(InvariantValidator.validate(state, content).is_valid, "Public reward leaves coherent state")
	return true


func public_training_reward_finishes() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_start(state, content, &"training_reward")
	var choice_result: ValidationResult = RulesEngine.execute(state, content, ResolveRewardCommand.new(state.pending_choice.choice_id, 0))
	expect_true(choice_result.is_valid, "Public training selection uses canonical generic roster")
	state = _load_copy(state, content)
	var choice: PendingChoice = state.pending_choice
	var trained: ValidationResult = RulesEngine.execute(state, content, ResolveSpecialistTrainingCommand.new(choice.choice_id, StringName(choice.options[0].role_definition_id)))
	expect_true(trained.is_valid, "Public Phase7 training resumes real Phase8 reward")
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Training sequence resumes turn")
	expect_true(state.resolution == null, "No stranded reward continuation")
	return true


func cache_replacement_roundtrip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	assert(RelicRules.acquire(state, content, &"relic.boundary_stones").is_valid)
	assert(RelicRules.acquire(state, content, &"relic.surveyors_compass").is_valid)
	state.resolution = ResolutionState.new()
	state.resolution.stage = &"reward_queue"
	state.resolution.context = {"mode": "reward"}
	RewardCommands._major(state, content, &"relic_cache", {"eligibility_act": 1, "source_id": 0})
	RewardRules.advance(state, content)
	_choose(state, content)
	state = _load_copy(state, content)
	expect_equal(state.pending_choice.kind, &"relic_replacement", "Replacement chain resumes its exact stage")
	var rng: int = state.current_rng_state
	_choose(state, content, 1)
	expect_equal(state.current_rng_state, rng, "Acquiring selected Relic consumes no further offer RNG")
	RewardRules.advance(state, content)
	expect_equal(state.pending_choice.kind, &"tile_reward", "Cache post-Relic reward preserved through reload")
	return true


func bag_shuffle_matches_rng() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	_start(state, content, &"tile_reward")
	var rng: RunRNG = RunRNG.from_snapshot(state.original_seed, state.current_rng_state, state.rng.operation_count)
	var before: Array[int] = state.expansion.bag.duplicate()
	_choose(state, content)
	var record: Dictionary = state.rewards.history.back()
	for id: int in record.details.tile_copy_ids:
		before.append(id)
	var expected: Array[int] = rng.shuffled_ids(before, &"tile_reward_bag_shuffle")
	expect_equal(state.expansion.bag, expected, "Every remaining bag copy participates in exact RunRNG shuffle")
	expect_equal(state.current_rng_state, rng.current_state, "Reward bag RNG continuation matches reference")
	return true


func reward_copy_can_be_next_draw() -> bool:
	var content: ContentRegistry = _content()
	var found: bool = false
	for seed_value: int in range(1, 30):
		var state: RunState = HomesteadRunFactory.create(seed_value, content)
		_start(state, content, &"tile_reward")
		_choose(state, content)
		var new_ids: Array = state.rewards.history.back().details.tile_copy_ids
		if new_ids.has(state.expansion.bag[0]):
			found = true
			break
	expect_true(found, "Newly awarded physical copy can occupy next replacement position after whole-bag shuffle")
	return true
