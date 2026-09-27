extends "res://tests/framework/test_suite.gd"
## View fixtures verify exact saved intent; real commands exercise representative chains.


func tests() -> Array[Callable]:
	var result: Array[Callable] = [no_choice_hidden, rendering_is_read_only,
		assignment_decline, relay_decline, replacement_decline, grand_finish,
		commands_capture_revision, old_buttons_do_not_answer_new_choice,
		double_press_emits_once, unknown_kind_visible_error, training_context,
		relic_descriptions_complete, real_training_command, real_compass_command,
		real_reward_command, real_grand_survey_sequence]
	for kind: StringName in PendingChoicePresenter.KINDS:
		result.append(exact_choice_kind.bind(kind))
	return result


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	assert(content.load_phase_nine().is_valid)
	return content


func _choice(state: RunState, kind: StringName) -> PendingChoice:
	var choice: PendingChoice = PendingChoice.new()
	choice.choice_id = state.id_allocator.allocate()
	choice.kind = kind
	var piece_id: int = state.specialists.pieces[0].piece_id
	var feature: CurrentFeature = TopologyService.rebuild(state)[0]
	match kind:
		&"specialist_assignment", &"specialist_relay":
			choice.options = [{"piece_id": piece_id, "target_type": feature.feature_type, "target_id": feature.lineage_id}]
			choice.context = {"decline_allowed": true}
		&"specialist_training":
			choice.options = [{"role_definition_id": "specialist.merchant"}, {"role_definition_id": "specialist.cartographer"}]
			choice.context = {"piece_id": piece_id}
		&"training_piece":
			choice.options = [{"piece_id": piece_id}]
		&"tile_reward", &"masterwork", &"tile_draft":
			choice.options = [{"definition_id": "tile.woodland_road"}, {"definition_id": "tile.forest_edge"}]
			if kind == &"tile_draft":
				choice.context = {"draft_type": "cadence", "act": 1, "placement_index": 2, "draft_sequence": 1}
		&"major_reward":
			choice.options = [{"major_id": "relic_cache"}, {"major_id": "grand_survey"}]
		&"relic_offer":
			choice.options = [{"definition_id": "relic.village_green"}, {"definition_id": "relic.boundary_stones"}]
		&"relic_replacement":
			choice.options = [{"decline": true}, {"replace_id": "relic.boundary_stones"}]
			choice.context = {"definition_id": "relic.village_green"}
		&"compass":
			choice.options = [{"tile_copy_id": state.expansion.hand[1]}, {"tile_copy_id": state.expansion.hand[0]}]
		&"grand_survey":
			choice.options = [{"tile_copy_id": state.expansion.hand[1], "finish": false}, {"tile_copy_id": 0, "finish": true}]
			choice.context = {"chosen_removals": []}
	state.pending_choice = choice
	state.phase = GamePhase.Type.PENDING_CHOICE
	return choice


func exact_choice_kind(kind: StringName) -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	var choice: PendingChoice = _choice(state, kind)
	var presenter: PendingChoicePresenter = PendingChoicePresenter.new()
	presenter.sync(state, content)
	expect_true(presenter.visible, "Pending %s has a visible panel" % kind)
	expect_equal(presenter.option_buttons.size(), choice.options.size(), "Every exact persisted option has a mouse button")
	for index: int in range(choice.options.size()):
		var command: PlayerCommand = presenter.command_for_option(index)
		expect_equal(command.get("choice_id"), choice.choice_id, "Command captures choice identity")
		expect_equal(command.get("expected_state_revision"), state.expansion.state_revision, "Command captures displayed revision")
		match kind:
			&"tile_draft":
				expect_true(command is ResolveTileDraftCommand, "Draft uses its authoritative typed command")
				expect_equal(command.get("option_index"), index, "Persisted draft option order is untouched")
			&"specialist_assignment":
				expect_true(command is ResolveSpecialistAssignmentCommand, "Assignment uses typed intent")
				expect_equal(command.get("target_id"), choice.options[index]["target_id"], "Exact authoritative target")
			&"specialist_training":
				expect_true(command is ResolveSpecialistTrainingCommand, "Training uses typed intent")
				expect_equal(command.get("role_definition_id"), StringName(choice.options[index]["role_definition_id"]), "Exact offered role order")
			&"compass":
				expect_true(command is ResolveCompassCommand, "Compass uses physical-copy intent")
				expect_equal(command.get("tile_copy_id"), choice.options[index]["tile_copy_id"], "Exact inspected copy order")
			&"specialist_relay":
				expect_true(command is ResolveRelayCommand, "Relay uses typed intent")
			&"grand_survey":
				expect_true(command is ResolveGrandSurveyCommand, "Grand Survey uses typed intent")
				expect_equal(command.get("finish"), choice.options[index]["finish"], "Finish remains a saved option")
			_:
				expect_true(command is ResolveRewardCommand, "Reward uses shared authoritative reward command")
				expect_equal(command.get("option_index"), index, "Offer ordering is untouched")
		expect_true(not presenter.option_buttons[index].text.is_empty(), "Human-readable option text")
	expect_true(presenter.command_for_option(-1) == null and presenter.command_for_option(1000) == null, "Invalid UI indices do not invent commands")
	presenter.free()
	return true


func no_choice_hidden() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	var presenter: PendingChoicePresenter = PendingChoicePresenter.new()
	presenter.sync(state, content)
	expect_true(not presenter.visible and presenter.option_buttons.is_empty(), "Ordinary turn has no choice panel")
	presenter.free()
	return true


func rendering_is_read_only() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	var requested: ValidationResult = RulesEngine.execute(state, content, RequestSpecialistTrainingCommand.new(state.specialists.pieces[0].piece_id))
	expect_true(requested.is_valid, "Real training offer created")
	var before: String = StateNormalizer.fingerprint(state)
	var presenter: PendingChoicePresenter = PendingChoicePresenter.new()
	presenter.sync(state, content)
	presenter.command_for_option(0)
	expect_equal(StateNormalizer.fingerprint(state), before, "Rendering and preparing intent change no state, RNG or options")
	presenter.free()
	return true


func _decline(kind: StringName) -> PlayerCommand:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	_choice(state, kind)
	var presenter: PendingChoicePresenter = PendingChoicePresenter.new()
	presenter.sync(state, content)
	var command: PlayerCommand = presenter.decline_command()
	presenter.free()
	return command


func assignment_decline() -> bool:
	var command: ResolveSpecialistAssignmentCommand = _decline(&"specialist_assignment") as ResolveSpecialistAssignmentCommand
	expect_true(command != null and command.decline, "Optional assignment exposes decline")
	return true


func relay_decline() -> bool:
	var command: ResolveRelayCommand = _decline(&"specialist_relay") as ResolveRelayCommand
	expect_true(command != null and command.option_index == -1, "Relay exposes normal typed decline")
	return true


func replacement_decline() -> bool:
	var command: ResolveRewardCommand = _decline(&"relic_replacement") as ResolveRewardCommand
	expect_true(command != null and command.option_index == 0, "Relic decline is the original persisted option")
	return true


func grand_finish() -> bool:
	var command: ResolveGrandSurveyCommand = _decline(&"grand_survey") as ResolveGrandSurveyCommand
	expect_true(command != null and command.finish, "Grand Survey may finish before removals")
	return true


func commands_capture_revision() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	_choice(state, &"grand_survey")
	var presenter: PendingChoicePresenter = PendingChoicePresenter.new()
	presenter.sync(state, content)
	var command: PlayerCommand = presenter.command_for_option(0)
	var original_revision: int = state.expansion.state_revision
	var original_copy: int = state.pending_choice.options[0]["tile_copy_id"]
	state.expansion.state_revision += 1
	state.pending_choice.options[0]["tile_copy_id"] = state.expansion.hand[2]
	expect_equal(command.get("expected_state_revision"), original_revision, "Same-ID sequential Grand Survey command retains old revision")
	expect_equal(command.get("tile_copy_id"), original_copy, "Command never consults subsequently changed option dictionary")
	presenter.free()
	return true


func old_buttons_do_not_answer_new_choice() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	_choice(state, &"major_reward")
	var presenter: PendingChoicePresenter = PendingChoicePresenter.new()
	var sent: Array[PlayerCommand] = []
	presenter.command_requested.connect(func(command: PlayerCommand) -> void: sent.append(command))
	presenter.sync(state, content)
	var old_button: Button = presenter.option_buttons[0]
	_choice(state, &"relic_offer")
	presenter.sync(state, content)
	old_button.pressed.emit()
	expect_true(sent.is_empty(), "Queued old callback cannot answer newly displayed choice")
	presenter.option_buttons[0].pressed.emit()
	expect_equal(sent.size(), 1, "Fresh option remains clickable")
	expect_equal(sent[0].get("choice_id"), state.pending_choice.choice_id, "Fresh click uses new choice identity")
	presenter.free()
	return true


func double_press_emits_once() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	_choice(state, &"major_reward")
	var presenter: PendingChoicePresenter = PendingChoicePresenter.new()
	var sent: Array[PlayerCommand] = []
	presenter.command_requested.connect(func(command: PlayerCommand) -> void: sent.append(command))
	presenter.sync(state, content)
	presenter.option_buttons[0].pressed.emit()
	presenter.option_buttons[0].pressed.emit()
	expect_equal(sent.size(), 1, "Double press emits one command")
	expect_true(presenter.option_buttons[0].disabled, "Input disabled before synchronous callback")
	presenter.free()
	return true


func unknown_kind_visible_error() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	_choice(state, &"unknown_future_choice")
	var presenter: PendingChoicePresenter = PendingChoicePresenter.new()
	var reported: Array[StringName] = []
	presenter.unhandled_choice.connect(func(kind: StringName) -> void: reported.append(kind))
	presenter.sync(state, content)
	expect_equal(reported, [&"unknown_future_choice"], "Unknown choice raises development signal")
	expect_true(presenter.visible and presenter.error_label.text.contains("Development error"), "Error remains visible rather than invisible stuck state")
	expect_true(presenter.command_for_option(0) == null, "Unknown type cannot emit an invented command")
	presenter.free()
	return true


func training_context() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	_choice(state, &"specialist_training")
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	var feature: CurrentFeature = TopologyService.rebuild(state)[0]
	piece.status = SpecialistPieceState.Status.ASSIGNED
	piece.assigned_target_type = feature.feature_type
	piece.assigned_target_id = feature.lineage_id
	var presenter: PendingChoicePresenter = PendingChoicePresenter.new()
	presenter.sync(state, content)
	expect_true(presenter.context_label.text.contains("Remains assigned"), "In-place training shows preserved assignment")
	expect_true(presenter.option_buttons[0].text.contains("Trade"), "Role effect readable without a hidden tooltip")
	presenter.free()
	return true


func relic_descriptions_complete() -> bool:
	var content: ContentRegistry = _content()
	for id: StringName in content.get_relic_ids():
		expect_true(not ChoiceText.description(id).is_empty(), "Every canonical Relic has effect help: " + String(id))
	for id: StringName in content.get_specialist_ids():
		expect_true(not ChoiceText.description(id).is_empty(), "Every canonical Specialist has effect help: " + String(id))
	for id: StringName in RewardRules.MAJOR_OPTIONS:
		expect_true(not ChoiceText.description(id).is_empty(), "Every Major Reward has effect help")
	return true


func real_training_command() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	var piece: SpecialistPieceState = state.specialists.pieces[0]
	expect_true(RulesEngine.execute(state, content, RequestSpecialistTrainingCommand.new(piece.piece_id)).is_valid, "Training offer starts")
	var expected: StringName = StringName(state.pending_choice.options[0]["role_definition_id"])
	var presenter: PendingChoicePresenter = PendingChoicePresenter.new()
	presenter.sync(state, content)
	var command: PlayerCommand = presenter.command_for_option(0)
	expect_true(RulesEngine.execute(state, content, command).is_valid, "Presenter training command passes engine")
	expect_equal(piece.role_definition_id, expected, "Exact selected role trained")
	expect_true(state.pending_choice == null, "Choice resolved without reroll")
	presenter.free()
	return true


func real_compass_command() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	expect_true(RelicRules.acquire(state, content, &"relic.surveyors_compass").is_valid, "Fixture equips Compass")
	expect_true(RulesEngine.execute(state, content, SurveyTileCommand.new(state.expansion.hand[0])).is_valid, "Normal Survey opens Compass")
	var expected: int = state.pending_choice.options[0]["tile_copy_id"]
	var presenter: PendingChoicePresenter = PendingChoicePresenter.new()
	presenter.sync(state, content)
	expect_true(RulesEngine.execute(state, content, presenter.command_for_option(0)).is_valid, "Presenter Compass command passes engine")
	expect_equal(state.expansion.hand[0], expected, "Inspected physical copy becomes replacement")
	expect_true(state.pending_choice == null, "Compass resolves")
	presenter.free()
	return true


func _reward_context(state: RunState) -> void:
	state.phase = GamePhase.Type.RESOLVING_PLACEMENT
	state.resolution = ResolutionState.new()
	state.resolution.stage = &"reward_queue"
	state.resolution.context = {"mode": "reward"}


func real_reward_command() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	_reward_context(state)
	RewardRules.enqueue(state, &"tile_reward")
	RewardRules.advance(state, content)
	var definition: StringName = StringName(state.pending_choice.options[0]["definition_id"])
	var count: int = RewardRules.copy_quantity(content.get_tile(definition))
	var before: int = state.tile_copies.size()
	var presenter: PendingChoicePresenter = PendingChoicePresenter.new()
	presenter.sync(state, content)
	expect_true(RulesEngine.execute(state, content, presenter.command_for_option(0)).is_valid, "Presenter reward command passes engine")
	expect_equal(state.tile_copies.size() - before, count, "Rules award canonical physical copies")
	expect_equal(state.phase, GamePhase.Type.TURN_INPUT, "Reward continuation returns to input")
	presenter.free()
	return true


func real_grand_survey_sequence() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _new_run(content)
	_reward_context(state)
	RelicHandRules.begin_grand_survey(state, content)
	var presenter: PendingChoicePresenter = PendingChoicePresenter.new()
	presenter.sync(state, content)
	var first_command: PlayerCommand = presenter.command_for_option(0)
	var removed: int = first_command.get("tile_copy_id")
	expect_true(RulesEngine.execute(state, content, first_command).is_valid, "First Grand Survey removal resolves")
	expect_true(state.expansion.removed_ids.has(removed), "Selected physical tile permanently removed")
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, content, first_command).is_valid, "Repeated command is stale even with same choice ID")
	expect_equal(StateNormalizer.fingerprint(state), before, "Rejected duplicate does not remove or reroll")
	presenter.sync(state, content)
	expect_true(presenter.context_label.text.contains("1 of 2"), "Sequential removal count displayed")
	expect_true(RulesEngine.execute(state, content, presenter.decline_command()).is_valid, "Finish button resolves remaining optional choice")
	expect_equal(state.expansion.survey_charges, 2, "One current-Act charge awarded by rules")
	presenter.free()
	return true


func _new_run(content: ContentRegistry) -> RunState:
	var state: RunState = HomesteadRunFactory.create(10010, content)
	assert(state.pending_choice != null and state.pending_choice.kind == &"tile_draft")
	assert(RulesEngine.execute(state, content, ResolveTileDraftCommand.new(state.pending_choice.choice_id, 0)).is_valid)
	return state
