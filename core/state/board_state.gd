class_name BoardState
extends RefCounted
## Sparse authoritative squares. Logic enumerates coordinates in x-then-y order.

const ORTHOGONAL_OFFSETS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var cells: Dictionary[Vector2i, BoardCellState] = {}
var revision: int = 0


func get_cell(coordinate: Vector2i) -> BoardCellState:
	return cells.get(coordinate)


func sorted_coordinates() -> Array[Vector2i]:
	var coordinates: Array[Vector2i] = cells.keys()
	coordinates.sort_custom(coordinate_before)
	return coordinates


func frontier() -> Array[Vector2i]:
	var candidates: Dictionary[Vector2i, bool] = {}
	for coordinate: Vector2i in sorted_coordinates():
		for offset: Vector2i in ORTHOGONAL_OFFSETS:
			var neighbor: Vector2i = coordinate + offset
			if not cells.has(neighbor):
				candidates[neighbor] = true
	var result: Array[Vector2i] = candidates.keys()
	result.sort_custom(coordinate_before)
	return result


func add_cell(cell: BoardCellState) -> void:
	assert(cell != null, "Cannot add a null board cell")
	assert(not cells.has(cell.coordinate), "Cannot overwrite an occupied board square")
	cells[cell.coordinate] = cell
	revision += 1


static func coordinate_before(left: Vector2i, right: Vector2i) -> bool:
	return left.x < right.x or (left.x == right.x and left.y < right.y)
