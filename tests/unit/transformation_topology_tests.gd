extends "res://tests/framework/test_suite.gd"

const TYPE = DomainTypes.FeatureType
const EDGE = DomainTypes.EdgeType


func tests() -> Array[Callable]:
	return [new_components_record_transformation_origin, base_components_keep_default_origin,
		adding_components_preserves_existing_identity, closed_growth_reopens_once_before_recompletion,
		closed_growth_preserves_scoring_history, completed_river_addition_does_not_reopen,
		retained_field_interior_provides_explicit_support, consumed_field_never_provides_support,
		zero_exit_forest_remains_natural, field_interior_remains_natural_without_field_edges,
		field_developments_query_preserved_bridge_interior]


func new_components_record_transformation_origin() -> bool:
	var state: RunState = _state()
	var cell: BoardCellState = _cell(Vector2i.ZERO, EDGE.ROAD)
	TopologyService.add_cell_components(state, cell, 3, &"transformation", 900)
	var component: FeatureComponentState = state.features.components[0]
	expect_equal(component.origin_act, 3, "New Road origin is the Transformation Act")
	expect_equal(component.origin_source_type, &"transformation", "Origin identifies Transformation source")
	expect_equal(component.origin_source_runtime_id, 900, "Origin points at physical Transformation copy")
	return true


func base_components_keep_default_origin() -> bool:
	var state: RunState = _state()
	var cell: BoardCellState = _cell(Vector2i.ZERO, EDGE.RIVER)
	TopologyService.add_cell_components(state, cell)
	var component: FeatureComponentState = state.features.components[0]
	expect_equal(component.origin_act, 1, "Base origin uses base placement Act")
	expect_equal(component.origin_source_type, &"base_tile", "Existing default origin unchanged")
	expect_equal(component.origin_source_runtime_id, cell.base_tile_copy_id, "Base physical identity unchanged")
	return true


func adding_components_preserves_existing_identity() -> bool:
	var state: RunState = _state()
	var cell: BoardCellState = _cell(Vector2i.ZERO, EDGE.RIVER)
	TopologyService.add_cell_components(state, cell)
	var river: FeatureComponentState = state.features.components[0]
	var road_group: TileFeatureGroup = TileFeatureGroup.new()
	road_group.edge_type = EDGE.ROAD
	cell.feature_groups.append(road_group)
	TopologyService.add_cell_components(state, cell, 3, &"transformation", 900)
	TopologyService.add_cell_components(state, cell, 3, &"transformation", 901)
	expect_equal(state.features.components.size(), 2, "Only missing geography creates components")
	expect_true(state.features.component(river.component_id) == river, "River instance identity preserved")
	expect_equal(river.origin_source_runtime_id, cell.base_tile_copy_id, "Existing River does not inherit Bridge origin")
	return true


func closed_growth_reopens_once_before_recompletion() -> bool:
	var state: RunState = _growing(TYPE.SETTLEMENT)
	var feature: CurrentFeature = _growth_feature(state, TYPE.SETTLEMENT)
	LineageService.reconcile(state, [feature], 900)
	var lineage: FeatureLineageState = state.features.lineages[0]
	expect_true(not lineage.completed, "Closed new growth becomes eligible for genuine completion")
	expect_equal(lineage.growth_phase, 2, "One new growth phase")
	expect_equal(state.features.history[0].kind, &"feature_reopened", "Growth boundary recorded before completion")
	expect_equal(state.features.history[1].kind, &"feature_grew", "New component recorded")
	LineageService.reconcile(state, [feature], 900)
	expect_equal(lineage.growth_phase, 2, "Reconstruction alone never adds another phase")
	var records: Array[FeatureCompletionRecord] = FeatureScoringService.calculate(FeatureScoringService.capture(state, [feature], 900))
	expect_equal(records.size(), 1, "Closed growth has a genuine completion candidate")
	expect_equal(records[0].new_component_ids, [state.features.components[1].component_id], "Only added component scores again")
	FeatureScoringService.resolve(state, [feature], 900)
	var event_count: int = state.features.history.size()
	FeatureScoringService.resolve(state, [feature], 900)
	expect_equal(state.features.history.size(), event_count, "Stable closed reconstruction cannot repeat the new completion")
	expect_equal(state.features.tracks.values[DomainTypes.TrackType.POPULATION], 2, "Only new Settlement component pays")
	return true


func closed_growth_preserves_scoring_history() -> bool:
	var state: RunState = _growing(TYPE.ROAD)
	var lineage: FeatureLineageState = state.features.lineages[0]
	lineage.scored_field_ids = [400]
	lineage.scored_settlement_ids = [500]
	LineageService.reconcile(state, [_growth_feature(state, TYPE.ROAD)], 900)
	expect_equal(lineage.scored_component_ids, [state.features.components[0].component_id], "Original component anti-farming survives")
	expect_equal(lineage.scored_field_ids, [400], "Historical supports survive")
	expect_equal(lineage.scored_settlement_ids, [500], "Road Settlement payment history survives")
	expect_equal(lineage.completion_ids, [600], "Original completion survives")
	return true


func completed_river_addition_does_not_reopen() -> bool:
	var state: RunState = _growing(TYPE.RIVER)
	LineageService.reconcile(state, [_growth_feature(state, TYPE.RIVER)], 900)
	expect_true(state.features.lineages[0].completed, "Bridge must not manufacture a River completion")
	expect_equal(state.features.lineages[0].growth_phase, 1, "No River growth phase from closed reconstruction")
	return true


func retained_field_interior_provides_explicit_support() -> bool:
	var state: RunState = _state()
	var cell: BoardCellState = _cell(Vector2i.ZERO, EDGE.SETTLEMENT)
	cell.has_field_geography = true
	cell.field_supports_settlement = true
	state.expansion.board.add_cell(cell)
	var feature: CurrentFeature = CurrentFeature.new()
	feature.feature_type = TYPE.SETTLEMENT
	feature.coordinates = [Vector2i.ZERO]
	expect_equal(FeatureContactService.support_ids(state, feature, EDGE.FIELD), [cell.base_tile_copy_id], "Current Field interior supports even without Field boundary")
	return true


func consumed_field_never_provides_support() -> bool:
	var state: RunState = _state()
	var cell: BoardCellState = _cell(Vector2i.ZERO, EDGE.SETTLEMENT)
	cell.has_field_geography = false
	cell.field_supports_settlement = true
	state.expansion.board.add_cell(cell)
	var feature: CurrentFeature = CurrentFeature.new()
	feature.feature_type = TYPE.SETTLEMENT
	feature.coordinates = [Vector2i.ZERO]
	expect_true(FeatureContactService.support_ids(state, feature, EDGE.FIELD).is_empty(), "Old Field relationship cannot resurrect consumed geography")
	return true


func zero_exit_forest_remains_natural() -> bool:
	var cell: BoardCellState = _cell(Vector2i.ZERO, EDGE.FOREST)
	cell.effective_edges = [EDGE.ROAD, EDGE.ROAD, EDGE.ROAD, EDGE.ROAD]
	expect_true(EnclosureService.has_natural_geography(cell), "Retained Forest component remains natural even without Forest exits")
	return true


func field_interior_remains_natural_without_field_edges() -> bool:
	var cell: BoardCellState = _cell(Vector2i.ZERO, EDGE.ROAD)
	cell.has_field_geography = true
	expect_true(EnclosureService.has_natural_geography(cell), "Retained Field is authoritative natural geography")
	cell.has_field_geography = false
	expect_true(not EnclosureService.has_natural_geography(cell), "Road alone is not natural")
	return true


func field_developments_query_preserved_bridge_interior() -> bool:
	var content: ContentRegistry = ContentRegistry.new()
	expect_true(content.load_phase_five().is_valid, "Development definitions load")
	var state: RunState = _state()
	var cell: BoardCellState = _cell(Vector2i.ZERO, EDGE.RIVER)
	cell.effective_edges = [EDGE.RIVER, EDGE.ROAD, EDGE.RIVER, EDGE.ROAD]
	cell.has_field_geography = true
	state.expansion.board.add_cell(cell)
	for definition_id: StringName in [&"tile.development.mill", &"tile.development.monastery"]:
		var copy_id: int = PhysicalTileRules.acquire(state, definition_id, &"scenario_fixture", TileLocationState.Kind.ACTIVE_HAND)
		expect_equal(DevelopmentPlacementQuery.query(state, content, copy_id).size(), 1, "Retained Bridge Field interior remains a Development host")
		cell.has_field_geography = false
		expect_true(DevelopmentPlacementQuery.query(state, content, copy_id).is_empty(), "Consumed Field excludes Field-dependent Development")
		cell.has_field_geography = true
	return true


func _state() -> RunState:
	var state: RunState = RunState.new(345)
	state.expansion = ExpansionState.new()
	state.features = FeatureState.new()
	return state


func _cell(at: Vector2i, edge: int) -> BoardCellState:
	var cell: BoardCellState = BoardCellState.new()
	cell.coordinate = at
	cell.base_tile_copy_id = 700 + at.x
	cell.act_placed = 1
	cell.effective_edges.assign([edge, edge, edge, edge])
	var group: TileFeatureGroup = TileFeatureGroup.new()
	group.edge_type = edge
	cell.feature_groups.append(group)
	return cell


func _growing(type: int) -> RunState:
	var state: RunState = _state()
	var lineage: FeatureLineageState = FeatureLineageState.new()
	lineage.lineage_id = state.id_allocator.allocate()
	lineage.feature_type = type
	lineage.completed = true
	lineage.completion_ids = [600]
	state.features.lineages.append(lineage)
	for x: int in range(2):
		var cell: BoardCellState = _cell(Vector2i(x, 0), FeatureState.edge_for_type(type))
		state.expansion.board.add_cell(cell)
		TopologyService.add_cell_components(state, cell)
	state.features.components[0].lineage_id = lineage.lineage_id
	lineage.member_ids = [state.features.components[0].component_id]
	lineage.scored_component_ids = lineage.member_ids.duplicate()
	return state


func _growth_feature(state: RunState, type: int) -> CurrentFeature:
	var feature: CurrentFeature = CurrentFeature.new()
	feature.feature_type = type
	feature.coordinates = [Vector2i.ZERO, Vector2i.RIGHT]
	feature.component_ids = [state.features.components[0].component_id, state.features.components[1].component_id]
	feature.lineage_id = state.features.lineages[0].lineage_id
	return feature
