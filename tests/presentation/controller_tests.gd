extends "res://tests/framework/test_suite.gd"
## Focused UI actions. Controlled acquisition is confined to uncommon-mode fixtures.

const Acquisition = preload("res://tests/fixtures/phase_five_factory.gd")
const Transformation = preload("res://tests/fixtures/phase_six_factory.gd")
const Previous = preload("res://tests/fixtures/phase_eight_factory.gd")
const ThreeActs = preload("res://tests/fixtures/phase_nine_factory.gd")
const Geography = preload("res://tests/fixtures/phase_three_factory.gd")
const Geometry = preload("res://tests/unit/relic_geometry_tests.gd")


func tests() -> Array[Callable]:
	return [new_run_and_hand_controls, select_queries_exact_authoritative_options,
		preview_and_cancel_are_pure, rotation_is_presentation_local,
		confirm_commits_exact_option_once, reserve_selected_updates_real_locations,
		reserve_tile_placement, satchel_two_reserve_slots, survey_selected_spends_charge,
		stale_preview_rejected_atomically, development_occupied_target,
		upgrade_targets_existing_development, transformation_keeps_exact_plan,
		boundary_stones_explicit_preview, distinct_port_relationship_options,
		results_overlay_valid_completed_victory, results_overlay_valid_exemplary,
		pending_choice_locks_ordinary_input,
		cosmetic_notice_dismissal_is_pure]


func _controller() -> GameController:
	var controller: GameController = GameController.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(controller)
	controller.start_run(1010)
	return controller


func _select_playable(controller: GameController) -> void:
	for copy_id: int in controller.session.state.expansion.hand:
		if copy_id != 0 and controller.select_copy(copy_id) and not controller.options.is_empty():
			controller.select_option(0)
			return
	assert(false, "New-run fixture must have a playable hand")


func new_run_and_hand_controls() -> bool:
	var controller: GameController = _controller()
	expect_equal(controller.session.state.phase, GamePhase.Type.TURN_INPUT, "New Run enters live gameplay")
	expect_equal(controller.hand_buttons.size(), 3, "Three mouse-selectable hand slots")
	expect_true(controller.board != null, "Controller owns a synchronized board presentation")
	expect_true(controller.confirm_button.disabled, "No irreversible play without selected preview")
	controller.free()
	return true


func select_queries_exact_authoritative_options() -> bool:
	var controller: GameController = _controller()
	var state: RunState = controller.session.state
	var before: String = StateNormalizer.fingerprint(state)
	var copy_id: int = state.expansion.hand[0]
	controller.hand_buttons[0].pressed.emit()
	var expected: Array[PlacementOption] = controller.session.options(copy_id)
	expect_equal(controller.options.size(), expected.size(), "Hand click consumes complete authoritative query")
	for index: int in range(expected.size()):
		expect_equal(controller.options[index].signature, expected[index].signature, "No lossy coordinate-only option mapping")
	expect_equal(StateNormalizer.fingerprint(state), before, "Selection has no domain side effect")
	controller.free()
	return true


func preview_and_cancel_are_pure() -> bool:
	var controller: GameController = _controller()
	var before: String = StateNormalizer.fingerprint(controller.session.state)
	_select_playable(controller)
	expect_true(controller.preview != null, "Selecting an exact option creates preview")
	expect_equal(StateNormalizer.fingerprint(controller.session.state), before, "Preview changes neither RNG nor board")
	controller.cancel_button.pressed.emit()
	expect_true(controller.preview == null, "Cancel discards presentation preview")
	expect_equal(StateNormalizer.fingerprint(controller.session.state), before, "Cancel changes no authoritative state")
	controller.free()
	return true


func rotation_is_presentation_local() -> bool:
	var controller: GameController = _controller()
	_select_playable(controller)
	var before: String = StateNormalizer.fingerprint(controller.session.state)
	controller.rotate_selection(1)
	controller.rotate_selection(-1)
	expect_equal(StateNormalizer.fingerprint(controller.session.state), before, "Rotation never commits a tile")
	if controller.preview != null:
		expect_true(controller.options.has(controller.preview), "Confirmable preview remains an authoritative option")
	controller.free()
	return true


func confirm_commits_exact_option_once() -> bool:
	var controller: GameController = _controller()
	_select_playable(controller)
	var selected: PlacementOption = controller.preview
	var state: RunState = controller.session.state
	controller.confirm_button.pressed.emit()
	var cell: BoardCellState = state.expansion.board.get_cell(selected.coordinate)
	expect_true(cell != null, "Confirm submits selected target")
	if cell != null:
		expect_equal(cell.base_tile_copy_id, selected.tile_copy_id, "Exact physical copy committed")
		expect_equal(cell.rotation, selected.rotation, "Exact rotation committed")
	var after: String = StateNormalizer.fingerprint(state)
	controller.confirm_button.pressed.emit()
	expect_equal(StateNormalizer.fingerprint(state), after, "Duplicate confirm cannot replay a placement")
	controller.free()
	return true


func reserve_selected_updates_real_locations() -> bool:
	var controller: GameController = _controller()
	var state: RunState = controller.session.state
	var copy_id: int = state.expansion.hand[0]
	controller.select_copy(copy_id)
	var result: ValidationResult = controller.reserve_selected()
	expect_true(result.is_valid, "Reserve mouse action submits authoritative command")
	expect_equal(state.expansion.reserve_id, copy_id, "Physical copy occupies Reserve")
	expect_true(state.expansion.hand[0] != copy_id and state.expansion.hand[0] != 0, "Hand refills through rules")
	controller.free()
	return true


func reserve_tile_placement() -> bool:
	var controller: GameController = _controller()
	_select_playable(controller)
	var copy_id: int = controller.preview.tile_copy_id
	assert(controller.reserve_selected().is_valid)
	expect_true(controller.select_copy(copy_id, TileLocationState.Kind.RESERVE), "Occupied Reserve is selectable")
	controller.select_option(0)
	expect_true(controller.confirm_preview().is_valid, "Reserve preview commits via normal placement command")
	expect_equal(controller.session.state.expansion.reserve_id, 0, "Only played Reserve slot is emptied")
	controller.free()
	return true


func survey_selected_spends_charge() -> bool:
	var controller: GameController = _controller()
	var state: RunState = controller.session.state
	var copy_id: int = state.expansion.hand[0]
	controller.select_copy(copy_id)
	var charges: int = state.expansion.survey_charges
	expect_true(controller.survey_selected().is_valid, "Selected active tile can be Surveyed")
	expect_equal(state.expansion.survey_charges, charges - 1, "Rules spend one Survey charge")
	expect_true(state.expansion.removed_ids.has(copy_id), "Survey removes exact selected physical tile")
	controller.free()
	return true


func stale_preview_rejected_atomically() -> bool:
	var controller: GameController = _controller()
	_select_playable(controller)
	var old: PlacementOption = controller.preview
	# Another authoritative command changes state, as a restored/replaced session could.
	var other_id: int = controller.session.state.expansion.hand[1]
	assert(controller.session.execute(SurveyTileCommand.new(other_id)).validation.is_valid)
	controller.preview = old
	var before: String = StateNormalizer.fingerprint(controller.session.state)
	expect_true(not controller.confirm_preview().is_valid, "Engine rejects stale option rather than trusting ghost")
	expect_equal(StateNormalizer.fingerprint(controller.session.state), before, "Stale failure is atomic")
	expect_true(controller.preview == null, "Stale preview is discarded")
	controller.free()
	return true


func development_occupied_target() -> bool:
	var controller: GameController = _controller()
	var state: RunState = controller.session.state
	var copy_id: int = Acquisition.acquire_hand(state, &"tile.development.housing")
	controller.attach_session(GameSession.new(state, controller.session.content))
	expect_true(controller.select_copy(copy_id), "Development copy selectable")
	var found: bool = false
	for index: int in range(controller.options.size()):
		if controller.options[index].coordinate == Vector2i.ZERO:
			controller.select_option(index)
			found = true
			break
	expect_true(found, "Authoritative query exposes occupied Founding Settlement host")
	if found:
		expect_true(controller.confirm_preview().is_valid, "Development uses selected host intent")
		expect_equal(state.expansion.board.get_cell(Vector2i.ZERO).developments.size(), 1, "Overlay added to existing cell")
	controller.free()
	return true


func boundary_stones_explicit_preview() -> bool:
	var fixture: RefCounted = Geometry.new()
	var content: ContentRegistry = fixture._content()
	var state: RunState = fixture._state(content)
	var copy_id: int = Acquisition.acquire_hand(state, &"tile.hamlet_edge")
	var controller: GameController = _controller()
	controller.attach_session(GameSession.new(state, content))
	controller.select_copy(copy_id)
	var found: bool = false
	for index: int in range(controller.options.size()):
		if controller.options[index].boundary_direction >= 0:
			controller.select_option(index)
			found = true
			break
	expect_true(found, "Special placement survives complete option mapping")
	expect_true(RelicRules.use_available(state, RelicGeometry.BOUNDARY), "Preview does not consume Relic use")
	if found:
		expect_true(controller.confirm_preview().is_valid, "Explicit special mode passes exact Boundary Stones intent")
		expect_true(not RelicRules.use_available(state, RelicGeometry.BOUNDARY), "Use consumed only on commit")
	controller.free()
	return true


func pending_choice_locks_ordinary_input() -> bool:
	var controller: GameController = _controller()
	var state: RunState = controller.session.state
	var copy_id: int = Acquisition.acquire_hand(state, &"tile.forest_belt")
	controller.attach_session(GameSession.new(state, controller.session.content))
	controller.select_copy(copy_id)
	for index: int in range(controller.options.size()):
		if controller.options[index].coordinate == Vector2i.LEFT and controller.options[index].rotation == 1:
			controller.select_option(index)
			break
	assert(controller.confirm_preview().is_valid)
	expect_true(state.pending_choice != null, "Unfinished local feature creates real optional assignment")
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not controller.select_copy(state.expansion.hand[1]), "Required choice blocks unrelated hand selection")
	expect_true(not controller.survey_selected().is_valid, "No normal Survey behind pending modal")
	expect_equal(StateNormalizer.fingerprint(state), before, "Blocked UI actions do not mutate rules")
	controller.free()
	return true


func cosmetic_notice_dismissal_is_pure() -> bool:
	var controller: GameController = _controller()
	var before: String = StateNormalizer.fingerprint(controller.session.state)
	controller.dismiss_notice()
	expect_equal(StateNormalizer.fingerprint(controller.session.state), before, "Cosmetic dismissal has no authoritative command")
	controller.free()
	return true


func upgrade_targets_existing_development() -> bool:
	var content: ContentRegistry = Previous.content()
	var state: RunState = Previous.create(content)
	var at: Vector2i = Acquisition.fields(state, content)
	Acquisition.play(state, content, &"tile.development.monastery", at)
	Previous.decline_assignment(state, content)
	var original: int = state.expansion.board.get_cell(at).developments[0].tile_copy_id
	var copy_id: int = Acquisition.acquire_hand(state, &"tile.development.abbey")
	var controller: GameController = _controller()
	controller.attach_session(GameSession.new(state, content))
	controller.select_copy(copy_id)
	var found: bool = false
	for index: int in range(controller.options.size()):
		if controller.options[index].coordinate == at:
			controller.select_option(index)
			found = true
			break
	expect_true(found, "Upgrade targets the actual existing enclosure")
	if found:
		expect_equal(controller.preview.target_development_copy_id, original, "Preview retains exact replacement identity")
		expect_true(controller.confirm_preview().is_valid, "Upgrade submits complete authoritative intent")
		expect_equal(state.expansion.board.get_cell(at).developments[0].stage,
			&"abbey", "Upgraded stage replaces prior presentation source")
	controller.free()
	return true


func transformation_keeps_exact_plan() -> bool:
	var content: ContentRegistry = Previous.content()
	var state: RunState = Previous.activate(Transformation.river(content))
	var copy_id: int = Acquisition.acquire_hand(state, Transformation.BRIDGE)
	var controller: GameController = _controller()
	controller.attach_session(GameSession.new(state, content))
	controller.select_copy(copy_id)
	var found: bool = false
	for index: int in range(controller.options.size()):
		if controller.options[index].coordinate == Vector2i.DOWN and controller.options[index].transformation_mode == &"bridge":
			controller.select_option(index)
			found = true
			break
	expect_true(found, "Bridge's specialized occupied target appears in legal options")
	if found:
		var before: String = StateNormalizer.fingerprint(state)
		var option: PlacementOption = controller.preview
		var command: PlaceTileCommand = GameController.command_for_option(option, TileLocationState.Kind.ACTIVE_HAND)
		expect_equal(command.transformation_signature, option.transformation_signature, "Exact rewrite signature preserved")
		expect_equal(StateNormalizer.fingerprint(state), before, "Transformation preview does not rewrite board")
		expect_true(controller.confirm_preview().is_valid, "Bridge passes authoritative planned rewrite")
		expect_equal(state.expansion.board.get_cell(Vector2i.DOWN).effective_edges, [2, 3, 2, 3], "Current River and crossing Road preserved")
	controller.free()
	return true


func satchel_two_reserve_slots() -> bool:
	var controller: GameController = _controller()
	var state: RunState = controller.session.state
	assert(RelicRules.acquire(state, controller.session.content, &"relic.wayfarers_satchel").is_valid)
	controller.attach_session(GameSession.new(state, controller.session.content))
	_select_playable(controller)
	var first: int = controller.preview.tile_copy_id
	expect_true(controller.reserve_selected(0).is_valid, "First Reserve action works with Satchel")
	_select_playable(controller)
	var second: int = controller.preview.tile_copy_id
	expect_true(controller.reserve_selected(1).is_valid, "Second Reserve action uses same authoritative command")
	expect_equal(state.expansion.reserve_id, first, "First reserved physical copy remains committed")
	expect_equal(state.expansion.reserve_extra_id, second, "Extra slot holds second physical copy")
	expect_true(controller.shell.reserve_buttons[1].visible, "Second Reserve has a visible mouse control")
	controller.select_copy(second, TileLocationState.Kind.RESERVE)
	controller.select_option(0)
	expect_true(controller.confirm_preview().is_valid, "Second Reserve copy is independently placeable")
	expect_equal(state.expansion.reserve_id, first, "Placing extra slot preserves first Reserve")
	expect_equal(state.expansion.reserve_extra_id, 0, "Only extra slot empties")
	controller.free()
	return true


func distinct_port_relationship_options() -> bool:
	var content: ContentRegistry = Previous.content()
	var state: RunState = Previous.create(content, 2)
	Acquisition.complete_settlement(state, content)
	Geography.add(state, content, &"tile.river_end", Vector2i(1, -1), 1)
	Geography.add(state, content, &"tile.river_end", Vector2i(-1, -1), 3)
	var copy_id: int = Acquisition.acquire_hand(state, &"tile.development.port")
	var controller: GameController = _controller()
	controller.attach_session(GameSession.new(state, content))
	controller.select_copy(copy_id)
	var labels: Array[String] = []
	var rivers: Array[int] = []
	var before: String = StateNormalizer.fingerprint(state)
	for index: int in range(controller.options.size()):
		var option: PlacementOption = controller.options[index]
		if option.coordinate != Vector2i.UP:
			continue
		controller.select_option(index)
		var label: String = controller._option_text(controller.preview)
		expect_true(not labels.has(label), "Same-cell Port choices name their distinct River relationship")
		labels.append(label)
		rivers.append(option.river_lineage_id)
		var command: PlaceTileCommand = GameController.command_for_option(controller.preview, TileLocationState.Kind.ACTIVE_HAND)
		expect_equal(command.river_lineage_id, option.river_lineage_id, "Selected River identity survives command conversion")
		expect_true(controller.session.validate(command).is_valid, "Every individually selected relationship remains legal")
	expect_equal(labels.size(), 3, "Three same-cell River alternatives stay separately selectable")
	expect_equal(StateNormalizer.fingerprint(state), before, "Inspecting alternative relationships is pure")
	if rivers.size() == 3:
		expect_true(controller.confirm_preview().is_valid, "Confirm retains final selected River intent")
		expect_equal(state.expansion.board.get_cell(Vector2i.UP).developments[0].river_lineage_id,
			rivers[-1], "Committed Port uses the specifically selected River")
	controller.free()
	return true


func results_overlay_valid_completed_victory() -> bool:
	return _assert_completed_results(1, "Victory")


func results_overlay_valid_exemplary() -> bool:
	return _assert_completed_results(2, "Exemplary Victory")


func _assert_completed_results(outcome: int, title: String) -> bool:
	var content: ContentRegistry = ThreeActs.content()
	var state: RunState = ThreeActs.scripted(content, ThreeActs.RUN_SEED, outcome).state
	var controller: GameController = _controller()
	controller.attach_session(GameSession.new(state, content))
	var before: String = StateNormalizer.fingerprint(state)
	var board: BoardView = controller.board
	expect_true(controller.results_active, "Completed valid fixture displays results immediately")
	expect_true(controller.shell.notice_text.text.contains(title), "Overlay displays authoritative victory result")
	expect_true(controller.shell.notice_text.text.contains(str(state.final_result.score)), "Overlay includes stored final score")
	for button: Button in controller.hand_buttons:
		expect_true(button.disabled, "Hand input stays locked after run end")
	expect_true(controller.confirm_button.disabled, "No further placement after run end")
	controller.shell.notice_button.pressed.emit()
	expect_true(not controller.results_active, "Results button reveals final map")
	expect_true(controller.board == board, "Map view retains existing board presentation")
	expect_equal(controller.session.state.phase, GamePhase.Type.RUN_COMPLETE, "Map inspection never resumes gameplay")
	controller.shell.results_button.pressed.emit()
	expect_true(controller.results_active, "Visible Results control returns to summary")
	expect_equal(StateNormalizer.fingerprint(state), before, "Map/result navigation does not reevaluate or mutate rules")
	controller.free()
	return true
