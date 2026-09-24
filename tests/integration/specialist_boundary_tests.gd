extends "res://tests/framework/test_suite.gd"
## Saved post-commit/pre-effect states and Act-boundary continuations.

const Fixture = preload("res://tests/fixtures/phase_seven_factory.gd")
const TYPE = DomainTypes.FeatureType
const TRACK = DomainTypes.TrackType


func tests() -> Array[Callable]:
	return [completed_peer_pending_assign_continuation, completed_peer_pending_decline_continuation,
		forged_locality_command_rejected, forged_locality_save_rejected,
		forged_snapshot_save_rejected, forged_source_save_rejected,
		final_act_placement_pending_decline, final_act_placement_pending_assign,
		abbey_generic_assignment_uses_persistent_enclosure, completed_abbey_has_no_last_second_assignment,
		deferred_mill_effect_survives_pending_load, malformed_snapshot_collections_rejected,
		historical_completed_feature_assignment_rejected, historical_completed_enclosure_assignment_rejected,
		duplicate_training_fallback_rejected, recruit_does_not_cycle_dead_hand,
		training_does_not_cycle_dead_hand]


func _pending_peer(content: ContentRegistry) -> RunState:
	var state: RunState = Fixture.create(content)
	Fixture.bind_for_fixture(state, content, Vector2i.ZERO, TYPE.ROAD)
	Fixture.play(state, content, &"tile.settlement_gate", Vector2i.RIGHT, 2)
	assert(state.pending_choice != null)
	return state


func _pending_peer_continuation(assign_piece: bool) -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = _pending_peer(content)
	var fingerprint: String = StateNormalizer.fingerprint(state)
	var history_size: int = state.features.history.size()
	var next_id: int = state.next_runtime_id
	var rng: int = state.rng.operation_count
	var tracks: Array[int] = state.features.tracks.values.duplicate()
	var returning_id: int = state.specialists.pieces[0].piece_id
	expect_equal(state.specialists.pieces[0].status, 1, "Completed Road's piece remains captured until Specialist-return stage")
	expect_equal(state.resolution.completion_snapshot["specialists"].size(), 1, "Frozen snapshot includes completed assigned peer")
	expect_equal(state.expansion.hand[0], 0, "Committed placement hand slot remains empty")
	var loaded: RunState = state
	for repetition: int in range(3):
		loaded = Fixture.load_copy(loaded, content)
		expect_equal(StateNormalizer.fingerprint(loaded), fingerprint, "Repeated pending load does not replay scoring, placement, assignment or returns")
		expect_equal(loaded.next_runtime_id, next_id, "Load allocates no runtime IDs")
		expect_equal(loaded.rng.operation_count, rng, "Load consumes no RNG")
		expect_equal(loaded.features.history.size(), history_size, "Load creates no history events")
		expect_equal(loaded.features.tracks.values, tracks, "Load scores no base, Development or Specialist gains")
	if assign_piece:
		Fixture.assign(state, content, TYPE.SETTLEMENT, 0, 1)
		Fixture.assign(loaded, content, TYPE.SETTLEMENT, 0, 1)
	else:
		Fixture.decline(state, content)
		Fixture.decline(loaded, content)
	expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Identical decision preserves IDs/RNG/events/tracks/refill continuation")
	expect_equal(state.specialists.pieces[0].status, 0, "Already completed Road returns after saved decision")
	expect_equal(state.specialists.pieces[1].status, 1 if assign_piece else 0, "Optional Settlement assignment resolves exactly once")
	var gain: int = 0
	for event: FeatureHistoryRecord in state.features.history:
		if event.kind == &"realm_track_changed" and event.source_id == returning_id and event.track == TRACK.TRADE:
			gain += event.amount
	expect_equal(gain, 2, "Paused completion gives generic bonus once")
	expect_true(not state.expansion.hand.has(0), "Consequences finish before deferred refill")
	return true


func completed_peer_pending_assign_continuation() -> bool:
	return _pending_peer_continuation(true)


func completed_peer_pending_decline_continuation() -> bool:
	return _pending_peer_continuation(false)


func _forged_locality(content: ContentRegistry) -> RunState:
	var state: RunState = Fixture.create(content)
	Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	var unrelated: int = Fixture.member(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	var targets: Array[Dictionary] = [{"target_type": TYPE.SETTLEMENT, "target_id": unrelated}]
	state.resolution.affected_targets = targets.duplicate(true)
	state.pending_choice.context["affected_targets"] = targets.duplicate(true)
	state.pending_choice.options.clear()
	for piece: SpecialistPieceState in state.specialists.pieces:
		state.pending_choice.options.append({"piece_id": piece.piece_id,
			"target_type": TYPE.SETTLEMENT, "target_id": unrelated})
	return state


func forged_locality_command_rejected() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = _forged_locality(content)
	var option: Dictionary = state.pending_choice.options[0]
	var fingerprint: String = StateNormalizer.fingerprint(state)
	var result: ValidationResult = RulesEngine.execute(state, content,
		ResolveSpecialistAssignmentCommand.new(state.pending_choice.choice_id,
		int(option.piece_id), int(option.target_type), int(option.target_id)))
	expect_true(not result.is_valid, "Consistent forged choice/context/targets cannot invent nonlocal eligibility")
	expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Rejected forged choice does not mutate any state")
	return true


func forged_locality_save_rejected() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = _forged_locality(content)
	return _reject_envelope(state, content, "Load verifies locality against committed physical placement")


func forged_snapshot_save_rejected() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = _pending_peer(content)
	state.resolution.completion_snapshot["tracks"][TRACK.TRADE] += 100
	return _reject_envelope(state, content, "Load rejects changed frozen pre-effect Track snapshot")


func forged_source_save_rejected() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = _pending_peer(content)
	state.resolution.source_id = state.expansion.board.get_cell(Vector2i.ZERO).base_tile_copy_id
	return _reject_envelope(state, content, "Historical Founding physical copy cannot impersonate just-committed placement")


func _reject_envelope(state: RunState, content: ContentRegistry, message: String) -> bool:
	var envelope: Dictionary = RunSerializer.to_envelope(state)
	var original: String = StateNormalizer.fingerprint(state)
	var loaded: DeserializationResult = RunSerializer.deserialize(JSON.stringify(envelope), content)
	expect_true(not loaded.validation.is_valid and loaded.state == null, message)
	expect_equal(StateNormalizer.fingerprint(state), original, "Rejected load never touches caller's source state")
	return true


func _final_act_pending(assign_piece: bool) -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content, 1)
	Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	Fixture.decline(state, content)
	for y: int in range(1, 17):
		Fixture.play(state, content, &"tile.open_fields", Vector2i(1, y))
		expect_true(state.pending_choice == null, "Field-only placements offer no Specialist target")
	expect_equal(state.expansion.normal_placements, 17, "Controlled Act-I scenario reaches penultimate placement")
	Fixture.play(state, content, &"tile.straight_road", Vector2i(2, 0), 1)
	expect_equal(state.expansion.normal_placements, 18, "Last Act placement committed exactly once")
	expect_equal(state.phase, GamePhase.Type.PENDING_CHOICE, "Final local assignment precedes Act transition hook")
	expect_equal(state.expansion.hand[0], 0, "Last Act hand slot remains empty while choice pending")
	var loaded: RunState = Fixture.load_copy(state, content)
	if assign_piece:
		Fixture.assign(state, content, TYPE.ROAD)
		Fixture.assign(loaded, content, TYPE.ROAD)
	else:
		Fixture.decline(state, content)
		Fixture.decline(loaded, content)
	expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Saved final-placement choice resumes deterministically")
	expect_equal(state.phase, GamePhase.Type.RESOLVING_ACT_TRANSITION, "Existing future Act transition boundary remains deferred")
	expect_equal(state.expansion.hand[0], 0, "No premature draw before later Act seeding")
	expect_equal(state.expansion.pending_refill_index, 0, "Pending refill remains owned by existing Act boundary")
	expect_true(state.pending_choice == null and state.resolution == null, "Specialist continuation finishes without implementing Act transition")
	return true


func final_act_placement_pending_decline() -> bool:
	return _final_act_pending(false)


func final_act_placement_pending_assign() -> bool:
	return _final_act_pending(true)


func abbey_generic_assignment_uses_persistent_enclosure() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.Previous.create(content)
	var center: Vector2i = Fixture.Development.fields(state, content, 7)
	Fixture.activate(state)
	Fixture.play(state, content, &"tile.development.monastery", center)
	Fixture.decline(state, content)
	var enclosure_id: int = state.features.enclosures[0].enclosure_id
	Fixture.play(state, content, &"tile.development.abbey", center)
	expect_true(state.pending_choice != null, "Unfinished persistent Monastery-family enclosure offers generic assignment after Upgrade")
	for role: StringName in content.get_specialist_ids():
		expect_true(not SpecialistRules.role_eligible(state, role, 4, enclosure_id, TopologyService.rebuild(state)), "No trained alpha role can occupy Abbey")
	var loaded: RunState = Fixture.load_copy(state, content)
	Fixture.assign(loaded, content, 4, enclosure_id)
	Fixture.play(loaded, content, &"tile.open_fields", center + Vector2i(-1, -1))
	var piece_id: int = loaded.specialists.pieces[0].piece_id
	var gain: int = 0
	for event: FeatureHistoryRecord in loaded.features.history:
		if event.kind == &"realm_track_changed" and event.source_id == piece_id and event.track == TRACK.CULTURE:
			gain += event.amount
	expect_equal(gain, 2, "Generic enclosure bonus resolves once on genuine Abbey completion")
	expect_equal(loaded.specialists.pieces[0].status, 0, "Generic piece returns from completed Abbey")
	return true


func completed_abbey_has_no_last_second_assignment() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.Previous.create(content)
	var center: Vector2i = Fixture.Development.fields(state, content, 8)
	Fixture.activate(state)
	Fixture.play(state, content, &"tile.development.monastery", center)
	Fixture.play(state, content, &"tile.development.abbey", center)
	expect_true(state.pending_choice == null, "Already surrounded Abbey cannot receive a last-second generic assignment")
	return true


func deferred_mill_effect_survives_pending_load() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.Previous.create(content)
	Fixture.Development.complete_settlement(state, content)
	Fixture.Geography.add(state, content, &"tile.open_fields", Vector2i(1, -1))
	Fixture.Geography.add(state, content, &"tile.hamlet_edge", Vector2i(2, -1), 2)
	Fixture.activate(state)
	var before: int = state.features.tracks.values[TRACK.POPULATION]
	Fixture.play(state, content, &"tile.development.mill", Vector2i(1, -1))
	expect_true(state.pending_choice != null, "Mill offers unfinished neighbor while retaining completed-neighbor immediate effect")
	expect_equal(state.features.tracks.values[TRACK.POPULATION], before, "Immediate effect waits until optional choice resolves")
	var loaded: RunState = Fixture.load_copy(state, content)
	var forged: RunState = Fixture.load_copy(state, content)
	forged.resolution.immediate_development_copy_id = 0
	forged.resolution.immediate_parent_event_id = 0
	_reject_envelope(forged, content, "Dropping deferred immediate fields cannot silently discard Mill scoring")
	Fixture.decline(state, content)
	Fixture.decline(loaded, content)
	expect_equal(loaded.features.tracks.values[TRACK.POPULATION], before + 2, "Stored Mill immediate effect pays for completed neighbor once")
	expect_equal(StateNormalizer.fingerprint(state), StateNormalizer.fingerprint(loaded), "Deferred Development continuation identical after load")
	return true


func malformed_snapshot_collections_rejected() -> bool:
	var content: ContentRegistry = Fixture.content()
	for key: String in ["features", "enclosures"]:
		for malformed: Variant in [7, [7], [{}]]:
			var state: RunState = _pending_peer(content)
			state.resolution.completion_snapshot[key] = malformed
			_reject_envelope(state, content, "Malformed snapshot collection rejects without engine diagnostics")
			var fingerprint: String = StateNormalizer.fingerprint(state)
			var result: ValidationResult = RulesEngine.execute(state, content,
				ResolveSpecialistAssignmentCommand.new(state.pending_choice.choice_id, 0, -1, 0, true))
			expect_true(not result.is_valid, "Malformed live continuation rejects before mutation")
			expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Malformed continuation remains untouched")
	return true


func _historical_assignment_rejected(enclosure_target: bool) -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.Previous.create(content)
	var target_id: int
	var target_type: int = 4 if enclosure_target else TYPE.SETTLEMENT
	if enclosure_target:
		var center: Vector2i = Fixture.Development.fields(state, content, 8)
		Fixture.Development.play(state, content, &"tile.development.monastery", center)
		target_id = state.features.enclosures[0].enclosure_id
	else:
		Fixture.Development.complete_settlement(state, content)
		target_id = Fixture.member(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	Fixture.activate(state)
	Fixture.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	piece.status = SpecialistPieceState.Status.ASSIGNED
	piece.assigned_target_type = target_type
	piece.assigned_target_id = target_id
	piece.assigned_act = state.expansion.current_act
	piece.assigned_placement_index = state.expansion.normal_placements
	piece.growth_baseline_component_ids = SpecialistRules.all_component_ids(state)
	state.pending_choice.options = SpecialistRules.assignment_options(state, state.resolution.affected_targets)
	_reject_envelope(state, content, "Unrelated pending resolution cannot excuse assignment to historical completed target")
	var fingerprint: String = StateNormalizer.fingerprint(state)
	var result: ValidationResult = RulesEngine.execute(state, content,
		ResolveSpecialistAssignmentCommand.new(state.pending_choice.choice_id, 0, -1, 0, true))
	expect_true(not result.is_valid, "Corrupt completed assignment rejects before resume")
	expect_equal(StateNormalizer.fingerprint(state), fingerprint, "No stranded piece or partial resolution mutation")
	return true


func historical_completed_feature_assignment_rejected() -> bool:
	return _historical_assignment_rejected(false)


func historical_completed_enclosure_assignment_rejected() -> bool:
	return _historical_assignment_rejected(true)


func duplicate_training_fallback_rejected() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	for piece: SpecialistPieceState in state.specialists.pieces:
		expect_true(RulesEngine.execute(state, content, RequestSpecialistTrainingCommand.new(piece.piece_id)).is_valid, "Request actual training")
		var role: StringName = StringName(state.pending_choice.options[0]["role_definition_id"])
		expect_true(RulesEngine.execute(state, content, ResolveSpecialistTrainingCommand.new(state.pending_choice.choice_id, role)).is_valid, "Train actual stable piece")
	expect_true(RulesEngine.execute(state, content, RequestSpecialistTrainingCommand.new()).is_valid, "All-trained reward becomes one handoff")
	state.specialists.deferred_rewards.append(state.specialists.deferred_rewards[0].duplicate(true))
	return _reject_envelope(state, content, "One resolved training reward cannot be duplicated in a saved handoff queue")


func _dead_hand(content: ContentRegistry) -> RunState:
	var state: RunState = Fixture.create(content)
	for index: int in range(3):
		Fixture.Development.acquire_hand(state, Fixture.Previous.BRIDGE, index)
	assert(StalemateRules.is_dead_hand(state, content))
	return state


func recruit_does_not_cycle_dead_hand() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = _dead_hand(content)
	var hand: Array[int] = state.expansion.hand.duplicate()
	var rng: int = state.rng.operation_count
	expect_true(RulesEngine.execute(state, content, RecruitStewardCommand.new()).is_valid, "Reward hook recruits third piece")
	expect_equal(state.expansion.hand, hand, "Recruitment does not perform an unrelated dead-hand cycle")
	expect_equal(state.rng.operation_count, rng, "Recruitment consumes no gameplay RNG")
	return true


func training_does_not_cycle_dead_hand() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = _dead_hand(content)
	var hand: Array[int] = state.expansion.hand.duplicate()
	var rng: int = state.rng.operation_count
	expect_true(RulesEngine.execute(state, content, RequestSpecialistTrainingCommand.new(state.specialists.pieces[0].piece_id)).is_valid, "Training creates offer")
	expect_equal(state.rng.operation_count, rng + 3, "Only three canonical uniform offer draws consume RNG")
	var role: StringName = StringName(state.pending_choice.options[0]["role_definition_id"])
	expect_true(RulesEngine.execute(state, content, ResolveSpecialistTrainingCommand.new(state.pending_choice.choice_id, role)).is_valid, "Training selection resolves")
	expect_equal(state.expansion.hand, hand, "Training resolution does not perform unrelated dead-hand cycle")
	expect_equal(state.rng.operation_count, rng + 3, "Selecting offered role consumes no further RNG")
	return true
