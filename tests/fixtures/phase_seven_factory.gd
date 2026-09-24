extends RefCounted
## Controlled geography/acquisition; gameplay and choice mutations use commands.

const Previous = preload("res://tests/fixtures/phase_six_factory.gd")
const Development = preload("res://tests/fixtures/phase_five_factory.gd")
const Geography = preload("res://tests/fixtures/phase_three_factory.gd")
const TYPE = DomainTypes.FeatureType


static func content() -> ContentRegistry:
	var registry: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = registry.load_phase_seven()
	assert(result.is_valid, result.user_message)
	return registry


static func create(registry: ContentRegistry, act: int = 3) -> RunState:
	var state: RunState = Previous.create(registry, act)
	SpecialistRules.initialize(state)
	return state


static func activate(state: RunState) -> RunState:
	SpecialistRules.initialize(state)
	return state


static func intent(state: RunState, registry: ContentRegistry, definition: StringName,
		at: Vector2i, rotation: int = -1, mode: StringName = &"") -> PlaceTileCommand:
	var copy_id: int = Development.acquire_hand(state, definition)
	for option: PlacementOption in PlacementQueryService.query_for_copy(state, registry, copy_id):
		if option.coordinate == at and (rotation < 0 or option.rotation == rotation) \
				and (mode.is_empty() or mode == option.transformation_mode):
			return Previous.command(option)
	assert(false, "No legal Specialist scenario intent: %s at %s rotation %s" % [definition, at, rotation])
	return null


static func play(state: RunState, registry: ContentRegistry, definition: StringName,
		at: Vector2i, rotation: int = -1, mode: StringName = &"") -> int:
	var command: PlaceTileCommand = intent(state, registry, definition, at, rotation, mode)
	assert(command != null)
	var result: ValidationResult = RulesEngine.execute(state, registry, command)
	assert(result.is_valid, result.user_message + str(result.debug_details))
	return command.tile_copy_id


static func assign(state: RunState, registry: ContentRegistry, type: int,
		target_id: int = 0, piece_index: int = 0) -> int:
	assert(state.pending_choice != null, "Placement offers optional local assignment")
	var piece_id: int = state.specialists.pieces[piece_index].piece_id
	for option: Dictionary in state.pending_choice.options:
		if int(option.piece_id) == piece_id and int(option.target_type) == type \
				and (target_id == 0 or int(option.target_id) == target_id):
			var command: ResolveSpecialistAssignmentCommand = ResolveSpecialistAssignmentCommand.new(
				state.pending_choice.choice_id, piece_id, type, int(option.target_id), false)
			var result: ValidationResult = RulesEngine.execute(state, registry, command)
			assert(result.is_valid, result.user_message + str(result.debug_details))
			return piece_id
	assert(false, "Expected local piece/target pair was not offered")
	return 0


static func decline(state: RunState, registry: ContentRegistry) -> void:
	if state.pending_choice == null:
		return
	var result: ValidationResult = RulesEngine.execute(state, registry,
		ResolveSpecialistAssignmentCommand.new(state.pending_choice.choice_id, 0, -1, 0, true))
	assert(result.is_valid, result.user_message)


static func member(state: RunState, at: Vector2i, type: int) -> int:
	return state.features.component_at(at, type).lineage_id


static func bind_for_fixture(state: RunState, registry: ContentRegistry, at: Vector2i,
		type: int, piece_index: int = 0, role: StringName = &"") -> void:
	# Controlled existing occupation; critical locality tests use actual placement choices.
	var piece: SpecialistPieceState = state.specialists.pieces[piece_index]
	piece.status = SpecialistPieceState.Status.ASSIGNED
	piece.assigned_target_type = type
	piece.assigned_target_id = member(state, at, type)
	piece.assigned_act = state.expansion.current_act
	piece.assigned_placement_index = state.expansion.normal_placements
	piece.growth_baseline_component_ids = SpecialistRules.all_component_ids(state)
	if not role.is_empty():
		assert(RulesEngine.execute(state, registry, RequestSpecialistTrainingCommand.new(piece.piece_id)).is_valid)
		assert(RulesEngine.execute(state, registry, ResolveSpecialistTrainingCommand.new(state.pending_choice.choice_id, role)).is_valid)
	assert(InvariantValidator.validate(state, registry).is_valid,
		InvariantValidator.validate(state, registry).describe())


static func load_copy(state: RunState, registry: ContentRegistry) -> RunState:
	var saved: SerializationResult = RunSerializer.serialize(state, registry)
	assert(saved.validation.is_valid, str(saved.validation.debug_details))
	var restored: DeserializationResult = RunSerializer.deserialize(saved.json_text, registry)
	assert(restored.validation.is_valid, str(restored.validation.debug_details))
	return restored.state


static func bridge_pair(registry: ContentRegistry) -> RunState:
	var state: RunState = Previous.river(registry)
	Geography.add(state, registry, &"tile.bending_road", Vector2i.RIGHT, 2)
	Geography.add(state, registry, &"tile.straight_road", Vector2i.ONE)
	Geography.add(state, registry, &"tile.forest_edge", Vector2i.LEFT, 1)
	Geography.add(state, registry, &"tile.road_end", Vector2i(-1, 1), 2)
	return activate(state)


static func forest_pair(registry: ContentRegistry) -> RunState:
	var state: RunState = Previous.two_forests(registry)
	assert(Geography.rewrite(state, registry, Vector2i.LEFT, [1, 1, 1, 0]).is_valid)
	assert(Geography.rewrite(state, registry, Vector2i(-1, 2), [1, 0, 0, 1]).is_valid)
	return activate(state)


static func settlement_pair(registry: ContentRegistry) -> RunState:
	var state: RunState = Previous.two_settlements(registry)
	assert(Geography.rewrite(state, registry, Vector2i.UP, [4, 0, 4, 0]).is_valid)
	assert(Geography.rewrite(state, registry, Vector2i(0, -3), [4, 4, 4, 0]).is_valid)
	return activate(state)
