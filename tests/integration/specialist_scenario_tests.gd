extends "res://tests/framework/test_suite.gd"
## Live commands prove Specialist timing, locality, merge safety and continuation.

const Fixture = preload("res://tests/fixtures/phase_seven_factory.gd")
const TYPE = DomainTypes.FeatureType
const TRACK = DomainTypes.TrackType


func tests() -> Array[Callable]:
	return [road_steward_completion, settlement_steward_completion, forest_steward_completion,
		river_steward_completion, monastery_steward_completion,
		placement_pauses_before_refill, decline_resumes_once, only_one_assignment,
		unrelated_feature_excluded, completed_feature_excluded, completed_monastery_excluded,
		housing_locality, market_locality, town_square_locality, port_locality,
		lodge_locality, mill_locality, abbey_preserves_assignment,
		urban_reopened_locality, bridge_created_locality, rewild_created_locality,
		ordinary_merge_rejected_atomically, urban_merge_rejected_atomically,
		bridge_merge_rejected_atomically, rewild_merge_rejected_atomically,
		legal_urban_merge_follows_assignment, legal_bridge_growth_excludes_old_components,
		legal_rewild_growth_excludes_old_components, pending_assignment_round_trip,
		assigned_round_trip, completed_return_round_trip, stale_assignment_is_atomic,
		placement_while_choice_pending_is_atomic, assignment_consumes_no_rng,
		deterministic_pending_continuation, simultaneous_assigned_completions,
		returned_piece_not_in_pending_local_choice, bridge_growth_scores_on_later_completion,
		rewild_growth_scores_on_later_completion, reserve_pause_never_refills_hand,
		bridge_new_access_offers_settlement, rewild_changed_field_offers_settlement]


func _generic(type: int, extension: StringName, at: Vector2i, rotation: int,
		cap: StringName, cap_at: Vector2i, cap_rotation: int, track: int) -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.play(state, content, extension, at, rotation)
	var piece_id: int = Fixture.assign(state, content, type)
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	expect_equal(piece.status, 1, "Piece remains assigned before completion")
	expect_equal(_specialist_gains(state, piece_id, track), 0, "No early Specialist scoring")
	Fixture.play(state, content, cap, cap_at, cap_rotation)
	Fixture.decline(state, content)
	expect_equal(_specialist_gains(state, piece_id, track), 2, "Generic Steward awards exactly +2 on genuine completion")
	expect_equal(piece.status, 0, "Completed piece returns available")
	expect_equal(piece.assigned_target_id, 0, "Return clears stale target")
	expect_true(state.pending_choice == null, "Returned piece gets no same-resolution assignment")
	_valid(state, content)
	return true


func road_steward_completion() -> bool:
	return _generic(TYPE.ROAD, &"tile.straight_road", Vector2i.RIGHT, 1,
		&"tile.road_end", Vector2i(2, 0), 3, TRACK.TRADE)


func settlement_steward_completion() -> bool:
	return _generic(TYPE.SETTLEMENT, &"tile.settlement_throughway", Vector2i.UP, 0,
		&"tile.hamlet_edge", Vector2i(0, -2), 2, TRACK.POPULATION)


func forest_steward_completion() -> bool:
	return _generic(TYPE.FOREST, &"tile.forest_belt", Vector2i.LEFT, 1,
		&"tile.forest_edge", Vector2i(-2, 0), 1, TRACK.ECOLOGY)


func river_steward_completion() -> bool:
	return _generic(TYPE.RIVER, &"tile.river_run", Vector2i.DOWN, 0,
		&"tile.river_end", Vector2i(0, 2), 0, TRACK.ECOLOGY)


func monastery_steward_completion() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.Previous.create(content)
	var center: Vector2i = Fixture.Development.fields(state, content, 7)
	Fixture.activate(state)
	Fixture.play(state, content, &"tile.development.monastery", center)
	var piece_id: int = Fixture.assign(state, content, 4)
	Fixture.play(state, content, &"tile.open_fields", center + Vector2i(-1, -1))
	expect_equal(_specialist_gains(state, piece_id, TRACK.CULTURE), 2, "Eighth square completes assigned Monastery")
	expect_equal(state.specialists.pieces[0].status, 0, "Monastery returns generic Steward")
	_valid(state, content)
	return true


func placement_pauses_before_refill() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	var count: int = state.expansion.normal_placements
	var rng: int = state.rng.operation_count
	var copy_id: int = Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	expect_equal(state.expansion.board.get_cell(Vector2i.RIGHT).base_tile_copy_id, copy_id, "Board commits before optional assignment")
	expect_equal(state.expansion.normal_placements, count + 1, "Placement counted exactly once before pause")
	expect_equal(state.expansion.hand[0], 0, "Hand slot stays empty while consequences pause")
	expect_true(state.pending_choice != null and state.resolution != null, "Choice and continuation are authoritative")
	expect_equal(state.rng.operation_count, rng, "Assignment pause consumes no RNG")
	_valid(state, content)
	return true


func decline_resumes_once() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	var choice_id: int = state.pending_choice.choice_id
	Fixture.decline(state, content)
	expect_true(not state.expansion.hand.has(0), "Declining finishes consequences and refills")
	var fingerprint: String = StateNormalizer.fingerprint(state)
	var result: ValidationResult = RulesEngine.execute(state, content,
		ResolveSpecialistAssignmentCommand.new(choice_id, 0, -1, 0, true))
	expect_true(not result.is_valid, "Repeated decline rejected")
	expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Repeated decline does not replay placement/refill")
	return true


func only_one_assignment() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.play(state, content, &"tile.settlement_gate", Vector2i.RIGHT, 2)
	var options: Array = state.pending_choice.options.duplicate(true)
	expect_true(options.size() >= 2, "Several legal piece/feature combinations share one choice")
	var choice_id: int = state.pending_choice.choice_id
	var selected: Dictionary = options[0]
	Fixture.assign(state, content, int(selected.target_type), int(selected.target_id))
	var before: String = StateNormalizer.fingerprint(state)
	var result: ValidationResult = RulesEngine.execute(state, content,
		ResolveSpecialistAssignmentCommand.new(choice_id, state.specialists.pieces[1].piece_id,
		int(selected.target_type), int(selected.target_id)))
	expect_true(not result.is_valid, "Placement cannot assign a second available piece")
	expect_equal(StateNormalizer.fingerprint(state), before, "Second assignment is inert")
	return true


func unrelated_feature_excluded() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	var settlement: int = Fixture.member(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	for option: Dictionary in state.pending_choice.options:
		expect_true(int(option.target_id) != settlement, "Nearby but unaltered Settlement is not a local target")
	return true


func completed_feature_excluded() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.play(state, content, &"tile.road_end", Vector2i.RIGHT, 3)
	expect_true(state.pending_choice == null, "Closing Road cannot receive last-second assignment")
	for piece: SpecialistPieceState in state.specialists.pieces:
		expect_equal(piece.status, 0, "Available pieces never deploy automatically")
	return true


func completed_monastery_excluded() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.Previous.create(content)
	var center: Vector2i = Fixture.Development.fields(state, content, 8)
	Fixture.activate(state)
	Fixture.play(state, content, &"tile.development.monastery", center)
	expect_true(state.pending_choice == null, "Already surrounded Monastery has no assignment opportunity")
	return true


func _development_locality(definition: StringName, type: int) -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	var target: int = Fixture.member(state, Vector2i.ZERO, type)
	Fixture.play(state, content, definition, Vector2i.ZERO)
	assert(state.pending_choice != null)
	for option: Dictionary in state.pending_choice.options:
		expect_equal(int(option.target_type), type, "Development offers its specific affected host type")
		expect_equal(int(option.target_id), target, "Development does not offer all coincident feature types")
	Fixture.assign(state, content, type, target)
	_valid(state, content)
	return true


func housing_locality() -> bool:
	return _development_locality(&"tile.development.housing", TYPE.SETTLEMENT)


func market_locality() -> bool:
	return _development_locality(&"tile.development.market", TYPE.SETTLEMENT)


func town_square_locality() -> bool:
	return _development_locality(&"tile.development.town_square", TYPE.SETTLEMENT)


func port_locality() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.Previous.create(content)
	Fixture.Geography.add(state, content, &"tile.riverside_hamlet", Vector2i.DOWN, 1)
	Fixture.activate(state)
	var target: int = Fixture.member(state, Vector2i.DOWN, TYPE.SETTLEMENT)
	Fixture.play(state, content, &"tile.development.port", Vector2i.DOWN)
	assert(state.pending_choice != null)
	for option: Dictionary in state.pending_choice.options:
		expect_equal(int(option.target_type), TYPE.SETTLEMENT, "Port assignment belongs to its Settlement, not its associated River")
		expect_equal(int(option.target_id), target, "Port locality retains specific unfinished Settlement host")
	return true


func lodge_locality() -> bool:
	return _development_locality(&"tile.development.foresters_lodge", TYPE.FOREST)


func mill_locality() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.Previous.create(content)
	Fixture.Geography.add(state, content, &"tile.settlement_throughway", Vector2i.UP)
	Fixture.activate(state)
	var target: int = Fixture.member(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	Fixture.play(state, content, &"tile.development.mill", Vector2i.UP)
	assert(state.pending_choice != null)
	for option: Dictionary in state.pending_choice.options:
		expect_equal(int(option.target_type), TYPE.SETTLEMENT, "Mill offers directly touching unfinished Settlement")
		expect_equal(int(option.target_id), target, "Mill target derives current contact, not permanently bound host")
	return true


func abbey_preserves_assignment() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.Previous.create(content)
	var center: Vector2i = Fixture.Development.fields(state, content, 7)
	Fixture.activate(state)
	Fixture.play(state, content, &"tile.development.monastery", center)
	var piece_id: int = Fixture.assign(state, content, 4)
	var enclosure: int = state.specialists.pieces[0].assigned_target_id
	Fixture.play(state, content, &"tile.development.abbey", center)
	Fixture.decline(state, content)
	expect_equal(state.specialists.pieces[0].assigned_target_id, enclosure, "Physical Upgrade preserves occupied persistent enclosure")
	Fixture.play(state, content, &"tile.open_fields", center + Vector2i(-1, -1))
	expect_equal(_specialist_gains(state, piece_id, TRACK.CULTURE), 2, "Existing generic assignment resolves with completed Abbey stage")
	return true


func urban_reopened_locality() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.Previous.create(content)
	Fixture.Development.complete_settlement(state, content)
	Fixture.activate(state)
	var lineage: int = Fixture.member(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	Fixture.play(state, content, Fixture.Previous.URBAN, Vector2i(0, -2), 0, &"urban_expansion")
	Fixture.assign(state, content, TYPE.SETTLEMENT, lineage)
	expect_equal(state.specialists.pieces[0].assigned_target_id, lineage, "Reopened Settlement accepts new local assignment")
	Fixture.play(state, content, &"tile.hamlet_edge", Vector2i(0, -3), 2)
	Fixture.decline(state, content)
	expect_equal(state.specialists.pieces[0].status, 0, "Genuine later re-completion returns assignment")
	return true


func bridge_created_locality() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.activate(Fixture.Previous.river(content, true))
	Fixture.play(state, content, Fixture.Previous.BRIDGE, Vector2i.DOWN, -1, &"bridge")
	var road: int = Fixture.member(state, Vector2i.DOWN, TYPE.ROAD)
	Fixture.assign(state, content, TYPE.ROAD, road)
	expect_equal(state.specialists.pieces[0].assigned_target_id, road, "Bridge-created unfinished Road is a local target")
	return true


func rewild_created_locality() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.Previous.create(content)
	Fixture.Geography.add(state, content, &"tile.road_end", Vector2i.RIGHT, 3)
	Fixture.Geography.add(state, content, &"tile.open_fields", Vector2i(2, 0))
	Fixture.activate(state)
	Fixture.play(state, content, Fixture.Previous.REWILD, Vector2i(2, 0), 0, &"rewilding")
	var forest: int = Fixture.member(state, Vector2i(2, 0), TYPE.FOREST)
	Fixture.assign(state, content, TYPE.FOREST, forest)
	expect_equal(state.specialists.pieces[0].assigned_target_id, forest, "New Rewilding Forest can receive local assignment")
	return true


func _reject_merge(kind: StringName) -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState
	var definition: StringName
	var at: Vector2i
	var rotation: int = 0
	var mode: StringName = &""
	var type: int
	var first: Vector2i
	var second: Vector2i
	if kind == &"urban":
		state = Fixture.settlement_pair(content)
		definition = Fixture.Previous.URBAN
		at = Vector2i(0, -2)
		rotation = 2
		mode = &"urban_expansion"
		type = TYPE.SETTLEMENT
		first = Vector2i.UP
		second = Vector2i(0, -3)
	elif kind == &"bridge":
		state = Fixture.bridge_pair(content)
		definition = Fixture.Previous.BRIDGE
		at = Vector2i.DOWN
		mode = &"bridge"
		rotation = -1
		type = TYPE.ROAD
		first = Vector2i.ONE
		second = Vector2i(-1, 1)
	else:
		state = Fixture.forest_pair(content)
		definition = Fixture.Previous.REWILD if kind == &"rewild" else &"tile.forest_belt"
		at = Vector2i(-1, 1)
		mode = &"rewilding_expansion" if kind == &"rewild" else &""
		type = TYPE.FOREST
		first = Vector2i.LEFT
		second = Vector2i(-1, 2)
	# Cache otherwise-valid complete intent before controlled assignments occupy both parents.
	var command: PlaceTileCommand = Fixture.intent(state, content, definition, at, rotation, mode)
	Fixture.bind_for_fixture(state, content, first, type)
	Fixture.bind_for_fixture(state, content, second, type, 1)
	var fingerprint: String = StateNormalizer.fingerprint(state)
	var rng: int = state.rng.operation_count
	var result: ValidationResult = RulesEngine.execute(state, content, command)
	expect_true(not result.is_valid, kind + " rejects a two-piece merged connected feature before commit")
	expect_equal(StateNormalizer.fingerprint(state), fingerprint, kind + " rejection preserves all physical state, histories and IDs")
	expect_equal(state.rng.operation_count, rng, kind + " rejection consumes no RNG")
	return true


func ordinary_merge_rejected_atomically() -> bool:
	return _reject_merge(&"ordinary")


func urban_merge_rejected_atomically() -> bool:
	return _reject_merge(&"urban")


func bridge_merge_rejected_atomically() -> bool:
	return _reject_merge(&"bridge")


func rewild_merge_rejected_atomically() -> bool:
	return _reject_merge(&"rewild")


func legal_urban_merge_follows_assignment() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.settlement_pair(content)
	Fixture.bind_for_fixture(state, content, Vector2i.UP, TYPE.SETTLEMENT)
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	var parent: int = piece.assigned_target_id
	var assigned_act: int = piece.assigned_act
	var placement: int = piece.assigned_placement_index
	Fixture.play(state, content, Fixture.Previous.URBAN, Vector2i(0, -2), 2, &"urban_expansion")
	Fixture.decline(state, content)
	expect_true(piece.assigned_target_id != parent, "One assignment follows descendant Settlement identity")
	expect_equal(piece.assigned_target_id, Fixture.member(state, Vector2i.UP, TYPE.SETTLEMENT), "Assignment targets current connected host")
	expect_equal(piece.assigned_act, assigned_act, "Merger preserves assignment Act")
	expect_equal(piece.assigned_placement_index, placement, "Merger preserves original assignment timing")
	_valid(state, content)
	return true


func legal_bridge_growth_excludes_old_components() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.bridge_pair(content)
	Fixture.bind_for_fixture(state, content, Vector2i.ONE, TYPE.ROAD, 0, &"specialist.cartographer")
	var absorbed: int = state.features.component_at(Vector2i(-1, 1), TYPE.ROAD).component_id
	Fixture.play(state, content, Fixture.Previous.BRIDGE, Vector2i.DOWN, -1, &"bridge")
	Fixture.decline(state, content)
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	var bridge: int = state.features.component_at(Vector2i.DOWN, TYPE.ROAD).component_id
	expect_true(piece.qualifying_component_ids.has(bridge), "New Bridge Road contribution is genuine post-assignment growth")
	expect_true(not piece.qualifying_component_ids.has(absorbed), "Absorbed old Road component is not growth")
	expect_equal(piece.qualifying_component_ids.size(), 1, "No extra Road tile from extending old neighbor edges")
	var loaded: RunState = Fixture.load_copy(state, content)
	expect_equal(loaded.specialists.pieces[0].qualifying_component_ids, piece.qualifying_component_ids, "Cartographer growth survives load")
	return true


func legal_rewild_growth_excludes_old_components() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.forest_pair(content)
	Fixture.bind_for_fixture(state, content, Vector2i.LEFT, TYPE.FOREST, 0, &"specialist.forester")
	var absorbed: int = state.features.component_at(Vector2i(-1, 2), TYPE.FOREST).component_id
	Fixture.play(state, content, Fixture.Previous.REWILD, Vector2i(-1, 1), 0, &"rewilding_expansion")
	Fixture.decline(state, content)
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	var growth: int = state.features.component_at(Vector2i(-1, 1), TYPE.FOREST).component_id
	expect_equal(piece.qualifying_component_ids, [growth], "Only new Rewilding tile counts, not absorbed old Forest")
	expect_true(not piece.qualifying_component_ids.has(absorbed), "Historical absorbed Forest is excluded")
	var loaded: RunState = Fixture.load_copy(state, content)
	expect_equal(loaded.specialists.pieces[0].qualifying_component_ids, piece.qualifying_component_ids, "Forester attribution survives load")
	return true


func pending_assignment_round_trip() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	var fingerprint: String = StateNormalizer.fingerprint(state)
	var rng: int = state.rng.operation_count
	for iteration: int in range(3):
		state = Fixture.load_copy(state, content)
		expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Pending load is inert: scores, events, IDs and all state unchanged")
		expect_equal(state.rng.operation_count, rng, "Pending load consumes zero RNG")
		expect_equal(state.expansion.hand[0], 0, "Load does not refill unresolved placement")
	return true


func assigned_round_trip() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	Fixture.assign(state, content, TYPE.ROAD)
	expect_equal(StateNormalizer.fingerprint(Fixture.load_copy(state, content)), StateNormalizer.fingerprint(state), "Assigned generic preserves identity, target and growth baseline")
	return true


func completed_return_round_trip() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	Fixture.assign(state, content, TYPE.ROAD)
	Fixture.play(state, content, &"tile.road_end", Vector2i(2, 0), 3)
	var fingerprint: String = StateNormalizer.fingerprint(state)
	for iteration: int in range(3):
		state = Fixture.load_copy(state, content)
		expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Load does not replay completed effects or returns")
	return true


func stale_assignment_is_atomic() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	var option: Dictionary = state.pending_choice.options[0]
	var command: ResolveSpecialistAssignmentCommand = ResolveSpecialistAssignmentCommand.new(
		state.pending_choice.choice_id + 1, int(option.piece_id), int(option.target_type), int(option.target_id))
	var fingerprint: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, content, command).is_valid, "Wrong choice identity rejected")
	expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Stale assignment leaves RNG, IDs, events and physical state unchanged")
	return true


func placement_while_choice_pending_is_atomic() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	var fingerprint: String = StateNormalizer.fingerprint(state)
	var command: PlaceTileCommand = PlaceTileCommand.new(state.expansion.hand[1],
		TileLocationState.Kind.ACTIVE_HAND, Vector2i.UP, 2)
	expect_true(not RulesEngine.execute(state, content, command).is_valid, "Another placement cannot interleave unresolved assignment")
	expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Rejected interleaving is inert")
	return true


func assignment_consumes_no_rng() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	var operations: int = state.rng.operation_count
	Fixture.assign(state, content, TYPE.ROAD)
	expect_equal(state.rng.operation_count, operations, "Player assignment and ordinary nonempty bag refill consume no RNG")
	return true


func deterministic_pending_continuation() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	var loaded: RunState = Fixture.load_copy(state, content)
	expect_equal(loaded.pending_choice.options, state.pending_choice.options, "Exact assignment combinations survive save")
	Fixture.assign(state, content, TYPE.ROAD)
	Fixture.assign(loaded, content, TYPE.ROAD)
	expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Identical pending decision resumes same consequences/refill")
	Fixture.play(state, content, &"tile.road_end", Vector2i(2, 0), 3)
	Fixture.play(loaded, content, &"tile.road_end", Vector2i(2, 0), 3)
	expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Identical future completion keeps scores, IDs, RNG and histories equal")
	return true


func _specialist_gains(state: RunState, piece_id: int, track: int) -> int:
	var result: int = 0
	for event: FeatureHistoryRecord in state.features.history:
		if event.kind == &"realm_track_changed" and event.source_id == piece_id and event.track == track:
			result += event.amount
	return result


func _valid(state: RunState, content: ContentRegistry) -> void:
	var report: InvariantReport = InvariantValidator.validate(state, content)
	expect_true(report.is_valid, "Scenario invariants: " + report.describe())


func simultaneous_assigned_completions() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.Previous.create(content)
	Fixture.Geography.add(state, content, &"tile.river_end", Vector2i.DOWN)
	Fixture.Geography.add(state, content, &"tile.hamlet_edge", Vector2i.ONE)
	Fixture.activate(state)
	Fixture.bind_for_fixture(state, content, Vector2i.ZERO, TYPE.ROAD)
	Fixture.bind_for_fixture(state, content, Vector2i.ONE, TYPE.SETTLEMENT, 1)
	var road_piece: int = state.specialists.pieces[0].piece_id
	var settlement_piece: int = state.specialists.pieces[1].piece_id
	Fixture.play(state, content, &"tile.settlement_gate", Vector2i.RIGHT, 2)
	expect_equal(_specialist_gains(state, road_piece, TRACK.TRADE), 2, "Shared placement completes assigned Road")
	expect_equal(_specialist_gains(state, settlement_piece, TRACK.POPULATION), 2, "Shared placement completes assigned Settlement")
	for piece: SpecialistPieceState in state.specialists.pieces:
		expect_equal(piece.status, 0, "Both simultaneous effects resolve then return")
	expect_true(state.pending_choice == null, "Simultaneously returned pieces cannot reassign")
	_valid(state, content)
	return true


func returned_piece_not_in_pending_local_choice() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	Fixture.assign(state, content, TYPE.ROAD)
	var returning: int = state.specialists.pieces[0].piece_id
	Fixture.play(state, content, &"tile.settlement_gate", Vector2i(2, 0), 2)
	assert(state.pending_choice != null)
	for option: Dictionary in state.pending_choice.options:
		expect_true(int(option.piece_id) != returning, "Completing Road's piece is absent from this placement's Settlement offer")
		expect_equal(int(option.target_type), TYPE.SETTLEMENT, "Only newly unfinished Settlement can receive remaining available piece")
	expect_equal(_specialist_gains(state, returning, TRACK.TRADE), 0, "Completion consequences remain frozen until local choice resolves")
	Fixture.assign(state, content, TYPE.SETTLEMENT, 0, 1)
	expect_equal(_specialist_gains(state, returning, TRACK.TRADE), 2, "Road resolves after existing local assignment choice")
	expect_equal(state.specialists.pieces[0].status, 0, "Returned piece awaits future placements")
	expect_equal(state.specialists.pieces[1].status, 1, "Chosen other piece remains on unfinished Settlement")
	return true


func bridge_growth_scores_on_later_completion() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.bridge_pair(content)
	Fixture.bind_for_fixture(state, content, Vector2i.ONE, TYPE.ROAD, 0, &"specialist.cartographer")
	var piece_id: int = state.specialists.pieces[0].piece_id
	Fixture.play(state, content, Fixture.Previous.BRIDGE, Vector2i.DOWN, -1, &"bridge")
	Fixture.decline(state, content)
	Fixture.play(state, content, &"tile.road_end", Vector2i(1, 2), 0)
	Fixture.decline(state, content)
	Fixture.play(state, content, &"tile.road_end", Vector2i(-1, 2), 0)
	Fixture.decline(state, content)
	expect_equal(_specialist_gains(state, piece_id, TRACK.TRADE), 3, "Cartographer scores Bridge and two new caps, excluding every absorbed old component")
	expect_equal(state.specialists.pieces[0].status, 0, "Cartographer returns after later physical Road completion")
	return true


func rewild_growth_scores_on_later_completion() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.forest_pair(content)
	Fixture.bind_for_fixture(state, content, Vector2i.LEFT, TYPE.FOREST, 0, &"specialist.forester")
	var piece_id: int = state.specialists.pieces[0].piece_id
	Fixture.play(state, content, Fixture.Previous.REWILD, Vector2i(-1, 1), 0, &"rewilding_expansion")
	Fixture.decline(state, content)
	Fixture.play(state, content, &"tile.forest_edge", Vector2i(-1, -1), 2)
	Fixture.decline(state, content)
	expect_equal(_specialist_gains(state, piece_id, TRACK.ECOLOGY), 2, "Forester scores new connecting Rewilding and cap, never absorbed old Forest tiles")
	expect_equal(state.specialists.pieces[0].status, 0, "Forester returns on real Forest re-completion")
	return true


func reserve_pause_never_refills_hand() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	var copy_id: int = Fixture.Development.acquire_hand(state, &"tile.straight_road")
	assert(RulesEngine.execute(state, content, ReserveTileCommand.new(copy_id)).is_valid)
	var hand: Array[int] = state.expansion.hand.duplicate()
	var intent: PlaceTileCommand = null
	for option: PlacementOption in PlacementQueryService.query_for_copy(state, content, copy_id):
		if option.coordinate == Vector2i.RIGHT and option.rotation == 1:
			intent = Fixture.Previous.command(option, TileLocationState.Kind.RESERVE)
	assert(intent != null)
	assert(RulesEngine.execute(state, content, intent).is_valid)
	expect_equal(state.expansion.reserve_id, 0, "Reserve empties before assignment pause")
	expect_equal(state.expansion.hand, hand, "Reserve placement pause leaves hand untouched")
	Fixture.assign(state, content, TYPE.ROAD)
	expect_equal(state.expansion.hand, hand, "Assignment completion does not refill a Reserve placement")
	return true


func bridge_new_access_offers_settlement() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.Previous.river(content, true)
	Fixture.Geography.add(state, content, &"tile.hamlet_edge", Vector2i.ONE)
	Fixture.activate(state)
	var settlement: int = Fixture.member(state, Vector2i.ONE, TYPE.SETTLEMENT)
	Fixture.play(state, content, Fixture.Previous.BRIDGE, Vector2i.DOWN, -1, &"bridge")
	var found: bool = false
	for option: Dictionary in state.pending_choice.options:
		if int(option.target_type) == TYPE.SETTLEMENT and int(option.target_id) == settlement:
			found = true
		expect_true(int(option.target_type) != TYPE.RIVER, "Preserved River receives no invented Bridge assignment locality")
	expect_true(found, "Neighboring Settlement newly gaining explicit Road access is directly affected")
	Fixture.assign(state, content, TYPE.SETTLEMENT, settlement)
	return true


func rewild_changed_field_offers_settlement() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.Previous.create(content)
	Fixture.Geography.add(state, content, &"tile.settlement_throughway", Vector2i.UP)
	Fixture.activate(state)
	var settlement: int = Fixture.member(state, Vector2i.UP, TYPE.SETTLEMENT)
	Fixture.play(state, content, Fixture.Previous.REWILD, Vector2i.UP, 1, &"rewilding")
	var targets: Array[int] = []
	for option: Dictionary in state.pending_choice.options:
		if int(option.target_type) not in targets:
			targets.append(int(option.target_type))
	expect_true(targets.has(TYPE.FOREST), "New Forest is an assignment candidate")
	expect_true(targets.has(TYPE.SETTLEMENT), "Settlement losing same-tile Field support is directly affected")
	Fixture.assign(state, content, TYPE.SETTLEMENT, settlement)
	return true
