class_name TradeLinkState
extends RefCounted
## Durable feature lineage endpoints, independent of physical feature adjacency.

var from_lineage_id: int = 0
var to_lineage_id: int = 0
var source_id: int = 0
var source_kind: StringName = &"fixture_authorized"
var explicit_access: bool = false


func signature() -> String:
	return "%d:%d:%s:%d:%d" % [mini(from_lineage_id, to_lineage_id),
		maxi(from_lineage_id, to_lineage_id), source_kind, source_id, int(explicit_access)]
