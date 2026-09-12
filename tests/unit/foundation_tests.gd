extends "res://tests/framework/test_suite.gd"

const AssertionSuite = preload("res://tests/framework/test_suite.gd")


func tests() -> Array[Callable]:
	return [
		success_result_reports_valid,
		failure_result_preserves_actionable_diagnostics,
		failure_result_owns_its_diagnostics,
		assertions_collect_failure_without_aborting,
		assertions_accept_equal_values,
	]


func success_result_reports_valid() -> bool:
	expect_true(ValidationResult.success().is_valid, "Successful boundary result is valid")
	return true


func failure_result_preserves_actionable_diagnostics() -> bool:
	var result: ValidationResult = ValidationResult.failure(&"invalid_content", "Check tile edges")
	expect_true(
		not result.is_valid and result.error_code == &"invalid_content"
		and result.user_message == "Check tile edges",
		"Rejected content carries a stable code and actionable message"
	)
	return true


func failure_result_owns_its_diagnostics() -> bool:
	var details: Dictionary = {"tile": {"id": "tile.open_fields"}}
	var result: ValidationResult = ValidationResult.failure(&"invalid_content", "Bad tile", details)
	details["tile"]["id"] = "changed"
	expect_equal(result.debug_details["tile"]["id"], "tile.open_fields", "Caller changes cannot rewrite diagnostics")
	return true


func assertions_collect_failure_without_aborting() -> bool:
	var probe: AssertionSuite = AssertionSuite.new()
	probe.expect_equal(1, 2, "Intentional mismatch")
	expect_equal(probe.failures.size(), 1, "An assertion records a failure and returns")
	return true


func assertions_accept_equal_values() -> bool:
	var probe: AssertionSuite = AssertionSuite.new()
	probe.expect_equal([1, 2], [1, 2], "Equal arrays")
	expect_true(probe.failures.is_empty(), "Equal values do not produce false failures")
	return true
