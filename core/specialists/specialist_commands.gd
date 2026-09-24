class_name SpecialistCommands
extends RefCounted
## Validated Specialist-specific command boundary, called by RulesEngine.


static func handles(command: PlayerCommand) -> bool:
	return command is ResolveSpecialistAssignmentCommand or command is RequestSpecialistTrainingCommand \
		or command is ResolveSpecialistTrainingCommand or command is RecruitStewardCommand


static func validate_command(state: RunState, _content: ContentRegistry,
		command: PlayerCommand) -> ValidationResult:
	if not handles(command) or state.specialists == null or state.features == null or state.expansion == null:
		return _fail(&"specialists_unavailable", "Specialist commands require a Specialist-enabled run.")
	if int(command.get("expected_state_revision")) != -1 and int(command.get("expected_state_revision")) != state.expansion.state_revision:
		return _fail(&"stale_specialist_choice", "The run changed after this choice was displayed.")
	if state.next_runtime_id > RunIdAllocator.EXHAUSTED_CURSOR - 16 or state.expansion.state_revision == 9223372036854775807:
		return _fail(&"invariant_failure", "Insufficient runtime capacity to resolve Specialist command.")
	if command is ResolveSpecialistAssignmentCommand:
		# A persisted choice resumes the whole completion/refill pipeline. Recheck
		# its capacity now; the pre-placement guard may predate this loaded state.
		if not FeatureResolutionService.has_resolution_capacity(state) or state.rng.operation_count > RunRNG.MAX_OPERATION_COUNT - 2:
			return _fail(&"invariant_failure", "Insufficient counters to resume placement consequences safely.")
		return _validate_assignment(state, command as ResolveSpecialistAssignmentCommand)
	if command is ResolveSpecialistTrainingCommand:
		return _validate_training(state, command as ResolveSpecialistTrainingCommand)
	if state.phase != GamePhase.Type.TURN_INPUT or state.pending_choice != null or state.resolution != null:
		return _fail(&"wrong_phase", "This reward hook requires idle normal turn input.")
	if command is RecruitStewardCommand:
		if state.specialists.pieces.size() >= SpecialistRules.HARD_CAP:
			return _fail(&"steward_cap", "The alpha permits at most three Steward/Specialist pieces.")
		return ValidationResult.success()
	var request: RequestSpecialistTrainingCommand = command as RequestSpecialistTrainingCommand
	var trainable: Array[int] = SpecialistRules.trainable_piece_ids(state)
	if request.piece_id == 0:
		if not trainable.is_empty():
			return _fail(&"training_piece_required", "Select a generic Steward to train.")
		return ValidationResult.success()
	var piece: SpecialistPieceState = state.specialists.piece(request.piece_id)
	if piece == null or piece.role_definition_id != &"":
		return _fail(&"not_generic_steward", "Training requires an existing generic Steward.")
	if not trainable.is_empty() and not trainable.has(piece.piece_id):
		return _fail(&"no_legal_training", "This committed Steward has no legal trained role; choose another Steward.")
	if state.rng.operation_count > RunRNG.MAX_OPERATION_COUNT - 3:
		return _fail(&"invariant_failure", "Insufficient RNG operation capacity for a training offer.")
	return ValidationResult.success()


static func _validate_assignment(state: RunState, command: ResolveSpecialistAssignmentCommand) -> ValidationResult:
	var choice: PendingChoice = state.pending_choice
	if state.phase != GamePhase.Type.PENDING_CHOICE or choice == null or choice.kind != &"specialist_assignment" or choice.choice_id != command.choice_id or state.resolution == null:
		return _fail(&"stale_specialist_choice", "No matching assignment opportunity is pending.")
	if command.decline:
		if command.piece_id != 0 or command.target_id != 0 or command.target_type != -1:
			return _fail(&"invalid_assignment_decline", "Decline cannot also contain assignment intent.")
		return ValidationResult.success()
	var intent: Dictionary = {"piece_id": command.piece_id, "target_type": command.target_type, "target_id": command.target_id}
	if not choice.options.has(intent):
		return _fail(&"invalid_assignment", "The piece/target combination was not offered.")
	var targets: Array[Dictionary] = []
	targets.assign(choice.context.get("affected_targets", []))
	if not SpecialistRules.assignment_options(state, targets).has(intent):
		return _fail(&"stale_specialist_choice", "The offered assignment is no longer legal.")
	return ValidationResult.success()


static func _validate_training(state: RunState, command: ResolveSpecialistTrainingCommand) -> ValidationResult:
	var choice: PendingChoice = state.pending_choice
	if state.phase != GamePhase.Type.PENDING_CHOICE or choice == null or choice.kind != &"specialist_training" or choice.choice_id != command.choice_id:
		return _fail(&"stale_specialist_choice", "No matching training offer is pending.")
	var intent: Dictionary = {"role_definition_id": String(command.role_definition_id)}
	if not choice.options.has(intent):
		return _fail(&"invalid_training_role", "The selected Specialist role was not offered.")
	var piece: SpecialistPieceState = state.specialists.piece(int(choice.context["piece_id"]))
	if piece == null or not SpecialistRules.training_pool(state, piece).has(command.role_definition_id):
		return _fail(&"stale_specialist_choice", "The offered training is no longer legal.")
	if piece.status != int(choice.context["status"]) or piece.assigned_target_type != int(choice.context["assigned_target_type"]) or piece.assigned_target_id != int(choice.context["assigned_target_id"]):
		return _fail(&"stale_specialist_choice", "The Steward commitment changed after this training offer.")
	return ValidationResult.success()


static func execute_command(state: RunState, _content: ContentRegistry,
		command: PlayerCommand) -> void:
	if command is ResolveSpecialistAssignmentCommand:
		_assign(state, command as ResolveSpecialistAssignmentCommand)
	elif command is RequestSpecialistTrainingCommand:
		_offer_training(state, command as RequestSpecialistTrainingCommand)
	elif command is ResolveSpecialistTrainingCommand:
		_train(state, command as ResolveSpecialistTrainingCommand)
	elif command is RecruitStewardCommand:
		recruit(state)


static func _assign(state: RunState, command: ResolveSpecialistAssignmentCommand) -> void:
	if not command.decline:
		var piece: SpecialistPieceState = state.specialists.piece(command.piece_id)
		piece.status = SpecialistPieceState.Status.ASSIGNED
		piece.assigned_target_type = command.target_type
		piece.assigned_target_id = command.target_id
		piece.assigned_act = state.expansion.current_act
		piece.assigned_placement_index = state.expansion.normal_placements
		piece.growth_baseline_component_ids = SpecialistRules.all_component_ids(state)
		piece.qualifying_component_ids.clear()
		SpecialistRules.history_event(state, &"specialist_assigned", piece.piece_id,
			{"target_type": command.target_type, "target_id": command.target_id, "role_definition_id": String(piece.role_definition_id)})
	state.pending_choice = null
	state.phase = GamePhase.Type.RESOLVING_PLACEMENT
	# RulesEngine resumes the persisted completion snapshot and performs final refill.


static func _offer_training(state: RunState, command: RequestSpecialistTrainingCommand) -> void:
	if SpecialistRules.trainable_piece_ids(state).is_empty():
		var event: FeatureHistoryRecord = SpecialistRules.history_event(state, &"training_reward_deferred", 0,
			{"reward_kind": "normal_tile_reward", "quantity": 1})
		state.specialists.deferred_rewards.append({"event_id": event.event_id, "reward_kind": "normal_tile_reward", "quantity": 1})
		return
	var piece: SpecialistPieceState = state.specialists.piece(command.piece_id)
	var pool: Array[StringName] = SpecialistRules.training_pool(state, piece)
	var offered: Array[StringName] = []
	if pool.size() <= 3:
		offered = pool.duplicate()
	else:
		for index: int in range(3):
			var role: StringName = state.rng.choose_definition_id(pool, &"specialist_training_offer")
			offered.append(role)
			pool.erase(role)
	var choice: PendingChoice = PendingChoice.new()
	choice.choice_id = state.id_allocator.allocate()
	choice.kind = &"specialist_training"
	for role: StringName in offered:
		choice.options.append({"role_definition_id": String(role)})
	choice.context = {"piece_id": piece.piece_id, "status": piece.status,
		"assigned_target_type": piece.assigned_target_type, "assigned_target_id": piece.assigned_target_id,
		"resume_phase": GamePhase.Type.TURN_INPUT}
	state.pending_choice = choice
	state.phase = GamePhase.Type.PENDING_CHOICE


static func _train(state: RunState, command: ResolveSpecialistTrainingCommand) -> void:
	var piece: SpecialistPieceState = state.specialists.piece(int(state.pending_choice.context["piece_id"]))
	piece.role_definition_id = command.role_definition_id
	if piece.status == SpecialistPieceState.Status.ASSIGNED and command.role_definition_id in [&"specialist.cartographer", &"specialist.forester"]:
		# Conversion starts growth credit now; original commitment timing is preserved.
		piece.growth_baseline_component_ids = SpecialistRules.all_component_ids(state)
		piece.qualifying_component_ids.clear()
	var details: Dictionary = {"role_definition_id": String(command.role_definition_id),
		"target_type": piece.assigned_target_type, "target_id": piece.assigned_target_id,
		"growth_credit_starts_at_training": command.role_definition_id in [&"specialist.cartographer", &"specialist.forester"]}
	var event: FeatureHistoryRecord = SpecialistRules.history_event(state, &"specialist_trained", piece.piece_id, details)
	piece.training_history.append({"event_id": event.event_id, "role_definition_id": String(piece.role_definition_id),
		"act": state.expansion.current_act, "placement_index": state.expansion.normal_placements})
	var resume_phase: GamePhase.Type = int(state.pending_choice.context.get("resume_phase", GamePhase.Type.TURN_INPUT)) as GamePhase.Type
	state.pending_choice = null
	state.phase = resume_phase


static func begin_training_reward(state: RunState, piece_id: int) -> void:
	# Reward validation already selected an eligible generic; reuse the one offer implementation.
	_offer_training(state, RequestSpecialistTrainingCommand.new(piece_id))
	if state.pending_choice != null:
		state.pending_choice.context["resume_phase"] = GamePhase.Type.RESOLVING_PLACEMENT


static func recruit(state: RunState) -> void:
	assert(state.specialists.pieces.size() < SpecialistRules.HARD_CAP)
	var piece: SpecialistPieceState = SpecialistPieceState.new()
	piece.piece_id = state.id_allocator.allocate()
	state.specialists.pieces.append(piece)
	SpecialistRules.history_event(state, &"steward_recruited", piece.piece_id)


static func _fail(code: StringName, message: String) -> ValidationResult:
	return ValidationResult.failure(code, message)
