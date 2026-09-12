class_name InvariantReport
extends RefCounted
## Validate imported state without crashing; assert/report internal corruption loudly.

var issues: Array[InvariantIssue] = []
var is_valid: bool:
	get:
		return issues.is_empty()


func add(code: StringName, message: String, runtime_id: int = 0) -> void:
	issues.append(InvariantIssue.new(code, message, runtime_id))


func describe() -> String:
	var lines: PackedStringArray = []
	for issue: InvariantIssue in issues:
		lines.append("[%s] runtime_id=%d: %s" % [issue.code, issue.runtime_id, issue.message])
	return "\n".join(lines)
