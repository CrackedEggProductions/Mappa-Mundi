extends "res://tests/framework/test_suite.gd"

const Factory = preload("res://tests/fixtures/phase_one_factory.gd")


func tests() -> Array[Callable]:
	return [
		allocates_deterministically_in_one_run_local_space,
		allocations_are_unique,
		cursor_resumes_without_reusing_discarded_ids,
		last_available_id_does_not_overflow_cursor,
		copies_of_one_definition_have_distinct_identity,
		run_metadata_forwards_live_owner_state,
		validates_empty_seeded_foundation,
		validates_archived_physical_copies,
		rejects_missing_state_and_content,
		rejects_missing_continuation_owners,
		rejects_duplicate_and_nonpositive_ids,
		rejects_next_id_collision,
		rejects_unknown_static_reference,
		rejects_missing_or_duplicate_locations,
		rejects_dangling_location_reference,
		rejects_unknown_or_unimplemented_location_kind,
		rejects_invalid_acquisition_metadata,
		rejects_incompatible_metadata_and_future_phase,
		rejects_null_registry_records,
		diagnostics_identify_corrupt_entity,
	]


func allocates_deterministically_in_one_run_local_space() -> bool:
	var left: RunIdAllocator = RunIdAllocator.new()
	var right: RunIdAllocator = RunIdAllocator.new()
	for expected: int in range(1, 21):
		expect_equal(left.allocate(), expected, "Monotonic allocation")
		expect_equal(right.allocate(), expected, "Independent run starts its own space")
	return true


func allocations_are_unique() -> bool:
	var allocator: RunIdAllocator = RunIdAllocator.new()
	var allocated: Array[int] = []
	for index: int in range(1000):
		var runtime_id: int = allocator.allocate()
		expect_true(runtime_id not in allocated, "Allocation %d must be unique" % index)
		allocated.append(runtime_id)
	return true


func cursor_resumes_without_reusing_discarded_ids() -> bool:
	var allocator: RunIdAllocator = RunIdAllocator.new()
	for index: int in range(7):
		expect_equal(allocator.allocate(), index + 1, "Allocate IDs even without surviving entities")
	var restored: RunIdAllocator = RunIdAllocator.new(allocator.get_next_id())
	expect_equal(restored.allocate(), 8, "Never derive next ID from surviving entity count")
	expect_equal(restored.allocate(), allocator.allocate() + 1, "Cursor progresses after restoration")
	return true


func last_available_id_does_not_overflow_cursor() -> bool:
	var allocator: RunIdAllocator = RunIdAllocator.new(RunIdAllocator.EXHAUSTED_CURSOR - 1)
	expect_equal(allocator.allocate(), RunIdAllocator.EXHAUSTED_CURSOR - 1, "Final legal ID")
	expect_equal(allocator.get_next_id(), RunIdAllocator.EXHAUSTED_CURSOR, "Exhaustion sentinel")
	return true


func copies_of_one_definition_have_distinct_identity() -> bool:
	var state: RunState = Factory.representative()
	expect_equal(state.tile_copies[0].definition_id, state.tile_copies[1].definition_id, "Same static design")
	expect_true(state.tile_copies[0].tile_copy_id != state.tile_copies[1].tile_copy_id, "Different physical IDs")
	state.tile_copies[0].acquisition_source = &"changed_fixture"
	expect_equal(state.tile_copies[1].acquisition_source, &"phase_one_fixture", "Copies own their metadata")
	return true


func run_metadata_forwards_live_owner_state() -> bool:
	var state: RunState = RunState.new(98765)
	expect_equal(state.original_seed, 98765, "Original seed is explicit")
	state.rng.select_index(20)
	expect_equal(state.current_rng_state, state.rng.current_state, "No stale RNG snapshot in RunState")
	state.id_allocator.allocate()
	expect_equal(state.next_runtime_id, 2, "No stale allocator cursor in RunState")
	return true


func validates_empty_seeded_foundation() -> bool:
	expect_true(InvariantValidator.validate(RunState.new(0), Factory.content()).is_valid, "Empty SETUP is valid")
	return true


func validates_archived_physical_copies() -> bool:
	expect_true(InvariantValidator.assert_valid(Factory.representative(), Factory.content()), "Representative state is valid")
	return true


func rejects_missing_state_and_content() -> bool:
	expect_true(not InvariantValidator.validate(null, Factory.content()).is_valid, "Null state rejected")
	expect_true(not InvariantValidator.validate(RunState.new(1), null).is_valid, "Null content rejected")
	expect_true(not InvariantValidator.validate(RunState.new(1), ContentRegistry.new()).is_valid, "Unloaded registry rejected")
	return true


func rejects_missing_continuation_owners() -> bool:
	var state: RunState = RunState.new(1)
	state.rng = null
	state.id_allocator = null
	var report: InvariantReport = InvariantValidator.validate(state, Factory.content())
	expect_equal(report.issues.size(), 2, "Missing owners reported without dereferencing null")
	return true


func rejects_duplicate_and_nonpositive_ids() -> bool:
	var state: RunState = Factory.representative()
	state.tile_copies[1].tile_copy_id = state.tile_copies[0].tile_copy_id
	expect_true(not InvariantValidator.validate(state, Factory.content()).is_valid, "Duplicate entity ID rejected")
	state.tile_copies[0].tile_copy_id = 0
	expect_true(not InvariantValidator.validate(state, Factory.content()).is_valid, "Nonpositive entity ID rejected")
	return true


func rejects_next_id_collision() -> bool:
	var state: RunState = Factory.representative()
	state.id_allocator = RunIdAllocator.new(state.tile_copies[2].tile_copy_id)
	expect_true(not InvariantValidator.validate(state, Factory.content()).is_valid, "Cursor must exceed maximum used ID")
	return true


func rejects_unknown_static_reference() -> bool:
	var state: RunState = Factory.representative()
	state.tile_copies[0].definition_id = &"tile.not_registered"
	expect_true(not InvariantValidator.validate(state, Factory.content()).is_valid, "Every static ID resolves")
	return true


func rejects_missing_or_duplicate_locations() -> bool:
	var state: RunState = Factory.representative()
	state.tile_locations.remove_at(0)
	expect_true(not InvariantValidator.validate(state, Factory.content()).is_valid, "Unlocated copy rejected")
	state = Factory.representative()
	state.tile_locations.append(TileLocationState.new(state.tile_copies[0].tile_copy_id))
	expect_true(not InvariantValidator.validate(state, Factory.content()).is_valid, "Duplicate location rejected")
	return true


func rejects_dangling_location_reference() -> bool:
	var state: RunState = Factory.representative()
	state.tile_locations.append(TileLocationState.new(777))
	expect_true(not InvariantValidator.validate(state, Factory.content()).is_valid, "No object reference substitutes for absent ID")
	return true


func rejects_unknown_or_unimplemented_location_kind() -> bool:
	var state: RunState = Factory.representative()
	state.tile_locations[0].kind = 99 as TileLocationState.Kind
	expect_true(not InvariantValidator.validate(state, Factory.content()).is_valid, "Out-of-enum location rejected")
	state.tile_locations[0].kind = TileLocationState.Kind.BAG
	expect_true(not InvariantValidator.validate(state, Factory.content()).is_valid, "No fake bag container in Phase 1")
	return true


func rejects_invalid_acquisition_metadata() -> bool:
	var state: RunState = Factory.representative()
	state.tile_copies[0].acquired_act = 4
	state.tile_copies[1].acquisition_source = &" "
	var report: InvariantReport = InvariantValidator.validate(state, Factory.content())
	expect_equal(report.issues.size(), 2, "Invalid acquisition Act/source rejected")
	return true


func rejects_incompatible_metadata_and_future_phase() -> bool:
	var state: RunState = RunState.new(1)
	state.save_schema_version = 99
	state.godot_version = "unverified_engine"
	state.phase = GamePhase.Type.PENDING_CHOICE
	var report: InvariantReport = InvariantValidator.validate(state, Factory.content())
	expect_equal(report.issues.size(), 3, "Version and unsupported phase diagnostics")
	return true


func rejects_null_registry_records() -> bool:
	var state: RunState = RunState.new(1)
	state.tile_copies.append(null)
	state.tile_locations.append(null)
	expect_equal(InvariantValidator.validate(state, Factory.content()).issues.size(), 2, "No null records")
	return true


func diagnostics_identify_corrupt_entity() -> bool:
	var state: RunState = Factory.representative()
	state.tile_locations.append(TileLocationState.new(888))
	var report: InvariantReport = InvariantValidator.validate(state, Factory.content())
	expect_equal(report.issues[0].code, &"unresolved_location", "Machine-readable corruption code")
	expect_equal(report.issues[0].runtime_id, 888, "Stable runtime ID in diagnostic")
	expect_true(report.describe().contains("888"), "Readable diagnostic identifies entity")
	return true
