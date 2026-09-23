class_name TransformationPlacementQuery
extends RefCounted
## Purpose-built, deterministic plans. No physical IDs or gameplay RNG are consumed.


static func query(state: RunState, content: ContentRegistry, copy_id: int) -> Array[PlacementOption]:
	var result: Array[PlacementOption] = []
	var copy: TileCopyState = PhysicalTileRules.find_copy(state, copy_id)
	if copy == null or state.features == null:
		return result
	var definition: TileDefinition = content.get_tile(copy.definition_id)
	if definition == null or definition.tile_class != DomainTypes.TileClass.TRANSFORMATION \
		or state.expansion.current_act < definition.unlock_act:
		return result
	var kind: StringName = definition.transformation_kind
	if kind in [&"urban_expansion", &"rewilding"]:
		for coordinate: Vector2i in state.expansion.board.frontier():
			for rotation: int in range(4 if kind == &"urban_expansion" else 2):
				_append(state, content, result, _expansion(state, definition, copy_id, coordinate, rotation))
	if kind in [&"bridge", &"rewilding"]:
		for coordinate: Vector2i in state.expansion.board.sorted_coordinates():
			for rotation: int in range(2):
				_append(state, content, result, _occupied(state, definition, copy_id, coordinate, rotation))
	return result


static func matches(option: PlacementOption, command: PlaceTileCommand) -> bool:
	return (option.tile_copy_id == command.tile_copy_id and option.coordinate == command.coordinate
		and option.rotation == command.rotation and option.placement_mode == command.placement_mode
		and option.transformation_mode == command.transformation_mode
		and option.target_base_copy_id == command.target_base_copy_id
		and option.transformation_signature == command.transformation_signature
		and command.host_lineage_id == 0 and command.river_lineage_id == 0
		and command.enclosure_id == 0 and command.target_development_copy_id == 0)


static func _plan(state: RunState, definition: TileDefinition, copy_id: int,
		mode: StringName, rotation: int, target_id: int) -> TransformationState:
	var plan: TransformationState = TransformationState.new()
	plan.tile_copy_id = copy_id
	plan.definition_id = definition.definition_id
	plan.act_applied = state.expansion.current_act
	plan.placement_index = state.expansion.normal_placements + 1
	plan.mode = mode
	plan.orientation = rotation
	plan.target_base_copy_id = target_id
	return plan


static func underlying_bridge_target(cell: BoardCellState) -> bool:
	# Static identity is deliberately retained after Rewilding changes current banks.
	return cell != null and cell.definition_id == &"tile.river_run"


static func unresolved_rule(state: RunState, definition: TileDefinition, at: Vector2i) -> StringName:
	var cell: BoardCellState = state.expansion.board.get_cell(at)
	if cell == null:
		return &""
	if definition.transformation_kind == &"bridge" and underlying_bridge_target(cell):
		var axis: int = (cell.rotation + 1) % 2
		if cell.effective_edges[axis] == DomainTypes.EdgeType.FOREST \
			or cell.effective_edges[axis + 2] == DomainTypes.EdgeType.FOREST:
			return &"unresolved_bridge_rewilding_rewrite"
	if definition.transformation_kind == &"rewilding":
		for development: DevelopmentState in cell.developments:
			if development.stage == &"abbey":
				return &"unresolved_abbey_field_dependency"
	return &""


static func _occupied(state: RunState, definition: TileDefinition, copy_id: int,
		coordinate: Vector2i, rotation: int) -> TransformationState:
	var cell: BoardCellState = state.expansion.board.get_cell(coordinate)
	var bridge: bool = definition.transformation_kind == &"bridge"
	if bridge:
		if not underlying_bridge_target(cell) or rotation != (cell.rotation + 1) % 2:
			return null
		if TopologyService._has_type(cell, DomainTypes.FeatureType.ROAD):
			return null
	else:
		if not cell.has_field_geography:
			return null
		for development: DevelopmentState in cell.developments:
			if development.stage in [&"mill", &"monastery", &"abbey"]:
				# Abbey remains unavailable pending an explicit continued-Field ruling.
				return null
	var plan: TransformationState = _plan(state, definition, copy_id,
		&"bridge" if bridge else &"rewilding", rotation, cell.base_tile_copy_id)
	var change: TransformationChange = _change(state, cell)
	plan.changes.append(change)
	for direction: int in [rotation, rotation + 2]:
		# Bridge-on-Rewilded-Run eligibility is known; Forest->Road authorization is unresolved.
		if cell.effective_edges[direction] != DomainTypes.EdgeType.FIELD:
			return null
		change.after_edges[direction] = DomainTypes.EdgeType.ROAD if bridge else DomainTypes.EdgeType.FOREST
		var neighbor: BoardCellState = state.expansion.board.get_cell(coordinate + BoardState.ORTHOGONAL_OFFSETS[direction])
		if neighbor == null:
			continue
		var facing: int = (direction + 2) % 4
		if not bridge:
			if neighbor.effective_edges[facing] != DomainTypes.EdgeType.FOREST:
				return null
			continue
		if neighbor.effective_edges[facing] != DomainTypes.EdgeType.FIELD or not (
			TopologyService._has_type(neighbor, DomainTypes.FeatureType.ROAD)
			or TopologyService._has_type(neighbor, DomainTypes.FeatureType.SETTLEMENT)):
			return null
		var rewrite: TransformationChange = _change(state, neighbor)
		rewrite.after_edges[facing] = DomainTypes.EdgeType.ROAD
		plan.changes.append(rewrite)
	if not bridge:
		change.field_after = false
	return plan


static func _append(state: RunState, content: ContentRegistry, result: Array[PlacementOption],
		plan: TransformationState) -> void:
	if plan == null:
		return
	# The first change is always the target before canonical coordinate sorting.
	var coordinate: Vector2i = plan.changes[0].coordinate
	plan.changes.sort_custom(func(left: TransformationChange, right: TransformationChange) -> bool:
		return BoardState.coordinate_before(left.coordinate, right.coordinate))
	if not TransformationGeometry.validate(state, content, plan):
		return
	var option: PlacementOption = PlacementOption.new()
	option.placement_mode = DomainTypes.PlacementMode.TRANSFORMATION
	option.coordinate = coordinate
	option.rotation = plan.orientation
	option.tile_copy_id = plan.tile_copy_id
	option.board_revision = state.expansion.board.revision
	option.state_revision = state.expansion.state_revision
	option.transformation_mode = plan.mode
	option.target_base_copy_id = plan.target_base_copy_id
	option.transformation_signature = TransformationGeometry.signature(plan)
	option.transformation_plan = plan
	option.signature = option.canonical_signature()
	result.append(option)


static func _change(state: RunState, cell: BoardCellState) -> TransformationChange:
	var change: TransformationChange = TransformationChange.new()
	change.coordinate = cell.coordinate
	change.before_edges = cell.effective_edges.duplicate()
	change.after_edges = cell.effective_edges.duplicate()
	change.field_before = cell.has_field_geography
	change.field_after = cell.has_field_geography
	for type: int in range(4):
		var component: FeatureComponentState = state.features.component_at(cell.coordinate, type as DomainTypes.FeatureType)
		if component != null and component.lineage_id not in change.target_lineage_ids:
			change.target_lineage_ids.append(component.lineage_id)
	change.target_lineage_ids.sort()
	return change


static func _expansion(state: RunState, definition: TileDefinition, copy_id: int,
		coordinate: Vector2i, rotation: int) -> TransformationState:
	var urban: bool = definition.transformation_kind == &"urban_expansion"
	var plan: TransformationState = _plan(state, definition, copy_id,
		&"urban_expansion" if urban else &"rewilding_expansion", rotation, copy_id)
	var change: TransformationChange = TransformationChange.new()
	change.coordinate = coordinate
	change.after_edges = TileRotation.edges(definition.canonical_edges, rotation)
	change.field_after = true
	plan.changes.append(change)
	var rewrite_count: int = 0
	for direction: int in range(4):
		var neighbor: BoardCellState = state.expansion.board.get_cell(coordinate + BoardState.ORTHOGONAL_OFFSETS[direction])
		if neighbor == null:
			continue
		var facing: int = (direction + 2) % 4
		if change.after_edges[direction] == neighbor.effective_edges[facing]:
			continue
		var edge: DomainTypes.EdgeType = DomainTypes.EdgeType.SETTLEMENT if urban else DomainTypes.EdgeType.FOREST
		if change.after_edges[direction] != edge or neighbor.effective_edges[facing] != DomainTypes.EdgeType.FIELD \
			or not neighbor.has_field_geography:
			return null
		var component: FeatureComponentState = state.features.component_at(neighbor.coordinate, FeatureState.type_for_edge(edge))
		if component == null or (not urban and not state.features.lineage(component.lineage_id).completed):
			return null
		rewrite_count += 1
		if not urban and rewrite_count > 1:
			return null
		var rewrite: TransformationChange = _change(state, neighbor)
		rewrite.after_edges[facing] = edge
		plan.changes.append(rewrite)
	return plan
