extends "res://tests/framework/test_suite.gd"

const Factory = preload("res://tests/fixtures/phase_two_factory.gd")
const FIELDS: Array[StringName] = [&"tile.open_fields", &"tile.open_fields", &"tile.open_fields"]
const ROADS: Array[StringName] = [&"tile.road_end", &"tile.road_end", &"tile.road_end"]


func tests() -> Array[Callable]:
	return [homestead_inventory_is_exact, opening_state_is_canonical,
		seeded_opening_is_deterministic, hand_placement_refills_only_consumed_slot,
		invalid_placement_is_atomic, source_zone_is_revalidated, stale_preview_is_atomic,
		forged_preview_signature_is_atomic, reserve_moves_and_refills,
		occupied_reserve_rejects_swap, reserve_placement_preserves_hand,
		survey_removes_physical_copy, reserve_cannot_be_surveyed,
		survey_requires_charge, reserve_and_survey_allow_both_orders,
		dead_hand_cycles_exact_copies_once, playable_hand_prevents_cycle,
		playable_reserve_does_not_prevent_cycle, unplayable_individual_stays,
		global_stalemate_injects_exact_emergency_set, playable_bag_prevents_global_stalemate,
		empty_bag_replenishment_is_repeatable, reserve_proof_is_conservative,
		phase_two_scripted_sequence_survives_load, act_boundary_defers_transition,
		exhausted_continuations_reject_atomically]


func homestead_inventory_is_exact() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = HomesteadRunFactory.create(41, content)
	var expected: Dictionary[StringName, int] = {
		&"tile.open_fields": 4, &"tile.forest_edge": 3, &"tile.forest_bend": 3,
		&"tile.forest_belt": 2, &"tile.river_end": 2, &"tile.river_run": 3,
		&"tile.river_bend": 3, &"tile.road_end": 3, &"tile.straight_road": 4,
		&"tile.bending_road": 4, &"tile.road_junction": 2, &"tile.hamlet_edge": 3,
		&"tile.settlement_corner": 3, &"tile.settlement_throughway": 2,
		&"tile.settlement_gate": 2, &"tile.riverside_hamlet": 2, &"tile.woodland_road": 2,
		&"tile.woodland_river": 2, &"tile.settlement_corner_gate": 2,
		&"tile.settlement_road_bend": 2, &"tile.settlement_road_throughway": 2,
	}
	var actual: Dictionary[StringName, int] = {}
	var identities: Dictionary[int, bool] = {}
	for copy: TileCopyState in state.tile_copies:
		expect_true(not identities.has(copy.tile_copy_id), "Physical copy ID is unique")
		identities[copy.tile_copy_id] = true
		if copy.definition_id != &"tile.founding.homestead":
			actual[copy.definition_id] = actual.get(copy.definition_id, 0) + 1
			expect_equal(content.get_tile(copy.definition_id).tile_class,
				DomainTypes.TileClass.EXPANSION, "Starting bag contains Expansion only")
	expect_equal(actual, expected, "Exact canonical counts of all 21 starting definitions")
	expect_equal(state.tile_copies.size(), 56, "55 starting copies plus separate Founding copy")
	expect_equal(state.expansion.bag.size(), 52, "Opening draw leaves 52 bag copies")
	return true


func opening_state_is_canonical() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = HomesteadRunFactory.create(41, content)
	var founding: BoardCellState = state.expansion.board.get_cell(Vector2i.ZERO)
	expect_true(founding != null, "Founding at origin")
	expect_equal(founding.effective_edges, [4, 3, 2, 1], "Fixed Settlement/Road/River/Forest orientation")
	expect_equal(founding.rotation, 0, "Founding fixed rotation")
	expect_equal(founding.act_placed, 1, "Founding historically Act I")
	expect_equal(founding.normal_placement_index, 0, "Founding consumes no normal placement")
	expect_equal(state.expansion.normal_placements, 0, "Zero normal placements completed")
	expect_equal(state.expansion.hand.size(), 3, "Three opening copies")
	expect_equal(state.expansion.reserve_id, 0, "Reserve empty")
	expect_equal(state.expansion.survey_charges, 1, "Act I Survey granted")
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Headless turn input ready")
	_valid(state, content)
	return true


func seeded_opening_is_deterministic() -> bool:
	var content: ContentRegistry = Factory.content()
	var first: RunState = HomesteadRunFactory.create(12345, content)
	var second: RunState = HomesteadRunFactory.create(12345, content)
	expect_equal(first.expansion.bag, second.expansion.bag, "Seed fixes bag order")
	expect_equal(first.expansion.hand, second.expansion.hand, "Seed fixes opening draws")
	expect_equal(StateNormalizer.fingerprint(first), StateNormalizer.fingerprint(second), "Identical authoritative start")
	var other: RunState = HomesteadRunFactory.create(98765, content)
	expect_true(first.expansion.bag != other.expansion.bag, "Different seeds can change bag")
	return true


func invalid_placement_is_atomic() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, ROADS, ROADS)
	_reject_unchanged(state, content, PlaceTileCommand.new(state.expansion.hand[0],
		TileLocationState.Kind.ACTIVE_HAND, Vector2i.ZERO, 0), "Occupied origin")
	_reject_unchanged(state, content, PlaceTileCommand.new(state.expansion.hand[0],
		TileLocationState.Kind.ACTIVE_HAND, Vector2i(20, -20), 0), "Nonadjacent target")
	_reject_unchanged(state, content, PlaceTileCommand.new(state.expansion.hand[0],
		TileLocationState.Kind.ACTIVE_HAND, Vector2i.ONE, 0), "Diagonal only")
	_reject_unchanged(state, content, PlaceTileCommand.new(state.expansion.hand[0],
		TileLocationState.Kind.ACTIVE_HAND, Vector2i.LEFT, 0), "Mismatched Forest side")
	_reject_unchanged(state, content, PlaceTileCommand.new(state.expansion.hand[0],
		TileLocationState.Kind.ACTIVE_HAND, Vector2i.RIGHT, 4), "Noncanonical rotation")
	return true


func source_zone_is_revalidated() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, ROADS, ROADS)
	var command: PlaceTileCommand = Factory.first_placement(state, content)
	command.source_zone = TileLocationState.Kind.RESERVE
	_reject_unchanged(state, content, command, "Hand copy cannot masquerade as Reserve")
	command.source_zone = TileLocationState.Kind.BAG
	_reject_unchanged(state, content, command, "Bag is not a player placement source")
	command.source_zone = TileLocationState.Kind.ACTIVE_HAND
	command.tile_copy_id = state.expansion.bag[0]
	_reject_unchanged(state, content, command, "Bag physical ID cannot be played as hand")
	return true


func stale_preview_is_atomic() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, ROADS, ROADS)
	var option: PlacementOption = Factory.options(state, content, state.expansion.hand[0])[0]
	var command: PlaceTileCommand = PlaceTileCommand.new(option.tile_copy_id,
		TileLocationState.Kind.ACTIVE_HAND, option.coordinate, option.rotation)
	command.expected_board_revision = option.board_revision
	command.expected_state_revision = option.state_revision
	command.expected_signature = option.signature
	expect_true(RulesEngine.execute(state, content,
		ReserveTileCommand.new(state.expansion.hand[1])).is_valid, "Reserve changes state revision")
	_reject_unchanged(state, content, command, "Stale state preview rejected after Reserve")
	return true


func forged_preview_signature_is_atomic() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, ROADS, ROADS)
	var command: PlaceTileCommand = Factory.first_placement(state, content)
	command.expected_signature = "incorrect-signature"
	_reject_unchanged(state, content, command, "Forged signature rejected")
	return true


func reserve_moves_and_refills() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, ROADS, ROADS)
	var old_hand: Array[int] = state.expansion.hand.duplicate()
	var next_draw: int = state.expansion.bag[0]
	expect_true(RulesEngine.execute(state, content, ReserveTileCommand.new(old_hand[1])).is_valid,
		"Move active-hand copy to empty Reserve")
	expect_equal(state.expansion.reserve_id, old_hand[1], "Same physical copy in Reserve")
	expect_equal(state.expansion.hand, [old_hand[0], next_draw, old_hand[2]], "Immediate replacement in same slot")
	expect_equal(state.expansion.normal_placements, 0, "Reserve is pre-placement")
	expect_equal(state.expansion.survey_charges, 1, "Reserve costs no Survey")
	_valid(state, content)
	return true


func occupied_reserve_rejects_swap() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, ROADS, ROADS, &"tile.road_end")
	_reject_unchanged(state, content, ReserveTileCommand.new(state.expansion.hand[0]), "Occupied Reserve rejects swap")
	_reject_unchanged(state, content, ReserveTileCommand.new(state.expansion.reserve_id), "Reserve cannot move itself to hand")
	return true


func reserve_placement_preserves_hand() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, ROADS, ROADS, &"tile.road_end")
	var old_hand: Array[int] = state.expansion.hand.duplicate()
	var old_bag: Array[int] = state.expansion.bag.duplicate()
	var option: PlacementOption = Factory.options(state, content, state.expansion.reserve_id)[0]
	expect_true(RulesEngine.execute(state, content, PlaceTileCommand.new(option.tile_copy_id,
		TileLocationState.Kind.RESERVE, option.coordinate, option.rotation)).is_valid, "Reserve placement succeeds")
	expect_equal(state.expansion.reserve_id, 0, "Reserve emptied")
	expect_equal(state.expansion.hand, old_hand, "Reserve placement leaves hand intact")
	expect_equal(state.expansion.bag, old_bag, "Reserve placement causes no replacement draw")
	expect_equal(state.expansion.normal_placements, 1, "Reserve placement consumes normal placement")
	_valid(state, content)
	return true


func survey_removes_physical_copy() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, ROADS, ROADS)
	var chosen: int = state.expansion.hand[1]
	var old_hand: Array[int] = state.expansion.hand.duplicate()
	var next_draw: int = state.expansion.bag[0]
	expect_true(RulesEngine.execute(state, content, SurveyTileCommand.new(chosen)).is_valid, "Survey succeeds")
	expect_equal(state.expansion.survey_charges, 0, "One Survey charge consumed")
	expect_equal(state.expansion.removed_ids, [chosen], "Chosen copy permanently removed")
	expect_equal(state.expansion.hand, [old_hand[0], next_draw, old_hand[2]], "Survey replaces only chosen slot")
	expect_true(PhysicalTileRules.find_copy(state, chosen) != null, "Removed identity remains recorded")
	expect_equal(state.expansion.normal_placements, 0, "Survey is pre-placement")
	_valid(state, content)
	return true


func reserve_cannot_be_surveyed() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, ROADS, ROADS, &"tile.road_end")
	_reject_unchanged(state, content, SurveyTileCommand.new(state.expansion.reserve_id), "Committed Reserve cannot be Surveyed")
	return true


func survey_requires_charge() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, ROADS, ROADS)
	expect_true(RulesEngine.execute(state, content, SurveyTileCommand.new(state.expansion.hand[0])).is_valid, "First Survey succeeds")
	_reject_unchanged(state, content, SurveyTileCommand.new(state.expansion.hand[1]), "Second Survey requires a charge")
	return true


func reserve_and_survey_allow_both_orders() -> bool:
	var content: ContentRegistry = Factory.content()
	for reserve_first: bool in [false, true]:
		var state: RunState = Factory.minimal(content, ROADS, ROADS)
		var reserved_id: int = state.expansion.hand[0]
		var surveyed_id: int = state.expansion.hand[1]
		var first: PlayerCommand = ReserveTileCommand.new(reserved_id) if reserve_first else SurveyTileCommand.new(surveyed_id)
		var second: PlayerCommand = SurveyTileCommand.new(surveyed_id) if reserve_first else ReserveTileCommand.new(reserved_id)
		expect_true(RulesEngine.execute(state, content, first).is_valid, "First pre-placement action")
		expect_true(RulesEngine.execute(state, content, second).is_valid, "Second pre-placement action")
		expect_equal(state.expansion.reserve_id, reserved_id, "Intended copy reserved")
		expect_equal(state.expansion.removed_ids, [surveyed_id], "Intended copy surveyed")
		expect_equal(state.expansion.normal_placements, 0, "Both actions precede placement")
		_valid(state, content)
	return true


func dead_hand_cycles_exact_copies_once() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, FIELDS, ROADS)
	var expected_ids: Array[int] = state.expansion.bag.duplicate()
	expected_ids.append_array(state.expansion.hand)
	var snapshot: RunRNG = RunRNG.from_snapshot(state.original_seed, state.current_rng_state, state.rng.operation_count)
	expected_ids = snapshot.shuffled_ids(expected_ids, &"dead_hand_cycle")
	var count_before: int = state.tile_copies.size()
	expect_true(StalemateRules.is_dead_hand(state, content), "All three Field tiles are unplayable at Founding")
	expect_true(RulesEngine.execute(state, content, CycleDeadHandCommand.new()).is_valid, "Free full-hand cycle")
	expect_equal(state.expansion.hand, expected_ids.slice(0, 3), "Entire return batch shuffled once then drawn")
	expect_equal(state.expansion.bag, expected_ids.slice(3), "Remaining shuffled bag exact")
	expect_equal(state.current_rng_state, snapshot.current_state, "Exactly one full-bag shuffle")
	expect_equal(state.tile_copies.size(), count_before, "Cycle neither duplicates nor destroys copies")
	expect_equal(state.expansion.survey_charges, 1, "Cycle is free")
	_valid(state, content)
	return true


func playable_hand_prevents_cycle() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content,
		[&"tile.open_fields", &"tile.road_end", &"tile.open_fields"], ROADS)
	expect_true(not StalemateRules.is_dead_hand(state, content), "One playable copy prevents dead hand")
	_reject_unchanged(state, content, CycleDeadHandCommand.new(), "Playable hand cannot cycle voluntarily")
	return true


func playable_reserve_does_not_prevent_cycle() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, FIELDS, ROADS, &"tile.road_end")
	var reserved_id: int = state.expansion.reserve_id
	expect_true(not Factory.options(state, content, reserved_id).is_empty(), "Reserve is playable")
	expect_true(RulesEngine.execute(state, content, CycleDeadHandCommand.new()).is_valid, "Playable Reserve does not block cycle")
	expect_equal(state.expansion.reserve_id, reserved_id, "Reserve remains committed and untouched")
	_valid(state, content)
	return true


func unplayable_individual_stays() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content,
		[&"tile.open_fields", &"tile.road_end", &"tile.road_end"], ROADS)
	var unplayable_id: int = state.expansion.hand[0]
	expect_true(Factory.options(state, content, unplayable_id).is_empty(), "Individual copy currently unplayable")
	expect_true(RulesEngine.execute(state, content, ReserveTileCommand.new(state.expansion.hand[1])).is_valid, "Legal pre-action")
	expect_equal(state.expansion.hand[0], unplayable_id, "Unplayable individual is not auto-cycled")
	return true


func global_stalemate_injects_exact_emergency_set() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, FIELDS, FIELDS, &"tile.road_end")
	var cursor: int = state.next_runtime_id
	var copy_count: int = state.tile_copies.size()
	var reserved_id: int = state.expansion.reserve_id
	expect_true(StalemateRules.is_global_stalemate(state, content), "Full hand and bag examined; playable Reserve ignored")
	expect_true(RulesEngine.execute(state, content, CycleDeadHandCommand.new()).is_valid, "Global safeguard resolves one redraw")
	expect_equal(state.tile_copies.size(), copy_count + 3, "Exactly three emergency copies")
	var acquired: Array[StringName] = []
	for copy_id: int in range(cursor, cursor + 3):
		var copy: TileCopyState = PhysicalTileRules.find_copy(state, copy_id)
		acquired.append(copy.definition_id)
		expect_equal(copy.acquisition_source, &"emergency_replenishment", "Emergency acquisition metadata")
		expect_equal(copy.acquired_act, 1, "Emergency acquisition Act")
	acquired.sort_custom(_definition_before)
	expect_equal(acquired, [&"tile.forest_edge", &"tile.hamlet_edge", &"tile.road_end"], "Canonical emergency set")
	expect_equal(state.expansion.reserve_id, reserved_id, "Reserve untouched by global safeguard")
	expect_equal(state.expansion.hand.size(), 3, "Dead hand redrawn")
	expect_equal(state.rng.operation_count, 1, "Combined emergency and returns batch shuffled once")
	_valid(state, content)
	return true


func playable_bag_prevents_global_stalemate() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, FIELDS,
		[&"tile.open_fields", &"tile.road_end", &"tile.open_fields"])
	expect_true(StalemateRules.is_dead_hand(state, content), "Hand itself dead")
	expect_true(not StalemateRules.is_global_stalemate(state, content), "Playable bag copy prevents global safeguard")
	return true


func empty_bag_replenishment_is_repeatable() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, ROADS, [])
	var cursor: int = state.next_runtime_id
	for batch: int in range(3):
		var drawn_definitions: Array[StringName] = []
		for index: int in range(3):
			var copy_id: int = PhysicalTileRules.draw(state, content.get_config())
			var copy: TileCopyState = PhysicalTileRules.find_copy(state, copy_id)
			drawn_definitions.append(copy.definition_id)
			expect_true(copy_id >= cursor, "Injected ID never collides with earlier copies")
			expect_equal(copy.acquisition_source, &"emergency_replenishment", "Draw acquisition source")
			# Retire each drawn copy to keep this focused draw fixture stable.
			PhysicalTileRules.set_location(state, copy_id, TileLocationState.Kind.REMOVED_FROM_RUN)
			state.expansion.removed_ids.append(copy_id)
			expect_equal(state.expansion.bag.size(), 2 - index, "Exactly three injected per exhausted bag")
		drawn_definitions.sort_custom(_definition_before)
		expect_equal(drawn_definitions, [&"tile.forest_edge", &"tile.hamlet_edge", &"tile.road_end"], "Repeated canonical emergency set")
		expect_equal(state.next_runtime_id, cursor + 3 * (batch + 1), "New monotonic IDs each replenishment")
		_valid(state, content)
	expect_equal(state.rng.operation_count, 3, "One shuffle for each of three replenishments")
	return true


func reserve_proof_is_conservative() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, ROADS, ROADS, &"tile.open_fields")
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(Factory.options(state, content, state.expansion.reserve_id).is_empty(), "Reserve has no current placement")
	expect_equal(ReserveProofService.assess(state, content),
		ReserveProofService.Verdict.NOT_PROVABLY_IMPOSSIBLE, "Current failure is not proof about future alpha actions")
	expect_equal(StateNormalizer.fingerprint(state), before, "Conservative proof never removes Reserve")
	return true


func phase_two_scripted_sequence_survives_load() -> bool:
	var content: ContentRegistry = Factory.content()
	var original: RunState = HomesteadRunFactory.create(20260910, content)
	var opening: PlaceTileCommand = Factory.first_placement(original, content)
	if opening == null:
		expect_true(false, "Script seed has an opening placement")
		return true
	var reserved_id: int = opening.tile_copy_id
	expect_true(RulesEngine.execute(original, content, ReserveTileCommand.new(reserved_id)).is_valid, "Script reserves playable copy")
	var surveyed_id: int = original.expansion.hand[1]
	expect_true(RulesEngine.execute(original, content, SurveyTileCommand.new(surveyed_id)).is_valid, "Script Surveys active hand")
	var option: PlacementOption = Factory.options(original, content, reserved_id)[0]
	expect_true(RulesEngine.execute(original, content, PlaceTileCommand.new(reserved_id,
		TileLocationState.Kind.RESERVE, option.coordinate, option.rotation)).is_valid, "Script places Reserve")
	var loaded: RunState = null
	var nonzero_rotation: bool = option.rotation != 0
	for step: int in range(1, 12):
		if step == 5:
			var saved: SerializationResult = RunSerializer.serialize(original, content)
			expect_true(saved.validation.is_valid, saved.validation.user_message)
			var restored: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
			expect_true(restored.validation.is_valid, restored.validation.user_message)
			loaded = restored.state
			if loaded == null:
				return true
			expect_true(loaded != original, "Fresh RunState after mid-sequence load")
			expect_true(loaded.expansion.board != original.expansion.board, "Fresh sparse board after load")
			expect_equal(loaded.expansion.bag, original.expansion.bag, "Bag order survives mid-sequence load")
			expect_equal(loaded.expansion.hand, original.expansion.hand, "Hand slots survive mid-sequence load")
			expect_equal(loaded.current_rng_state, original.current_rng_state, "Current RNG continuation restored")
			expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(original), "Mid-sequence fingerprint")
		var command: PlaceTileCommand = _playable_command(original, content, loaded)
		if command == null:
			return true
		nonzero_rotation = nonzero_rotation or command.rotation != 0
		expect_true(RulesEngine.execute(original, content, command).is_valid, "Script placement %d" % (step + 1))
		_valid(original, content)
		if loaded != null:
			expect_true(RulesEngine.execute(loaded, content, command).is_valid, "Loaded placement %d" % (step + 1))
			_valid(loaded, content)
			expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(original), "Deterministic continuation after command")
	expect_true(nonzero_rotation, "Script exercises a rotated tile")
	expect_equal(original.expansion.normal_placements, 12, "Twelve legal normal placements")
	expect_equal(original.expansion.board.cells.size(), 13, "Founding plus twelve base copies")
	expect_equal(original.expansion.removed_ids, [surveyed_id], "Survey identity retained through sequence")
	if loaded != null:
		for index: int in range(10):
			expect_equal(loaded.rng.select_index(101), original.rng.select_index(101), "Exact future RNG result")
			expect_equal(loaded.id_allocator.allocate(), original.id_allocator.allocate(), "Exact future runtime identity")
		_valid(loaded, content)
		expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(original), "Fingerprint after RNG and ID continuation")
	print("DEMO Mappa Mundi: 12 placements; Reserve, Survey, rotation; save/load after 5; deterministic continuation verified.")
	return true


func act_boundary_defers_transition() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = HomesteadRunFactory.create(10249, content)
	for index: int in range(18):
		var command: PlaceTileCommand = _playable_command(state, content)
		if command == null:
			return true
		expect_true(RulesEngine.execute(state, content, command).is_valid, "Act-I placement %d" % (index + 1))
	expect_equal(state.expansion.normal_placements, 18, "Stop at 18 normal Act-I placements")
	expect_equal(state.expansion.current_act, 1, "Act-II behavior remains deferred")
	expect_equal(state.phase, GamePhase.Type.RESOLVING_ACT_TRANSITION, "Explicit later-phase boundary")
	expect_true(state.expansion.pending_refill_index >= 0, "Final hand refill pending later transition seeding")
	expect_equal(state.expansion.hand.count(0), 1, "Exactly consumed final slot stays empty")
	_reject_unchanged(state, content, SurveyTileCommand.new(state.expansion.hand[0]), "No pre-placement input across deferred boundary")
	_valid(state, content)
	return true


func exhausted_continuations_reject_atomically() -> bool:
	var content: ContentRegistry = Factory.content()
	for field: int in range(3):
		var state: RunState = Factory.minimal(content, ROADS, ROADS)
		var command: PlaceTileCommand = Factory.first_placement(state, content)
		if field == 0:
			state.expansion.state_revision = 9223372036854775807
		elif field == 1:
			state.id_allocator = RunIdAllocator.new(9223372036854775807)
		else:
			state.rng = RunRNG.from_snapshot(state.original_seed, state.current_rng_state, 9223372036854775807)
		_reject_unchanged(state, content, command, "Exhausted continuation rejected before mutation")
	return true


func _playable_command(state: RunState, content: ContentRegistry,
		mirror: RunState = null) -> PlaceTileCommand:
	# Test bound diagnoses a stalled demonstration without changing production rules.
	for attempt: int in range(100):
		var command: PlaceTileCommand = Factory.first_placement(state, content, true)
		if command == null:
			command = Factory.first_placement(state, content)
		if command != null:
			return command
		var cycle: ValidationResult = RulesEngine.execute(state, content, CycleDeadHandCommand.new())
		expect_true(cycle.is_valid, "Resolve qualifying dead hand: " + cycle.user_message)
		if not cycle.is_valid:
			return null
		if mirror != null:
			expect_true(RulesEngine.execute(mirror, content, CycleDeadHandCommand.new()).is_valid, "Mirror free cycle")
	expect_true(false, "Script did not find a placement in 100 free redraws")
	return null


func _valid(state: RunState, content: ContentRegistry) -> void:
	var report: InvariantReport = InvariantValidator.validate(state, content)
	expect_true(report.is_valid, report.describe())


func _definition_before(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)


func _reject_unchanged(state: RunState, content: ContentRegistry,
		command: PlayerCommand, message: String) -> void:
	var before: String = StateNormalizer.fingerprint(state)
	var result: ValidationResult = RulesEngine.execute(state, content, command)
	expect_true(not result.is_valid, message)
	expect_true(result.error_code != &"", "Structured error: " + message)
	expect_equal(StateNormalizer.fingerprint(state), before, "Rejected intent leaves state unchanged: " + message)
	_valid(state, content)


func hand_placement_refills_only_consumed_slot() -> bool:
	var content: ContentRegistry = Factory.content()
	var state: RunState = Factory.minimal(content, ROADS, ROADS)
	var old_hand: Array[int] = state.expansion.hand.duplicate()
	var next_draw: int = state.expansion.bag[0]
	var command: PlaceTileCommand = Factory.first_placement(state, content, true)
	var slot: int = old_hand.find(command.tile_copy_id)
	expect_true(RulesEngine.execute(state, content, command).is_valid, "Hand placement succeeds")
	expect_equal(state.expansion.hand[slot], next_draw, "Bag index zero refills consumed slot")
	for index: int in range(3):
		if index != slot:
			expect_equal(state.expansion.hand[index], old_hand[index], "Unchosen hand copy persists")
	var cell: BoardCellState = state.expansion.board.get_cell(command.coordinate)
	expect_equal(cell.base_tile_copy_id, command.tile_copy_id, "Placed identity retained")
	expect_equal(cell.rotation, command.rotation, "Nonzero gameplay rotation retained")
	expect_equal(state.expansion.normal_placements, 1, "One normal placement consumed")
	expect_equal(state.expansion.board.revision, 2, "Board revision incremented once")
	_valid(state, content)
	return true
