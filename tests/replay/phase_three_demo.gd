extends SceneTree
## Run after editor import. No UI, fixture actions are never player commands.

const Scenarios = preload("res://tests/integration/feature_scenario_tests.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scenarios: RefCounted = Scenarios.new()
	var cases: Array[StringName] = [&"deterministic_homestead_demo",
		&"simultaneous_batch_freezes_every_peer", &"settlement_recompletion_scores_only_growth_and_new_support",
		&"forest_merger_inherits_two_scored_parents", &"road_merger_never_repays_parents",
		&"monastery_fixture_completes_once"]
	for case: StringName in cases:
		if not scenarios.call(case):
			scenarios.failures.append("Demonstration did not reach its completion sentinel")
	if not scenarios.failures.is_empty():
		for failure: String in scenarios.failures:
			printerr("FAIL: " + failure)
		quit(1)
		return
	print("DEMO RESULT: seeded four-feature scoring, shared completion snapshot, anti-farming, Monastery and save/load continuation passed.")
	quit(0)
