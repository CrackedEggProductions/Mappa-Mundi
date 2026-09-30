class_name GameShell
extends Control
## Responsive tabletop controls. Every value and enabled action comes from the controller.

var tracks_label: Label
var charter_summary: Label
var act_label: Label
var act_placements_label: Label
var act_progress: ProgressBar
var track_value_labels: Array[Label] = []
var track_reward_labels: Array[Label] = []
var track_bars: Array[ProgressBar] = []
var charter_conditions_label: Label
var next_draft_label: Label
var charter_button: Button
var fit_button: Button
var zoom_in_button: Button
var zoom_out_button: Button
var results_button: Button
var new_run_button: Button
var side_label: Label
var inspection_label: Label
var inspection_panel: PanelContainer
var hand_buttons: Array[Button] = []
var reserve_buttons: Array[Button] = []
var reserve_actions: Array[Button] = []
var relic_slot_buttons: Array[Button] = []
var steward_slot_buttons: Array[Button] = []
var relic_header: Label
var steward_header: Label
var hand_header: Label
var reserve_header: Label
var survey_button: Button
var bag_label: Label
var cycle_button: Button
var rotate_left: Button
var rotate_right: Button
var confirm_button: Button
var cancel_button: Button
var option_menu: OptionButton
var selection_label: Label
var feedback_label: Label
var toast_panel: PanelContainer
var toast_timer: Timer
var board_container: SubViewportContainer
var board_viewport: SubViewport
var workspace: Control
var charter_layer: Control
var modal_layer: CenterContainer
var notice_panel: PanelContainer
var notice_text: RichTextLabel
var notice_button: Button
var _hand_row: HBoxContainer
var _tray: PanelContainer


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = parchment_theme()
	var background: ColorRect = ColorRect.new()
	background.color = AlphaTheme.WOOD
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	_build_top(layout)
	workspace = Control.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.custom_minimum_size.y = 250
	layout.add_child(workspace)
	board_container = SubViewportContainer.new()
	board_container.stretch = true
	board_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	workspace.add_child(board_container)
	board_viewport = SubViewport.new()
	board_viewport.size = Vector2i(1100, 600)
	board_viewport.transparent_bg = true
	board_viewport.handle_input_locally = true
	board_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	board_container.add_child(board_viewport)
	_build_utilities()
	_build_tray(layout)
	_build_toast()
	_build_modal()
	charter_layer = Control.new()
	charter_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	charter_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charter_layer.z_index = 20
	workspace.add_child(charter_layer)
	# Compatibility inspection fields remain read-only and outside normal layout.
	tracks_label = label("", self)
	tracks_label.hide()
	side_label = label("", self)
	side_label.hide()
	resized.connect(_responsive)
	_responsive.call_deferred()


func _build_top(parent: Node) -> void:
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	parent.add_child(top)
	var act: VBoxContainer = column_panel(top, 165)
	act_label = label("Act I", act)
	act_label.add_theme_font_size_override("font_size", 23)
	act_progress = progress(act)
	act_placements_label = label("0 / 18 placements", act)
	var tracks: HBoxContainer = HBoxContainer.new()
	tracks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tracks)
	for index: int in range(4):
		var card: VBoxContainer = column_panel(tracks, 128)
		card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label(PresentationQueries.TRACK_NAMES[index], card)
		var value: Label = label("0", card)
		value.add_theme_font_size_override("font_size", 23)
		track_value_labels.append(value)
		var bar: ProgressBar = progress(card)
		bar.add_theme_stylebox_override("fill", AlphaTheme.box(AlphaTheme.TRACKS[index], AlphaTheme.TRACKS[index].darkened(0.2), 1, 0))
		track_bars.append(bar)
		var reward: Label = label("40 · Train", card)
		reward.add_theme_font_size_override("font_size", 15)
		track_reward_labels.append(reward)
	var objective: VBoxContainer = column_panel(top, 230)
	charter_summary = label("Charter", objective)
	charter_summary.add_theme_font_size_override("font_size", 21)
	charter_summary.clip_text = true
	charter_conditions_label = label("0 / 2 conditions", objective)
	next_draft_label = label("Draft in 2 placements", objective)
	charter_button = button("Charter\n☷", top)
	charter_button.theme_type_variation = &"WoodButton"
	charter_button.tooltip_text = "Open or close Charter details"


func _build_utilities() -> void:
	var left: VBoxContainer = column_panel(workspace, 150, true)
	var left_panel: PanelContainer = left.get_parent() as PanelContainer
	left_panel.position = Vector2(6, 6)
	relic_header = wood_label("Relics (0/2)", left)
	var relic_row: HBoxContainer = HBoxContainer.new()
	left.add_child(relic_row)
	for index: int in range(5):
		var slot: Button = button("+", relic_row)
		slot.custom_minimum_size = Vector2(40, 48)
		slot.add_theme_font_size_override("font_size", 16)
		slot.theme_type_variation = &"WoodButton"
		slot.pressed.connect(func() -> void: show_inspection(slot.tooltip_text))
		relic_slot_buttons.append(slot)
	var right: VBoxContainer = column_panel(workspace, 164, true)
	var right_panel: PanelContainer = right.get_parent() as PanelContainer
	right_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right_panel.offset_left = -180
	right_panel.offset_right = -6
	right_panel.offset_top = 6
	steward_header = wood_label("Stewards (2/2)", right)
	var pieces: HBoxContainer = HBoxContainer.new()
	right.add_child(pieces)
	for index: int in range(3):
		var piece: Button = button("S", pieces)
		piece.custom_minimum_size = Vector2(44, 48)
		piece.tooltip_text = "Available Steward"
		piece.pressed.connect(func() -> void: show_inspection(piece.tooltip_text))
		steward_slot_buttons.append(piece)
	fit_button = button("Fit Board", right)
	var zoom: HBoxContainer = HBoxContainer.new()
	right.add_child(zoom)
	zoom_out_button = button("−", zoom)
	zoom_in_button = button("+", zoom)
	zoom_out_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_in_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_button = button("Results", right)
	new_run_button = button("New Run", right)
	inspection_panel = PanelContainer.new()
	inspection_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	inspection_panel.position = Vector2(6, 90)
	inspection_panel.custom_minimum_size.x = 300
	inspection_panel.z_index = 4
	workspace.add_child(inspection_panel)
	var details: VBoxContainer = VBoxContainer.new()
	inspection_panel.add_child(details)
	inspection_label = label("", details)
	inspection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button("Close details", details).pressed.connect(inspection_panel.hide)
	inspection_panel.hide()


func _build_tray(parent: Node) -> void:
	_tray = PanelContainer.new()
	_tray.theme_type_variation = &"WoodPanel"
	parent.add_child(_tray)
	var tray: HBoxContainer = HBoxContainer.new()
	tray.add_theme_constant_override("separation", 14)
	_tray.add_child(tray)
	var reserve: VBoxContainer = VBoxContainer.new()
	reserve.custom_minimum_size.x = 164
	tray.add_child(reserve)
	reserve_header = wood_label("Reserve (0/1)", reserve)
	for index: int in range(2):
		var row: HBoxContainer = HBoxContainer.new()
		reserve.add_child(row)
		var slot: Button = button("Empty", row)
		slot.custom_minimum_size = Vector2(105, 66)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.expand_icon = true
		slot.add_theme_constant_override("icon_max_width", 45)
		slot.clip_text = true
		reserve_buttons.append(slot)
		var store: Button = button("Store", row)
		store.add_theme_font_size_override("font_size", 15)
		reserve_actions.append(store)
	var hand: VBoxContainer = VBoxContainer.new()
	hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray.add_child(hand)
	hand_header = wood_label("Your Hand (3 tiles)", hand)
	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 10)
	hand.add_child(_hand_row)
	for index: int in range(3):
		var card: Button = button("Empty", _hand_row)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(145, 150)
		card.expand_icon = true
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_theme_constant_override("icon_max_width", 110)
		card.add_theme_font_size_override("font_size", 18)
		card.clip_text = true
		hand_buttons.append(card)
	selection_label = wood_label("Choose a tile", hand)
	selection_label.clip_text = true
	selection_label.add_theme_font_size_override("font_size", 16)
	var actions: VBoxContainer = VBoxContainer.new()
	actions.custom_minimum_size.x = 310
	tray.add_child(actions)
	var status: HBoxContainer = HBoxContainer.new()
	actions.add_child(status)
	survey_button = button("Survey · 1", status)
	survey_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	survey_button.tooltip_text = "Spend one Survey charge to remove the selected hand tile and draw another."
	bag_label = wood_label("Bag\n16", status)
	bag_label.custom_minimum_size.x = 80
	bag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rotations: HBoxContainer = HBoxContainer.new()
	actions.add_child(rotations)
	rotate_left = button("↶ Rotate left", rotations)
	rotate_right = button("Rotate right ↷", rotations)
	rotate_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotate_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_menu = OptionButton.new()
	option_menu.fit_to_longest_item = false
	option_menu.custom_minimum_size.y = 32
	actions.add_child(option_menu)
	var commit: HBoxContainer = HBoxContainer.new()
	actions.add_child(commit)
	confirm_button = button("Confirm placement", commit)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.theme_type_variation = &"ConfirmButton"
	cancel_button = button("Cancel", commit)
	cancel_button.theme_type_variation = &"CancelButton"
	cycle_button = button("Cycle unplayable hand", actions)
	cycle_button.tooltip_text = "Use the authoritative dead-hand rescue when every hand tile is unplayable."


func _build_toast() -> void:
	toast_panel = PanelContainer.new()
	workspace.add_child(toast_panel)
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_panel.offset_left = -240
	toast_panel.offset_right = 240
	toast_panel.offset_top = -95
	toast_panel.offset_bottom = -8
	toast_panel.z_index = 5
	var row: HBoxContainer = HBoxContainer.new()
	toast_panel.add_child(row)
	feedback_label = label("", row)
	feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button("×", row).pressed.connect(dismiss_feedback)
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 7.0
	toast_timer.timeout.connect(dismiss_feedback)
	add_child(toast_timer)
	toast_panel.hide()


func _build_modal() -> void:
	modal_layer = CenterContainer.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.z_index = 10
	add_child(modal_layer)
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.08, 0.06, 0.04, 0.72)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.z_as_relative = false
	veil.z_index = 9
	modal_layer.add_child(veil)
	veil.set_as_top_level(true)
	notice_panel = PanelContainer.new()
	notice_panel.custom_minimum_size = Vector2(850, 550)
	modal_layer.add_child(notice_panel)
	var column: VBoxContainer = VBoxContainer.new()
	notice_panel.add_child(column)
	notice_text = RichTextLabel.new()
	notice_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(notice_text)
	notice_button = button("Continue", column)
	modal_layer.hide()


func show_feedback(text: String, detail: String = "") -> void:
	feedback_label.text = text
	feedback_label.tooltip_text = detail
	toast_panel.visible = not text.is_empty()
	if toast_panel.visible:
		toast_timer.start()


func dismiss_feedback() -> void:
	toast_timer.stop()
	toast_panel.hide()


func show_inspection(text: String) -> void:
	inspection_label.text = text
	inspection_panel.show()


func _responsive() -> void:
	var wide: bool = size.x >= 1600
	for card: Button in hand_buttons:
		card.custom_minimum_size.y = 180 if wide else 150
		card.add_theme_constant_override("icon_max_width", 140 if wide else 110)


static func column_panel(parent: Node, width: int, dark: bool = false) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = width
	if dark:
		panel.theme_type_variation = &"WoodPanel"
	parent.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	return column


static func progress(parent: Node) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 9
	parent.add_child(bar)
	return bar


static func label(value: String, parent: Node) -> Label:
	var item: Label = Label.new()
	item.text = value
	parent.add_child(item)
	return item


static func wood_label(value: String, parent: Node) -> Label:
	var item: Label = label(value, parent)
	item.add_theme_color_override("font_color", Color("efe1c3"))
	return item


static func button(value: String, parent: Node) -> Button:
	var item: Button = Button.new()
	item.text = value
	item.custom_minimum_size.y = 36
	parent.add_child(item)
	return item


static func parchment_theme() -> Theme:
	return AlphaTheme.create()
