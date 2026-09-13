class_name EnclosureService
extends RefCounted
## Enclosures are independent of edge-connected lineage identity.


static func capture(state: RunState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var enclosures: Array[EnclosureState] = state.features.enclosures.duplicate()
	enclosures.sort_custom(func(a: EnclosureState, b: EnclosureState) -> bool: return a.enclosure_id < b.enclosure_id)
	for enclosure: EnclosureState in enclosures:
		if enclosure.stage != &"monastery" or enclosure.completed_stages.has(enclosure.stage):
			continue
		var occupied: int = 0
		var natural: int = 0
		for x: int in range(-1, 2):
			for y: int in range(-1, 2):
				if x == 0 and y == 0:
					continue
				var cell: BoardCellState = state.expansion.board.get_cell(enclosure.coordinate + Vector2i(x, y))
				if cell == null:
					continue
				occupied += 1
				if has_natural_geography(cell):
					natural += 1
		if occupied == 8:
			result.append({"enclosure_id": enclosure.enclosure_id, "stage": String(enclosure.stage), "natural_count": natural, "source_id": enclosure.development_tile_copy_id})
	return result


static func has_natural_geography(cell: BoardCellState) -> bool:
	for edge: int in cell.effective_edges:
		if edge in [DomainTypes.EdgeType.FIELD, DomainTypes.EdgeType.FOREST, DomainTypes.EdgeType.RIVER]:
			return true
	return false
