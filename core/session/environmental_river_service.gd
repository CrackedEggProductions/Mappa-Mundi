class_name EnvironmentalRiverService
extends RefCounted
## Setup geography, never a player placement or a replay recipe for loading saves.

const SOURCE: StringName = &"setup_environment"
const RIVER_IDS: Array[StringName] = [&"tile.river_run", &"tile.river_bend", &"tile.river_end"]


static func generate(state: RunState, content: ContentRegistry) -> void:
	assert(state.expansion.board.cells.size() == 1 and path(state).is_empty())
	var choices: Array[Array] = templates()
	var selected: Array = choices[state.rng.select_index(choices.size(), &"environmental_river_path")]
	assert(valid_path(state.expansion.board, selected), "Setup River template must match every occupied edge")
	for item: Dictionary in selected:
		var definition_id: StringName = item["definition_id"]
		var copy_id: int = PhysicalTileRules.acquire(state, definition_id, SOURCE, TileLocationState.Kind.BOARD_BASE)
		state.expansion.board.add_cell(BoardCellState.from_definition(
			content.get_tile(definition_id), copy_id, item["coordinate"], item["rotation"], 1, 0))


static func templates() -> Array[Array]:
	# Seven continuation positions: bends never first/last and at least one Run
	# separates them. Each of the 24 combinations is collision-free by construction.
	var result: Array[Array] = []
	for first: int in range(1, 4):
		for second: int in range(first + 2, 6):
			for first_turn: int in [-1, 1]:
				for second_turn: int in [-1, 1]:
					var entries: Array[Dictionary] = []
					var coordinate: Vector2i = Vector2i.DOWN
					var heading: int = 2
					for index: int in range(8):
						var incoming: int = (heading + 2) % 4
						var turn: int = first_turn if index == first else (second_turn if index == second else 0)
						var outgoing: int = posmod(heading + turn, 4)
						var edges: Array[DomainTypes.EdgeType] = [0, 0, 0, 0]
						edges[incoming] = DomainTypes.EdgeType.RIVER
						if index < 7:
							edges[outgoing] = DomainTypes.EdgeType.RIVER
						var definition_id: StringName = &"tile.river_end" if index == 7 else (
							&"tile.river_bend" if turn != 0 else &"tile.river_run")
						entries.append({"coordinate": coordinate, "definition_id": definition_id,
							"rotation": _rotation(definition_id, edges), "edges": edges})
						heading = outgoing
						coordinate += BoardState.ORTHOGONAL_OFFSETS[heading]
					result.append(entries)
	return result


static func valid_path(board: BoardState, entries: Array) -> bool:
	var occupied: Dictionary = {}
	for coordinate: Vector2i in board.sorted_coordinates():
		occupied[coordinate] = board.get_cell(coordinate).effective_edges
	for item: Dictionary in entries:
		var coordinate: Vector2i = item["coordinate"]
		var edges: Array = item["edges"]
		if occupied.has(coordinate):
			return false
		for direction: int in range(4):
			var neighbor: Vector2i = coordinate + BoardState.ORTHOGONAL_OFFSETS[direction]
			if occupied.has(neighbor) and edges[direction] != occupied[neighbor][(direction + 2) % 4]:
				return false
		occupied[coordinate] = edges
	return true


static func path(state: RunState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.expansion == null:
		return result
	for cell: BoardCellState in state.expansion.board.cells.values():
		if cell == null or not is_environment(state, cell.base_tile_copy_id):
			continue
		result.append({"tile_copy_id": cell.base_tile_copy_id, "definition_id": String(cell.definition_id),
			"coordinate": [cell.coordinate.x, cell.coordinate.y], "rotation": cell.rotation})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["tile_copy_id"] < b["tile_copy_id"])
	return result


static func is_environment(state: RunState, copy_id: int) -> bool:
	var copy: TileCopyState = PhysicalTileRules.find_copy(state, copy_id)
	return copy != null and copy.acquisition_source == SOURCE


static func _rotation(definition_id: StringName, edges: Array[DomainTypes.EdgeType]) -> int:
	var canonical: Array[DomainTypes.EdgeType] = HomesteadContentValidator.canonical_edges_for(definition_id)
	for quarter_turns: int in range(4):
		if TileRotation.edges(canonical, quarter_turns) == edges:
			return quarter_turns
	assert(false, "Environmental piece must have a canonical orientation")
	return 0
