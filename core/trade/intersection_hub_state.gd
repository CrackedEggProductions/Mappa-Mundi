class_name IntersectionHubState
extends RefCounted
## Derived infrastructure identity: the physical Junction copy is its stable hub ID.

var hub_id: int = 0
var coordinate: Vector2i = Vector2i.ZERO
var socket_directions: Array[int] = []
var road_lineage_ids: Array[int] = []
var neighboring_hub_ids: Array[int] = []
