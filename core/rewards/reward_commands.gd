class_name RewardCommands
extends RefCounted
## Validate exact saved offers before any acquisition, allocation or random draw.

const KINDS: Array[StringName] = [&"tile_reward", &"masterwork", &"major_reward", &"relic_offer", &"relic_replacement", &"training_piece"]


static func handles(command: PlayerCommand) -> bool:
	return command is ResolveRewardCommand


static func validate_command(state: RunState, content: ContentRegistry, command: PlayerCommand) -> ValidationResult:
	if not handles(command) or state.rewards == null or state.relics == null or state.expansion == null:
		return _fail(&"rewards_unavailable", "Rewards require a Phase-8 run.")
	var intent: ResolveRewardCommand = command as ResolveRewardCommand
	var choice: PendingChoice = state.pending_choice
	if state.phase != GamePhase.Type.PENDING_CHOICE or choice == null or not KINDS.has(choice.kind) or choice.choice_id != intent.choice_id:
		return _fail(&"stale_reward_choice", "No matching reward choice is pending.")
	if intent.expected_state_revision != -1 and intent.expected_state_revision != state.expansion.state_revision:
		return _fail(&"stale_reward_choice", "The run changed after the offer was shown.")
	if intent.option_index < 0 or intent.option_index >= choice.options.size():
		return _fail(&"invalid_reward_option", "Select one of the persisted reward options.")
	if state.next_runtime_id > RunIdAllocator.EXHAUSTED_CURSOR - 128 or state.rng.operation_count > RunRNG.MAX_OPERATION_COUNT - state.expansion.bag.size() - 64:
		return _fail(&"invariant_failure", "Insufficient counters to finish this reward safely.")
	var selected: Dictionary = choice.options[intent.option_index]
	var act: int = int(choice.context.get("eligibility_act", state.expansion.current_act))
	match choice.kind:
		&"tile_reward", &"masterwork":
			if not RewardRules.tile_pool(content, act, choice.kind == &"masterwork").has(StringName(selected.get("definition_id", ""))):
				return _fail(&"invalid_reward_design", "The offered tile is outside the frozen unlock pool.")
		&"major_reward":
			if not RewardRules.major_pool(state, content, act).has(StringName(selected.get("major_id", ""))):
				return _fail(&"invalid_major_reward", "That Major Reward is no longer valid.")
		&"relic_offer", &"relic_replacement":
			var id: StringName = StringName(selected.get("definition_id", choice.context.get("definition_id", "")))
			if not RelicRules.eligible_ids(state, content, act).has(id):
				return _fail(&"invalid_relic_reward", "That Relic has already been acquired or is not unlocked.")
			if choice.kind == &"relic_replacement" and not bool(selected.get("decline", false)):
				return RelicRules.removal_validation(state, content, StringName(selected.get("replace_id", "")))
		&"training_piece":
			if not SpecialistRules.trainable_piece_ids(state).has(int(selected.get("piece_id", 0))):
				return _fail(&"invalid_training_piece", "This Steward cannot currently be trained.")
	return ValidationResult.success()


static func execute_command(state: RunState, content: ContentRegistry, command: PlayerCommand) -> void:
	var intent: ResolveRewardCommand = command as ResolveRewardCommand
	var choice: PendingChoice = state.pending_choice
	var selected: Dictionary = choice.options[intent.option_index].duplicate(true)
	var context: Dictionary = choice.context.duplicate(true)
	state.pending_choice = null
	state.phase = GamePhase.Type.RESOLVING_PLACEMENT
	RewardRules.record(state, &"reward_resolved", {"choice_id": choice.choice_id,
		"kind": String(choice.kind), "selected": selected}, int(context.get("source_id", 0)))
	match choice.kind:
		&"tile_reward", &"masterwork":
			_award_tiles(state, content, StringName(selected["definition_id"]), choice.kind == &"masterwork", context)
		&"training_piece":
			SpecialistCommands.begin_training_reward(state, int(selected["piece_id"]))
		&"major_reward":
			_major(state, content, StringName(selected["major_id"]), context)
		&"relic_offer":
			_relic(state, content, StringName(selected["definition_id"]), context)
		&"relic_replacement":
			if bool(selected.get("decline", false)):
				RelicRules.record(state, &"relic_declined", {"definition_id": String(context["definition_id"])})
			else:
				var result: ValidationResult = RelicRules.acquire(state, content,
					StringName(context["definition_id"]), StringName(selected["replace_id"]))
				assert(result.is_valid, result.user_message)


static func _award_tiles(state: RunState, content: ContentRegistry, id: StringName, masterwork: bool, context: Dictionary) -> void:
	var count: int = 3 if masterwork else RewardRules.copy_quantity(content.get_tile(id))
	var acquired: Array[int] = []
	for index: int in range(count):
		var copy_id: int = PhysicalTileRules.acquire(state, id,
			&"masterwork_reward" if masterwork else &"normal_tile_reward", TileLocationState.Kind.BAG)
		state.expansion.bag.append(copy_id)
		acquired.append(copy_id)
	state.expansion.bag = state.rng.shuffled_ids(state.expansion.bag, &"tile_reward_bag_shuffle")
	RewardRules.record(state, &"reward_tiles_acquired", {"definition_id": String(id),
		"tile_copy_ids": acquired, "quantity": count, "eligibility_act": int(context["eligibility_act"])}, int(context.get("source_id", 0)))


static func _major(state: RunState, content: ContentRegistry, id: StringName, context: Dictionary) -> void:
	match id:
		&"recruit_steward":
			SpecialistCommands.recruit(state)
		&"masterwork":
			RewardRules._prepend(state, &"masterwork", context)
		&"relic_cache":
			# Push in reverse order: the whole Relic chain completes before the tile offer.
			RewardRules._prepend(state, &"tile_reward", context)
			RewardRules._prepend(state, &"relic_offer", context)
		&"grand_survey":
			RelicHandRules.begin_grand_survey(state, content)


static func _relic(state: RunState, content: ContentRegistry, id: StringName, context: Dictionary) -> void:
	if RelicRules.equipped(state).size() < state.relics.capacity:
		var result: ValidationResult = RelicRules.acquire(state, content, id)
		assert(result.is_valid, result.user_message)
		return
	var options: Array[Dictionary] = [{"decline": true}]
	for relic: RelicInstanceState in RelicRules.equipped(state):
		if RelicRules.removal_validation(state, content, relic.definition_id).is_valid:
			options.append({"replace_id": String(relic.definition_id)})
	context["definition_id"] = String(id)
	RewardRules.create_choice(state, &"relic_replacement", options, context)


static func _fail(code: StringName, message: String) -> ValidationResult:
	return ValidationResult.failure(code, message)
