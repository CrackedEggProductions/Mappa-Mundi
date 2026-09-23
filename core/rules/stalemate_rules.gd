class_name StalemateRules
extends RefCounted
## Exact legality, never a heuristic; Reserve is deliberately absent from both tests.


static func has_play(state: RunState, content: ContentRegistry, copy_id: int) -> bool:
	return not PlacementQueryService.query_for_copy(state, content, copy_id).is_empty()


static func is_dead_hand(state: RunState, content: ContentRegistry) -> bool:
	if state.expansion.hand.size() != content.get_config().hand_capacity:
		return false
	for copy_id: int in state.expansion.hand:
		if copy_id == 0 or has_play(state, content, copy_id):
			return false
	return true


static func is_global_stalemate(state: RunState, content: ContentRegistry) -> bool:
	if not is_dead_hand(state, content):
		return false
	for copy_id: int in state.expansion.bag:
		if has_play(state, content, copy_id):
			return false
	return true


static func cycle_if_dead(state: RunState, content: ContentRegistry) -> bool:
	if not is_dead_hand(state, content):
		return false
	var config: RunConfig = content.get_config()
	var global_stalemate: bool = is_global_stalemate(state, content)
	for copy_id: int in state.expansion.hand:
		PhysicalTileRules.set_location(state, copy_id, TileLocationState.Kind.BAG)
		state.expansion.bag.append(copy_id)
	state.expansion.hand.clear()
	if global_stalemate:
		PhysicalTileRules.inject_emergency(state, config)
	state.expansion.bag = state.rng.shuffled_ids(state.expansion.bag, &"dead_hand_cycle")
	for index: int in range(config.hand_capacity):
		state.expansion.hand.append(PhysicalTileRules.draw(state, config))
	# One resolution gives one free cycle. A still-dead redraw remains eligible;
	# never loop unpredictably within a single command or force a Reserve placement.
	return true
