extends "res://tests/framework/test_suite.gd"
## Natural seed-1 opening hand; no injected tile or modified starting piece state.

const F = preload("res://tests/fixtures/phase_nine_factory.gd")
const S = preload("res://tests/fixtures/phase_seven_factory.gd")
const TYPE = DomainTypes.FeatureType
const OPEN_AT: Vector2i = Vector2i(1, 1)


func tests() -> Array[Callable]:
	return [starting_stewards_survive_setup, first_settlement_offers_both_generics,
		first_settlement_assigns_one_piece, first_settlement_decline_keeps_both_available,
		pending_generic_assignment_round_trips, first_settlement_completion_has_no_late_assignment,
		generic_survives_ineligible_trained_peer, generic_and_eligible_trained_peer_both_appear,
		occupied_settlement_skips_assignment, unavailable_pieces_skip_first_settlement_choice,
		natural_starting_monastery_offers_generic_stewards]


func _opening_command(state: RunState, content: ContentRegistry,
		at: Vector2i = OPEN_AT, rotation: int = 0) -> PlaceTileCommand:
	for id: int in state.expansion.hand:
		if PhysicalTileRules.find_copy(state, id).definition_id != &"tile.hamlet_edge":
			continue
		for option: PlacementOption in PlacementQueryService.query_for_copy(state, content, id):
			if option.coordinate == at and option.rotation == rotation:
				return F.Intent.command(option)
	assert(false, "Seed 1 Starter option 0 must naturally draw this legal Hamlet Edge")
	return null


func _pending(content: ContentRegistry) -> RunState:
	var state: RunState = F.started(content, 1)
	var result: ValidationResult = RulesEngine.execute(state, content, _opening_command(state, content))
	assert(result.is_valid, result.user_message + str(result.debug_details))
	assert(state.pending_choice != null and state.pending_choice.kind == &"specialist_assignment")
	return state


func _assignment(state: RunState) -> ResolveSpecialistAssignmentCommand:
	var option: Dictionary = state.pending_choice.options[0]
	return ResolveSpecialistAssignmentCommand.new(state.pending_choice.choice_id,
		int(option.piece_id), int(option.target_type), int(option.target_id))


func _expect_generic_available(state: RunState) -> void:
	expect_equal(state.specialists.pieces.size(), 2, "Exactly two starting pieces")
	expect_true(state.specialists.pieces[0].piece_id != state.specialists.pieces[1].piece_id,
		"Starting Stewards have distinct stable identities")
	for piece: SpecialistPieceState in state.specialists.pieces:
		expect_equal(piece.role_definition_id, &"", "Starting piece is generic, not a trained Specialist")
		expect_equal(piece.status, SpecialistPieceState.Status.AVAILABLE, "Starting Steward available")
		expect_equal(piece.assigned_target_id, 0, "No implicit setup assignment")
		expect_equal(piece.assigned_target_type, -1, "No implicit target type")


func starting_stewards_survive_setup() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(1, content)
	_expect_generic_available(state)
	var ids: Array[int] = [state.specialists.pieces[0].piece_id, state.specialists.pieces[1].piece_id]
	expect_true(RulesEngine.execute(state, content,
		ResolveTileDraftCommand.new(state.pending_choice.choice_id, 0)).is_valid, "Actual Starter Draft resolves")
	state = F.round_trip(state, content)
	_expect_generic_available(state)
	expect_equal([state.specialists.pieces[0].piece_id, state.specialists.pieces[1].piece_id], ids,
		"Starter acquisition and load preserve both physical piece identities")
	return true


func first_settlement_offers_both_generics() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.started(content, 1)
	_expect_generic_available(state)
	var rng: int = state.rng.current_state
	var count: int = state.rng.operation_count
	expect_true(RulesEngine.execute(state, content, _opening_command(state, content)).is_valid, "First Hamlet commits")
	var target: int = state.features.component_at(OPEN_AT, TYPE.SETTLEMENT).lineage_id
	var feature: CurrentFeature = SpecialistRules.find_feature(TopologyService.rebuild(state), target)
	expect_equal(feature.open_exits, 1, "New Settlement remains unfinished with its north exit open")
	expect_true(not SpecialistRules.occupied(state, TYPE.SETTLEMENT, target), "No existing Steward occupies target")
	expect_true(state.resolution.affected_targets.has({"target_type": TYPE.SETTLEMENT, "target_id": target}),
		"A newly created Settlement is directly affected")
	var candidates: Array[Dictionary] = SpecialistRules.assignment_options(state, state.resolution.affected_targets)
	expect_equal(candidates.size(), 2, "Both generic physical pieces are legal")
	expect_equal(state.pending_choice.options, candidates, "Persisted choice exposes exact authoritative candidates")
	for index: int in range(2):
		expect_equal(candidates[index], {"piece_id": state.specialists.pieces[index].piece_id,
			"target_type": TYPE.SETTLEMENT, "target_id": target}, "Stable piece-order actionable payload")
	expect_true(bool(state.pending_choice.context.decline_allowed), "Optional assignment retains Decline")
	expect_equal(state.rng.current_state, rng, "Placement and assignment candidate generation consume no RNG")
	expect_equal(state.rng.operation_count, count, "No hidden candidate sampling")
	print("STEWARD OPENING TRACE: seed=1 tile=tile.hamlet_edge at=(1,1) rotation=0 open_exits=%d targets=%s options=%s" %
		[feature.open_exits, state.resolution.affected_targets, candidates])
	return true


func first_settlement_assigns_one_piece() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = _pending(content)
	var command: ResolveSpecialistAssignmentCommand = _assignment(state)
	expect_true(RulesEngine.execute(state, content, command).is_valid, "Offered generic command succeeds")
	expect_equal(state.specialists.pieces[0].status, SpecialistPieceState.Status.ASSIGNED, "Selected physical Steward commits")
	expect_equal(state.specialists.pieces[0].assigned_target_id, command.target_id, "Exact Settlement lineage assigned")
	expect_equal(state.specialists.pieces[1].status, SpecialistPieceState.Status.AVAILABLE, "Other Steward remains available")
	expect_true(state.pending_choice == null and state.phase == GamePhase.Type.TURN_INPUT, "Placement resolution resumes")
	expect_true(not state.expansion.hand.has(0), "Pending opening hand refill completes")
	expect_true(not RulesEngine.execute(state, content, command).is_valid, "Repeated assignment cannot duplicate deployment")
	return true


func first_settlement_decline_keeps_both_available() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = _pending(content)
	S.decline(state, content)
	_expect_generic_available(state)
	expect_true(state.pending_choice == null and state.phase == GamePhase.Type.TURN_INPUT, "Decline resumes without duplicate choice")
	expect_true(not SpecialistRules.occupied(state, TYPE.SETTLEMENT,
		state.features.component_at(OPEN_AT, TYPE.SETTLEMENT).lineage_id), "Decline leaves Settlement unoccupied")
	expect_true(not state.expansion.hand.has(0), "Decline completes refill")
	return true


func pending_generic_assignment_round_trips() -> bool:
	var content: ContentRegistry = F.content()
	for decline: bool in [false, true]:
		var state: RunState = _pending(content)
		var restored: RunState = F.round_trip(state, content)
		expect_equal(restored.pending_choice.options, state.pending_choice.options, "Exact piece/target payload survives load")
		expect_equal(restored.rng.current_state, state.rng.current_state, "Load consumes no RNG")
		expect_equal(restored.rng.operation_count, state.rng.operation_count, "Load never regenerates assignment offer")
		var command: ResolveSpecialistAssignmentCommand = ResolveSpecialistAssignmentCommand.new(
			state.pending_choice.choice_id, 0, -1, 0, true) if decline else _assignment(state)
		expect_true(RulesEngine.execute(state, content, command).is_valid, "Original choice resolves")
		expect_true(RulesEngine.execute(restored, content, command).is_valid, "Loaded choice resolves")
		expect_equal(StateNormalizer.fingerprint(restored), StateNormalizer.fingerprint(state),
			"Assignment and Decline each resume identically after load")
	return true


func first_settlement_completion_has_no_late_assignment() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.started(content, 1)
	expect_true(RulesEngine.execute(state, content,
		_opening_command(state, content, Vector2i.UP, 2)).is_valid, "First Hamlet caps Founding Settlement")
	var target: int = state.features.component_at(Vector2i.UP, TYPE.SETTLEMENT).lineage_id
	var feature: CurrentFeature = SpecialistRules.find_feature(TopologyService.rebuild(state), target)
	expect_equal(feature.open_exits, 0, "Settlement genuinely closes")
	var completed: bool = false
	for event: FeatureHistoryRecord in state.features.history:
		if event.kind == &"feature_completed" and event.lineage_id == target:
			completed = true
	expect_true(completed, "Normal genuine completion event resolves without late assignment")
	expect_true(state.pending_choice == null, "No late assignment or Decline-only choice")
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Consequences and refill continue automatically")
	_expect_generic_available(state)
	return true


func generic_survives_ineligible_trained_peer() -> bool:
	var content: ContentRegistry = S.content()
	var state: RunState = S.create(content)
	S.bind_for_fixture(state, content, Vector2i.ZERO, TYPE.ROAD, 1, &"specialist.merchant")
	S.play(state, content, &"tile.road_junction", Vector2i.RIGHT, 3)
	expect_equal(state.specialists.pieces[1].status, SpecialistPieceState.Status.AVAILABLE, "Completed Road returns Merchant")
	S.play(state, content, &"tile.settlement_throughway", Vector2i.UP, 0)
	expect_equal(state.pending_choice.options.size(), 1, "Ineligible Merchant never hides the legal generic")
	expect_equal(int(state.pending_choice.options[0].piece_id), state.specialists.pieces[0].piece_id,
		"Only generic Steward can occupy this unfinished Settlement")
	return true


func generic_and_eligible_trained_peer_both_appear() -> bool:
	var content: ContentRegistry = S.content()
	var state: RunState = S.create(content)
	S.bind_for_fixture(state, content, Vector2i.ZERO, TYPE.SETTLEMENT, 1, &"specialist.architect")
	S.play(state, content, &"tile.hamlet_edge", Vector2i.UP, 2)
	expect_equal(state.specialists.pieces[1].status, SpecialistPieceState.Status.AVAILABLE, "Completed Settlement returns Architect")
	S.play(state, content, &"tile.hamlet_edge", Vector2i(1, -1), 0)
	expect_equal(state.pending_choice.options.size(), 2, "Generic Steward and trained Architect both remain legal")
	for index: int in range(2):
		expect_equal(int(state.pending_choice.options[index].piece_id), state.specialists.pieces[index].piece_id,
			"Deterministic physical-piece ordering includes generic and trained pieces")
	return true


func occupied_settlement_skips_assignment() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = _pending(content)
	var targets: Array[Dictionary] = state.resolution.affected_targets.duplicate(true)
	expect_true(RulesEngine.execute(state, content, _assignment(state)).is_valid, "First Steward occupies Settlement")
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(SpecialistRules.assignment_options(state, targets).is_empty(), "Second available Steward cannot share feature")
	expect_true(not SpecialistRules.begin_assignment(state, targets), "Zero legal options create no optional choice")
	expect_equal(StateNormalizer.fingerprint(state), before, "Skipped choice changes neither state, RNG nor IDs")
	return true


func unavailable_pieces_skip_first_settlement_choice() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = F.started(content, 1)
	S.bind_for_fixture(state, content, Vector2i.ZERO, TYPE.ROAD, 0)
	S.bind_for_fixture(state, content, Vector2i.ZERO, TYPE.FOREST, 1)
	expect_true(RulesEngine.execute(state, content, _opening_command(state, content)).is_valid,
		"Same natural first Settlement placement succeeds with committed pieces")
	expect_true(state.pending_choice == null, "No available pieces means no Decline-only opportunity")
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Skipped assignment continues normal resolution")
	expect_true(not state.expansion.hand.has(0), "Refill is not blocked by nonexistent choice")
	return true


func natural_starting_monastery_offers_generic_stewards() -> bool:
	var content: ContentRegistry = F.content()
	var state: RunState = HomesteadRunFactory.create(2, content)
	var core_copy_id: int = 0
	for id: int in state.expansion.bag:
		var copy: TileCopyState = PhysicalTileRules.find_copy(state, id)
		if copy.definition_id == &"tile.development.monastery":
			core_copy_id = id
	expect_true(core_copy_id > 0, "Identify guaranteed core copy before Starter acquisition")
	expect_true(RulesEngine.execute(state, content,
		ResolveTileDraftCommand.new(state.pending_choice.choice_id, 0)).is_valid, "Natural Starter choice resolves")
	expect_true(state.expansion.hand.has(core_copy_id), "Seed 2 naturally draws the exact guaranteed Monastery")
	var selected: PlacementOption = null
	for option: PlacementOption in PlacementQueryService.query_for_copy(state, content, core_copy_id):
		if option.coordinate == Vector2i(-4, 2):
			selected = option
			break
	assert(selected != null, "Generated environment supplies legal Monastery host")
	expect_true(RulesEngine.execute(state, content, F.Intent.command(selected)).is_valid,
		"Guaranteed core Monastery is played through authoritative placement")
	expect_equal(state.pending_choice.kind, &"specialist_assignment", "Unfinished enclosure offers assignment")
	expect_equal(state.pending_choice.options.size(), 2, "Both available generic Stewards offered")
	var target: int = int(state.pending_choice.options[0].target_id)
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	expect_true(SpecialistRules.target_unfinished(state, SpecialistRules.ENCLOSURE, target, current),
		"Assignment concerns current unfinished Monastery enclosure")
	for index: int in range(2):
		expect_equal(state.pending_choice.options[index], {"piece_id": state.specialists.pieces[index].piece_id,
			"target_type": SpecialistRules.ENCLOSURE, "target_id": target}, "Generic physical identity and enclosure preserved")
	for role: StringName in SpecialistRules.ROLE_TYPES:
		expect_true(not SpecialistRules.role_eligible(state, role, SpecialistRules.ENCLOSURE, target, current),
			"Generic enclosure eligibility does not bypass trained-role restrictions")
	return true
