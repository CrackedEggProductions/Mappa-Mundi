class_name TileRotation
extends RefCounted
## Clockwise quarter turns; directional sockets are always N/E/S/W = 0/1/2/3.


static func edges(
	canonical: Array[DomainTypes.EdgeType], quarter_turns: int
) -> Array[DomainTypes.EdgeType]:
	assert(canonical.size() == 4, "A tile requires exactly four mechanical edges")
	var result: Array[DomainTypes.EdgeType] = []
	for direction: int in range(4):
		result.append(canonical[posmod(direction - quarter_turns, 4)])
	return result


static func groups(
	canonical: Array[TileFeatureGroup], quarter_turns: int
) -> Array[TileFeatureGroup]:
	var result: Array[TileFeatureGroup] = []
	for original: TileFeatureGroup in canonical:
		var rotated: TileFeatureGroup = original.duplicate(true) as TileFeatureGroup
		rotated.directions.clear()
		for direction: int in original.directions:
			rotated.directions.append(posmod(direction + quarter_turns, 4))
		rotated.directions.sort()
		result.append(rotated)
	return result


static func geometry_signature(definition: TileDefinition, quarter_turns: int) -> String:
	var group_tokens: Array[String] = []
	for group: TileFeatureGroup in groups(definition.feature_groups, quarter_turns):
		group_tokens.append("%d:%s" % [group.edge_type, str(group.directions)])
	group_tokens.sort()
	var relationship_tokens: Array[String] = []
	for relationship: TileFeatureRelationship in definition.relationships:
		relationship_tokens.append("%d:%d:%d" % [
			relationship.from_edge_type, relationship.to_edge_type, relationship.kind,
		])
	relationship_tokens.sort()
	return "%s|%s|%s" % [
		str(edges(definition.canonical_edges, quarter_turns)),
		";".join(group_tokens), ";".join(relationship_tokens),
	]
