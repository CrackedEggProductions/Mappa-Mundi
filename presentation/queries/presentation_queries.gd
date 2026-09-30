class_name PresentationQueries
extends RefCounted
## Display-only adapters. All topology, progress and results come from core queries/state.

const EDGE_NAMES: Array[String] = ["Field", "Forest", "River", "Road", "Settlement"]
const TRACK_NAMES: Array[String] = ["Population", "Trade", "Culture", "Ecology"]
const CONDITION_NAMES: Dictionary = {
	"settlement_completions": "Genuine Settlement completions",
	"road_completions": "Genuine Road completions",
	"forest_completions": "Genuine Forest completions",
	"river_interactions_created": "River interactions created",
	"enclosure_completions": "Monastery-family completions",
	"network_settlements": "Settlements in a qualifying Trade Network",
	"historically_completed_road": "Roads with genuine completion history",
	"market_settlements": "Current Settlements with Market family",
	"settlement_size": "Current Settlement size",
	"forest_size": "Current Forest size",
	"active_river_interactions": "Current active River interactions",
	"developments_on_size_qualified_settlement": "Developments in that size-qualified Settlement",
	"currently_established_settlement_size": "Currently completed Settlement size",
	"families_on_established_size_qualified_settlement": "Distinct Development families in that completed Settlement",
	"other_settlements_for_same_qualified_settlement": "Other Settlements linked to that same qualifying Settlement",
	"commercial_settlements_in_same_network": "Settlements with Market family or Port in that same network",
	"exceed_settlement_size": "Any current Settlement size",
	"exceed_network_settlements": "Settlements in that qualifying Trade Network",
}


static func charter_text(state: RunState, content: ContentRegistry) -> String:
	var sections: Array[String] = []
	var ordinary: Dictionary = CharterRules.visible_ordinary(state, content)
	if not ordinary.is_empty():
		sections.append(_charter_section(ordinary))
	var grand: Dictionary = CharterRules.visible_grand(state, content)
	if not grand.is_empty():
		if bool(grand.get("exact_revealed", false)):
			sections.append(_charter_section(grand))
		else:
			sections.append("Grand Charter forecast\n" + String(grand.get("forecast", "")))
	return "\n\n".join(sections) if not sections.is_empty() else "Charter information is not yet available."


static func _charter_section(visible: Dictionary) -> String:
	var progress: Dictionary = visible.get("progress", {})
	var lines: Array[String] = [String(visible.get("display_name", "Charter")),
		"Current result: " + ("Incomplete" if progress.get("overall_state", "failed") == "failed" else _result_name(String(progress.get("overall_state", "failed"))))]
	for exceed: bool in [false, true]:
		lines.append("Exceed — also requires every Fulfill condition:" if exceed else "Fulfill:")
		for condition: Dictionary in progress.get("conditions", []):
			if bool(condition.get("exceed", false)) != exceed:
				continue
			var key: String = String(condition.get("key", ""))
			var label: String = String(CONDITION_NAMES.get(key, key.trim_prefix("exceed_").capitalize()))
			var source: String = "history" if condition.get("source", "") == "history" else "current"
			lines.append("%s %s: %s / %s (%s)" % ["✓" if condition.get("satisfied", false) else "○",
				label, condition.get("current", 0), condition.get("target", 0), source])
	return "\n".join(lines)


static func specialists_text(state: RunState, content: ContentRegistry) -> String:
	if state.specialists == null:
		return "Stewards unavailable."
	var lines: Array[String] = []
	for piece: SpecialistPieceState in state.specialists.pieces:
		var label: String = ChoiceText.piece_label(state, content, piece.piece_id)
		if piece.status == SpecialistPieceState.Status.ASSIGNED:
			label += " — ASSIGNED\n" + ChoiceText.target_label(state, piece.assigned_target_type, piece.assigned_target_id)
		else:
			label += " — AVAILABLE"
		lines.append(label)
	return "\n\n".join(lines)


static func relics_text(state: RunState, content: ContentRegistry) -> String:
	if state.relics == null:
		return "Relics unavailable."
	var lines: Array[String] = ["Relic capacity: %d" % state.relics.capacity]
	for slot: int in range(state.relics.capacity):
		var equipped: RelicInstanceState = null
		for relic: RelicInstanceState in state.relics.instances:
			if relic.equipped_slot == slot:
				equipped = relic
				break
		if equipped == null:
			lines.append("Slot %d — empty" % (slot + 1))
		else:
			var label: String = _relic_name(content, equipped.definition_id)
			if equipped.once_per_act:
				label += " — %d use(s) remaining this Act" % equipped.uses_remaining
			lines.append(label + "\n" + ChoiceText.description(equipped.definition_id))
	return "\n\n".join(lines)


static func inspect_tile(state: RunState, content: ContentRegistry, coordinate: Vector2i) -> String:
	var cell: BoardCellState = state.expansion.board.get_cell(coordinate)
	if cell == null:
		return "Open map at (%d, %d)" % [coordinate.x, coordinate.y]
	var definition: TileDefinition = content.get_tile(cell.definition_id)
	var lines: Array[String] = [definition.display_name if definition != null else "Tile",
		"(%d, %d) · placed Act %d" % [coordinate.x, coordinate.y, cell.act_placed]]
	if definition != null and definition.setup_environment:
		lines.append("Setup environment — this River is landscape and does not complete.")
	if cell.intersection_hub:
		lines.append("Intersection hub — Roads terminate here; Trade continues through every connected arm. Adds no physical Road length.")
	var edges: Array[String] = []
	const DIRECTIONS: Array[String] = ["N", "E", "S", "W"]
	for direction: int in range(cell.effective_edges.size()):
		edges.append(DIRECTIONS[direction] + ": " + EDGE_NAMES[cell.effective_edges[direction]])
	lines.append(" · ".join(edges))
	for development: DevelopmentState in cell.developments:
		lines.append("Development: " + String(development.stage).capitalize())
	for transformation: TransformationState in cell.transformations:
		var transformed: TileDefinition = content.get_tile(transformation.definition_id)
		lines.append("Transformation: " + (transformed.display_name if transformed != null else String(transformation.mode).capitalize()))
	var networks: Array[CurrentTradeNetwork] = TradeNetworkService.rebuild(state)
	for feature: CurrentFeature in TopologyService.rebuild(state):
		if coordinate not in feature.coordinates:
			continue
		var lineage: FeatureLineageState = state.features.lineage(feature.lineage_id)
		var complete: bool = lineage != null and lineage.completed
		var lifecycle: String = "environment" if feature.feature_type == DomainTypes.FeatureType.RIVER else (
			"completed" if complete else "unfinished")
		lines.append("%s · %d tiles · %s" % [ChoiceText.feature_name(feature.feature_type),
			feature.coordinates.size(), lifecycle])
		if feature.feature_type == DomainTypes.FeatureType.RIVER:
			_append_river_contacts(lines, state, feature)
		for network: CurrentTradeNetwork in networks:
			if feature.lineage_id in network.road_lineage_ids or feature.lineage_id in network.settlement_lineage_ids:
				lines.append("Trade Network reaches %d distinct Settlements" % network.settlement_lineage_ids.size())
		_append_pieces(lines, state, content, feature.feature_type, feature.lineage_id)
	for enclosure: EnclosureState in state.features.enclosures:
		if enclosure.coordinate == coordinate:
			lines.append("%s enclosure · %s" % [String(enclosure.stage).capitalize(),
				"completed" if enclosure.stage in enclosure.completed_stages else "unfinished"])
			_append_pieces(lines, state, content, SpecialistRules.ENCLOSURE, enclosure.enclosure_id)
	return "\n".join(lines)


static func _append_river_contacts(lines: Array[String], state: RunState, river: CurrentFeature) -> void:
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	var settlements: Array[int] = SpecialistRules.touching_settlements(state, river, current)
	var forests: int = 0
	var river_tiles: Array[int] = []
	for coordinate: Vector2i in river.coordinates:
		river_tiles.append(state.expansion.board.get_cell(coordinate).base_tile_copy_id)
	for feature: CurrentFeature in current:
		if feature.feature_type != DomainTypes.FeatureType.FOREST:
			continue
		for id: int in FeatureContactService.support_ids(state, feature, DomainTypes.EdgeType.RIVER):
			if id in river_tiles:
				forests += 1
				break
	lines.append("River contacts: %d Settlements · %d Forests" % [settlements.size(), forests])
	for interaction: Dictionary in RiverInteractionService.current(state):
		if river.lineage_id in interaction["river_ids"]:
			var at: Vector2i = interaction["coordinate"]
			lines.append("River interaction: %s at (%d, %d)" % [String(interaction["kind"]).capitalize(), at.x, at.y])


static func _append_pieces(lines: Array[String], state: RunState, content: ContentRegistry, type: int, id: int) -> void:
	if state.specialists == null:
		return
	for piece: SpecialistPieceState in state.specialists.pieces:
		if piece.status == SpecialistPieceState.Status.ASSIGNED and piece.assigned_target_type == type and piece.assigned_target_id == id:
			lines.append(ChoiceText.piece_label(state, content, piece.piece_id) + " assigned to this feature")


static func results_text(state: RunState, content: ContentRegistry) -> String:
	var result: RunResult = state.final_result
	if result == null:
		return "The run is still in progress."
	var outcomes: Dictionary = {&"completed_no_victory": "Completed run — No Victory",
		&"victory": "Victory", &"exemplary_victory": "Exemplary Victory"}
	var lines: Array[String] = [String(outcomes.get(result.victory_result, "Completed run")),
		"Final score: %d" % result.score]
	for index: int in range(TRACK_NAMES.size()):
		lines.append("%s: %d" % [TRACK_NAMES[index], result.tracks[index]])
	var stats: Dictionary = result.statistics
	lines.append("Grand Charter: %s — %s" % [_charter_name(content, result.grand_charter_id), _result_name(String(result.grand_charter_result))])
	for record: Array in [["Largest Settlement established", "largest_settlement_established"],
		["Longest Road completed", "longest_road_completed"], ["Largest Forest completed", "largest_forest_completed"],
		["Longest connected River", "longest_river_size"],
		["Active River interactions", "river_interaction_count"]]:
		lines.append("%s: %s" % [record[0], stats.get(record[1], 0)])
	lines.append("\nCharter results")
	for evaluation: Dictionary in stats.get("charters", []):
		lines.append("%s — %s" % [_charter_name(content, StringName(evaluation.get("charter_id", ""))),
			_result_name(String(evaluation.get("overall_state", "failed")))])
	for kind: String in ["acquired", "equipped", "replaced"]:
		var names: Array[String] = []
		for id: String in stats.get("relics_" + kind, []):
			names.append(_relic_name(content, StringName(id)))
		lines.append("Relics %s: %s" % [kind, ", ".join(names) if not names.is_empty() else "none"])
	lines.append("\nSpecialist training")
	var training: Array = stats.get("specialist_training", [])
	for index: int in range(training.size()):
		var role: StringName = StringName(training[index].get("role_definition_id", ""))
		var definition: SpecialistDefinition = content.get_specialist(role)
		var name: String = definition.display_name if definition != null else "Generic Steward (untrained)"
		lines.append("Piece %d: %s" % [index + 1, name])
		for record: Dictionary in training[index].get("history", []):
			lines.append("Trained in Act %s" % record.get("act", "?"))
	lines.append("Run seed: %s" % str(stats.get("run_seed", state.original_seed)))
	return "\n".join(lines)


static func transition_text(state: RunState, content: ContentRegistry, outgoing_act: int) -> String:
	var lines: Array[String] = ["Act %d completed" % outgoing_act]
	for evaluation: Dictionary in state.charters.evaluations:
		if int(evaluation.get("evaluation_act", 0)) == outgoing_act:
			lines.append("%s — %s" % [_charter_name(content, StringName(evaluation.get("charter_id", ""))),
				_result_name(String(evaluation.get("overall_state", "failed")))])
	lines.append("Entering Act %d · Relic capacity %d" % [state.expansion.current_act, state.relics.capacity])
	for index: int in range(TRACK_NAMES.size()):
		lines.append("%s: %d" % [TRACK_NAMES[index], state.features.tracks.values[index]])
	var names: Array[String] = []
	for id: StringName in content.get_config().entry_draft_pool(state.expansion.current_act):
		var definition: TileDefinition = content.get_tile(id)
		names.append(definition.display_name if definition != null else "Tile")
	if not names.is_empty():
		lines.append("New possibilities: " + ", ".join(names))
		lines.append("Each entry draft adds one copy of the design you choose.")
	return "\n".join(lines)


static func _charter_name(content: ContentRegistry, id: StringName) -> String:
	var definition: CharterDefinition = content.get_charter(id)
	return definition.display_name if definition != null else "Charter"


static func _relic_name(content: ContentRegistry, id: StringName) -> String:
	var definition: RelicDefinition = content.get_relic(id)
	return definition.display_name if definition != null else "Relic"


static func _result_name(result: String) -> String:
	return result.capitalize()


static func hud_model(state: RunState, content: ContentRegistry) -> Dictionary:
	var act: int = state.expansion.current_act
	var used: int = state.expansion.normal_placements
	var incoming: bool = state.act_transition != null and state.act_transition.advanced and not state.act_transition.counter_reset
	if incoming:
		used = 0
	var config: RunConfig = content.get_config()
	var tracks: Array[Dictionary] = []
	for index: int in range(4):
		var next: int = 0
		var reward: String = "All rewards earned"
		for threshold: int in range(config.track_thresholds.size()):
			var kind: StringName = config.track_threshold_reward_kinds[threshold]
			if kind != &"none" and config.track_thresholds[threshold] > state.features.tracks.values[index]:
				next = config.track_thresholds[threshold]
				reward = String({&"training_reward": "Train", &"relic_offer": "Relic", &"major_reward": "Major"}.get(kind, "Reward"))
				break
		tracks.append({"value": state.features.tracks.values[index], "next_threshold": next, "next_reward": reward})
	var objective: Dictionary = CharterRules.visible_grand(state, content) if act == 3 else CharterRules.visible_ordinary(state, content)
	var count: int = 0
	var satisfied: int = 0
	for condition: Dictionary in objective.get("progress", {}).get("conditions", []):
		if not bool(condition.get("exceed", false)):
			count += 1
			satisfied += int(bool(condition.get("satisfied", false)))
	var next_draft: int = TileDraftService.next_draft_placement(state, config)
	return {"act": act, "incoming": incoming, "used": used, "limit": config.act_placement_limits[act - 1],
		"tracks": tracks, "charter_name": objective.get("display_name", "Charter"),
		"satisfied": satisfied, "conditions": count, "next_draft": next_draft,
		"draft_distance": maxi(0, next_draft - used)}
