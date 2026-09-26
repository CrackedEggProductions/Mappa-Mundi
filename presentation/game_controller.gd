class_name GameController
extends Control
## Sole graphical command boundary. Selection, notices and previews are disposable.

signal state_synced
signal command_finished(report: ResolutionResult)

var session: GameSession
var shell: GameShell
var board: BoardView
var assets: TileArtRegistry
var choice_presenter: PendingChoicePresenter
var hand_buttons: Array[Button] = []
var confirm_button: Button
var cancel_button: Button
var options: Array[PlacementOption] = []
var preview: PlacementOption = null
var selected_copy_id: int = 0
var selected_source: TileLocationState.Kind = TileLocationState.Kind.ACTIVE_HAND
var selected_rotation: int = 0
var notice_active: bool = false
var results_active: bool = false
var _busy: bool = false
var _built: bool = false
var _notices: Array[String] = []
var _menu_indices: Array[int] = []
var _entry: CenterContainer
var _seed: LineEdit
var _entry_error: Label
var _registry: ContentRegistry


func _ready() -> void:
	ensure_ui()
	get_window().min_size = Vector2i(1280, 720)


func ensure_ui() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	assets = TileArtRegistry.new()
	shell = GameShell.new()
	add_child(shell)
	shell.build()
	board = BoardView.new()
	shell.board_viewport.add_child(board)
	board.coordinate_clicked.connect(choose_coordinate)
	board.coordinate_hovered.connect(_inspect_coordinate)
	choice_presenter = PendingChoicePresenter.new()
	choice_presenter.custom_minimum_size = Vector2(900, 600)
	shell.modal_layer.add_child(choice_presenter)
	choice_presenter.hide()
	choice_presenter.command_requested.connect(submit)
	hand_buttons = shell.hand_buttons
	confirm_button = shell.confirm_button
	cancel_button = shell.cancel_button
	for index: int in range(3):
		hand_buttons[index].pressed.connect(_select_hand.bind(index))
	for index: int in range(2):
		shell.reserve_buttons[index].pressed.connect(_select_reserve.bind(index))
		shell.reserve_actions[index].pressed.connect(reserve_selected.bind(index))
	shell.survey_button.pressed.connect(survey_selected)
	shell.cycle_button.pressed.connect(cycle_dead_hand)
	shell.fit_button.pressed.connect(fit_board)
	shell.charter_button.pressed.connect(show_charter)
	shell.results_button.pressed.connect(show_results)
	shell.new_run_button.pressed.connect(func() -> void:
		shell.hide()
		_entry.show())
	shell.rotate_left.pressed.connect(rotate_selection.bind(-1))
	shell.rotate_right.pressed.connect(rotate_selection.bind(1))
	confirm_button.pressed.connect(confirm_preview)
	cancel_button.pressed.connect(cancel_preview)
	shell.option_menu.item_selected.connect(_select_menu_option)
	shell.notice_button.pressed.connect(dismiss_notice)
	_build_entry()
	shell.hide()


func _build_entry() -> void:
	_entry = CenterContainer.new()
	_entry.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_entry.theme = shell.theme
	add_child(_entry)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = 610
	_entry.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	var title: Label = GameShell.label("Mappa Mundi", column)
	title.add_theme_font_size_override("font_size", 48)
	GameShell.label("Build one realm across three Acts.", column)
	GameShell.label("Run seed (same seed and choices reproduce a run)", column)
	_seed = LineEdit.new()
	_seed.text = "1"
	_seed.placeholder_text = "Integer seed"
	column.add_child(_seed)
	GameShell.button("New Run", column).pressed.connect(_new_run_clicked)
	GameShell.label("Mouse: select → preview → Confirm\nWheel: zoom · Middle/right drag: pan\nQ/E: rotate · Enter: confirm · F: fit board", column)
	_entry_error = GameShell.label("", column)


func _new_run_clicked() -> void:
	if not _seed.text.is_valid_int():
		_entry_error.text = "Enter an integer seed."
		return
	start_run(_seed.text.to_int())


func start_run(seed_value: int) -> void:
	ensure_ui()
	_registry = ContentRegistry.new()
	var loaded: ValidationResult = _registry.load_phase_nine()
	if not loaded.is_valid:
		push_error(loaded.user_message)
		_entry_error.text = loaded.user_message
		return
	attach_session(GameSession.start(seed_value, _registry))
	fit_board.call_deferred()


func attach_session(value: GameSession) -> void:
	ensure_ui()
	session = value
	_registry = value.content
	var mapping: Dictionary = assets.mapping_report(_registry)
	print("Presentation art: %d anchors, %d references, %d mechanical fallbacks" % [mapping.production_anchors.size(), mapping.references.size(), mapping.fallbacks.size()])
	for path: String in mapping.missing:
		print("Missing optional presentation asset; using fallback: ", path)
	_entry.hide()
	shell.show()
	_notices.clear()
	notice_active = false
	results_active = false
	_clear_selection()
	_sync()


func _input_available() -> bool:
	return session != null and not _busy and not notice_active and not results_active \
		and session.state.phase in [GamePhase.Type.TURN_INPUT, GamePhase.Type.BONUS_INPUT]


func select_copy(copy_id: int, source: TileLocationState.Kind = TileLocationState.Kind.ACTIVE_HAND) -> bool:
	if not _input_available():
		return false
	var location: TileLocationState = null
	for entry: TileLocationState in session.state.tile_locations:
		if entry.tile_copy_id == copy_id:
			location = entry
			break
	if location == null or location.kind != source or source not in [TileLocationState.Kind.ACTIVE_HAND, TileLocationState.Kind.RESERVE]:
		return false
	selected_copy_id = copy_id
	selected_source = source
	options = session.options(copy_id)
	preview = null
	selected_rotation = options[0].rotation if not options.is_empty() else 0
	_refresh_selection()
	return true


func select_option(index: int) -> void:
	if not _input_available() or index < 0 or index >= options.size():
		return
	preview = options[index]
	selected_rotation = preview.rotation
	_refresh_selection()


func choose_coordinate(coordinate: Vector2i) -> void:
	if not _input_available():
		_inspect_coordinate(coordinate)
		return
	var fallback: int = -1
	for index: int in range(options.size()):
		if options[index].coordinate != coordinate:
			continue
		if fallback == -1:
			fallback = index
		if options[index].rotation == selected_rotation:
			select_option(index)
			return
	if fallback >= 0:
		select_option(fallback)
	else:
		_inspect_coordinate(coordinate)


func rotate_selection(delta: int) -> void:
	if not _input_available() or options.is_empty():
		return
	# Symmetric rotations may be deduplicated by the authoritative query.
	for distance: int in range(1, 5):
		var wanted: int = posmod(selected_rotation + delta * distance, 4)
		for index: int in range(options.size()):
			if options[index].rotation == wanted and (preview == null or options[index].coordinate == preview.coordinate):
				selected_rotation = wanted
				if preview != null:
					preview = options[index]
				_refresh_selection()
				return


func cancel_preview() -> void:
	preview = null
	if shell != null:
		_refresh_selection()


func confirm_preview() -> ValidationResult:
	if not _input_available() or preview == null:
		return ValidationResult.failure(&"no_preview", "Choose a legal target before confirming.")
	return submit(command_for_option(preview, selected_source))


static func command_for_option(option: PlacementOption, source: TileLocationState.Kind) -> PlaceTileCommand:
	var command: PlaceTileCommand = PlaceTileCommand.new(option.tile_copy_id, source, option.coordinate, option.rotation)
	command.placement_mode = option.placement_mode
	command.expected_board_revision = option.board_revision
	command.expected_state_revision = option.state_revision
	command.expected_signature = option.signature
	command.host_lineage_id = option.host_lineage_id
	command.river_lineage_id = option.river_lineage_id
	command.target_development_copy_id = option.target_development_copy_id
	command.enclosure_id = option.enclosure_id
	command.boundary_direction = option.boundary_direction
	command.transformation_mode = option.transformation_mode
	command.target_base_copy_id = option.target_base_copy_id
	command.transformation_signature = option.transformation_signature
	return command


func reserve_selected(slot: int = -1) -> ValidationResult:
	return submit(ReserveTileCommand.new(selected_copy_id, slot))


func survey_selected() -> ValidationResult:
	return submit(SurveyTileCommand.new(selected_copy_id))


func cycle_dead_hand() -> ValidationResult:
	return submit(CycleDeadHandCommand.new())


func submit(command: PlayerCommand) -> ValidationResult:
	if session == null or _busy or notice_active or results_active:
		return ValidationResult.failure(&"presentation_busy", "Finish the current choice or notice first.")
	_busy = true
	var report: ResolutionResult = session.execute(command)
	_busy = false
	_clear_selection()
	if report.validation.is_valid:
		if session.state.expansion.current_act != report.previous_act:
			_notices.append(PresentationQueries.transition_text(session.state, session.content, report.previous_act))
		if session.state.charters != null and session.state.charters.exact_revealed and not report.previous_grand_revealed:
			_notices.append("Grand Charter revealed\n\n" + PresentationQueries.charter_text(session.state, session.content))
	elif report.validation.error_code == &"invariant_failure":
		push_error(report.validation.user_message + " " + str(report.validation.debug_details))
	_sync()
	if report.validation.is_valid:
		_play_cues(report)
	else:
		shell.feedback_label.text = report.validation.user_message
	command_finished.emit(report)
	return report.validation


func _clear_selection() -> void:
	selected_copy_id = 0
	preview = null
	options.clear()


func _sync() -> void:
	var state: RunState = session.state
	var content: ContentRegistry = session.content
	board.sync(state, content, assets)
	shell.act_label.text = "Mappa Mundi  ·  Act %d  ·  %d placed / %d remaining" % [
		state.expansion.current_act, state.expansion.normal_placements,
		content.get_config().act_placement_limits[state.expansion.current_act - 1] - state.expansion.normal_placements]
	shell.tracks_label.text = "Population %d   Trade %d   Culture %d   Ecology %d" % state.features.tracks.values
	shell.side_label.text = "Relics\n" + PresentationQueries.relics_text(state, content) \
		+ "\n\nStewards & Specialists\n" + PresentationQueries.specialists_text(state, content) \
		+ "\n\nSurvey charges: %d\nBag: %d tiles" % [state.expansion.survey_charges, state.expansion.bag.size()]
	shell.charter_button.tooltip_text = PresentationQueries.charter_text(state, content)
	var objective: Dictionary = CharterRules.visible_grand(state, content) if state.expansion.current_act == 3 else CharterRules.visible_ordinary(state, content)
	var progress: Dictionary = objective.get("progress", {})
	var progress_status: String = String(progress.get("overall_state", "failed"))
	shell.charter_summary.text = String(objective.get("display_name", "Charter")) + " · " + ("Incomplete" if progress_status == "failed" else progress_status.capitalize()) + " · Open Charter for conditions and progress"
	shell.charter_summary.tooltip_text = shell.charter_button.tooltip_text
	for index: int in range(3):
		var copy_id: int = state.expansion.hand[index]
		hand_buttons[index].text = "%d · %s" % [index + 1, _tile_name(copy_id)]
		hand_buttons[index].icon = _thumbnail(copy_id)
		hand_buttons[index].tooltip_text = _tile_name(copy_id)
	var reserve_ids: Array[int] = [state.expansion.reserve_id, state.expansion.reserve_extra_id]
	for index: int in range(2):
		var available_slot: bool = index < RelicHandRules.reserve_capacity(state)
		shell.reserve_buttons[index].visible = available_slot
		shell.reserve_actions[index].visible = available_slot
		shell.reserve_buttons[index].text = _tile_name(reserve_ids[index])
		shell.reserve_buttons[index].tooltip_text = _tile_name(reserve_ids[index])
		shell.reserve_actions[index].tooltip_text = "Commit the selected hand tile to this Reserve slot; immediately draw a replacement."
	shell.results_button.visible = state.phase == GamePhase.Type.RUN_COMPLETE
	shell.new_run_button.visible = state.phase == GamePhase.Type.RUN_COMPLETE
	choice_presenter.sync(state, content)
	if state.pending_choice != null:
		shell.modal_layer.show()
		shell.notice_panel.hide()
		choice_presenter.show()
	elif state.phase == GamePhase.Type.RUN_COMPLETE:
		show_results()
	else:
		_show_next_notice()
	_refresh_selection()
	state_synced.emit()


func _refresh_selection() -> void:
	if session == null:
		return
	var active: bool = _input_available()
	board.interaction_enabled = not notice_active and not results_active and session.state.pending_choice == null
	board.set_options(options)
	board.clear_preview()
	if preview != null:
		board.set_preview(preview, session.state, session.content, assets)
	confirm_button.disabled = not active or preview == null
	cancel_button.disabled = preview == null
	shell.rotate_left.disabled = not active or options.is_empty()
	shell.rotate_right.disabled = shell.rotate_left.disabled
	for index: int in range(3):
		hand_buttons[index].disabled = not active or session.state.expansion.hand[index] == 0
	var reserve_ids: Array[int] = [session.state.expansion.reserve_id, session.state.expansion.reserve_extra_id]
	for index: int in range(2):
		shell.reserve_buttons[index].disabled = not active or reserve_ids[index] == 0
		shell.reserve_actions[index].disabled = not active or not session.validate(ReserveTileCommand.new(selected_copy_id, index)).is_valid
	shell.survey_button.disabled = not active or not session.validate(SurveyTileCommand.new(selected_copy_id)).is_valid
	shell.cycle_button.disabled = not active or not session.validate(CycleDeadHandCommand.new()).is_valid
	shell.option_menu.clear()
	_menu_indices.clear()
	for index: int in range(options.size()):
		var option: PlacementOption = options[index]
		if preview != null and option.coordinate != preview.coordinate:
			continue
		shell.option_menu.add_item(_option_text(option))
		_menu_indices.append(index)
		if option == preview:
			shell.option_menu.select(_menu_indices.size() - 1)
	shell.option_menu.disabled = not active or options.is_empty()
	if selected_copy_id == 0:
		shell.selection_label.text = "Select a hand or Reserve tile, choose a target, then Confirm."
	elif options.is_empty():
		shell.selection_label.text = _tile_name(selected_copy_id) + " — no legal placement now. Try another tile, Reserve or Survey."
	else:
		shell.selection_label.text = _tile_name(selected_copy_id) + " · " + str(options.size()) + " legal options" \
			+ (" · Preview: " + _option_text(preview) if preview != null else " · Choose a highlighted target or option below.")
	shell.selection_label.tooltip_text = shell.selection_label.text
	shell.option_menu.tooltip_text = _option_text(preview) if preview != null else "Choose an exact location, rotation and mode."


func _option_text(option: PlacementOption) -> String:
	var mode_text: String = ["Expansion", "Development", "Upgrade", "Transformation"][option.placement_mode]
	if not option.transformation_mode.is_empty():
		mode_text = String(option.transformation_mode).replace("_", " ").capitalize()
	if option.boundary_direction >= 0:
		mode_text += " · Use Boundary Stones"
	if option.target_development_copy_id > 0:
		mode_text += " · replace " + _tile_name(option.target_development_copy_id)
	if option.host_lineage_id > 0:
		var host: FeatureLineageState = session.state.features.lineage(option.host_lineage_id)
		if host != null:
			mode_text += " · " + ChoiceText.target_label(session.state, host.feature_type, option.host_lineage_id)
	if option.river_lineage_id > 0:
		mode_text += " · " + ChoiceText.target_label(session.state, DomainTypes.FeatureType.RIVER, option.river_lineage_id)
	return "(%d, %d) · %d° · %s" % [option.coordinate.x, option.coordinate.y, option.rotation * 90, mode_text]


func _select_hand(index: int) -> void:
	if session != null:
		select_copy(session.state.expansion.hand[index])


func _select_reserve(index: int) -> void:
	if session != null:
		select_copy(session.state.expansion.reserve_id if index == 0 else session.state.expansion.reserve_extra_id, TileLocationState.Kind.RESERVE)


func _select_menu_option(index: int) -> void:
	if index >= 0 and index < _menu_indices.size():
		select_option(_menu_indices[index])


func _tile_name(copy_id: int) -> String:
	var copy: TileCopyState = PhysicalTileRules.find_copy(session.state, copy_id)
	return "Empty" if copy == null else session.content.get_tile(copy.definition_id).display_name


func _thumbnail(copy_id: int) -> Texture2D:
	var copy: TileCopyState = PhysicalTileRules.find_copy(session.state, copy_id)
	return null if copy == null else assets.thumbnail(copy.definition_id, session.content)


func _inspect_coordinate(coordinate: Vector2i) -> void:
	if session != null and session.state.expansion.board.cells.has(coordinate):
		shell.inspection_label.text = PresentationQueries.inspect_tile(session.state, session.content, coordinate)


func fit_board() -> void:
	if board != null:
		board.fit_board(Vector2(shell.board_viewport.size))


func show_charter() -> void:
	if session == null or session.state.pending_choice != null:
		return
	_notices.append(PresentationQueries.charter_text(session.state, session.content))
	_show_next_notice()
	_refresh_selection()


func _show_next_notice() -> void:
	choice_presenter.hide()
	if _notices.is_empty():
		notice_active = false
		shell.modal_layer.hide()
		return
	notice_active = true
	shell.notice_panel.show()
	shell.modal_layer.show()
	shell.notice_text.text = _notices.pop_front()
	shell.notice_button.text = "Continue"


func dismiss_notice() -> void:
	if results_active:
		show_final_map()
		return
	notice_active = false
	_show_next_notice()
	_refresh_selection()


func show_results() -> void:
	if session == null or session.state.final_result == null:
		return
	results_active = true
	notice_active = false
	choice_presenter.hide()
	shell.modal_layer.show()
	shell.notice_panel.show()
	shell.notice_text.text = PresentationQueries.results_text(session.state, session.content)
	shell.notice_button.text = "View the final map"
	_refresh_selection()


func show_final_map() -> void:
	results_active = false
	notice_active = false
	shell.modal_layer.hide()
	_refresh_selection()
	fit_board()


func _play_cues(report: ResolutionResult) -> void:
	var texts: Array[String] = []
	var names: Array[String] = ["Population", "Trade", "Culture", "Ecology"]
	for index: int in range(4):
		if report.track_deltas[index] != 0:
			texts.append("%s %+d" % [names[index], report.track_deltas[index]])
	board.highlighted_coordinates.clear()
	for cue: Dictionary in report.cues:
		var kind: String = String(cue.get("kind", ""))
		if "completed" in kind or "triggered" in kind or "returned" in kind or "threshold" in kind or "milestone" in kind or "reward_offered" in kind:
			var caption: String = kind.replace("_", " ").capitalize()
			if not texts.has(caption):
				texts.append(caption)
		if "complet" in kind:
			for component: FeatureComponentState in session.state.features.components:
				if component.lineage_id == int(cue.get("lineage_id", 0)):
					board.highlighted_coordinates.append(component.coordinate)
	board.queue_redraw()
	shell.feedback_label.text = " · ".join(texts) if not texts.is_empty() else "Action resolved."
	shell.feedback_label.tooltip_text = "\n".join(texts)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F11:
		get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
	elif session != null and key_event.keycode == KEY_F:
		fit_board()
	elif _input_available():
		match key_event.keycode:
			KEY_1, KEY_2, KEY_3: _select_hand(key_event.keycode - KEY_1)
			KEY_Q: rotate_selection(-1)
			KEY_E: rotate_selection(1)
			KEY_ENTER: confirm_preview()
			KEY_ESCAPE: cancel_preview()


func _input(event: InputEvent) -> void:
	# A physical double click must not select a newly-rendered subsequent offer.
	if event is InputEventMouseButton and (event as InputEventMouseButton).double_click:
		get_viewport().set_input_as_handled()
