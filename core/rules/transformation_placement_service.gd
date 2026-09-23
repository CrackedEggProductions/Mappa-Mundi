class_name TransformationPlacementService
extends RefCounted
## Commit a wholly revalidated plan, then resolve once from the final topology.


static func plan_for_command(state: RunState, content: ContentRegistry,
		command: PlaceTileCommand) -> TransformationState:
	for option: PlacementOption in TransformationPlacementQuery.query(state, content, command.tile_copy_id):
		if TransformationPlacementQuery.matches(option, command):
			return option.transformation_plan
	return null


static func place(state: RunState, content: ContentRegistry, command: PlaceTileCommand,
		plan: TransformationState) -> void:
	assert(plan != null, "Transformation intent must be validated before physical mutation")
	assert(plan.placement_index == state.expansion.normal_placements)
	var created_ids: Array[int] = []
	var target_lineages: Array[int] = []
	for change: TransformationChange in plan.changes:
		var cell: BoardCellState
		if change.before_edges.is_empty():
			cell = BoardCellState.from_definition(content.get_tile(plan.definition_id), plan.tile_copy_id,
				change.coordinate, plan.orientation, plan.act_applied, plan.placement_index)
			state.expansion.board.add_cell(cell)
		else:
			cell = state.expansion.board.get_cell(change.coordinate)
			cell.geometry_revision += 1
			state.expansion.board.revision += 1
		TransformationGeometry.rewrite(cell, change, plan.mode)
		var old_count: int = state.features.components.size()
		TopologyService.add_cell_components(state, cell, plan.act_applied, &"transformation", plan.tile_copy_id)
		for index: int in range(old_count, state.features.components.size()):
			var id: int = state.features.components[index].component_id
			change.created_component_ids.append(id)
			created_ids.append(id)
		for lineage_id: int in change.target_lineage_ids:
			if lineage_id not in target_lineages:
				target_lineages.append(lineage_id)
	state.expansion.board.get_cell(command.coordinate).transformations.append(plan)
	PhysicalTileRules.set_location(state, plan.tile_copy_id,
		TileLocationState.Kind.BOARD_BASE if plan.mode in [&"urban_expansion", &"rewilding_expansion"]
		else TileLocationState.Kind.BOARD_TRANSFORMATION)
	var event: FeatureHistoryRecord = FeatureHistoryRecord.new()
	event.event_id = state.id_allocator.allocate()
	event.kind = &"transformation_applied"
	event.act = plan.act_applied
	event.placement_index = plan.placement_index
	event.source_id = plan.tile_copy_id
	created_ids.sort()
	target_lineages.sort()
	event.component_ids = created_ids
	event.parent_ids = target_lineages
	state.features.history.append(event)
	FeatureResolutionService.resolve(state, plan.tile_copy_id)
