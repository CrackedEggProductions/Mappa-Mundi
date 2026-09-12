class_name SerializationResult
extends RefCounted
## Serialization diagnostics are separate from gameplay command validation.

var validation: ValidationResult
var json_text: String = ""


func _init(result: ValidationResult, text: String = "") -> void:
	validation = result
	json_text = text
