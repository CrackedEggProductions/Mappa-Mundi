class_name SpecialistPlacementService
extends RefCounted
## Private projected components prove occupancy legality without live mutation.


static func merge_is_legal(state: RunState, preview: RunState) -> bool:
	if state.specialists == null:
		return true
	for feature: CurrentFeature in TopologyService.rebuild(preview):
		var parents: Array[int] = LineageService._lineage_ids(preview, feature)
		var count: int = 0
		for piece: SpecialistPieceState in state.specialists.pieces:
			if piece.status == SpecialistPieceState.Status.ASSIGNED \
				and piece.assigned_target_type == feature.feature_type \
				and piece.assigned_target_id in parents:
				count += 1
		if count > 1:
			return false
	return true


static func expansion_is_legal(state: RunState, definition: TileDefinition,
		copy_id: int, coordinate: Vector2i, rotation: int) -> bool:
	if state.specialists == null or state.features == null:
		return true
	var preview: RunState = RunState.new(0)
	preview.expansion = ExpansionState.new()
	preview.expansion.board.cells = state.expansion.board.cells.duplicate()
	preview.features = FeatureState.new()
	preview.features.components = state.features.components.duplicate()
	preview.features.lineages = state.features.lineages.duplicate()
	var cell: BoardCellState = BoardCellState.from_definition(definition, copy_id,
		coordinate, rotation, state.expansion.current_act, state.expansion.normal_placements + 1)
	preview.expansion.board.cells[coordinate] = cell
	for type: int in range(4):
		if TopologyService._has_type(cell, type as DomainTypes.FeatureType):
			var component: FeatureComponentState = FeatureComponentState.new()
			component.component_id = -type - 1
			component.coordinate = coordinate
			component.feature_type = type as DomainTypes.FeatureType
			preview.features.components.append(component)
	return merge_is_legal(state, preview)


static func affected_targets(state: RunState, command: PlaceTileCommand,
		plan: TransformationState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	if command.placement_mode in [DomainTypes.PlacementMode.DEVELOPMENT, DomainTypes.PlacementMode.UPGRADE]:
		var development: DevelopmentState = DevelopmentService.find(state, command.tile_copy_id)
		if development.host_lineage_id != 0:
			_add(result, state.features.lineage(development.host_lineage_id).feature_type, development.host_lineage_id)
		elif development.enclosure_id != 0:
			_add(result, 4, development.enclosure_id)
		elif development.stage == &"mill":
			for feature: CurrentFeature in current:
				if feature.feature_type == DomainTypes.FeatureType.SETTLEMENT \
					and DevelopmentService.coordinate_touches_feature(state, command.coordinate, feature):
					_add(result, feature.feature_type, feature.lineage_id)
	else:
		for feature: CurrentFeature in current:
			if plan == null:
				if command.coordinate in feature.coordinates:
					_add(result, feature.feature_type, feature.lineage_id)
			else:
				for change: TransformationChange in plan.changes:
					if change.coordinate not in feature.coordinates:
						continue
					# New Road identity on a Settlement also creates explicit access.
					if plan.mode == &"bridge" and feature.feature_type != DomainTypes.FeatureType.ROAD:
						if feature.feature_type == DomainTypes.FeatureType.SETTLEMENT \
							and DomainTypes.EdgeType.ROAD not in change.before_edges:
							_add(result, feature.feature_type, feature.lineage_id)
						continue
					if change.before_edges.is_empty() or _changed_feature(change, feature.feature_type) \
						or (plan.mode == &"rewilding" and feature.feature_type == DomainTypes.FeatureType.RIVER) \
						or (plan.mode == &"rewilding" and feature.feature_type == DomainTypes.FeatureType.SETTLEMENT \
							and change.field_before and not change.field_after):
						_add(result, feature.feature_type, feature.lineage_id)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["target_type"] < b["target_type"] if a["target_type"] != b["target_type"] else a["target_id"] < b["target_id"])
	return result


static func committed_targets(state: RunState, source_id: int) -> Array[Dictionary]:
	# Reconstruct locality from the actual most recent placement, not saved UI intent.
	for at: Vector2i in state.expansion.board.sorted_coordinates():
		var cell: BoardCellState = state.expansion.board.get_cell(at)
		var command: PlaceTileCommand = PlaceTileCommand.new()
		command.tile_copy_id = source_id
		command.coordinate = at
		for transformation: TransformationState in cell.transformations:
			if transformation.tile_copy_id == source_id and transformation.placement_index == state.expansion.normal_placements \
				and transformation.act_applied == state.expansion.current_act:
				command.placement_mode = DomainTypes.PlacementMode.TRANSFORMATION
				return affected_targets(state, command, transformation)
		for development: DevelopmentState in cell.developments:
			if development.tile_copy_id == source_id and development.placement_index == state.expansion.normal_placements \
				and development.act_placed == state.expansion.current_act:
				command.placement_mode = DomainTypes.PlacementMode.DEVELOPMENT
				return affected_targets(state, command, null)
		if cell.base_tile_copy_id == source_id and cell.normal_placement_index == state.expansion.normal_placements \
			and cell.act_placed == state.expansion.current_act:
			command.placement_mode = DomainTypes.PlacementMode.EXPANSION
			return affected_targets(state, command, null)
	return []


static func _changed_feature(change: TransformationChange, type: int) -> bool:
	var edge: int = FeatureState.edge_for_type(type as DomainTypes.FeatureType)
	for direction: int in range(4):
		if change.before_edges[direction] != change.after_edges[direction] \
			and edge in [change.before_edges[direction], change.after_edges[direction]]:
			return true
	return false


static func _add(targets: Array[Dictionary], type: int, id: int) -> void:
	var entry: Dictionary = {"target_type": type, "target_id": id}
	if entry not in targets:
		targets.append(entry)
