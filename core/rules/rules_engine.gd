class_name RulesEngine
extends RefCounted
## Synchronous authoritative Phase-2 resolution. No presentation callbacks.


static func execute(state: RunState, content: ContentRegistry,
		command: PlayerCommand) -> ValidationResult:
	var validation: ValidationResult = validate(state, content, command)
	if not validation.is_valid:
		return validation
	var config: RunConfig = content.get_config()
	if command is PlaceTileCommand:
		_place(state, content, command as PlaceTileCommand)
	elif command is ReserveTileCommand:
		var reserve_command: ReserveTileCommand = command as ReserveTileCommand
		var index: int = state.expansion.hand.find(reserve_command.tile_copy_id)
		state.expansion.reserve_id = reserve_command.tile_copy_id
		PhysicalTileRules.set_location(state, reserve_command.tile_copy_id, TileLocationState.Kind.RESERVE)
		state.expansion.hand[index] = PhysicalTileRules.draw(state, config)
	elif command is SurveyTileCommand:
		var survey_command: SurveyTileCommand = command as SurveyTileCommand
		var index: int = state.expansion.hand.find(survey_command.tile_copy_id)
		state.expansion.survey_charges -= 1
		state.expansion.removed_ids.append(survey_command.tile_copy_id)
		PhysicalTileRules.set_location(state, survey_command.tile_copy_id, TileLocationState.Kind.REMOVED_FROM_RUN)
		state.expansion.hand[index] = PhysicalTileRules.draw(state, config)
	# Free cycling is a domain resolution step, including an explicit still-dead retry.
	if state.phase == GamePhase.Type.TURN_INPUT:
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
	if state.expansion == null or state.phase != GamePhase.Type.TURN_INPUT:
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
		var reserve_command: ReserveTileCommand = command as ReserveTileCommand
		if state.expansion.reserve_id != 0:
			return _failure(&"reserve_occupied", "Reserve is already occupied.")
		return _validate_hand(state, reserve_command.tile_copy_id)
	if command is SurveyTileCommand:
		var survey_command: SurveyTileCommand = command as SurveyTileCommand
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
		if command.tile_copy_id <= 0 or state.expansion.reserve_id != command.tile_copy_id:
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
	var geometry: ValidationResult = PlacementQueryService.validate(
		state.expansion.board, definition, command.coordinate, command.rotation
	)
	if not geometry.is_valid:
		return geometry
	if not command.expected_signature.is_empty():
		var signature_matches: bool = false
		for option: PlacementOption in PlacementQueryService.query(
				state.expansion.board, definition, command.tile_copy_id, state.expansion.state_revision):
			if option.coordinate == command.coordinate and option.rotation == command.rotation \
					and option.signature == command.expected_signature:
				signature_matches = true
				break
		if not signature_matches:
			return _failure(&"stale_signature", "The preview signature does not match this intent.")
	return ValidationResult.success()


static func _place(state: RunState, content: ContentRegistry, command: PlaceTileCommand) -> void:
	var transformation: TransformationState = null
	if command.placement_mode == DomainTypes.PlacementMode.TRANSFORMATION:
		transformation = TransformationPlacementService.plan_for_command(state, content, command)
		assert(transformation != null, "Complete geometry intent is available before any placement mutation")
	state.phase = GamePhase.Type.RESOLVING_PLACEMENT
	var expansion: ExpansionState = state.expansion
	var tile: TileCopyState = PhysicalTileRules.find_copy(state, command.tile_copy_id)
	if command.source_zone == TileLocationState.Kind.ACTIVE_HAND:
		expansion.pending_refill_index = expansion.hand.find(command.tile_copy_id)
		expansion.hand[expansion.pending_refill_index] = 0
	else:
		expansion.reserve_id = 0
	expansion.normal_placements += 1
	if command.placement_mode == DomainTypes.PlacementMode.EXPANSION:
		expansion.board.add_cell(BoardCellState.from_definition(
			content.get_tile(tile.definition_id), tile.tile_copy_id, command.coordinate,
			command.rotation, expansion.current_act, expansion.normal_placements
		))
		PhysicalTileRules.set_location(state, tile.tile_copy_id, TileLocationState.Kind.BOARD_BASE)
		if state.features != null:
			TopologyService.add_cell_components(state, expansion.board.get_cell(command.coordinate))
			FeatureResolutionService.resolve(state, tile.tile_copy_id)
	elif command.placement_mode == DomainTypes.PlacementMode.TRANSFORMATION:
		TransformationPlacementService.place(state, content, command, transformation)
	else:
		DevelopmentPlacementService.place(state, content, command)
	# Later reward stages join the shared completion pipeline before this draw.
	var config: RunConfig = content.get_config()
	if expansion.normal_placements == config.act_placement_limits[expansion.current_act - 1]:
		state.phase = GamePhase.Type.RESOLVING_ACT_TRANSITION
		return # Later Acts phase owns seeding before this pending refill.
	PhysicalTileRules.refill_pending(state, config)
	state.phase = GamePhase.Type.TURN_INPUT
