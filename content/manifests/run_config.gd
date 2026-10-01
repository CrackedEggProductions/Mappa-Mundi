class_name RunConfig
extends Resource
## Passive alpha configuration; draft cadence and content pools are authoritative.

const DEFAULT_THRESHOLD_REWARD_KINDS: Array[StringName] = [&"relic_offer", &"training_reward", &"relic_offer", &"major_reward"]

@export var config_id: StringName = &""
@export var act_placement_limits: Array[int] = []
@export var track_thresholds: Array[int] = []
@export var track_threshold_reward_kinds: Array[StringName] = DEFAULT_THRESHOLD_REWARD_KINDS.duplicate()
@export var starting_bag: Array[StartingBagEntry] = []
## Unlocking a design never automatically creates physical copies.
@export var starter_draft_pool: Array[StringName] = []
@export var act_one_draft_pool: Array[StringName] = []
@export var act_two_unlocks: Array[StringName] = []
@export var act_three_unlocks: Array[StringName] = []
@export var draft_interval: int = 2
@export var hand_capacity: int = 3
@export var reserve_capacity: int = 1
@export var initial_survey_charges: int = 1
@export var emergency_definitions: Array[StringName] = []


func draft_pool(act: int) -> Array[StringName]:
	var result: Array[StringName] = act_one_draft_pool.duplicate()
	if act >= 2:
		result.append_array(act_two_unlocks)
	if act >= 3:
		result.append_array(act_three_unlocks)
	return result


func entry_draft_pool(act: int) -> Array[StringName]:
	if act == 2:
		return act_two_unlocks.duplicate()
	if act == 3:
		return act_three_unlocks.duplicate()
	return starter_draft_pool.duplicate() if act == 1 else []
