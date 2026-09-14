extends "res://tests/framework/test_suite.gd"

const Fixture = preload("res://tests/fixtures/topology_fixture.gd")
const PhaseTwo = preload("res://tests/fixtures/phase_two_factory.gd")
const EDGE = DomainTypes.EdgeType
const TYPE = DomainTypes.FeatureType


func tests() -> Array[Callable]:
	return [founding_has_four_distinct_components, single_feature_types_create_one_component,
		hybrids_keep_components_separate, component_creation_is_idempotent,
		component_origins_are_independent_of_base_age, matching_orthogonal_components_connect,
		nonmatching_types_never_connect, diagonal_same_types_do_not_connect,
		junction_requires_all_branches_closed, canonical_bends_are_internally_connected,
		endpoint_pairs_complete_for_each_tracked_type, unresolved_exit_remains_unfinished,
		closed_loop_has_no_exits, field_has_no_component, topology_rebuild_is_pure_and_deterministic,
		rebuild_ignores_registry_and_board_insertion_order, topology_revision_advances_on_reconcile,
		new_feature_allocates_lineage, ordinary_growth_retains_identity,
		reopening_retains_identity_and_history, completed_river_reopening_rejected,
		merge_creates_descendant_and_preserves_history, ancestry_is_transitive_and_sorted,
		repeated_reconcile_does_not_allocate_or_record, disconnected_lineage_is_rejected]


func founding_has_four_distinct_components() -> bool:
	var state: RunState = Fixture.empty()
	var definition: TileDefinition = PhaseTwo.content().get_tile(&"tile.founding.homestead")
	var cell: BoardCellState = BoardCellState.from_definition(definition, state.id_allocator.allocate(), Vector2i.ZERO, 0, 1, 0)
	state.expansion.board.add_cell(cell)
	TopologyService.add_cell_components(state, cell)
	expect_equal(state.features.components.size(), 4, "Founding has four persistent stubs")
	var current: Array[CurrentFeature] = Fixture.reconcile(state)
	expect_equal(current.size(), 4, "Road–Settlement access does not merge topology")
	for feature: CurrentFeature in current:
		expect_equal(feature.open_exits, 1, "Each Founding stub initially has one exit")
	return true


func single_feature_types_create_one_component() -> bool:
	for edge: int in range(1, 5):
		var state: RunState = Fixture.empty()
		Fixture.add(state, Vector2i.ZERO, [edge as DomainTypes.EdgeType, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
		expect_equal(state.features.components.size(), 1, "One tracked type creates one component")
	return true


func hybrids_keep_components_separate() -> bool:
	var content: ContentRegistry = PhaseTwo.content()
	for definition_id: StringName in [&"tile.settlement_gate", &"tile.riverside_hamlet", &"tile.woodland_road", &"tile.woodland_river"]:
		var state: RunState = Fixture.empty()
		var cell: BoardCellState = BoardCellState.from_definition(content.get_tile(definition_id), state.id_allocator.allocate(), Vector2i.ZERO, 0, 1, 0)
		state.expansion.board.add_cell(cell)
		TopologyService.add_cell_components(state, cell)
		expect_equal(TopologyService.rebuild(state).size(), 2, "Hybrid relationships preserve two types")
	return true


func component_creation_is_idempotent() -> bool:
	var state: RunState = Fixture.empty()
	var cell: BoardCellState = Fixture.add(state, Vector2i.ZERO, [EDGE.ROAD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	var next_id: int = state.next_runtime_id
	TopologyService.add_cell_components(state, cell)
	expect_equal(state.next_runtime_id, next_id, "Already existing component never replaced")
	return true


func component_origins_are_independent_of_base_age() -> bool:
	var state: RunState = Fixture.empty()
	var cell: BoardCellState = Fixture.add(state, Vector2i.ZERO, [EDGE.RIVER, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	var component: FeatureComponentState = state.features.components[0]
	expect_equal(component.origin_act, 1, "Base creation retains origin Act")
	expect_equal(component.origin_source_runtime_id, cell.base_tile_copy_id, "Base physical identity retained")
	component.origin_act = 3
	component.origin_source_type = &"fixture_future_origin"
	expect_equal(cell.act_placed, 1, "Component origin can differ from base age")
	return true


func matching_orthogonal_components_connect() -> bool:
	var state: RunState = _pair(EDGE.ROAD)
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	expect_equal(current.size(), 1, "Matching opposite Road sockets connect")
	expect_equal(current[0].component_ids.size(), 2, "Both stable components belong to connected feature")
	return true


func nonmatching_types_never_connect() -> bool:
	var state: RunState = Fixture.empty()
	Fixture.add(state, Vector2i.ZERO, [EDGE.FIELD, EDGE.ROAD, EDGE.FIELD, EDGE.FIELD])
	Fixture.add(state, Vector2i.RIGHT, [EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.SETTLEMENT])
	expect_equal(TopologyService.rebuild(state).size(), 2, "Different features never collapse even across facing edges")
	return true


func diagonal_same_types_do_not_connect() -> bool:
	var state: RunState = Fixture.empty()
	Fixture.add(state, Vector2i.ZERO, [EDGE.FOREST, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	Fixture.add(state, Vector2i.ONE, [EDGE.FOREST, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	expect_equal(TopologyService.rebuild(state).size(), 2, "Diagonal contact is not topology")
	return true


func junction_requires_all_branches_closed() -> bool:
	var state: RunState = Fixture.empty()
	Fixture.add(state, Vector2i.ZERO, [EDGE.ROAD, EDGE.ROAD, EDGE.ROAD, EDGE.FIELD])
	Fixture.add(state, Vector2i.UP, [EDGE.FIELD, EDGE.FIELD, EDGE.ROAD, EDGE.FIELD])
	Fixture.add(state, Vector2i.RIGHT, [EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.ROAD])
	expect_equal(TopologyService.rebuild(state)[0].open_exits, 1, "One open branch prevents junction completion")
	Fixture.add(state, Vector2i.DOWN, [EDGE.ROAD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	expect_equal(TopologyService.rebuild(state)[0].open_exits, 0, "Every junction branch closes")
	return true


func canonical_bends_are_internally_connected() -> bool:
	var content: ContentRegistry = PhaseTwo.content()
	for definition_id: StringName in [&"tile.settlement_corner", &"tile.forest_bend", &"tile.river_bend", &"tile.bending_road"]:
		var state: RunState = Fixture.empty()
		var definition: TileDefinition = content.get_tile(definition_id)
		var cell: BoardCellState = BoardCellState.from_definition(definition, state.id_allocator.allocate(), Vector2i.ZERO, 0, 1, 0)
		state.expansion.board.add_cell(cell)
		TopologyService.add_cell_components(state, cell)
		var current: Array[CurrentFeature] = TopologyService.rebuild(state)
		expect_equal(current.size(), 1, "Bend has one internal component")
		expect_equal(current[0].open_exits, 2, "Both bend sockets belong to the same feature")
	return true


func endpoint_pairs_complete_for_each_tracked_type() -> bool:
	for edge: int in range(1, 5):
		expect_equal(TopologyService.rebuild(_pair(edge as DomainTypes.EdgeType))[0].open_exits, 0, "Endpoint pair completes")
	return true


func unresolved_exit_remains_unfinished() -> bool:
	var state: RunState = Fixture.empty()
	Fixture.add(state, Vector2i.ZERO, [EDGE.ROAD, EDGE.FIELD, EDGE.ROAD, EDGE.FIELD])
	expect_equal(TopologyService.rebuild(state)[0].open_exits, 2, "Both empty-facing exits unresolved")
	return true


func closed_loop_has_no_exits() -> bool:
	var state: RunState = Fixture.empty()
	Fixture.add(state, Vector2i.ZERO, [EDGE.FIELD, EDGE.RIVER, EDGE.RIVER, EDGE.FIELD])
	Fixture.add(state, Vector2i.RIGHT, [EDGE.FIELD, EDGE.FIELD, EDGE.RIVER, EDGE.RIVER])
	Fixture.add(state, Vector2i.DOWN, [EDGE.RIVER, EDGE.RIVER, EDGE.FIELD, EDGE.FIELD])
	Fixture.add(state, Vector2i.ONE, [EDGE.RIVER, EDGE.FIELD, EDGE.FIELD, EDGE.RIVER])
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	expect_equal(current.size(), 1, "River loop is one feature")
	expect_equal(current[0].open_exits, 0, "Loop closes without endpoint tiles")
	return true


func field_has_no_component() -> bool:
	var state: RunState = Fixture.empty()
	Fixture.add(state, Vector2i.ZERO, [EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	expect_true(state.features.components.is_empty(), "Field is geography, not feature identity")
	expect_true(TopologyService.rebuild(state).is_empty(), "Field has no topology object")
	return true


func _pair(edge: DomainTypes.EdgeType) -> RunState:
	var state: RunState = Fixture.empty()
	Fixture.add(state, Vector2i.ZERO, [EDGE.FIELD, edge, EDGE.FIELD, EDGE.FIELD])
	Fixture.add(state, Vector2i.RIGHT, [EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, edge])
	return state


func topology_rebuild_is_pure_and_deterministic() -> bool:
	var state: RunState = _pair(EDGE.ROAD)
	var id: int = state.next_runtime_id
	var first: String = Fixture.signature(TopologyService.rebuild(state))
	expect_equal(Fixture.signature(TopologyService.rebuild(state)), first, "Pure repeated reconstruction")
	expect_equal(state.next_runtime_id, id, "No graph identity allocation")
	expect_true(state.features.history.is_empty(), "No reconstruction events")
	return true


func rebuild_ignores_registry_and_board_insertion_order() -> bool:
	var state: RunState = _pair(EDGE.ROAD)
	var before: String = Fixture.signature(Fixture.reconcile(state))
	state.features.components.reverse()
	var cell: BoardCellState = state.expansion.board.cells[Vector2i.ZERO]
	state.expansion.board.cells.erase(Vector2i.ZERO)
	state.expansion.board.cells[Vector2i.ZERO] = cell
	expect_equal(Fixture.signature(TopologyService.rebuild(state)), before, "Unordered storage never affects traversal")
	return true


func topology_revision_advances_on_reconcile() -> bool:
	var state: RunState = _pair(EDGE.ROAD)
	expect_equal(state.features.topology_revision, 0, "No implicit topology revision")
	Fixture.reconcile(state)
	expect_equal(state.features.topology_revision, state.expansion.board.revision, "Reconcile reflects authoritative board")
	return true


func new_feature_allocates_lineage() -> bool:
	var state: RunState = _pair(EDGE.FOREST)
	Fixture.reconcile(state)
	expect_equal(state.features.lineages.size(), 1, "New connected feature has one identity")
	expect_equal(state.features.components[0].lineage_id, state.features.components[1].lineage_id, "Members assigned same lineage")
	return true


func ordinary_growth_retains_identity() -> bool:
	var state: RunState = Fixture.empty()
	Fixture.add(state, Vector2i.ZERO, [EDGE.FIELD, EDGE.ROAD, EDGE.FIELD, EDGE.FIELD])
	Fixture.reconcile(state)
	var id: int = state.features.lineages[0].lineage_id
	Fixture.add(state, Vector2i.RIGHT, [EDGE.FIELD, EDGE.ROAD, EDGE.FIELD, EDGE.ROAD])
	Fixture.reconcile(state)
	expect_equal(state.features.components[1].lineage_id, id, "Ordinary growth retains lineage")
	expect_equal(state.features.history[-1].kind, &"feature_grew", "Growth audit is explicit")
	return true


func reopening_retains_identity_and_history() -> bool:
	var state: RunState = _pair(EDGE.ROAD)
	FeatureScoringService.resolve(state, Fixture.reconcile(state))
	var lineage: FeatureLineageState = state.features.lineages[0]
	Fixture.set_geometry(state.expansion.board.get_cell(Vector2i.RIGHT), [EDGE.FIELD, EDGE.ROAD, EDGE.FIELD, EDGE.ROAD])
	Fixture.reconcile(state)
	expect_true(not lineage.completed and lineage.growth_phase == 2, "Genuine reopening starts new phase")
	expect_equal(lineage.scored_component_ids.size(), 2, "Reopening never resets scoring")
	expect_equal(lineage.completion_ids.size(), 1, "Historical completion survives")
	return true


func completed_river_reopening_rejected() -> bool:
	var state: RunState = _pair(EDGE.RIVER)
	FeatureScoringService.resolve(state, Fixture.reconcile(state))
	Fixture.set_geometry(state.expansion.board.get_cell(Vector2i.RIGHT), [EDGE.FIELD, EDGE.RIVER, EDGE.FIELD, EDGE.RIVER])
	expect_equal(LineageService.validate_rebuild(state, TopologyService.rebuild(state)).error_code, &"completed_river_reopening", "River reopening prohibited")
	return true


func merge_creates_descendant_and_preserves_history() -> bool:
	var state: RunState = Fixture.empty()
	Fixture.add(state, Vector2i.ZERO, [EDGE.FIELD, EDGE.ROAD, EDGE.FIELD, EDGE.FIELD])
	Fixture.add(state, Vector2i(2, 0), [EDGE.FIELD, EDGE.FIELD, EDGE.FIELD, EDGE.ROAD])
	Fixture.reconcile(state)
	var parents: Array[int] = [state.features.lineages[0].lineage_id, state.features.lineages[1].lineage_id]
	for lineage: FeatureLineageState in state.features.lineages:
		lineage.scored_component_ids = lineage.member_ids.duplicate()
	Fixture.add(state, Vector2i.RIGHT, [EDGE.FIELD, EDGE.ROAD, EDGE.FIELD, EDGE.ROAD])
	var current: Array[CurrentFeature] = Fixture.reconcile(state)
	var descendant: FeatureLineageState = state.features.lineage(current[0].lineage_id)
	expect_equal(descendant.parent_ids, parents, "Merge parents sorted deterministically")
	expect_equal(descendant.scored_component_ids.size(), 2, "Both historical scoring sets inherited")
	expect_true(not state.features.lineage(parents[0]).active, "Parent remains historical")
	return true


func ancestry_is_transitive_and_sorted() -> bool:
	var state: RunState = Fixture.empty()
	for index: int in range(3):
		var lineage: FeatureLineageState = FeatureLineageState.new()
		lineage.lineage_id = state.id_allocator.allocate()
		if index > 0:
			lineage.parent_ids = [index]
		state.features.lineages.append(lineage)
	expect_equal(LineageService.get_ancestry_closure(state, 3), [1, 2], "Transitive sorted ancestry")
	expect_true(LineageService.is_ancestor(state, 1, 3), "Ancestor query resolves grandparent")
	return true


func repeated_reconcile_does_not_allocate_or_record() -> bool:
	var state: RunState = _pair(EDGE.ROAD)
	Fixture.reconcile(state)
	var id: int = state.next_runtime_id
	Fixture.reconcile(state)
	expect_equal(state.next_runtime_id, id, "Stable rebuild has no ID or event effects")
	return true


func disconnected_lineage_is_rejected() -> bool:
	var state: RunState = _pair(EDGE.ROAD)
	Fixture.reconcile(state)
	Fixture.set_geometry(state.expansion.board.get_cell(Vector2i.RIGHT), [EDGE.ROAD, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	expect_equal(LineageService.validate_rebuild(state, TopologyService.rebuild(state)).error_code, &"unsupported_feature_split", "Disconnected shared identity rejected")
	return true
