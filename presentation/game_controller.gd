class_name GameController
extends Control
## Sole graphical command boundary. Selection, notices and previews are disposable.

signal state_synced
signal command_finished(report: ResolutionResult)

var session: GameSession
var shell: GameShell
var board: BoardView
var assets: TileArtRegistry
var charter_popout: CharterPopout
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
	charter_popout = CharterPopout.new()
	shell.charter_bounds.add_child(charter_popout)
	charter_popout.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	charter_popout.offset_left = -360
	charter_popout.offset_right = -2
	charter_popout.hide()
	charter_popout.close_requested.connect(close_charter)
	board = BoardView.new()
	shell.board_viewport.add_child(board)
	board.coordinate_clicked.connect(choose_coordinate)
	board.coordinate_hovered.connect(_inspect_coordinate)
	choice_presenter = PendingChoicePresenter.new()
	choice_presenter.custom_minimum_size = Vector2(900, 600)
	shell.modal_layer.add_child(choice_presenter)
	choice_presenter.hide()
	choice_presenter.command_requested.connect(submit)
	choice_presenter.inspect_charter_requested.connect(show_charter)
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
	shell.zoom_in_button.pressed.connect(zoom_board.bind(1.12))
	shell.zoom_out_button.pressed.connect(zoom_board.bind(1.0 / 1.12))
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
	charter_popout.hide()
	shell.inspection_panel.hide()
	shell.dismiss_feedback()
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
		if session.state.expansion.board.cells.has(coordinate):
			shell.show_inspection(shell.inspection_label.text)


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
	if charter_popout.visible and session.state.pending_choice != null:
		return ValidationResult.failure(&"presentation_busy", "Close the information panel to return to your choice.")
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
		shell.show_feedback(report.validation.user_message)
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
	var hud: Dictionary = PresentationQueries.hud_model(state, content)
	shell.act_label.text = ("Entering Act " if hud.incoming else "Act ") + ["I", "II", "III"][hud.act - 1]
	shell.act_placements_label.text = "%d / %d placements" % [hud.used, hud.limit]
	shell.act_progress.max_value = hud.limit
	shell.act_progress.value = hud.used
	for index: int in range(4):
		var track: Dictionary = hud.tracks[index]
		shell.track_value_labels[index].text = str(track.value)
		shell.track_bars[index].max_value = track.next_threshold if track.next_threshold > 0 else maxi(100, track.value)
		shell.track_bars[index].value = track.value
		shell.track_reward_labels[index].text = "%d · %s" % [track.next_threshold, track.next_reward] if track.next_threshold > 0 else "Rewards complete"
	shell.charter_summary.text = hud.charter_name
	shell.charter_conditions_label.text = "%d / %d conditions" % [hud.satisfied, hud.conditions]
	shell.next_draft_label.text = "Draft in %d placement%s" % [hud.draft_distance, "" if hud.draft_distance == 1 else "s"] if hud.next_draft > 0 else "No more drafts this Act"
	shell.side_label.text = "Next Tile Draft: after placement %d" % hud.next_draft if hud.next_draft > 0 else "No more Tile Drafts this Act"
	shell.charter_button.tooltip_text = "Read conditions, progress and rewards"
	shell.survey_button.text = "Survey · %d" % state.expansion.survey_charges
	shell.bag_label.text = "Bag\n%d" % state.expansion.bag.size()
	shell.hand_header.text = "Your Hand (%d tiles)" % (3 - state.expansion.hand.count(0))
	_sync_pieces()
	if charter_popout.visible:
		charter_popout.sync(state, content)
	for index: int in range(3):
		var copy_id: int = state.expansion.hand[index]
		hand_buttons[index].text = "%d · %s" % [index + 1, _tile_name(copy_id)]
		hand_buttons[index].icon = _thumbnail(copy_id)
		hand_buttons[index].tooltip_text = _tile_help(copy_id)
	var reserve_ids: Array[int] = [state.expansion.reserve_id, state.expansion.reserve_extra_id]
	shell.reserve_header.text = "Reserve (%d/%d)" % [2 - reserve_ids.count(0), RelicHandRules.reserve_capacity(state)]
	for index: int in range(2):
		var available_slot: bool = index < RelicHandRules.reserve_capacity(state)
		shell.reserve_buttons[index].visible = available_slot
		shell.reserve_actions[index].visible = available_slot
		shell.reserve_buttons[index].text = _tile_name(reserve_ids[index])
		shell.reserve_buttons[index].tooltip_text = _tile_help(reserve_ids[index])
		shell.reserve_buttons[index].icon = _thumbnail(reserve_ids[index])
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
	var inspecting_choice: bool = charter_popout.visible and session.state.pending_choice != null
	choice_presenter.set_information_overlay_open(inspecting_choice)
	shell.charter_layer.mouse_filter = Control.MOUSE_FILTER_STOP if inspecting_choice else Control.MOUSE_FILTER_IGNORE
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
		AlphaTheme.selected(hand_buttons[index], selected_copy_id != 0 and selected_copy_id == session.state.expansion.hand[index])
	var reserve_ids: Array[int] = [session.state.expansion.reserve_id, session.state.expansion.reserve_extra_id]
	for index: int in range(2):
		shell.reserve_buttons[index].disabled = not active or reserve_ids[index] == 0
		AlphaTheme.selected(shell.reserve_buttons[index], selected_copy_id != 0 and selected_copy_id == reserve_ids[index])
		shell.reserve_actions[index].disabled = not active or not session.validate(ReserveTileCommand.new(selected_copy_id, index)).is_valid
	shell.survey_button.disabled = not active or not session.validate(SurveyTileCommand.new(selected_copy_id)).is_valid
	shell.cycle_button.disabled = not active or not session.validate(CycleDeadHandCommand.new()).is_valid
	shell.cycle_button.visible = not shell.cycle_button.disabled
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
		shell.selection_label.text = "Choose a hand or Reserve tile"
	elif options.is_empty():
		shell.selection_label.text = _tile_name(selected_copy_id) + " — no legal placement now. Try another tile, Reserve or Survey."
	else:
		shell.selection_label.text = _tile_name(selected_copy_id) + " · " + str(options.size()) + " legal options" \
			+ (" · Preview: " + _option_text(preview) if preview != null else " · Choose a highlighted target")
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
		shell.board_container.tooltip_text = shell.inspection_label.text


func fit_board() -> void:
	if board != null:
		var available: Vector2 = Vector2(shell.board_viewport.size)
		var covered: float = charter_popout.size.x if charter_popout.visible else 0.0
		available.x -= covered
		board.fit_board(available)
		board.camera.position.x += covered * 0.5 / board.camera.zoom.x


func zoom_board(factor: float) -> void:
	if board != null:
		board.camera.zoom = Vector2.ONE * clampf(board.camera.zoom.x * factor, BoardView.MIN_ZOOM, 3.5)


func show_charter() -> void:
	if session == null:
		return
	if charter_popout.visible:
		close_charter()
		return
	charter_popout.sync(session.state, session.content)
	charter_popout.show()
	shell.notice_text.text = PresentationQueries.charter_text(session.state, session.content)
	_refresh_selection()
	charter_popout.close_button.grab_focus()


func close_charter() -> void:
	charter_popout.hide()
	_refresh_selection()
	if session != null and session.state.pending_choice != null:
		if choice_presenter.charter_button.is_visible_in_tree():
			choice_presenter.charter_button.grab_focus()
		elif not choice_presenter.option_buttons.is_empty():
			choice_presenter.option_buttons[0].grab_focus()
	else:
		shell.charter_button.grab_focus()


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
	if charter_popout.visible:
		close_charter()
		return
	if results_active:
		show_final_map()
		return
	notice_active = false
	if session != null and session.state.pending_choice != null:
		shell.notice_panel.hide()
		choice_presenter.show()
		shell.modal_layer.show()
		_refresh_selection()
		return
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
	var completions: Array[String] = []
	var names: Array[String] = ["Population", "Trade", "Culture", "Ecology"]
	for index: int in range(4):
		if report.track_deltas[index] != 0:
			texts.append("%s %+d" % [names[index], report.track_deltas[index]])
	board.highlighted_coordinates.clear()
	for cue: Dictionary in report.cues:
		var kind: String = String(cue.get("kind", ""))
		var details: Dictionary = cue.get("details", {})
		if "completed" in kind:
			var lineage: FeatureLineageState = session.state.features.lineage(int(cue.get("lineage_id", 0)))
			var title: String = (ChoiceText.feature_name(lineage.feature_type) if lineage != null else "Enclosure") + " completed!"
			if not completions.has(title):
				completions.append(title)
		if kind == "tile_draft_resolved":
			var tile: TileDefinition = session.content.get_tile(StringName(details.get("definition_id", "")))
			if tile != null:
				texts.append("%s added to the bag." % tile.display_name)
			continue
		if kind == "track_threshold_crossed":
			var config: RunConfig = session.content.get_config()
			var threshold_index: int = config.track_thresholds.find(int(details.get("threshold", -1)))
			if threshold_index >= 0 and config.track_threshold_reward_kinds[threshold_index] == &"none":
				continue
		if "triggered" in kind or "returned" in kind or "threshold" in kind or "milestone" in kind or "reward_offered" in kind:
			var caption: String = kind.replace("_", " ").capitalize()
			if not texts.has(caption):
				texts.append(caption)
		if "complet" in kind:
			for component: FeatureComponentState in session.state.features.components:
				if component.lineage_id == int(cue.get("lineage_id", 0)):
					board.highlighted_coordinates.append(component.coordinate)
	board.queue_redraw()
	texts = completions + texts
	if not texts.is_empty():
		shell.show_feedback("\n".join(texts.slice(0, 4)), "\n".join(texts))


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
	elif key_event.keycode == KEY_ESCAPE and charter_popout.visible:
		close_charter()
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


func _tile_help(copy_id: int) -> String:
	var copy: TileCopyState = PhysicalTileRules.find_copy(session.state, copy_id)
	if copy == null:
		return "Empty slot"
	var definition: TileDefinition = session.content.get_tile(copy.definition_id)
	return definition.display_name + "\n" + ChoiceText.tile_help(definition)


func _sync_pieces() -> void:
	var state: RunState = session.state
	var equipped_count: int = 0
	for slot: int in range(shell.relic_slot_buttons.size()):
		var button: Button = shell.relic_slot_buttons[slot]
		button.visible = state.relics != null and slot < state.relics.capacity
		button.text = "+"
		button.tooltip_text = "Empty Relic slot"
		if state.relics == null:
			continue
		for relic: RelicInstanceState in state.relics.instances:
			if relic.equipped_slot != slot:
				continue
			equipped_count += 1
			var definition: RelicDefinition = session.content.get_relic(relic.definition_id)
			var words: PackedStringArray = definition.display_name.split(" ")
			var initials: String = ""
			for word: String in words:
				initials += word.left(1)
			button.text = initials.left(3)
			button.tooltip_text = definition.display_name + "\n" + ChoiceText.description(relic.definition_id)
			if relic.once_per_act:
				button.tooltip_text += "\n%d use(s) remaining this Act" % relic.uses_remaining
	var capacity: int = state.relics.capacity if state.relics != null else 0
	shell.relic_header.text = "Relics (%d/%d)" % [equipped_count, capacity]
	var available: int = 0
	var total: int = state.specialists.pieces.size() if state.specialists != null else 0
	for index: int in range(shell.steward_slot_buttons.size()):
		var button: Button = shell.steward_slot_buttons[index]
		button.visible = index < total
		if index >= total:
			continue
		var piece: SpecialistPieceState = state.specialists.pieces[index]
		var is_available: bool = piece.status == SpecialistPieceState.Status.AVAILABLE
		available += int(is_available)
		var role: String = "Steward" if piece.role_definition_id.is_empty() else session.content.get_specialist(piece.role_definition_id).display_name
		button.text = role.left(2) + ("○" if is_available else "●")
		button.theme_type_variation = &"Button" if is_available else &"WoodButton"
		button.tooltip_text = role + ("\nAvailable" if is_available else "\nAssigned: " + ChoiceText.target_label(state, piece.assigned_target_type, piece.assigned_target_id))
		if not is_available:
			for component: FeatureComponentState in state.features.components:
				if component.lineage_id == piece.assigned_target_id:
					button.tooltip_text += "\nAt (%d, %d)" % [component.coordinate.x, component.coordinate.y]
					break
	shell.steward_header.text = "Stewards (%d/%d)" % [available, total]
