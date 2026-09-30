class_name TileDraftService
extends RefCounted
## Saved one-copy acquisitions. Continuations remain in setup, placement and Act rules.

const TYPES: Array[StringName] = [&"starter", &"cadence", &"act_entry"]


static func pool(content: ContentRegistry, subtype: StringName, act: int) -> Array[StringName]:
	var config: RunConfig = content.get_config()
	var candidates: Array[StringName] = []
	match subtype:
		&"starter":
			if act == 1:
				candidates = config.starter_draft_pool.duplicate()
		&"cadence":
			candidates = config.draft_pool(act)
		&"act_entry":
			candidates = config.entry_draft_pool(act)
	var eligible: Array[StringName] = []
	for id: StringName in candidates:
		var definition: TileDefinition = content.get_tile(id)
		if definition != null and definition.player_drawable and definition.unlock_act <= act and not eligible.has(id):
			eligible.append(id)
	eligible.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return eligible


static func completed(state: RunState, subtype: StringName, act: int, placement_index: int = 0) -> bool:
	if state.rewards == null:
		return false
	for event: Dictionary in state.rewards.history:
		if event.get("kind") != "tile_draft_resolved":
			continue
		if not event.get("details") is Dictionary:
			return false
		var details: Dictionary = event["details"]
		if details.get("draft_type") == String(subtype) and details.get("act") == act \
				and details.get("placement_index") == placement_index:
			return true
	return false


static func eligible_pool(state: RunState, content: ContentRegistry, subtype: StringName, act: int) -> Array[StringName]:
	# Strict acquisition prerequisites, evaluated only when generating an offer.
	# The static pool remains the validation boundary for saved offers/history.
	var candidates: Array[StringName] = pool(content, subtype, act)
	for upgrade: StringName in [&"tile.development.abbey", &"tile.development.grand_market"]:
		var prerequisite: StringName = &"tile.development.monastery" if upgrade == &"tile.development.abbey" else &"tile.development.market"
		if not has_board_or_bag_copy(state, prerequisite):
			candidates.erase(upgrade)
	return candidates


static func has_board_or_bag_copy(state: RunState, definition_id: StringName) -> bool:
	for copy_id: int in state.expansion.bag:
		var copy: TileCopyState = PhysicalTileRules.find_copy(state, copy_id)
		if copy != null and copy.definition_id == definition_id:
			return true
	for coordinate: Vector2i in state.expansion.board.sorted_coordinates():
		for development: DevelopmentState in state.expansion.board.get_cell(coordinate).developments:
			var copy: TileCopyState = PhysicalTileRules.find_copy(state, development.tile_copy_id)
			if copy != null and copy.definition_id == definition_id \
					and development.stage == StringName(String(definition_id).trim_prefix("tile.development.")):
				return true
	return false


static func next_draft_placement(state: RunState, config: RunConfig) -> int:
	if state.charters == null or state.phase == GamePhase.Type.RUN_COMPLETE:
		return 0
	var act: int = state.expansion.current_act
	var used: int = state.expansion.normal_placements
	if state.act_transition != null and state.act_transition.advanced and not state.act_transition.counter_reset:
		used = 0 # Incoming-Act UI must not display the outgoing placement counter.
	var next: int = used + config.draft_interval - (used % config.draft_interval)
	var limit: int = config.act_placement_limits[act - 1]
	if next > limit or (act == 3 and next == limit):
		return 0
	return next


static func cadence_due(state: RunState, config: RunConfig) -> bool:
	if state.charters == null:
		return false
	var act: int = state.expansion.current_act
	var count: int = state.expansion.normal_placements
	return count > 0 and count % config.draft_interval == 0 \
		and not (act == 3 and count == config.act_placement_limits[2]) \
		and not completed(state, &"cadence", act, count)


static func begin(state: RunState, content: ContentRegistry, subtype: StringName, placement_index: int = 0) -> bool:
	var act: int = state.expansion.current_act
	if completed(state, subtype, act, placement_index):
		return false
	assert(state.pending_choice == null and state.resolution == null and state.rewards.queue.is_empty())
	var candidates: Array[StringName] = eligible_pool(state, content, subtype, act)
	assert(not candidates.is_empty(), "Validated draft content must provide a choice.")
	var sequence: int = 1
	for event: Dictionary in state.rewards.history:
		if event.get("kind") == "tile_draft_offered":
			sequence += 1
	var choice: PendingChoice = PendingChoice.new()
	choice.choice_id = state.id_allocator.allocate()
	choice.kind = &"tile_draft"
	choice.context = {"draft_type": String(subtype), "act": act,
		"placement_index": placement_index, "draft_sequence": sequence}
	for id: StringName in RewardRules.sample(state, candidates, &"tile_draft_offer"):
		choice.options.append({"definition_id": String(id)})
	state.pending_choice = choice
	state.phase = GamePhase.Type.PENDING_CHOICE
	var details: Dictionary = choice.context.duplicate(true)
	details["choice_id"] = choice.choice_id
	details["options"] = choice.options.duplicate(true)
	RewardRules.record(state, &"tile_draft_offered", details)
	return true


static func validate_command(state: RunState, content: ContentRegistry, command: ResolveTileDraftCommand) -> ValidationResult:
	var choice: PendingChoice = state.pending_choice
	if state.phase != GamePhase.Type.PENDING_CHOICE or choice == null \
			or choice.kind != &"tile_draft" or choice.choice_id != command.choice_id:
		return ValidationResult.failure(&"stale_tile_draft", "No matching Tile Draft is pending.")
	if command.expected_state_revision != -1 and command.expected_state_revision != state.expansion.state_revision:
		return ValidationResult.failure(&"stale_tile_draft", "The run changed after this draft was shown.")
	if command.option_index < 0 or command.option_index >= choice.options.size():
		return ValidationResult.failure(&"invalid_draft_option", "Choose one of the saved Tile Draft designs.")
	var id: StringName = StringName(choice.options[command.option_index].get("definition_id", ""))
	if not pool(content, StringName(choice.context["draft_type"]), int(choice.context["act"])).has(id):
		return ValidationResult.failure(&"invalid_draft_design", "This design is outside the draft's unlocked pool.")
	if state.next_runtime_id > RunIdAllocator.EXHAUSTED_CURSOR - 128 \
			or state.rng.operation_count > RunRNG.MAX_OPERATION_COUNT - state.expansion.bag.size() - 128:
		return ValidationResult.failure(&"invariant_failure", "Insufficient counters to finish this draft safely.")
	return ValidationResult.success()


static func execute_command(state: RunState, command: ResolveTileDraftCommand) -> StringName:
	var choice: PendingChoice = state.pending_choice
	var subtype: StringName = StringName(choice.context["draft_type"])
	var id: StringName = StringName(choice.options[command.option_index]["definition_id"])
	var copy_id: int = PhysicalTileRules.acquire(state, id, StringName(String(subtype) + "_draft"), TileLocationState.Kind.BAG)
	state.expansion.bag.append(copy_id)
	state.expansion.bag = state.rng.shuffled_ids(state.expansion.bag, &"tile_draft_bag_shuffle")
	var details: Dictionary = choice.context.duplicate(true)
	details.merge({"choice_id": choice.choice_id, "definition_id": String(id), "tile_copy_id": copy_id, "quantity": 1})
	RewardRules.record(state, &"tile_draft_resolved", details)
	state.pending_choice = null
	state.phase = GamePhase.Type.RESOLVING_PLACEMENT
	return subtype
