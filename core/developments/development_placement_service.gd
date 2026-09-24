class_name DevelopmentPlacementService
extends RefCounted
## Internal mutation after complete RulesEngine validation and source-slot removal.


static func place(state: RunState, content: ContentRegistry, command: PlaceTileCommand, immediate: bool = true) -> void:
	var copy: TileCopyState = PhysicalTileRules.find_copy(state, command.tile_copy_id)
	var definition: TileDefinition = content.get_tile(copy.definition_id)
	var cell: BoardCellState = state.expansion.board.get_cell(command.coordinate)
	var development: DevelopmentState = DevelopmentState.new()
	development.tile_copy_id = copy.tile_copy_id
	development.family_id = definition.development_family_id
	development.host_kind = definition.development_host_kind
	development.host_lineage_id = command.host_lineage_id
	development.river_lineage_id = command.river_lineage_id
	development.enclosure_id = command.enclosure_id
	development.act_placed = state.expansion.current_act
	development.placement_index = state.expansion.normal_placements
	development.stage = definition.development_stage
	development.replaced_copy_id = command.target_development_copy_id
	var event_kind: StringName = &"development_placed"
	if command.placement_mode == DomainTypes.PlacementMode.UPGRADE:
		var old: DevelopmentState = DevelopmentService.find(state, command.target_development_copy_id)
		var index: int = cell.developments.find(old)
		cell.developments[index] = development
		state.expansion.removed_ids.append(old.tile_copy_id)
		PhysicalTileRules.set_location(state, old.tile_copy_id, TileLocationState.Kind.REMOVED_FROM_RUN)
		event_kind = &"development_upgraded"
	else:
		cell.developments.append(development)
	PhysicalTileRules.set_location(state, copy.tile_copy_id, TileLocationState.Kind.BOARD_DEVELOPMENT)
	if development.host_kind == &"enclosure":
		_install_enclosure(state, development, command.coordinate)
	var event: FeatureHistoryRecord = FeatureScoringService._event(state, event_kind, copy.tile_copy_id)
	event.lineage_id = development.host_lineage_id
	if development.host_lineage_id != 0:
		event.feature_type = state.features.lineage(development.host_lineage_id).feature_type
	if development.replaced_copy_id != 0:
		event.parent_ids.append(development.replaced_copy_id)
	state.features.history.append(event)
	if development.replaced_copy_id != 0:
		var replaced: FeatureHistoryRecord = FeatureScoringService._event(state, &"development_replaced", development.replaced_copy_id)
		replaced.parent_event_id = event.event_id
		replaced.parent_ids.append(copy.tile_copy_id)
		state.features.history.append(replaced)
	# Overlays do not rebuild geometry or create completion transitions for hosts.
	DevelopmentService.remap_hosts(state, TopologyService.rebuild(state))
	if immediate:
		DevelopmentEffects.immediate(state, copy.tile_copy_id, event.event_id)
	elif state.resolution != null:
		state.resolution.immediate_development_copy_id = copy.tile_copy_id
		state.resolution.immediate_parent_event_id = event.event_id


static func _install_enclosure(state: RunState, development: DevelopmentState, coordinate: Vector2i) -> void:
	var enclosure: EnclosureState = null
	if development.enclosure_id != 0:
		for candidate: EnclosureState in state.features.enclosures:
			if candidate.enclosure_id == development.enclosure_id:
				enclosure = candidate
				break
	else:
		enclosure = EnclosureState.new()
		enclosure.enclosure_id = state.id_allocator.allocate()
		enclosure.coordinate = coordinate
		state.features.enclosures.append(enclosure)
		development.enclosure_id = enclosure.enclosure_id
	assert(enclosure != null, "Validated Upgrade enclosure must exist")
	enclosure.development_tile_copy_id = development.tile_copy_id
	enclosure.stage = development.stage
