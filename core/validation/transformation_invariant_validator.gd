class_name TransformationInvariantValidator
extends RefCounted
## Validate persisted physical provenance and geometry history without replaying gameplay.

const NEW_BASE_MODES: Array[StringName] = [&"urban_expansion", &"rewilding_expansion"]
const MODES: Array[StringName] = [&"urban_expansion", &"rewilding_expansion", &"bridge", &"rewilding"]


static func validate(state: RunState, content: ContentRegistry, report: InvariantReport) -> void:
	var copies: Dictionary[int, TransformationState] = {}
	var chains: Dictionary = {}
	var created_ids: Array[int] = []
	for coordinate: Vector2i in state.expansion.board.sorted_coordinates():
		var cell: BoardCellState = state.expansion.board.get_cell(coordinate)
		for transformation: TransformationState in cell.transformations:
			if transformation == null:
				report.add(&"null_transformation", "Transformation history cannot contain null.")
				continue
			if copies.has(transformation.tile_copy_id):
				report.add(&"duplicate_transformation", "Each physical Transformation has one target record.")
			copies[transformation.tile_copy_id] = transformation
			_validate_identity(state, content, cell, transformation, report)
			var coordinates: Array[Vector2i] = []
			for change: TransformationChange in transformation.changes:
				if change == null or not state.expansion.board.cells.has(change.coordinate):
					report.add(&"invalid_transformation_change", "Every geometry change requires an occupied coordinate.")
					continue
				if change.coordinate in coordinates:
					report.add(&"duplicate_transformation_change", "One Transformation records each affected square once.")
				coordinates.append(change.coordinate)
				_validate_change(state, cell, transformation, change, created_ids, report)
				if not chains.has(change.coordinate):
					chains[change.coordinate] = []
				chains[change.coordinate].append({"transformation": transformation, "change": change})
			if coordinate not in coordinates:
				report.add(&"missing_transformation_target", "Transformation history must include its target square.")
	for coordinate: Vector2i in chains:
		_validate_chain(state, content, coordinate, chains[coordinate], report)
	for component: FeatureComponentState in state.features.components:
		if component.origin_source_type == &"transformation" and component.component_id not in created_ids:
			report.add(&"missing_transformation_provenance", "Transformation components require a matching creation record.")
	_validate_audit(state, copies, report)


static func _validate_identity(state: RunState, content: ContentRegistry, cell: BoardCellState,
		value: TransformationState, report: InvariantReport) -> void:
	var copy: TileCopyState = PhysicalTileRules.find_copy(state, value.tile_copy_id)
	var definition: TileDefinition = content.get_tile(value.definition_id)
	if copy == null or definition == null or copy.definition_id != value.definition_id \
		or definition.tile_class != DomainTypes.TileClass.TRANSFORMATION:
		report.add(&"invalid_transformation_identity", "Transformation definition and physical copy must agree.")
		return
	var expected_kind: StringName = &"rewilding" if value.mode == &"rewilding_expansion" else value.mode
	if value.mode not in MODES or expected_kind != definition.transformation_kind:
		report.add(&"invalid_transformation_mode", "Transformation mode must match its static design.")
	var maximum_changes: int = 2 if value.mode == &"rewilding_expansion" else (1 if value.mode == &"rewilding" else 3)
	if value.changes.size() > maximum_changes:
		report.add(&"excess_transformation_changes", "Transformation exceeds its canonical affected-square count.")
	if value.mode == &"bridge" and (cell.definition_id != &"tile.river_run" or value.orientation != (cell.rotation + 1) % 2):
		report.add(&"invalid_bridge_axis", "Bridge crosses its underlying straight River Run perpendicularly.")
	if value.target_base_copy_id != cell.base_tile_copy_id or value.changes.is_empty() \
		or value.orientation < 0 or value.orientation > (3 if value.mode == &"urban_expansion" else 1):
		report.add(&"invalid_transformation_target", "Transformation target, orientation and changes must be explicit.")
	if value.act_applied < definition.unlock_act or value.act_applied < copy.acquired_act \
		or value.act_applied > state.expansion.current_act or value.act_applied < cell.act_placed \
		or value.placement_index <= 0 or value.placement_index > PlacementChronology.count_for_act(state, value.act_applied):
		report.add(&"invalid_transformation_age", "Transformation application must follow acquisition and host construction.")
	if value.mode in NEW_BASE_MODES:
		if value.tile_copy_id != cell.base_tile_copy_id or value.placement_index != cell.normal_placement_index \
			or value.act_applied != cell.act_placed or value.orientation != cell.rotation:
			report.add(&"invalid_transformation_base", "Specialized Expansion identity must match its new physical base.")
	elif value.tile_copy_id == cell.base_tile_copy_id or PlacementChronology.rank(state, value.tile_copy_id, value.act_applied, value.placement_index) \
		<= PlacementChronology.rank(state, cell.base_tile_copy_id, cell.act_placed, cell.normal_placement_index):
		report.add(&"invalid_transformation_overlay", "Occupied Transformation must be a later separate physical copy.")


static func _validate_change(state: RunState, host: BoardCellState, value: TransformationState,
		change: TransformationChange, created_ids: Array[int], report: InvariantReport) -> void:
	var cell: BoardCellState = state.expansion.board.get_cell(change.coordinate)
	var is_new: bool = value.mode in NEW_BASE_MODES and change.coordinate == host.coordinate
	if change.after_edges.size() != 4 or change.before_edges.size() != (0 if is_new else 4):
		report.add(&"invalid_transformation_edges", "Geometry records require four edges except an empty new-base predecessor.")
		return
	var base_rank: int = PlacementChronology.rank(state, cell.base_tile_copy_id, cell.act_placed, cell.normal_placement_index)
	var change_rank: int = PlacementChronology.rank(state, value.tile_copy_id, value.act_applied, value.placement_index)
	if base_rank > change_rank or (not is_new and base_rank == change_rank):
		report.add(&"invalid_transformation_chronology", "A changed existing cell must predate its Transformation.")
	if not FeatureInvariantValidator._unique_positive(change.target_lineage_ids) \
		or not FeatureInvariantValidator._unique_positive(change.created_component_ids):
		report.add(&"duplicate_transformation_fact", "Transformation provenance sets require unique positive identities.")
	for lineage_id: int in change.target_lineage_ids:
		var lineage: FeatureLineageState = state.features.lineage(lineage_id)
		var belongs: bool = false
		if lineage != null:
			for member_id: int in lineage.member_ids:
				var member: FeatureComponentState = state.features.component(member_id)
				if member != null and member.coordinate == change.coordinate:
					belongs = true
		if not belongs:
			report.add(&"invalid_transformation_lineage", "Target lineage must retain a component at the changed coordinate.")
	for component_id: int in change.created_component_ids:
		var component: FeatureComponentState = state.features.component(component_id)
		if component_id in created_ids or component == null:
			report.add(&"invalid_created_component", "Created component must resolve and have exactly one Transformation origin.")
			continue
		created_ids.append(component_id)
		if component.origin_source_type != &"transformation" or component.origin_source_runtime_id != value.tile_copy_id \
			or component.coordinate != change.coordinate or component.origin_act != value.act_applied:
			report.add(&"transformation_origin_mismatch", "Component origin must identify its creating physical Transformation and Act.")
		var edge: int = FeatureState.edge_for_type(component.feature_type)
		if edge not in change.after_edges or edge in change.before_edges:
			report.add(&"invalid_transformation_growth", "Only genuinely added component geography is new scoring growth.")
	for edge: int in range(1, 5):
		if edge not in change.after_edges or edge in change.before_edges:
			continue
		var component: FeatureComponentState = state.features.component_at(change.coordinate,
			FeatureState.type_for_edge(edge as DomainTypes.EdgeType))
		if component == null or component.component_id not in change.created_component_ids:
			report.add(&"unrecorded_transformation_growth", "Every added feature type requires recorded Transformation provenance.")
	if is_new:
		if not change.before_edges.is_empty() or change.field_before or not change.target_lineage_ids.is_empty():
			report.add(&"invalid_new_base_history", "A new base has no prior geography or feature host.")
		return
	_validate_delta(state, host, value, change, report)


static func _validate_delta(state: RunState, host: BoardCellState, value: TransformationState,
		change: TransformationChange, report: InvariantReport) -> void:
	var changed: int = 0
	for direction: int in range(4):
		var before: int = change.before_edges[direction]
		var after: int = change.after_edges[direction]
		if before not in DomainTypes.EdgeType.values() or after not in DomainTypes.EdgeType.values():
			report.add(&"unknown_transformation_edge", "Geometry history contains an unknown edge type.")
		if before == after:
			continue
		changed += 1
		var allowed: bool = false
		match value.mode:
			&"urban_expansion":
				allowed = before == DomainTypes.EdgeType.FIELD and after == DomainTypes.EdgeType.SETTLEMENT
			&"rewilding", &"rewilding_expansion":
				allowed = before == DomainTypes.EdgeType.FIELD and after == DomainTypes.EdgeType.FOREST
			&"bridge":
				allowed = after == DomainTypes.EdgeType.ROAD and before == DomainTypes.EdgeType.FIELD
		if not allowed:
			report.add(&"illegal_transformation_rewrite", "Transformation history cannot overwrite unrelated built or River edges.")
	if changed == 0:
		report.add(&"empty_transformation_change", "Occupied change must actually rewrite geometry.")
	if value.mode == &"bridge" and change.field_after != change.field_before:
		report.add(&"bridge_field_loss", "Bridge preserves current interior Field geography.")
	if value.mode == &"rewilding" and (not change.field_before or change.field_after):
		report.add(&"invalid_rewilding_field", "Occupied Rewilding consumes existing Field geography.")
	if value.mode in NEW_BASE_MODES:
		if not change.field_before or not change.field_after:
			report.add(&"invalid_boundary_field", "Boundary-only rewrite requires and preserves the existing Field interior.")
		var required_type: int = DomainTypes.FeatureType.SETTLEMENT if value.mode == &"urban_expansion" else DomainTypes.FeatureType.FOREST
		var matching_host: bool = false
		for lineage_id: int in change.target_lineage_ids:
			var lineage: FeatureLineageState = state.features.lineage(lineage_id)
			if lineage != null and lineage.feature_type == required_type:
				matching_host = true
		if not matching_host:
			report.add(&"missing_boundary_feature", "Boundary rewrite must belong to the canonical existing host type.")
		var displacement: Vector2i = change.coordinate - host.coordinate
		if absi(displacement.x) + absi(displacement.y) != 1 or changed != 1:
			report.add(&"invalid_boundary_rewrite", "Specialized Expansion changes one facing edge of an orthogonal neighbor.")
		else:
			var direction: int = BoardState.ORTHOGONAL_OFFSETS.find(displacement)
			var facing: int = (direction + 2) % 4
			if direction % 2 != value.orientation % 2 or change.before_edges[facing] == change.after_edges[facing]:
				report.add(&"invalid_boundary_axis", "Rewritten boundary must face the new base on its feature axis.")
	elif change.coordinate == host.coordinate:
		if changed != 2:
			report.add(&"invalid_transformation_axis", "Occupied Transformation rewrites exactly two opposite target edges.")
		for direction: int in range(4):
			if (change.before_edges[direction] != change.after_edges[direction]) != (direction % 2 == value.orientation):
				report.add(&"invalid_transformation_axis", "Target edge changes must follow the selected opposite axis.")
	elif value.mode == &"bridge":
		var displacement: Vector2i = change.coordinate - host.coordinate
		var direction: int = BoardState.ORTHOGONAL_OFFSETS.find(displacement)
		if direction < 0 or direction % 2 != value.orientation or changed != 1:
			report.add(&"invalid_bridge_neighbor", "Bridge changes only its two Road-axis neighboring boundaries.")
		elif change.before_edges[(direction + 2) % 4] == change.after_edges[(direction + 2) % 4]:
			report.add(&"invalid_bridge_facing_edge", "Neighbor rewrite must face the Bridge target.")
		var had_built_host: bool = false
		for lineage_id: int in change.target_lineage_ids:
			var lineage: FeatureLineageState = state.features.lineage(lineage_id)
			if lineage != null and lineage.feature_type in [DomainTypes.FeatureType.ROAD, DomainTypes.FeatureType.SETTLEMENT]:
				had_built_host = true
		if not had_built_host:
			report.add(&"missing_bridge_neighbor_host", "Neighbor rewrite requires a prior Road or Settlement feature.")
		var neighbor: BoardCellState = state.expansion.board.get_cell(change.coordinate)
		if TopologyService._has_type(neighbor, DomainTypes.FeatureType.SETTLEMENT):
			var access: bool = false
			for relationship: TileFeatureRelationship in neighbor.relationships:
				if relationship.kind == TileFeatureRelationship.Kind.ROAD_SETTLEMENT_ACCESS:
					access = true
			if not access:
				report.add(&"missing_bridge_access", "Rewritten Settlement neighbor must retain explicit Road access.")



static func _validate_chain(state: RunState, content: ContentRegistry, coordinate: Vector2i,
		chain: Array, report: InvariantReport) -> void:
	chain.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first: TransformationState = a["transformation"]
		var second: TransformationState = b["transformation"]
		return PlacementChronology.rank(state, first.tile_copy_id, first.act_applied, first.placement_index) \
			< PlacementChronology.rank(state, second.tile_copy_id, second.act_applied, second.placement_index))
	var cell: BoardCellState = state.expansion.board.get_cell(coordinate)
	var occupied_changes: int = 0
	var previous: TransformationChange = null
	for entry: Dictionary in chain:
		var change: TransformationChange = entry["change"]
		if not change.before_edges.is_empty():
			occupied_changes += 1
		if previous != null and (previous.after_edges != change.before_edges or previous.field_after != change.field_before):
			report.add(&"broken_transformation_chain", "Each Transformation must preserve its predecessor's resulting geometry.")
		previous = change
	if cell.geometry_revision < occupied_changes:
		report.add(&"missing_geometry_revision", "Every occupied-cell rewrite must advance geometry revision.")
	if previous.after_edges != cell.effective_edges or previous.field_after != cell.has_field_geography:
		report.add(&"transformation_current_geometry_mismatch", "Latest history must exactly reproduce current geography.")
	var first: TransformationChange = chain[0]["change"]
	var definition: TileDefinition = content.get_tile(cell.definition_id)
	if definition != null and (first.before_edges.is_empty() or cell.geometry_revision == occupied_changes):
		var edges: Array[DomainTypes.EdgeType] = first.after_edges if first.before_edges.is_empty() else first.before_edges
		var field: bool = first.field_after if first.before_edges.is_empty() else first.field_before
		if edges != TileRotation.edges(definition.canonical_edges, cell.rotation) \
			or field != definition.canonical_edges.has(DomainTypes.EdgeType.FIELD):
			report.add(&"transformation_base_geometry_mismatch", "First Transformation must agree with the unmodified physical base.")


static func _validate_audit(state: RunState, copies: Dictionary, report: InvariantReport) -> void:
	var seen: Array[int] = []
	for event: FeatureHistoryRecord in state.features.history:
		if event.kind != &"transformation_applied":
			continue
		if event.source_id in seen or not copies.has(event.source_id):
			report.add(&"invalid_transformation_audit", "Each Transformation event requires one matching physical instance.")
			continue
		seen.append(event.source_id)
		var value: TransformationState = copies[event.source_id]
		var components: Array[int] = []
		var lineages: Array[int] = []
		for change: TransformationChange in value.changes:
			if change == null:
				continue
			components.append_array(change.created_component_ids)
			for lineage_id: int in change.target_lineage_ids:
				if lineage_id not in lineages:
					lineages.append(lineage_id)
		components.sort()
		lineages.sort()
		var actual_components: Array[int] = event.component_ids.duplicate()
		var actual_lineages: Array[int] = event.parent_ids.duplicate()
		actual_components.sort()
		actual_lineages.sort()
		if event.act != value.act_applied or event.placement_index != value.placement_index \
			or actual_components != components or actual_lineages != lineages:
			report.add(&"transformation_audit_mismatch", "Application audit must agree with physical age and provenance sets.")
	for copy_id: int in copies:
		if copy_id not in seen:
			report.add(&"missing_transformation_audit", "Every applied Transformation requires its structured history event.")
