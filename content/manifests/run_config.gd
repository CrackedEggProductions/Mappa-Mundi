class_name RunConfig
extends Resource
## Tunable alpha data only. Starting bag and subsystem values are added by phase.

@export var config_id: StringName = &""
@export var act_placement_limits: Array[int] = []
@export var track_thresholds: Array[int] = []
@export var starting_bag: Array[StartingBagEntry] = []
@export var hand_capacity: int = 3
@export var reserve_capacity: int = 1
@export var initial_survey_charges: int = 1
@export var emergency_definitions: Array[StringName] = []
