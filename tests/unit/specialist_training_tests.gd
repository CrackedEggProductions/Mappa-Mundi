extends "res://tests/framework/test_suite.gd"
## Training-specific command tests use the public validation before each mutation.

const Fixture = preload("res://tests/fixtures/topology_fixture.gd")
const Gameplay = preload("res://tests/fixtures/phase_seven_factory.gd")
const EDGE = DomainTypes.EdgeType
const TYPE = DomainTypes.FeatureType


func tests() -> Array[Callable]:
	return [available_pool_exact_eight, available_offer_three_distinct,
		same_rng_state_same_offer, uniform_sampling_uses_sorted_pool,
		assigned_road_pool, assigned_settlement_pool, assigned_forest_pool,
		assigned_river_pool_without_settlement, assigned_river_pool_with_settlement,
		assigned_monastery_pool_empty, training_preserves_identity,
		training_in_place_preserves_commitment, growth_training_excludes_pretraining_growth,
		trained_role_cannot_retrain, duplicate_roles_allowed, invalid_role_inert,
		stale_choice_inert, changed_training_context_rejected, fallback_all_trained, fallback_only_untrainable_generics,
		untrainable_selection_with_other_available_rejected, recruit_third_cap_fourth,
		training_offer_never_recalls_assigned_piece, pending_continuation_rechecks_id_capacity,
		pending_continuation_rechecks_rng_capacity, pending_continuation_rechecks_gain_capacity]


func available_pool_exact_eight() -> bool:
	var state: RunState = _state()
	var pool: Array[StringName] = SpecialistRules.training_pool(state, state.specialists.pieces[0])
	expect_equal(pool.size(), 8, "Exactly eight alpha roles")
	expect_equal(pool[0], &"specialist.architect", "Canonical lexical order")
	expect_equal(pool[7], &"specialist.riverkeeper", "Canonical pool, no deferred roles")
	return true


func available_offer_three_distinct() -> bool:
	var state: RunState = _state()
	_offer(state, 0)
	var offered: Array[String] = _roles(state)
	expect_equal(offered.size(), 3, "Three offered roles")
	expect_true(offered[0] != offered[1] and offered[0] != offered[2] and offered[1] != offered[2], "Sampling without replacement")
	expect_equal(state.rng.operation_count, 3, "Only training offer consumes gameplay RNG")
	return true


func same_rng_state_same_offer() -> bool:
	var first: RunState = _state()
	var second: RunState = _state()
	_offer(first, 0)
	_offer(second, 0)
	expect_equal(first.pending_choice.options, second.pending_choice.options, "Same seed/state offer")
	expect_equal(first.rng.current_state, second.rng.current_state, "Same RNG continuation")
	return true


func uniform_sampling_uses_sorted_pool() -> bool:
	var state: RunState = _state()
	var rng: RunRNG = RunRNG.from_snapshot(state.rng.original_seed, state.rng.current_state, state.rng.operation_count)
	var pool: Array[StringName] = SpecialistRules.training_pool(state, state.specialists.pieces[0])
	var expected: Array[String] = []
	for index: int in range(3):
		var role: StringName = rng.choose_definition_id(pool, &"specialist_training_offer")
		expected.append(String(role))
		pool.erase(role)
	_offer(state, 0)
	expect_equal(_roles(state), expected, "Uniform index draws over sorted remaining legal roles, no helpfulness weighting")
	return true


func assigned_road_pool() -> bool:
	return _filtered(TYPE.ROAD, ["specialist.cartographer", "specialist.merchant"])


func assigned_settlement_pool() -> bool:
	return _filtered(TYPE.SETTLEMENT, ["specialist.architect", "specialist.homesteader"])


func assigned_forest_pool() -> bool:
	return _filtered(TYPE.FOREST, ["specialist.forester", "specialist.naturalist"])


func assigned_river_pool_without_settlement() -> bool:
	return _filtered(TYPE.RIVER, ["specialist.riverkeeper"])


func assigned_river_pool_with_settlement() -> bool:
	var state: RunState = _state(TYPE.RIVER, true)
	_bind(state, 0, TYPE.RIVER)
	_offer(state, 0)
	expect_equal(_roles(state), ["specialist.harbormaster", "specialist.riverkeeper"], "Harbormaster included only with authoritative contact")
	return true


func assigned_monastery_pool_empty() -> bool:
	var state: RunState = _state()
	_bind(state, 0, 4)
	expect_true(SpecialistRules.training_pool(state, state.specialists.pieces[0]).is_empty(), "No alpha trained Monastery role")
	return true


func training_preserves_identity() -> bool:
	var state: RunState = _state()
	var id: int = state.specialists.pieces[0].piece_id
	_offer(state, 0)
	var role: StringName = StringName(_roles(state)[0])
	var count: int = state.rng.operation_count
	_train(state, role)
	expect_equal(state.specialists.pieces[0].piece_id, id, "Training does not create a replacement piece")
	expect_equal(state.specialists.pieces.size(), 2, "Roster unchanged")
	expect_equal(state.specialists.pieces[0].role_definition_id, role, "Permanent role stored")
	expect_equal(state.specialists.pieces[0].training_history.size(), 1, "Structured permanent training history")
	expect_equal(state.rng.operation_count, count, "Selecting offered role does not draw again")
	return true


func training_in_place_preserves_commitment() -> bool:
	var state: RunState = _state()
	_bind(state, 0, TYPE.ROAD)
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	var target: int = piece.assigned_target_id
	_offer(state, 0)
	_train(state, &"specialist.merchant")
	expect_equal(piece.status, SpecialistPieceState.Status.ASSIGNED, "No recall")
	expect_equal(piece.assigned_target_id, target, "Same feature")
	expect_equal(piece.assigned_act, 1, "Original assignment Act")
	expect_equal(piece.assigned_placement_index, 7, "Original assignment index")
	return true


func growth_training_excludes_pretraining_growth() -> bool:
	for type: int in [TYPE.ROAD, TYPE.FOREST]:
		var state: RunState = _state(type)
		_bind(state, 0, type)
		var piece: SpecialistPieceState = state.specialists.pieces[0]
		var edge: DomainTypes.EdgeType = FeatureState.edge_for_type(type)
		Fixture.add(state, Vector2i.UP, [edge, EDGE.FIELD, edge, EDGE.FIELD])
		SpecialistRules.remap_and_growth(state, Fixture.reconcile(state))
		expect_equal(piece.qualifying_component_ids.size(), 1, "Generic commitment already observed growth")
		_offer(state, 0)
		_train(state, &"specialist.cartographer" if type == TYPE.ROAD else &"specialist.forester")
		expect_true(piece.qualifying_component_ids.is_empty(), "Training starts growth credit now, never retroactive")
		expect_equal(piece.growth_baseline_component_ids, SpecialistRules.all_component_ids(state), "All current foreign and host components observed")
		expect_equal(piece.assigned_placement_index, 7, "Training does not rewrite original assignment timing")
	return true


func trained_role_cannot_retrain() -> bool:
	var state: RunState = _state()
	_offer(state, 0)
	_train(state, StringName(_roles(state)[0]))
	var before: String = _fingerprint(state)
	var result: ValidationResult = SpecialistCommands.validate_command(state, null, RequestSpecialistTrainingCommand.new(state.specialists.pieces[0].piece_id))
	expect_true(not result.is_valid, "Already-trained role cannot retrain")
	expect_equal(_fingerprint(state), before, "Rejected retraining leaves all Specialist counters unchanged")
	return true


func duplicate_roles_allowed() -> bool:
	var state: RunState = _state()
	_bind(state, 0, TYPE.ROAD)
	_offer(state, 0)
	_train(state, &"specialist.merchant")
	# Duplicate role filtering is independent of who else currently has that role.
	var pool: Array[StringName] = SpecialistRules.training_pool(state, state.specialists.pieces[1])
	expect_true(pool.has(&"specialist.merchant"), "Another Merchant remains in full training pool")
	return true


func invalid_role_inert() -> bool:
	var state: RunState = _state()
	_offer(state, 0)
	var before: String = _fingerprint(state)
	var result: ValidationResult = SpecialistCommands.validate_command(state, null, ResolveSpecialistTrainingCommand.new(state.pending_choice.choice_id, &"specialist.stonewright"))
	expect_true(not result.is_valid, "Deferred/unoffered role rejected")
	expect_equal(_fingerprint(state), before, "Rejected role does not consume RNG, IDs, or history")
	return true


func stale_choice_inert() -> bool:
	var state: RunState = _state()
	_offer(state, 0)
	var command: ResolveSpecialistTrainingCommand = ResolveSpecialistTrainingCommand.new(state.pending_choice.choice_id, StringName(_roles(state)[0]))
	command.expected_state_revision = state.expansion.state_revision + 1
	var before: String = _fingerprint(state)
	expect_true(not SpecialistCommands.validate_command(state, null, command).is_valid, "Stale revision rejected")
	expect_equal(_fingerprint(state), before, "Stale command inert")
	return true


func changed_training_context_rejected() -> bool:
	var state: RunState = _state()
	_bind(state, 0, TYPE.ROAD)
	_offer(state, 0)
	state.specialists.pieces[0].assigned_target_id += 500
	var before: String = _fingerprint(state)
	var command: ResolveSpecialistTrainingCommand = ResolveSpecialistTrainingCommand.new(state.pending_choice.choice_id, &"specialist.merchant")
	expect_true(not SpecialistCommands.validate_command(state, null, command).is_valid, "A legal role cannot validate a different commitment than the saved offer")
	expect_equal(_fingerprint(state), before, "Changed context rejects before mutation")
	return true


func fallback_all_trained() -> bool:
	var state: RunState = _state()
	for index: int in range(2):
		_offer(state, index)
		_train(state, StringName(_roles(state)[0]))
	var rng: int = state.rng.current_state
	var command: RequestSpecialistTrainingCommand = RequestSpecialistTrainingCommand.new()
	expect_true(SpecialistCommands.validate_command(state, null, command).is_valid, "All-trained reward converts")
	SpecialistCommands.execute_command(state, null, command)
	expect_equal(state.specialists.deferred_rewards.size(), 1, "Exactly one typed handoff")
	expect_equal(state.specialists.deferred_rewards[0]["reward_kind"], "normal_tile_reward", "Normal Tile Reward retained for later phase")
	expect_equal(state.specialists.deferred_rewards[0]["quantity"], 1, "No lost or doubled reward")
	expect_equal(state.rng.current_state, rng, "Fallback consumes no role-offer RNG")
	expect_true(state.pending_choice == null, "No empty role offer")
	return true


func fallback_only_untrainable_generics() -> bool:
	var state: RunState = _state()
	_bind(state, 0, 4)
	_bind(state, 1, 4)
	state.specialists.pieces[1].assigned_target_id += 1
	var command: RequestSpecialistTrainingCommand = RequestSpecialistTrainingCommand.new(state.specialists.pieces[0].piece_id)
	expect_true(SpecialistCommands.validate_command(state, null, command).is_valid, "All remaining generics on Monasteries cannot train")
	SpecialistCommands.execute_command(state, null, command)
	expect_equal(state.specialists.deferred_rewards.size(), 1, "Untrainable is the same typed fallback")
	expect_equal(state.specialists.pieces[0].status, SpecialistPieceState.Status.ASSIGNED, "Fallback never recalls")
	return true


func untrainable_selection_with_other_available_rejected() -> bool:
	var state: RunState = _state()
	_bind(state, 0, 4)
	var before: String = _fingerprint(state)
	var command: RequestSpecialistTrainingCommand = RequestSpecialistTrainingCommand.new(state.specialists.pieces[0].piece_id)
	expect_true(not SpecialistCommands.validate_command(state, null, command).is_valid, "Cannot claim fallback while another generic can train")
	expect_equal(_fingerprint(state), before, "No RNG or reward from invalid target")
	return true


func recruit_third_cap_fourth() -> bool:
	var state: RunState = _state()
	var command: RecruitStewardCommand = RecruitStewardCommand.new()
	expect_equal(state.specialists.pieces.size(), 2, "Two initial physical generics")
	expect_true(SpecialistCommands.validate_command(state, null, command).is_valid, "Third piece allowed")
	SpecialistCommands.execute_command(state, null, command)
	expect_equal(state.specialists.pieces.size(), 3, "Third physical piece recruited")
	var before: String = _fingerprint(state)
	expect_true(not SpecialistCommands.validate_command(state, null, command).is_valid, "Fourth piece blocked by hard cap")
	expect_equal(_fingerprint(state), before, "Cap rejection is inert")
	return true


func training_offer_never_recalls_assigned_piece() -> bool:
	var state: RunState = _state(TYPE.FOREST)
	_bind(state, 0, TYPE.FOREST)
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	var baseline: Array[int] = piece.growth_baseline_component_ids.duplicate()
	_offer(state, 0)
	expect_equal(piece.status, SpecialistPieceState.Status.ASSIGNED, "Pending choice preserves commitment")
	expect_equal(piece.growth_baseline_component_ids, baseline, "Offer creation does not reset growth")
	expect_equal(state.pending_choice.context["assigned_target_id"], piece.assigned_target_id, "Serialized offer keeps target context")
	return true


func _state(type: int = TYPE.ROAD, settlement_touch: bool = false) -> RunState:
	var state: RunState = Fixture.empty()
	var edge: DomainTypes.EdgeType = FeatureState.edge_for_type(type)
	var cell: BoardCellState = Fixture.add(state, Vector2i.ZERO, [edge, EDGE.FIELD, EDGE.FIELD, EDGE.SETTLEMENT if settlement_touch else EDGE.FIELD])
	if settlement_touch:
		var relation: TileFeatureRelationship = TileFeatureRelationship.new()
		relation.kind = TileFeatureRelationship.Kind.SETTLEMENT_RIVER_TOUCH
		relation.from_edge_type = EDGE.SETTLEMENT
		relation.to_edge_type = EDGE.RIVER
		cell.relationships.append(relation)
	Fixture.reconcile(state)
	SpecialistRules.initialize(state)
	state.phase = GamePhase.Type.TURN_INPUT
	return state


func _bind(state: RunState, index: int, type: int) -> void:
	var piece: SpecialistPieceState = state.specialists.pieces[index]
	piece.status = SpecialistPieceState.Status.ASSIGNED
	piece.assigned_target_type = type
	piece.assigned_target_id = 900 if type == 4 else state.features.component_at(Vector2i.ZERO, type).lineage_id
	piece.assigned_act = 1
	piece.assigned_placement_index = 7
	piece.growth_baseline_component_ids = SpecialistRules.all_component_ids(state)


func _offer(state: RunState, index: int) -> void:
	var command: RequestSpecialistTrainingCommand = RequestSpecialistTrainingCommand.new(state.specialists.pieces[index].piece_id)
	var result: ValidationResult = SpecialistCommands.validate_command(state, null, command)
	expect_true(result.is_valid, "Training hook command validates: " + result.user_message)
	if result.is_valid:
		SpecialistCommands.execute_command(state, null, command)


func _train(state: RunState, role: StringName) -> void:
	var command: ResolveSpecialistTrainingCommand = ResolveSpecialistTrainingCommand.new(state.pending_choice.choice_id, role)
	var result: ValidationResult = SpecialistCommands.validate_command(state, null, command)
	expect_true(result.is_valid, "Offered training validates: " + result.user_message)
	if result.is_valid:
		SpecialistCommands.execute_command(state, null, command)


func _roles(state: RunState) -> Array[String]:
	var result: Array[String] = []
	for option: Dictionary in state.pending_choice.options:
		result.append(option["role_definition_id"])
	return result


func _filtered(type: int, expected: Array) -> bool:
	var state: RunState = _state(type)
	_bind(state, 0, type)
	_offer(state, 0)
	expect_equal(_roles(state), expected, "Offer filters by current target")
	expect_equal(state.rng.operation_count, 0, "At most three legal roles are all shown without arbitrary randomization")
	return true


func _fingerprint(state: RunState) -> String:
	var pieces: Array[Dictionary] = []
	for piece: SpecialistPieceState in state.specialists.pieces:
		pieces.append({"id": piece.piece_id, "role": piece.role_definition_id, "status": piece.status,
			"target": piece.assigned_target_id, "history": piece.training_history.duplicate(true)})
	return var_to_str({"pieces": pieces, "rng": state.rng.current_state, "rng_count": state.rng.operation_count,
		"ids": state.next_runtime_id, "history": state.specialists.history,
		"rewards": state.specialists.deferred_rewards,
		"choice": state.pending_choice.options if state.pending_choice != null else []})


func pending_continuation_rechecks_id_capacity() -> bool:
	return _pending_capacity(false)


func pending_continuation_rechecks_rng_capacity() -> bool:
	return _pending_capacity(true)


func pending_continuation_rechecks_gain_capacity() -> bool:
	var state: RunState = _state()
	state.features.tracks.values[0] = 9223372036854775806
	var before: String = _fingerprint(state)
	var command: ResolveSpecialistAssignmentCommand = ResolveSpecialistAssignmentCommand.new(1, 0, -1, 0, true)
	var result: ValidationResult = SpecialistCommands.validate_command(state, null, command)
	expect_equal(result.error_code, &"invariant_failure", "Continuation checks scoring counter capacity before choice mutation")
	expect_equal(_fingerprint(state), before, "Insufficient Track capacity rejects without mutation")
	return true


func _pending_capacity(exhaust_rng: bool) -> bool:
	var content: ContentRegistry = Gameplay.content()
	for decline: bool in [false, true]:
		var state: RunState = Gameplay.create(content)
		Gameplay.play(state, content, &"tile.straight_road", Vector2i.RIGHT, 1)
		expect_true(state.pending_choice != null, "Live placement pauses before consequences")
		if exhaust_rng:
			state.rng = RunRNG.from_snapshot(state.rng.original_seed, state.rng.current_state, RunRNG.MAX_OPERATION_COUNT - 1)
		else:
			# Sixteen IDs remain, passing the old generic command guard, but not
			# enough for the pending full consequence pipeline and possible refill.
			state.id_allocator = RunIdAllocator.new(RunIdAllocator.EXHAUSTED_CURSOR - 17)
		expect_true(InvariantValidator.validate(state, content).is_valid, "Near-exhausted saved state remains structurally valid")
		var saved: SerializationResult = RunSerializer.serialize(state, content)
		expect_true(saved.validation.is_valid, "Near-exhausted pending choice can be saved")
		var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
		expect_true(loaded.validation.is_valid, "Loading preserves pending capacity context without effects")
		state = loaded.state
		var command: ResolveSpecialistAssignmentCommand
		if decline:
			command = ResolveSpecialistAssignmentCommand.new(state.pending_choice.choice_id, 0, -1, 0, true)
		else:
			var option: Dictionary = state.pending_choice.options[0]
			command = ResolveSpecialistAssignmentCommand.new(state.pending_choice.choice_id, option["piece_id"], option["target_type"], option["target_id"])
		var before: String = StateNormalizer.fingerprint(state)
		var result: ValidationResult = RulesEngine.execute(state, content, command)
		expect_equal(result.error_code, &"invariant_failure", "Assignment and decline both reserve full continuation capacity")
		expect_equal(StateNormalizer.fingerprint(state), before, "Rejected resume preserves pending choice, pieces, RNG, IDs, history, geometry and hand")
	return true
