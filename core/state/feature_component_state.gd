class_name FeatureComponentState
extends RefCounted
## Persistent contribution identity, independent of base-tile age and graph traversal.

var component_id: int = 0
var feature_type: DomainTypes.FeatureType = DomainTypes.FeatureType.ROAD
var coordinate: Vector2i = Vector2i.ZERO
var origin_act: int = 1
var origin_source_type: StringName = &"base_tile"
var origin_source_runtime_id: int = 0
var lineage_id: int = 0
