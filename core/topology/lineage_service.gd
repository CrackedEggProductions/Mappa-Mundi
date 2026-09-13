class_name LineageService
extends RefCounted
## Historical identity follows current topology, never the reverse.


static func validate_rebuild(state: RunState, current: Array[CurrentFeature]) -> ValidationResult:
	var occupied_lineages: Dictionary[int, bool] = {}
	for feature: CurrentFeature in current:
		for lineage_id: int in _lineage_ids(state, feature):
			var lineage: FeatureLineageState = state.features.lineage(lineage_id)
			if lineage == null or not lineage.active or lineage.feature_type != feature.feature_type:
				return ValidationResult.failure(&"invalid_current_lineage", "Feature has an invalid current lineage.")
			if occupied_lineages.has(lineage_id):
				return ValidationResult.failure(&"unsupported_feature_split", "One lineage cannot occupy disconnected features.")
			occupied_lineages[lineage_id] = true
			if lineage.feature_type == DomainTypes.FeatureType.RIVER and lineage.completed and feature.open_exits > 0:
				return ValidationResult.failure(&"completed_river_reopening", "Completed Rivers cannot normally reopen.")
	return ValidationResult.success()


static func reconcile(state: RunState, current: Array[CurrentFeature], source_id: int = 0) -> void:
	assert(validate_rebuild(state, current).is_valid, "Validate topology before lineage mutation")
	for feature: CurrentFeature in current:
		var previous_ids: Array[int] = _lineage_ids(state, feature)
		var lineage: FeatureLineageState
		if previous_ids.size() != 1:
			lineage = FeatureLineageState.new()
			lineage.lineage_id = state.id_allocator.allocate()
			lineage.feature_type = feature.feature_type
			lineage.parent_ids = previous_ids.duplicate()
			state.features.lineages.append(lineage)
			for parent_id: int in previous_ids:
				var parent: FeatureLineageState = state.features.lineage(parent_id)
				_inherit_history(lineage, parent)
				parent.active = false
			_record(state, &"feature_created" if previous_ids.is_empty() else &"feature_merged", lineage, feature.component_ids, source_id)
		else:
			lineage = state.features.lineage(previous_ids[0])
			var additions: Array[int] = []
			for component_id: int in feature.component_ids:
				if not lineage.member_ids.has(component_id):
					additions.append(component_id)
			if lineage.completed and feature.open_exits > 0:
				lineage.completed = false
				lineage.growth_phase += 1
				_record(state, &"feature_reopened", lineage, feature.component_ids, source_id)
			if not additions.is_empty():
				_record(state, &"feature_grew", lineage, additions, source_id)
		lineage.member_ids = feature.component_ids.duplicate()
		feature.lineage_id = lineage.lineage_id
		for component_id: int in feature.component_ids:
			state.features.component(component_id).lineage_id = lineage.lineage_id
	state.features.topology_revision = state.expansion.board.revision


static func is_ancestor(state: RunState, candidate_id: int, lineage_id: int) -> bool:
	return get_ancestry_closure(state, lineage_id).has(candidate_id)


static func get_ancestry_closure(state: RunState, lineage_id: int) -> Array[int]:
	var result: Array[int] = []
	var lineage: FeatureLineageState = state.features.lineage(lineage_id)
	if lineage == null:
		return result
	var pending: Array[int] = lineage.parent_ids.duplicate()
	while not pending.is_empty():
		var parent_id: int = pending.pop_back()
		if result.has(parent_id):
			continue
		result.append(parent_id)
		var parent: FeatureLineageState = state.features.lineage(parent_id)
		if parent != null:
			pending.append_array(parent.parent_ids)
	result.sort()
	return result


static func _lineage_ids(state: RunState, feature: CurrentFeature) -> Array[int]:
	var result: Array[int] = []
	for component_id: int in feature.component_ids:
		var lineage_id: int = state.features.component(component_id).lineage_id
		if lineage_id != 0 and not result.has(lineage_id):
			result.append(lineage_id)
	result.sort()
	return result


static func _inherit_history(descendant: FeatureLineageState, parent: FeatureLineageState) -> void:
	_union(descendant.scored_component_ids, parent.scored_component_ids)
	_union(descendant.scored_field_ids, parent.scored_field_ids)
	_union(descendant.scored_river_ids, parent.scored_river_ids)
	_union(descendant.scored_forest_ids, parent.scored_forest_ids)
	_union(descendant.scored_settlement_ids, parent.scored_settlement_ids)
	_union(descendant.completion_ids, parent.completion_ids)
	descendant.highest_settlement_class = maxi(descendant.highest_settlement_class, parent.highest_settlement_class)
	descendant.growth_phase = maxi(descendant.growth_phase, parent.growth_phase)


static func _union(target: Array[int], source: Array[int]) -> void:
	for value: int in source:
		if not target.has(value):
			target.append(value)
	target.sort()


static func _record(
	state: RunState, kind: StringName, lineage: FeatureLineageState,
	component_ids: Array[int], source_id: int
) -> void:
	var event: FeatureHistoryRecord = FeatureHistoryRecord.new()
	event.event_id = state.id_allocator.allocate()
	event.kind = kind
	event.lineage_id = lineage.lineage_id
	event.feature_type = lineage.feature_type
	event.act = state.expansion.current_act
	event.placement_index = state.expansion.normal_placements
	event.source_id = source_id
	event.component_ids = component_ids.duplicate()
	event.parent_ids = lineage.parent_ids.duplicate()
	state.features.history.append(event)
