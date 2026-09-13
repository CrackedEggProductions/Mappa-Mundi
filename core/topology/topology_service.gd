class_name TopologyService
extends RefCounted
## Deterministic full reconstruction; cross-feature access is never connectivity.


static func add_cell_components(state: RunState, cell: BoardCellState) -> void:
	for type_value: int in range(4):
		var feature_type: DomainTypes.FeatureType = type_value as DomainTypes.FeatureType
		if not _has_type(cell, feature_type):
			continue
		if state.features.component_at(cell.coordinate, feature_type) != null:
			continue
		var component: FeatureComponentState = FeatureComponentState.new()
		component.component_id = state.id_allocator.allocate()
		component.feature_type = feature_type
		component.coordinate = cell.coordinate
		component.origin_act = cell.act_placed
		component.origin_source_type = &"base_tile"
		component.origin_source_runtime_id = cell.base_tile_copy_id
		state.features.components.append(component)


static func rebuild(state: RunState) -> Array[CurrentFeature]:
	var result: Array[CurrentFeature] = []
	if state.features == null or state.expansion == null:
		return result
	var board: BoardState = state.expansion.board
	var visited: Dictionary[int, bool] = {}
	for coordinate: Vector2i in board.sorted_coordinates():
		for type_value: int in range(4):
			var feature_type: DomainTypes.FeatureType = type_value as DomainTypes.FeatureType
			var seed_component: FeatureComponentState = state.features.component_at(coordinate, feature_type)
			if seed_component == null or visited.has(seed_component.component_id):
				continue
			if not _has_type(board.get_cell(coordinate), feature_type):
				continue
			var current: CurrentFeature = _walk(state, seed_component, visited)
			result.append(current)
	return result


static func _walk(
	state: RunState, seed_component: FeatureComponentState, visited: Dictionary[int, bool]
) -> CurrentFeature:
	var current: CurrentFeature = CurrentFeature.new()
	current.feature_type = seed_component.feature_type
	var pending: Array[FeatureComponentState] = [seed_component]
	var known_lineages: Array[int] = []
	visited[seed_component.component_id] = true
	var cursor: int = 0
	while cursor < pending.size():
		var component: FeatureComponentState = pending[cursor]
		cursor += 1
		current.component_ids.append(component.component_id)
		current.coordinates.append(component.coordinate)
		if component.lineage_id != 0 and not known_lineages.has(component.lineage_id):
			known_lineages.append(component.lineage_id)
		var cell: BoardCellState = state.expansion.board.get_cell(component.coordinate)
		for direction: int in _directions(cell, current.feature_type):
			var neighbor_coordinate: Vector2i = component.coordinate + BoardState.ORTHOGONAL_OFFSETS[direction]
			var neighbor: BoardCellState = state.expansion.board.get_cell(neighbor_coordinate)
			if neighbor == null:
				current.open_exits += 1
				continue
			if not _directions(neighbor, current.feature_type).has((direction + 2) % 4):
				continue
			var next: FeatureComponentState = state.features.component_at(neighbor_coordinate, current.feature_type)
			if next != null and not visited.has(next.component_id):
				visited[next.component_id] = true
				pending.append(next)
	current.component_ids.sort()
	current.coordinates.sort_custom(BoardState.coordinate_before)
	if known_lineages.size() == 1:
		current.lineage_id = known_lineages[0]
	return current


static func _has_type(cell: BoardCellState, feature_type: DomainTypes.FeatureType) -> bool:
	for group: TileFeatureGroup in cell.feature_groups:
		if group.edge_type == FeatureState.edge_for_type(feature_type):
			return true
	return false


static func _directions(cell: BoardCellState, feature_type: DomainTypes.FeatureType) -> Array[int]:
	var result: Array[int] = []
	var edge_type: int = FeatureState.edge_for_type(feature_type)
	for group: TileFeatureGroup in cell.feature_groups:
		if group.edge_type != edge_type:
			continue
		for direction: int in group.directions:
			if cell.effective_edges[direction] == edge_type and not result.has(direction):
				result.append(direction)
	result.sort()
	return result
