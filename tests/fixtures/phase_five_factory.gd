extends RefCounted
## Controlled acquisition only; Development gameplay always uses RulesEngine.

const Previous = preload("res://tests/fixtures/phase_four_factory.gd")
const TYPE = DomainTypes.FeatureType
const PREFIX: String = "tile.development."


static func content() -> ContentRegistry:
	var registry: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = registry.load_phase_five()
	assert(result.is_valid, result.user_message)
	return registry


static func create(registry: ContentRegistry, act: int = 1) -> RunState:
	var state: RunState = Previous.create(registry)
	state.expansion.current_act = act
	# Keep legal Expansion draws available so a Development consequence is isolated.
	for index: int in range(16):
		state.expansion.bag.append(PhysicalTileRules.acquire(state, &"tile.open_fields",
			&"scenario_fixture", TileLocationState.Kind.BAG))
	return state


static func acquire_hand(state: RunState, id: StringName, slot: int = 0) -> int:
	var old: int = state.expansion.hand[slot]
	state.expansion.removed_ids.append(old)
	PhysicalTileRules.set_location(state, old, TileLocationState.Kind.REMOVED_FROM_RUN)
	var copy_id: int = PhysicalTileRules.acquire(state, id, &"scenario_fixture", TileLocationState.Kind.ACTIVE_HAND)
	state.expansion.hand[slot] = copy_id
	return copy_id


static func options(state: RunState, registry: ContentRegistry, copy_id: int) -> Array[PlacementOption]:
	return PlacementQueryService.query_for_copy(state, registry, copy_id)


static func command(option: PlacementOption, source: TileLocationState.Kind = TileLocationState.Kind.ACTIVE_HAND) -> PlaceTileCommand:
	var intent: PlaceTileCommand = PlaceTileCommand.new(option.tile_copy_id, source, option.coordinate, option.rotation)
	intent.placement_mode = option.placement_mode
	intent.host_lineage_id = option.host_lineage_id
	intent.river_lineage_id = option.river_lineage_id
	intent.target_development_copy_id = option.target_development_copy_id
	intent.enclosure_id = option.enclosure_id
	intent.expected_board_revision = option.board_revision
	intent.expected_state_revision = option.state_revision
	intent.expected_signature = option.signature
	return intent


static func play(state: RunState, registry: ContentRegistry, id: StringName,
		at: Vector2i, river_id: int = 0) -> int:
	var copy_id: int = acquire_hand(state, id)
	for option: PlacementOption in options(state, registry, copy_id):
		if option.coordinate == at and (river_id == 0 or option.river_lineage_id == river_id):
			var result: ValidationResult = RulesEngine.execute(state, registry, command(option))
			assert(result.is_valid, result.user_message)
			return copy_id
	assert(false, "No legal fixture placement for %s at %s" % [id, at])
	return 0


static func development(state: RunState, at: Vector2i) -> DevelopmentState:
	return state.expansion.board.get_cell(at).developments[0]


static func complete_settlement(state: RunState, registry: ContentRegistry) -> void:
	Previous.Previous.add(state, registry, &"tile.hamlet_edge", Vector2i.UP, 2)


static func fields(state: RunState, registry: ContentRegistry, neighbors: int = 0) -> Vector2i:
	Previous.Previous.add(state, registry, &"tile.river_end", Vector2i.DOWN)
	var center: Vector2i = Vector2i(0, 3)
	Previous.Previous.add(state, registry, &"tile.open_fields", Vector2i(0, 2))
	Previous.Previous.add(state, registry, &"tile.open_fields", center)
	var offsets: Array[Vector2i] = [Vector2i(1, -1), Vector2i.RIGHT, Vector2i.ONE,
		Vector2i.DOWN, Vector2i(-1, 1), Vector2i.LEFT, Vector2i(-1, -1)]
	for index: int in range(maxi(0, neighbors - 1)):
		Previous.Previous.add(state, registry, &"tile.open_fields", center + offsets[index])
	return center


static func ports(state: RunState, registry: ContentRegistry, count: int = 2) -> void:
	for index: int in range(count):
		Previous.Previous.add(state, registry, &"tile.riverside_hamlet", Vector2i(0, index + 1), 1)
		Previous.Previous.add(state, registry, &"tile.hamlet_edge", Vector2i(1, index + 1), 3)


static func location(state: RunState, copy_id: int) -> TileLocationState.Kind:
	for value: TileLocationState in state.tile_locations:
		if value.tile_copy_id == copy_id:
			return value.kind
	return TileLocationState.Kind.REMOVED_FROM_RUN


static func assert_valid(state: RunState, registry: ContentRegistry) -> void:
	var report: InvariantReport = InvariantValidator.validate(state, registry)
	assert(report.is_valid, report.describe())
