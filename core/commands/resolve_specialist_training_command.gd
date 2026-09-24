class_name ResolveSpecialistTrainingCommand
extends PlayerCommand

var choice_id: int
var role_definition_id: StringName
var expected_state_revision: int = -1


func _init(choice: int = 0, role: StringName = &"") -> void:
	choice_id = choice
	role_definition_id = role
