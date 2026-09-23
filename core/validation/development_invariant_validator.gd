class_name DevelopmentInvariantValidator
extends RefCounted
## Check physical overlays after base topology validation; never reconcile on load.


static func validate(state: RunState, content: ContentRegistry, report: InvariantReport) -> void:
	var placements: Dictionary[int, FeatureHistoryRecord] = {}
	var replacements: Dictionary[int, int] = {}
	for event: FeatureHistoryRecord in state.features.history:
		if event.kind in [&"development_placed", &"development_upgraded"]:
			if placements.has(event.source_id):
				report.add(&"duplicate_development_play", "Physical Development can be played only once.")
			placements[event.source_id] = event
			var tile: TileCopyState = PhysicalTileRules.find_copy(state, event.source_id)
			var definition: TileDefinition = content.get_tile(tile.definition_id) if tile != null else null
			if definition == null or definition.tile_class not in [DomainTypes.TileClass.DEVELOPMENT, DomainTypes.TileClass.UPGRADE]:
				report.add(&"invalid_development_play", "Development play requires a physical overlay design.")
			elif event.act < definition.unlock_act or event.placement_index <= 0:
				report.add(&"invalid_development_unlock", "Development placement must respect unlock and placement index.")
			if event.kind == &"development_upgraded":
				if event.parent_ids.size() != 1 or definition == null:
					report.add(&"invalid_upgrade_history", "Upgrade must identify exactly one replaced copy.")
					continue
				var old_id: int = event.parent_ids[0]
				var old: TileCopyState = PhysicalTileRules.find_copy(state, old_id)
				if old == null or old.definition_id != definition.upgrade_from_definition_id or old_id in replacements \
					or old_id not in state.expansion.removed_ids or not placements.has(old_id):
					report.add(&"invalid_upgrade_prerequisite", "Replaced prerequisite must have been played and removed exactly once.")
				replacements[old_id] = event.source_id
			elif not event.parent_ids.is_empty():
				report.add(&"unexpected_development_parent", "Ordinary placement has no replaced copy.")
	for old_id: int in replacements:
		var audit_count: int = 0
		for event: FeatureHistoryRecord in state.features.history:
			if event.kind == &"development_replaced" and event.source_id == old_id and event.parent_ids == [replacements[old_id]]:
				audit_count += 1
		if audit_count != 1:
			report.add(&"missing_replacement_audit", "Physical replacement requires one reciprocal audit record.")
	for coordinate: Vector2i in state.expansion.board.sorted_coordinates():
		var cell: BoardCellState = state.expansion.board.get_cell(coordinate)
		if cell.developments.size() > 1:
			report.add(&"occupied_development_slot", "Current rules allow only one Development per tile.")
		for development: DevelopmentState in cell.developments:
			_validate_overlay(state, content, cell, development, placements, report)
	for copy_id: int in placements:
		if DevelopmentService.find(state, copy_id) == null and not replacements.has(copy_id):
			report.add(&"missing_development_overlay", "Played Development must remain on board or have replacement history.")
	_validate_effects(state, content, report)


static func _validate_overlay(state: RunState, content: ContentRegistry, cell: BoardCellState,
		development: DevelopmentState, placements: Dictionary, report: InvariantReport) -> void:
	var copy: TileCopyState = PhysicalTileRules.find_copy(state, development.tile_copy_id)
	var definition: TileDefinition = content.get_tile(copy.definition_id) if copy != null else null
	if definition == null or definition.tile_class not in [DomainTypes.TileClass.DEVELOPMENT, DomainTypes.TileClass.UPGRADE]:
		report.add(&"invalid_development_copy", "Overlay requires a physical Development or Upgrade.")
		return
	if development.family_id != definition.development_family_id or development.stage != definition.development_stage \
		or development.host_kind != definition.development_host_kind:
		report.add(&"invalid_development_identity", "Family, stage and host kind must match static definition.")
	if development.act_placed < definition.unlock_act or development.act_placed > state.expansion.current_act \
		or development.act_placed < copy.acquired_act or development.placement_index <= cell.normal_placement_index \
		or development.placement_index > state.expansion.normal_placements:
		report.add(&"invalid_development_placement", "Overlay placement metadata must follow its base and acquisition.")
	var event: FeatureHistoryRecord = placements.get(development.tile_copy_id)
	if event == null or event.act != development.act_placed or event.placement_index != development.placement_index:
		report.add(&"development_placement_history", "Overlay must retain its physical placement audit.")
	elif definition.tile_class == DomainTypes.TileClass.UPGRADE:
		if event.kind != &"development_upgraded" or event.parent_ids != [development.replaced_copy_id]:
			report.add(&"upgrade_replacement_mismatch", "Upgrade slot must agree with the replaced physical identity.")
	elif development.replaced_copy_id != 0 or event.kind != &"development_placed":
		report.add(&"invalid_ordinary_replacement", "Ordinary Development cannot replace a prior copy.")
	if development.host_kind in [&"settlement", &"forest"]:
		var type: DomainTypes.FeatureType = DomainTypes.FeatureType.SETTLEMENT if development.host_kind == &"settlement" else DomainTypes.FeatureType.FOREST
		var component: FeatureComponentState = state.features.component_at(cell.coordinate, type)
		if component == null or component.lineage_id != development.host_lineage_id or development.enclosure_id != 0:
			report.add(&"invalid_development_host", "Overlay must follow the current lineage of its specific host geography.")
	elif development.host_kind in [&"field", &"enclosure"]:
		if not cell.effective_edges.has(DomainTypes.EdgeType.FIELD) or development.host_lineage_id != 0:
			report.add(&"invalid_field_development", "Field/enclosure Development requires current Field geography and no feature host.")
		if development.host_kind == &"enclosure":
			var found: bool = false
			for enclosure: EnclosureState in state.features.enclosures:
				if enclosure.enclosure_id == development.enclosure_id and enclosure.coordinate == cell.coordinate \
					and enclosure.development_tile_copy_id == development.tile_copy_id and enclosure.stage == development.stage:
					found = true
			if not found:
				report.add(&"invalid_development_enclosure", "Overlay must resolve its persistent enclosure and current stage.")
		elif development.enclosure_id != 0:
			report.add(&"unexpected_enclosure_host", "Mill has no enclosure association.")
	if development.stage == &"port":
		if development.river_lineage_id not in DevelopmentService.port_rivers(state, cell.coordinate, development.host_lineage_id):
			report.add(&"invalid_port_association", "Port must retain a currently connected River with canonical contact.")
	elif development.river_lineage_id != 0:
		report.add(&"unexpected_river_association", "Only Port permanently associates with River lineage.")


static func _validate_effects(state: RunState, content: ContentRegistry, report: InvariantReport) -> void:
	var events: Dictionary[int, FeatureHistoryRecord] = {}
	for event: FeatureHistoryRecord in state.features.history:
		if event.kind in [&"development_immediate_effect", &"development_completion_trigger"]:
			var copy: TileCopyState = PhysicalTileRules.find_copy(state, event.source_id)
			var definition: TileDefinition = content.get_tile(copy.definition_id) if copy != null else null
			var parent: FeatureHistoryRecord = events.get(event.parent_event_id)
			if definition == null or definition.development_family_id == &"" or parent == null:
				report.add(&"invalid_development_effect", "Development trigger requires a physical design and preceding parent.")
			elif event.kind == &"development_immediate_effect" and (parent.kind not in [&"development_placed", &"development_upgraded"] or parent.source_id != event.source_id):
				report.add(&"invalid_immediate_effect_parent", "Immediate effect belongs only to the newly played copy.")
			elif event.kind == &"development_completion_trigger" and parent.kind != &"completion_snapshot":
				report.add(&"invalid_completion_effect_parent", "Development completion effects use the shared snapshot parent.")
		events[event.event_id] = event
