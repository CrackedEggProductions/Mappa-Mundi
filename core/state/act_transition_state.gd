class_name ActTransitionState
extends RefCounted
## Step is the NEXT canonical operation (1..14), never replayed after load.

var transition_id: int = 0
var outgoing_act: int = 1
var incoming_act: int = 2
var step: int = 1
var charter_result: Dictionary = {}
var rewards: Array[StringName] = []
var pending_charter_reward_index: int = 0
var reward_history_start: int = 0
var pending_hand_refill: int = -1
var rewards_queued: bool = false
var advanced: bool = false
var capacity_refreshed: bool = false
var survey_refreshed: bool = false
var relics_refreshed: bool = false
var unlocked: bool = false
var seeded: bool = false
var shuffled: bool = false
var information_selected: bool = false
var counter_reset: bool = false
var refill_done: bool = false
var seeded_copy_ids: Array[int] = []
