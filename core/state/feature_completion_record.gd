class_name FeatureCompletionRecord
extends RefCounted
## Persisted completion facts calculated from a shared frozen snapshot.

var record_id: int = 0
var snapshot_id: int = 0
var lineage_id: int = 0
var feature_type: int = -1
var enclosure_id: int = 0
var act: int = 1
var placement_index: int = 0
var source_id: int = 0
var first_completion: bool = true
var growth_phase: int = 1
var total_size: int = 0
var component_ids: Array[int] = []
var new_component_ids: Array[int] = []
var field_support_ids: Array[int] = []
var river_support_ids: Array[int] = []
var forest_contact_ids: Array[int] = []
var new_field_ids: Array[int] = []
var new_river_ids: Array[int] = []
var new_forest_ids: Array[int] = []
## Historical full-network membership at this completion, separate from physical size.
var trade_network_id: int = 0
var network_road_ids: Array[int] = []
var network_settlement_ids: Array[int] = []
var new_settlement_ids: Array[int] = []
var gains: Array[int] = [0, 0, 0, 0]
var development_families: Array[StringName] = []
var forest_undeveloped: bool = true
var enclosure_stage: StringName = &""
var natural_neighbor_count: int = 0
var settlement_neighbor_count: int = 0
## 0 unclassified; 1 Hamlet; 2 Village; 3 Town; 4 City.
var settlement_class: int = 0
## Qualification retained before this completion, including unfinished growth.
var highest_class_before_completion: int = 0
