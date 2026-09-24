extends RefCounted
## Controlled acquisition and board setup; Transformation mutations use commands.

const Previous = preload("res://tests/fixtures/phase_five_factory.gd")
const Geography = preload("res://tests/fixtures/phase_three_factory.gd")
const TYPE = DomainTypes.FeatureType
const URBAN: StringName = &"tile.transformation.urban_expansion"
const BRIDGE: StringName = &"tile.transformation.bridge"
const REWILD: StringName = &"tile.transformation.rewilding"


static func content() -> ContentRegistry:
	var registry: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = registry.load_phase_six()
	assert(result.is_valid, result.user_message)
	return registry


static func create(registry: ContentRegistry, act: int = 3) -> RunState:
	return Previous.create(registry, act)


static func command(option: PlacementOption, source: TileLocationState.Kind = TileLocationState.Kind.ACTIVE_HAND) -> PlaceTileCommand:
	var intent: PlaceTileCommand = Previous.command(option, source)
	intent.transformation_mode = option.transformation_mode
	intent.target_base_copy_id = option.target_base_copy_id
	intent.transformation_signature = option.transformation_signature
	return intent


static func option_at(state: RunState, registry: ContentRegistry, copy_id: int,
		at: Vector2i, mode: StringName, rotation: int = -1) -> PlacementOption:
	for option: PlacementOption in PlacementQueryService.query_for_copy(state, registry, copy_id):
		if option.coordinate == at and option.transformation_mode == mode and (rotation < 0 or option.rotation == rotation):
			return option
	return null


static func play(state: RunState, registry: ContentRegistry, id: StringName,
		at: Vector2i, mode: StringName, rotation: int = -1) -> int:
	var copy_id: int = Previous.acquire_hand(state, id)
	var option: PlacementOption = option_at(state, registry, copy_id, at, mode, rotation)
	assert(option != null, "No %s option for %s at %s rotation %d" % [mode, id, at, rotation])
	var result: ValidationResult = RulesEngine.execute(state, registry, command(option))
	assert(result.is_valid, result.user_message)
	return copy_id


static func two_settlements(registry: ContentRegistry) -> RunState:
	var state: RunState = create(registry)
	Previous.complete_settlement(state, registry)
	Geography.add(state, registry, &"tile.road_end", Vector2i.RIGHT, 3)
	Geography.add(state, registry, &"tile.open_fields", Vector2i(1, -1))
	Geography.add(state, registry, &"tile.open_fields", Vector2i(1, -2))
	Geography.add(state, registry, &"tile.hamlet_edge", Vector2i(1, -3), 3)
	Geography.add(state, registry, &"tile.hamlet_edge", Vector2i(0, -3), 1)
	return state


static func river(registry: ContentRegistry, complete: bool = false) -> RunState:
	var state: RunState = create(registry)
	Geography.add(state, registry, &"tile.river_run", Vector2i.DOWN)
	if complete:
		Geography.add(state, registry, &"tile.river_end", Vector2i(0, 2))
	return state


static func two_forests(registry: ContentRegistry) -> RunState:
	var state: RunState = create(registry)
	Geography.add(state, registry, &"tile.forest_edge", Vector2i.LEFT, 1)
	Geography.add(state, registry, &"tile.open_fields", Vector2i(-2, 0))
	Geography.add(state, registry, &"tile.open_fields", Vector2i(-2, 1))
	Geography.add(state, registry, &"tile.forest_edge", Vector2i(-2, 2), 1)
	Geography.add(state, registry, &"tile.forest_edge", Vector2i(-1, 2), 3)
	return state


static func component(state: RunState, at: Vector2i, type: DomainTypes.FeatureType) -> FeatureComponentState:
	return state.features.component_at(at, type)


static func gains(state: RunState, source_id: int, track: int) -> int:
	var total: int = 0
	for event: FeatureHistoryRecord in state.features.history:
		if event.kind == &"realm_track_changed" and event.source_id == source_id and event.track == track:
			total += event.amount
	return total


static func events(state: RunState, kind: StringName) -> int:
	var count: int = 0
	for event: FeatureHistoryRecord in state.features.history:
		if event.kind == kind:
			count += 1
	return count
