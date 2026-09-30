class_name TileDraftInvariantValidator
extends RefCounted
## Direct-snapshot checks: offers, one-copy ownership and continuation must agree.


static func validate(state: RunState, content: ContentRegistry, report: InvariantReport) -> void:
	if state.rewards == null:
		return
	var offers: Dictionary = {}
	var resolved: Dictionary = {}
	var keys: Array[String] = []
	var copies: Array[int] = []
	for event: Dictionary in state.rewards.history:
		var kind: String = event["kind"]
		if kind not in ["tile_draft_offered", "tile_draft_resolved"]:
			continue
		var details: Dictionary = event["details"]
		if not _context_valid(details, content.get_config()) or not details.get("choice_id") is int:
			_fail(report, "Draft audit has invalid typed context.")
			return
		var choice_id: int = details["choice_id"]
		if choice_id <= 0 or choice_id >= state.next_runtime_id or event["act"] != details["act"]:
			_fail(report, "Draft audit identity/Act is invalid.")
			return
		if kind == "tile_draft_offered":
			var key: String = "%s:%d:%d" % [details["draft_type"], details["act"], details["placement_index"]]
			if offers.size() != resolved.size() or offers.has(choice_id) or keys.has(key) or details["draft_sequence"] != offers.size() + 1 \
					or not _options_valid(details.get("options"), content, details):
				_fail(report, "Draft offers must be unique, sequential and eligible.")
				return
			keys.append(key)
			offers[choice_id] = details
		else:
			if not offers.has(choice_id) or resolved.has(choice_id) \
					or not details.get("tile_copy_id") is int or details.get("quantity") != 1:
				_fail(report, "A draft must resolve exactly once into one copy.")
				return
			var offer: Dictionary = offers[choice_id]
			for field: String in ["draft_type", "act", "placement_index", "draft_sequence"]:
				if offer[field] != details[field]:
					_fail(report, "Draft resolution differs from its saved offer.")
			var tile: TileCopyState = PhysicalTileRules.find_copy(state, details["tile_copy_id"])
			if tile == null or copies.has(details["tile_copy_id"]) \
					or not offer["options"].has({"definition_id": details.get("definition_id")}) \
					or String(tile.definition_id) != details.get("definition_id") \
					or tile.acquired_act != details["act"] \
					or String(tile.acquisition_source) != details["draft_type"] + "_draft":
				_fail(report, "Draft acquisition must reference its unique physical copy and source.")
				return
			copies.append(tile.tile_copy_id)
			resolved[choice_id] = true
	var pending: Array[int] = []
	for id: int in offers:
		if not resolved.has(id):
			pending.append(id)
	var choice: PendingChoice = state.pending_choice
	if choice != null and choice.kind == &"tile_draft":
		if pending != [choice.choice_id] or not _context_valid(choice.context, content.get_config()):
			_fail(report, "Pending draft must match the single unresolved offer.")
			return
		var offer: Dictionary = offers[choice.choice_id]
		if choice.options != offer["options"]:
			_fail(report, "Pending draft must preserve exact offer order.")
		for field: String in ["draft_type", "act", "placement_index", "draft_sequence"]:
			if choice.context[field] != offer[field]:
				_fail(report, "Pending draft context differs from its offer.")
		_validate_boundary(state, content.get_config(), report)
	elif not pending.is_empty():
		_fail(report, "An unresolved draft cannot lose its PendingChoice.")
	for tile: TileCopyState in state.tile_copies:
		if tile.acquisition_source in [&"starter_draft", &"cadence_draft", &"act_entry_draft"] \
				and not copies.has(tile.tile_copy_id):
			_fail(report, "Every drafted physical copy needs an acquisition record.")


static func _context_valid(context: Dictionary, config: RunConfig) -> bool:
	if not context.get("draft_type") is String or StringName(context["draft_type"]) not in TileDraftService.TYPES:
		return false
	for field: String in ["act", "placement_index", "draft_sequence"]:
		if not context.get(field) is int:
			return false
	var act: int = context["act"]
	var count: int = context["placement_index"]
	if act < 1 or act > 3 or context["draft_sequence"] < 1:
		return false
	match context["draft_type"]:
		"starter":
			return act == 1 and count == 0
		"act_entry":
			return act in [2, 3] and count == 0
		"cadence":
			return count > 0 and count <= config.act_placement_limits[act - 1] \
				and count % config.draft_interval == 0 and not (act == 3 and count == config.act_placement_limits[2])
	return false


static func _options_valid(value: Variant, content: ContentRegistry, context: Dictionary) -> bool:
	if not value is Array:
		return false
	var pool: Array[StringName] = TileDraftService.pool(content, StringName(context["draft_type"]), context["act"])
	# Act-III entry may have excluded Grand Market at generation. Never infer
	# historical prerequisite eligibility from today's inventory after loading.
	var filtered_entry: bool = context["draft_type"] == "act_entry" and context["act"] == 3
	if value.size() != mini(3, pool.size()) and not (filtered_entry and value.size() == 2):
		return false
	var seen: Array[StringName] = []
	for option: Variant in value:
		if not option is Dictionary or not RunSerializer._has_exact_keys(option, ["definition_id"]) \
				or not option["definition_id"] is String:
			return false
		var id: StringName = StringName(option["definition_id"])
		if id not in pool or id in seen:
			return false
		seen.append(id)
	if filtered_entry and value.size() == 2 and (not seen.has(&"tile.transformation.bridge") or not seen.has(&"tile.transformation.rewilding")):
		return false
	return true


static func _validate_boundary(state: RunState, config: RunConfig, report: InvariantReport) -> void:
	var context: Dictionary = state.pending_choice.context
	if state.charters == null or state.phase != GamePhase.Type.PENDING_CHOICE or state.resolution != null \
			or not state.rewards.queue.is_empty() or context["act"] != state.expansion.current_act:
		_fail(report, "Draft must pause only after prior consequences finish.")
		return
	match context["draft_type"]:
		"starter":
			if state.expansion.normal_placements != 0 or state.act_transition != null \
					or state.expansion.hand != [0, 0, 0]:
				_fail(report, "Starter Draft must precede the opening hand.")
		"cadence":
			if context["placement_index"] != state.expansion.normal_placements or state.act_transition != null \
					or state.charters.bonus_active or not state.charters.bonus_queue.is_empty() \
					or not TileDraftService.cadence_due(state, config):
				_fail(report, "Cadence Draft must follow the complete normal placement chain.")
		"act_entry":
			if state.act_transition == null or state.act_transition.step != 10 \
					or not state.act_transition.information_selected:
				_fail(report, "Act Entry Draft must follow incoming unlocks and Charter information.")


static func _fail(report: InvariantReport, message: String) -> void:
	report.add(&"invalid_tile_draft", message)
