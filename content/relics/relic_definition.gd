class_name RelicDefinition
extends Resource
## Passive canonical alpha content; executable rules remain in RelicRules.

@export var definition_id: StringName = &""
@export var display_name: String = ""
@export var unlock_act: int = 1
@export var behavior_id: StringName = &""

@export var tier: StringName = &"foundational"
@export var once_per_act: bool = false
