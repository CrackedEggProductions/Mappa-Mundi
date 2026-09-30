class_name AlphaTheme
extends RefCounted
## Presentation-only palette and reusable control states.

const PARCHMENT: Color = Color("e5d4aa")
const INK: Color = Color("30271e")
const SECONDARY_INK: Color = Color("594535")
const LIGHT_INK: Color = Color("f3e7cd")
const WOOD: Color = Color("35271f")
const FRAME: Color = Color("241b16")
const GOLD: Color = Color("c69a43")
const TRACKS: Array[Color] = [Color("a55e48"), Color("b68a56"), Color("628f92"), Color("66784a")]


static func box(fill: Color, border: Color = Color("806347"), width: int = 1, padding: int = 10) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(5)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


static func create() -> Theme:
	var result: Theme = Theme.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Liberation Serif", "DejaVu Serif"])
	result.default_font = font
	result.default_font_size = 18
	for kind: String in ["Label", "Button", "OptionButton", "LineEdit", "ProgressBar"]:
		result.set_color("font_color", kind, INK)
		result.set_color("font_hover_color", kind, INK)
		result.set_color("font_pressed_color", kind, INK)
		result.set_color("font_focus_color", kind, INK)
		result.set_color("font_disabled_color", kind, INK)
	result.set_color("default_color", "RichTextLabel", INK)
	result.set_stylebox("panel", "PanelContainer", box(PARCHMENT))
	result.set_type_variation("WoodPanel", "PanelContainer")
	result.set_stylebox("panel", "WoodPanel", box(FRAME, Color("806347"), 2))
	for kind: String in ["Button", "OptionButton", "LineEdit"]:
		result.set_stylebox("normal", kind, box(Color("dfcaa0")))
		result.set_stylebox("hover", kind, box(Color("f0dfb9"), GOLD, 2))
		result.set_stylebox("pressed", kind, box(Color("e4c482"), GOLD, 3))
		result.set_stylebox("disabled", kind, box(Color("b2a38b"), Color("675746")))
		result.set_stylebox("focus", kind, box(Color(0, 0, 0, 0), GOLD, 2, 0))
	for variant: String in ["ConfirmButton", "CancelButton", "WoodButton"]:
		result.set_type_variation(variant, "Button")
		var fill: Color = Color("465735") if variant == "ConfirmButton" else (Color("783e31") if variant == "CancelButton" else Color("48362a"))
		for state: String in ["normal", "hover", "pressed"]:
			result.set_stylebox(state, variant, box(fill.lightened(0.14) if state == "hover" else fill, GOLD if state == "pressed" else Color("927958"), 2))
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.set_color(key, variant, Color("f3e7cd"))
	result.set_stylebox("background", "ProgressBar", box(Color("bcaa87"), Color("9b8561"), 1, 0))
	result.set_stylebox("fill", "ProgressBar", box(Color("628f92"), Color("465c5c"), 1, 0))
	_information_styles(result, false)
	return result


static func information(dark: bool = false) -> Theme:
	# A paired surface/text theme: parent style variations alone cannot recolor
	# child Labels, and Godot's TooltipPanel otherwise keeps its dark default.
	var result: Theme = create()
	_information_styles(result, dark)
	return result


static func _information_styles(result: Theme, dark: bool) -> void:
	var background: Color = FRAME if dark else PARCHMENT
	var foreground: Color = LIGHT_INK if dark else INK
	var secondary: Color = PARCHMENT if dark else SECONDARY_INK
	var variation: String = "DarkInfoOverlay" if dark else "ParchmentInfoOverlay"
	result.set_type_variation(variation, "PanelContainer")
	for kind: String in ["PanelContainer", "Panel", "PopupPanel", "TooltipPanel", "PopupMenu", variation]:
		result.set_stylebox("panel", kind, box(background, Color("806347"), 1))
	for kind: String in ["Label", "TooltipLabel", "PopupMenu"]:
		result.set_color("font_color", kind, foreground)
		result.set_color("font_hover_color", kind, foreground)
		result.set_color("font_disabled_color", kind, secondary)
		result.set_color("font_accelerator_color", kind, secondary)
		result.set_color("font_separator_color", kind, secondary)
	result.set_color("default_color", "RichTextLabel", foreground)
	result.set_stylebox("hover", "PopupMenu", box(background.lightened(0.08), GOLD))


static func selected(button: Button, value: bool) -> void:
	button.set_meta("selected", value)
	if value:
		button.add_theme_stylebox_override("normal", box(Color("f2ddb0"), GOLD, 4))
	else:
		button.remove_theme_stylebox_override("normal")
