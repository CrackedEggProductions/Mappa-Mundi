class_name FeatureScoringService
extends RefCounted
## Capture every genuine completion before applying any member of the batch.
## Historical eligibility is copied into the snapshot along with current contact.


static func capture(state: RunState, current: Array[CurrentFeature], source_id: int = 0) -> CompletionSnapshot:
	var features: Array[Dictionary] = []
	var ordered: Array[CurrentFeature] = current.duplicate()
	ordered.sort_custom(func(a: CurrentFeature, b: CurrentFeature) -> bool: return a.lineage_id < b.lineage_id)
	for feature: CurrentFeature in ordered:
		var lineage: FeatureLineageState = state.features.lineage(feature.lineage_id)
		if feature.open_exits != 0 or lineage.completed:
			continue
		var field_ids: Array[int] = []
		var river_ids: Array[int] = []
		var forest_ids: Array[int] = []
		if feature.feature_type == DomainTypes.FeatureType.SETTLEMENT:
			field_ids = FeatureContactService.support_ids(state, feature, DomainTypes.EdgeType.FIELD)
			river_ids = FeatureContactService.support_ids(state, feature, DomainTypes.EdgeType.RIVER)
		elif feature.feature_type == DomainTypes.FeatureType.RIVER:
			forest_ids = FeatureContactService.support_ids(state, feature, DomainTypes.EdgeType.FOREST)
		features.append({
			"lineage_id": lineage.lineage_id, "feature_type": feature.feature_type,
			"component_ids": feature.component_ids.duplicate(), "total_size": feature.component_ids.size(),
			"first_completion": lineage.completion_ids.is_empty(), "growth_phase": lineage.growth_phase,
			"new_component_ids": _difference(feature.component_ids, lineage.scored_component_ids),
			"field_support_ids": field_ids, "river_support_ids": river_ids, "forest_contact_ids": forest_ids,
			"new_field_ids": _difference(field_ids, lineage.scored_field_ids),
			"new_river_ids": _difference(river_ids, lineage.scored_river_ids),
			"new_forest_ids": _difference(forest_ids, lineage.scored_forest_ids),
			"undeveloped": FeatureContactService.forest_is_undeveloped(state, feature),
		})
	return CompletionSnapshot.new({
		"act": state.expansion.current_act, "placement_index": state.expansion.normal_placements,
		"source_id": source_id, "board_revision": state.expansion.board.revision,
		"topology_revision": state.features.topology_revision,
		"tracks": state.features.tracks.values.duplicate(), "features": features,
		"enclosures": EnclosureService.capture(state),
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
		for key: String in ["component_ids", "new_component_ids", "field_support_ids", "river_support_ids", "forest_contact_ids", "new_field_ids", "new_river_ids", "new_forest_ids"]:
			var values: Array[int] = []
			values.assign(facts[key])
			record.set(key, values)
		match record.feature_type:
			DomainTypes.FeatureType.SETTLEMENT:
				record.gains[DomainTypes.TrackType.POPULATION] = 2 * record.new_component_ids.size() + record.new_field_ids.size() + record.new_river_ids.size()
				# Without Developments larger Settlements retain Village classification.
				record.settlement_class = 1 if record.total_size <= 2 else 2
			DomainTypes.FeatureType.ROAD:
				# Network +2 per Settlement belongs strictly to Phase 4.
				record.gains[DomainTypes.TrackType.TRADE] = record.new_component_ids.size()
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
		record.gains[DomainTypes.TrackType.CULTURE] = 5 + int(enclosure["natural_count"])
		records.append(record)
	return records


static func resolve(state: RunState, current: Array[CurrentFeature], source_id: int = 0) -> CompletionSnapshot:
	var snapshot: CompletionSnapshot = capture(state, current, source_id)
	var records: Array[FeatureCompletionRecord] = calculate(snapshot)
	if records.is_empty():
		return snapshot
	var snapshot_event: FeatureHistoryRecord = _event(state, &"completion_snapshot", source_id)
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
					enclosure.completed_stages.append(enclosure.stage)
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
			var changed: FeatureHistoryRecord = _event(state, &"realm_track_changed", source_id)
			changed.lineage_id = record.lineage_id
			changed.feature_type = record.feature_type
			changed.parent_event_id = record.record_id
			changed.track = track
			changed.amount = amount
			pipeline.enqueue_child(changed)
	# Future category stages run here from the same snapshot, before child draining.
	pipeline.drain_children(state)
	return snapshot


static func _apply_lineage(state: RunState, record: FeatureCompletionRecord) -> void:
	var lineage: FeatureLineageState = state.features.lineage(record.lineage_id)
	lineage.completed = true
	lineage.completion_ids.append(record.record_id)
	_union(lineage.scored_component_ids, record.new_component_ids)
	_union(lineage.scored_field_ids, record.new_field_ids)
	_union(lineage.scored_river_ids, record.new_river_ids)
	_union(lineage.scored_forest_ids, record.new_forest_ids)
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
