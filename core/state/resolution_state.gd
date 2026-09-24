class_name ResolutionState
extends RefCounted
## A committed placement paused before consequences, not a command to replay.

var source_id: int = 0
var stage: StringName = &""
var affected_targets: Array[Dictionary] = []
var completion_snapshot: Dictionary = {}
var immediate_development_copy_id: int = 0
var immediate_parent_event_id: int = 0
