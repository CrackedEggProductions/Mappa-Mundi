extends SceneTree
## Deterministic command-driven scenarios, without presentation or reward seeding.

const Scenarios = preload("res://tests/scenarios/transformation_scenarios.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var suite: RefCounted = Scenarios.new()
	var completed: int = 0
	for test: Callable in suite.tests():
		if test.call() != true:
			suite.failures.append("Scenario did not finish: " + test.get_method())
		else:
			completed += 1
	for failure: String in suite.failures:
		printerr("FAIL: " + failure)
	if suite.failures.is_empty():
		print("DEMO RESULT: %d Transformation scenarios passed: Urban reopening/closed merger with inherited histories and hosted Developments; perpendicular Bridge Road growth with unchanged River; both Rewilding modes and preserved built features; atomic rejection; physical hand/Reserve/Survey; inert repeated load and identical continuation." % completed)
	quit(0 if suite.failures.is_empty() else 1)
