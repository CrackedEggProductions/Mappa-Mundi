extends "res://tests/framework/test_suite.gd"

const Fixture = preload("res://tests/fixtures/phase_five_factory.gd")


func tests() -> Array[Callable]:
	return [all_designs_round_trip, repeated_load_is_inert, upgrade_replacement_round_trip,
		port_association_round_trip, completed_enclosure_round_trip, deterministic_continuation,
		malformed_overlay_shapes_rejected, corrupted_overlay_identity_rejected,
		corrupted_host_associations_rejected, corrupted_physical_zones_rejected,
		corrupted_replacement_history_rejected, corrupted_enclosure_stage_rejected,
		corrupted_development_track_total_rejected, overlay_facts_change_fingerprint,
		completion_family_sets_normalize, completion_facts_round_trip,
		corrupt_completion_host_is_rejected_without_reconstruction]


func corrupt_completion_host_is_rejected_without_reconstruction() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _housing(registry)
	var data: Dictionary = RunSerializer.to_envelope(state)
	data["run_state"]["features"]["completions"][0]["lineage_id"] = "9223372036854770000"
	_reject(data, registry, "Broken historical host returns structured rejection, never dereferences a missing lineage")
	return true


func _save_load(state: RunState, registry: ContentRegistry) -> RunState:
	var saved: SerializationResult = RunSerializer.serialize(state, registry)
	expect_true(saved.validation.is_valid, "Save invariants: " + str(saved.validation.debug_details))
	if not saved.validation.is_valid:
		return null
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, registry)
	expect_true(loaded.validation.is_valid, "Load invariants: " + str(loaded.validation.debug_details))
	return loaded.state


func _housing(registry: ContentRegistry) -> RunState:
	var state: RunState = Fixture.create(registry)
	Fixture.complete_settlement(state, registry)
	Fixture.play(state, registry, &"tile.development.housing", Vector2i.ZERO)
	return state


func _upgrade(registry: ContentRegistry) -> RunState:
	var state: RunState = Fixture.create(registry, 3)
	Fixture.complete_settlement(state, registry)
	Fixture.play(state, registry, &"tile.development.market", Vector2i.ZERO)
	Fixture.play(state, registry, &"tile.development.grand_market", Vector2i.ZERO)
	return state


func _enclosure(registry: ContentRegistry, upgrade: bool = false) -> RunState:
	var state: RunState = Fixture.create(registry, 2)
	var center: Vector2i = Fixture.fields(state, registry, 8)
	Fixture.play(state, registry, &"tile.development.monastery", center)
	if upgrade:
		Fixture.play(state, registry, &"tile.development.abbey", center)
	return state


func all_designs_round_trip() -> bool:
	var registry: ContentRegistry = Fixture.content()
	for stage: String in ["housing", "market", "town_square", "mill", "monastery", "foresters_lodge", "port", "abbey", "grand_market"]:
		var state: RunState = Fixture.create(registry, 3)
		var at: Vector2i = Vector2i.ZERO
		if stage in ["monastery", "abbey", "mill"]:
			at = Fixture.fields(state, registry, 8)
		if stage == "port":
			Fixture.ports(state, registry)
			at = Vector2i.DOWN
		if stage == "abbey":
			Fixture.play(state, registry, &"tile.development.monastery", at)
		elif stage == "grand_market":
			Fixture.play(state, registry, &"tile.development.market", at)
		Fixture.play(state, registry, StringName("tile.development." + stage), at)
		var loaded: RunState = _save_load(state, registry)
		if loaded != null:
			expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), stage + " retains authoritative identity, hosts and history")
	return true


func repeated_load_is_inert() -> bool:
	var registry: ContentRegistry = Fixture.content()
	for initial: RunState in [_housing(registry), _upgrade(registry), _enclosure(registry), _enclosure(registry, true)]:
		var state: RunState = initial
		var fingerprint: String = StateNormalizer.fingerprint(state)
		var facts: Array = [state.next_runtime_id, state.current_rng_state, state.rng.operation_count,
			state.features.history.size(), state.features.completions.size(), state.features.tracks.values.duplicate()]
		for iteration: int in range(3):
			state = _save_load(state, registry)
			if state == null:
				return true
			expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Repeated load does not trigger completed-host effects")
			expect_equal([state.next_runtime_id, state.current_rng_state, state.rng.operation_count,
				state.features.history.size(), state.features.completions.size(), state.features.tracks.values], facts,
				"Zero allocations, RNG operations, events, completions or Track gains")
	return true


func upgrade_replacement_round_trip() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _upgrade(registry)
	var loaded: RunState = _save_load(state, registry)
	if loaded != null:
		var overlay: DevelopmentState = Fixture.development(loaded, Vector2i.ZERO)
		expect_equal(Fixture.location(loaded, overlay.replaced_copy_id), TileLocationState.Kind.REMOVED_FROM_RUN, "Old Market remains permanently removed")
		expect_equal(Fixture.location(loaded, overlay.tile_copy_id), TileLocationState.Kind.BOARD_DEVELOPMENT, "Grand Market remains physical board overlay")
		expect_equal(StateNormalizer.normalize(loaded), StateNormalizer.normalize(state), "Replacement audit survives exactly")
	return true


func port_association_round_trip() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 2)
	Fixture.ports(state, registry)
	Fixture.play(state, registry, &"tile.development.port", Vector2i.DOWN)
	var loaded: RunState = _save_load(state, registry)
	if loaded != null:
		expect_equal(Fixture.development(loaded, Vector2i.DOWN).river_lineage_id, Fixture.development(state, Vector2i.DOWN).river_lineage_id, "Specific Port River survives loading")
	return true


func completed_enclosure_round_trip() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _enclosure(registry, true)
	var loaded: RunState = _save_load(state, registry)
	if loaded != null:
		expect_equal(loaded.features.enclosures[0].completed_stages, [&"monastery", &"abbey"], "Both stage histories persist")
		expect_equal(loaded.features.tracks.values, state.features.tracks.values, "Completed Abbey does not score again")
	return true


func deterministic_continuation() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _housing(registry)
	Fixture.acquire_hand(state, &"tile.development.housing")
	var loaded: RunState = _save_load(state, registry)
	if loaded == null:
		return true
	var original_options: Array[PlacementOption] = Fixture.options(state, registry, state.expansion.hand[0])
	var loaded_options: Array[PlacementOption] = Fixture.options(loaded, registry, loaded.expansion.hand[0])
	expect_equal(original_options.size(), loaded_options.size(), "Same legal Development choices after load")
	for index: int in range(original_options.size()):
		expect_equal(original_options[index].signature, loaded_options[index].signature, "Placement intents retain exact signatures")
	expect_true(not original_options.is_empty(), "Continuation has a legal physical Development")
	if original_options.is_empty():
		return true
	expect_true(RulesEngine.execute(state, registry, Fixture.command(original_options[0])).is_valid, "Original continuation succeeds")
	expect_true(RulesEngine.execute(loaded, registry, Fixture.command(loaded_options[0])).is_valid, "Loaded continuation succeeds")
	expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Effects, draws, IDs, topology and RNG continue identically")
	return true


func _overlay(data: Dictionary) -> Dictionary:
	for cell: Dictionary in data["run_state"]["expansion"]["board"]["cells"]:
		if not cell["developments"].is_empty():
			return cell["developments"][0]
	return {}


func _reject(data: Dictionary, registry: ContentRegistry, reason: String) -> void:
	var loaded: DeserializationResult = RunSerializer.deserialize(JSON.stringify(data), registry)
	expect_true(not loaded.validation.is_valid and loaded.state == null, "Malformed Development save rejected: " + reason)


func malformed_overlay_shapes_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _housing(registry)
	for value: Variant in [null, {}, "overlay", [null], [{"tile_copy_id": 1}]]:
		var data: Dictionary = RunSerializer.to_envelope(state)
		data["run_state"]["expansion"]["board"]["cells"][0]["developments"] = value
		_reject(data, registry, "overlay array shape")
	return true


func corrupted_overlay_identity_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _housing(registry)
	for pair: Array in [["family_id", "family.market"], ["stage", "abbey"], ["tile_copy_id", "0"], ["act_placed", 3], ["placement_index", "0"]]:
		var data: Dictionary = RunSerializer.to_envelope(state)
		_overlay(data)[pair[0]] = pair[1]
		_reject(data, registry, pair[0])
	return true


func corrupted_host_associations_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _housing(registry)
	for pair: Array in [["host_lineage_id", "0"], ["host_kind", "field"], ["river_lineage_id", "1"], ["enclosure_id", "1"]]:
		var data: Dictionary = RunSerializer.to_envelope(state)
		_overlay(data)[pair[0]] = pair[1]
		_reject(data, registry, pair[0])
	return true


func corrupted_physical_zones_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _housing(registry)
	var data: Dictionary = RunSerializer.to_envelope(state)
	data["run_state"]["expansion"]["bag"].append(_overlay(data)["tile_copy_id"])
	_reject(data, registry, "physical copy in both bag and overlay")
	data = RunSerializer.to_envelope(state)
	for cell: Dictionary in data["run_state"]["expansion"]["board"]["cells"]:
		if not cell["developments"].is_empty():
			cell["developments"].append(cell["developments"][0].duplicate(true))
	_reject(data, registry, "duplicate occupied slot")
	return true


func corrupted_replacement_history_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _upgrade(registry)
	var data: Dictionary = RunSerializer.to_envelope(state)
	_overlay(data)["replaced_copy_id"] = "0"
	_reject(data, registry, "missing replaced identity")
	data = RunSerializer.to_envelope(state)
	for event: Dictionary in data["run_state"]["features"]["history"]:
		if event["kind"] == "development_replaced":
			event["parent_ids"] = []
	_reject(data, registry, "missing reciprocal replacement audit")
	return true


func corrupted_enclosure_stage_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _enclosure(registry, true)
	for pair: Array in [["stage", "monastery"], ["development_tile_copy_id", "0"], ["completed_stages", ["abbey"]]]:
		var data: Dictionary = RunSerializer.to_envelope(state)
		data["run_state"]["features"]["enclosures"][0][pair[0]] = pair[1]
		_reject(data, registry, "enclosure " + pair[0])
	return true


func corrupted_development_track_total_rejected() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _housing(registry)
	var data: Dictionary = RunSerializer.to_envelope(state)
	data["run_state"]["features"]["tracks"][0] = "0"
	_reject(data, registry, "omitted Development gains")
	return true


func overlay_facts_change_fingerprint() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = _upgrade(registry)
	var original: String = StateNormalizer.fingerprint(state)
	var overlay: DevelopmentState = Fixture.development(state, Vector2i.ZERO)
	for key: String in ["tile_copy_id", "host_lineage_id", "river_lineage_id", "replaced_copy_id", "enclosure_id", "placement_index"]:
		var before: int = overlay.get(key)
		overlay.set(key, before + 1)
		expect_true(StateNormalizer.fingerprint(state) != original, key + " changes authoritative fingerprint")
		overlay.set(key, before)
	return true


func completion_family_sets_normalize() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry, 2)
	Fixture.play(state, registry, &"tile.development.housing", Vector2i.ZERO)
	Fixture.complete_settlement(state, registry)
	var original: String = StateNormalizer.fingerprint(state)
	for record: FeatureCompletionRecord in state.features.completions:
		record.development_families.reverse()
	expect_equal(StateNormalizer.fingerprint(state), original, "Historical family sets normalize without modifying authoritative order")
	return true


func completion_facts_round_trip() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(registry)
	Fixture.play(state, registry, &"tile.development.housing", Vector2i.ZERO)
	Fixture.complete_settlement(state, registry)
	var loaded: RunState = _save_load(state, registry)
	if loaded != null:
		expect_equal(StateNormalizer.normalize(loaded), StateNormalizer.normalize(state), "Frozen families and base/Development scoring history survive exactly")
	return true
