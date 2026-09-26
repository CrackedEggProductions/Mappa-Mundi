class_name PlacementChronology
extends RefCounted
## Act-local counters are not a global clock. Physical journal order also handles
## authorized bonus placements, which deliberately share a normal-placement index.


static func count_for_act(state: RunState, act: int) -> int:
	if state.charters == null:
		return state.expansion.normal_placements
	var count: int = 0
	for entry: Dictionary in state.charters.placement_history:
		if entry.get("act") == act and entry.get("is_bonus") == false:
			count += 1
	return count


static func rank(state: RunState, copy_id: int, act: int, index: int) -> int:
	if state.charters == null:
		return act * 2147483648 + index
	var founding: BoardCellState = state.expansion.board.get_cell(Vector2i.ZERO)
	if founding != null and copy_id == founding.base_tile_copy_id:
		return 0
	for position: int in range(state.charters.placement_history.size()):
		if state.charters.placement_history[position].get("copy_id") == copy_id:
			return position + 1
	return -1


static func valid_index(state: RunState, act: int, index: int) -> bool:
	return act >= 1 and act <= state.expansion.current_act \
		and index >= 0 and index <= count_for_act(state, act)
