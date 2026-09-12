class_name ValidationResult
extends RefCounted
## Structured boundary result. Diagnostic dictionaries are not gameplay state.

var is_valid: bool = false
var error_code: StringName = &""
var user_message: String = ""
var debug_details: Dictionary = {}


static func success() -> ValidationResult:
	var result: ValidationResult = ValidationResult.new()
	result.is_valid = true
	return result


static func failure(
	code: StringName, message: String, details: Dictionary = {}
) -> ValidationResult:
	var result: ValidationResult = ValidationResult.new()
	result.error_code = code
	result.user_message = message
	result.debug_details = details.duplicate(true)
	return result
