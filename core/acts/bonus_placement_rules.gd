class_name BonusPlacementRules
extends RefCounted
## Internal effect hook. Current alpha content grants no bonus placements.


static func enqueue(state: RunState, source_id: int) -> ValidationResult:
	if state.charters == null or source_id <= 0 or source_id >= state.next_runtime_id \
			or state.act_transition != null or state.final_result != null \
			or state.phase not in [GamePhase.Type.RESOLVING_PLACEMENT, GamePhase.Type.PENDING_CHOICE]:
		return ValidationResult.failure(&"invalid_bonus_source", "Bonus work requires an active outgoing placement consequence.")
	state.charters.bonus_queue.append({"source_id": source_id, "act": state.expansion.current_act})
	return ValidationResult.success()


static func finish(state: RunState, config: RunConfig) -> bool:
	if state.charters == null:
		return false
	var charter: CharterState = state.charters
	if charter.bonus_active:
		# Bonus replacement is distinct from the original normal placement refill.
		PhysicalTileRules.refill_pending(state, config)
		charter.bonus_active = false
	if not charter.bonus_queue.is_empty():
		if state.expansion.pending_refill_index >= 0:
			assert(charter.deferred_refill_index == -1)
			charter.deferred_refill_index = state.expansion.pending_refill_index
			state.expansion.pending_refill_index = -1
		state.phase = GamePhase.Type.BONUS_INPUT
		return true
	if charter.deferred_refill_index >= 0:
		state.expansion.pending_refill_index = charter.deferred_refill_index
		charter.deferred_refill_index = -1
	return false
