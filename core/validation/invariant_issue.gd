class_name InvariantIssue
extends RefCounted
## Programming/corruption diagnostic, distinct from an illegal player command.

var code: StringName
var message: String
var runtime_id: int


func _init(issue_code: StringName, detail: String, entity_id: int = 0) -> void:
	code = issue_code
	message = detail
	runtime_id = entity_id
