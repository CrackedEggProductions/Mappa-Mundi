class_name CharterPopout
extends PanelContainer
## Disposable structured objective view; only visible CharterRules output is read.

signal close_requested
var close_button: Button
var sections: VBoxContainer
var displayed_sections: Array[Dictionary] = []
var condition_rows: Array[Dictionary] = []


func _init() -> void:
	theme = AlphaTheme.information()
	theme_type_variation = &"ParchmentInfoOverlay"
	custom_minimum_size.x = 340
	var column: VBoxContainer = VBoxContainer.new()
	add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	var title: Label = GameShell.label("Charter & Grand Charter", header)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = GameShell.button("×", header)
	close_button.tooltip_text = "Close Charter details"
	close_button.pressed.connect(func() -> void: close_requested.emit())
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	sections = VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 12)
	scroll.add_child(sections)


func sync(state: RunState, content: ContentRegistry) -> void:
	for child: Node in sections.get_children():
		sections.remove_child(child)
		child.queue_free()
	displayed_sections.clear()
	condition_rows.clear()
	var ordinary: Dictionary = CharterRules.visible_ordinary(state, content)
	var grand: Dictionary = CharterRules.visible_grand(state, content)
	if not ordinary.is_empty():
		_section(ordinary, content)
	if not grand.is_empty():
		if bool(grand.get("exact_revealed", false)):
			_section(grand, content)
		else:
			displayed_sections.append(grand.duplicate(true))
			_text("Grand Charter forecast", 23)
			_text(String(grand.get("forecast", "")))
			_text("Exact requirements are revealed after Act II placement 11 and its consequences.", 16)


func _section(visible: Dictionary, content: ContentRegistry) -> void:
	displayed_sections.append(visible.duplicate(true))
	var definition: CharterDefinition = content.get_charter(StringName(visible.get("charter_id", "")))
	_text(String(visible.get("display_name", "Charter")), 26)
	if definition != null:
		_text("Grand Charter" if definition.evaluation_act == 3 else "Act %s Charter" % ["I", "II"][definition.evaluation_act - 1], 17)
	var progress: Dictionary = visible.get("progress", {})
	_text("Current result: " + ("Incomplete" if progress.get("overall_state") == "failed" else String(progress.get("overall_state", "")).capitalize()))
	for exceed: bool in [false, true]:
		_text("Exceed · also fulfill every condition above" if exceed else "Fulfill every condition", 20)
		for condition: Dictionary in progress.get("conditions", []):
			if bool(condition.get("exceed", false)) != exceed:
				continue
			var key: String = condition.get("key", "")
			var name: String = String(PresentationQueries.CONDITION_NAMES.get(key, key.trim_prefix("exceed_").capitalize()))
			var met: bool = condition.get("satisfied", false)
			_text(("✓ " if met else "○ ") + name)
			var current: int = condition.get("current", 0)
			var target: int = condition.get("target", 0)
			var bar: ProgressBar = GameShell.progress(sections)
			bar.max_value = maxi(target, 1)
			bar.value = current
			var source: String = "History" if condition.get("source") == "history" else "Current realm"
			_text("%d / %d · %s · %s" % [current, target, source, "Satisfied" if met else "Incomplete"], 16)
			condition_rows.append({"key": key, "current": current, "target": target, "satisfied": met, "bar": bar})
		if definition != null:
			var rewards: Array[StringName] = definition.exceed_rewards if exceed else definition.fulfill_rewards
			var names: Array[String] = []
			for reward: StringName in rewards:
				names.append(String({&"tile_reward": "Normal Tile Reward", &"relic_offer": "Relic offer", &"major_reward": "Major Reward"}.get(reward, String(reward).capitalize())))
			if definition.evaluation_act == 3:
				_text("Result: Exemplary Victory" if exceed else "Result: Victory", 17)
			else:
				_text(("Additional reward: " if exceed else "Reward: ") + (", then ".join(names) if not names.is_empty() else "None"), 17)
	sections.add_child(HSeparator.new())


func _text(value: String, font_size: int = 18) -> Label:
	var item: Label = GameShell.label(value, sections)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", font_size)
	return item
