class_name AlphaTheme
extends RefCounted
## Presentation-only palette and reusable control states.

const PARCHMENT: Color = Color("e5d4aa")
const INK: Color = Color("30271e")
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
		result.set_color("font_disabled_color", kind, Color("786c5a"))
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
		for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			result.set_color(key, variant, Color("f3e7cd"))
	result.set_stylebox("background", "ProgressBar", box(Color("bcaa87"), Color("9b8561"), 1, 0))
	result.set_stylebox("fill", "ProgressBar", box(Color("628f92"), Color("465c5c"), 1, 0))
	return result


static func selected(button: Button, value: bool) -> void:
	button.set_meta("selected", value)
	if value:
		button.add_theme_stylebox_override("normal", box(Color("f2ddb0"), GOLD, 4))
	else:
		button.remove_theme_stylebox_override("normal")
