class_name FeatureHistoryRecord
extends RefCounted
## Structured audit, never replayed to reconstruct authoritative state.

var event_id: int = 0
var kind: StringName = &""
var lineage_id: int = 0
var feature_type: int = -1
var act: int = 1
var placement_index: int = 0
var source_id: int = 0
var parent_event_id: int = 0
var component_ids: Array[int] = []
var parent_ids: Array[int] = []
var track: int = -1
var amount: int = 0
