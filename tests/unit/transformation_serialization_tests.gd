extends "res://tests/framework/test_suite.gd"

const Fixture = preload("res://tests/fixtures/phase_six_factory.gd")


func tests() -> Array[Callable]:
	return [all_modes_round_trip, repeated_loading_is_inert, physical_zones_round_trip,
		stacked_history_round_trip, transformation_continuation, malformed_history_rejected,
		corrupted_identity_rejected, corrupted_change_rejected, corrupted_provenance_rejected,
		corrupted_field_rejected, corrupted_audit_rejected, transformation_sets_normalize,
		transformation_facts_change_fingerprint]


func _state(registry: ContentRegistry, mode: StringName) -> RunState:
	var state: RunState = Fixture.river(registry)
	match mode:
		&"bridge": Fixture.play(state, registry, Fixture.BRIDGE, Vector2i.DOWN, mode)
		&"rewilding": Fixture.play(state, registry, Fixture.REWILD, Vector2i.DOWN, mode, 1)
		_:
			var id: StringName = Fixture.URBAN if mode == &"urban_expansion" else Fixture.REWILD
			var copy_id: int = Fixture.Previous.acquire_hand(state, id)
			for option: PlacementOption in PlacementQueryService.query_for_copy(state, registry, copy_id):
				if option.transformation_mode == mode:
					expect_true(RulesEngine.execute(state, registry, Fixture.command(option)).is_valid, "Specialized Expansion fixture plays")
					return state
			expect_true(false, "Specialized Expansion fixture has a legal option")
	return state


func _load(state: RunState, registry: ContentRegistry) -> RunState:
	var saved: SerializationResult = RunSerializer.serialize(state, registry)
	expect_true(saved.validation.is_valid, "Serialization invariants: " + str(saved.validation.debug_details))
	if not saved.validation.is_valid:
		return null
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, registry)
	expect_true(loaded.validation.is_valid, "Deserialization invariants: " + str(loaded.validation.debug_details))
	return loaded.state


func all_modes_round_trip() -> bool:
	var registry: ContentRegistry = Fixture.content()
	for mode: StringName in [&"urban_expansion", &"rewilding_expansion", &"bridge", &"rewilding"]:
		var state: RunState = _state(registry, mode)
		var loaded: RunState = _load(state, registry)
		if loaded != null:
			expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "%s preserves complete authoritative state" % mode)
	return true


func repeated_loading_is_inert() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _state(registry, &"bridge")
	var original: String = StateNormalizer.fingerprint(state)
	var facts: Array = [state.next_runtime_id, state.current_rng_state, state.rng.operation_count,
		state.features.history.size(), state.features.completions.size(), state.features.tracks.values.duplicate()]
	for index: int in range(4):
		state = _load(state, registry)
		if state == null:
			return true
		expect_equal(StateNormalizer.fingerprint(state), original, "Repeated reconstruction does not apply Transformations again")
		expect_equal([state.next_runtime_id, state.current_rng_state, state.rng.operation_count,
			state.features.history.size(), state.features.completions.size(), state.features.tracks.values], facts,
			"Loading causes zero allocations, RNG operations, events, completions or scoring")
	return true


func physical_zones_round_trip() -> bool:
	var registry: ContentRegistry = Fixture.content()
	for mode: StringName in [&"urban_expansion", &"rewilding_expansion", &"bridge", &"rewilding"]:
		var state: RunState = _load(_state(registry, mode), registry)
		if state == null:
			continue
		for cell: BoardCellState in state.expansion.board.cells.values():
			for value: TransformationState in cell.transformations:
				var expected: int = TileLocationState.Kind.BOARD_BASE if mode in [&"urban_expansion", &"rewilding_expansion"] else TileLocationState.Kind.BOARD_TRANSFORMATION
				expect_equal(Fixture.Previous.location(state, value.tile_copy_id), expected, "Physical location reflects the actual placement mode")
	return true


func stacked_history_round_trip() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _state(registry, &"rewilding_expansion")
	var target: Vector2i = _transformation_coordinate(state)
	Fixture.play(state, registry, Fixture.REWILD, target, &"rewilding")
	var loaded: RunState = _load(state, registry)
	if loaded != null:
		expect_equal(loaded.expansion.board.get_cell(target).transformations.size(), 2, "Both physical copies persist on the same square")
		expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Stacked before/after history round-trips")
	return true


func transformation_continuation() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _state(registry, &"rewilding_expansion")
	var copy_id: int = Fixture.Previous.acquire_hand(state, Fixture.REWILD)
	var loaded: RunState = _load(state, registry)
	if loaded == null:
		return true
	var original: Array[PlacementOption] = PlacementQueryService.query_for_copy(state, registry, copy_id)
	var restored: Array[PlacementOption] = PlacementQueryService.query_for_copy(loaded, registry, copy_id)
	expect_equal(original.size(), restored.size(), "Transformation choices reconstruct identically")
	for index: int in range(original.size()):
		expect_equal(original[index].signature, restored[index].signature, "Exact geometry intent survives loading")
	expect_true(not original.is_empty(), "Rewilding continuation has a valid target")
	if not original.is_empty():
		expect_true(RulesEngine.execute(state, registry, Fixture.command(original[0])).is_valid, "Original continuation plays")
		expect_true(RulesEngine.execute(loaded, registry, Fixture.command(restored[0])).is_valid, "Loaded continuation plays")
		expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Future components, topology, histories, draws and RNG match")
	return true


func _encoded(data: Dictionary) -> Dictionary:
	for cell: Dictionary in data["run_state"]["expansion"]["board"]["cells"]:
		if not cell["transformations"].is_empty():
			return cell["transformations"][0]
	return {}


func _reject(data: Dictionary, registry: ContentRegistry, reason: String) -> void:
	var result: DeserializationResult = RunSerializer.deserialize(JSON.stringify(data), registry)
	expect_true(not result.validation.is_valid and result.state == null, "Corrupt save rejected: " + reason)


func malformed_history_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _state(registry, &"bridge")
	for value: Variant in [null, {}, "change", [null], [{"coordinate": [0, 1]}]]:
		var data: Dictionary = RunSerializer.to_envelope(state)
		_encoded(data)["changes"] = value
		_reject(data, registry, "malformed geometry history")
	return true


func corrupted_identity_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _state(registry, &"bridge")
	for pair: Array in [["tile_copy_id", "0"], ["target_base_copy_id", "0"], ["act_applied", 1],
		["definition_id", "tile.open_fields"], ["mode", "rewilding"], ["placement_index", "0"], ["orientation", 3]]:
		var data: Dictionary = RunSerializer.to_envelope(state)
		_encoded(data)[pair[0]] = pair[1]
		_reject(data, registry, pair[0])
	return true


func corrupted_change_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _state(registry, &"bridge")
	for pair: Array in [["before_edges", []], ["after_edges", [0, 0, 0, 0]],
		["coordinate", [200, 200]], ["target_lineage_ids", ["1"]]]:
		var data: Dictionary = RunSerializer.to_envelope(state)
		_encoded(data)["changes"][0][pair[0]] = pair[1]
		_reject(data, registry, pair[0])
	return true


func corrupted_provenance_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _state(registry, &"bridge")
	var data: Dictionary = RunSerializer.to_envelope(state)
	_encoded(data)["changes"][0]["created_component_ids"] = []
	_reject(data, registry, "created components omitted")
	data = RunSerializer.to_envelope(state)
	for component: Dictionary in data["run_state"]["features"]["components"]:
		if component["origin_source_type"] == "transformation":
			component["origin_act"] = 1
	_reject(data, registry, "new component backdated")
	return true


func corrupted_field_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _state(registry, &"bridge")
	var data: Dictionary = RunSerializer.to_envelope(state)
	_encoded(data)["changes"][0]["field_after"] = false
	_reject(data, registry, "Bridge consumes Field in history")
	data = RunSerializer.to_envelope(state)
	for cell: Dictionary in data["run_state"]["expansion"]["board"]["cells"]:
		if not cell["transformations"].is_empty():
			cell["has_field_geography"] = false
	_reject(data, registry, "current Field differs from recorded history")
	return true


func corrupted_audit_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _state(registry, &"bridge")
	var data: Dictionary = RunSerializer.to_envelope(state)
	for event: Dictionary in data["run_state"]["features"]["history"]:
		if event["kind"] == "transformation_applied":
			event["component_ids"] = []
	_reject(data, registry, "application audit disagrees with geometry history")
	return true


func transformation_sets_normalize() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _state(registry, &"rewilding_expansion")
	var target: Vector2i = _transformation_coordinate(state)
	Fixture.play(state, registry, Fixture.REWILD, target, &"rewilding")
	var before: String = StateNormalizer.fingerprint(state)
	var cell: BoardCellState = state.expansion.board.get_cell(target)
	cell.transformations.reverse()
	for value: TransformationState in cell.transformations:
		value.changes.reverse()
		for change: TransformationChange in value.changes:
			change.target_lineage_ids.reverse()
			change.created_component_ids.reverse()
	expect_equal(StateNormalizer.fingerprint(state), before, "Physical registries and provenance sets normalize deterministically")
	expect_true(InvariantValidator.validate(state, registry).is_valid, "Chronology comes from placement indices, not container order")
	return true


func transformation_facts_change_fingerprint() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _state(registry, &"bridge")
	var value: TransformationState = state.expansion.board.get_cell(Vector2i.DOWN).transformations[0]
	var before: String = StateNormalizer.fingerprint(state)
	for key: String in ["tile_copy_id", "target_base_copy_id", "placement_index", "act_applied", "orientation"]:
		var saved: int = value.get(key)
		value.set(key, saved + 1)
		expect_true(StateNormalizer.fingerprint(state) != before, key + " is authoritative fingerprint data")
		value.set(key, saved)
	value.changes[0].field_after = not value.changes[0].field_after
	expect_true(StateNormalizer.fingerprint(state) != before, "Interior geography is authoritative fingerprint data")
	return true


func _transformation_coordinate(state: RunState) -> Vector2i:
	for coordinate: Vector2i in state.expansion.board.sorted_coordinates():
		if not state.expansion.board.get_cell(coordinate).transformations.is_empty():
			return coordinate
	return Vector2i.ZERO
