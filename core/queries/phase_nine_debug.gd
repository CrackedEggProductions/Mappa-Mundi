class_name PhaseNineDebug
extends RefCounted
## Read-only headless inspection. Secret IDs require an explicit debug opt-in.


static func inspect(state: RunState, content: ContentRegistry, reveal_secret: bool = false) -> Dictionary:
	if state.charters == null:
		return {}
	var seeds: Array[Dictionary] = []
	for event: Dictionary in state.charters.history:
		if event.get("kind") == "act_content_seeded":
			seeds.append(event.duplicate(true))
	var result: Dictionary = {"act": state.expansion.current_act,
		"normal_placements": state.expansion.normal_placements,
		"completed_act_placements": state.charters.completed_act_placements.duplicate(),
		"ordinary_charter": CharterRules.visible_ordinary(state, content),
		"grand_charter": CharterRules.visible_grand(state, content),
		"unlocked_act": ActRules.unlocked_act(state),
		"eligible_tiles": RewardRules.tile_pool(content, ActRules.unlocked_act(state)),
		"seed_history": seeds, "pending_refill": state.expansion.pending_refill_index,
		"bonus_queue": state.charters.bonus_queue.duplicate(true)}
	if reveal_secret:
		result["debug_secret_grand_id"] = String(state.charters.grand_id)
	if state.act_transition != null:
		result["transition"] = PhaseNineSerializer.encode(state.act_transition, &"act_transition")
	if state.final_result != null:
		result["final_statistics"] = state.final_result.statistics.duplicate(true)
	return result
