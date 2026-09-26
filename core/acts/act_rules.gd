class_name ActRules
extends RefCounted
## Internal command-driven progression. Every completed step is safe to snapshot.

const STEP_KEYS: Array[StringName] = [&"evaluate_charter", &"charter_rewards",
	&"legendary_noop", &"advance_act", &"relic_capacity", &"survey_refresh",
	&"relic_refresh", &"unlock_content", &"seed_content", &"shuffle_bag",
	&"charter_information", &"reset_counter", &"pending_refill", &"turn_input"]
const ACT_TWO_SEEDS: Array[StringName] = [&"tile.development.market", &"tile.development.port",
	&"tile.transformation.urban_expansion", &"tile.development.town_square", &"tile.development.abbey"]
const ACT_THREE_SEEDS: Array[StringName] = [&"tile.transformation.bridge",
	&"tile.transformation.rewilding", &"tile.development.grand_market"]


static func ready(state: RunState, content: ContentRegistry) -> bool:
	return state.charters != null and state.expansion != null and state.pending_choice == null \
		and state.resolution == null and state.rewards.queue.is_empty() \
		and state.charters.bonus_queue.is_empty() and not state.charters.bonus_active \
		and state.expansion.normal_placements == content.get_config().act_placement_limits[state.expansion.current_act - 1]


static func unlocked_act(state: RunState) -> int:
	# Presentation/debug queries may inspect a saved boundary between steps 4 and 8.
	if state.act_transition != null and not state.act_transition.unlocked:
		return state.act_transition.outgoing_act
	return state.expansion.current_act


static func begin_transition(state: RunState, content: ContentRegistry) -> ValidationResult:
	if not ready(state, content) or state.expansion.current_act >= 3 or state.act_transition != null \
		or state.final_result != null:
		return ValidationResult.failure(&"act_transition_unavailable", "Finish the outgoing Act consequences before transitioning.")
	var transition: ActTransitionState = ActTransitionState.new()
	transition.transition_id = state.id_allocator.allocate()
	transition.outgoing_act = state.expansion.current_act
	transition.incoming_act = transition.outgoing_act + 1
	transition.pending_hand_refill = state.expansion.pending_refill_index
	state.charters.completed_act_placements[transition.outgoing_act - 1] = state.expansion.normal_placements
	state.act_transition = transition
	state.phase = GamePhase.Type.RESOLVING_ACT_TRANSITION
	_record(state, &"act_transition_started", {"transition_id": transition.transition_id,
		"outgoing_act": transition.outgoing_act, "incoming_act": transition.incoming_act})
	return ValidationResult.success()


static func _evaluate_outgoing(state: RunState, content: ContentRegistry, transition: ActTransitionState) -> void:
	var id: StringName = state.charters.act_one_id if transition.outgoing_act == 1 else state.charters.act_two_id
	var progress: CharterProgress = CharterRules.evaluate(state, content, id)
	transition.charter_result = progress.to_dict()
	transition.rewards = CharterRules.ordered_rewards(content.get_charter(id), progress.overall_state)
	transition.charter_result["evaluation_act"] = transition.outgoing_act
	transition.charter_result["transition_id"] = transition.transition_id
	transition.charter_result["rewards_generated"] = transition.rewards.duplicate()
	transition.charter_result["rewards_resolved"] = []
	transition.reward_history_start = state.rewards.history.size()
	state.charters.evaluations.append(transition.charter_result.duplicate(true))
	_record(state, &"charter_evaluated", transition.charter_result)


static func _rewards(state: RunState, content: ContentRegistry, transition: ActTransitionState) -> bool:
	while transition.pending_charter_reward_index < transition.rewards.size():
		if not transition.rewards_queued:
			var kind: StringName = transition.rewards[transition.pending_charter_reward_index]
			RewardRules.enqueue(state, kind, transition.transition_id, transition.outgoing_act)
			transition.rewards_queued = true
			state.resolution = ResolutionState.new()
			state.resolution.stage = &"reward_queue"
			state.resolution.context = {"mode": "reward"}
			_record(state, &"charter_reward_started", {"transition_id": transition.transition_id,
				"reward_index": transition.pending_charter_reward_index, "kind": String(kind),
				"eligibility_act": transition.outgoing_act})
		RewardRules.advance(state, content)
		if state.pending_choice != null:
			return false
		assert(state.rewards.queue.is_empty(), "A Charter reward chain must pause or finish")
		state.resolution = null
		transition.pending_charter_reward_index += 1
		transition.rewards_queued = false
	var resolved: Array[Dictionary] = []
	for event: Dictionary in state.rewards.history.slice(transition.reward_history_start):
		resolved.append(event.duplicate(true))
	transition.charter_result["rewards_resolved"] = resolved
	for index: int in range(state.charters.evaluations.size()):
		if int(state.charters.evaluations[index].get("transition_id", 0)) == transition.transition_id:
			state.charters.evaluations[index] = transition.charter_result.duplicate(true)
	state.phase = GamePhase.Type.RESOLVING_ACT_TRANSITION
	return true


static func seed_definitions(act: int) -> Array[StringName]:
	return ACT_TWO_SEEDS.duplicate() if act == 2 else (ACT_THREE_SEEDS.duplicate() if act == 3 else [])


static func _seed(state: RunState, transition: ActTransitionState) -> void:
	var definitions: Array[StringName] = seed_definitions(transition.incoming_act)
	for id: StringName in definitions:
		for copy_index: int in range(2):
			var copy_id: int = PhysicalTileRules.acquire(state, id, &"act_transition_seed", TileLocationState.Kind.BAG)
			state.expansion.bag.append(copy_id)
			transition.seeded_copy_ids.append(copy_id)
	transition.seeded = true
	_record(state, &"act_content_seeded", {"transition_id": transition.transition_id,
		"act": transition.incoming_act, "copy_ids": transition.seeded_copy_ids.duplicate(),
		"definition_ids": definitions})


static func _record(state: RunState, kind: StringName, details: Dictionary) -> void:
	state.charters.history.append({"event_id": state.id_allocator.allocate(), "kind": String(kind),
		"act": state.expansion.current_act, "details": details.duplicate(true)})


static func finalize(state: RunState, content: ContentRegistry) -> ValidationResult:
	if not ready(state, content) or state.expansion.current_act != 3 or state.act_transition != null \
		or state.final_result != null:
		return ValidationResult.failure(&"run_finalization_unavailable", "Resolve the entire final Act before ending the run.")
	var score: int = 0
	for amount: int in state.features.tracks.values:
		if amount < 0 or score > 9223372036854775807 - amount:
			return ValidationResult.failure(&"final_score_overflow", "Final Track sum exceeds the supported integer range.")
		score += amount
	var progress: CharterProgress = CharterRules.evaluate(state, content, state.charters.grand_id)
	var evaluation: Dictionary = progress.to_dict()
	evaluation["evaluation_act"] = 3
	evaluation["rewards_generated"] = []
	evaluation["rewards_resolved"] = []
	state.charters.evaluations.append(evaluation)
	_record(state, &"charter_evaluated", evaluation)
	var result: RunResult = RunResult.new()
	result.grand_charter_id = state.charters.grand_id
	result.grand_charter_result = progress.overall_state
	result.victory_result = &"exemplary_victory" if progress.overall_state == &"exceeded" else (
		&"victory" if progress.overall_state == &"fulfilled" else &"completed_no_victory")
	result.tracks = state.features.tracks.values.duplicate()
	result.score = score
	result.statistics = _statistics(state, result)
	state.final_result = result
	state.charters.completed_act_placements[2] = state.expansion.normal_placements
	# A final active-hand hole is deliberate; reward-added bag copies stay undrawn.
	state.expansion.pending_refill_index = -1
	state.phase = GamePhase.Type.RUN_COMPLETE
	_record(state, &"run_ended", {"grand_charter_id": String(result.grand_charter_id),
		"grand_charter_result": String(result.grand_charter_result),
		"victory_result": String(result.victory_result), "score": result.score})
	return ValidationResult.success()


static func _statistics(state: RunState, result: RunResult) -> Dictionary:
	var acquired: Array[String] = []
	var equipped: Array[String] = []
	var replaced: Array[String] = []
	var instances: Array[RelicInstanceState] = state.relics.instances.duplicate()
	instances.sort_custom(func(a: RelicInstanceState, b: RelicInstanceState) -> bool:
		return a.acquisition_order < b.acquisition_order)
	for relic: RelicInstanceState in instances:
		acquired.append(String(relic.definition_id))
		if relic.equipped_slot >= 0:
			equipped.append(String(relic.definition_id))
		else:
			replaced.append(String(relic.definition_id))
	var training: Array[Dictionary] = []
	var pieces: Array[SpecialistPieceState] = state.specialists.pieces.duplicate()
	pieces.sort_custom(func(a: SpecialistPieceState, b: SpecialistPieceState) -> bool: return a.piece_id < b.piece_id)
	for piece: SpecialistPieceState in pieces:
		training.append({"piece_id": piece.piece_id, "role_definition_id": String(piece.role_definition_id),
			"history": piece.training_history.duplicate(true)})
	return {"final_population": result.tracks[0], "final_trade": result.tracks[1],
		"final_culture": result.tracks[2], "final_ecology": result.tracks[3],
		"final_total_score": result.score, "grand_charter_id": String(result.grand_charter_id),
		"grand_charter_result": String(result.grand_charter_result),
		"largest_settlement_established": state.features.largest_completed_sizes[DomainTypes.FeatureType.SETTLEMENT],
		"longest_road_completed": state.features.largest_completed_sizes[DomainTypes.FeatureType.ROAD],
		"largest_forest_completed": state.features.largest_completed_sizes[DomainTypes.FeatureType.FOREST],
		"longest_river_completed": state.features.largest_completed_sizes[DomainTypes.FeatureType.RIVER],
		"relics_acquired": acquired, "relics_equipped": equipped, "relics_replaced": replaced,
		"relic_history": state.relics.history.duplicate(true), "specialist_training": training,
		"charters": state.charters.evaluations.duplicate(true), "run_seed": state.original_seed}


static func advance(state: RunState, content: ContentRegistry) -> ValidationResult:
	while state.act_transition != null and state.pending_choice == null:
		var result: ValidationResult = advance_one(state, content)
		if not result.is_valid:
			return result
	return ValidationResult.success()


static func advance_one(state: RunState, content: ContentRegistry) -> ValidationResult:
	if state.act_transition == null or state.pending_choice != null or state.final_result != null \
		or state.charters.bonus_active or not state.charters.bonus_queue.is_empty():
		return ValidationResult.failure(&"act_step_unavailable", "No settled Act transition step is available.")
	var transition: ActTransitionState = state.act_transition
	state.phase = GamePhase.Type.RESOLVING_ACT_TRANSITION
	match transition.step:
		1:
			_evaluate_outgoing(state, content, transition)
		2:
			if not _rewards(state, content, transition):
				return ValidationResult.success()
		3:
			pass # Legendary Projects are deliberately absent from the alpha.
		4:
			state.expansion.current_act = transition.incoming_act
			transition.advanced = true
		5:
			state.relics.capacity = RelicRules.capacity_for_act(transition.incoming_act)
			transition.capacity_refreshed = true
		6:
			state.expansion.survey_charges = 1
			transition.survey_refreshed = true
		7:
			var refresh: ValidationResult = RelicRules.refresh_act(state, transition.incoming_act)
			assert(refresh.is_valid, refresh.user_message)
			transition.relics_refreshed = true
		8:
			transition.unlocked = true
		9:
			_seed(state, transition)
		10:
			state.expansion.bag = state.rng.shuffled_ids(state.expansion.bag, &"act_transition_bag_shuffle")
			transition.shuffled = true
		11:
			if transition.incoming_act == 2:
				CharterRules.select_ordinary(state, content, 2)
				CharterRules.select_grand(state, content)
			transition.information_selected = true
		12:
			state.expansion.normal_placements = 0
			transition.counter_reset = true
		13:
			PhysicalTileRules.refill_pending(state, content.get_config())
			transition.refill_done = true
		14:
			state.phase = GamePhase.Type.TURN_INPUT
		_:
			return ValidationResult.failure(&"invalid_act_step", "Unknown Act transition step.")
	_record(state, &"act_transition_step", {"transition_id": transition.transition_id,
		"outgoing_act": transition.outgoing_act, "incoming_act": transition.incoming_act,
		"step": transition.step, "step_key": String(STEP_KEYS[transition.step - 1])})
	if transition.step == 14:
		_record(state, &"act_started", {"act": transition.incoming_act, "transition_id": transition.transition_id})
		state.act_transition = null
	else:
		transition.step += 1
	return ValidationResult.success()
