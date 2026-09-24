extends Control
## Application smoke screen only; all static loading/validation lives outside UI.

var _content_registry: ContentRegistry = ContentRegistry.new()


func _ready() -> void:
	get_window().min_size = Vector2i(1280, 720)
	var result: ValidationResult = _content_registry.load_phase_seven()
	if not result.is_valid:
		push_error("Mappa Mundi content startup failed [%s]: %s" % [
			result.error_code, result.user_message,
		])
		get_tree().quit(1)
		return
	print("Mappa Mundi: Phase 7 content validated (%d tile definitions); Godot %s" % [
		_content_registry.get_tile_ids().size(), BuildVersions.godot_version(),
	])


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F11:
			if get_window().mode == Window.MODE_FULLSCREEN:
				get_window().mode = Window.MODE_WINDOWED
			else:
				get_window().mode = Window.MODE_FULLSCREEN
			get_viewport().set_input_as_handled()
