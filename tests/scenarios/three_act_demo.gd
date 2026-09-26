extends SceneTree
## Complete command-driven three-Act demonstrations; no presentation scenes.

const Scenarios = preload("res://tests/integration/phase_nine_full_run_tests.gd")
const Fixture = preload("res://tests/fixtures/phase_nine_factory.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_cmdline_user_args().has("--find-seed"):
		_find_seed()
		return
	var suite: RefCounted = Scenarios.new()
	var completed: int = 0
	for scenario: Callable in suite.tests():
		if scenario.call() == true:
			completed += 1
		else:
			suite.failures.append("Scenario did not finish: " + scenario.get_method())
		print("PHASE 9 SCENARIO: ", scenario.get_method())
	for outcome: int in range(3):
		var run: Dictionary = suite._run(outcome)
		var state: RunState = run["state"]
		print("FULL RUN: ", state.final_result.victory_result,
			" seed=", state.original_seed, " placements=", run["act_counts"],
			" score=", state.final_result.score, " tracks=", state.final_result.tracks,
			" fingerprint=", run["fingerprint"])
		print("CHARTERS: ", state.charters.act_one_id, " / ", state.charters.act_two_id,
			" / ", state.charters.grand_id, " reveal=Act ", state.charters.exact_revealed_act,
			" placement ", state.charters.exact_revealed_index,
			" consequence choices=", run["choices"].size())
		print("FINAL STATISTICS: retained keys=", state.final_result.statistics.keys(),
			" evaluations=", state.charters.evaluations.size(), " training pieces=", state.specialists.pieces.size())
		var inspection: Dictionary = PhaseNineDebug.inspect(state, Fixture.content(), true)
		print("ACT INSPECTOR: unlocked=", inspection["unlocked_act"],
			" seed batches=", inspection["seed_history"].size(),
			" eligible designs=", inspection["eligible_tiles"].size(),
			" progress=", inspection["grand_charter"].get("progress", {}))
	for failure: String in suite.failures:
		printerr("FAIL: " + failure)
	if suite.failures.is_empty():
		print("DEMO RESULT: %d Phase-9 integration scenarios passed; 5 complete three-Act runs (failure, victory, exemplary, deterministic replay, save/load replay), 330 normal placements." % completed)
	quit(0 if suite.failures.is_empty() else 1)


func _find_seed() -> void:
	var registry: ContentRegistry = Fixture.content()
	for seed_value: int in range(1, 300):
		var initial: RunState = HomesteadRunFactory.create(seed_value, registry)
		if initial.charters.act_one_id != &"charter.a1_living_landscape":
			continue
		assert(RulesEngine.execute(initial, registry, RequestSpecialistTrainingCommand.new(initial.specialists.pieces[0].piece_id)).is_valid)
		if not Fixture.naturalist_offered(initial):
			continue
		var run: Dictionary = Fixture.scripted(registry, seed_value, 0, false, 1)
		var state: RunState = run["state"]
		print("SEED CANDIDATE: ", seed_value, " ActII=", state.charters.act_two_id, " Grand=", state.charters.grand_id)
		if state.charters.grand_id == &"charter.grand_living_heritage" \
				and state.charters.act_two_id == &"charter.a2_stewardship_of_land":
			print("FOUND COMPLETE-RUN SEED: ", seed_value)
			quit(0)
			return
	printerr("No matching deterministic integration seed in the bounded search")
	quit(1)
