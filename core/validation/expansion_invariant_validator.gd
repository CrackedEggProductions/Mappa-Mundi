class_name ExpansionInvariantValidator
extends RefCounted
## Phase-2 physical zones and local geometry only; no connected feature topology.

const FOUNDING_ID: StringName = &"tile.founding.homestead"
const OFFSETS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


static func validate(state: RunState, content: ContentRegistry, report: InvariantReport) -> void:
	var expansion: ExpansionState = state.expansion
	var config: RunConfig = content.get_config()
	_validate_turn(state, config, report)
	if expansion.board == null:
		report.add(&"missing_board", "Initialized expansion state requires a sparse board.")
		return
	var represented: Array[int] = []
	_validate_zone(state, expansion.bag, TileLocationState.Kind.BAG, represented, report)
	_validate_zone(state, expansion.hand, TileLocationState.Kind.ACTIVE_HAND, represented, report)
	_validate_zone(state, RelicHandRules.reserve_ids(state), TileLocationState.Kind.RESERVE, represented, report)
	_validate_zone(state, expansion.inspected_ids, TileLocationState.Kind.INSPECTED, represented, report)
	if expansion.reserve_extra_id > 0 and RelicHandRules.reserve_capacity(state) < 2:
		report.add(&"illegal_extra_reserve", "The second Reserve slot requires an equipped Satchel.")
	_validate_zone(state, expansion.removed_ids, TileLocationState.Kind.REMOVED_FROM_RUN, represented, report)
	var board_ids: Array[int] = []
	var development_ids: Array[int] = []
	var transformation_ids: Array[int] = []
	var placement_indices: Array[int] = []
	for coordinate: Vector2i in expansion.board.sorted_coordinates():
		var cell: BoardCellState = expansion.board.cells[coordinate]
		if cell == null:
			report.add(&"missing_board_cell", "Occupied coordinate has a null cell.")
			continue
		board_ids.append(cell.base_tile_copy_id)
		for development: DevelopmentState in cell.developments:
			if development == null:
				report.add(&"null_development", "Development slots cannot contain null.")
			else:
				development_ids.append(development.tile_copy_id)
		for transformation: TransformationState in cell.transformations:
			if transformation == null:
				report.add(&"null_transformation", "Transformation history cannot contain null.")
			elif transformation.mode not in [&"urban_expansion", &"rewilding_expansion"]:
				transformation_ids.append(transformation.tile_copy_id)
				if transformation.placement_index in placement_indices:
					report.add(&"duplicate_placement_index", "Occupied Transformations consume unique normal placements.")
				placement_indices.append(transformation.placement_index)
		_validate_cell(state, content, coordinate, cell, report)
		if cell.normal_placement_index in placement_indices:
			report.add(&"duplicate_placement_index", "Each placed base has a unique normal placement index.", cell.base_tile_copy_id)
		placement_indices.append(cell.normal_placement_index)
	_validate_zone(state, board_ids, TileLocationState.Kind.BOARD_BASE, represented, report)
	_validate_zone(state, development_ids, TileLocationState.Kind.BOARD_DEVELOPMENT, represented, report)
	_validate_zone(state, transformation_ids, TileLocationState.Kind.BOARD_TRANSFORMATION, represented, report)
	for tile: TileCopyState in state.tile_copies:
		if tile != null and tile.tile_copy_id not in represented:
			report.add(&"unrepresented_tile", "Physical location has no matching zone/container entry.", tile.tile_copy_id)
		if tile != null and tile.acquired_act > expansion.current_act:
			report.add(&"future_acquisition", "Physical copies cannot be acquired in a future Act.", tile.tile_copy_id)
		if tile != null and tile.definition_id == FOUNDING_ID:
			var origin: BoardCellState = expansion.board.cells.get(Vector2i.ZERO)
			if origin == null or origin.base_tile_copy_id != tile.tile_copy_id:
				report.add(&"illegal_founding_copy", "Founding exists only as the single origin base copy.", tile.tile_copy_id)
	var overlay_placements: int = transformation_ids.size()
	if state.features != null:
		for event: FeatureHistoryRecord in state.features.history:
			if event != null and event.kind in [&"development_placed", &"development_upgraded"]:
				overlay_placements += 1
				if event.placement_index in placement_indices:
					report.add(&"duplicate_placement_index", "Each normal placement has a unique index.")
				placement_indices.append(event.placement_index)
	if expansion.board.cells.size() + overlay_placements != expansion.normal_placements + 1:
		report.add(&"placement_count_mismatch", "Founding, base placements and overlay play history must match the placement counter.")
	var expected_revision: int = expansion.board.cells.size()
	for cell: BoardCellState in expansion.board.cells.values():
		if cell != null and cell.geometry_revision >= 0:
			if expected_revision > 9223372036854775807 - cell.geometry_revision:
				report.add(&"overflowing_geometry_history", "Geometry revision sum must remain representable.")
			else:
				expected_revision += cell.geometry_revision
	if expansion.board.revision != expected_revision:
		report.add(&"invalid_board_revision", "Board revision must reflect insertions and explicit geometry rewrites.")
	if not expansion.board.cells.has(Vector2i.ZERO):
		report.add(&"missing_founding_tile", "Founding Tile must remain at the origin.")
	else:
		var founding: BoardCellState = expansion.board.cells[Vector2i.ZERO]
		if founding == null or founding.definition_id != FOUNDING_ID or founding.rotation != 0 \
			or founding.act_placed != 1 or founding.normal_placement_index != 0:
			report.add(&"invalid_founding_tile", "Origin requires the fixed Act-I Founding Tile with placement index zero.")


static func _validate_turn(state: RunState, config: RunConfig, report: InvariantReport) -> void:
	var expansion: ExpansionState = state.expansion
	if expansion.current_act < 1 or expansion.current_act > 3 or config.act_placement_limits.size() < expansion.current_act:
		report.add(&"unsupported_act", "Current Act requires a canonical placement limit.")
		return
	var limit: int = config.act_placement_limits[expansion.current_act - 1]
	if expansion.normal_placements < 0 or expansion.normal_placements > limit:
		report.add(&"invalid_placement_count", "Normal placement counter lies outside the controlled current Act.")
	if expansion.survey_charges < 0 or (state.rewards == null and expansion.survey_charges > config.initial_survey_charges):
		report.add(&"invalid_survey_charges", "Survey charges lie outside Phase-2 grant bounds.")
	if expansion.state_revision < 0 or expansion.reserve_id < 0 or expansion.reserve_extra_id < 0:
		report.add(&"invalid_expansion_metadata", "State revision and optional Reserve ID must be nonnegative.")
	if expansion.state_revision < expansion.normal_placements:
		report.add(&"rewound_state_revision", "State revision cannot precede the number of committed placements.")
	if expansion.hand.size() != config.hand_capacity:
		report.add(&"invalid_hand_capacity", "Stable expansion state requires all normal hand slots.")
	if state.phase == GamePhase.Type.PENDING_CHOICE and state.pending_choice != null and state.pending_choice.kind == &"compass":
		_validate_compass(state, report)
		return
	if not expansion.inspected_ids.is_empty():
		report.add(&"stranded_inspected_tiles", "Inspected physical copies require a pending Compass choice.")
	if state.phase == GamePhase.Type.PENDING_CHOICE and state.specialists != null:
		if state.resolution != null:
			if expansion.pending_refill_index == -1:
				if 0 in expansion.hand:
					report.add(&"untracked_refill", "Reserve placement must retain the full active hand.")
			elif expansion.pending_refill_index < 0 or expansion.pending_refill_index >= expansion.hand.size() \
				or expansion.hand[expansion.pending_refill_index] != 0 or expansion.hand.count(0) != 1:
				report.add(&"invalid_pending_refill", "Committed placement must retain its single empty slot.")
		elif expansion.pending_refill_index != -1 or 0 in expansion.hand:
			report.add(&"invalid_training_boundary", "Training cannot conceal an incomplete placement.")
		return # Specialist invariants validate the exact typed choice/continuation.
	if expansion.normal_placements == limit:
		if state.phase != GamePhase.Type.RESOLVING_ACT_TRANSITION:
			report.add(&"invalid_act_boundary", "Final placement must wait at the deferred Act transition.")
		if expansion.pending_refill_index == -1:
			if 0 in expansion.hand:
				report.add(&"untracked_refill", "Empty hand slot requires pending refill context.")
		elif expansion.pending_refill_index < 0 or expansion.pending_refill_index >= expansion.hand.size() \
			or expansion.hand[expansion.pending_refill_index] != 0 or expansion.hand.count(0) != 1:
			report.add(&"invalid_pending_refill", "Deferred refill must identify the sole empty hand slot.")
	elif state.phase != GamePhase.Type.TURN_INPUT or expansion.pending_refill_index != -1 or 0 in expansion.hand:
		report.add(&"invalid_turn_boundary", "Ordinary turn requires TURN_INPUT, full hand and no pending refill.")


static func _validate_zone(state: RunState, ids: Array[int], kind: TileLocationState.Kind,
		represented: Array[int], report: InvariantReport) -> void:
	for tile_id: int in ids:
		if tile_id == 0 and kind == TileLocationState.Kind.ACTIVE_HAND:
			continue # Pending slot legality is checked by _validate_turn.
		if tile_id <= 0 or tile_id in represented:
			report.add(&"duplicate_zone_identity", "Physical ID must appear in exactly one zone entry.", tile_id)
		represented.append(tile_id)
		var resolved: bool = false
		for tile: TileCopyState in state.tile_copies:
			if tile != null and tile.tile_copy_id == tile_id:
				resolved = true
		if not resolved:
			report.add(&"unresolved_zone_id", "Zone references an absent physical tile.", tile_id)
		var matching_location: bool = false
		for location: TileLocationState in state.tile_locations:
			if location != null and location.tile_copy_id == tile_id and location.kind == kind:
				matching_location = true
		if not matching_location:
			report.add(&"zone_location_mismatch", "Container and physical location kind disagree.", tile_id)


static func _validate_cell(state: RunState, content: ContentRegistry, coordinate: Vector2i,
		cell: BoardCellState, report: InvariantReport) -> void:
	var tile_id: int = cell.base_tile_copy_id
	if cell.coordinate != coordinate:
		report.add(&"coordinate_mismatch", "Sparse key and stored cell coordinate disagree.", tile_id)
	if cell.act_placed < 1 or cell.act_placed > state.expansion.current_act or cell.rotation < 0 or cell.rotation > 3 \
		or cell.normal_placement_index < 0 or cell.normal_placement_index > state.expansion.normal_placements:
		report.add(&"invalid_cell_metadata", "Cell rotation, Act or placement index is invalid.", tile_id)
	if cell.definition_id == FOUNDING_ID and coordinate != Vector2i.ZERO:
		report.add(&"duplicate_founding_tile", "Founding definition may occur only at the origin.", tile_id)
	for tile: TileCopyState in state.tile_copies:
		if tile != null and tile.tile_copy_id == tile_id and tile.definition_id != cell.definition_id:
			report.add(&"board_definition_mismatch", "Board base and physical copy definition disagree.", tile_id)
	var definition: TileDefinition = content.get_tile(cell.definition_id)
	if definition == null:
		report.add(&"unknown_board_definition", "Board definition does not resolve.", tile_id)
		return
	var specialized_base: bool = false
	for transformation: TransformationState in cell.transformations:
		if transformation != null and transformation.tile_copy_id == tile_id and transformation.mode in [&"urban_expansion", &"rewilding_expansion"]:
			specialized_base = true
	if definition.tile_class != DomainTypes.TileClass.EXPANSION and not specialized_base:
		report.add(&"unsupported_board_class", "Board bases require Expansion or a recorded specialized Transformation placement.", tile_id)
	if not cell.transformations.is_empty() and state.features == null:
		report.add(&"transformation_without_features", "Transformation state requires feature provenance.")
	if cell.effective_edges.size() != 4:
		report.add(&"invalid_effective_edges", "Every base requires four effective edges.", tile_id)
		return
	for edge: DomainTypes.EdgeType in cell.effective_edges:
		if edge not in DomainTypes.EdgeType.values():
			report.add(&"invalid_effective_edge", "Unknown effective edge type.", tile_id)
	if cell.geometry_revision < 0 or (state.features == null and cell.geometry_revision != 0):
		report.add(&"invalid_geometry_revision", "Rewritten geometry requires initialized feature history.", tile_id)
	if cell.definition_id == FOUNDING_ID and cell.geometry_revision != 0:
		report.add(&"rewritten_founding", "Founding geometry remains fixed.", tile_id)
	if cell.geometry_revision == 0 and cell.effective_edges != TileRotation.edges(definition.canonical_edges, cell.rotation):
		report.add(&"unexpected_effective_geometry", "Phase-2 effective edges must equal rotated base geometry.", tile_id)
	if cell.geometry_revision == 0 and cell.has_field_geography != definition.canonical_edges.has(DomainTypes.EdgeType.FIELD):
		report.add(&"invalid_field_geography", "Unmodified Field geography must match its physical base.", tile_id)
	if cell.geometry_revision == 0 and cell.field_supports_settlement != definition.field_supports_settlement:
		report.add(&"invalid_field_support", "Unmodified Field support must match its definition.", tile_id)
	if cell.geometry_revision == 0 and _groups_signature(cell.feature_groups) != _groups_signature(TileRotation.groups(definition.feature_groups, cell.rotation)):
		report.add(&"invalid_internal_groups", "Current internal features differ from rotated static groups.", tile_id)
	if cell.geometry_revision == 0 and _relationships_signature(cell.relationships) != _relationships_signature(definition.relationships):
		report.add(&"invalid_internal_relationships", "Current internal relationships differ from the static base.", tile_id)
	if cell.geometry_revision > 0:
		_validate_current_geometry(state, cell, report)
	for direction: int in cell.hard_boundaries:
		if not RelicGeometry.is_hard_boundary(state.expansion.board, coordinate, direction):
			report.add(&"invalid_hard_boundary", "Hard boundaries must join a reciprocal occupied Field/Forest seam.", tile_id)
	var earlier_neighbor: bool = cell.normal_placement_index == 0
	for direction: int in range(4):
		var neighbor_coordinate: Vector2i = coordinate + OFFSETS[direction]
		if not state.expansion.board.cells.has(neighbor_coordinate):
			continue
		var neighbor: BoardCellState = state.expansion.board.cells[neighbor_coordinate]
		if neighbor != null and neighbor.normal_placement_index < cell.normal_placement_index:
			earlier_neighbor = true
		if neighbor != null and neighbor.effective_edges.size() == 4 \
			and cell.effective_edges[direction] != neighbor.effective_edges[(direction + 2) % 4] \
			and not RelicGeometry.is_hard_boundary(state.expansion.board, coordinate, direction):
			report.add(&"occupied_edge_mismatch", "Occupied orthogonal edges must match exactly.", tile_id)
	if not earlier_neighbor:
		report.add(&"disconnected_placement", "Every normal base must adjoin a previously placed base.", tile_id)


static func _validate_current_geometry(state: RunState, cell: BoardCellState, report: InvariantReport) -> void:
	var covered: Array[int] = []
	var types: Array[int] = []
	for group: TileFeatureGroup in cell.feature_groups:
		if group == null or group.edge_type not in [1, 2, 3, 4] or group.edge_type in types:
			report.add(&"invalid_current_group", "Current groups require unique tracked feature types.")
			continue
		if group.directions.is_empty() and (state.features == null or state.features.component_at(cell.coordinate, FeatureState.type_for_edge(group.edge_type)) == null):
			report.add(&"unproven_retained_group", "Zero-exit geography requires a retained feature component.")
		types.append(group.edge_type)
		for direction: int in group.directions:
			if direction not in [0, 1, 2, 3] or direction in covered:
				report.add(&"invalid_current_socket", "Current sockets must be valid and unique.")
				continue
			covered.append(direction)
			if cell.effective_edges[direction] != group.edge_type:
				report.add(&"current_socket_mismatch", "Effective edge must match its internal group.")
	for direction: int in range(4):
		if cell.effective_edges[direction] != DomainTypes.EdgeType.FIELD and direction not in covered:
			report.add(&"missing_current_socket", "Every tracked edge requires internal membership.")
	if cell.field_supports_settlement and (4 not in types or not cell.has_field_geography):
		report.add(&"invalid_current_support", "Field/Settlement contact requires both geographies.")
	for relation: TileFeatureRelationship in cell.relationships:
		if relation == null or relation.from_edge_type not in types or relation.to_edge_type not in types:
			report.add(&"invalid_current_relationship", "Cross-feature relationships require present endpoints.")
		elif not ([relation.from_edge_type, relation.to_edge_type, relation.kind] in [
			[3, 4, TileFeatureRelationship.Kind.ROAD_SETTLEMENT_ACCESS],
			[4, 2, TileFeatureRelationship.Kind.SETTLEMENT_RIVER_TOUCH],
			[1, 2, TileFeatureRelationship.Kind.FOREST_RIVER_TOUCH]]):
			report.add(&"invalid_current_relationship", "Unknown cross-feature relationship.")


static func _groups_signature(groups: Array[TileFeatureGroup]) -> String:
	var parts: Array[String] = []
	for group: TileFeatureGroup in groups:
		if group == null:
			parts.append("null")
			continue
		var directions: Array[int] = group.directions.duplicate()
		directions.sort()
		parts.append("%d:%s" % [group.edge_type, str(directions)])
	parts.sort()
	return "|".join(parts)


static func _relationships_signature(relationships: Array[TileFeatureRelationship]) -> String:
	var parts: Array[String] = []
	for relation: TileFeatureRelationship in relationships:
		if relation == null:
			parts.append("null")
			continue
		parts.append("%d:%d:%d" % [relation.from_edge_type, relation.to_edge_type, relation.kind])
	parts.sort()
	return "|".join(parts)


static func _validate_compass(state: RunState, report: InvariantReport) -> void:
	var expansion: ExpansionState = state.expansion
	var choice: PendingChoice = state.pending_choice
	if not choice.context.get("hand_index") is int:
		report.add(&"invalid_compass_slot", "Compass hand index must be an integer.")
		return
	var index: int = choice.context["hand_index"]
	if state.resolution == null or state.resolution.stage != &"compass" \
		or state.relics == null or not RelicRules.active(state, &"relic.surveyors_compass"):
		report.add(&"invalid_compass_resolution", "Compass requires its own persisted hand continuation.")
	if expansion.pending_refill_index != -1 or index < 0 or index >= expansion.hand.size() \
		or expansion.hand[index] != 0 or expansion.hand.count(0) != 1:
		report.add(&"invalid_compass_slot", "Compass must retain exactly its own vacated active-hand slot.")
	if expansion.inspected_ids.is_empty() or expansion.inspected_ids.size() > 3 \
		or choice.context.get("inspected_ids", []) != expansion.inspected_ids:
		report.add(&"invalid_compass_set", "Persisted Compass set must match one to three inspected physical copies.")
	var expected: Array[Dictionary] = []
	for copy_id: int in expansion.inspected_ids:
		expected.append({"tile_copy_id": copy_id})
	if choice.options != expected:
		report.add(&"invalid_compass_options", "Compass options must exactly preserve the inspected set.")
