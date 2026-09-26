class_name RunResult
extends RefCounted
## Immutable-after-finalization data for inspection and future results presentation.

var grand_charter_id: StringName = &""
var grand_charter_result: StringName = &"failed"
var victory_result: StringName = &"completed_no_victory"
var score: int = 0
var tracks: Array[int] = [0, 0, 0, 0]
var statistics: Dictionary = {}
