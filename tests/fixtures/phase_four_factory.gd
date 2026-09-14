extends RefCounted
## Controlled economic scenarios; none expose a future player action.

const Previous = preload("res://tests/fixtures/phase_three_factory.gd")
const TYPE = DomainTypes.FeatureType


static func content() -> ContentRegistry:
	return Previous.content()


static func create(registry: ContentRegistry) -> RunState:
	var state: RunState = Previous.create(registry)
	TradeNetworkService.initialize(state)
	assert(InvariantValidator.validate(state, registry).is_valid)
	return state


static func chain(registry: ContentRegistry, hubs: int = 2) -> RunState:
	var state: RunState = create(registry)
	for index: int in range(hubs):
		Previous.add(state, registry, &"tile.settlement_gate", Vector2i(index + 1, index), 2)
		if index + 1 < hubs:
			Previous.add(state, registry, &"tile.settlement_gate", Vector2i(index + 1, index + 1))
	return state


static func member(state: RunState, at: Vector2i, type: DomainTypes.FeatureType) -> int:
	return state.features.component_at(at, type).lineage_id


static func reopen_first_road(state: RunState, registry: ContentRegistry) -> void:
	assert(Previous.rewrite(state, registry, Vector2i(1, 0), [3, 0, 4, 3]).is_valid)


static func close_first_road(state: RunState, registry: ContentRegistry) -> void:
	Previous.add(state, registry, &"tile.road_end", Vector2i(1, -1), 2)


static func pair(registry: ContentRegistry) -> RunState:
	var state: RunState = create(registry)
	Previous.add(state, registry, &"tile.road_end", Vector2i.RIGHT, 3)
	Previous.add(state, registry, &"tile.open_fields", Vector2i(2, 0))
	Previous.add(state, registry, &"tile.settlement_gate", Vector2i(3, 0))
	return state


static func connect_pair(state: RunState) -> void:
	var link: TradeLinkState = TradeLinkState.new()
	link.from_lineage_id = member(state, Vector2i.ZERO, TYPE.ROAD)
	link.to_lineage_id = member(state, Vector2i(3, 0), TYPE.ROAD)
	state.trade.authorized_links.append(link)
	TradeNetworkService.reconcile(state)


static func disconnect_pair(state: RunState) -> void:
	state.trade.authorized_links.clear()
	TradeNetworkService.reconcile(state)


static func genealogy(registry: ContentRegistry) -> RunState:
	var state: RunState = pair(registry)
	connect_pair(state)
	disconnect_pair(state)
	connect_pair(state)
	assert(InvariantValidator.validate(state, registry).is_valid, InvariantValidator.validate(state, registry).describe())
	return state


static func settlement_merger(registry: ContentRegistry, paid: bool) -> RunState:
	var state: RunState = create(registry)
	Previous.add(state, registry, &"tile.hamlet_edge", Vector2i.UP, 2)
	if paid:
		Previous.add(state, registry, &"tile.road_end", Vector2i.RIGHT, 3)
	Previous.add(state, registry, &"tile.open_fields", Vector2i(1, -1))
	Previous.add(state, registry, &"tile.open_fields", Vector2i(1, -2))
	Previous.add(state, registry, &"tile.hamlet_edge", Vector2i(1, -3), 3)
	Previous.add(state, registry, &"tile.hamlet_edge", Vector2i(0, -3), 1)
	assert(Previous.rewrite(state, registry, Vector2i.UP, [4, 0, 4, 0]).is_valid)
	assert(Previous.rewrite(state, registry, Vector2i(0, -3), [0, 4, 4, 0]).is_valid)
	Previous.add(state, registry, &"tile.settlement_throughway", Vector2i(0, -2))
	if paid:
		assert(Previous.rewrite(state, registry, Vector2i.RIGHT, [0, 3, 0, 3]).is_valid)
		Previous.add(state, registry, &"tile.road_end", Vector2i(2, 0), 3)
	else:
		Previous.add(state, registry, &"tile.road_end", Vector2i.RIGHT, 3)
	return state


static func road_merger(registry: ContentRegistry) -> RunState:
	var state: RunState = create(registry)
	Previous.add(state, registry, &"tile.road_end", Vector2i.RIGHT, 3)
	Previous.add(state, registry, &"tile.open_fields", Vector2i(2, 0))
	Previous.add(state, registry, &"tile.open_fields", Vector2i(2, 1))
	Previous.add(state, registry, &"tile.settlement_gate", Vector2i(2, 2), 2)
	Previous.add(state, registry, &"tile.road_end", Vector2i(1, 2), 1)
	assert(Previous.rewrite(state, registry, Vector2i.RIGHT, [0, 0, 3, 3]).is_valid)
	assert(Previous.rewrite(state, registry, Vector2i(1, 2), [3, 3, 0, 0]).is_valid)
	Previous.add(state, registry, &"tile.straight_road", Vector2i.ONE)
	return state


static func stage_expansion(state: RunState, registry: ContentRegistry, id: StringName, at: Vector2i, rotation: int) -> void:
	# Batch fixture only: caller must finish feature resolution before inspecting
	# stable-state invariants. This is not a player-facing placement command.
	var definition: TileDefinition = registry.get_tile(id)
	assert(PlacementQueryService.validate(state.expansion.board, definition, at, rotation).is_valid)
	var copy_id: int = PhysicalTileRules.acquire(state, id, &"scenario_fixture", TileLocationState.Kind.BOARD_BASE)
	state.expansion.normal_placements += 1
	var cell: BoardCellState = BoardCellState.from_definition(definition, copy_id, at, rotation, 1, state.expansion.normal_placements)
	state.expansion.board.add_cell(cell)
	TopologyService.add_cell_components(state, cell)
	state.expansion.state_revision += 1
