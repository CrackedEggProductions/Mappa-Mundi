extends SceneTree
## Deterministic command-driven scenarios, without presentation or reward seeding.

const Scenarios = preload("res://tests/scenarios/transformation_scenarios.gd")
const Rulings = preload("res://tests/integration/transformation_ruling_tests.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var suite: RefCounted = Scenarios.new()
	var rulings: RefCounted = Rulings.new()
	var completed: int = 0
	for group: RefCounted in [suite, rulings]:
		for test: Callable in group.tests():
			if test.call() != true:
				group.failures.append("Scenario did not finish: " + test.get_method())
			else:
				completed += 1
	suite.failures.append_array(rulings.failures)
	for failure: String in suite.failures:
		printerr("FAIL: " + failure)
	if suite.failures.is_empty():
		print("DEMO RESULT: %d Transformation scenarios passed: Urban reopening/closed merger with inherited histories and hosted Developments; perpendicular Bridge Road growth with unchanged River; both Rewilding modes and preserved built features; atomic rejection; physical hand/Reserve/Survey; canonical Bridge bank rejection and Abbey/Rewilding; inert repeated load and identical continuation." % completed)
	quit(0 if suite.failures.is_empty() else 1)
