class_name DevelopmentEffects
extends RefCounted
## Frozen primitive trigger facts are captured before any base or Development gain.


static func capture(state: RunState, current: Array[CurrentFeature], trigger_ids: Array[int], only_copy_id: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var developments: Array[DevelopmentState] = DevelopmentService.all(state)
	var networks: Array[CurrentTradeNetwork] = []
	if state.trade != null:
		networks = TradeNetworkService.rebuild(state)
	for development: DevelopmentState in developments:
		if only_copy_id != 0 and development.tile_copy_id != only_copy_id:
			continue
		var coordinate: Vector2i = DevelopmentService.coordinate_for(state, development.tile_copy_id)
		for feature: CurrentFeature in current:
			if not trigger_ids.has(feature.lineage_id):
				continue
			var applies: bool = development.host_lineage_id == feature.lineage_id and development.host_kind in [&"settlement", &"forest"]
			if development.stage == &"mill":
				applies = feature.feature_type == DomainTypes.FeatureType.SETTLEMENT and DevelopmentService.coordinate_touches_feature(state, coordinate, feature)
			if not applies:
				continue
			var other_settlements: int = 0
			for network: CurrentTradeNetwork in networks:
				if network.settlement_lineage_ids.has(feature.lineage_id):
					other_settlements = network.settlement_lineage_ids.size() - 1
					break
			var other_ports: int = 0
			if development.stage == &"port":
				for peer: DevelopmentState in developments:
					if peer.stage == &"port" and peer.tile_copy_id != development.tile_copy_id and peer.river_lineage_id == development.river_lineage_id:
						other_ports += 1
			var touches_river: bool = false
			if development.stage == &"mill":
				for river: CurrentFeature in current:
					if river.feature_type == DomainTypes.FeatureType.RIVER and DevelopmentService.coordinate_touches_feature(state, coordinate, river):
						touches_river = true
			result.append({"copy_id": development.tile_copy_id, "stage": String(development.stage),
				"lineage_id": feature.lineage_id, "feature_type": feature.feature_type,
				"other_settlements": other_settlements, "other_ports": other_ports,
				"touches_river": touches_river, "families": DevelopmentService.families(state, feature.lineage_id)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["copy_id"] < b["copy_id"] if a["copy_id"] != b["copy_id"] else a["lineage_id"] < b["lineage_id"])
	return result


static func calculate(snapshot: CompletionSnapshot) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for facts: Dictionary in snapshot.data().get("developments", []):
		var gains: Array[int] = [0, 0, 0, 0]
		match StringName(facts["stage"]):
			&"housing":
				gains[DomainTypes.TrackType.POPULATION] = 2
			&"mill":
				gains[DomainTypes.TrackType.POPULATION] = 2
				gains[DomainTypes.TrackType.TRADE] = 1 if facts["touches_river"] else 0
			&"market", &"grand_market":
				gains[DomainTypes.TrackType.TRADE] = int(facts["other_settlements"]) * (2 if facts["stage"] == "grand_market" else 1)
			&"port":
				gains[DomainTypes.TrackType.TRADE] = 2 + int(facts["other_ports"])
			&"foresters_lodge":
				gains[DomainTypes.TrackType.ECOLOGY] = 1
			&"town_square":
				gains[DomainTypes.TrackType.CULTURE] = 2 * facts["families"].size()
			_:
				continue
		var effect: Dictionary = facts.duplicate(true)
		effect["gains"] = gains
		result.append(effect)
	return result


static func apply(state: RunState, effects: Array[Dictionary], parent_event_id: int, pipeline: CompletionPipeline, immediate_effect: bool = false) -> void:
	for effect: Dictionary in effects:
		var event: FeatureHistoryRecord = FeatureScoringService._event(state, &"development_immediate_effect" if immediate_effect else &"development_completion_trigger", effect["copy_id"])
		event.parent_event_id = parent_event_id
		event.lineage_id = effect["lineage_id"]
		event.feature_type = effect["feature_type"]
		pipeline.enqueue_child(event)
		for track: int in range(4):
			var amount: int = effect["gains"][track]
			if amount == 0:
				continue
			state.features.tracks.add(track as DomainTypes.TrackType, amount)
			var changed: FeatureHistoryRecord = FeatureScoringService._event(state, &"realm_track_changed", effect["copy_id"])
			changed.parent_event_id = event.event_id
			changed.lineage_id = event.lineage_id
			changed.feature_type = event.feature_type
			changed.track = track
			changed.amount = amount
			pipeline.enqueue_child(changed)


static func immediate(state: RunState, new_copy_id: int, parent_event_id: int, include_enclosures: bool = true) -> void:
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	var complete_ids: Array[int] = []
	for feature: CurrentFeature in current:
		if feature.open_exits == 0:
			complete_ids.append(feature.lineage_id)
	var facts: Array[Dictionary] = capture(state, current, complete_ids, new_copy_id)
	var pipeline: CompletionPipeline = CompletionPipeline.new()
	apply(state, calculate(CompletionSnapshot.new({"developments": facts})), parent_event_id, pipeline, true)
	pipeline.drain_children(state)
	if not include_enclosures:
		return
	var enclosures: Array[Dictionary] = []
	for enclosure: Dictionary in EnclosureService.capture(state):
		if enclosure["source_id"] == new_copy_id:
			enclosures.append(enclosure)
	if not enclosures.is_empty():
		var snapshot: CompletionSnapshot = CompletionSnapshot.new({
			"act": state.expansion.current_act, "placement_index": state.expansion.normal_placements,
			"source_id": new_copy_id, "features": [], "enclosures": enclosures, "developments": []})
		FeatureScoringService.apply_snapshot(state, snapshot, parent_event_id)
