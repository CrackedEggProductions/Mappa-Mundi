class_name RunConfig
extends Resource
## Tunable alpha data only. Starting bag and subsystem values are added by phase.

@export var config_id: StringName = &""
@export var act_placement_limits: Array[int] = []
@export var track_thresholds: Array[int] = []
@export var starting_bag: Array[StartingBagEntry] = []
## Ordered physical-copy grants; preserve order before the full-bag shuffle.
@export var act_two_seeds: Array[StartingBagEntry] = []
@export var act_three_seeds: Array[StartingBagEntry] = []
@export var hand_capacity: int = 3
@export var reserve_capacity: int = 1
@export var initial_survey_charges: int = 1
@export var emergency_definitions: Array[StringName] = []


func seeds_for_act(act: int) -> Array[StartingBagEntry]:
	return act_two_seeds if act == 2 else (act_three_seeds if act == 3 else [])
