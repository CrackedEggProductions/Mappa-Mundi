class_name DeserializationResult
extends RefCounted
## Invalid external input never publishes a partially reconstructed run.

var validation: ValidationResult
var state: RunState


func _init(result: ValidationResult, loaded_state: RunState = null) -> void:
	validation = result
	state = loaded_state
