extends RefCounted
## Archived physical copies exercise identity without inventing bag/placement rules.


static func content() -> ContentRegistry:
	var registry: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = registry.load_content()
	assert(result.is_valid, result.user_message)
	return registry


static func representative(seed_value: int = 735192) -> RunState:
	var state: RunState = RunState.new(seed_value)
	for index: int in range(3):
		var copy_id: int = state.id_allocator.allocate()
		state.tile_copies.append(TileCopyState.new(
			copy_id, &"tile.open_fields", index + 1, &"phase_one_fixture"
		))
		state.tile_locations.append(TileLocationState.new(
			copy_id, TileLocationState.Kind.REMOVED_FROM_RUN
		))
		# Allocated but no longer represented: cursor must never reuse these IDs.
		state.id_allocator.allocate()
	state.rng.integer_range(-100, 100)
	state.rng.select_index(13)
	state.rng.shuffled_ids([9, 2, 8, 5, 7])
	state.rng.choose_definition_id([&"tile.open_fields", &"tile.straight_road"])
	return state
