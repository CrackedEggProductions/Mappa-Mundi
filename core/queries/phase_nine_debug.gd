class_name PhaseNineDebug
extends RefCounted
## Read-only headless inspection. Secret IDs require an explicit debug opt-in.


static func inspect(state: RunState, content: ContentRegistry, reveal_secret: bool = false) -> Dictionary:
	if state.charters == null:
		return {}
	var entry_drafts: Array[Dictionary] = []
	for event: Dictionary in state.rewards.history:
		if event.get("kind") == "tile_draft_resolved" and event.get("details", {}).get("draft_type") == "act_entry":
			entry_drafts.append(event.duplicate(true))
	var result: Dictionary = {"act": state.expansion.current_act,
		"normal_placements": state.expansion.normal_placements,
		"completed_act_placements": state.charters.completed_act_placements.duplicate(),
		"ordinary_charter": CharterRules.visible_ordinary(state, content),
		"grand_charter": CharterRules.visible_grand(state, content),
		"unlocked_act": ActRules.unlocked_act(state),
		"eligible_tiles": RewardRules.tile_pool(content, ActRules.unlocked_act(state)),
		"act_entry_draft_history": entry_drafts, "pending_refill": state.expansion.pending_refill_index,
		"bonus_queue": state.charters.bonus_queue.duplicate(true)}
	result["environmental_river_path"] = EnvironmentalRiverService.path(state)
	result["river_interactions"] = RiverInteractionService.current(state)
	result["river_interaction_history"] = RiverInteractionService.creation_history(state)
	var hubs: Array[Dictionary] = []
	for hub: IntersectionHubState in IntersectionHubService.rebuild(state):
		hubs.append({"hub_id": hub.hub_id, "coordinate": hub.coordinate,
			"road_lineage_ids": hub.road_lineage_ids.duplicate(), "neighboring_hub_ids": hub.neighboring_hub_ids.duplicate()})
	result["intersection_hubs"] = hubs
	var paid_contacts: Array[Dictionary] = []
	for lineage: FeatureLineageState in state.features.lineages:
		if lineage.feature_type == DomainTypes.FeatureType.FOREST:
			paid_contacts.append({"lineage_id": lineage.lineage_id, "scored_river_ids": lineage.scored_river_ids.duplicate()})
	result["forest_river_scoring_history"] = paid_contacts
	if reveal_secret:
		result["debug_secret_grand_id"] = String(state.charters.grand_id)
	if state.act_transition != null:
		result["transition"] = PhaseNineSerializer.encode(state.act_transition, &"act_transition")
	if state.final_result != null:
		result["final_statistics"] = state.final_result.statistics.duplicate(true)
	return result
