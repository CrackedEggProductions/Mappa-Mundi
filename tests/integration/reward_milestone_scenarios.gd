extends "res://tests/framework/test_suite.gd"
## Real canonical tiles and player commands exercise milestone pipeline integration.

const F = preload("res://tests/fixtures/phase_eight_factory.gd")
const TradeFixture = preload("res://tests/fixtures/phase_four_factory.gd")
const TYPE = DomainTypes.FeatureType


func tests() -> Array[Callable]:
	var result: Array[Callable] = [settlement_milestone_before_threshold,
		milestone_queue_save_load, forest_milestone_once_across_two_features,
		road_network_milestone_on_recompletion]
	for type: int in [TYPE.SETTLEMENT, TYPE.FOREST, TYPE.RIVER]:
		result.append(unfinished_growth_no_milestone.bind(type))
		result.append(real_completion_milestone.bind(type))
	return result


func _direction(type: int) -> Vector2i:
	return Vector2i.UP if type == TYPE.SETTLEMENT else (Vector2i.LEFT if type == TYPE.FOREST else Vector2i.DOWN)


func _through(type: int) -> StringName:
	return &"tile.settlement_throughway" if type == TYPE.SETTLEMENT else (&"tile.forest_belt" if type == TYPE.FOREST else &"tile.river_run")


func _end(type: int) -> StringName:
	return &"tile.hamlet_edge" if type == TYPE.SETTLEMENT else (&"tile.forest_edge" if type == TYPE.FOREST else &"tile.river_end")


func _name(type: int) -> StringName:
	return &"settlement" if type == TYPE.SETTLEMENT else (&"forest" if type == TYPE.FOREST else &"river")


func _size(type: int) -> int:
	return 8 if type == TYPE.SETTLEMENT else 10


func _chain(registry: ContentRegistry, type: int, size_before: int) -> RunState:
	# Establish the unfinished geography before Phase-8 activation; no completion
	# records or milestone dictionaries are fabricated by this setup.
	var state: RunState = F.Previous.Previous.create(registry, 1)
	for index: int in range(1, size_before):
		F.Geography.add(state, registry, _through(type), _direction(type) * index,
			1 if type == TYPE.FOREST else 0)
	return F.activate(state)


func _close(state: RunState, registry: ContentRegistry, type: int, distance: int) -> void:
	var rotation: int = 2 if type == TYPE.SETTLEMENT else (1 if type == TYPE.FOREST else 0)
	F.play(state, registry, _end(type), _direction(type) * distance, rotation)
	F.decline_assignment(state, registry)


func _resolve_rewards(state: RunState, registry: ContentRegistry) -> void:
	var guard: int = 0
	while state.pending_choice != null:
		guard += 1
		assert(guard < 30, "Finite milestone reward chain")
		if state.pending_choice.kind == &"specialist_assignment":
			F.decline_assignment(state, registry)
		elif state.pending_choice.kind == &"specialist_training":
			var choice: PendingChoice = state.pending_choice
			assert(RulesEngine.execute(state, registry, ResolveSpecialistTrainingCommand.new(
				choice.choice_id, StringName(choice.options[0]["role_definition_id"]))).is_valid)
		else:
			assert(state.pending_choice.kind in RewardCommands.KINDS, "Only canonical reward choices expected")
			var result: ValidationResult = RulesEngine.execute(state, registry,
				ResolveRewardCommand.new(state.pending_choice.choice_id, 0))
			assert(result.is_valid, result.user_message + str(result.debug_details))


func unfinished_growth_no_milestone(type: int) -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _chain(registry, type, _size(type) - 1)
	F.play(state, registry, _through(type), _direction(type) * (_size(type) - 1),
		1 if type == TYPE.FOREST else 0)
	F.decline_assignment(state, registry)
	var lineage: FeatureLineageState = F.Geography.lineage_at(state, Vector2i.ZERO, type)
	expect_true(not lineage.completed, "Threshold-sized feature still has its open exit")
	expect_true(state.rewards.milestone_flags.is_empty(), "Growing to milestone size does not earn completion reward")
	expect_true(state.pending_choice == null, "Only optional local assignment, never a premature Relic offer")
	expect_true(InvariantValidator.validate(state, registry).is_valid, "Real unfinished geometry remains valid")
	return true


func real_completion_milestone(type: int) -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _chain(registry, type, _size(type) - 1)
	_close(state, registry, type, _size(type) - 1)
	var lineage: FeatureLineageState = F.Geography.lineage_at(state, Vector2i.ZERO, type)
	expect_true(lineage.completed, "Canonical end tile genuinely closes the feature")
	expect_true(state.rewards.milestone_flags.has(_name(type)), "Real completion earns correct milestone")
	expect_equal(state.pending_choice.kind, &"relic_offer", "Milestone begins its normal Relic acquisition chain")
	var last: FeatureCompletionRecord = state.features.completions.back()
	expect_equal(last.total_size, _size(type), "Milestone sees all physical tiles in completed feature")
	_resolve_rewards(state, registry)
	expect_true(state.resolution == null and state.pending_choice == null, "Reward queue resumes ordinary refill and ends")
	expect_true(InvariantValidator.validate(state, registry).is_valid, "Completed real board and acquired Relic save legally")
	return true


func settlement_milestone_before_threshold() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _chain(registry, TYPE.SETTLEMENT, 7)
	_close(state, registry, TYPE.SETTLEMENT, 7)
	expect_true(state.features.tracks.values[DomainTypes.TrackType.POPULATION] >= 20, "Real Settlement base/support scoring crosses Population 20")
	expect_equal(state.pending_choice.kind, &"relic_offer", "Milestone acquisition precedes crossed threshold")
	expect_true(state.rewards.threshold_flags.is_empty(), "Threshold queue has not interrupted milestone reward")
	assert(RulesEngine.execute(state, registry, ResolveRewardCommand.new(state.pending_choice.choice_id, 0)).is_valid)
	expect_equal(state.pending_choice.kind, &"tile_reward", "Only after Relic acquisition does Population-20 offer begin")
	expect_equal(RelicRules.equipped(state).size(), 1, "Milestone Relic is active for later rewards")
	expect_true(state.rewards.threshold_flags.has("0:20"), "Crossed threshold now marked once")
	_resolve_rewards(state, registry)
	return true


func milestone_queue_save_load() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _chain(registry, TYPE.SETTLEMENT, 7)
	_close(state, registry, TYPE.SETTLEMENT, 7)
	var source: String = StateNormalizer.fingerprint(state)
	var restored: RunState = F.load_copy(F.load_copy(state, registry), registry)
	expect_equal(StateNormalizer.fingerprint(restored), source, "Repeated milestone choice load changes no scoring, history, RNG or refill")
	for candidate: RunState in [state, restored]:
		assert(RulesEngine.execute(candidate, registry, ResolveRewardCommand.new(candidate.pending_choice.choice_id, 0)).is_valid)
	expect_equal(StateNormalizer.fingerprint(restored), StateNormalizer.fingerprint(state), "Same milestone selection yields identical next threshold offer")
	restored = F.load_copy(restored, registry)
	_resolve_rewards(state, registry)
	_resolve_rewards(restored, registry)
	expect_equal(StateNormalizer.fingerprint(restored), StateNormalizer.fingerprint(state), "Both continuations score/reward/refill exactly once")
	return true


func forest_milestone_once_across_two_features() -> bool:
	var registry: ContentRegistry = F.content()
	# Two ten-tile forests need Act II's placement budget; no Act transition is exercised.
	var state: RunState = F.Previous.Previous.create(registry, 2)
	for index: int in range(1, 9):
		F.Geography.add(state, registry, &"tile.forest_belt", Vector2i(-index, 0), 1)
	# Separate second woodland attaches to a Field side of the first belt.
	F.Geography.add(state, registry, &"tile.forest_edge", Vector2i(-1, 1), 2)
	for index: int in range(2, 10):
		F.Geography.add(state, registry, &"tile.forest_belt", Vector2i(-1, index))
	state = F.activate(state)
	_close(state, registry, TYPE.FOREST, 9)
	_resolve_rewards(state, registry)
	var earned_before: int = _milestone_events(state)
	F.play(state, registry, &"tile.forest_edge", Vector2i(-1, 10))
	F.decline_assignment(state, registry)
	expect_equal(_milestone_events(state), earned_before, "Second genuinely completed ten-tile Forest cannot reaward once-per-run milestone")
	expect_equal(state.rewards.milestone_flags, [&"forest"], "Exactly one Forest flag")
	_resolve_rewards(state, registry)
	expect_true(InvariantValidator.validate(state, registry).is_valid, "Both physical Forest completions remain coherent")
	return true


func road_network_milestone_on_recompletion() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = TradeFixture.chain(registry, 5)
	TradeFixture.reopen_first_road(state, registry)
	state = F.activate(state)
	expect_true(state.rewards.milestone_flags.is_empty(), "Existing large network is not a completion event")
	F.play(state, registry, &"tile.road_end", Vector2i(1, -1), 2)
	F.decline_assignment(state, registry)
	expect_true(state.rewards.milestone_flags.has(&"road"), "Genuine recompletion earns previously unearned current-network milestone")
	expect_equal(state.pending_choice.kind, &"relic_offer", "Road milestone uses ordinary persisted Relic offer")
	var record: FeatureCompletionRecord = state.features.completions.back()
	expect_true(record.network_settlement_ids.size() >= 5, "Authoritative full network, not physical Road size, qualifies")
	_resolve_rewards(state, registry)
	return true


func _milestone_events(state: RunState) -> int:
	var count: int = 0
	for event: Dictionary in state.rewards.history:
		if event["kind"] == "milestone_earned":
			count += 1
	return count
