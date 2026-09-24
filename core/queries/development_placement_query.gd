class_name DevelopmentPlacementQuery
extends RefCounted
## Complete, deterministic overlay intents; no rotation aliases or UI-selected hosts.


static func query(state: RunState, content: ContentRegistry, copy_id: int) -> Array[PlacementOption]:
	var result: Array[PlacementOption] = []
	if state.expansion == null or state.features == null:
		return result
	var copy: TileCopyState = PhysicalTileRules.find_copy(state, copy_id)
	if copy == null:
		return result
	var definition: TileDefinition = content.get_tile(copy.definition_id)
	if definition == null or definition.unlock_act > state.expansion.current_act:
		return result
	if definition.tile_class not in [DomainTypes.TileClass.DEVELOPMENT, DomainTypes.TileClass.UPGRADE]:
		return result
	for coordinate: Vector2i in state.expansion.board.sorted_coordinates():
		var cell: BoardCellState = state.expansion.board.get_cell(coordinate)
		if definition.tile_class == DomainTypes.TileClass.UPGRADE:
			var targets: Array[DevelopmentState] = cell.developments.duplicate()
			targets.sort_custom(func(a: DevelopmentState, b: DevelopmentState) -> bool:
				return a.tile_copy_id < b.tile_copy_id)
			for target: DevelopmentState in targets:
				var base: TileCopyState = PhysicalTileRules.find_copy(state, target.tile_copy_id)
				if base == null or base.definition_id != definition.upgrade_from_definition_id:
					continue
				var option: PlacementOption = _option(state, copy_id, coordinate, DomainTypes.PlacementMode.UPGRADE)
				option.host_lineage_id = target.host_lineage_id
				option.river_lineage_id = target.river_lineage_id
				option.enclosure_id = target.enclosure_id
				option.target_development_copy_id = target.tile_copy_id
				_append(result, option)
			continue
		if not cell.developments.is_empty():
			continue
		if definition.development_host_kind == &"enclosure" and _has_enclosure(state, coordinate):
			continue
		var host: int = 0
		if definition.development_host_kind in [&"field", &"enclosure"]:
			if not cell.has_field_geography:
				continue
		elif definition.development_host_kind in [&"settlement", &"forest"]:
			var type: DomainTypes.FeatureType = DomainTypes.FeatureType.SETTLEMENT if definition.development_host_kind == &"settlement" else DomainTypes.FeatureType.FOREST
			var component: FeatureComponentState = state.features.component_at(coordinate, type)
			if component == null:
				continue
			host = component.lineage_id
		else:
			continue
		var rivers: Array[int] = [0]
		if definition.development_stage == &"port":
			rivers = DevelopmentService.port_rivers(state, coordinate, host)
		for river_id: int in rivers:
			var option: PlacementOption = _option(state, copy_id, coordinate, DomainTypes.PlacementMode.DEVELOPMENT)
			option.host_lineage_id = host
			option.river_lineage_id = river_id
			_append(result, option)
	return result


static func matches(option: PlacementOption, command: PlaceTileCommand) -> bool:
	return (option.tile_copy_id == command.tile_copy_id and option.coordinate == command.coordinate
		and option.rotation == command.rotation and option.placement_mode == command.placement_mode
		and option.host_lineage_id == command.host_lineage_id
		and option.river_lineage_id == command.river_lineage_id
		and option.enclosure_id == command.enclosure_id
		and option.target_development_copy_id == command.target_development_copy_id)


static func _option(state: RunState, copy_id: int, coordinate: Vector2i,
		mode: DomainTypes.PlacementMode) -> PlacementOption:
	var option: PlacementOption = PlacementOption.new()
	option.tile_copy_id = copy_id
	option.coordinate = coordinate
	option.placement_mode = mode
	option.board_revision = state.expansion.board.revision
	option.state_revision = state.expansion.state_revision
	return option


static func _append(options: Array[PlacementOption], option: PlacementOption) -> void:
	option.signature = option.canonical_signature()
	options.append(option)


static func _has_enclosure(state: RunState, coordinate: Vector2i) -> bool:
	for enclosure: EnclosureState in state.features.enclosures:
		if enclosure.coordinate == coordinate:
			return true
	return false
