class_name FeatureContactService
extends RefCounted
## Current contact is socket/relationship geometry; past support lives on lineages.


static func support_ids(state: RunState, feature: CurrentFeature, support_edge: int) -> Array[int]:
	var result: Array[int] = []
	var board: BoardState = state.expansion.board
	var source_edge: int = FeatureState.edge_for_type(feature.feature_type)
	for coordinate: Vector2i in feature.coordinates:
		var cell: BoardCellState = board.get_cell(coordinate)
		if _touches_internally(cell, source_edge, support_edge):
			_add_unique(result, cell.base_tile_copy_id)
		for direction: int in range(4):
			var neighbor: BoardCellState = board.get_cell(coordinate + BoardState.ORTHOGONAL_OFFSETS[direction])
			if neighbor == null:
				continue
			if support_edge == DomainTypes.EdgeType.FIELD and not neighbor.has_field_geography:
				continue
			var socket: int = cell.effective_edges[direction]
			if socket != neighbor.effective_edges[(direction + 2) % 4]:
				continue
			var source_reaches_socket: bool = socket == source_edge or _touches_internally(cell, source_edge, socket)
			var support_reaches_socket: bool = socket == support_edge or _touches_internally(neighbor, socket, support_edge)
			if source_reaches_socket and support_reaches_socket:
				_add_unique(result, neighbor.base_tile_copy_id)
	result.sort()
	return result


static func forest_is_undeveloped(state: RunState, feature: CurrentFeature) -> bool:
	for coordinate: Vector2i in feature.coordinates:
		for development: DevelopmentState in state.expansion.board.get_cell(coordinate).developments:
			if development.stage != &"foresters_lodge":
				return false
	return true


static func _touches_internally(cell: BoardCellState, first: int, second: int) -> bool:
	if first == second:
		return false
	if DomainTypes.EdgeType.FIELD in [first, second] and not cell.has_field_geography:
		return false
	if cell.field_supports_settlement and first in [DomainTypes.EdgeType.SETTLEMENT, DomainTypes.EdgeType.FIELD] and second in [DomainTypes.EdgeType.SETTLEMENT, DomainTypes.EdgeType.FIELD]:
		return true
	for relationship: TileFeatureRelationship in cell.relationships:
		# Access is commercial connectivity, never natural support/contact.
		if relationship.kind == TileFeatureRelationship.Kind.ROAD_SETTLEMENT_ACCESS:
			continue
		if (relationship.from_edge_type == first and relationship.to_edge_type == second) or (relationship.from_edge_type == second and relationship.to_edge_type == first):
			return true
	return false


static func _add_unique(values: Array[int], value: int) -> void:
	if not values.has(value):
		values.append(value)
