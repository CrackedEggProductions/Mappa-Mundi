class_name TileFeatureGroup
extends Resource
## One same-type component within one static tile; Field is not a feature.

@export var edge_type: int = DomainTypes.EdgeType.ROAD
## Canonical directional sockets: 0 North, 1 East, 2 South, 3 West.
@export var directions: Array[int] = []
