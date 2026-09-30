extends SceneTree
## Non-authoritative graphical captures through the human controller path.

var controller: GameController
var prefix: String


func _initialize() -> void:
	call_deferred("_run")


func _frames() -> void:
	for index: int in range(5):
		await process_frame


func _capture(name: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	var path: String = prefix + "-" + name + ".png"
	var result: Error = root.get_texture().get_image().save_png(path)
	assert(result == OK)
	print("CAPTURE: ", path)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var width: int = int(args[0]) if args.size() > 0 else 1280
	var height: int = int(args[1]) if args.size() > 1 else 720
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(width, height)
	prefix = "res://builds/ui-usability-%dx%d" % [width, height]
	controller = GameController.new()
	root.add_child(controller)
	controller.start_run(1)
	await _frames()
	await _capture("starter-draft")
	controller.choice_presenter.option_buttons[0].pressed.emit()
	await _frames()
	controller.fit_board()
	controller.shell.dismiss_feedback()
	await _capture("normal")
	controller.show_charter()
	await _capture("charter")
	controller.close_charter()
	for index: int in range(3):
		controller.hand_buttons[index].pressed.emit()
		if not controller.options.is_empty():
			controller.select_option(0)
			break
	await _capture("preview")
	print("LAYOUT: root=", root.size, " shell=", controller.shell.size,
		" board=", controller.shell.board_container.get_global_rect(), " hand=", controller.hand_buttons[0].get_global_rect())
	quit(0)
