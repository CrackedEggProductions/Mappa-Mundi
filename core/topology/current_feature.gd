class_name CurrentFeature
extends RefCounted
## Disposable graph result. Persistent identity belongs to FeatureLineageState.

var feature_type: DomainTypes.FeatureType = DomainTypes.FeatureType.ROAD
var component_ids: Array[int] = []
var coordinates: Array[Vector2i] = []
var open_exits: int = 0
## Zero until reconciliation when a graph joins several historical lineages.
var lineage_id: int = 0
