class_name PendingChoicePresenter
extends PanelContainer
## Snapshot-to-buttons adapter. It never executes commands or changes RunState.

signal command_requested(command: PlayerCommand)
signal unhandled_choice(kind: StringName)
signal inspect_charter_requested

const KINDS: Array[StringName] = [&"specialist_assignment", &"specialist_training",
	&"training_piece", &"tile_reward", &"masterwork", &"major_reward", &"relic_offer",
	&"relic_replacement", &"compass", &"specialist_relay", &"grand_survey", &"tile_draft"]
const TITLES: Dictionary = {
	&"specialist_assignment": "Assign one Steward or Specialist",
	&"specialist_training": "Train this Steward permanently",
	&"training_piece": "Choose a Steward to train",
	&"tile_reward": "Choose a Tile Reward", &"masterwork": "Choose a Masterwork Tile",
	&"major_reward": "Choose a Major Reward", &"relic_offer": "Choose a Relic",
	&"relic_replacement": "Relic capacity is full", &"compass": "Surveyor’s Compass",
	&"specialist_relay": "Steward’s Relay", &"grand_survey": "Grand Survey",
}

var option_buttons: Array[Button] = []
var decline_button: Button
var title_label: Label
var context_label: Label
var error_label: Label
var charter_button: Button
var choice_id: int = 0
var choice_kind: StringName = &""
var state_revision: int = -1
var _commands: Array[PlayerCommand] = []
var _decline: PlayerCommand
var _body: VBoxContainer
var _options_box: GridContainer
var _generation: int = 0
var _submitted: bool = false
var information_overlay_open: bool = false
var _art: TileArtRegistry = TileArtRegistry.new()


func _ensure_controls() -> void:
	if _body != null:
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margins: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 16)
	add_child(margins)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	margins.add_child(_body)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(title_label)
	context_label = Label.new()
	context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(context_label)
	charter_button = Button.new()
	charter_button.text = "Inspect Charter"
	charter_button.tooltip_text = "Read the current objective, then return to these same draft options."
	charter_button.pressed.connect(func() -> void: inspect_charter_requested.emit())
	_body.add_child(charter_button)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	_options_box = GridContainer.new()
	_options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_box.add_theme_constant_override("h_separation", 12)
	_options_box.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_options_box)
	error_label = Label.new()
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.modulate = Color("a55e48")
	_body.add_child(error_label)


func sync(state: RunState, content: ContentRegistry) -> void:
	_ensure_controls()
	_generation += 1
	_submitted = false
	for child: Node in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()
	if decline_button != null:
		_body.remove_child(decline_button)
		decline_button.queue_free()
	decline_button = null
	_commands.clear()
	_decline = null
	option_buttons.clear()
	error_label.text = ""
	choice_id = 0
	choice_kind = &""
	state_revision = -1
	visible = state != null and state.phase == GamePhase.Type.PENDING_CHOICE and state.pending_choice != null
	if not visible:
		return
	var choice: PendingChoice = state.pending_choice
	choice_id = choice.choice_id
	choice_kind = choice.kind
	_options_box.columns = 3 if choice_kind == &"tile_draft" else 1
	custom_minimum_size = Vector2(960, 570) if choice_kind == &"tile_draft" else Vector2(900, 600)
	state_revision = state.expansion.state_revision
	title_label.text = String(TITLES.get(choice_kind, "Unsupported required choice"))
	if choice_kind == &"tile_draft":
		const DRAFT_TITLES: Dictionary = {"starter": "Choose Your First Addition", "cadence": "Tile Draft", "act_entry": "New possibilities"}
		title_label.text = String(DRAFT_TITLES.get(String(choice.context.get("draft_type", "cadence")), "Tile Draft"))
	charter_button.visible = choice_kind == &"tile_draft"
	context_label.text = _context_text(state, content, choice)
	if not KINDS.has(choice_kind):
		error_label.text = "Development error: no presenter for required choice ‘%s’. Please report this; the run is paused safely." % String(choice_kind)
		unhandled_choice.emit(choice_kind)
		return
	for index: int in range(choice.options.size()):
		var option: Dictionary = choice.options[index]
		var command: PlayerCommand = _make_command(choice_kind, option, index)
		command.set("expected_state_revision", state_revision)
		_commands.append(command)
		_add_option(state, content, option, command, index)
	if choice_kind in [&"specialist_assignment", &"specialist_relay"] and bool(choice.context.get("decline_allowed", false)):
		_decline = ResolveSpecialistAssignmentCommand.new(choice_id, 0, -1, 0, true) if choice_kind == &"specialist_assignment" else ResolveRelayCommand.new(choice_id, -1)
		_decline.set("expected_state_revision", state_revision)
		decline_button = Button.new()
		decline_button.text = "Decline — leave the piece available"
		decline_button.custom_minimum_size.y = 42
		decline_button.pressed.connect(_submit.bind(_decline, _generation))
		_body.add_child(decline_button)


func command_for_option(index: int) -> PlayerCommand:
	return _commands[index] if index >= 0 and index < _commands.size() else null


func decline_command() -> PlayerCommand:
	return _decline


func _make_command(kind: StringName, option: Dictionary, index: int) -> PlayerCommand:
	match kind:
		&"tile_draft":
			return ResolveTileDraftCommand.new(choice_id, index)
		&"specialist_assignment":
			return ResolveSpecialistAssignmentCommand.new(choice_id, int(option["piece_id"]), int(option["target_type"]), int(option["target_id"]))
		&"specialist_training":
			return ResolveSpecialistTrainingCommand.new(choice_id, StringName(option["role_definition_id"]))
		&"compass":
			return ResolveCompassCommand.new(choice_id, int(option["tile_copy_id"]))
		&"specialist_relay":
			return ResolveRelayCommand.new(choice_id, index)
		&"grand_survey":
			return ResolveGrandSurveyCommand.new(choice_id, int(option["tile_copy_id"]), bool(option["finish"]))
		_:
			return ResolveRewardCommand.new(choice_id, index)


func _add_option(state: RunState, content: ContentRegistry, option: Dictionary,
		command: PlayerCommand, index: int) -> void:
	if choice_kind == &"tile_draft":
		var card: Button = Button.new()
		card.text = _option_text(state, content, option)
		card.icon = _art.thumbnail(StringName(option["definition_id"]), content)
		card.expand_icon = true
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_theme_constant_override("icon_max_width", 140)
		card.custom_minimum_size = Vector2(285, 290)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tooltip_text = card.text
		card.set_meta("option_index", index)
		card.pressed.connect(_submit.bind(command, _generation))
		_options_box.add_child(card)
		option_buttons.append(card)
		return
	var row: HBoxContainer = HBoxContainer.new()
	# Grid columns expand only when their direct children request the space.
	# Wrapped text otherwise collapses to padding width (notably generic Stewards).
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	_options_box.add_child(row)
	var tile_id: StringName = _tile_id(state, option)
	if tile_id != &"":
		var thumbnail: TextureRect = TextureRect.new()
		thumbnail.texture = _art.thumbnail(tile_id, content)
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.custom_minimum_size = Vector2(80, 80)
		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(thumbnail)
	var button: Button = Button.new()
	button.text = _option_text(state, content, option)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 58
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = button.text
	button.set_meta("option_index", index)
	button.pressed.connect(_submit.bind(command, _generation))
	row.add_child(button)
	option_buttons.append(button)
	if bool(option.get("decline", false)) or bool(option.get("finish", false)):
		_decline = command


func _submit(command: PlayerCommand, generation: int) -> void:
	if generation != _generation or _submitted or information_overlay_open or not visible or command == null:
		return
	_submitted = true
	for button: Button in option_buttons:
		button.disabled = true
	if decline_button != null:
		decline_button.disabled = true
	command_requested.emit(command)


func set_information_overlay_open(value: bool) -> void:
	# Inspection suspends input, not the choice presenter or its saved offer.
	information_overlay_open = value
	for button: Button in option_buttons:
		button.disabled = value or _submitted
	if decline_button != null:
		decline_button.disabled = value or _submitted


func _tile_id(state: RunState, option: Dictionary) -> StringName:
	if choice_kind in [&"tile_reward", &"masterwork", &"tile_draft"]:
		return StringName(option["definition_id"])
	var copy_id: int = int(option.get("tile_copy_id", 0))
	if copy_id > 0:
		var tile: TileCopyState = PhysicalTileRules.find_copy(state, copy_id)
		if tile != null:
			return tile.definition_id
	return &""


func _option_text(state: RunState, content: ContentRegistry, option: Dictionary) -> String:
	if bool(option.get("decline", false)):
		return "Decline the incoming Relic"
	if bool(option.get("finish", false)):
		return "Finish Grand Survey — keep the remaining tiles"
	var tile_id: StringName = _tile_id(state, option)
	if tile_id != &"":
		var tile: TileDefinition = content.get_tile(tile_id)
		const CLASSES: Array[String] = ["Expansion", "Development", "Upgrade", "Transformation"]
		var detail: String = CLASSES[tile.tile_class]
		if choice_kind in [&"tile_reward", &"masterwork"]:
			var count: int = 3 if choice_kind == &"masterwork" else RewardRules.copy_quantity(tile)
			detail += " · %d copies" % count
		elif choice_kind == &"tile_draft":
			detail += " · 1 copy added to the bag"
			detail += "\n" + ChoiceText.tile_help(tile)
		elif choice_kind == &"grand_survey":
			detail += " · remove permanently and replace"
		return tile.display_name + "\n" + detail
	if choice_kind in [&"specialist_assignment", &"specialist_relay"]:
		return "%s → %s" % [ChoiceText.piece_label(state, content, int(option["piece_id"])), ChoiceText.target_label(state, int(option["target_type"]), int(option["target_id"]))]
	if choice_kind == &"training_piece":
		var piece: SpecialistPieceState = state.specialists.piece(int(option["piece_id"]))
		var summary: String = ChoiceText.piece_label(state, content, piece.piece_id)
		if piece.status == SpecialistPieceState.Status.ASSIGNED:
			summary += "\nAssigned: " + ChoiceText.target_label(state, piece.assigned_target_type, piece.assigned_target_id)
		return summary
	if choice_kind == &"specialist_training":
		var role: StringName = StringName(option["role_definition_id"])
		return content.get_specialist(role).display_name + "\n" + ChoiceText.description(role)
	if choice_kind == &"major_reward":
		var major: StringName = StringName(option["major_id"])
		const NAMES: Dictionary = {&"recruit_steward": "Recruit a Steward", &"masterwork": "Masterwork Tile Grant", &"relic_cache": "Relic Cache", &"grand_survey": "Grand Survey"}
		return String(NAMES.get(major, major)) + "\n" + ChoiceText.description(major)
	var id: StringName = StringName(option.get("replace_id", option.get("definition_id", "")))
	var relic: RelicDefinition = content.get_relic(id)
	if relic != null:
		return ("Replace " if option.has("replace_id") else "") + relic.display_name + " · " + String(relic.tier).capitalize() + "\n" + ChoiceText.description(id)
	return "Choice %d" % (option_buttons.size() + 1)


func _context_text(state: RunState, content: ContentRegistry, choice: PendingChoice) -> String:
	match choice.kind:
		&"tile_draft":
			var text: String = "Choose one design. One physical copy joins the bag, then the bag shuffles."
			if choice.context.get("draft_type") == "starter":
				text += " Your opening hand is drawn afterward. Inspect your Charter before choosing."
			elif choice.context.get("draft_type") == "act_entry":
				text += " These are newly unlocked possibilities for this Act."
			return text
		&"specialist_assignment":
			return "Choose one piece and one local unfinished feature, or decline."
		&"specialist_training":
			var piece: SpecialistPieceState = state.specialists.piece(int(choice.context["piece_id"]))
			var text: String = ChoiceText.piece_label(state, content, piece.piece_id) + ". Training is permanent."
			if piece.status == SpecialistPieceState.Status.ASSIGNED:
				text += " Remains assigned to " + ChoiceText.target_label(state, piece.assigned_target_type, piece.assigned_target_id) + "."
			return text
		&"relic_replacement":
			var incoming: StringName = StringName(choice.context["definition_id"])
			return "Incoming: " + content.get_relic(incoming).display_name + "\n" + ChoiceText.description(incoming) + "\nOnly legally removable equipped Relics are listed."
		&"compass":
			return "Choose one inspected physical tile. The others return to the bag, then the bag shuffles."
		&"grand_survey":
			return "%d of 2 removals selected. Replacements happen one at a time; you may finish now. Gain one Survey charge for this Act." % choice.context.get("chosen_removals", []).size()
		&"specialist_relay":
			return "Reassign the same returned piece to one legal touching unfinished feature, or decline."
	return "Choose one of the offered options."
