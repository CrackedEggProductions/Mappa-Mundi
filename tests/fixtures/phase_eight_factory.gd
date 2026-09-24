extends RefCounted
## Phase-8 test fixtures preserve canonical geometry; all player decisions use commands.

const Previous = preload("res://tests/fixtures/phase_seven_factory.gd")
const Geography = Previous.Geography
const Development = Previous.Development


static func content() -> ContentRegistry:
	var registry: ContentRegistry = ContentRegistry.new()
	var loaded: ValidationResult = registry.load_phase_eight()
	assert(loaded.is_valid, loaded.user_message)
	return registry


static func create(registry: ContentRegistry, act: int = 3) -> RunState:
	return activate(Previous.create(registry, act))


static func activate(state: RunState) -> RunState:
	if state.specialists == null:
		SpecialistRules.initialize(state)
	state.relics = RelicState.new()
	state.rewards = RewardState.new()
	state.relics.current_act = state.expansion.current_act
	state.relics.capacity = RelicRules.capacity_for_act(state.expansion.current_act)
	return state


static func equip(state: RunState, registry: ContentRegistry, id: StringName) -> void:
	var result: ValidationResult = RelicRules.acquire(state, registry, id)
	assert(result.is_valid, result.user_message)


static func play(state: RunState, registry: ContentRegistry, id: StringName,
		coordinate: Vector2i, rotation: int = -1, mode: StringName = &"") -> int:
	return Previous.play(state, registry, id, coordinate, rotation, mode)


static func decline_assignment(state: RunState, registry: ContentRegistry) -> void:
	if state.pending_choice != null and state.pending_choice.kind == &"specialist_assignment":
		Previous.decline(state, registry)


static func load_copy(state: RunState, registry: ContentRegistry) -> RunState:
	return Previous.load_copy(state, registry)
