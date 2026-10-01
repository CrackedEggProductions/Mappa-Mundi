extends "res://tests/framework/test_suite.gd"
## Human entry uses external entropy; explicit seeds retain the exact run stream.


func tests() -> Array[Callable]:
	return [blank_seed_uses_injected_entropy, explicit_seed_bypasses_entropy,
		signed_64_bit_seed_validation, invalid_seed_does_not_start,
		randomize_only_prepares_candidate, current_seed_is_copyable,
		explicit_seed_replay_is_identical, injected_seeds_change_setup]


func _entry() -> GameController:
	var controller: GameController = GameController.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(controller)
	return controller


func blank_seed_uses_injected_entropy() -> bool:
	var c: GameController = _entry()
	var calls: Array[int] = [0]
	c.fresh_seed_source = func() -> int:
		calls[0] += 1
		return 783451920
	expect_equal(c._seed.text, "", "Human New Run does not default to seed 1")
	expect_equal(c._seed.get_theme_color("font_placeholder_color"), AlphaTheme.SECONDARY_INK, "Blank-seed hint is readable on parchment")
	c._new_run_clicked()
	expect_equal(calls[0], 1, "One external seed is generated")
	expect_equal(c.session.state.original_seed, 783451920, "Generated seed initializes the run")
	var explicit: GameSession = GameSession.start(783451920, c.session.content)
	expect_equal(StateNormalizer.fingerprint(c.session.state), StateNormalizer.fingerprint(explicit.state),
		"Generating an initial seed never consumes the gameplay stream")
	c.free()
	return true


func explicit_seed_bypasses_entropy() -> bool:
	for value: int in [1, -2026, 9223372036854775807, -9223372036854775807 - 1]:
		var c: GameController = _entry()
		var calls: Array[int] = [0]
		c.fresh_seed_source = func() -> int:
			calls[0] += 1
			return 999
		c._seed.text = str(value)
		c._new_run_clicked()
		expect_equal(c.session.state.original_seed, value, "Explicit signed integer preserved exactly")
		expect_equal(calls[0], 0, "Explicit entry does not request entropy")
		var saved: SerializationResult = RunSerializer.serialize(c.session.state, c.session.content)
		var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, c.session.content)
		expect_true(loaded.validation.is_valid, "Boundary seeds retain the existing save representation")
		if loaded.validation.is_valid:
			expect_equal(loaded.state.original_seed, value, "Save round-trip preserves the full integer")
		c.free()
	return true


func signed_64_bit_seed_validation() -> bool:
	for invalid: String in ["", "+", "-", "1.5", "seed1", "1 2", "1e3", "9223372036854775808", "-9223372036854775809", "999999999999999999999999"]:
		expect_true(not RunSeedSource.parse(invalid).valid, "Reject malformed/overflow seed: " + invalid)
	for pair: Array in [["  +00042 ", 42], ["-00042", -42], ["-0", 0], ["000", 0]]:
		var parsed: Dictionary = RunSeedSource.parse(pair[0])
		expect_true(parsed.valid, "Accept ordinary integer formatting")
		expect_equal(parsed.seed, pair[1], "Formatting does not change integer value")
	return true


func invalid_seed_does_not_start() -> bool:
	var c: GameController = _entry()
	var calls: Array[int] = [0]
	c.fresh_seed_source = func() -> int:
		calls[0] += 1
		return 123
	for invalid: String in ["not a seed", "9223372036854775808", "-9223372036854775809"]:
		c._seed.text = invalid
		c._new_run_clicked()
		expect_true(c.session == null and c._entry.visible, "Invalid entry stays at New Run")
		expect_true(not c._entry_error.text.is_empty(), "Invalid input has readable feedback")
	expect_equal(calls[0], 0, "Invalid entry never consumes seed entropy")
	c.free()
	return true


func randomize_only_prepares_candidate() -> bool:
	var c: GameController = _entry()
	var calls: Array[int] = [0]
	c.fresh_seed_source = func() -> int:
		calls[0] += 1
		return 8000 + calls[0]
	c._randomize_seed()
	expect_equal(c._seed.text, "8001", "Randomize fills a candidate")
	expect_true(c.session == null, "Randomize does not start a run")
	c._randomize_seed()
	expect_equal(c._seed.text, "8002", "Each click requests a new candidate")
	c._new_run_clicked()
	expect_equal(calls[0], 2, "Starting the prepared candidate does not reroll")
	expect_equal(c.session.state.original_seed, 8002, "Displayed candidate becomes exact run seed")
	c.free()
	return true


func current_seed_is_copyable() -> bool:
	var c: GameController = _entry()
	c.start_run(-9223372036854775807 - 1)
	expect_equal(c.shell.seed_field.text, "-9223372036854775808", "HUD retains the full seed without float conversion")
	expect_true(not c.shell.seed_field.editable and c.shell.seed_field.selecting_enabled, "Read-only value remains selectable/copyable")
	expect_equal(c.shell.seed_field.get_theme_color("font_uneditable_color"), AlphaTheme.INK, "Read-only seed remains dark and readable on parchment")
	expect_true(c.shell.seed_field.tooltip_text.contains("-9223372036854775808"), "Full seed also readable on hover")
	c.free()
	return true


func explicit_seed_replay_is_identical() -> bool:
	var first: GameController = _entry()
	var second: GameController = _entry()
	for c: GameController in [first, second]:
		c._seed.text = "1"
		c._new_run_clicked()
	expect_equal(StateNormalizer.fingerprint(first.session.state), StateNormalizer.fingerprint(second.session.state), "Explicit seed reproduces River, Charter and persisted Starter offer")
	for c: GameController in [first, second]:
		c.choice_presenter.option_buttons[0].pressed.emit()
	expect_equal(StateNormalizer.fingerprint(first.session.state), StateNormalizer.fingerprint(second.session.state), "Same Starter choice reproduces bag, hand and RNG continuation")
	first.free()
	second.free()
	return true


func injected_seeds_change_setup() -> bool:
	var signatures: Array[String] = []
	for value: int in [783451920, 2026, 1]:
		var c: GameController = _entry()
		c.fresh_seed_source = func() -> int: return value
		c._new_run_clicked()
		var state: RunState = c.session.state
		var river: Array[String] = []
		for coordinate: Vector2i in state.expansion.board.sorted_coordinates():
			var cell: BoardCellState = state.expansion.board.cells[coordinate]
			river.append("%s:%s:r%d" % [coordinate, cell.definition_id, cell.rotation])
		var signature: String = str([state.charters.act_one_id, river, state.pending_choice.options])
		signatures.append(signature)
		print("SEED ENTRY SAMPLE: ", value, " ", signature)
		c.free()
	expect_true(signatures[0] != signatures[1], "Known distinct injected seeds produce different gameplay setup choices")
	return true
