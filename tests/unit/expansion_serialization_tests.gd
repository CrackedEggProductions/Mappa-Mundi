extends "res://tests/framework/test_suite.gd"


func tests() -> Array[Callable]:
	return [
		expansion_round_trip_preserves_all_zones_and_geometry,
		loaded_expansion_uses_fresh_objects,
		load_has_no_rng_or_gameplay_effects,
		continued_rng_and_ids_match,
		normalization_ignores_sparse_insertion_and_metadata_order,
		authoritative_zone_order_changes_fingerprint,
		rejects_duplicate_serialized_coordinates,
		rejects_malformed_expansion_fields,
		rejects_invalid_coordinate_encodings,
		rejects_invalid_geometry_encodings,
		rejects_zone_duplicates_and_location_mismatch,
		rejects_corrupt_founding_and_internal_metadata,
		rejects_invalid_counters_and_missing_physical_references,
		rejects_disconnected_board_and_illegal_founding_copies,
		rejects_rewound_state_revision,
		full_width_revision_round_trips,
	]


func expansion_round_trip_preserves_all_zones_and_geometry() -> bool:
	var content: ContentRegistry = _content()
	var original: RunState = _representative(content)
	var saved: SerializationResult = RunSerializer.serialize(original, content)
	expect_true(saved.validation.is_valid, saved.validation.user_message)
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	expect_true(loaded.validation.is_valid, loaded.validation.user_message)
	if loaded.state != null:
		expect_equal(loaded.state.expansion.bag, original.expansion.bag, "Exact next-draw order")
		expect_equal(loaded.state.expansion.hand, original.expansion.hand, "Exact hand slots")
		expect_equal(loaded.state.expansion.reserve_id, original.expansion.reserve_id, "Reserved physical identity")
		expect_equal(loaded.state.expansion.removed_ids, original.expansion.removed_ids, "Survey removal retained")
		expect_equal(ExpansionSerializer.encode(loaded.state.expansion), ExpansionSerializer.encode(original.expansion), "All explicit spatial metadata")
		expect_equal(StateNormalizer.fingerprint(loaded.state), StateNormalizer.fingerprint(original), "Round-trip fingerprint")
		expect_true(InvariantValidator.validate(loaded.state, content).is_valid, "Loaded invariants")
	return true


func loaded_expansion_uses_fresh_objects() -> bool:
	var content: ContentRegistry = _content()
	var original: RunState = _representative(content)
	var loaded: RunState = _round_trip(original, content)
	if loaded == null:
		return true
	expect_true(loaded.expansion != original.expansion, "Fresh expansion owner")
	expect_true(loaded.expansion.board != original.expansion.board, "Fresh sparse board")
	var first: BoardCellState = original.expansion.board.cells[Vector2i.ZERO]
	var second: BoardCellState = loaded.expansion.board.cells[Vector2i.ZERO]
	expect_true(first != second, "Fresh runtime cell")
	expect_true(first.feature_groups[0] != second.feature_groups[0], "Fresh internal group")
	expect_true(first.relationships[0] != second.relationships[0], "Fresh explicit relationship")
	var before: String = StateNormalizer.fingerprint(original)
	loaded.expansion.bag.reverse()
	second.feature_groups[0].directions.clear()
	expect_equal(StateNormalizer.fingerprint(original), before, "Loaded mutation cannot leak to original")
	return true


func load_has_no_rng_or_gameplay_effects() -> bool:
	var content: ContentRegistry = _content()
	var original: RunState = _representative(content)
	var loaded: RunState = _round_trip(original, content)
	if loaded != null:
		expect_equal(loaded.rng.operation_count, original.rng.operation_count, "Loading consumed no RNG operation")
		expect_equal(loaded.expansion.normal_placements, 3, "No placement on load")
		expect_equal(loaded.expansion.survey_charges, 0, "No new grant on load")
		expect_equal(loaded.expansion.state_revision, original.expansion.state_revision, "No command resolution on load")
	return true


func continued_rng_and_ids_match() -> bool:
	var content: ContentRegistry = _content()
	var original: RunState = _representative(content)
	var loaded: RunState = _round_trip(original, content)
	if loaded != null:
		for index: int in range(12):
			expect_equal(loaded.rng.integer_range(-500, 500), original.rng.integer_range(-500, 500), "Exact continued RNG draw %d" % index)
			expect_equal(loaded.id_allocator.allocate(), original.id_allocator.allocate(), "Exact future ID %d" % index)
		expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(original), "Continued states remain identical")
	return true


func normalization_ignores_sparse_insertion_and_metadata_order() -> bool:
	var content: ContentRegistry = _content()
	var original: RunState = _representative(content)
	var loaded: RunState = _round_trip(original, content)
	if loaded == null:
		return true
	var reordered: Dictionary[Vector2i, BoardCellState] = {}
	var coordinates: Array[Vector2i] = loaded.expansion.board.sorted_coordinates()
	coordinates.reverse()
	for coordinate: Vector2i in coordinates:
		var cell: BoardCellState = loaded.expansion.board.cells[coordinate]
		cell.feature_groups.reverse()
		cell.relationships.reverse()
		for group: TileFeatureGroup in cell.feature_groups:
			group.directions.reverse()
		reordered[coordinate] = cell
	loaded.expansion.board.cells = reordered
	loaded.tile_copies.reverse()
	loaded.tile_locations.reverse()
	expect_true(InvariantValidator.validate(loaded, content).is_valid, "Incidental reordering stays invariant-valid")
	expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(original), "Sparse and metadata insertion order excluded")
	return true


func authoritative_zone_order_changes_fingerprint() -> bool:
	var state: RunState = _representative(_content())
	var before: String = StateNormalizer.fingerprint(state)
	state.expansion.bag.reverse()
	expect_true(StateNormalizer.fingerprint(state) != before, "Bag order is authoritative")
	before = StateNormalizer.fingerprint(state)
	state.expansion.hand.reverse()
	expect_true(StateNormalizer.fingerprint(state) != before, "Hand slot order is authoritative")
	return true


func rejects_duplicate_serialized_coordinates() -> bool:
	var envelope: Dictionary = _envelope()
	envelope["run_state"]["expansion"]["board"]["cells"].append(
		envelope["run_state"]["expansion"]["board"]["cells"][0].duplicate(true))
	_expect_rejected(envelope, "Duplicate coordinates cannot silently overwrite")
	return true


func rejects_malformed_expansion_fields() -> bool:
	var envelope: Dictionary = _envelope()
	envelope["run_state"]["expansion"].erase("survey_charges")
	_expect_rejected(envelope, "Missing authoritative field")
	envelope = _envelope()
	envelope["run_state"]["expansion"]["future_topology"] = {}
	_expect_rejected(envelope, "Unknown state cannot silently disappear")
	for value: Variant in [null, {}, [1], ["01"], ["-1"], ["0"]]:
		envelope = _envelope()
		envelope["run_state"]["expansion"]["bag"] = value
		_expect_rejected(envelope, "Malformed ordered ID array")
	return true


func rejects_invalid_coordinate_encodings() -> bool:
	for value: Variant in [null, {}, [0], [0, 0, 0], [true, 0], [0.5, 0], ["0", 0], [2147483648, 0]]:
		var envelope: Dictionary = _envelope()
		envelope["run_state"]["expansion"]["board"]["cells"][0]["coordinate"] = value
		_expect_rejected(envelope, "Malformed or lossy coordinate encoding")
	return true


func rejects_invalid_geometry_encodings() -> bool:
	for value: Variant in [null, [0, 0, 0], [0, 0, 0, 5], [true, 0, 0, 0]]:
		var envelope: Dictionary = _envelope()
		envelope["run_state"]["expansion"]["board"]["cells"][0]["effective_edges"] = value
		_expect_rejected(envelope, "Malformed effective edges")
	var envelope: Dictionary = _envelope()
	envelope["run_state"]["expansion"]["board"]["cells"][0]["rotation"] = 4
	_expect_rejected(envelope, "Noncanonical rotation")
	envelope = _envelope()
	_founding(envelope)["feature_groups"][0]["directions"] = [4]
	_expect_rejected(envelope, "Invalid internal direction")
	return true


func rejects_zone_duplicates_and_location_mismatch() -> bool:
	var envelope: Dictionary = _envelope()
	var expansion: Dictionary = envelope["run_state"]["expansion"]
	expansion["bag"].append(expansion["hand"][0])
	_expect_rejected(envelope, "Same physical copy in bag and hand", &"invalid_saved_state")
	envelope = _envelope()
	envelope["run_state"]["tile_locations"][0]["kind"] = TileLocationState.Kind.BAG
	_expect_rejected(envelope, "Board location disagrees with physical location", &"invalid_saved_state")
	envelope = _envelope()
	expansion = envelope["run_state"]["expansion"]
	expansion["reserve_id"] = expansion["hand"][0]
	_expect_rejected(envelope, "Reserve cannot duplicate hand identity", &"invalid_saved_state")
	return true


func rejects_corrupt_founding_and_internal_metadata() -> bool:
	var envelope: Dictionary = _envelope()
	_founding(envelope)["rotation"] = 1
	_expect_rejected(envelope, "Founding cannot rotate", &"invalid_saved_state")
	envelope = _envelope()
	_founding(envelope)["relationships"] = []
	_expect_rejected(envelope, "Founding access cannot disappear", &"invalid_saved_state")
	envelope = _envelope()
	_founding(envelope)["feature_groups"] = []
	_expect_rejected(envelope, "Feature stubs must survive", &"invalid_saved_state")
	return true


func rejects_invalid_counters_and_missing_physical_references() -> bool:
	for field: String in ["normal_placements", "survey_charges", "pending_refill_index"]:
		var envelope: Dictionary = _envelope()
		envelope["run_state"]["expansion"][field] = 999
		_expect_rejected(envelope, "Inconsistent %s" % field, &"invalid_saved_state")
	var envelope: Dictionary = _envelope()
	_founding(envelope)["base_tile_copy_id"] = "9999"
	_expect_rejected(envelope, "Unresolved board base", &"invalid_saved_state")
	return true


func rejects_disconnected_board_and_illegal_founding_copies() -> bool:
	var envelope: Dictionary = _envelope()
	for cell: Dictionary in envelope["run_state"]["expansion"]["board"]["cells"]:
		if cell["normal_placement_index"] == 3:
			cell["coordinate"] = [-1000000, 1000000]
	_expect_rejected(envelope, "Disconnected last placement cannot be a legal history", &"invalid_saved_state")
	envelope = _envelope()
	envelope["run_state"]["tile_copies"][1]["definition_id"] = "tile.founding.homestead"
	_expect_rejected(envelope, "Founding cannot be a bag or reward copy", &"invalid_saved_state")
	envelope = _envelope()
	envelope["run_state"]["tile_copies"][1]["acquired_act"] = 2
	_expect_rejected(envelope, "Act-I run cannot acquire an Act-II copy", &"invalid_saved_state")
	return true


func full_width_revision_round_trips() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _representative(content)
	state.expansion.state_revision = 9007199254740993
	var loaded: RunState = _round_trip(state, content)
	if loaded != null:
		expect_equal(loaded.expansion.state_revision, 9007199254740993, "64-bit state revision never passes through JSON float")
	return true


func rejects_rewound_state_revision() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _representative(content)
	state.expansion.state_revision = state.expansion.normal_placements - 1
	expect_true(not InvariantValidator.validate(state, content).is_valid, "Direct state revision cannot precede committed placements")
	var envelope: Dictionary = RunSerializer.to_envelope(state)
	_expect_rejected(envelope, "Loaded state revision cannot rewind placements", &"invalid_saved_state")
	return true


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = content.load_homestead()
	expect_true(result.is_valid, result.user_message)
	return content


func _representative(content: ContentRegistry) -> RunState:
	var state: RunState = HomesteadRunFactory.create(28463, content)
	expect_true(RulesEngine.execute(state, content, ReserveTileCommand.new(state.expansion.hand[0])).is_valid, "Fixture Reserve")
	expect_true(RulesEngine.execute(state, content, SurveyTileCommand.new(state.expansion.hand[1])).is_valid, "Fixture Survey")
	for index: int in range(3):
		var placed: bool = false
		for tile_id: int in state.expansion.hand:
			var definition: TileDefinition = content.get_tile(PhysicalTileRules.find_copy(state, tile_id).definition_id)
			var options: Array[PlacementOption] = PlacementQueryService.query(state.expansion.board, definition, tile_id)
			if options.is_empty():
				continue
			var option: PlacementOption = options[0]
			var result: ValidationResult = RulesEngine.execute(state, content,
				PlaceTileCommand.new(tile_id, TileLocationState.Kind.ACTIVE_HAND, option.coordinate, option.rotation))
			expect_true(result.is_valid, result.user_message)
			placed = result.is_valid
			break
		expect_true(placed, "Fixture normal placement %d" % index)
	return state


func _round_trip(state: RunState, content: ContentRegistry) -> RunState:
	var saved: SerializationResult = RunSerializer.serialize(state, content)
	expect_true(saved.validation.is_valid, saved.validation.user_message)
	var result: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	expect_true(result.validation.is_valid, result.validation.user_message)
	return result.state


func _envelope() -> Dictionary:
	# Parse to untyped JSON collections so malformed probes test our boundary,
	# rather than tripping Godot typed-array guards during fixture construction.
	return JSON.parse_string(JSON.stringify(RunSerializer.to_envelope(_representative(_content()))))


func _founding(envelope: Dictionary) -> Dictionary:
	for cell: Dictionary in envelope["run_state"]["expansion"]["board"]["cells"]:
		if cell["definition_id"] == "tile.founding.homestead":
			return cell
	return {}


func _expect_rejected(envelope: Dictionary, message: String, code: StringName = &"invalid_save") -> void:
	var loaded: DeserializationResult = RunSerializer.deserialize(JSON.stringify(envelope), _content())
	expect_true(not loaded.validation.is_valid and loaded.state == null, message)
	expect_equal(loaded.validation.error_code, code, message + " diagnostic category")
