extends SceneTree
## UI scenes run headlessly here; core-only regression runner stays independent.

const SUITES: Array[String] = [
	"res://tests/presentation/board_view_tests.gd",
	"res://tests/presentation/choice_presenter_tests.gd",
	"res://tests/presentation/presentation_query_tests.gd",
	"res://tests/presentation/controller_tests.gd",
	"res://tests/presentation/full_ui_run_tests.gd",
	"res://tests/presentation/playtest_revision_tests.gd",
	"res://tests/presentation/tile_draft_presentation_tests.gd",
	"res://tests/presentation/usability_tests.gd",
	"res://tests/presentation/overlay_regression_tests.gd",
	"res://tests/presentation/generic_steward_presenter_tests.gd",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: int = 0
	var failed: int = 0
	for path: String in SUITES:
		var script: Script = load(path) as Script
		var suite: RefCounted = script.new()
		for scenario: Callable in suite.tests():
			var before: int = suite.failures.size()
			var completed: Variant = await scenario.call()
			if completed == true and suite.failures.size() == before:
				passed += 1
				print("PASS: ", scenario.get_method())
			else:
				failed += 1
				printerr("FAIL: ", scenario.get_method(), " ", suite.failures.slice(before))
	print("PRESENTATION RESULT: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
