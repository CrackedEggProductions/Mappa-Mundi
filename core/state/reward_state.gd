class_name RewardState
extends RefCounted
## Ordered resumable work; threshold/milestone flags never reset during a run.

var threshold_flags: Array[String] = []
var milestone_flags: Array[StringName] = []
var queue: Array[Dictionary] = []
var history: Array[Dictionary] = []
