class_name DevelopmentState
extends RefCounted
## A physical overlay; coordinate belongs to its board cell, definition to its copy.

var tile_copy_id: int = 0
var family_id: StringName = &""
var host_kind: StringName = &""
var host_lineage_id: int = 0
var river_lineage_id: int = 0
var enclosure_id: int = 0
var act_placed: int = 1
var placement_index: int = 0
var stage: StringName = &""
var replaced_copy_id: int = 0


func requires_field_geography() -> bool:
	# Continued legality follows the current stage, not an Upgrade's prerequisite.
	return host_kind == &"field" or stage == &"monastery"
