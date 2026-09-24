class_name TransformationChange
extends RefCounted
## One cell's exact before/after geometry in a validated Transformation intent.

var coordinate: Vector2i = Vector2i.ZERO
var before_edges: Array[DomainTypes.EdgeType] = []
var after_edges: Array[DomainTypes.EdgeType] = []
var field_before: bool = false
var field_after: bool = false
var target_lineage_ids: Array[int] = []
var created_component_ids: Array[int] = []
