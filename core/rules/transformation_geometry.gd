class_name TransformationGeometry
extends RefCounted
## Pure projected geometry. Preview components use private negative IDs, never run IDs.


static func signature(plan: TransformationState) -> String:
	var changes: Array = []
	for change: TransformationChange in plan.changes:
		changes.append([change.coordinate.x, change.coordinate.y, change.before_edges,
			change.after_edges, change.field_before, change.field_after, change.target_lineage_ids])
	return JSON.stringify([String(plan.mode), plan.orientation, plan.target_base_copy_id, changes])


static func copy_cell(source: BoardCellState) -> BoardCellState:
	var cell: BoardCellState = BoardCellState.new()
	cell.coordinate = source.coordinate
	cell.base_tile_copy_id = source.base_tile_copy_id
	cell.definition_id = source.definition_id
	cell.rotation = source.rotation
	cell.act_placed = source.act_placed
	cell.normal_placement_index = source.normal_placement_index
	cell.geometry_revision = source.geometry_revision
	cell.effective_edges = source.effective_edges.duplicate()
	cell.field_supports_settlement = source.field_supports_settlement
	cell.has_field_geography = source.has_field_geography
	cell.developments = source.developments.duplicate()
	cell.transformations = source.transformations.duplicate()
	for group: TileFeatureGroup in source.feature_groups:
		cell.feature_groups.append(group.duplicate(true) as TileFeatureGroup)
	for relation: TileFeatureRelationship in source.relationships:
		cell.relationships.append(relation.duplicate(true) as TileFeatureRelationship)
	return cell


static func rewrite(cell: BoardCellState, change: TransformationChange, mode: StringName) -> void:
	cell.effective_edges = change.after_edges.duplicate()
	cell.has_field_geography = change.field_after
	cell.field_supports_settlement = cell.field_supports_settlement and cell.has_field_geography
	# Existing groups persist even when a specifically authorized rewrite consumes their exits.
	for edge: int in range(1, 5):
		var group: TileFeatureGroup = null
		for candidate: TileFeatureGroup in cell.feature_groups:
			if candidate.edge_type == edge:
				group = candidate
		if group == null and edge in cell.effective_edges:
			group = TileFeatureGroup.new()
			group.edge_type = edge as DomainTypes.EdgeType
			cell.feature_groups.append(group)
		if group != null:
			group.directions.clear()
			for direction: int in range(4):
				if cell.effective_edges[direction] == edge:
					group.directions.append(direction)
	if mode == &"bridge" and TopologyService._has_type(cell, DomainTypes.FeatureType.SETTLEMENT):
		var has_access: bool = false
		for relation: TileFeatureRelationship in cell.relationships:
			if relation.kind == TileFeatureRelationship.Kind.ROAD_SETTLEMENT_ACCESS:
				has_access = true
		if not has_access:
			var access: TileFeatureRelationship = TileFeatureRelationship.new()
			access.from_edge_type = DomainTypes.EdgeType.ROAD
			access.to_edge_type = DomainTypes.EdgeType.SETTLEMENT
			access.kind = TileFeatureRelationship.Kind.ROAD_SETTLEMENT_ACCESS
			cell.relationships.append(access)
	if mode == &"rewilding" and TopologyService._has_type(cell, DomainTypes.FeatureType.RIVER):
		var has_touch: bool = false
		for relation: TileFeatureRelationship in cell.relationships:
			if relation.kind == TileFeatureRelationship.Kind.FOREST_RIVER_TOUCH:
				has_touch = true
		if not has_touch:
			var touch: TileFeatureRelationship = TileFeatureRelationship.new()
			touch.from_edge_type = DomainTypes.EdgeType.FOREST
			touch.to_edge_type = DomainTypes.EdgeType.RIVER
			touch.kind = TileFeatureRelationship.Kind.FOREST_RIVER_TOUCH
			cell.relationships.append(touch)


static func projected(state: RunState, content: ContentRegistry, plan: TransformationState) -> RunState:
	var preview: RunState = RunState.new(0)
	preview.expansion = ExpansionState.new()
	preview.features = FeatureState.new()
	preview.features.lineages = state.features.lineages.duplicate()
	preview.features.components = state.features.components.duplicate()
	preview.expansion.board.cells = state.expansion.board.cells.duplicate()
	var next_preview_id: int = -1
	for change: TransformationChange in plan.changes:
		var cell: BoardCellState
		if change.before_edges.is_empty():
			cell = BoardCellState.from_definition(content.get_tile(plan.definition_id), plan.tile_copy_id,
				change.coordinate, plan.orientation, plan.act_applied, plan.placement_index)
		else:
			cell = copy_cell(state.expansion.board.get_cell(change.coordinate))
		rewrite(cell, change, plan.mode)
		preview.expansion.board.cells[change.coordinate] = cell
		for type: int in range(4):
			if not TopologyService._has_type(cell, type as DomainTypes.FeatureType) \
				or preview.features.component_at(cell.coordinate, type as DomainTypes.FeatureType) != null:
				continue
			var component: FeatureComponentState = FeatureComponentState.new()
			component.component_id = next_preview_id
			next_preview_id -= 1
			component.coordinate = cell.coordinate
			component.feature_type = type as DomainTypes.FeatureType
			preview.features.components.append(component)
	return preview


static func validate(state: RunState, content: ContentRegistry, plan: TransformationState) -> bool:
	var preview: RunState = projected(state, content, plan)
	for change: TransformationChange in plan.changes:
		var cell: BoardCellState = preview.expansion.board.get_cell(change.coordinate)
		for development: DevelopmentState in cell.developments:
			if development.host_kind in [&"field", &"enclosure"] and not cell.has_field_geography:
				return false
		for direction: int in range(4):
			var neighbor: BoardCellState = preview.expansion.board.get_cell(
				cell.coordinate + BoardState.ORTHOGONAL_OFFSETS[direction])
			if neighbor != null and cell.effective_edges[direction] != neighbor.effective_edges[(direction + 2) % 4]:
				return false
	# Future Specialist merger restrictions belong here, before any live mutation.
	return LineageService.validate_rebuild(preview, TopologyService.rebuild(preview)).is_valid
