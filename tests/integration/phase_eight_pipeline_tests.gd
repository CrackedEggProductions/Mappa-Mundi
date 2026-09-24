extends "res://tests/framework/test_suite.gd"
## Real command continuations: shared snapshots, same-piece Relay and reward refill.

const F = preload("res://tests/fixtures/phase_eight_factory.gd")
const TYPE = DomainTypes.FeatureType


func tests() -> Array[Callable]:
	return [relay_accepts_same_piece, relay_decline_leaves_available,
		relay_excludes_occupied_target, relay_trained_role_filter,
		relay_pending_round_trip, relay_invalid_choice_atomic,
		relay_forged_return_rejected, ordinary_diagonal_not_touching,
		same_tile_requires_declared_relationship, relay_no_relic_preserves_phase_seven,
		completion_relic_children_follow_returns, reward_chain_before_hand_refill,
		training_fallback_resolves_real_tile_reward, legacy_suppression_retains_unpaid_history,
		legacy_multiplier_round_trip, enclosure_relay_round_trip, simultaneous_relay_occupancy,
		relay_revision_exhaustion_atomic, reward_revision_exhaustion_atomic, altered_pending_relic_facts_rejected]


func _relay(registry: ContentRegistry, role: StringName = &"", historic: bool = false) -> RunState:
	var state: RunState = F.create(registry)
	F.equip(state, registry, &"relic.stewards_relay")
	if historic:
		F.equip(state, registry, &"relic.historic_routes")
	F.play(state, registry, &"tile.straight_road", Vector2i.RIGHT, 1)
	F.Previous.assign(state, registry, TYPE.ROAD)
	if not role.is_empty():
		var piece: SpecialistPieceState = state.specialists.pieces[0]
		assert(RulesEngine.execute(state, registry, RequestSpecialistTrainingCommand.new(piece.piece_id)).is_valid)
		assert(RulesEngine.execute(state, registry, ResolveSpecialistTrainingCommand.new(state.pending_choice.choice_id, role)).is_valid)
	F.play(state, registry, &"tile.settlement_gate", Vector2i(2, 0), 2)
	return state # Normal optional local assignment still precedes Road completion.


func relay_accepts_same_piece() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _relay(registry)
	var id: int = state.specialists.pieces[0].piece_id
	F.decline_assignment(state, registry)
	expect_equal(state.pending_choice.kind, &"specialist_relay", "Returned piece receives explicit Relay opportunity")
	var selected: Dictionary = state.pending_choice.options[0]
	expect_equal(selected["piece_id"], id, "Only the same returning piece is offered")
	expect_true(RulesEngine.execute(state, registry, ResolveRelayCommand.new(state.pending_choice.choice_id, 0)).is_valid, "Accept legal Relay")
	expect_equal(state.specialists.pieces[0].status, SpecialistPieceState.Status.ASSIGNED, "Relay reassigns immediately")
	expect_equal(state.specialists.pieces[0].assigned_target_id, selected["target_id"], "Target follows selected mechanical feature")
	_valid(state, registry)
	return true


func relay_decline_leaves_available() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _relay(registry)
	F.decline_assignment(state, registry)
	expect_true(RulesEngine.execute(state, registry, ResolveRelayCommand.new(state.pending_choice.choice_id)).is_valid, "Decline Relay")
	expect_equal(state.specialists.pieces[0].status, SpecialistPieceState.Status.AVAILABLE, "Declined piece stays available")
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Normal placement finishes after decline")
	return true


func relay_excludes_occupied_target() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _relay(registry)
	var city: int = F.Previous.member(state, Vector2i(2, 0), TYPE.SETTLEMENT)
	F.Previous.assign(state, registry, TYPE.SETTLEMENT, city, 1)
	if state.pending_choice != null:
		for option: Dictionary in state.pending_choice.options:
			expect_true(option["target_id"] != city, "Already assigned connected feature excluded from Relay")
	return true


func relay_trained_role_filter() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _relay(registry, &"specialist.merchant")
	F.decline_assignment(state, registry)
	if state.pending_choice != null:
		for option: Dictionary in state.pending_choice.options:
			expect_equal(option["target_type"], TYPE.ROAD, "Merchant Relay remains Road-only")
	else:
		expect_equal(state.specialists.pieces[0].status, 0, "No legal Road leaves Merchant available")
	return true


func relay_pending_round_trip() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _relay(registry)
	F.decline_assignment(state, registry)
	var rng: int = state.rng.operation_count
	var restored: RunState = F.load_copy(state, registry)
	expect_equal(StateNormalizer.fingerprint(restored), StateNormalizer.fingerprint(state), "Relay exact saved continuation")
	expect_equal(restored.rng.operation_count, rng, "Load does not reroll Relay")
	for copy: RunState in [state, restored]:
		assert(RulesEngine.execute(copy, registry, ResolveRelayCommand.new(copy.pending_choice.choice_id, 0)).is_valid)
	expect_equal(StateNormalizer.fingerprint(restored), StateNormalizer.fingerprint(state), "Same Relay resumes exactly once")
	return true


func relay_invalid_choice_atomic() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _relay(registry)
	F.decline_assignment(state, registry)
	var before: String = StateNormalizer.fingerprint(state)
	var result: ValidationResult = RulesEngine.execute(state, registry, ResolveRelayCommand.new(state.pending_choice.choice_id, 999))
	expect_true(not result.is_valid, "Unknown Relay option rejected")
	expect_equal(StateNormalizer.fingerprint(state), before, "No history, allocation or RNG on invalid Relay")
	return true


func relay_forged_return_rejected() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _relay(registry)
	F.decline_assignment(state, registry)
	state.pending_choice.context["returned"]["piece_id"] = state.specialists.pieces[1].piece_id
	state.resolution.context["relay_queue"][0] = state.pending_choice.context["returned"].duplicate(true)
	expect_true(not StewardRelayRules.valid_choice(state), "An available piece cannot forge a return from this completion")
	expect_true(not RunSerializer.serialize(state, registry).validation.is_valid, "Forged pending Relay is not a valid save")
	return true


func ordinary_diagonal_not_touching() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.Previous.Previous.create(registry)
	F.Geography.add(state, registry, &"tile.river_end", Vector2i.DOWN)
	F.Geography.add(state, registry, &"tile.hamlet_edge", Vector2i.ONE)
	F.activate(state)
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	var source: int = F.Previous.member(state, Vector2i.ZERO, TYPE.ROAD)
	var target: int = F.Previous.member(state, Vector2i.ONE, TYPE.SETTLEMENT)
	expect_true(not StewardRelayRules.touches(state, TYPE.ROAD, source, TYPE.SETTLEMENT, target, current), "Diagonal member tiles are not ordinary contact")
	return true


func same_tile_requires_declared_relationship() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	var road: int = F.Previous.member(state, Vector2i.ZERO, TYPE.ROAD)
	var city: int = F.Previous.member(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	var river: int = F.Previous.member(state, Vector2i.ZERO, TYPE.RIVER)
	expect_true(StewardRelayRules.touches(state, TYPE.ROAD, road, TYPE.SETTLEMENT, city, current), "Explicit founding Road/Settlement access counts")
	expect_true(not StewardRelayRules.touches(state, TYPE.ROAD, road, TYPE.RIVER, river, current), "Undeclared co-location does not count")
	return true


func relay_no_relic_preserves_phase_seven() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	F.play(state, registry, &"tile.straight_road", Vector2i.RIGHT, 1)
	F.Previous.assign(state, registry, TYPE.ROAD)
	F.play(state, registry, &"tile.settlement_gate", Vector2i(2, 0), 2)
	F.decline_assignment(state, registry)
	expect_true(state.pending_choice == null, "No Relay means no returned-piece opportunity")
	expect_equal(state.specialists.pieces[0].status, 0, "Piece available for a future placement")
	return true


func completion_relic_children_follow_returns() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _relay(registry, &"", true)
	F.decline_assignment(state, registry)
	expect_equal(state.pending_choice.kind, &"specialist_relay", "Return pauses for Relay before Relic numerical effects")
	expect_equal(state.features.tracks.values[2], 0, "Historic Routes waits for return/Relay handling")
	assert(RulesEngine.execute(state, registry, ResolveRelayCommand.new(state.pending_choice.choice_id)).is_valid)
	var returned: int = -1
	var triggered: int = -1
	for index: int in range(state.features.history.size()):
		var event: FeatureHistoryRecord = state.features.history[index]
		if event.kind == &"specialist_returned":
			returned = index
		if event.kind == &"relic_triggered":
			triggered = index
	expect_true(returned >= 0 and triggered > returned, "FIFO Relic effect follows Specialist return")
	expect_equal(state.features.tracks.values[2], 1, "Only original Act-I Road component earns Historic Routes")
	_valid(state, registry)
	return true


func reward_chain_before_hand_refill() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	for x: int in range(1, 19):
		F.play(state, registry, &"tile.straight_road", Vector2i(x, 0), 1)
		F.decline_assignment(state, registry)
	F.play(state, registry, &"tile.road_end", Vector2i(19, 0), 3)
	F.decline_assignment(state, registry)
	expect_true(state.pending_choice != null, "Crossed Trade 20 produces a reward")
	expect_equal(state.pending_choice.kind, &"tile_reward", "First threshold is a Tile Reward")
	var slot: int = state.expansion.pending_refill_index
	expect_true(slot >= 0 and state.expansion.hand[slot] == 0, "Ordinary refill waits behind the reward")
	var loaded: RunState = F.load_copy(state, registry)
	for copy: RunState in [state, loaded]:
		assert(RulesEngine.execute(copy, registry, ResolveRewardCommand.new(copy.pending_choice.choice_id, 0)).is_valid)
		expect_equal(copy.expansion.pending_refill_index, -1, "Reward then final refill completes once")
		expect_true(not copy.expansion.hand.has(0), "Reward copies available before hand replacement")
	expect_equal(StateNormalizer.fingerprint(state), StateNormalizer.fingerprint(loaded), "Saved reward resumes identical shuffle and refill")
	return true


func training_fallback_resolves_real_tile_reward() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	for piece: SpecialistPieceState in state.specialists.pieces:
		assert(RulesEngine.execute(state, registry, RequestSpecialistTrainingCommand.new(piece.piece_id)).is_valid)
		var role: StringName = StringName(state.pending_choice.options[0]["role_definition_id"])
		assert(RulesEngine.execute(state, registry, ResolveSpecialistTrainingCommand.new(state.pending_choice.choice_id, role)).is_valid)
	expect_true(RulesEngine.execute(state, registry, RequestSpecialistTrainingCommand.new()).is_valid, "Untrainable reward accepted through Phase-7 API")
	expect_equal(state.pending_choice.kind, &"tile_reward", "Deferred fallback now hands off to real reward system")
	expect_true(state.specialists.deferred_rewards.is_empty(), "Handoff consumed exactly once")
	var before: int = state.tile_copies.size()
	assert(RulesEngine.execute(state, registry, ResolveRewardCommand.new(state.pending_choice.choice_id, 0)).is_valid)
	expect_true(state.tile_copies.size() > before, "Fallback grants physical tile copies")
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Standalone training reward returns to turn input")
	_valid(state, registry)
	return true


func _suppressed_city(registry: ContentRegistry) -> RunState:
	var state: RunState = F.create(registry)
	F.equip(state, registry, &"relic.one_great_city")
	F.Geography.add(state, registry, &"tile.settlement_throughway", Vector2i.UP)
	F.Geography.add(state, registry, &"tile.settlement_throughway", Vector2i(0, -2))
	F.Geography.add(state, registry, &"tile.road_end", Vector2i.RIGHT, 3)
	F.Geography.add(state, registry, &"tile.open_fields", Vector2i(1, -1))
	F.Geography.add(state, registry, &"tile.hamlet_edge", Vector2i(2, -1), 1)
	F.Geography.add(state, registry, &"tile.hamlet_edge", Vector2i(3, -1), 3)
	return state


func legacy_suppression_retains_unpaid_history() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _suppressed_city(registry)
	var city_id: int = F.Previous.member(state, Vector2i(2, -1), TYPE.SETTLEMENT)
	var city: FeatureLineageState = state.features.lineage(city_id)
	expect_true(city.completed, "Suppressed city still genuinely completes")
	expect_true(city.scored_component_ids.is_empty(), "Zero base payout does not consume unpaid eligibility")
	expect_true(F.Geography.rewrite(state, registry, Vector2i(2, -1), [4, 4, 0, 0]).is_valid, "Controlled genuine reopening")
	F.Geography.add(state, registry, &"tile.hamlet_edge", Vector2i(2, -2), 2)
	expect_equal(city.scored_component_ids.size(), 3, "Later largest tie pays all three previously unpaid tiles")
	var record: FeatureCompletionRecord = state.features.completions.back()
	expect_equal(record.base_multiplier, 2, "Qualifying genuine re-completion doubles only base")
	expect_equal(record.new_component_ids.size(), 3, "Suppressed prior members qualify for first payment")
	_valid(state, registry)
	return true


func legacy_multiplier_round_trip() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _suppressed_city(registry)
	var loaded: RunState = F.load_copy(state, registry)
	expect_equal(StateNormalizer.fingerprint(state), StateNormalizer.fingerprint(loaded), "Zero multiplier, paid history and completed state persist")
	expect_equal(loaded.features.completions.back().base_multiplier, 0, "Save retains why the latest completion paid zero")
	return true


func _valid(state: RunState, registry: ContentRegistry) -> void:
	var report: InvariantReport = InvariantValidator.validate(state, registry)
	expect_true(report.is_valid, report.describe())


func enclosure_relay_round_trip() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.Previous.Previous.create(registry)
	var center: Vector2i = F.Development.fields(state, registry, 7)
	F.activate(state)
	F.equip(state, registry, &"relic.stewards_relay")
	F.play(state, registry, &"tile.development.monastery", center)
	F.Previous.assign(state, registry, 4)
	F.play(state, registry, &"tile.forest_edge", center + Vector2i(-1, -1), 0)
	F.decline_assignment(state, registry)
	expect_equal(state.pending_choice.kind, &"specialist_relay", "Completed enclosure returns to its diagonal neighboring Forest")
	var restored: RunState = F.load_copy(state, registry)
	expect_equal(StateNormalizer.fingerprint(restored), StateNormalizer.fingerprint(state), "Enclosure source distinct from eighth-square placement survives save")
	assert(RulesEngine.execute(restored, registry, ResolveRelayCommand.new(restored.pending_choice.choice_id, 0)).is_valid)
	expect_equal(restored.specialists.pieces[0].assigned_target_type, TYPE.FOREST, "Generic enclosure Steward may Relay to eligible neighbor")
	_valid(restored, registry)
	return true


func simultaneous_relay_occupancy() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.Previous.Previous.create(registry)
	F.Geography.add(state, registry, &"tile.river_end", Vector2i.DOWN)
	F.Geography.add(state, registry, &"tile.hamlet_edge", Vector2i.ONE)
	F.activate(state)
	F.equip(state, registry, &"relic.stewards_relay")
	F.Previous.bind_for_fixture(state, registry, Vector2i.ZERO, TYPE.ROAD)
	F.Previous.bind_for_fixture(state, registry, Vector2i.ONE, TYPE.SETTLEMENT, 1)
	F.play(state, registry, &"tile.settlement_gate", Vector2i.RIGHT, 2)
	F.decline_assignment(state, registry)
	expect_equal(state.pending_choice.context["returned"]["piece_id"], state.specialists.pieces[0].piece_id, "Simultaneous returns use stable piece order")
	var target: int = F.Previous.member(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	var chosen: int = -1
	for index: int in range(state.pending_choice.options.size()):
		if state.pending_choice.options[index]["target_id"] == target:
			chosen = index
	assert(chosen >= 0, "Both completed features touch the unfinished founding Settlement")
	assert(RulesEngine.execute(state, registry, ResolveRelayCommand.new(state.pending_choice.choice_id, chosen)).is_valid)
	expect_equal(state.pending_choice.context["returned"]["piece_id"], state.specialists.pieces[1].piece_id, "Second return follows first decision")
	for option: Dictionary in state.pending_choice.options:
		expect_true(option["target_id"] != target, "Earlier Relay occupation excludes later target")
	var restored: RunState = F.load_copy(state, registry)
	for copy: RunState in [state, restored]:
		assert(RulesEngine.execute(copy, registry, ResolveRelayCommand.new(copy.pending_choice.choice_id)).is_valid)
	expect_equal(StateNormalizer.fingerprint(state), StateNormalizer.fingerprint(restored), "Reload between Relay choices preserves both returns and first assignment")
	return true


func relay_revision_exhaustion_atomic() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _relay(registry)
	F.decline_assignment(state, registry)
	state.expansion.state_revision = 9223372036854775807
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, registry, ResolveRelayCommand.new(state.pending_choice.choice_id)).is_valid, "Exhausted revision rejects Relay before mutation")
	expect_equal(StateNormalizer.fingerprint(state), before, "Rejected Relay cannot return, score or consume RNG")
	return true


func reward_revision_exhaustion_atomic() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	state.resolution = ResolutionState.new()
	state.resolution.stage = &"reward_queue"
	state.resolution.context["mode"] = "reward"
	RewardRules.enqueue(state, &"tile_reward")
	RewardRules.advance(state, registry)
	state.expansion.state_revision = 9223372036854775807
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, registry, ResolveRewardCommand.new(state.pending_choice.choice_id, 0)).is_valid, "Exhausted revision rejects reward before mutation")
	expect_equal(StateNormalizer.fingerprint(state), before, "Rejected reward cannot add copies or shuffle")
	return true


func altered_pending_relic_facts_rejected() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _relay(registry, &"", true)
	F.decline_assignment(state, registry)
	var returned: Dictionary = state.pending_choice.context["returned"]
	var key: String = String.num_int64(returned["target_id"])
	state.resolution.completion_snapshot["relics"]["feature_facts"][key]["act_one_road_count"] = 999
	expect_true(not RunSerializer.serialize(state, registry).validation.is_valid, "Pending Relic effects must match actual historical component ages")
	var text: String = JSON.stringify(RunSerializer.to_envelope(state))
	expect_true(not RunSerializer.deserialize(text, registry).validation.is_valid, "Edited saved snapshot cannot manufacture a later Relic payout")
	return true
