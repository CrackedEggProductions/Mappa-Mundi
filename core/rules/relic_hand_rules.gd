class_name RelicHandRules
extends RefCounted
## Shared physical hand operations. Commands validate before invoking mutations.


static func reserve_capacity(state: RunState) -> int:
	return 2 if RelicRules.active(state, &"relic.wayfarers_satchel") else 1


static func reserve_ids(state: RunState) -> Array[int]:
	var ids: Array[int] = []
	for copy_id: int in [state.expansion.reserve_id, state.expansion.reserve_extra_id]:
		if copy_id > 0:
			ids.append(copy_id)
	return ids


static func _reserve_slot(state: RunState, requested: int) -> int:
	if requested != -1:
		return requested
	if state.expansion.reserve_id == 0:
		return 0
	if reserve_capacity(state) == 2 and state.expansion.reserve_extra_id == 0:
		return 1
	return -1


static func validate_reserve(state: RunState, command: ReserveTileCommand) -> ValidationResult:
	var slot: int = _reserve_slot(state, command.reserve_slot)
	if slot < 0 or slot >= reserve_capacity(state):
		return _failure(&"reserve_occupied", "No empty legal Reserve slot is available.")
	if (slot == 0 and state.expansion.reserve_id != 0) or (slot == 1 and state.expansion.reserve_extra_id != 0):
		return _failure(&"reserve_occupied", "The selected Reserve slot is occupied.")
	if command.tile_copy_id <= 0 or command.tile_copy_id not in state.expansion.hand:
		return _failure(&"not_in_hand", "Only occupied active-hand tiles may enter Reserve.")
	return ValidationResult.success()


static func reserve(state: RunState, content: ContentRegistry, command: ReserveTileCommand) -> void:
	var slot: int = _reserve_slot(state, command.reserve_slot)
	var hand_index: int = state.expansion.hand.find(command.tile_copy_id)
	if slot == 0:
		state.expansion.reserve_id = command.tile_copy_id
	else:
		state.expansion.reserve_extra_id = command.tile_copy_id
	PhysicalTileRules.set_location(state, command.tile_copy_id, TileLocationState.Kind.RESERVE)
	state.expansion.hand[hand_index] = PhysicalTileRules.draw(state, content.get_config())


static func remove_reserved(state: RunState, copy_id: int) -> void:
	if state.expansion.reserve_id == copy_id:
		state.expansion.reserve_id = 0
	elif state.expansion.reserve_extra_id == copy_id:
		state.expansion.reserve_extra_id = 0


static func survey(state: RunState, content: ContentRegistry, copy_id: int) -> void:
	var expansion: ExpansionState = state.expansion
	var index: int = expansion.hand.find(copy_id)
	var compass: bool = state.relics != null and state.relics.normal_surveys_used == 0 \
		and RelicRules.active(state, &"relic.surveyors_compass")
	if state.relics != null:
		state.relics.normal_surveys_used += 1
	expansion.survey_charges -= 1
	_remove_hand_copy(state, copy_id)
	if not compass:
		expansion.hand[index] = PhysicalTileRules.draw(state, content.get_config())
		return
	if expansion.bag.is_empty():
		PhysicalTileRules.inject_emergency(state, content.get_config())
		expansion.bag = state.rng.shuffled_ids(expansion.bag, &"empty_bag_replenishment")
	var choice: PendingChoice = PendingChoice.new()
	choice.choice_id = state.id_allocator.allocate()
	choice.kind = &"compass"
	for count: int in range(mini(3, expansion.bag.size())):
		var inspected: int = expansion.bag.pop_front()
		expansion.inspected_ids.append(inspected)
		PhysicalTileRules.set_location(state, inspected, TileLocationState.Kind.INSPECTED)
		choice.options.append({"tile_copy_id": inspected})
	choice.context = {"hand_index": index, "inspected_ids": expansion.inspected_ids.duplicate()}
	state.resolution = ResolutionState.new()
	state.resolution.source_id = copy_id
	state.resolution.stage = &"compass"
	state.resolution.context = {"hand_index": index}
	state.pending_choice = choice
	state.phase = GamePhase.Type.PENDING_CHOICE
	RelicRules.record(state, &"relic_triggered", {"definition_id": &"relic.surveyors_compass", "inspected_ids": expansion.inspected_ids.duplicate()}, copy_id)


static func handles(command: PlayerCommand) -> bool:
	return command is ResolveCompassCommand or command is ResolveGrandSurveyCommand


static func validate_command(state: RunState, content: ContentRegistry, command: PlayerCommand) -> ValidationResult:
	if not handles(command) or state.phase != GamePhase.Type.PENDING_CHOICE or state.pending_choice == null:
		return _failure(&"wrong_phase", "No matching hand choice is pending.")
	var reserve_count: int = content.get_config().emergency_definitions.size() * 2 + 1
	if state.expansion.state_revision == 9223372036854775807 \
		or state.rng.operation_count > 9223372036854775807 - 2 \
		or state.next_runtime_id > RunIdAllocator.EXHAUSTED_CURSOR - reserve_count:
		return _failure(&"invariant_failure", "Insufficient counters to resolve this hand choice safely.")
	if command is ResolveGrandSurveyCommand and state.expansion.survey_charges == 9223372036854775807:
		return _failure(&"invariant_failure", "Grand Survey charge cannot overflow.")
	if command.expected_state_revision != -1 and command.expected_state_revision != state.expansion.state_revision:
		return _failure(&"stale_preview", "The run changed after this hand choice preview.")
	var choice: PendingChoice = state.pending_choice
	if command.choice_id != choice.choice_id:
		return _failure(&"stale_choice", "Choice identity does not match the pending choice.")
	if command is ResolveCompassCommand:
		if choice.kind != &"compass" or command.tile_copy_id not in state.expansion.inspected_ids:
			return _failure(&"invalid_compass_choice", "Choose one persisted inspected physical copy.")
	elif choice.kind != &"grand_survey":
		return _failure(&"invalid_grand_survey_choice", "No Grand Survey is pending.")
	elif not command.finish and (command.tile_copy_id <= 0 \
		or command.tile_copy_id not in choice.context["eligible_ids"] \
		or command.tile_copy_id not in state.expansion.hand):
		return _failure(&"invalid_grand_survey_choice", "Choose an occupied original active-hand tile.")
	return ValidationResult.success()


static func execute_command(state: RunState, content: ContentRegistry, command: PlayerCommand) -> void:
	if command is ResolveCompassCommand:
		var compass_command: ResolveCompassCommand = command as ResolveCompassCommand
		var index: int = int(state.pending_choice.context["hand_index"])
		state.expansion.hand[index] = compass_command.tile_copy_id
		PhysicalTileRules.set_location(state, compass_command.tile_copy_id, TileLocationState.Kind.ACTIVE_HAND)
		for copy_id: int in state.expansion.inspected_ids:
			if copy_id != compass_command.tile_copy_id:
				state.expansion.bag.append(copy_id)
				PhysicalTileRules.set_location(state, copy_id, TileLocationState.Kind.BAG)
		state.expansion.inspected_ids.clear()
		state.expansion.bag = state.rng.shuffled_ids(state.expansion.bag, &"compass_return")
		state.pending_choice = null
		state.resolution = null
		state.phase = GamePhase.Type.TURN_INPUT
	else:
		var grand_command: ResolveGrandSurveyCommand = command as ResolveGrandSurveyCommand
		if not grand_command.finish:
			var index: int = state.expansion.hand.find(grand_command.tile_copy_id)
			_remove_hand_copy(state, grand_command.tile_copy_id)
			state.pending_choice.context["chosen_removals"].append(grand_command.tile_copy_id)
			state.pending_choice.context["eligible_ids"].erase(grand_command.tile_copy_id)
			state.expansion.hand[index] = PhysicalTileRules.draw(state, content.get_config())
		if grand_command.finish or state.pending_choice.context["chosen_removals"].size() == 2 \
			or state.pending_choice.context["eligible_ids"].is_empty():
			_finish_grand_survey(state)
		else:
			_grand_options(state.pending_choice)


static func begin_grand_survey(state: RunState, _content: ContentRegistry) -> void:
	var choice: PendingChoice = PendingChoice.new()
	choice.choice_id = state.id_allocator.allocate()
	choice.kind = &"grand_survey"
	var eligible: Array[int] = []
	for copy_id: int in state.expansion.hand:
		if copy_id > 0:
			eligible.append(copy_id)
	choice.context = {"eligible_ids": eligible, "chosen_removals": [], "charge_awarded": false}
	_grand_options(choice)
	state.pending_choice = choice
	state.phase = GamePhase.Type.PENDING_CHOICE


static func _grand_options(choice: PendingChoice) -> void:
	choice.options.clear()
	for copy_id: int in choice.context["eligible_ids"]:
		choice.options.append({"tile_copy_id": copy_id, "finish": false})
	choice.options.append({"tile_copy_id": 0, "finish": true})


static func _finish_grand_survey(state: RunState) -> void:
	state.expansion.survey_charges += 1
	# The choice disappears only after its one-time charge and audit are committed.
	if state.rewards != null:
		state.rewards.history.append({"event_id": state.id_allocator.allocate(),
			"kind": &"grand_survey_resolved", "source_id": state.pending_choice.choice_id,
			"act": state.expansion.current_act,
			"details": {"removed_ids": state.pending_choice.context["chosen_removals"].duplicate(), "survey_charge": 1}})
	state.pending_choice = null
	state.phase = GamePhase.Type.RESOLVING_PLACEMENT


static func _remove_hand_copy(state: RunState, copy_id: int) -> void:
	var index: int = state.expansion.hand.find(copy_id)
	state.expansion.hand[index] = 0
	state.expansion.removed_ids.append(copy_id)
	PhysicalTileRules.set_location(state, copy_id, TileLocationState.Kind.REMOVED_FROM_RUN)


static func _failure(code: StringName, message: String) -> ValidationResult:
	return ValidationResult.failure(code, message)
