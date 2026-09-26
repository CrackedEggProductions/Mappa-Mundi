class_name CharterRules
extends RefCounted
## Explicit alpha queries. Selection is called only at engine-owned information steps.

const TYPE = DomainTypes.FeatureType
const TRACKS: Dictionary = {"population": 0, "trade": 1, "culture": 2, "ecology": 3}


static func evaluate(state: RunState, content: ContentRegistry, id: StringName) -> CharterProgress:
	var progress: CharterProgress = CharterProgress.new()
	progress.charter_id = id
	var definition: CharterDefinition = content.get_charter(id)
	if definition == null or state.features == null:
		progress.overall_state = &"invalid"
		return progress
	var targets: Dictionary = definition.targets
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	var networks: Array[CurrentTradeNetwork] = TradeNetworkService.rebuild(state)
	for name: String in TRACKS:
		if targets.has(name):
			progress.add(StringName(name), state.features.tracks.values[TRACKS[name]], int(targets[name]))
	match definition.behavior_id:
		&"a1_growing_realm":
			progress.add(&"settlement_completions", completion_count(state, TYPE.SETTLEMENT), int(targets["settlement_completions"]), &"history")
		&"a1_open_roads":
			progress.add(&"road_completions", completion_count(state, TYPE.ROAD), int(targets["road_completions"]), &"history")
			progress.add(&"network_settlements", _largest_network(networks), int(targets["network_settlements"]))
		&"a1_living_landscape":
			progress.add(&"forest_completions", completion_count(state, TYPE.FOREST), int(targets["forest_completions"]), &"history")
			progress.add(&"river_completions", completion_count(state, TYPE.RIVER), int(targets["river_completions"]), &"history")
		&"a2_market_towns":
			var markets: Array[int] = _commercial_settlements(state, current, false)
			progress.add(&"market_settlements", markets.size(), int(targets["market_settlements"]), &"current_state", false, markets)
			progress.add(&"historically_completed_road", _completed_road_count(state, networks), 1, &"history")
			progress.add(&"network_settlements", _largest_network(_historical_networks(state, networks)), int(targets["network_settlements"]))
		&"a2_growing_communities":
			_growing_communities(progress, state, current, targets)
		&"a2_stewardship_of_land", &"grand_living_heritage":
			progress.add(&"forest_size", _largest_feature(current, TYPE.FOREST), int(targets["forest_size"]))
			progress.add(&"river_size", _largest_feature(current, TYPE.RIVER), int(targets["river_size"]))
			if definition.behavior_id == &"grand_living_heritage":
				progress.add(&"enclosure_completions", completion_count(state, -1), int(targets["enclosure_completions"]), &"history")
		&"grand_great_metropolis":
			_metropolis(progress, state, current, networks, targets)
		&"grand_merchant_republic":
			_merchant_republic(progress, state, current, networks, targets)
	for name: String in TRACKS:
		var key: String = "exceed_" + name
		if targets.has(key):
			progress.add(StringName(key), state.features.tracks.values[TRACKS[name]], int(targets[key]), &"current_state", true)
	progress.finish()
	return progress


static func completion_count(state: RunState, feature_type: int) -> int:
	var result: int = 0
	for record: FeatureCompletionRecord in state.features.completions:
		if feature_type == -1:
			if record.enclosure_id > 0 and record.enclosure_stage in [&"monastery", &"abbey"]:
				result += 1
		elif record.enclosure_id == 0 and record.feature_type == feature_type:
			result += 1
	return result


static func _growing_communities(progress: CharterProgress, state: RunState,
		current: Array[CurrentFeature], targets: Dictionary) -> void:
	progress.add(&"settlement_size", _largest_feature(current, TYPE.SETTLEMENT), int(targets["settlement_size"]))
	var best_developments: int = 0
	var witnesses: Array[int] = []
	for feature: CurrentFeature in current:
		if feature.feature_type != TYPE.SETTLEMENT or feature.coordinates.size() < int(targets["settlement_size"]):
			continue
		var count: int = 0
		for development: DevelopmentState in DevelopmentService.all(state):
			if development.host_kind == &"settlement" and development.host_lineage_id == feature.lineage_id:
				count += 1
		best_developments = maxi(best_developments, count)
		if count >= int(targets["developments"]):
			witnesses.append(feature.lineage_id)
	progress.add(&"developments_on_size_qualified_settlement", best_developments, int(targets["developments"]), &"current_state", false, witnesses)


static func _metropolis(progress: CharterProgress, state: RunState, current: Array[CurrentFeature],
		networks: Array[CurrentTradeNetwork], targets: Dictionary) -> void:
	var largest_completed: int = 0
	var best_families: int = 0
	var best_others: int = 0
	var witnesses: Array[int] = []
	for feature: CurrentFeature in current:
		if feature.feature_type != TYPE.SETTLEMENT:
			continue
		var lineage: FeatureLineageState = state.features.lineage(feature.lineage_id)
		# Human ruling: a reopened unfinished Settlement cannot fulfill Great Metropolis.
		if lineage == null or not lineage.completed or feature.open_exits != 0 or lineage.completion_ids.is_empty():
			continue
		largest_completed = maxi(largest_completed, feature.coordinates.size())
		if feature.coordinates.size() < int(targets["settlement_size"]):
			continue
		var families: int = DevelopmentService.families(state, feature.lineage_id).size()
		best_families = maxi(best_families, families)
		if families < int(targets["development_families"]):
			continue
		var others: int = 0
		for network: CurrentTradeNetwork in networks:
			if feature.lineage_id in network.settlement_lineage_ids:
				others = maxi(others, network.settlement_lineage_ids.size() - 1)
		best_others = maxi(best_others, others)
		if others >= int(targets["other_settlements"]):
			witnesses.append(feature.lineage_id)
	progress.add(&"currently_established_settlement_size", largest_completed, int(targets["settlement_size"]))
	progress.add(&"families_on_established_size_qualified_settlement", best_families, int(targets["development_families"]))
	progress.add(&"other_settlements_for_same_qualified_settlement", best_others, int(targets["other_settlements"]), &"current_state", false, witnesses)
	# Human ruling: the additional size-ten Settlement may be any current Settlement.
	progress.add(&"exceed_settlement_size", _largest_feature(current, TYPE.SETTLEMENT), int(targets["exceed_settlement_size"]), &"current_state", true)


static func _merchant_republic(progress: CharterProgress, state: RunState,
		current: Array[CurrentFeature], networks: Array[CurrentTradeNetwork], targets: Dictionary) -> void:
	var historical: Array[CurrentTradeNetwork] = _historical_networks(state, networks)
	var commercial: Array[int] = _commercial_settlements(state, current, true)
	var best_commercial: int = 0
	var largest_qualified: int = 0
	var witnesses: Array[int] = []
	for network: CurrentTradeNetwork in historical:
		if network.settlement_lineage_ids.size() < int(targets["network_settlements"]):
			continue
		var count: int = 0
		for id: int in network.settlement_lineage_ids:
			if id in commercial:
				count += 1
		best_commercial = maxi(best_commercial, count)
		if count >= int(targets["commercial_settlements"]):
			largest_qualified = maxi(largest_qualified, network.settlement_lineage_ids.size())
			witnesses.append(network.lineage_id)
	progress.add(&"historically_completed_road", _completed_road_count(state, networks), 1, &"history")
	progress.add(&"network_settlements", _largest_network(historical), int(targets["network_settlements"]))
	progress.add(&"commercial_settlements_in_same_network", best_commercial, int(targets["commercial_settlements"]), &"current_state", false, witnesses)
	progress.add(&"exceed_network_settlements", largest_qualified, int(targets["exceed_network_settlements"]), &"current_state", true)


static func _largest_feature(current: Array[CurrentFeature], type: int) -> int:
	var result: int = 0
	for feature: CurrentFeature in current:
		if feature.feature_type == type:
			result = maxi(result, feature.coordinates.size())
	return result


static func _largest_network(networks: Array[CurrentTradeNetwork]) -> int:
	var result: int = 0
	for network: CurrentTradeNetwork in networks:
		result = maxi(result, network.settlement_lineage_ids.size())
	return result


static func _historical_networks(state: RunState, networks: Array[CurrentTradeNetwork]) -> Array[CurrentTradeNetwork]:
	var result: Array[CurrentTradeNetwork] = []
	for network: CurrentTradeNetwork in networks:
		for id: int in network.road_lineage_ids:
			var lineage: FeatureLineageState = state.features.lineage(id)
			# Inherited genuine completion history survives merger and reopening.
			if lineage != null and not lineage.completion_ids.is_empty():
				result.append(network)
				break
	return result


static func _completed_road_count(state: RunState, networks: Array[CurrentTradeNetwork]) -> int:
	var roads: Array[int] = []
	for network: CurrentTradeNetwork in networks:
		for id: int in network.road_lineage_ids:
			var lineage: FeatureLineageState = state.features.lineage(id)
			if lineage != null and not lineage.completion_ids.is_empty() and id not in roads:
				roads.append(id)
	return roads.size()


static func _commercial_settlements(state: RunState, current: Array[CurrentFeature],
		include_port: bool) -> Array[int]:
	var result: Array[int] = []
	for feature: CurrentFeature in current:
		if feature.feature_type != TYPE.SETTLEMENT:
			continue
		var families: Array[StringName] = DevelopmentService.families(state, feature.lineage_id)
		if &"family.market" in families or (include_port and &"family.port" in families):
			result.append(feature.lineage_id)
	result.sort()
	return result


static func ordered_rewards(definition: CharterDefinition, result: StringName) -> Array[StringName]:
	var rewards: Array[StringName] = []
	if definition == null or result not in [&"fulfilled", &"exceeded"]:
		return rewards
	rewards.append_array(definition.fulfill_rewards)
	if result == &"exceeded":
		rewards.append_array(definition.exceed_rewards)
	return rewards


static func select_ordinary(state: RunState, content: ContentRegistry, act: int) -> StringName:
	assert(state.charters != null and act in [1, 2])
	var existing: StringName = state.charters.act_one_id if act == 1 else state.charters.act_two_id
	if existing != &"":
		return existing
	var selected: StringName = state.rng.choose_definition_id(content.get_charter_ids(act), &"charter_selection")
	if act == 1:
		state.charters.act_one_id = selected
	else:
		state.charters.act_two_id = selected
	_record(state, &"charter_selected", selected)
	return selected


static func select_grand(state: RunState, content: ContentRegistry) -> StringName:
	assert(state.charters != null and state.expansion.current_act == 2)
	if state.charters.grand_id != &"":
		return state.charters.grand_id
	state.charters.grand_id = state.rng.choose_definition_id(content.get_charter_ids(3), &"grand_charter_selection")
	state.charters.forecast_visible = true
	_record(state, &"grand_charter_selected", state.charters.grand_id)
	_record(state, &"grand_charter_forecast_revealed", state.charters.grand_id)
	return state.charters.grand_id


static func reveal_grand(state: RunState) -> void:
	assert(state.charters != null and state.charters.grand_id != &"")
	if state.charters.exact_revealed:
		return
	state.charters.exact_revealed = true
	state.charters.exact_revealed_act = state.expansion.current_act
	state.charters.exact_revealed_index = state.expansion.normal_placements
	_record(state, &"grand_charter_exact_revealed", state.charters.grand_id)


static func visible_grand(state: RunState, content: ContentRegistry) -> Dictionary:
	if state.charters == null or not state.charters.forecast_visible:
		return {}
	var definition: CharterDefinition = content.get_charter(state.charters.grand_id)
	if definition == null:
		return {}
	var result: Dictionary = {"forecast": definition.forecast_text, "exact_revealed": state.charters.exact_revealed}
	if state.charters.exact_revealed:
		result["charter_id"] = String(definition.definition_id)
		result["display_name"] = definition.display_name
		result["targets"] = definition.targets.duplicate(true)
		result["progress"] = evaluate(state, content, definition.definition_id).to_dict()
	return result


static func visible_ordinary(state: RunState, content: ContentRegistry) -> Dictionary:
	if state.charters == null or state.expansion.current_act == 3:
		return {}
	var id: StringName = state.charters.act_one_id if state.expansion.current_act == 1 else state.charters.act_two_id
	var definition: CharterDefinition = content.get_charter(id)
	if definition == null:
		return {}
	return {"charter_id": String(id), "display_name": definition.display_name,
		"targets": definition.targets.duplicate(true), "progress": evaluate(state, content, id).to_dict()}


static func _record(state: RunState, kind: StringName, id: StringName) -> void:
	state.charters.history.append({"event_id": state.id_allocator.allocate(), "kind": String(kind),
		"act": state.expansion.current_act, "placement_index": state.expansion.normal_placements,
		"charter_id": String(id)})
