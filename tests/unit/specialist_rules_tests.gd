extends "res://tests/framework/test_suite.gd"
## Isolated domain scoring graphs; command scenarios separately enforce physical zones.

const Fixture = preload("res://tests/fixtures/topology_fixture.gd")
const EDGE = DomainTypes.EdgeType
const TYPE = DomainTypes.FeatureType


func tests() -> Array[Callable]:
	return [generic_tracks_by_host, merchant_one_settlement_zero, merchant_two_settlements_two,
		merchant_three_settlements_four, merchant_uses_unfinished_network_peers,
		merchant_deduplicates_access, merchant_network_growth_is_not_scoring,
		architect_deduplicates_upgrade_families, homesteader_counts_current_old_support,
		naturalist_lodge_exception, naturalist_ordinary_development_disqualifies,
		riverkeeper_counts_forest_tiles, harbormaster_requires_explicit_contact,
		harbormaster_counts_settlements_and_port_hosts, generic_monastery_snapshot,
		completed_targets_excluded, growth_credits_only_new_target_components,
		growth_excludes_foreign_postassignment_construction, forest_growth_excludes_absorbed_old_tiles,
		snapshot_freezes_family_and_support_facts, effects_return_only_after_batch,
		bonus_does_not_change_base_history, no_completion_no_specialist_fact]


func generic_tracks_by_host() -> bool:
	for type: int in range(5):
		var facts: Dictionary = _facts("", type)
		var expected: Array[int] = [0, 0, 0, 0]
		expected[[1, 0, 3, 3, 2][type]] = 2
		expect_equal(_calculate([facts])[0]["gains"], expected, "Generic host-specific bonus")
	return true


func merchant_one_settlement_zero() -> bool:
	expect_equal(_merchant(1), [0, 0, 0, 0], "First Settlement grants no Merchant bonus")
	return true


func merchant_two_settlements_two() -> bool:
	expect_equal(_merchant(2), [0, 2, 0, 0], "Two distinct Settlement nodes")
	return true


func merchant_three_settlements_four() -> bool:
	expect_equal(_merchant(3), [0, 4, 0, 0], "Transitive network counts all three Settlements")
	return true


func merchant_uses_unfinished_network_peers() -> bool:
	var state: RunState = _chain(3)
	var road: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.ROAD)
	_bind(state, road, &"specialist.merchant")
	expect_true(_at(state, Vector2i(2, 0), TYPE.ROAD).open_exits > 0, "Intermediate Road unfinished")
	expect_true(_at(state, Vector2i.ZERO, TYPE.SETTLEMENT).open_exits > 0, "Host network includes unfinished Settlement")
	expect_equal(_capture(state, [road.lineage_id])[0]["gains"], [0, 4, 0, 0], "Full economic graph is authoritative")
	return true


func merchant_deduplicates_access() -> bool:
	var state: RunState = _chain(2)
	var cell: BoardCellState = state.expansion.board.get_cell(Vector2i.ZERO)
	cell.relationships.append(cell.relationships[0].duplicate(true) as TileFeatureRelationship)
	TradeNetworkService.reconcile(state)
	var road: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.ROAD)
	_bind(state, road, &"specialist.merchant")
	expect_equal(_capture(state, [road.lineage_id])[0]["gains"][1], 2, "Repeated access never duplicates Settlement")
	return true


func merchant_network_growth_is_not_scoring() -> bool:
	var state: RunState = _chain(3)
	_bind(state, _at(state, Vector2i.ZERO, TYPE.ROAD), &"specialist.merchant")
	var before: Array[int] = state.features.tracks.values.duplicate()
	TradeNetworkService.reconcile(state)
	expect_equal(state.features.tracks.values, before, "Network reconciliation gives no Specialist score")
	expect_true(_capture(state, []).is_empty(), "No completion trigger means no Merchant")
	return true


func architect_deduplicates_upgrade_families() -> bool:
	var state: RunState = _settlement()
	var feature: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	_overlay(state, Vector2i.ZERO, &"market", &"market", feature.lineage_id)
	_overlay(state, Vector2i.ZERO, &"grand_market", &"market", feature.lineage_id)
	_overlay(state, Vector2i.ZERO, &"housing", &"housing", feature.lineage_id)
	_overlay(state, Vector2i.ZERO, &"housing", &"housing", feature.lineage_id)
	_bind(state, feature, &"specialist.architect")
	expect_equal(_capture(state, [feature.lineage_id])[0]["gains"], [0, 0, 4, 0], "Upgrade and duplicate families deduplicate")
	return true


func homesteader_counts_current_old_support() -> bool:
	var state: RunState = _settlement()
	var feature: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	var support: Array[int] = FeatureContactService.support_ids(state, feature, EDGE.FIELD)
	state.features.lineage(feature.lineage_id).scored_field_ids = support.duplicate()
	_bind(state, feature, &"specialist.homesteader")
	expect_true(not support.is_empty(), "Scenario has current Field support")
	expect_equal(_capture(state, [feature.lineage_id])[0]["gains"][0], support.size(), "Old paid support still counts for Homesteader")
	state.expansion.board.get_cell(Vector2i.ZERO).has_field_geography = false
	expect_equal(_capture(state, [feature.lineage_id])[0]["gains"][0], 0, "Current removed Field ceases to count")
	return true


func naturalist_lodge_exception() -> bool:
	var state: RunState = _single(TYPE.FOREST)
	var feature: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.FOREST)
	_bind(state, feature, &"specialist.naturalist")
	expect_equal(_capture(state, [feature.lineage_id])[0]["gains"][3], 1, "Undeveloped Forest tile pays")
	_overlay(state, Vector2i.ZERO, &"foresters_lodge", &"foresters_lodge", feature.lineage_id)
	expect_equal(_capture(state, [feature.lineage_id])[0]["gains"][3], 1, "Lodge retains light-development exception")
	return true


func naturalist_ordinary_development_disqualifies() -> bool:
	var state: RunState = _single(TYPE.FOREST)
	var feature: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.FOREST)
	_bind(state, feature, &"specialist.naturalist")
	_overlay(state, Vector2i.ZERO, &"mill", &"mill", 0)
	expect_equal(_capture(state, [feature.lineage_id])[0]["gains"][3], 0, "Ordinary Development disqualifies entire Forest")
	return true


func riverkeeper_counts_forest_tiles() -> bool:
	var state: RunState = _river_contacts()
	var river: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.RIVER)
	_bind(state, river, &"specialist.riverkeeper")
	var count: int = FeatureContactService.support_ids(state, river, EDGE.FOREST).size()
	expect_equal(count, 1, "Explicit hybrid Forest contact is one tile")
	state.features.lineage(river.lineage_id).scored_forest_ids = FeatureContactService.support_ids(state, river, EDGE.FOREST)
	expect_equal(_capture(state, [river.lineage_id])[0]["gains"][3], 1, "Base-paid Forest contact still contributes")
	return true


func harbormaster_requires_explicit_contact() -> bool:
	var state: RunState = _river_contacts()
	var river: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.RIVER)
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	expect_true(SpecialistRules.role_eligible(state, &"specialist.harbormaster", TYPE.RIVER, river.lineage_id, current), "Explicit River/Settlement relationship permits assignment")
	state.expansion.board.get_cell(Vector2i.ZERO).relationships.clear()
	expect_true(not SpecialistRules.role_eligible(state, &"specialist.harbormaster", TYPE.RIVER, river.lineage_id, current), "Coexisting geography alone is not contact")
	return true


func harbormaster_counts_settlements_and_port_hosts() -> bool:
	var state: RunState = _river_contacts()
	var river: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.RIVER)
	var settlement: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	_bind(state, river, &"specialist.harbormaster")
	expect_equal(_capture(state, [river.lineage_id])[0]["gains"][1], 2, "One touching Settlement gives two")
	_overlay(state, Vector2i.ZERO, &"port", &"port", settlement.lineage_id)
	_overlay(state, Vector2i.ZERO, &"port", &"port", settlement.lineage_id)
	expect_equal(_capture(state, [river.lineage_id])[0]["gains"][1], 3, "Multiple Ports in one host count once")
	return true


func generic_monastery_snapshot() -> bool:
	var state: RunState = _single(TYPE.ROAD)
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	piece.status = SpecialistPieceState.Status.ASSIGNED
	piece.assigned_target_type = 4
	piece.assigned_target_id = 99
	var facts: Array[Dictionary] = SpecialistRules.capture(state, TopologyService.rebuild(state), [], [{"enclosure_id": 99, "stage": "abbey"}])
	expect_equal(_calculate(facts)[0]["gains"], [0, 0, 2, 0], "Persistent generic enclosure commitment survives Abbey stage")
	return true


func completed_targets_excluded() -> bool:
	var state: RunState = _single(TYPE.ROAD)
	var feature: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.ROAD)
	feature.open_exits = 0
	expect_true(not SpecialistRules.target_unfinished(state, TYPE.ROAD, feature.lineage_id, [feature]), "No last-second assignment to geometrically closed feature")
	return true


func growth_credits_only_new_target_components() -> bool:
	var state: RunState = _single(TYPE.ROAD)
	var road: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.ROAD)
	var piece: SpecialistPieceState = _bind(state, road, &"specialist.cartographer")
	Fixture.add(state, Vector2i.UP, [EDGE.ROAD, EDGE.FIELD, EDGE.ROAD, EDGE.FIELD])
	SpecialistRules.remap_and_growth(state, Fixture.reconcile(state))
	expect_equal(piece.qualifying_component_ids.size(), 1, "Only newly attached component is growth")
	SpecialistRules.remap_and_growth(state, TopologyService.rebuild(state))
	expect_equal(piece.qualifying_component_ids.size(), 1, "Rebuilding does not duplicate growth credit")
	return true


func growth_excludes_foreign_postassignment_construction() -> bool:
	return _merger_growth(TYPE.ROAD, &"specialist.cartographer")


func forest_growth_excludes_absorbed_old_tiles() -> bool:
	return _merger_growth(TYPE.FOREST, &"specialist.forester")


func snapshot_freezes_family_and_support_facts() -> bool:
	var state: RunState = _settlement()
	var feature: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	_bind(state, feature, &"specialist.architect")
	_overlay(state, Vector2i.ZERO, &"housing", &"housing", feature.lineage_id)
	var frozen: CompletionSnapshot = CompletionSnapshot.new({"specialists": SpecialistRules.capture(state, TopologyService.rebuild(state), [feature.lineage_id], [])})
	_overlay(state, Vector2i.ZERO, &"market", &"market", feature.lineage_id)
	state.features.tracks.values = [99, 99, 99, 99]
	expect_equal(SpecialistRules.calculate(frozen)[0]["gains"], [0, 0, 2, 0], "Frozen peer state ignores later overlays and Track gain")
	expect_equal(_capture(state, [feature.lineage_id])[0]["gains"][2], 4, "Fresh genuine completion reevaluates current state")
	return true


func effects_return_only_after_batch() -> bool:
	var state: RunState = _single(TYPE.ROAD)
	var piece: SpecialistPieceState = _bind(state, _at(state, Vector2i.ZERO, TYPE.ROAD), &"")
	var effects: Array[Dictionary] = _capture(state, [piece.assigned_target_id])
	var rng: int = state.rng.current_state
	var pipeline: CompletionPipeline = CompletionPipeline.new()
	SpecialistRules.apply(state, effects, 0, pipeline)
	expect_equal(piece.status, SpecialistPieceState.Status.ASSIGNED, "Effect application does not return a piece early")
	expect_equal(state.features.tracks.values, [0, 2, 0, 0], "Generic effect applied")
	SpecialistRules.return_pieces(state, effects, 0, pipeline)
	pipeline.drain_children(state)
	expect_equal(piece.status, SpecialistPieceState.Status.AVAILABLE, "Separate return stage")
	expect_equal(piece.assigned_target_id, 0, "Return clears stale target")
	expect_true(piece.growth_baseline_component_ids.is_empty(), "Return clears growth commitment")
	expect_equal(state.rng.current_state, rng, "Scoring and return consume no RNG")
	return true


func bonus_does_not_change_base_history() -> bool:
	var state: RunState = _single(TYPE.ROAD)
	var feature: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.ROAD)
	var lineage: FeatureLineageState = state.features.lineage(feature.lineage_id)
	lineage.scored_component_ids = feature.component_ids.duplicate()
	lineage.scored_settlement_ids = [123]
	_bind(state, feature, &"")
	var pipeline: CompletionPipeline = CompletionPipeline.new()
	SpecialistRules.apply(state, _capture(state, [feature.lineage_id]), 0, pipeline)
	expect_equal(lineage.scored_component_ids, feature.component_ids, "No Specialist pollution of base components")
	expect_equal(lineage.scored_settlement_ids, [123], "No Specialist payment anti-farming set")
	expect_true(lineage.completion_ids.is_empty(), "Specialist apply does not invent feature completion")
	return true


func no_completion_no_specialist_fact() -> bool:
	var state: RunState = _single(TYPE.FOREST)
	_bind(state, _at(state, Vector2i.ZERO, TYPE.FOREST), &"specialist.forester")
	expect_true(_capture(state, []).is_empty(), "An assigned unfinished feature has no bonus")
	return true


func _facts(role: String, type: int = 0) -> Dictionary:
	return {"piece_id": 1, "role_definition_id": role, "target_type": type,
		"target_id": 1, "growth_count": 0, "size": 0, "network_settlement_count": 0,
		"families": [], "field_count": 0, "forest_count": 0, "undeveloped": false,
		"touching_settlements": [], "port_settlements": []}


func _calculate(facts: Array[Dictionary]) -> Array[Dictionary]:
	return SpecialistRules.calculate(CompletionSnapshot.new({"specialists": facts}))


func _capture(state: RunState, ids: Array[int]) -> Array[Dictionary]:
	return _calculate(SpecialistRules.capture(state, TopologyService.rebuild(state), ids, []))


func _at(state: RunState, coordinate: Vector2i, type: int) -> CurrentFeature:
	return SpecialistRules.find_feature(TopologyService.rebuild(state), state.features.component_at(coordinate, type).lineage_id)


func _bind(state: RunState, feature: CurrentFeature, role: StringName) -> SpecialistPieceState:
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	piece.status = SpecialistPieceState.Status.ASSIGNED
	piece.role_definition_id = role
	piece.assigned_target_type = feature.feature_type
	piece.assigned_target_id = feature.lineage_id
	piece.assigned_act = 1
	piece.assigned_placement_index = 0
	piece.growth_baseline_component_ids = SpecialistRules.all_component_ids(state)
	return piece


func _single(type: int) -> RunState:
	var state: RunState = Fixture.empty()
	var edge: DomainTypes.EdgeType = FeatureState.edge_for_type(type)
	Fixture.add(state, Vector2i.ZERO, [edge, EDGE.FIELD, EDGE.FIELD, EDGE.FIELD])
	Fixture.reconcile(state)
	SpecialistRules.initialize(state)
	return state


func _settlement() -> RunState:
	var state: RunState = _single(TYPE.SETTLEMENT)
	state.expansion.board.get_cell(Vector2i.ZERO).field_supports_settlement = true
	return state


func _overlay(state: RunState, coordinate: Vector2i, stage: StringName,
		family: StringName, host: int) -> void:
	var development: DevelopmentState = DevelopmentState.new()
	development.tile_copy_id = state.id_allocator.allocate()
	development.stage = stage
	development.family_id = family
	development.host_kind = &"settlement"
	development.host_lineage_id = host
	state.expansion.board.get_cell(coordinate).developments.append(development)


func _chain(count: int) -> RunState:
	var state: RunState = Fixture.empty()
	state.trade = TradeState.new()
	for x: int in range(count * 2):
		var last: bool = x == count * 2 - 1
		var left: DomainTypes.EdgeType = EDGE.SETTLEMENT if x % 2 == 0 else EDGE.ROAD
		var right: DomainTypes.EdgeType = EDGE.FIELD if last else (EDGE.ROAD if x % 2 == 0 else EDGE.SETTLEMENT)
		var north: DomainTypes.EdgeType = EDGE.ROAD if x == 2 else EDGE.FIELD
		var cell: BoardCellState = Fixture.add(state, Vector2i(x, 0), [north, right, EDGE.FIELD, left])
		if not last:
			cell.relationships.append(TileFeatureRelationship.new())
	Fixture.reconcile(state)
	TradeNetworkService.reconcile(state)
	SpecialistRules.initialize(state)
	return state


func _merchant(count: int) -> Array:
	var state: RunState = _chain(count)
	var road: CurrentFeature = _at(state, Vector2i.ZERO, TYPE.ROAD)
	_bind(state, road, &"specialist.merchant")
	return _capture(state, [road.lineage_id])[0]["gains"]


func _river_contacts() -> RunState:
	var state: RunState = Fixture.empty()
	var cell: BoardCellState = Fixture.add(state, Vector2i.ZERO, [EDGE.SETTLEMENT, EDGE.RIVER, EDGE.FOREST, EDGE.RIVER])
	for kind: int in [TileFeatureRelationship.Kind.SETTLEMENT_RIVER_TOUCH, TileFeatureRelationship.Kind.FOREST_RIVER_TOUCH]:
		var relation: TileFeatureRelationship = TileFeatureRelationship.new()
		relation.kind = kind as TileFeatureRelationship.Kind
		relation.from_edge_type = EDGE.SETTLEMENT if kind == TileFeatureRelationship.Kind.SETTLEMENT_RIVER_TOUCH else EDGE.FOREST
		relation.to_edge_type = EDGE.RIVER
		cell.relationships.append(relation)
	Fixture.reconcile(state)
	SpecialistRules.initialize(state)
	return state


func _merger_growth(type: int, role: StringName) -> bool:
	var state: RunState = _single(type)
	var edge: DomainTypes.EdgeType = FeatureState.edge_for_type(type)
	var feature: CurrentFeature = _at(state, Vector2i.ZERO, type)
	var piece: SpecialistPieceState = _bind(state, feature, role)
	var original_act: int = piece.assigned_act
	# A foreign feature is genuinely constructed after assignment, but existed
	# before the connecting placement. It must still not count as assigned growth.
	Fixture.add(state, Vector2i(0, -2), [edge, EDGE.FIELD, edge, EDGE.FIELD])
	SpecialistRules.remap_and_growth(state, Fixture.reconcile(state))
	var foreign_id: int = state.features.component_at(Vector2i(0, -2), type).component_id
	expect_true(piece.qualifying_component_ids.is_empty(), "Foreign construction is not assigned growth")
	Fixture.add(state, Vector2i.UP, [edge, EDGE.FIELD, edge, EDGE.FIELD])
	SpecialistRules.remap_and_growth(state, Fixture.reconcile(state))
	var joining_id: int = state.features.component_at(Vector2i.UP, type).component_id
	expect_equal(piece.qualifying_component_ids, [joining_id], "Only new connecting component qualifies")
	expect_true(not piece.qualifying_component_ids.has(foreign_id), "Foreign postassignment old component excluded on merger")
	expect_true(piece.assigned_target_id != feature.lineage_id, "Piece follows descendant identity")
	expect_equal(piece.assigned_act, original_act, "Commitment timing retained")
	var gain_track: int = 1 if type == TYPE.ROAD else 3
	expect_equal(_capture(state, [piece.assigned_target_id])[0]["gains"][gain_track], 1, "Scoring uses qualifying identities, not size subtraction")
	return true
