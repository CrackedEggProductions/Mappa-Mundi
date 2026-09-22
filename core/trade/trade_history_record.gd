class_name TradeHistoryRecord
extends RefCounted
## Structured genealogy audit, with reach at the time of the event.

var event_id: int = 0
var kind: StringName = &"network_created"
var lineage_id: int = 0
var act: int = 1
var placement_index: int = 0
var source_id: int = 0
var parent_ids: Array[int] = []
var road_lineage_ids: Array[int] = []
var settlement_lineage_ids: Array[int] = []
