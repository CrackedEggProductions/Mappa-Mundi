extends SceneTree
## Automated controller/button exercise, not a claim of manual mouse testing.

const FullRuns = preload("res://tests/presentation/full_ui_run_tests.gd")
const ControllerTests = preload("res://tests/presentation/controller_tests.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var total: int = 0
	var failures: Array[String] = []
	for script: Script in [ControllerTests, FullRuns]:
		var suite: RefCounted = script.new()
		for scenario: Callable in suite.tests():
			if scenario.call() != true:
				suite.failures.append("Aborted scenario: " + scenario.get_method())
			total += 1
			print("PRESENTATION SCENARIO: ", scenario.get_method())
		failures.append_array(suite.failures)
	for trace: Dictionary in FullRuns._runs:
		print("PRESENTATION FULL RUN: seed=", trace.state.original_seed,
			" counts=", trace.counts, " result=", trace.state.final_result.victory_result if trace.state.final_result != null else "unfinished",
			" choices=", trace.choices.size(), " fingerprint=", trace.fingerprint)
	for failure: String in failures:
		printerr("FAIL: ", failure)
	print("PRESENTATION RESULT: ", total, " scenarios; ", failures.size(), " failures; ", FullRuns._runs.size(), " complete-run attempts")
	quit(0 if failures.is_empty() else 1)
