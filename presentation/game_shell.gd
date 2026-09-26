class_name GameShell
extends Control
## Responsive containers and visual styling only; no gameplay decisions.

var tracks_label: Label
var charter_summary: Label
var act_label: Label
var charter_button: Button
var fit_button: Button
var results_button: Button
var new_run_button: Button
var side_label: Label
var inspection_label: Label
var hand_buttons: Array[Button] = []
var reserve_buttons: Array[Button] = []
var reserve_actions: Array[Button] = []
var survey_button: Button
var cycle_button: Button
var rotate_left: Button
var rotate_right: Button
var confirm_button: Button
var cancel_button: Button
var option_menu: OptionButton
var selection_label: Label
var feedback_label: Label
var board_container: SubViewportContainer
var board_viewport: SubViewport
var modal_layer: CenterContainer
var notice_panel: PanelContainer
var notice_text: RichTextLabel
var notice_button: Button


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = parchment_theme()
	var background: ColorRect = ColorRect.new()
	background.color = Color("e5d4aa")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var top: HBoxContainer = HBoxContainer.new()
	layout.add_child(top)
	act_label = label("Mappa Mundi", top)
	act_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracks_label = label("", top)
	charter_button = button("Charter & Grand Charter", top)
	charter_summary = label("", layout)
	charter_summary.clip_text = true
	var middle: HBoxContainer = HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(middle)
	var board_column: VBoxContainer = VBoxContainer.new()
	board_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(board_column)
	var board_tools: HBoxContainer = HBoxContainer.new()
	board_column.add_child(board_tools)
	fit_button = button("Center / Fit Board", board_tools)
	label("Wheel: zoom  ·  Middle/right drag: pan", board_tools)
	results_button = button("Return to results", board_tools)
	new_run_button = button("New Run", board_tools)
	board_container = SubViewportContainer.new()
	board_container.stretch = true
	board_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_container.custom_minimum_size = Vector2(400, 280)
	board_column.add_child(board_container)
	board_viewport = SubViewport.new()
	board_viewport.size = Vector2i(1100, 600)
	board_viewport.handle_input_locally = true
	board_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	board_container.add_child(board_viewport)
	var side_scroll: ScrollContainer = ScrollContainer.new()
	side_scroll.custom_minimum_size.x = 340
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(side_scroll)
	var side_column: VBoxContainer = VBoxContainer.new()
	side_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(side_column)
	side_label = label("", side_column)
	side_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label("Reserve", side_column)
	for index: int in range(2):
		var row: HBoxContainer = HBoxContainer.new()
		side_column.add_child(row)
		var select_button: Button = button("Empty", row)
		select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select_button.clip_text = true
		reserve_buttons.append(select_button)
		reserve_actions.append(button("Store", row))
	survey_button = button("Survey selected hand tile", side_column)
	survey_button.tooltip_text = "Spend one Survey charge to remove the selected hand tile and draw a replacement."
	cycle_button = button("Cycle unplayable hand", side_column)
	inspection_label = label("Click a placed tile to inspect it.", side_column)
	inspection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hand_row: HBoxContainer = HBoxContainer.new()
	layout.add_child(hand_row)
	for index: int in range(3):
		var tile_button: Button = button("Empty", hand_row)
		tile_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile_button.custom_minimum_size.y = 116
		tile_button.expand_icon = true
		tile_button.add_theme_constant_override("icon_max_width", 96)
		tile_button.clip_text = true
		hand_buttons.append(tile_button)
	selection_label = label("Select a tile, choose a target, then Confirm.", layout)
	selection_label.clip_text = true
	var actions: HBoxContainer = HBoxContainer.new()
	layout.add_child(actions)
	rotate_left = button("Rotate left", actions)
	rotate_right = button("Rotate right", actions)
	option_menu = OptionButton.new()
	option_menu.fit_to_longest_item = false
	option_menu.custom_minimum_size.x = 180
	option_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(option_menu)
	confirm_button = button("Confirm placement", actions)
	cancel_button = button("Cancel preview", actions)
	feedback_label = label("", layout)
	feedback_label.custom_minimum_size.y = 30
	feedback_label.clip_text = true
	modal_layer = CenterContainer.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.z_index = 10
	add_child(modal_layer)
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.12, 0.10, 0.07, 0.65)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.z_as_relative = false
	veil.z_index = 9
	modal_layer.add_child(veil)
	veil.set_as_top_level(true)
	notice_panel = PanelContainer.new()
	notice_panel.custom_minimum_size = Vector2(860, 600)
	modal_layer.add_child(notice_panel)
	var notice_box: VBoxContainer = VBoxContainer.new()
	notice_panel.add_child(notice_box)
	notice_text = RichTextLabel.new()
	notice_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notice_text.bbcode_enabled = false
	notice_box.add_child(notice_text)
	notice_button = button("Continue", notice_box)
	modal_layer.hide()


static func label(value: String, parent: Node) -> Label:
	var item: Label = Label.new()
	item.text = value
	parent.add_child(item)
	return item


static func button(value: String, parent: Node) -> Button:
	var item: Button = Button.new()
	item.text = value
	item.custom_minimum_size.y = 42
	parent.add_child(item)
	return item


static func parchment_theme() -> Theme:
	var result: Theme = Theme.new()
	result.default_font_size = 22
	# RichTextLabel uses default_color, unlike Label's font_color.
	result.set_color("default_color", "RichTextLabel", Color("30271e"))
	for kind: String in ["Label", "Button", "OptionButton", "RichTextLabel", "LineEdit"]:
		result.set_color("font_color", kind, Color("30271e"))
		result.set_color("font_hover_color", kind, Color("30271e"))
		result.set_color("font_pressed_color", kind, Color("30271e"))
		result.set_color("font_disabled_color", kind, Color("8b806d"))
	for style_name: String in ["normal", "hover", "pressed", "disabled", "focus", "panel"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("f0e3c5") if style_name != "hover" else Color("e1c68a")
		style.border_color = Color("a39069")
		style.set_border_width_all(1)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		for kind: String in ["Button", "OptionButton", "PanelContainer", "LineEdit"]:
			result.set_stylebox(style_name, kind, style)
	return result
