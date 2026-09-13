class_name FeatureState
extends RefCounted
## Persistent feature truth; current connectivity is deliberately not stored here.

var components: Array[FeatureComponentState] = []
var lineages: Array[FeatureLineageState] = []
var history: Array[FeatureHistoryRecord] = []
var completions: Array[FeatureCompletionRecord] = []
var enclosures: Array[EnclosureState] = []
var tracks: RealmTrackState = RealmTrackState.new()
var topology_revision: int = 0
## Indexed by FeatureType; records survive reopening and merging.
var largest_completed_sizes: Array[int] = [0, 0, 0, 0]


func component(id: int) -> FeatureComponentState:
	for value: FeatureComponentState in components:
		if value.component_id == id:
			return value
	return null


func lineage(id: int) -> FeatureLineageState:
	for value: FeatureLineageState in lineages:
		if value.lineage_id == id:
			return value
	return null


func component_at(at: Vector2i, type: DomainTypes.FeatureType) -> FeatureComponentState:
	for value: FeatureComponentState in components:
		if value.coordinate == at and value.feature_type == type:
			return value
	return null


static func edge_for_type(type: DomainTypes.FeatureType) -> DomainTypes.EdgeType:
	const EDGES: Array[DomainTypes.EdgeType] = [DomainTypes.EdgeType.ROAD,
		DomainTypes.EdgeType.SETTLEMENT, DomainTypes.EdgeType.FOREST, DomainTypes.EdgeType.RIVER]
	return EDGES[type]


static func type_for_edge(edge: DomainTypes.EdgeType) -> DomainTypes.FeatureType:
	const TYPES: Array[DomainTypes.FeatureType] = [DomainTypes.FeatureType.FOREST,
		DomainTypes.FeatureType.FOREST, DomainTypes.FeatureType.RIVER,
		DomainTypes.FeatureType.ROAD, DomainTypes.FeatureType.SETTLEMENT]
	assert(edge != DomainTypes.EdgeType.FIELD, "Field has no tracked component")
	return TYPES[edge]
