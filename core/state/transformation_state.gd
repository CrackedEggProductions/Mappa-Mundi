class_name TransformationState
extends RefCounted
## Persistent physical history, including specialized new-base placements.

var tile_copy_id: int = 0
var definition_id: StringName = &""
var act_applied: int = 1
var placement_index: int = 0
var mode: StringName = &""
var orientation: int = 0
var target_base_copy_id: int = 0
var changes: Array[TransformationChange] = []
