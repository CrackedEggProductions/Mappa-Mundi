class_name EnclosureState
extends RefCounted
## Separate from connected features. Zero Development ID denotes a deferred fixture.

var enclosure_id: int = 0
var coordinate: Vector2i = Vector2i.ZERO
var development_tile_copy_id: int = 0
var family_id: StringName = &"monastery"
var stage: StringName = &"monastery"
var completed_stages: Array[StringName] = []
var assigned_steward_id: int = 0
var completion_ids: Array[int] = []
