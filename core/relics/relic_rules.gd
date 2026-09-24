class_name RelicRules
extends RefCounted
## One authority for Relic lifetime, legality and frozen completion modifiers.
## Reward commands own choices; this service never generates offers or consumes RNG.

const BOUNDARY: StringName = &"relic.boundary_stones"
const COMPASS: StringName = &"relic.surveyors_compass"
const SATCHEL: StringName = &"relic.wayfarers_satchel"
const GREEN: StringName = &"relic.village_green"
const FERRY: StringName = &"relic.ferry_rights"
const MIXED: StringName = &"relic.mixed_use_charter"
const HISTORIC: StringName = &"relic.historic_routes"
const RELAY: StringName = &"relic.stewards_relay"
const CITY: StringName = &"relic.one_great_city"
const LONG_ROAD: StringName = &"relic.the_long_road"


static func equipped(state: RunState) -> Array[RelicInstanceState]:
	var result: Array[RelicInstanceState] = []
	if state.relics == null:
		return result
	for instance: RelicInstanceState in state.relics.instances:
		if instance.equipped_slot >= 0:
			result.append(instance)
	result.sort_custom(func(a: RelicInstanceState, b: RelicInstanceState) -> bool:
		return a.acquisition_order < b.acquisition_order)
	return result


static func find(state: RunState, id: StringName) -> RelicInstanceState:
	if state.relics != null:
		for instance: RelicInstanceState in state.relics.instances:
			if instance.definition_id == id:
				return instance
	return null


static func active(state: RunState, id: StringName) -> bool:
	var instance: RelicInstanceState = find(state, id)
	return instance != null and instance.equipped_slot >= 0


static func capacity_for_act(act: int) -> int:
	return 2 if act <= 1 else (4 if act == 2 else 5)


static func refresh_act(state: RunState, act: int) -> ValidationResult:
	if state.relics == null or act < 1 or act > 3 or act < state.relics.current_act:
		return ValidationResult.failure(&"invalid_relic_act", "Relic refresh requires a current or later alpha Act.")
	# Repeating an Act-start hook must not recharge an already spent use.
	if act == state.relics.current_act:
		state.relics.capacity = capacity_for_act(act)
		return ValidationResult.success()
	state.relics.current_act = act
	state.relics.capacity = capacity_for_act(act)
	state.relics.normal_surveys_used = 0
	for instance: RelicInstanceState in equipped(state):
		instance.use_act = act
		instance.uses_remaining = 1 if instance.once_per_act else 0
	record(state, &"relic_act_refreshed", {"act": act, "capacity": state.relics.capacity})
	return ValidationResult.success()


static func use_available(state: RunState, id: StringName) -> bool:
	var instance: RelicInstanceState = find(state, id)
	return instance != null and instance.equipped_slot >= 0 and instance.use_act == state.relics.current_act and instance.uses_remaining > 0


static func consume_use(state: RunState, id: StringName) -> ValidationResult:
	if not use_available(state, id):
		return ValidationResult.failure(&"relic_use_unavailable", "This Relic has no available use in this Act.")
	var instance: RelicInstanceState = find(state, id)
	instance.uses_remaining -= 1
	record(state, &"relic_use_consumed", {"definition_id": String(id)}, instance.runtime_id)
	return ValidationResult.success()


static func eligible_ids(state: RunState, registry: ContentRegistry, eligibility_act: int = 0) -> Array[StringName]:
	var result: Array[StringName] = []
	if state.relics == null:
		return result
	var act: int = state.expansion.current_act if eligibility_act == 0 else eligibility_act
	for id: StringName in registry.get_relic_ids():
		var definition: RelicDefinition = registry.get_relic(id)
		if definition.unlock_act <= act and find(state, id) == null:
			result.append(id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result


static func removal_validation(state: RunState, _registry: ContentRegistry, id: StringName) -> ValidationResult:
	if not active(state, id):
		return ValidationResult.failure(&"relic_not_equipped", "Only an equipped Relic can be replaced.")
	if id == SATCHEL and state.expansion.reserve_extra_id != 0:
		return ValidationResult.failure(&"occupied_satchel", "The second Reserve slot must be empty before removing Satchel.")
	if id == MIXED:
		for coordinate: Vector2i in state.expansion.board.sorted_coordinates():
			var families: Array[StringName] = []
			for development: DevelopmentState in state.expansion.board.get_cell(coordinate).developments:
				families.append(development.family_id)
			if &"family.housing" in families and &"family.market" in families:
				return ValidationResult.failure(&"occupied_mixed_use", "Existing Housing and Market coexistence requires Mixed-Use Charter.")
	return ValidationResult.success()


static func acquisition_validation(state: RunState, registry: ContentRegistry, id: StringName,
		replace_id: StringName = &"") -> ValidationResult:
	if state.relics == null or id not in eligible_ids(state, registry):
		return ValidationResult.failure(&"relic_not_eligible", "This Relic is locked, unknown, or already acquired.")
	if equipped(state).size() < state.relics.capacity:
		if replace_id != &"":
			return ValidationResult.failure(&"unnecessary_relic_replacement", "Use the available Relic slot.")
		return ValidationResult.success()
	if replace_id == &"":
		return ValidationResult.failure(&"relic_capacity_full", "Choose a legally removable Relic or decline.")
	return removal_validation(state, registry, replace_id)


static func acquire(state: RunState, registry: ContentRegistry, id: StringName,
		replace_id: StringName = &"") -> ValidationResult:
	var validation: ValidationResult = acquisition_validation(state, registry, id, replace_id)
	if not validation.is_valid:
		return validation
	var slot: int = -1
	if replace_id != &"":
		var old: RelicInstanceState = find(state, replace_id)
		slot = old.equipped_slot
		old.equipped_slot = -1
		old.removed_act = state.expansion.current_act
		record(state, &"relic_replaced", {"definition_id": String(replace_id), "replacement_id": String(id), "slot": slot}, old.runtime_id)
	else:
		var occupied: Array[int] = []
		for old: RelicInstanceState in equipped(state):
			occupied.append(old.equipped_slot)
		for index: int in range(state.relics.capacity):
			if index not in occupied:
				slot = index
				break
	var instance: RelicInstanceState = RelicInstanceState.new()
	instance.runtime_id = state.id_allocator.allocate()
	instance.definition_id = id
	instance.acquisition_order = state.relics.instances.size() + 1
	instance.acquired_act = state.expansion.current_act
	instance.equipped_slot = slot
	instance.use_act = state.relics.current_act
	instance.once_per_act = registry.get_relic(id).once_per_act
	instance.uses_remaining = 1 if instance.once_per_act else 0
	state.relics.instances.append(instance)
	record(state, &"relic_acquired", {"definition_id": String(id), "slot": slot,
		"acquisition_order": instance.acquisition_order}, instance.runtime_id)
	if state.trade != null and (id == FERRY or replace_id == FERRY):
		TradeNetworkService.reconcile(state, instance.runtime_id)
	return ValidationResult.success()


static func record(state: RunState, kind: StringName, details: Dictionary = {}, source_id: int = 0) -> Dictionary:
	var event: Dictionary = {"event_id": state.id_allocator.allocate(), "kind": String(kind),
		"source_id": source_id, "act": state.expansion.current_act, "details": details.duplicate(true)}
	state.relics.history.append(event)
	return event


static func precedence(rules: Array[Dictionary]) -> Dictionary:
	# A candidate declares permission/prohibition, specificity, acquisition_order.
	# Stable rule IDs only break an otherwise semantically identical tie.
	if rules.is_empty():
		return {}
	var ordered: Array[Dictionary] = rules.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("prohibition", false)) != bool(b.get("prohibition", false)):
			return bool(a.get("prohibition", false))
		if int(a.get("specificity", 0)) != int(b.get("specificity", 0)):
			return int(a.get("specificity", 0)) > int(b.get("specificity", 0))
		if int(a.get("acquisition_order", 0)) != int(b.get("acquisition_order", 0)):
			return int(a.get("acquisition_order", 0)) > int(b.get("acquisition_order", 0))
		return String(a.get("rule_id", "")) < String(b.get("rule_id", "")))
	return ordered[0].duplicate(true)


static func capture(state: RunState, current: Array[CurrentFeature]) -> Dictionary:
	if state.relics == null:
		return {}
	var equipped_facts: Array[Dictionary] = []
	for instance: RelicInstanceState in equipped(state):
		equipped_facts.append({"runtime_id": instance.runtime_id,
			"definition_id": String(instance.definition_id), "acquisition_order": instance.acquisition_order})
	var largest: int = 0
	var feature_facts: Dictionary = {}
	for feature: CurrentFeature in current:
		var natural_contact: bool = false
		var act_one_road_count: int = 0
		if feature.feature_type == DomainTypes.FeatureType.SETTLEMENT:
			largest = maxi(largest, feature.coordinates.size())
			natural_contact = _natural_exterior(state, feature)
		elif feature.feature_type == DomainTypes.FeatureType.ROAD:
			for component_id: int in feature.component_ids:
				if state.features.component(component_id).origin_act == 1:
					act_one_road_count += 1
		feature_facts[String.num_int64(feature.lineage_id)] = {"natural_contact": natural_contact,
			"act_one_road_count": act_one_road_count}
	return {"equipped": equipped_facts, "largest_settlement_size": largest,
		"prior_longest_road": state.features.largest_completed_sizes[DomainTypes.FeatureType.ROAD],
		"feature_facts": feature_facts}


static func snapshot_active(snapshot: CompletionSnapshot, id: StringName) -> bool:
	for instance: Dictionary in snapshot.data().get("relics", {}).get("equipped", []):
		if StringName(instance["definition_id"]) == id:
			return true
	return false


static func base_multiplier(snapshot: CompletionSnapshot, facts: Dictionary) -> int:
	var captured: Dictionary = snapshot.data().get("relics", {})
	var type: int = facts["feature_type"]
	if type == DomainTypes.FeatureType.SETTLEMENT and snapshot_active(snapshot, CITY):
		return 2 if int(facts["total_size"]) >= int(captured["largest_settlement_size"]) else 0
	if type == DomainTypes.FeatureType.ROAD and snapshot_active(snapshot, LONG_ROAD):
		return 2 if int(facts["total_size"]) >= int(captured["prior_longest_road"]) else 0
	return 1


static func calculate(snapshot: CompletionSnapshot) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var data: Dictionary = snapshot.data()
	var captured: Dictionary = data.get("relics", {})
	for instance: Dictionary in captured.get("equipped", []):
		var id: StringName = StringName(instance["definition_id"])
		for feature: Dictionary in data.get("features", []):
			var facts: Dictionary = captured.get("feature_facts", {}).get(String.num_int64(int(feature["lineage_id"])), {})
			var gains: Array[int] = [0, 0, 0, 0]
			if id == GREEN and int(feature["feature_type"]) == DomainTypes.FeatureType.SETTLEMENT and bool(facts.get("natural_contact", false)):
				gains[DomainTypes.TrackType.CULTURE] = int(feature["total_size"])
			elif id == HISTORIC and int(data["act"]) >= 2 and int(feature["feature_type"]) == DomainTypes.FeatureType.ROAD:
				gains[DomainTypes.TrackType.CULTURE] = int(facts.get("act_one_road_count", 0))
			if gains == [0, 0, 0, 0]:
				continue
			result.append({"runtime_id": instance["runtime_id"], "definition_id": String(id),
				"acquisition_order": instance["acquisition_order"], "target_id": feature["lineage_id"],
				"target_type": feature["feature_type"], "gains": gains})
	# Numeric amounts were all calculated before mutation. Acquisition order is
	# deterministic bookkeeping, never sequential reevaluation of the snapshot.
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["acquisition_order"] != b["acquisition_order"]:
			return a["acquisition_order"] < b["acquisition_order"]
		return a["target_id"] < b["target_id"])
	return result


static func apply(state: RunState, effects: Array[Dictionary], parent_event_id: int,
		pipeline: CompletionPipeline) -> void:
	for effect: Dictionary in effects:
		var event: FeatureHistoryRecord = FeatureScoringService._event(state, &"relic_triggered", int(effect["runtime_id"]))
		event.parent_event_id = parent_event_id
		event.lineage_id = int(effect["target_id"])
		event.feature_type = int(effect["target_type"])
		pipeline.enqueue_child(event)
		var audit: Dictionary = effect.duplicate(true)
		audit["event_id"] = event.event_id
		audit["kind"] = "relic_triggered"
		audit["source_id"] = int(effect["runtime_id"])
		audit["act"] = state.expansion.current_act
		audit["details"] = effect.duplicate(true)
		state.relics.history.append(audit)
		for track: int in range(4):
			var amount: int = int(effect["gains"][track])
			if amount == 0:
				continue
			state.features.tracks.add(track as DomainTypes.TrackType, amount)
			var changed: FeatureHistoryRecord = FeatureScoringService._event(state, &"realm_track_changed", int(effect["runtime_id"]))
			changed.parent_event_id = event.event_id
			changed.lineage_id = event.lineage_id
			changed.feature_type = event.feature_type
			changed.track = track
			changed.amount = amount
			pipeline.enqueue_child(changed)


static func _natural_exterior(state: RunState, feature: CurrentFeature) -> bool:
	for coordinate: Vector2i in feature.coordinates:
		var cell: BoardCellState = state.expansion.board.get_cell(coordinate)
		for edge: int in [DomainTypes.EdgeType.FIELD, DomainTypes.EdgeType.FOREST, DomainTypes.EdgeType.RIVER]:
			if FeatureContactService._touches_internally(cell, DomainTypes.EdgeType.SETTLEMENT, edge):
				return true
		for offset: Vector2i in BoardState.ORTHOGONAL_OFFSETS:
			var neighbor_at: Vector2i = coordinate + offset
			if neighbor_at in feature.coordinates:
				continue
			var neighbor: BoardCellState = state.expansion.board.get_cell(neighbor_at)
			if neighbor != null and (neighbor.has_field_geography or neighbor.effective_edges.has(DomainTypes.EdgeType.FOREST)
					or neighbor.effective_edges.has(DomainTypes.EdgeType.RIVER)):
				return true
	return false
