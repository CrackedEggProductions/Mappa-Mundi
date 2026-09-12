extends RefCounted
## Each test must return true after reaching its final assertion.
## An aborted GDScript function returns null and is therefore a failed test.

var failures: Array[String] = []


func tests() -> Array[Callable]:
	return []


func expect_true(actual: bool, message: String) -> void:
	if not actual:
		failures.append(message)


func expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
