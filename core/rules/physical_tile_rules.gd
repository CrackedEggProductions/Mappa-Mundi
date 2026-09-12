class_name PhysicalTileRules
extends RefCounted
## Internal resolution primitives; normal player mutations go through RulesEngine.


static func find_copy(state: RunState, copy_id: int) -> TileCopyState:
	for tile: TileCopyState in state.tile_copies:
		if tile.tile_copy_id == copy_id:
			return tile
	return null


static func set_location(state: RunState, copy_id: int, kind: TileLocationState.Kind) -> void:
	for location: TileLocationState in state.tile_locations:
		if location.tile_copy_id == copy_id:
			location.kind = kind
			return
	assert(false, "Missing physical tile location: %d" % copy_id)


static func acquire(state: RunState, definition_id: StringName, source: StringName,
		kind: TileLocationState.Kind) -> int:
	var copy_id: int = state.id_allocator.allocate()
	state.tile_copies.append(TileCopyState.new(
		copy_id, definition_id, state.expansion.current_act, source
	))
	state.tile_locations.append(TileLocationState.new(copy_id, kind))
	return copy_id


static func inject_emergency(state: RunState, config: RunConfig) -> void:
	# Caller combines the entire add/return batch before one full-bag shuffle.
	for definition_id: StringName in config.emergency_definitions:
		state.expansion.bag.append(acquire(
			state, definition_id, &"emergency_replenishment", TileLocationState.Kind.BAG
		))


static func draw(state: RunState, config: RunConfig) -> int:
	if state.expansion.bag.is_empty():
		inject_emergency(state, config)
		state.expansion.bag = state.rng.shuffled_ids(state.expansion.bag, &"empty_bag_replenishment")
	var copy_id: int = state.expansion.bag.pop_front()
	set_location(state, copy_id, TileLocationState.Kind.ACTIVE_HAND)
	return copy_id


static func refill_pending(state: RunState, config: RunConfig) -> void:
	var index: int = state.expansion.pending_refill_index
	if index >= 0:
		state.expansion.hand[index] = draw(state, config)
		state.expansion.pending_refill_index = -1
