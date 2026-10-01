extends "res://tests/framework/test_suite.gd"


func tests() -> Array[Callable]:
	return [hand_hover_uses_static_rules, reserve_reuses_rules, draft_hover_is_pure,
		complex_rules_are_wrapped_parchment, relic_offer_shows_rarity,
		equipped_relic_shows_rarity_and_uses, reward_ladder_includes_twenty]


func _controller() -> GameController:
	var controller: GameController = GameController.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(controller)
	controller.start_run(2)
	return controller


func _monastery_slot(controller: GameController) -> int:
	for index: int in range(controller.session.state.expansion.hand.size()):
		var copy: TileCopyState = PhysicalTileRules.find_copy(controller.session.state, controller.session.state.expansion.hand[index])
		if copy != null and copy.definition_id == &"tile.development.monastery":
			return index
	return -1


func hand_hover_uses_static_rules() -> bool:
	var controller: GameController = _controller()
	controller.choice_presenter.option_buttons[0].pressed.emit()
	var slot: int = _monastery_slot(controller)
	expect_true(slot >= 0, "Seed 2 opening hand naturally contains the fixed-core Monastery")
	if slot >= 0:
		var button: Button = controller.hand_buttons[slot]
		var tile: TileDefinition = controller.session.content.get_tile(&"tile.development.monastery")
		expect_equal(button.tooltip_text, ChoiceText.tile_tooltip(tile), "Hand reads centralized static rules")
		expect_true(button.tooltip_text.contains("Placement:") and button.tooltip_text.contains("Effect:"), "Complex tile explains placement before effects")
		var before: String = StateNormalizer.fingerprint(controller.session.state)
		var tooltip: Control = button._make_custom_tooltip(button.tooltip_text) as Control
		expect_true(tooltip != null, "Actual hand control builds the readable hover card")
		tooltip.free()
		expect_equal(StateNormalizer.fingerprint(controller.session.state), before, "Hover consumes no RNG and changes no state")
		expect_equal(controller.selected_copy_id, 0, "Hover does not select the tile")
	controller.free()
	return true


func reserve_reuses_rules() -> bool:
	var controller: GameController = _controller()
	controller.choice_presenter.option_buttons[0].pressed.emit()
	var slot: int = _monastery_slot(controller)
	if slot >= 0:
		controller.hand_buttons[slot].pressed.emit()
		controller.shell.reserve_actions[0].pressed.emit()
		expect_true(controller.session.state.expansion.reserve_id > 0, "Normal Reserve command stores Monastery")
		expect_equal(controller.shell.reserve_buttons[0].tooltip_text,
			ChoiceText.tile_tooltip(controller.session.content.get_tile(&"tile.development.monastery")), "Reserve keeps full placement/effect help")
		expect_true(controller.shell.reserve_buttons[0] is InfoTooltipButton, "Reserve uses wrapped hover component")
	else:
		expect_true(false, "Expected natural Monastery")
	controller.free()
	return true


func draft_hover_is_pure() -> bool:
	var controller: GameController = _controller()
	var before: String = StateNormalizer.fingerprint(controller.session.state)
	for index: int in range(controller.choice_presenter.option_buttons.size()):
		var button: Button = controller.choice_presenter.option_buttons[index]
		var id: StringName = StringName(controller.session.state.pending_choice.options[index]["definition_id"])
		expect_equal(button.tooltip_text, ChoiceText.tile_tooltip(controller.session.content.get_tile(id)), "Draft shares full static help")
		var tooltip: Control = button._make_custom_tooltip(button.tooltip_text) as Control
		tooltip.free()
	expect_equal(StateNormalizer.fingerprint(controller.session.state), before, "Draft hover preserves exact PendingChoice and RNG")
	controller.free()
	return true


func complex_rules_are_wrapped_parchment() -> bool:
	var controller: GameController = _controller()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for id: StringName in [&"tile.development.monastery", &"tile.development.foresters_lodge", &"tile.development.abbey", &"tile.development.grand_market"]:
		var text: String = ChoiceText.tile_tooltip(controller.session.content.get_tile(id))
		var button: InfoTooltipButton = InfoTooltipButton.new()
		var tooltip: PanelContainer = button._make_custom_tooltip(text) as PanelContainer
		tree.root.add_child(tooltip)
		var label: Label = tooltip.get_child(0) as Label
		expect_equal(label.text, text, "Tooltip preserves complete summary")
		expect_equal(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "Long prose wraps")
		expect_equal(label.custom_minimum_size.x, 340.0, "Compact manuscript note width")
		expect_equal(label.get_theme_color("font_color"), AlphaTheme.INK, "Dark ink body")
		var style: StyleBoxFlat = tooltip.get_theme_stylebox("panel") as StyleBoxFlat
		expect_equal(style.bg_color, AlphaTheme.PARCHMENT, "Opaque light parchment")
		tooltip.free()
		button.free()
	controller.free()
	return true


func relic_offer_shows_rarity() -> bool:
	var controller: GameController = _controller()
	controller.choice_presenter.option_buttons[0].pressed.emit()
	var state: RunState = controller.session.state
	state.resolution = ResolutionState.new()
	state.resolution.stage = &"reward_queue"
	state.resolution.context = {"mode": "reward"}
	state.phase = GamePhase.Type.RESOLVING_PLACEMENT
	state.features.tracks.values[0] = 20
	RewardRules.queue_thresholds(state)
	RewardRules.advance(state, controller.session.content)
	controller._sync()
	expect_equal(state.pending_choice.kind, &"relic_offer", "20 creates normal Relic presenter")
	var before: String = StateNormalizer.fingerprint(state)
	for index: int in range(state.pending_choice.options.size()):
		var id: StringName = StringName(state.pending_choice.options[index]["definition_id"])
		var relic: RelicDefinition = controller.session.content.get_relic(id)
		var button: Button = controller.choice_presenter.option_buttons[index]
		expect_true(button.text.contains(relic.display_name) and button.text.contains(String(relic.rarity).capitalize()), "Offer explicitly names rarity")
		expect_true(button.text.contains(ChoiceText.description(id)), "Unchanged Relic effect remains visible")
	expect_equal(StateNormalizer.fingerprint(state), before, "Rendering persisted Relic offer is pure")
	controller.free()
	return true


func equipped_relic_shows_rarity_and_uses() -> bool:
	var controller: GameController = _controller()
	controller.choice_presenter.option_buttons[0].pressed.emit()
	var acquired: ValidationResult = RelicRules.acquire(controller.session.state, controller.session.content, &"relic.boundary_stones")
	expect_true(acquired.is_valid, "Acquire eligible fixture Relic")
	controller._sync()
	var text: String = controller.shell.relic_slot_buttons[0].tooltip_text
	expect_true(text.contains("Common") and text.contains("Boundary Stones"), "Equipped detail names rarity and Relic")
	expect_true(text.contains("remaining this Act"), "Once-per-Act availability still shown")
	expect_true(controller.shell.relic_slot_buttons[0] is InfoTooltipButton, "Equipped details wrap on parchment")
	controller.free()
	return true


func reward_ladder_includes_twenty() -> bool:
	var controller: GameController = _controller()
	controller.choice_presenter.option_buttons[0].pressed.emit()
	controller.session.state.features.tracks.values = [19, 20, 40, 70]
	controller._sync()
	for index: int in range(4):
		expect_equal(controller.shell.track_reward_labels[index].text,
			["20 · Relic", "40 · Train", "70 · Relic", "100 · Major"][index], "HUD follows active configured rewards")
	controller.free()
	return true
