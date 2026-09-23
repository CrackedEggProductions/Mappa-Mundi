extends SceneTree
## Runs without loading the application scene or any gameplay presentation.

const TestSuite = preload("res://tests/framework/test_suite.gd")
const SUITE_PATHS: Array[String] = [
	"res://tests/unit/foundation_tests.gd",
	"res://tests/unit/content_validation_tests.gd",
	"res://tests/integration/content_registry_tests.gd",
	"res://tests/unit/identity_state_tests.gd",
	"res://tests/unit/run_rng_tests.gd",
	"res://tests/unit/serialization_tests.gd",
	"res://tests/integration/run_round_trip_tests.gd",
	"res://tests/unit/expansion_content_tests.gd",
	"res://tests/unit/board_placement_tests.gd",
	"res://tests/unit/expansion_serialization_tests.gd",
	"res://tests/unit/feature_topology_tests.gd",
	"res://tests/unit/feature_scoring_tests.gd",
	"res://tests/unit/feature_serialization_tests.gd",
	"res://tests/integration/expansion_gameplay_tests.gd",
	"res://tests/integration/feature_scenario_tests.gd",
	"res://tests/unit/trade_scoring_tests.gd",
	"res://tests/unit/trade_graph_tests.gd",
	"res://tests/unit/trade_serialization_tests.gd",
	"res://tests/integration/trade_scenario_tests.gd",
	"res://tests/unit/development_content_tests.gd",
	"res://tests/unit/development_effect_tests.gd",
	"res://tests/unit/development_placement_tests.gd",
	"res://tests/unit/development_serialization_tests.gd",
	"res://tests/integration/development_scenario_tests.gd",
	"res://tests/integration/development_acceptance_tests.gd",
	"res://tests/unit/phase_six_content_test.gd",
	"res://tests/unit/transformation_topology_tests.gd",
	"res://tests/unit/transformation_serialization_tests.gd",
	"res://tests/scenarios/transformation_scenarios.gd",
	"res://tests/integration/transformation_acceptance_tests.gd",
]

var _passed: int = 0
var _failed: int = 0
var _completed: bool = false


func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_check_completion")


func _run() -> void:
	print("Mappa Mundi Phase %d tests | Godot %s" % [
		BuildVersions.IMPLEMENTATION_PHASE, Engine.get_version_info()["string"],
	])
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if "--self-test-failure" in arguments:
		var failure_suite: TestSuite = TestSuite.new()
		_run_test(failure_suite, _intentional_failure.bind(failure_suite))
	elif "--self-test-runtime-error" in arguments:
		_run_test(TestSuite.new(), _intentional_runtime_error)
	else:
		for suite_path: String in SUITE_PATHS:
			var suite_script: GDScript = load(suite_path) as GDScript
			if suite_script == null or not suite_script.can_instantiate():
				_failed += 1
				printerr("FAIL: cannot load suite %s" % suite_path)
				continue
			var suite: TestSuite = suite_script.new() as TestSuite
			for test: Callable in suite.tests():
				_run_test(suite, test)
		if current_scene != null or root.get_child_count() != 0:
			_failed += 1
			printerr("FAIL: test runner instantiated presentation nodes")
	print("RESULT: %d passed, %d failed" % [_passed, _failed])
	_completed = true
	quit(0 if _failed == 0 and _passed > 0 else 1)


func _check_completion() -> void:
	if not _completed:
		printerr("FAIL: test runner aborted before completing all suites")
		quit(1)


func _run_test(suite: TestSuite, test: Callable) -> void:
	suite.failures.clear()
	var completed: Variant = test.call()
	if completed != true:
		suite.failures.append("Test did not reach its completion sentinel")
	if suite.failures.is_empty():
		_passed += 1
		print("PASS: %s" % test.get_method())
	else:
		_failed += 1
		printerr("FAIL: %s | %s" % [test.get_method(), "; ".join(suite.failures)])


func _intentional_failure(suite: TestSuite) -> bool:
	suite.expect_true(false, "Intentional assertion failure verifies exit status")
	return true


func _intentional_runtime_error() -> bool:
	var empty: Array[bool] = []
	return empty[0]
