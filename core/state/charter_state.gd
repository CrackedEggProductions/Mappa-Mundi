class_name CharterState
extends RefCounted
## Exact selections and audit facts; normal presentation must use CharterRules.

var act_one_id: StringName = &""
var act_two_id: StringName = &""
var grand_id: StringName = &""
var forecast_visible: bool = false
var exact_revealed: bool = false
var exact_revealed_act: int = 0
var exact_revealed_index: int = 0
var evaluations: Array[Dictionary] = []
var history: Array[Dictionary] = []
var completed_act_placements: Array[int] = [0, 0, 0]
## Physical commit order distinguishes bonus plays sharing one normal index.
var placement_history: Array[Dictionary] = []
var bonus_queue: Array[Dictionary] = []
var bonus_active: bool = false
var deferred_refill_index: int = -1
