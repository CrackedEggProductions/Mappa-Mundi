extends "res://tests/scenarios/presentation_mouse_smoke.gd"
## Real viewport input. Lodge and Track-20 fixtures isolate presentation coverage.

var capture_prefix: String


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(int(args[0]), int(args[1])) if args.size() >= 2 else Vector2i(1280, 720)
	var suffix: String = args[2] if args.size() >= 3 else str(Time.get_unix_time_from_system())
	capture_prefix = "res://docs/reports/ui_usability/relic-information-%dx%d-%s" % [root.size.x, root.size.y, suffix]
	controller = GameController.new()
	root.add_child(controller)
	await _frames()
	_check(controller._seed.text.is_empty(), "Human seed field starts blank")
	await _capture("new-run")
	await _click(_find_button(controller, "New Run"))
	_check(controller.session != null, "Blank seed starts a run using external entropy")
	print("FRESH SEED: ", controller.session.state.original_seed)
	_check(controller.shell.seed_field.text == str(controller.session.state.original_seed), "Full generated seed discoverable in HUD")
	_check(controller.session.state.pending_choice.kind == &"tile_draft", "Fresh run pauses at Starter Draft")
	controller.free()
	await _frames()
	controller = GameController.new()
	root.add_child(controller)
	await _frames()
	controller._seed.text = "2"
	await _click(_find_button(controller, "New Run"))
	_check(controller.session.state.original_seed == 2, "Explicit seed used exactly")
	await _click(controller.choice_presenter.option_buttons[0])
	var state: RunState = controller.session.state
	_check(state.phase == GamePhase.Type.TURN_INPUT, "Mouse Starter Draft continues to opening hand")
	var monastery_slot: int = -1
	for index: int in range(state.expansion.hand.size()):
		if PhysicalTileRules.find_copy(state, state.expansion.hand[index]).definition_id == &"tile.development.monastery":
			monastery_slot = index
	_check(monastery_slot >= 0, "Natural seed-2 hand includes Monastery")
	if monastery_slot < 0:
		quit(1)
		return
	await _hover_rules(controller.hand_buttons[monastery_slot], "Monastery", "monastery")
	await _click(controller.hand_buttons[monastery_slot])
	await _click(controller.shell.reserve_actions[0])
	_check(state.expansion.reserve_id > 0, "Normal mouse Reserve command")
	await _hover_rules(controller.shell.reserve_buttons[0], "Monastery", "reserve")
	# Controlled test acquisition, not a balance change or replacement for Drafts.
	var fixture: Script = load("res://tests/fixtures/phase_five_factory.gd")
	fixture.acquire_hand(state, &"tile.development.foresters_lodge", 0)
	controller._sync()
	await _frames()
	await _hover_rules(controller.hand_buttons[0], "Forester", "lodge")
	# Real placements/scoring create a save-valid threshold offer; no Track edits.
	state = _threshold_fixture(controller.session.content)
	controller.attach_session(GameSession.new(state, controller.session.content))
	await _frames()
	# Leave the former hand hover when switching to this controlled fixture.
	await _hover(controller.choice_presenter.title_label)
	_check(state.pending_choice != null and state.pending_choice.kind == &"relic_offer", "20 threshold opens normal Relic Offer")
	var chosen: StringName = StringName(state.pending_choice.options[0]["definition_id"])
	for index: int in range(state.pending_choice.options.size()):
		var id: StringName = StringName(state.pending_choice.options[index]["definition_id"])
		var relic: RelicDefinition = controller.session.content.get_relic(id)
		_check(controller.choice_presenter.option_buttons[index].text.contains(String(relic.rarity).capitalize()), "Offer visibly labels rarity")
	await _capture("relic-offer")
	await _click(controller.choice_presenter.option_buttons[0])
	_check(RelicRules.active(state, chosen), "One mouse choice acquires the offered Relic")
	_check(state.pending_choice != null and state.pending_choice.kind == &"tile_draft", "Cadence draft follows the fully resolved threshold reward")
	await _click(controller.choice_presenter.option_buttons[0])
	_check(state.pending_choice == null and state.phase == GamePhase.Type.TURN_INPUT, "Mouse cadence choice finishes refill and returns to play")
	_check(RelicRules.active(state, chosen), "Chosen Relic equipped")
	var detail: Button = controller.shell.relic_slot_buttons[0]
	var rarity: String = String(controller.session.content.get_relic(chosen).rarity).capitalize()
	_check(detail.tooltip_text.contains(rarity), "Equipped detail retains rarity")
	await _hover(detail)
	_check(_visible_tooltip_label(root, rarity) != null, "Equipped Relic hover appears through real mouse input")
	await _capture("equipped-relic")
	var viewport: Rect2 = Rect2(Vector2.ZERO, Vector2(root.size))
	for control: Control in [controller.shell.seed_field, controller.hand_buttons[2], controller.shell.charter_button]:
		_check(viewport.encloses(control.get_global_rect()), "Seed and existing controls fit viewport")
	print("RELIC INFORMATION MOUSE RESULT: %d checks, %d failures at %dx%d" % [checks, failures.size(), root.size.x, root.size.y])
	quit(0 if failures.is_empty() else 1)


func _threshold_fixture(content: ContentRegistry) -> RunState:
	var recipe: Script = load("res://tests/fixtures/phase_nine_factory.gd")
	var state: RunState = recipe.started(content, recipe.RUN_SEED)
	recipe.train_naturalist(state, content)
	for entry: Dictionary in recipe.placements(1, 0, state):
		var copy_id: int = recipe.Acquisition.acquire_hand(state, StringName(entry.definition_id))
		var placed: ValidationResult = RulesEngine.execute(state, content, recipe._intent(state, content, copy_id, entry))
		assert(placed.is_valid, placed.user_message)
		while state.pending_choice != null:
			if state.pending_choice.kind == &"relic_offer" and int(state.pending_choice.context.get("threshold", 0)) == 20:
				assert(InvariantValidator.validate(state, content).is_valid, "Threshold fixture must retain genuine scoring history")
				return state
			var resolved: ValidationResult = RulesEngine.execute(state, content, recipe.choice_command(state))
			assert(resolved.is_valid, resolved.user_message)
	assert(false, "Controlled real placements must reach a twenty-point Relic offer")
	return state


func _hover(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	root.grab_focus()
	root.warp_mouse(at)
	# Let the desktop's warp event settle before starting the tooltip timer.
	await _frames()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.relative = Vector2.ONE
	root.push_input(motion, true)
	await create_timer(1.5).timeout
	await _frames()


func _hover_rules(control: Button, name_part: String, capture: String) -> void:
	var before: String = StateNormalizer.fingerprint(controller.session.state)
	await _hover(control)
	var label: Label = _visible_tooltip_label(root, "Placement:")
	_check(label != null and label.text.contains(name_part), "Mouse hover exposes " + name_part + " rules")
	if label != null:
		_check(label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Rules wrap within the compact note")
		_check(label.get_theme_color("font_color") == AlphaTheme.INK, "Tooltip body is dark ink")
		_check(label.size.x <= 360 and label.size.y < 460, "Rules remain compact at target resolution")
	_check(StateNormalizer.fingerprint(controller.session.state) == before, "Hover leaves RNG and authoritative state unchanged")
	await _capture(capture)


func _visible_tooltip_label(node: Node, contains: String) -> Label:
	if node is Label:
		var label: Label = node as Label
		if label.is_visible_in_tree() and label.text.contains(contains):
			return label
	for child: Node in node.get_children(true):
		var found: Label = _visible_tooltip_label(child, contains)
		if found != null:
			return found
	return null


func _capture(stage: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = capture_prefix + "-" + stage + ".png"
	assert(not FileAccess.file_exists(path), "Use a fresh capture suffix")
	_check(root.get_texture().get_image().save_png(path) == OK, "Screenshot saved: " + stage)
