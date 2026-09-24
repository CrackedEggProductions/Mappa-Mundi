class_name RelicGeometry
extends RefCounted
## Exact exceptions with explicit intent; permanent seams never depend on equipment.

const BOUNDARY: StringName = &"relic.boundary_stones"
const MIXED: StringName = &"relic.mixed_use_charter"


static func field_forest(first: int, second: int) -> bool:
	return (first == DomainTypes.EdgeType.FIELD and second == DomainTypes.EdgeType.FOREST) \
		or (first == DomainTypes.EdgeType.FOREST and second == DomainTypes.EdgeType.FIELD)


static func boundary_mismatch(board: BoardState, edges: Array[DomainTypes.EdgeType], at: Vector2i) -> int:
	if board.get_cell(at) != null or edges.size() != 4:
		return -1
	var mismatch: int = -1
	for direction: int in range(4):
		var neighbor: BoardCellState = board.get_cell(at + BoardState.ORTHOGONAL_OFFSETS[direction])
		if neighbor == null:
			continue
		var other: int = neighbor.effective_edges[(direction + 2) % 4]
		if edges[direction] == other:
			continue
		if mismatch != -1 or not field_forest(edges[direction], other):
			return -1
		mismatch = direction
	return mismatch


static func validate_expansion(state: RunState, definition: TileDefinition, command: PlaceTileCommand) -> ValidationResult:
	if command.boundary_direction == -1:
		return PlacementQueryService.validate(state.expansion.board, definition, command.coordinate, command.rotation)
	if command.boundary_direction not in [0, 1, 2, 3] or not RelicRules.use_available(state, BOUNDARY):
		return ValidationResult.failure(&"boundary_stones_unavailable", "Boundary Stones requires an unused equipped Act use and explicit direction.")
	if definition.tile_class != DomainTypes.TileClass.EXPANSION or definition.definition_id == &"tile.founding.homestead" \
		or command.rotation < 0 or command.rotation > 3:
		return ValidationResult.failure(&"invalid_boundary_intent", "Boundary intent requires a legal Expansion orientation.")
	var edges: Array[DomainTypes.EdgeType] = TileRotation.edges(definition.canonical_edges, command.rotation)
	if boundary_mismatch(state.expansion.board, edges, command.coordinate) != command.boundary_direction:
		return ValidationResult.failure(&"invalid_boundary_intent", "Exactly the selected Field/Forest mismatch may be ignored.")
	return ValidationResult.success()


static func record_boundary(board: BoardState, at: Vector2i, direction: int) -> void:
	var cell: BoardCellState = board.get_cell(at)
	var neighbor: BoardCellState = board.get_cell(at + BoardState.ORTHOGONAL_OFFSETS[direction])
	assert(cell != null and neighbor != null)
	assert(field_forest(cell.effective_edges[direction], neighbor.effective_edges[(direction + 2) % 4]))
	if direction not in cell.hard_boundaries:
		cell.hard_boundaries.append(direction)
		cell.hard_boundaries.sort()
	var reverse: int = (direction + 2) % 4
	if reverse not in neighbor.hard_boundaries:
		neighbor.hard_boundaries.append(reverse)
		neighbor.hard_boundaries.sort()


static func apply_boundary(state: RunState, intent: RefCounted) -> void:
	var direction: int = int(intent.get("boundary_direction"))
	if direction == -1:
		return
	assert(RelicRules.use_available(state, BOUNDARY), "Consume only a validated committed placement")
	record_boundary(state.expansion.board, intent.get("coordinate"), direction)
	var consumed: ValidationResult = RelicRules.consume_use(state, BOUNDARY)
	assert(consumed.is_valid)
	RelicRules.record(state, &"boundary_stones_applied", {
		"coordinate": intent.get("coordinate"), "direction": direction,
		"placement_index": state.expansion.normal_placements,
	}, int(intent.get("tile_copy_id")))


static func is_hard_boundary(board: BoardState, at: Vector2i, direction: int) -> bool:
	if direction not in [0, 1, 2, 3]:
		return false
	var cell: BoardCellState = board.get_cell(at)
	var neighbor: BoardCellState = board.get_cell(at + BoardState.ORTHOGONAL_OFFSETS[direction])
	return cell != null and neighbor != null and direction in cell.hard_boundaries \
		and (direction + 2) % 4 in neighbor.hard_boundaries \
		and field_forest(cell.effective_edges[direction], neighbor.effective_edges[(direction + 2) % 4])


static func can_add_development(state: RunState, cell: BoardCellState, definition: TileDefinition) -> bool:
	if cell.developments.is_empty():
		return true
	if cell.developments.size() != 1 or not RelicRules.active(state, MIXED) \
		or not TopologyService._has_type(cell, DomainTypes.FeatureType.SETTLEMENT):
		return false
	return _family_pair(cell.developments[0].family_id, definition.development_family_id)


static func slot_pair_valid(state: RunState, cell: BoardCellState) -> bool:
	if cell.developments.size() <= 1:
		return true
	return cell.developments.size() == 2 and RelicRules.active(state, MIXED) \
		and TopologyService._has_type(cell, DomainTypes.FeatureType.SETTLEMENT) \
		and _family_pair(cell.developments[0].family_id, cell.developments[1].family_id)


static func _family_pair(first: StringName, second: StringName) -> bool:
	return (first == &"family.housing" and second == &"family.market") or (first == &"family.market" and second == &"family.housing")


static func validate_boundaries(state: RunState, report: InvariantReport) -> void:
	if state.expansion == null:
		return
	var board: BoardState = state.expansion.board
	var proven: Dictionary[String, bool] = {}
	var used_acts: Array[int] = []
	if state.relics != null:
		for event: Dictionary in state.relics.history:
			if event.get("kind") != "boundary_stones_applied":
				continue
			var details: Variant = event.get("details")
			if not details is Dictionary or not details.get("coordinate") is Vector2i \
				or not details.get("direction") is int or not details.get("placement_index") is int \
				or not event.get("act") is int or not event.get("source_id") is int or not event.get("event_id") is int:
				report.add(&"invalid_boundary_history", "Boundary audit must retain typed source, direction and placement.")
				continue
			var at: Vector2i = details["coordinate"]
			var direction: int = details["direction"]
			var cell: BoardCellState = board.get_cell(at)
			if cell == null or not is_hard_boundary(board, at, direction) \
				or cell.base_tile_copy_id != event["source_id"] or cell.act_placed != event["act"] \
				or cell.normal_placement_index != details["placement_index"] or event["act"] in used_acts:
				report.add(&"invalid_boundary_history", "Each Act may record one permanent seam from its actual new-square placement.")
				continue
			used_acts.append(event["act"])
			var instance: RelicInstanceState = RelicRules.find(state, BOUNDARY)
			var uses: int = 0
			for use: Dictionary in state.relics.history:
				var use_details: Variant = use.get("details")
				if instance != null and use.get("kind") == "relic_use_consumed" and use.get("act") == event["act"] \
					and use.get("source_id") == instance.runtime_id and use.get("event_id") is int \
					and int(use["event_id"]) < int(event["event_id"]) and use_details is Dictionary \
					and use_details.get("definition_id") == String(BOUNDARY):
					uses += 1
			if uses != 1:
				report.add(&"unpaid_boundary_history", "Permanent seam requires one historical Boundary Stones use in its Act.")
			var key: String = _seam_key(at, direction)
			if proven.has(key):
				report.add(&"duplicate_boundary_history", "A permanent seam has one original application event.")
			proven[key] = true
	for at: Vector2i in board.sorted_coordinates():
		var cell: BoardCellState = board.get_cell(at)
		for direction: int in cell.hard_boundaries:
			if not is_hard_boundary(board, at, direction) or not proven.has(_seam_key(at, direction)):
				report.add(&"unproven_hard_boundary", "A hard seam must retain reciprocal geometry and its committed Relic application.")


static func _seam_key(at: Vector2i, direction: int) -> String:
	var other: Vector2i = at + BoardState.ORTHOGONAL_OFFSETS[direction]
	if BoardState.coordinate_before(other, at):
		return "%d,%d|%d,%d" % [other.x, other.y, at.x, at.y]
	return "%d,%d|%d,%d" % [at.x, at.y, other.x, other.y]
