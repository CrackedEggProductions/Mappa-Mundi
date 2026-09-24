extends SceneTree
## Read-only diagnostics plus command-driven demonstrations; no presentation scene.

const Scenarios = preload("res://tests/integration/phase_eight_pipeline_tests.gd")
const Fixture = preload("res://tests/fixtures/phase_eight_factory.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_trace_rewards()
	var suite: RefCounted = Scenarios.new()
	var completed: int = 0
	for scenario: Callable in suite.tests():
		if scenario.call() != true:
			suite.failures.append("Scenario did not finish: " + scenario.get_method())
		else:
			completed += 1
		print("PHASE 8 SCENARIO: ", scenario.get_method())
	for failure: String in suite.failures:
		printerr("FAIL: " + failure)
	if suite.failures.is_empty():
		print("DEMO RESULT: %d Phase-8 scenarios passed: Relay, immutable snapshots, base-only Legacy scoring, unpaid history, reward-before-refill and exact save continuation." % completed)
	quit(0 if suite.failures.is_empty() else 1)


func _trace_rewards() -> void:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = HomesteadRunFactory.create(808080, content)
	Fixture.equip(state, content, &"relic.boundary_stones")
	Fixture.equip(state, content, &"relic.ferry_rights")
	print("RELIC CAPACITY: ", state.relics.capacity)
	for relic: RelicInstanceState in state.relics.instances:
		print("RELIC: ", relic.definition_id, " runtime=", relic.runtime_id,
			" slot=", relic.equipped_slot, " acquired_act=", relic.acquired_act,
			" order=", relic.acquisition_order, " use_epoch=", relic.use_act,
			" uses_remaining=", relic.uses_remaining)
	print("CURRENT MODIFIERS: ", RelicRules.capture(state, TopologyService.rebuild(state)))
	print("FERRY ACCESS LINKS: ", TradeNetworkService.access_links(state))
	state.resolution = ResolutionState.new()
	state.resolution.stage = &"reward_queue"
	state.resolution.context["mode"] = "reward"
	RewardRules.enqueue(state, &"tile_reward")
	RewardRules.advance(state, content)
	print("PENDING REWARD: ", state.pending_choice.kind, " exact options=", state.pending_choice.options)
	print("THRESHOLDS: ", state.rewards.threshold_flags, " MILESTONES: ", state.rewards.milestone_flags,
		" REMAINING QUEUE: ", state.rewards.queue)
	var restored: RunState = Fixture.load_copy(state, content)
	print("LOAD PRESERVES RNG: ", restored.current_rng_state == state.current_rng_state,
		" operations=", restored.rng.operation_count)
	assert(RulesEngine.execute(restored, content, ResolveRewardCommand.new(restored.pending_choice.choice_id, 0)).is_valid)
	for event: Dictionary in restored.rewards.history:
		if event.get("kind") == "reward_tiles_acquired":
			print("PHYSICAL REWARD COPIES: ", event["details"])
	print("RELIC ACQUISITION HISTORY: ", restored.relics.history)
