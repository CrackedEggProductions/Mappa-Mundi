class_name InfoTooltipButton
extends Button
## Shared compact manuscript note; text comes from static content or UI queries.

const TEXT_WIDTH: float = 340.0


func _make_custom_tooltip(for_text: String) -> Object:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme = AlphaTheme.information()
	panel.theme_type_variation = &"ParchmentInfoOverlay"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body: Label = Label.new()
	body.text = for_text
	body.custom_minimum_size.x = TEXT_WIDTH
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 17)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(body)
	return panel
