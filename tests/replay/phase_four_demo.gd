extends SceneTree

const Scenarios = preload("res://tests/integration/trade_scenario_tests.gd")
const Graphs = preload("res://tests/unit/trade_graph_tests.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scenarios: RefCounted = Scenarios.new()
	for test: Callable in scenarios.tests():
		if test.call() != true:
			scenarios.failures.append("Scenario did not finish")
	var graphs: RefCounted = Graphs.new()
	graphs.split_and_reconnect_preserve_genealogy()
	var failures: Array = scenarios.failures + graphs.failures
	for failure: String in failures:
		printerr("FAIL: " + failure)
	if failures.is_empty():
		print("DEMO RESULT: transitive full-network scoring, unfinished hubs, no retroactive gain, leave/rejoin and merger anti-farming, split/reconnection genealogy and non-triggering save/load passed.")
	quit(0 if failures.is_empty() else 1)
