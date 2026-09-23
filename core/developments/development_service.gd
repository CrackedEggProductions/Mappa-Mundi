class_name DevelopmentService
extends RefCounted
## Current overlay queries and host reconciliation, independent of presentation.


static func all(state: RunState) -> Array[DevelopmentState]:
	var result: Array[DevelopmentState] = []
	if state.expansion == null:
		return result
	for coordinate: Vector2i in state.expansion.board.sorted_coordinates():
		result.append_array(state.expansion.board.get_cell(coordinate).developments)
	result.sort_custom(func(a: DevelopmentState, b: DevelopmentState) -> bool:
		return a.tile_copy_id < b.tile_copy_id)
	return result


static func find(state: RunState, copy_id: int) -> DevelopmentState:
	for development: DevelopmentState in all(state):
		if development.tile_copy_id == copy_id:
			return development
	return null


static func coordinate_for(state: RunState, copy_id: int) -> Vector2i:
	for coordinate: Vector2i in state.expansion.board.sorted_coordinates():
		for development: DevelopmentState in state.expansion.board.get_cell(coordinate).developments:
			if development.tile_copy_id == copy_id:
				return coordinate
	assert(false, "Development copy is not on the board")
	return Vector2i.ZERO


static func families(state: RunState, settlement_id: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for development: DevelopmentState in all(state):
		if development.host_kind == &"settlement" and development.host_lineage_id == settlement_id:
			if not result.has(development.family_id):
				result.append(development.family_id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result


static func current_class(state: RunState, settlement_id: int) -> int:
	for feature: CurrentFeature in TopologyService.rebuild(state):
		if feature.lineage_id == settlement_id and feature.feature_type == DomainTypes.FeatureType.SETTLEMENT:
			return classify(feature.coordinates.size(), families(state, settlement_id).size())
	return 0


static func classify(size: int, family_count: int) -> int:
	if size >= 9 and family_count >= 2:
		return 4
	if size >= 6 and size <= 8 and family_count >= 1:
		return 3
	if size >= 3 and size <= 5:
		return 2
	return 1 if size >= 1 and size <= 2 else 0


static func remap_hosts(state: RunState, current: Array[CurrentFeature]) -> void:
	for development: DevelopmentState in all(state):
		development.host_lineage_id = _descendant(state, current, development.host_lineage_id)
		development.river_lineage_id = _descendant(state, current, development.river_lineage_id)
	for feature: CurrentFeature in current:
		if feature.feature_type == DomainTypes.FeatureType.SETTLEMENT:
			var lineage: FeatureLineageState = state.features.lineage(feature.lineage_id)
			lineage.highest_settlement_class = maxi(lineage.highest_settlement_class,
				classify(feature.coordinates.size(), families(state, feature.lineage_id).size()))


static func _descendant(state: RunState, current: Array[CurrentFeature], previous: int) -> int:
	if previous == 0:
		return 0
	for feature: CurrentFeature in current:
		if feature.lineage_id == previous or LineageService.is_ancestor(state, previous, feature.lineage_id):
			return feature.lineage_id
	return previous # Validation reports unsupported disappearance; never invent a host.


static func coordinate_touches_feature(state: RunState, coordinate: Vector2i,
		feature: CurrentFeature, source_edge: int = DomainTypes.EdgeType.FIELD) -> bool:
	var cell: BoardCellState = state.expansion.board.get_cell(coordinate)
	if cell == null:
		return false
	for at: Vector2i in feature.coordinates:
		var offset: Vector2i = at - coordinate
		if absi(offset.x) + absi(offset.y) == 1:
			return true
		if at == coordinate and FeatureContactService._touches_internally(
				cell, FeatureState.edge_for_type(feature.feature_type), source_edge):
			return true
	return false


static func port_rivers(state: RunState, coordinate: Vector2i, host_lineage_id: int) -> Array[int]:
	var result: Array[int] = []
	if state.features == null:
		return result
	var component: FeatureComponentState = state.features.component_at(coordinate, DomainTypes.FeatureType.SETTLEMENT)
	if component == null or component.lineage_id != host_lineage_id:
		return result
	# Contact belongs to this tile; another tile of the host cannot grant eligibility.
	for feature: CurrentFeature in TopologyService.rebuild(state):
		if feature.feature_type != DomainTypes.FeatureType.RIVER:
			continue
		if coordinate_touches_feature(state, coordinate, feature, DomainTypes.EdgeType.SETTLEMENT):
			result.append(feature.lineage_id)
	result.sort()
	return result
