class_name SpecialistRules
extends RefCounted
## Readable domain rules. Commands own mutations; UI never decides eligibility.

const ENCLOSURE: int = 4
const HARD_CAP: int = 3
const ROLE_TYPES: Dictionary = {
	&"specialist.merchant": 0, &"specialist.cartographer": 0,
	&"specialist.architect": 1, &"specialist.homesteader": 1,
	&"specialist.naturalist": 2, &"specialist.forester": 2,
	&"specialist.riverkeeper": 3, &"specialist.harbormaster": 3,
}


static func initialize(state: RunState) -> void:
	assert(state.specialists == null, "Specialist initialization is run setup, never load reconstruction")
	state.specialists = SpecialistState.new()
	for index: int in range(2):
		var piece: SpecialistPieceState = SpecialistPieceState.new()
		piece.piece_id = state.id_allocator.allocate()
		state.specialists.pieces.append(piece)


static func all_component_ids(state: RunState) -> Array[int]:
	var result: Array[int] = []
	for component: FeatureComponentState in state.features.components:
		result.append(component.component_id)
	result.sort()
	return result


static func find_feature(current: Array[CurrentFeature], id: int) -> CurrentFeature:
	for feature: CurrentFeature in current:
		if feature.lineage_id == id:
			return feature
	return null


static func find_enclosure(state: RunState, id: int) -> EnclosureState:
	for enclosure: EnclosureState in state.features.enclosures:
		if enclosure.enclosure_id == id:
			return enclosure
	return null


static func target_unfinished(state: RunState, type: int, id: int,
		current: Array[CurrentFeature]) -> bool:
	if type != ENCLOSURE:
		var feature: CurrentFeature = find_feature(current, id)
		return feature != null and feature.feature_type == type and feature.open_exits > 0
	var enclosure: EnclosureState = find_enclosure(state, id)
	if enclosure == null or enclosure.stage not in [&"monastery", &"abbey"] or enclosure.completed_stages.has(enclosure.stage):
		return false
	for complete: Dictionary in EnclosureService.capture(state):
		if int(complete["enclosure_id"]) == id:
			return false
	return true


static func touching_settlements(state: RunState, river: CurrentFeature,
		current: Array[CurrentFeature]) -> Array[int]:
	var result: Array[int] = []
	var touching_tiles: Array[int] = FeatureContactService.support_ids(state, river, DomainTypes.EdgeType.SETTLEMENT)
	for settlement: CurrentFeature in current:
		if settlement.feature_type != DomainTypes.FeatureType.SETTLEMENT:
			continue
		for coordinate: Vector2i in settlement.coordinates:
			if touching_tiles.has(state.expansion.board.get_cell(coordinate).base_tile_copy_id):
				result.append(settlement.lineage_id)
				break
	result.sort()
	return result


static func role_eligible(state: RunState, role: StringName, type: int, id: int,
		current: Array[CurrentFeature]) -> bool:
	if role == &"":
		return type >= 0 and type <= ENCLOSURE
	if not ROLE_TYPES.has(role) or int(ROLE_TYPES[role]) != type:
		return false
	if role == &"specialist.harbormaster":
		var river: CurrentFeature = find_feature(current, id)
		return river != null and not touching_settlements(state, river, current).is_empty()
	return true


static func occupied(state: RunState, type: int, id: int) -> bool:
	for piece: SpecialistPieceState in state.specialists.pieces:
		if piece.status == SpecialistPieceState.Status.ASSIGNED and piece.assigned_target_type == type and piece.assigned_target_id == id:
			return true
	return false


static func assignment_options(state: RunState, affected_targets: Array[Dictionary]) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if state.specialists == null:
		return options
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	for target: Dictionary in affected_targets:
		var type: int = target["target_type"]
		var id: int = target["target_id"]
		if not target_unfinished(state, type, id, current) or occupied(state, type, id):
			continue
		for piece: SpecialistPieceState in state.specialists.pieces:
			if piece.status != SpecialistPieceState.Status.AVAILABLE or not role_eligible(state, piece.role_definition_id, type, id, current):
				continue
			var option: Dictionary = {"piece_id": piece.piece_id, "target_type": type, "target_id": id}
			if not options.has(option):
				options.append(option)
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["target_type"] != b["target_type"]:
			return a["target_type"] < b["target_type"]
		if a["target_id"] != b["target_id"]:
			return a["target_id"] < b["target_id"]
		return a["piece_id"] < b["piece_id"])
	return options


static func begin_assignment(state: RunState, targets: Array[Dictionary]) -> bool:
	var options: Array[Dictionary] = assignment_options(state, targets)
	if options.is_empty():
		return false
	assert(state.pending_choice == null)
	var choice: PendingChoice = PendingChoice.new()
	choice.choice_id = state.id_allocator.allocate()
	choice.kind = &"specialist_assignment"
	choice.options = options
	choice.context = {"affected_targets": targets.duplicate(true), "decline_allowed": true}
	state.pending_choice = choice
	state.phase = GamePhase.Type.PENDING_CHOICE
	return true


static func remap_and_growth(state: RunState, current: Array[CurrentFeature]) -> void:
	if state.specialists == null:
		return
	var observed: Array[int] = all_component_ids(state)
	for piece: SpecialistPieceState in state.specialists.pieces:
		if piece.status != SpecialistPieceState.Status.ASSIGNED or piece.assigned_target_type == ENCLOSURE:
			continue
		piece.assigned_target_id = DevelopmentService._descendant(state, current, piece.assigned_target_id)
		var feature: CurrentFeature = find_feature(current, piece.assigned_target_id)
		if feature == null:
			continue # Invariants report disappearance; never invent a replacement target.
		for component_id: int in feature.component_ids:
			if not piece.growth_baseline_component_ids.has(component_id) and not piece.qualifying_component_ids.has(component_id):
				piece.qualifying_component_ids.append(component_id)
		piece.qualifying_component_ids.sort()
		# Observe foreign growth too: a later merger must not credit these old tiles.
		piece.growth_baseline_component_ids = observed.duplicate()


static func training_pool(state: RunState, piece: SpecialistPieceState) -> Array[StringName]:
	var roles: Array[StringName] = []
	if piece == null or piece.role_definition_id != &"":
		return roles
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	for role: StringName in ROLE_TYPES:
		if piece.status == SpecialistPieceState.Status.AVAILABLE or role_eligible(state, role, piece.assigned_target_type, piece.assigned_target_id, current):
			roles.append(role)
	roles.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return roles


static func trainable_piece_ids(state: RunState) -> Array[int]:
	var result: Array[int] = []
	for piece: SpecialistPieceState in state.specialists.pieces:
		if not training_pool(state, piece).is_empty():
			result.append(piece.piece_id)
	result.sort()
	return result


static func capture(state: RunState, current: Array[CurrentFeature], trigger_ids: Array[int],
		enclosure_facts: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.specialists == null:
		return result
	var networks: Array[CurrentTradeNetwork] = []
	if state.trade != null:
		networks = TradeNetworkService.rebuild(state)
	for piece: SpecialistPieceState in state.specialists.pieces:
		if piece.status != SpecialistPieceState.Status.ASSIGNED:
			continue
		var facts: Dictionary = {"piece_id": piece.piece_id, "role_definition_id": String(piece.role_definition_id),
			"target_type": piece.assigned_target_type, "target_id": piece.assigned_target_id,
			"growth_count": 0, "size": 0, "network_settlement_count": 0, "families": [],
			"field_count": 0, "forest_count": 0, "undeveloped": false,
			"touching_settlements": [], "port_settlements": []}
		if piece.assigned_target_type == ENCLOSURE:
			var completes: bool = false
			for enclosure: Dictionary in enclosure_facts:
				if int(enclosure["enclosure_id"]) == piece.assigned_target_id:
					completes = true
			if completes:
				result.append(facts)
			continue
		if not trigger_ids.has(piece.assigned_target_id):
			continue
		var feature: CurrentFeature = find_feature(current, piece.assigned_target_id)
		if feature == null:
			continue
		facts["size"] = feature.coordinates.size()
		for component_id: int in piece.qualifying_component_ids:
			if feature.component_ids.has(component_id):
				facts["growth_count"] += 1
		match feature.feature_type:
			DomainTypes.FeatureType.ROAD:
				for network: CurrentTradeNetwork in networks:
					if network.road_lineage_ids.has(feature.lineage_id):
						facts["network_settlement_count"] = network.settlement_lineage_ids.size()
						break
			DomainTypes.FeatureType.SETTLEMENT:
				var families: Array[String] = []
				for family: StringName in DevelopmentService.families(state, feature.lineage_id):
					families.append(String(family))
				facts["families"] = families
				facts["field_count"] = FeatureContactService.support_ids(state, feature, DomainTypes.EdgeType.FIELD).size()
			DomainTypes.FeatureType.FOREST:
				facts["undeveloped"] = FeatureContactService.forest_is_undeveloped(state, feature)
			DomainTypes.FeatureType.RIVER:
				facts["forest_count"] = FeatureContactService.support_ids(state, feature, DomainTypes.EdgeType.FOREST).size()
				var settlements: Array[int] = touching_settlements(state, feature, current)
				var ports: Array[int] = []
				for development: DevelopmentState in DevelopmentService.all(state):
					if development.stage == &"port" and settlements.has(development.host_lineage_id) and not ports.has(development.host_lineage_id):
						ports.append(development.host_lineage_id)
				ports.sort()
				facts["touching_settlements"] = settlements
				facts["port_settlements"] = ports
		result.append(facts)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["piece_id"] < b["piece_id"])
	return result


static func calculate(snapshot: CompletionSnapshot) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for facts: Dictionary in snapshot.data().get("specialists", []):
		var gains: Array[int] = [0, 0, 0, 0]
		match StringName(facts["role_definition_id"]):
			&"":
				const TRACKS: Array[int] = [1, 0, 3, 3, 2]
				gains[TRACKS[int(facts["target_type"])]] = 2
			&"specialist.merchant":
				gains[1] = maxi(0, int(facts["network_settlement_count"]) - 1) * 2
			&"specialist.cartographer":
				gains[1] = facts["growth_count"]
			&"specialist.architect":
				gains[2] = 2 * facts["families"].size()
			&"specialist.homesteader":
				gains[0] = facts["field_count"]
			&"specialist.naturalist":
				gains[3] = facts["size"] if facts["undeveloped"] else 0
			&"specialist.forester":
				gains[3] = facts["growth_count"]
			&"specialist.riverkeeper":
				gains[3] = facts["forest_count"]
			&"specialist.harbormaster":
				gains[1] = 2 * facts["touching_settlements"].size() + facts["port_settlements"].size()
			_:
				assert(false, "Snapshot contains a non-alpha Specialist role")
		var effect: Dictionary = facts.duplicate(true)
		effect["gains"] = gains
		result.append(effect)
	return result


static func history_event(state: RunState, kind: StringName, piece_id: int,
		details: Dictionary = {}, parent_event_id: int = 0,
		pipeline: CompletionPipeline = null) -> FeatureHistoryRecord:
	var event: FeatureHistoryRecord = FeatureScoringService._event(state, kind, piece_id)
	event.parent_event_id = parent_event_id
	event.lineage_id = int(details.get("target_id", 0)) if int(details.get("target_type", -1)) != ENCLOSURE else 0
	event.feature_type = int(details.get("target_type", -1)) if int(details.get("target_type", -1)) != ENCLOSURE else -1
	if pipeline == null:
		state.features.history.append(event)
	else:
		pipeline.enqueue_child(event)
	var record: Dictionary = details.duplicate(true)
	record["event_id"] = event.event_id
	record["kind"] = String(kind)
	record["piece_id"] = piece_id
	record["act"] = state.expansion.current_act
	record["placement_index"] = state.expansion.normal_placements
	state.specialists.history.append(record)
	return event


static func apply(state: RunState, effects: Array[Dictionary], parent_event_id: int,
		pipeline: CompletionPipeline) -> void:
	for effect: Dictionary in effects:
		var event: FeatureHistoryRecord = history_event(state, &"specialist_triggered", effect["piece_id"], effect, parent_event_id, pipeline)
		for track: int in range(4):
			var amount: int = effect["gains"][track]
			if amount == 0:
				continue
			state.features.tracks.add(track as DomainTypes.TrackType, amount)
			var changed: FeatureHistoryRecord = FeatureScoringService._event(state, &"realm_track_changed", effect["piece_id"])
			changed.parent_event_id = event.event_id
			changed.lineage_id = event.lineage_id
			changed.feature_type = event.feature_type
			changed.track = track
			changed.amount = amount
			pipeline.enqueue_child(changed)


static func return_pieces(state: RunState, effects: Array[Dictionary], parent_event_id: int,
		pipeline: CompletionPipeline) -> void:
	for effect: Dictionary in effects:
		var piece: SpecialistPieceState = state.specialists.piece(effect["piece_id"])
		history_event(state, &"specialist_returned", piece.piece_id, effect, parent_event_id, pipeline)
		piece.status = SpecialistPieceState.Status.AVAILABLE
		piece.assigned_target_type = -1
		piece.assigned_target_id = 0
		piece.assigned_act = 0
		piece.assigned_placement_index = 0
		piece.growth_baseline_component_ids.clear()
		piece.qualifying_component_ids.clear()
