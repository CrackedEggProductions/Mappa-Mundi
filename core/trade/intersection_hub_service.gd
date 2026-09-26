class_name IntersectionHubService
extends RefCounted
## Read-only Junction graph projection. No physical Road component is invented.


static func rebuild(state: RunState) -> Array[IntersectionHubState]:
	var result: Array[IntersectionHubState] = []
	if state.expansion == null or state.features == null:
		return result
	for coordinate: Vector2i in state.expansion.board.sorted_coordinates():
		var cell: BoardCellState = state.expansion.board.get_cell(coordinate)
		if not cell.intersection_hub:
			continue
		var current: IntersectionHubState = IntersectionHubState.new()
		current.hub_id = cell.base_tile_copy_id
		current.coordinate = coordinate
		for direction: int in range(4):
			if cell.effective_edges[direction] != DomainTypes.EdgeType.ROAD:
				continue
			current.socket_directions.append(direction)
			var neighbor: BoardCellState = state.expansion.board.get_cell(coordinate + BoardState.ORTHOGONAL_OFFSETS[direction])
			if neighbor == null or neighbor.effective_edges[(direction + 2) % 4] != DomainTypes.EdgeType.ROAD:
				continue
			if neighbor.intersection_hub:
				current.neighboring_hub_ids.append(neighbor.base_tile_copy_id)
			else:
				var component: FeatureComponentState = state.features.component_at(neighbor.coordinate, DomainTypes.FeatureType.ROAD)
				if component != null and component.lineage_id not in current.road_lineage_ids:
					current.road_lineage_ids.append(component.lineage_id)
		current.road_lineage_ids.sort()
		current.neighboring_hub_ids.sort()
		result.append(current)
	result.sort_custom(func(a: IntersectionHubState, b: IntersectionHubState) -> bool: return a.hub_id < b.hub_id)
	return result


static func hub(state: RunState, id: int) -> IntersectionHubState:
	for current: IntersectionHubState in rebuild(state):
		if current.hub_id == id:
			return current
	return null


static func at(state: RunState, coordinate: Vector2i) -> IntersectionHubState:
	for current: IntersectionHubState in rebuild(state):
		if current.coordinate == coordinate:
			return current
	return null
