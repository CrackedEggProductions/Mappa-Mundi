class_name CharterDefinition
extends Resource
## Passive canonical targets and ordered rewards; CharterRules owns evaluation.

@export var definition_id: StringName = &""
@export var display_name: String = ""
@export var evaluation_act: int = 1
@export var forecast_text: String = ""
@export var behavior_id: StringName = &""
@export var targets: Dictionary = {}
@export var fulfill_rewards: Array[StringName] = []
@export var exceed_rewards: Array[StringName] = []
