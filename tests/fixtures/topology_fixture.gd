extends RefCounted
## Isolated graph fixtures; gameplay integration fixtures validate physical zones too.


static func empty() -> RunState:
	var state: RunState = RunState.new(913)
	state.expansion = ExpansionState.new()
	state.features = FeatureState.new()
	return state


static func add(state: RunState, at: Vector2i, edges: Array[DomainTypes.EdgeType]) -> BoardCellState:
	var cell: BoardCellState = BoardCellState.new()
	cell.coordinate = at
	cell.base_tile_copy_id = state.id_allocator.allocate()
	cell.act_placed = state.expansion.current_act
	set_geometry(cell, edges)
	state.expansion.board.add_cell(cell)
	TopologyService.add_cell_components(state, cell)
	return cell


static func set_geometry(cell: BoardCellState, edges: Array[DomainTypes.EdgeType]) -> void:
	cell.effective_edges = edges.duplicate()
	cell.feature_groups.clear()
	for edge: int in range(1, 5):
		var group: TileFeatureGroup = TileFeatureGroup.new()
		group.edge_type = edge
		for direction: int in range(4):
			if edges[direction] == edge:
				group.directions.append(direction)
		if not group.directions.is_empty():
			cell.feature_groups.append(group)


static func reconcile(state: RunState) -> Array[CurrentFeature]:
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	assert(LineageService.validate_rebuild(state, current).is_valid)
	LineageService.reconcile(state, current)
	return current


static func signature(current: Array[CurrentFeature]) -> String:
	var parts: Array[String] = []
	for feature: CurrentFeature in current:
		parts.append(str([feature.feature_type, feature.component_ids, feature.coordinates,
			feature.open_exits, feature.lineage_id]))
	return "|".join(parts)
