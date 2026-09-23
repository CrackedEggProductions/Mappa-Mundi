class_name FeatureScoringService
extends RefCounted
## Capture every genuine completion before applying any member of the batch.
## Historical eligibility is copied into the snapshot along with current contact.


static func capture(state: RunState, current: Array[CurrentFeature], source_id: int = 0) -> CompletionSnapshot:
	var features: Array[Dictionary] = []
	var trigger_ids: Array[int] = []
	# Rebuild once before any scoring: every simultaneous Road sees the same graph.
	var networks: Array[CurrentTradeNetwork] = []
	if state.trade != null:
		networks = TradeNetworkService.rebuild(state)
	var ordered: Array[CurrentFeature] = current.duplicate()
	ordered.sort_custom(func(a: CurrentFeature, b: CurrentFeature) -> bool: return a.lineage_id < b.lineage_id)
	for feature: CurrentFeature in ordered:
		var lineage: FeatureLineageState = state.features.lineage(feature.lineage_id)
		if feature.open_exits != 0 or lineage.completed:
			continue
		var field_ids: Array[int] = []
		var river_ids: Array[int] = []
		var forest_ids: Array[int] = []
		var network_id: int = 0
		var network_roads: Array[int] = []
		var network_settlements: Array[int] = []
		if feature.feature_type == DomainTypes.FeatureType.SETTLEMENT:
			field_ids = FeatureContactService.support_ids(state, feature, DomainTypes.EdgeType.FIELD)
			river_ids = FeatureContactService.support_ids(state, feature, DomainTypes.EdgeType.RIVER)
		elif feature.feature_type == DomainTypes.FeatureType.RIVER:
			forest_ids = FeatureContactService.support_ids(state, feature, DomainTypes.EdgeType.FOREST)
		elif feature.feature_type == DomainTypes.FeatureType.ROAD:
			for network: CurrentTradeNetwork in networks:
				if network.road_lineage_ids.has(lineage.lineage_id):
					network_id = network.lineage_id
					network_roads = network.road_lineage_ids.duplicate()
					network_settlements = network.settlement_lineage_ids.duplicate()
					break
		trigger_ids.append(feature.lineage_id)
		features.append({
			"lineage_id": lineage.lineage_id, "feature_type": feature.feature_type,
			"component_ids": feature.component_ids.duplicate(), "total_size": feature.component_ids.size(),
			"first_completion": lineage.completion_ids.is_empty(), "growth_phase": lineage.growth_phase,
			"highest_settlement_class": lineage.highest_settlement_class,
			"development_families": DevelopmentService.families(state, feature.lineage_id),
			"new_component_ids": _difference(feature.component_ids, lineage.scored_component_ids),
			"field_support_ids": field_ids, "river_support_ids": river_ids, "forest_contact_ids": forest_ids,
			"new_field_ids": _difference(field_ids, lineage.scored_field_ids),
			"new_river_ids": _difference(river_ids, lineage.scored_river_ids),
			"new_forest_ids": _difference(forest_ids, lineage.scored_forest_ids),
			"trade_network_id": network_id, "network_road_ids": network_roads,
			"network_settlement_ids": network_settlements,
			"new_settlement_ids": _unpaid_settlements(state, lineage, network_settlements),
			"undeveloped": FeatureContactService.forest_is_undeveloped(state, feature),
		})
	return CompletionSnapshot.new({
		"act": state.expansion.current_act, "placement_index": state.expansion.normal_placements,
		"source_id": source_id, "board_revision": state.expansion.board.revision,
		"topology_revision": state.features.topology_revision,
		"trade_revision": state.trade.trade_revision if state.trade != null else 0,
		"tracks": state.features.tracks.values.duplicate(), "features": features,
		"enclosures": EnclosureService.capture(state),
		"developments": DevelopmentEffects.capture(state, current, trigger_ids),
	})


static func calculate(snapshot: CompletionSnapshot) -> Array[FeatureCompletionRecord]:
	var records: Array[FeatureCompletionRecord] = []
	var data: Dictionary = snapshot.data()
	for facts: Dictionary in data["features"]:
		var record: FeatureCompletionRecord = _record(data)
		record.lineage_id = facts["lineage_id"]
		record.feature_type = facts["feature_type"]
		record.total_size = facts["total_size"]
		record.first_completion = facts["first_completion"]
		record.growth_phase = facts["growth_phase"]
		record.trade_network_id = facts.get("trade_network_id", 0)
		record.development_families.assign(facts.get("development_families", []))
		record.highest_class_before_completion = facts.get("highest_settlement_class", 0)
		record.forest_undeveloped = facts.get("undeveloped", true)
		for key: String in ["component_ids", "new_component_ids", "field_support_ids", "river_support_ids", "forest_contact_ids", "new_field_ids", "new_river_ids", "new_forest_ids"]:
			var values: Array[int] = []
			values.assign(facts[key])
			record.set(key, values)
		for key: String in ["network_road_ids", "network_settlement_ids", "new_settlement_ids"]:
			var values: Array[int] = []
			values.assign(facts.get(key, []))
			record.set(key, values)
		match record.feature_type:
			DomainTypes.FeatureType.SETTLEMENT:
				record.gains[DomainTypes.TrackType.POPULATION] = 2 * record.new_component_ids.size() + record.new_field_ids.size() + record.new_river_ids.size()
				# Current Development qualification, with highest achieved class retained.
				var qualified: int = 1 if record.total_size <= 2 else (2 if record.total_size <= 5 else 0)
				if record.total_size >= 6 and record.total_size <= 8 and not record.development_families.is_empty():
					qualified = 3
				elif record.total_size >= 9 and record.development_families.size() >= 2:
					qualified = 4
				record.settlement_class = maxi(qualified, int(facts.get("highest_settlement_class", 0)))
			DomainTypes.FeatureType.ROAD:
				record.gains[DomainTypes.TrackType.TRADE] = record.new_component_ids.size() + 2 * record.new_settlement_ids.size()
			DomainTypes.FeatureType.FOREST:
				record.gains[DomainTypes.TrackType.ECOLOGY] = record.new_component_ids.size() + (2 if facts["undeveloped"] else 0)
			DomainTypes.FeatureType.RIVER:
				# Completed Rivers cannot reopen; inherited completion prevents length farming.
				var length_gain: int = floori(record.total_size / 2.0) if record.first_completion else 0
				record.gains[DomainTypes.TrackType.ECOLOGY] = length_gain + record.new_forest_ids.size()
		records.append(record)
	for enclosure: Dictionary in data["enclosures"]:
		var record: FeatureCompletionRecord = _record(data)
		record.enclosure_id = enclosure["enclosure_id"]
		record.source_id = enclosure["source_id"]
		record.total_size = 8
		record.enclosure_stage = StringName(enclosure["stage"])
		record.natural_neighbor_count = enclosure["natural_count"]
		record.settlement_neighbor_count = enclosure.get("settlement_count", 0)
		record.gains[DomainTypes.TrackType.CULTURE] = (8 if record.enclosure_stage == &"abbey" else 5) + record.natural_neighbor_count
		if record.enclosure_stage == &"abbey":
			record.gains[DomainTypes.TrackType.CULTURE] += record.settlement_neighbor_count
		records.append(record)
	return records


static func resolve(state: RunState, current: Array[CurrentFeature], source_id: int = 0) -> CompletionSnapshot:
	var snapshot: CompletionSnapshot = capture(state, current, source_id)
	apply_snapshot(state, snapshot)
	return snapshot


static func apply_snapshot(state: RunState, snapshot: CompletionSnapshot, parent_event_id: int = 0) -> void:
	var records: Array[FeatureCompletionRecord] = calculate(snapshot)
	var effects: Array[Dictionary] = DevelopmentEffects.calculate(snapshot)
	if records.is_empty():
		return
	var source_id: int = snapshot.data()["source_id"]
	var snapshot_event: FeatureHistoryRecord = _event(state, &"completion_snapshot", source_id)
	snapshot_event.parent_event_id = parent_event_id
	state.features.history.append(snapshot_event)
	var pipeline: CompletionPipeline = CompletionPipeline.new()
	for record: FeatureCompletionRecord in records:
		record.record_id = state.id_allocator.allocate()
		record.snapshot_id = snapshot_event.event_id
		if record.lineage_id != 0:
			_apply_lineage(state, record)
		else:
			for enclosure: EnclosureState in state.features.enclosures:
				if enclosure.enclosure_id == record.enclosure_id:
					enclosure.completed_stages.append(record.enclosure_stage)
					enclosure.completion_ids.append(record.record_id)
		state.features.completions.append(record)
		var completed: FeatureHistoryRecord = FeatureHistoryRecord.new()
		completed.event_id = record.record_id
		completed.kind = &"feature_completed" if record.lineage_id != 0 else &"enclosure_completed"
		completed.lineage_id = record.lineage_id
		completed.feature_type = record.feature_type
		completed.act = record.act
		completed.placement_index = record.placement_index
		completed.source_id = record.source_id
		completed.parent_event_id = snapshot_event.event_id
		completed.component_ids = record.component_ids.duplicate()
		pipeline.enqueue_child(completed)
		for track: int in range(4):
			var amount: int = record.gains[track]
			if amount == 0:
				continue
			state.features.tracks.add(track as DomainTypes.TrackType, amount)
			var changed: FeatureHistoryRecord = _event(state, &"realm_track_changed", record.source_id)
			changed.lineage_id = record.lineage_id
			changed.feature_type = record.feature_type
			changed.parent_event_id = record.record_id
			changed.track = track
			changed.amount = amount
			pipeline.enqueue_child(changed)
	DevelopmentEffects.apply(state, effects, snapshot_event.event_id, pipeline)
	# Specialist/Relic/threshold stages remain deferred, after the Development batch.
	pipeline.drain_children(state)


static func _apply_lineage(state: RunState, record: FeatureCompletionRecord) -> void:
	var lineage: FeatureLineageState = state.features.lineage(record.lineage_id)
	lineage.completed = true
	lineage.completion_ids.append(record.record_id)
	_union(lineage.scored_component_ids, record.new_component_ids)
	_union(lineage.scored_field_ids, record.new_field_ids)
	_union(lineage.scored_river_ids, record.new_river_ids)
	_union(lineage.scored_forest_ids, record.new_forest_ids)
	_union(lineage.scored_settlement_ids, record.new_settlement_ids)
	lineage.highest_settlement_class = maxi(lineage.highest_settlement_class, record.settlement_class)
	state.features.largest_completed_sizes[record.feature_type] = maxi(state.features.largest_completed_sizes[record.feature_type], record.total_size)


static func _record(data: Dictionary) -> FeatureCompletionRecord:
	var record: FeatureCompletionRecord = FeatureCompletionRecord.new()
	record.act = data["act"]
	record.placement_index = data["placement_index"]
	record.source_id = data["source_id"]
	return record


static func _event(state: RunState, kind: StringName, source_id: int) -> FeatureHistoryRecord:
	var event: FeatureHistoryRecord = FeatureHistoryRecord.new()
	event.event_id = state.id_allocator.allocate()
	event.kind = kind
	event.act = state.expansion.current_act
	event.placement_index = state.expansion.normal_placements
	event.source_id = source_id
	return event


static func _unpaid_settlements(state: RunState, road: FeatureLineageState, settlement_ids: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for settlement_id: int in settlement_ids:
		var historical_ids: Array[int] = LineageService.get_ancestry_closure(state, settlement_id)
		historical_ids.append(settlement_id)
		var paid: bool = false
		for historical_id: int in historical_ids:
			if road.scored_settlement_ids.has(historical_id):
				paid = true
				break
		if not paid:
			result.append(settlement_id)
	result.sort()
	return result


static func _difference(current: Array[int], historical: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for value: int in current:
		if not historical.has(value):
			result.append(value)
	result.sort()
	return result


static func _union(target: Array[int], added: Array[int]) -> void:
	for value: int in added:
		if not target.has(value):
			target.append(value)
	target.sort()
