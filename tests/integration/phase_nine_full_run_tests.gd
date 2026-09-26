extends "res://tests/framework/test_suite.gd"
## Complete real-command runs; controlled source acquisition is documented in F.

const F = preload("res://tests/fixtures/phase_nine_factory.gd")
const RUN_SEED: int = 212
var _runs: Dictionary = {}


func tests() -> Array[Callable]:
	return [completed_failure, completed_victory, completed_exemplary,
		deterministic_full_replay, every_boundary_round_trip_replay,
		midpoint_waits_for_real_assignment, exact_seeding_across_full_run,
		final_rewards_before_no_refill, completed_run_rejects_commands,
		genuine_completion_history, completed_result_round_trip,
		persistent_civilization, final_statistics, full_charter_reward_chains]


func _run(outcome: int = 0, restore: bool = false) -> Dictionary:
	var key: String = "%d:%s" % [outcome, str(restore)]
	if not _runs.has(key):
		_runs[key] = F.scripted(F.content(), RUN_SEED, outcome, restore)
	return _runs[key]


func completed_failure() -> bool:
	var run: Dictionary = _run()
	var state: RunState = run["state"]
	expect_equal(state.phase, GamePhase.Type.RUN_COMPLETE, "66 authoritative placements finish the run")
	expect_equal(run["act_counts"], [18, 22, 26], "Each Act uses its canonical normal-placement count")
	expect_equal(run["commands"].size(), 66, "No transition bypass replaces a normal command")
	expect_equal(state.final_result.victory_result, &"completed_no_victory", "Failed Grand Charter is a scored completed run")
	expect_equal(state.final_result.grand_charter_result, &"failed", "Grand failure recorded separately")
	expect_true(state.final_result.score > 0, "Failure does not zero the final score")
	expect_equal(state.charters.grand_id, &"charter.grand_living_heritage", "Fixture uses an actually randomized Grand selection")
	return true


func completed_victory() -> bool:
	var state: RunState = _run(1)["state"]
	expect_equal(state.final_result.victory_result, &"victory", "True forest, river and enclosure history supports Victory")
	expect_equal(state.final_result.grand_charter_result, &"fulfilled", "Fulfillment without exceed retained")
	expect_equal(state.final_result.score, _track_sum(state), "Victory score is exactly the four uncapped Tracks")
	return true


func completed_exemplary() -> bool:
	var state: RunState = _run(2)["state"]
	expect_equal(state.final_result.victory_result, &"exemplary_victory", "Additional Ecology/Culture earns Exemplary Victory")
	expect_equal(state.final_result.grand_charter_result, &"exceeded", "Grand exceeded recorded")
	expect_equal(state.final_result.score, _track_sum(state), "Exemplary outcome applies no numeric multiplier")
	return true


func deterministic_full_replay() -> bool:
	var first: Dictionary = _run(1)
	var second: Dictionary = F.scripted(F.content(), RUN_SEED, 1)
	expect_equal(second["choices"], first["choices"], "Same seed/choices preserve every reward offer")
	expect_equal(second["turns"], first["turns"], "Charters, hand draws and RNG operations reproduce across all 66 placements")
	expect_equal(second["fingerprint"], first["fingerprint"], "Full board, histories, bag, Tracks and result fingerprint match")
	return true


func every_boundary_round_trip_replay() -> bool:
	var original: Dictionary = _run(1)
	var restored: Dictionary = _run(1, true)
	expect_true(restored["round_trips"] > 66, "Saves cover all stable turns plus actual PendingChoices")
	expect_equal(restored["choices"], original["choices"], "Reload does not reroll saved choices")
	expect_equal(restored["turns"], original["turns"], "Reload duplicates no seeding, reward, shuffle, refresh or refill")
	expect_equal(restored["fingerprint"], original["fingerprint"], "Repeated save/load is side-effect-free through complete run")
	return true


func midpoint_waits_for_real_assignment() -> bool:
	var run: Dictionary = _run()
	expect_true(not run["midpoint_pending"].is_empty(), "Placement 11 actually pauses for its local Specialist assignment")
	for revealed: bool in run["midpoint_pending"]:
		expect_true(not revealed, "Exact Grand remains hidden throughout placement-11 choices")
	for turn: Dictionary in run["turns"]:
		if turn["outgoing_act"] == 2 and turn["placement"] in [10, 11, 12]:
			expect_equal(turn["exact_revealed"], turn["placement"] >= 11,
				"Stable boundary reveals exactly after placement 11, before turn 12")
	var before_reveal_rng: int = -1
	for choice: Dictionary in run["choices"]:
		if choice["act"] == 2 and choice["placement"] == 11:
			before_reveal_rng = choice["rng_operations"]
	for turn: Dictionary in run["turns"]:
		if turn["outgoing_act"] == 2 and turn["placement"] == 11:
			expect_equal(turn["rng_operations"], before_reveal_rng, "Assignment and exact reveal consume no RNG")
	var state: RunState = run["state"]
	expect_equal(state.charters.exact_revealed_act, 2, "Reveal belongs to Act II")
	expect_equal(state.charters.exact_revealed_index, 11, "Reveal retains exact normal placement index")
	return true


func exact_seeding_across_full_run() -> bool:
	var state: RunState = _run()["state"]
	var seeded: Dictionary = {}
	for copy: TileCopyState in state.tile_copies:
		if String(copy.acquisition_source).begins_with("act_transition"):
			var key: String = "%d:%s" % [copy.acquired_act, copy.definition_id]
			seeded[key] = int(seeded.get(key, 0)) + 1
	var expected: Dictionary = {}
	for id: String in ["market", "port", "town_square", "abbey"]:
		expected["2:tile.development." + id] = 2
	expected["2:tile.transformation.urban_expansion"] = 2
	expected["3:tile.transformation.bridge"] = 2
	expected["3:tile.transformation.rewilding"] = 2
	expected["3:tile.development.grand_market"] = 2
	expect_equal(seeded, expected, "Exactly ten Act-II and six Act-III identified seed copies survive full run")
	return true


func final_rewards_before_no_refill() -> bool:
	var run: Dictionary = _run(2)
	var final_choices: int = 0
	for choice: Dictionary in run["choices"]:
		if choice["act"] == 3 and choice["placement"] == 26:
			final_choices += 1
	expect_true(final_choices > 0, "Final placement resolves real threshold and Relic choices")
	var state: RunState = run["state"]
	expect_equal(state.expansion.hand[0], 0, "Final active-hand slot remains empty after all rewards")
	expect_equal(state.expansion.pending_refill_index, -1, "No orphaned final refill remains")
	expect_true(state.act_transition == null, "Act III does not create an ordinary transition")
	expect_true(state.pending_choice == null and state.resolution == null, "Finalization follows settled consequence queues")
	return true


func completed_run_rejects_commands() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = _run()["state"]
	var before: String = StateNormalizer.fingerprint(state)
	var occupied: int = state.expansion.hand[1]
	var commands: Array[PlayerCommand] = [SurveyTileCommand.new(occupied),
		ReserveTileCommand.new(occupied), ResolveRewardCommand.new(1, 0),
		ResolveSpecialistAssignmentCommand.new(1, 0, -1, 0, true),
		PlaceTileCommand.new(occupied, TileLocationState.Kind.ACTIVE_HAND, Vector2i(43, 0), 0)]
	for command: PlayerCommand in commands:
		expect_true(not RulesEngine.execute(state, registry, command).is_valid, "RUN_COMPLETE rejects ordinary gameplay mutation")
		expect_equal(StateNormalizer.fingerprint(state), before, "Rejected post-run commands have zero state/RNG/history effects")
	return true


func genuine_completion_history() -> bool:
	var state: RunState = _run()["state"]
	var types: Dictionary = {}
	var monastery: bool = false
	for record: FeatureCompletionRecord in state.features.completions:
		if record.feature_type >= 0:
			types[record.feature_type] = maxi(int(types.get(record.feature_type, 0)), record.total_size)
		if record.enclosure_id != 0:
			monastery = true
	expect_equal(types.get(DomainTypes.FeatureType.FOREST), 9, "Forest history originates in nine connected, really completed tiles")
	expect_equal(types.get(DomainTypes.FeatureType.RIVER), 9, "River history originates in nine connected, really completed tiles")
	expect_true(monastery, "Real surrounding placements complete the Monastery enclosure")
	expect_equal(state.charters.evaluations.size(), 3, "Each of two ordinary Charters and one Grand evaluates once")
	return true


func completed_result_round_trip() -> bool:
	var registry: ContentRegistry = F.content()
	for outcome: int in range(3):
		var state: RunState = _run(outcome)["state"]
		var before: String = StateNormalizer.fingerprint(state)
		for count: int in range(3):
			state = F.round_trip(state, registry)
			expect_equal(StateNormalizer.fingerprint(state), before, "Completed result reload is pure for each outcome")
			expect_equal(state.phase, GamePhase.Type.RUN_COMPLETE, "Completed save cannot restart gameplay")
			expect_equal(state.expansion.hand[0], 0, "Completed save cannot refill final hand hole")
	return true


func persistent_civilization() -> bool:
	var run: Dictionary = _run(1)
	var transitions: Array = run["transition_entries"]
	expect_equal(transitions.size(), 2, "Exactly two Act transitions")
	expect_equal(transitions[0]["capacity"], 4, "Act II capacity refreshes after outgoing consequences")
	expect_equal(transitions[1]["capacity"], 5, "Act III capacity refreshes after outgoing consequences")
	for transition: Dictionary in transitions:
		expect_equal(transition["survey_charges"], 1, "Incoming Act has exactly one fresh Survey")
		expect_true(not transition["hand"].has(0), "Outgoing hand replacement occurs before incoming input")
	expect_true(transitions[1]["board_size"] > transitions[0]["board_size"], "One board accumulates across Acts")
	expect_equal(transitions[1]["grand_id"], transitions[0]["grand_id"], "Entering Act III neither selects nor replaces Grand Charter")
	var state: RunState = run["state"]
	expect_equal(state.expansion.board.cells.size(), 61, "Founding plus 60 Expansion commands, with six Development/Upgrade overlays")
	expect_equal(state.charters.completed_act_placements, [18, 22, 26], "Historical Act counters retained")
	return true


func final_statistics() -> bool:
	var state: RunState = _run(1)["state"]
	var stats: Dictionary = state.final_result.statistics
	expect_equal(stats["run_seed"], RUN_SEED, "Original seed retained")
	expect_equal(stats["final_total_score"], _track_sum(state), "Statistics retain actual uncapped score")
	expect_equal(stats["largest_settlement_established"], 2, "Settlement historical record retained")
	expect_equal(stats["longest_road_completed"], 2, "Road historical record retained")
	expect_equal(stats["largest_forest_completed"], 9, "Forest historical record retained")
	expect_equal(stats["longest_river_completed"], 9, "River historical record retained")
	expect_equal(stats["charters"].size(), 3, "Selected ordinary and Grand results retained structurally")
	for key: String in ["relics_acquired", "relics_equipped", "relics_replaced", "relic_history", "specialist_training"]:
		expect_true(stats.has(key), "Final statistics include " + key)
	return true


func _track_sum(state: RunState) -> int:
	var total: int = 0
	for value: int in state.features.tracks.values:
		total += value
	return total


func full_charter_reward_chains() -> bool:
	var run: Dictionary = _run(1)
	var state: RunState = run["state"]
	var first: Dictionary = state.charters.evaluations[0]
	var second: Dictionary = state.charters.evaluations[1]
	expect_equal(first["overall_state"], &"fulfilled", "Actual Act-I Charter succeeds on genuine completion history")
	expect_equal(first["rewards_generated"], [&"tile_reward"], "Act-I fulfillment creates its normal Tile Reward")
	expect_equal(second["overall_state"], &"exceeded", "Actual Act-II Charter exceeds through genuine Forest scoring")
	expect_equal(second["rewards_generated"], [&"relic_offer", &"tile_reward", &"major_reward"], "Act-II exceeded reward order retained")
	expect_true(not first["rewards_resolved"].is_empty() and not second["rewards_resolved"].is_empty(), "Both transitions persist their real resolved reward chains")
	for choice: Dictionary in run["choices"]:
		if choice["in_transition"]:
			expect_equal(choice["capacity"], 2 if choice["act"] == 1 else 4, "Outgoing Charter choices use outgoing Relic capacity")
	return true
