class_name RulesEngine
extends RefCounted
## Authoritative command boundary; optional assignment pauses before consequences.


static func execute(state: RunState, content: ContentRegistry,
		command: PlayerCommand) -> ValidationResult:
	var validation: ValidationResult = validate(state, content, command)
	if not validation.is_valid:
		return validation
	if command is ResumeActTransitionCommand:
		ActRules.advance(state, content)
	elif command is ResolveRelayCommand:
		StewardRelayRules.execute_command(state, command as ResolveRelayCommand)
		_resume_phase_eight(state, content)
	elif RewardCommands.handles(command):
		RewardCommands.execute_command(state, content, command)
		_resume_phase_eight(state, content)
	elif RelicHandRules.handles(command):
		RelicHandRules.execute_command(state, content, command)
		if state.resolution != null and state.resolution.stage == &"reward_queue":
			_resume_phase_eight(state, content)
	elif _specialist_command(command):
		var resumes_placement: bool = command is ResolveSpecialistAssignmentCommand
		SpecialistCommands.execute_command(state, content, command)
		if resumes_placement:
			_resume_placement(state, content)
		elif state.rewards != null:
			RewardRules.claim_deferred_training(state)
			if state.resolution == null and not state.rewards.queue.is_empty():
				state.resolution = ResolutionState.new()
				state.resolution.stage = &"reward_queue"
				state.resolution.context["mode"] = "reward"
			if state.resolution != null and state.pending_choice == null:
				_resume_phase_eight(state, content)
	elif command is PlaceTileCommand:
		_place(state, content, command as PlaceTileCommand)
	elif command is ReserveTileCommand:
		RelicHandRules.reserve(state, content, command as ReserveTileCommand)
	elif command is SurveyTileCommand:
		RelicHandRules.survey(state, content, (command as SurveyTileCommand).tile_copy_id)
	# Free cycling is a domain resolution step, including an explicit still-dead retry.
	if state.phase == GamePhase.Type.TURN_INPUT \
			and (not _specialist_command(command) or command is ResolveSpecialistAssignmentCommand):
		StalemateRules.cycle_if_dead(state, content)
	state.expansion.state_revision += 1
	if OS.is_debug_build():
		InvariantValidator.assert_valid(state, content)
	return ValidationResult.success()


static func validate(state: RunState, content: ContentRegistry,
		command: PlayerCommand) -> ValidationResult:
	var invariants: InvariantReport = InvariantValidator.validate(state, content)
	if not invariants.is_valid:
		return ValidationResult.failure(&"invariant_failure", "Invalid authoritative state.",
			{"invariants": invariants.describe()})
	if state.phase == GamePhase.Type.RUN_COMPLETE:
		return _failure(&"run_complete", "A completed run cannot accept gameplay commands.")
	if state.phase == GamePhase.Type.BONUS_INPUT and not command is PlaceTileCommand:
		return _failure(&"bonus_placement_only", "Bonus placements do not permit start-of-turn actions.")
	if state.expansion != null and state.expansion.state_revision == 9223372036854775807:
		return _failure(&"invariant_failure", "No state revision remains for this command.")
	if state.relics != null and (state.next_runtime_id > RunIdAllocator.EXHAUSTED_CURSOR - 128 \
			or state.rng.operation_count > RunRNG.MAX_OPERATION_COUNT - 64):
		return _failure(&"invariant_failure", "Insufficient counters to resume Phase-8 consequences atomically.")
	if command is ResumeActTransitionCommand:
		if state.charters != null and state.act_transition != null \
				and state.phase == GamePhase.Type.RESOLVING_ACT_TRANSITION \
				and state.pending_choice == null and state.resolution == null:
			return ValidationResult.success()
		return _failure(&"wrong_phase", "No stable Act transition awaits continuation.")
	if command is ResolveRelayCommand:
		return StewardRelayRules.validate_command(state, command as ResolveRelayCommand)
	if RewardCommands.handles(command):
		return RewardCommands.validate_command(state, content, command)
	if RelicHandRules.handles(command):
		return RelicHandRules.validate_command(state, content, command)
	if _specialist_command(command):
		return SpecialistCommands.validate_command(state, content, command)
	var bonus_input: bool = state.phase == GamePhase.Type.BONUS_INPUT
	if state.expansion == null or (state.phase != GamePhase.Type.TURN_INPUT and not bonus_input):
		return _failure(&"wrong_phase", "Normal turn input is not available.")
	# Reserve capacity for the entire synchronous resolution before touching state.
	# A required empty-bag draw and subsequent global-stalemate cycle can each
	# inject one emergency batch and shuffle once. Exhaustion is a state/runtime
	# limitation, not a reason to leave a half-applied command behind.
	var emergency_capacity: int = content.get_config().emergency_definitions.size() * 2
	if state.expansion.state_revision == 9223372036854775807 \
			or state.expansion.board.revision > 9223372036854775807 - 4 \
			or state.rng.operation_count > 9223372036854775807 - 2 \
			or state.next_runtime_id > RunIdAllocator.EXHAUSTED_CURSOR - emergency_capacity:
		return _failure(&"invariant_failure", "Insufficient runtime counter capacity to resolve a command safely.")
	if command is PlaceTileCommand:
		if state.trade != null and state.trade.trade_revision == 9223372036854775807:
			return _failure(&"invariant_failure", "Insufficient Trade revision capacity to resolve placement safely.")
		if state.features != null and not FeatureResolutionService.has_resolution_capacity(state):
			return _failure(&"invariant_failure", "Insufficient counters to resolve feature history safely.")
		return _validate_place(state, content, command as PlaceTileCommand)
	if command is ReserveTileCommand:
		return RelicHandRules.validate_reserve(state, command as ReserveTileCommand)
	if command is SurveyTileCommand:
		var survey_command: SurveyTileCommand = command as SurveyTileCommand
		if state.relics != null and state.relics.normal_surveys_used == 9223372036854775807:
			return _failure(&"invariant_failure", "No normal-Survey history counter remains.")
		if state.expansion.survey_charges <= 0:
			return _failure(&"no_survey_charge", "No Survey charge remains.")
		return _validate_hand(state, survey_command.tile_copy_id)
	if command is CycleDeadHandCommand:
		if StalemateRules.is_dead_hand(state, content):
			return ValidationResult.success()
		return _failure(&"hand_is_playable", "A free cycle requires three unplayable hand tiles.")
	return _failure(&"unsupported_command", "Unknown player command.")


static func _validate_hand(state: RunState, copy_id: int) -> ValidationResult:
	if copy_id <= 0 or not state.expansion.hand.has(copy_id):
		return _failure(&"not_in_hand", "The selected physical tile is not in the active hand.")
	return ValidationResult.success()


static func _failure(code: StringName, message: String) -> ValidationResult:
	return ValidationResult.failure(code, message)


static func _validate_place(state: RunState, content: ContentRegistry,
		command: PlaceTileCommand) -> ValidationResult:
	if command.placement_mode not in [DomainTypes.PlacementMode.EXPANSION,
			DomainTypes.PlacementMode.DEVELOPMENT, DomainTypes.PlacementMode.UPGRADE,
			DomainTypes.PlacementMode.TRANSFORMATION]:
		return _failure(&"unsupported_mode", "This placement mode is not available.")
	if command.source_zone == TileLocationState.Kind.ACTIVE_HAND:
		var hand_check: ValidationResult = _validate_hand(state, command.tile_copy_id)
		if not hand_check.is_valid:
			return hand_check
	elif command.source_zone == TileLocationState.Kind.RESERVE:
		if command.tile_copy_id <= 0 or not RelicHandRules.reserve_ids(state).has(command.tile_copy_id):
			return _failure(&"not_in_reserve", "The selected physical tile is not in Reserve.")
	else:
		return _failure(&"invalid_source", "Placement must use active hand or Reserve.")
	if command.expected_board_revision != -1 \
			and command.expected_board_revision != state.expansion.board.revision:
		return _failure(&"stale_preview", "The board changed after this preview.")
	if command.expected_state_revision != -1 \
			and command.expected_state_revision != state.expansion.state_revision:
		return _failure(&"stale_preview", "The run changed after this preview.")
	var tile: TileCopyState = PhysicalTileRules.find_copy(state, command.tile_copy_id)
	var definition: TileDefinition = content.get_tile(tile.definition_id)
	if command.placement_mode == DomainTypes.PlacementMode.TRANSFORMATION:
		var target_failure: StringName = TransformationPlacementQuery.target_failure(state, definition, command.coordinate)
		if target_failure != &"":
			return _failure(target_failure, "Bridge requires current Field edges on both sides of its Road axis.")
		for option: PlacementOption in TransformationPlacementQuery.query(state, content, command.tile_copy_id):
			if not TransformationPlacementQuery.matches(option, command):
				continue
			if not command.expected_signature.is_empty() and command.expected_signature != option.signature:
				return _failure(&"stale_signature", "The Transformation preview no longer matches this intent.")
			return ValidationResult.success()
		return _failure(&"invalid_transformation_intent", "No legal Transformation matches the complete intent.")
	if command.transformation_mode != &"" or command.target_base_copy_id != 0 \
		or not command.transformation_signature.is_empty():
		return _failure(&"unexpected_transformation_intent", "This placement class cannot carry Transformation targets.")
	if command.placement_mode != DomainTypes.PlacementMode.EXPANSION:
		if command.boundary_direction != -1:
			return _failure(&"invalid_boundary_mode", "Boundary Stones only permits a new-square Expansion.")
		for option: PlacementOption in DevelopmentPlacementQuery.query(state, content, command.tile_copy_id):
			if not DevelopmentPlacementQuery.matches(option, command):
				continue
			if not command.expected_signature.is_empty() and command.expected_signature != option.signature:
				return _failure(&"stale_signature", "The preview signature does not match this intent.")
			return ValidationResult.success()
		return _failure(&"invalid_development_intent", "No legal Development placement matches the complete intent.")
	if command.host_lineage_id != 0 or command.river_lineage_id != 0 \
			or command.target_development_copy_id != 0 or command.enclosure_id != 0:
		return _failure(&"invalid_expansion_intent", "Expansion placement cannot carry overlay targets.")
	var geometry: ValidationResult = RelicGeometry.validate_expansion(state, definition, command)
	if not geometry.is_valid:
		return geometry
	if not SpecialistPlacementService.expansion_is_legal(state, definition,
			command.tile_copy_id, command.coordinate, command.rotation):
		return _failure(&"specialist_merge_conflict", "Two assigned features cannot merge.")
	if not command.expected_signature.is_empty():
		var signature_matches: bool = false
		for option: PlacementOption in PlacementQueryService.query_for_copy(state, content, command.tile_copy_id):
			if option.coordinate == command.coordinate and option.rotation == command.rotation \
					and option.boundary_direction == command.boundary_direction and option.signature == command.expected_signature:
				signature_matches = true
				break
		if not signature_matches:
			return _failure(&"stale_signature", "The preview signature does not match this intent.")
	return ValidationResult.success()


static func _place(state: RunState, content: ContentRegistry, command: PlaceTileCommand) -> void:
	var bonus: bool = state.phase == GamePhase.Type.BONUS_INPUT
	if bonus:
		state.charters.bonus_queue.pop_front()
		state.charters.bonus_active = true
	var transformation: TransformationState = null
	if command.placement_mode == DomainTypes.PlacementMode.TRANSFORMATION:
		transformation = TransformationPlacementService.plan_for_command(state, content, command)
		assert(transformation != null, "Complete geometry intent is available before any placement mutation")
	state.phase = GamePhase.Type.RESOLVING_PLACEMENT
	var pauses: bool = state.specialists != null
	if pauses:
		state.resolution = ResolutionState.new()
		state.resolution.source_id = command.tile_copy_id
		state.resolution.stage = &"committed_placement"
	var expansion: ExpansionState = state.expansion
	var tile: TileCopyState = PhysicalTileRules.find_copy(state, command.tile_copy_id)
	if command.source_zone == TileLocationState.Kind.ACTIVE_HAND:
		expansion.pending_refill_index = expansion.hand.find(command.tile_copy_id)
		expansion.hand[expansion.pending_refill_index] = 0
	else:
		RelicHandRules.remove_reserved(state, command.tile_copy_id)
	if not bonus:
		expansion.normal_placements += 1
	if state.charters != null:
		state.charters.placement_history.append({"copy_id": command.tile_copy_id,
			"act": expansion.current_act, "normal_index": expansion.normal_placements,
			"is_bonus": bonus})
	if command.placement_mode == DomainTypes.PlacementMode.EXPANSION:
		expansion.board.add_cell(BoardCellState.from_definition(
			content.get_tile(tile.definition_id), tile.tile_copy_id, command.coordinate,
			command.rotation, expansion.current_act, expansion.normal_placements
		))
		PhysicalTileRules.set_location(state, tile.tile_copy_id, TileLocationState.Kind.BOARD_BASE)
		RelicGeometry.apply_boundary(state, command)
		if state.features != null:
			TopologyService.add_cell_components(state, expansion.board.get_cell(command.coordinate))
			FeatureResolutionService.resolve(state, tile.tile_copy_id, not pauses)
	elif command.placement_mode == DomainTypes.PlacementMode.TRANSFORMATION:
		TransformationPlacementService.place(state, content, command, transformation, not pauses)
	else:
		DevelopmentPlacementService.place(state, content, command, not pauses)
	if pauses:
		state.resolution.affected_targets = SpecialistPlacementService.affected_targets(state, command, transformation)
		state.resolution.completion_snapshot = FeatureScoringService.capture(
			state, TopologyService.rebuild(state), command.tile_copy_id).data()
		state.resolution.stage = &"specialist_assignment"
		if SpecialistRules.begin_assignment(state, state.resolution.affected_targets):
			return
		_resume_placement(state, content)
		return
	_finish_placement(state, content)


static func _resume_placement(state: RunState, content: ContentRegistry) -> void:
	assert(state.resolution != null)
	state.phase = GamePhase.Type.RESOLVING_PLACEMENT
	state.resolution.stage = &"completion_batch"
	var resolution: ResolutionState = state.resolution
	FeatureScoringService.apply_snapshot(state, CompletionSnapshot.new(resolution.completion_snapshot))
	if resolution.immediate_development_copy_id != 0:
		DevelopmentEffects.immediate(state, resolution.immediate_development_copy_id,
			resolution.immediate_parent_event_id, false)
	if state.relics != null:
		resolution.context["base_applied"] = true
		var relay_queue: Array[Dictionary] = []
		var snapshot_relics: Dictionary = resolution.completion_snapshot.get("relics", {})
		for relic: Dictionary in snapshot_relics.get("equipped", []):
			if StringName(relic["definition_id"]) == &"relic.stewards_relay":
				relay_queue.assign(resolution.context.get("returned_pieces", []))
				break
		relay_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["piece_id"] < b["piece_id"])
		resolution.context["relay_queue"] = relay_queue
		resolution.stage = &"specialist_relay"
		_resume_phase_eight(state, content)
		return
	state.resolution = null
	_finish_placement(state, content)


static func _resume_phase_eight(state: RunState, content: ContentRegistry) -> void:
	if state.pending_choice != null or state.resolution == null:
		return
	var resolution: ResolutionState = state.resolution
	state.phase = GamePhase.Type.RESOLVING_PLACEMENT
	if resolution.stage == &"specialist_relay":
		if StewardRelayRules.begin_next(state):
			return
		resolution.stage = &"relic_effects"
	if resolution.stage == &"relic_effects":
		var snapshot: CompletionSnapshot = CompletionSnapshot.new(resolution.completion_snapshot)
		var pipeline: CompletionPipeline = CompletionPipeline.new()
		RelicRules.apply(state, RelicRules.calculate(snapshot),
			int(resolution.context.get("snapshot_event_id", 0)), pipeline)
		pipeline.drain_children(state)
		resolution.context["relics_applied"] = true
		RewardRules.queue_completion(state, snapshot)
		resolution.context["rewards_queued"] = true
		resolution.stage = &"reward_queue"
	if resolution.stage == &"reward_queue":
		RewardRules.advance(state, content)
		if state.pending_choice != null:
			return
		assert(state.rewards.queue.is_empty(), "A reward continuation must finish or expose a choice")
		var placement: bool = resolution.context.get("mode", "placement") == "placement"
		state.resolution = null
		if state.act_transition != null:
			ActRules.advance(state, content)
		elif placement:
			_finish_placement(state, content)
		else:
			state.phase = GamePhase.Type.TURN_INPUT


static func _finish_placement(state: RunState, content: ContentRegistry) -> void:
	# Later reward stages join the shared completion pipeline before this draw.
	var expansion: ExpansionState = state.expansion
	var config: RunConfig = content.get_config()
	if BonusPlacementRules.finish(state, config):
		return
	if expansion.normal_placements == config.act_placement_limits[expansion.current_act - 1]:
		state.phase = GamePhase.Type.RESOLVING_ACT_TRANSITION
		if state.charters != null:
			if expansion.current_act == 3:
				var finalized: ValidationResult = ActRules.finalize(state, content)
				assert(finalized.is_valid, finalized.user_message)
			else:
				ActRules.begin_transition(state, content)
				ActRules.advance(state, content)
		return # Later Acts phase owns seeding before this pending refill.
	PhysicalTileRules.refill_pending(state, config)
	if state.charters != null and expansion.current_act == 2 and expansion.normal_placements >= 11:
		CharterRules.reveal_grand(state)
	state.phase = GamePhase.Type.TURN_INPUT


static func _specialist_command(command: PlayerCommand) -> bool:
	return command is ResolveSpecialistAssignmentCommand or command is RequestSpecialistTrainingCommand \
		or command is ResolveSpecialistTrainingCommand or command is RecruitStewardCommand
