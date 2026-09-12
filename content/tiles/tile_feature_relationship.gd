class_name TileFeatureRelationship
extends Resource
## Explicit cross-feature facts. These never merge the participating features.

enum Kind { ROAD_SETTLEMENT_ACCESS, SETTLEMENT_RIVER_TOUCH, FOREST_RIVER_TOUCH }

@export var from_edge_type: int = DomainTypes.EdgeType.ROAD
@export var to_edge_type: int = DomainTypes.EdgeType.SETTLEMENT
@export var kind: Kind = Kind.ROAD_SETTLEMENT_ACCESS
