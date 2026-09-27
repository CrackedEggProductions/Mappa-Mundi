extends "res://tests/framework/test_suite.gd"

const F = preload("res://tests/fixtures/phase_nine_factory.gd")


func tests() -> Array[Callable]:
	return [starter_waits_for_choice, starter_rng_order, starter_exact_one_copy,
		starter_copy_can_enter_opening_hand, starter_round_trip_is_inert,
		starter_replay_matches, invalid_choice_is_atomic, stale_choice_is_atomic,
		duplicate_command_is_atomic, altered_offer_rejected, altered_context_rejected,
		orphan_draft_copy_rejected, cadence_counts, bonus_does_not_increment_cadence,
		cadence_waits_before_refill, reserve_cadence_needs_no_refill,
		all_classes_grant_one, chosen_design_remains_eligible]


func starter_waits_for_choice() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(19, content)
	expect_equal(state.phase, GamePhase.Type.PENDING_CHOICE, "Setup waits for a real player choice")
	expect_equal(state.pending_choice.kind, &"tile_draft", "Typed Tile Draft")
	expect_equal(state.pending_choice.context["draft_type"], "starter", "Starter subtype")
	expect_true(state.charters.act_one_id != &"", "Charter is already selected and visible")
	expect_equal(state.expansion.hand, [0, 0, 0], "No opening draw precedes the choice")
	expect_equal(state.expansion.bag.size(), 18, "Only fixed core exists before acquisition")
	expect_equal(state.pending_choice.options.size(), 3, "Three distinct directional designs")
	var ids: Array[String] = []
	for option: Dictionary in state.pending_choice.options:
		expect_true(not ids.has(option["definition_id"]), "Offer designs distinct")
		ids.append(option["definition_id"])
		expect_true(content.get_config().starter_draft_pool.has(StringName(option["definition_id"])), "Directional pool only")
	return true


func starter_rng_order() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(19, content)
	# Environment uses one path selection; Charter uses one; offer samples three.
	expect_equal(state.rng.operation_count, 5, "No initial bag shuffle before Starter Draft")
	var copied: Array[int] = state.expansion.bag.duplicate()
	copied.append(state.next_runtime_id)
	var expected: RunRNG = RunRNG.from_snapshot(state.original_seed, state.rng.current_state, state.rng.operation_count)
	var shuffled: Array[int] = expected.shuffled_ids(copied, &"tile_draft_bag_shuffle")
	_resolve(state, content)
	expect_equal(state.expansion.hand, shuffled.slice(0, 3), "Opening draw follows chosen copy and full shuffle")
	expect_equal(state.expansion.bag, shuffled.slice(3), "Whole remaining bag retains exact shuffled order")
	expect_equal(state.rng.current_state, expected.current_state, "Exactly one canonical shuffle")
	return true


func starter_exact_one_copy() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(19, content)
	var before: int = state.tile_copies.size()
	var offered: Array[Dictionary] = state.pending_choice.options.duplicate(true)
	_resolve(state, content)
	expect_equal(state.tile_copies.size(), before + 1, "Exactly one physical copy")
	expect_equal(state.expansion.bag.size() + state.expansion.hand.size(), 19, "Nineteen player copies before any placement")
	var draft: TileCopyState = state.tile_copies.back()
	expect_equal(String(draft.definition_id), offered[0]["definition_id"], "Chosen design created")
	expect_equal(draft.acquisition_source, &"starter_draft", "Explicit acquisition source")
	expect_equal(draft.acquired_act, 1, "Act-I acquisition")
	expect_true(InvariantValidator.validate(state, content).is_valid, "Unique physical identity and audit are valid")
	return true


func starter_copy_can_enter_opening_hand() -> bool:
	var content: ContentRegistry = F.content()
	var found: bool = false
	for seed_value: int in range(40):
		var state: RunState = HomesteadRunFactory.create(seed_value, content)
		var id: int = state.next_runtime_id
		_resolve(state, content)
		if state.expansion.hand.has(id):
			found = true
			break
	expect_true(found, "A chosen Starter copy can become an opening draw")
	return true


func starter_round_trip_is_inert() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(19, content)
	var fingerprint: String = StateNormalizer.fingerprint(state)
	for repeat: int in range(4):
		state = F.round_trip(state, content)
		expect_equal(StateNormalizer.fingerprint(state), fingerprint, "No load RNG, reroll, copy or hand draw")
	_resolve(state, content)
	expect_equal(state.expansion.bag.size(), 16, "Exactly one resolution after repeated loads")
	return true


func starter_replay_matches() -> bool:
	var content: ContentRegistry = F.content()
	var a: RunState = HomesteadRunFactory.create(22, content)
	var b: RunState = HomesteadRunFactory.create(22, content)
	expect_equal(a.pending_choice.options, b.pending_choice.options, "Same seed exact display order")
	_resolve(a, content)
	_resolve(b, content)
	expect_equal(StateNormalizer.fingerprint(a), StateNormalizer.fingerprint(b), "Choice and bag continuation deterministic")
	return true


func invalid_choice_is_atomic() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(22, content)
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, content, ResolveTileDraftCommand.new(state.pending_choice.choice_id, 3)).is_valid, "Out-of-offer option rejected")
	expect_equal(StateNormalizer.fingerprint(state), before, "Invalid input consumes no RNG or IDs")
	return true


func stale_choice_is_atomic() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(22, content)
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, content, ResolveTileDraftCommand.new(state.pending_choice.choice_id, 0, 99)).is_valid, "Stale revision rejected")
	expect_equal(StateNormalizer.fingerprint(state), before, "Stale input is atomic")
	return true


func duplicate_command_is_atomic() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(22, content)
	var command: ResolveTileDraftCommand = ResolveTileDraftCommand.new(state.pending_choice.choice_id, 0)
	expect_true(RulesEngine.execute(state, content, command).is_valid, "First choice resolves")
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, content, command).is_valid, "Duplicate cannot acquire again")
	expect_equal(StateNormalizer.fingerprint(state), before, "Duplicate is atomic")
	return true


func altered_offer_rejected() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(22, content)
	state.pending_choice.options.reverse()
	expect_true(not InvariantValidator.validate(state, content).is_valid, "Saved offer order cannot diverge from audit")
	return true


func altered_context_rejected() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(22, content)
	state.pending_choice.context["draft_type"] = "act_entry"
	expect_true(not InvariantValidator.validate(state, content).is_valid, "Wrong setup continuation rejected")
	return true


func orphan_draft_copy_rejected() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.started(content)
	state.expansion.bag.append(PhysicalTileRules.acquire(state, &"tile.forest_edge", &"cadence_draft", TileLocationState.Kind.BAG))
	expect_true(not InvariantValidator.validate(state, content).is_valid, "Unaudited acquisition rejected")
	return true


func cadence_counts() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.started(content)
	var counts: Array[int] = []
	for act: int in range(1, 4):
		state.expansion.current_act = act
		var count: int = 0
		for placement: int in range(1, content.get_config().act_placement_limits[act - 1] + 1):
			state.expansion.normal_placements = placement
			var due: bool = TileDraftService.cadence_due(state, content.get_config())
			expect_equal(due, placement % 2 == 0 and not (act == 3 and placement == 26), "Normal placement cadence with final exception")
			count += int(due)
		counts.append(count)
	expect_equal(counts, [9, 11, 12], "Exact per-Act cadence counts")
	return true


func bonus_does_not_increment_cadence() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.started(content)
	state.expansion.normal_placements = 1
	state.charters.bonus_active = true
	expect_true(not TileDraftService.cadence_due(state, content.get_config()), "Bonus does not advance normal count")
	state.charters.bonus_active = false
	return true


func cadence_waits_before_refill() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.started(content)
	# A stable post-consequence fixture preserves physical identity while emptying one hand slot.
	var returned: int = state.expansion.hand[0]
	state.expansion.hand[0] = 0
	state.expansion.bag.append(returned)
	PhysicalTileRules.set_location(state, returned, TileLocationState.Kind.BAG)
	state.expansion.pending_refill_index = 0
	state.expansion.normal_placements = 2
	RulesEngine._finish_placement(state, content)
	expect_equal(state.pending_choice.kind, &"tile_draft", "Draft precedes pending refill")
	expect_equal(state.expansion.hand[0], 0, "Slot remains empty while choosing")
	var before: int = state.tile_copies.size()
	# Direct primitive isolates exact copy/shuffle ordering; normal command path covered by full runs.
	TileDraftService.execute_command(state, ResolveTileDraftCommand.new(state.pending_choice.choice_id, 0))
	var next_copy: int = state.expansion.bag[0]
	RulesEngine._finish_placement(state, content)
	expect_equal(state.tile_copies.size(), before + 1, "One cadence copy")
	expect_equal(state.expansion.hand[0], next_copy, "Refill draws after draft shuffle")
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Completed ledger prevents repeat draft")
	return true


func reserve_cadence_needs_no_refill() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.started(content)
	state.expansion.normal_placements = 2
	var hand: Array[int] = state.expansion.hand.duplicate()
	RulesEngine._finish_placement(state, content)
	var operations: int = state.rng.operation_count
	TileDraftService.execute_command(state, ResolveTileDraftCommand.new(state.pending_choice.choice_id, 0))
	RulesEngine._finish_placement(state, content)
	expect_equal(state.rng.operation_count, operations + 1, "A draft shuffles even without a refill")
	expect_equal(state.expansion.hand, hand, "Reserve-origin boundary leaves full hand alone")
	return true


func all_classes_grant_one() -> bool:
	var content: ContentRegistry = F.content()
	for id: StringName in [&"tile.forest_edge", &"tile.woodland_road", &"tile.development.market", &"tile.development.abbey", &"tile.transformation.bridge"]:
		var state: RunState = F.started(content)
		state.expansion.current_act = 3
		state.pending_choice = PendingChoice.new()
		state.pending_choice.choice_id = state.id_allocator.allocate()
		state.pending_choice.kind = &"tile_draft"
		state.pending_choice.context = {"draft_type": "cadence", "act": 3, "placement_index": 2, "draft_sequence": 2}
		state.pending_choice.options = [{"definition_id": String(id)}]
		var before: int = state.tile_copies.size()
		TileDraftService.execute_command(state, ResolveTileDraftCommand.new(state.pending_choice.choice_id, 0))
		expect_equal(state.tile_copies.size(), before + 1, "Draft quantity ignores Normal Tile Reward class: " + String(id))
		expect_equal(state.tile_copies.back().acquired_act, 3, "Correct acquisition Act")
	return true


func chosen_design_remains_eligible() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(22, content)
	var chosen: StringName = StringName(state.pending_choice.options[0]["definition_id"])
	_resolve(state, content)
	expect_true(TileDraftService.pool(content, &"cadence", 1).has(chosen), "Acquisition never exhausts a design")
	return true


func _resolve(state: RunState, content: ContentRegistry) -> void:
	var result: ValidationResult = RulesEngine.execute(state, content, ResolveTileDraftCommand.new(state.pending_choice.choice_id, 0))
	expect_true(result.is_valid, result.user_message + str(result.debug_details))
