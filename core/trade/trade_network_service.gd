class_name TradeNetworkService
extends RefCounted
## Deterministic economic connectivity and history reconciliation, without scoring or RNG.


static func initialize(state: RunState) -> void:
	assert(state.features != null and state.trade == null)
	state.trade = TradeState.new()
	reconcile(state)


static func access_links(state: RunState) -> Array[TradeLinkState]:
	var links: Array[TradeLinkState] = []
	if state.features == null or state.expansion == null:
		return links
	for coordinate: Vector2i in state.expansion.board.sorted_coordinates():
		var cell: BoardCellState = state.expansion.board.get_cell(coordinate)
		for relationship: TileFeatureRelationship in cell.relationships:
			if relationship.kind != TileFeatureRelationship.Kind.ROAD_SETTLEMENT_ACCESS:
				continue
			var road: FeatureComponentState = state.features.component_at(coordinate, DomainTypes.FeatureType.ROAD)
			var settlement: FeatureComponentState = state.features.component_at(coordinate, DomainTypes.FeatureType.SETTLEMENT)
			if road == null or settlement == null:
				continue
			var link: TradeLinkState = TradeLinkState.new()
			link.from_lineage_id = road.lineage_id
			link.to_lineage_id = settlement.lineage_id
			link.source_id = cell.base_tile_copy_id
			link.source_kind = &"board_access"
			link.explicit_access = true
			links.append(link)
	if state.trade != null:
		for contribution: TradeLinkState in state.trade.authorized_links:
			# A contribution is current authoritative state, not a callback into a Relic.
			if contribution == null:
				continue
			var link: TradeLinkState = TradeLinkState.new()
			link.from_lineage_id = contribution.from_lineage_id
			link.to_lineage_id = contribution.to_lineage_id
			link.source_id = contribution.source_id
			link.source_kind = contribution.source_kind
			links.append(link)
	links.sort_custom(func(a: TradeLinkState, b: TradeLinkState) -> bool: return a.signature() < b.signature())
	return links


static func rebuild(state: RunState) -> Array[CurrentTradeNetwork]:
	var result: Array[CurrentTradeNetwork] = []
	if state.features == null:
		return result
	var links: Array[TradeLinkState] = access_links(state)
	var adjacency: Dictionary[int, Array] = {}
	for link: TradeLinkState in links:
		if not _current_member(state, link.from_lineage_id) or not _current_member(state, link.to_lineage_id):
			continue
		for id: int in [link.from_lineage_id, link.to_lineage_id]:
			if not adjacency.has(id):
				adjacency[id] = []
		adjacency[link.from_lineage_id].append(link.to_lineage_id)
		adjacency[link.to_lineage_id].append(link.from_lineage_id)
	var nodes: Array[int] = adjacency.keys()
	nodes.sort()
	var visited: Dictionary[int, bool] = {}
	for root_id: int in nodes:
		if visited.has(root_id):
			continue
		var network: CurrentTradeNetwork = CurrentTradeNetwork.new()
		var pending: Array[int] = [root_id]
		while not pending.is_empty():
			var id: int = pending.pop_front()
			if visited.has(id):
				continue
			visited[id] = true
			if state.features.lineage(id).feature_type == DomainTypes.FeatureType.ROAD:
				network.road_lineage_ids.append(id)
			else:
				network.settlement_lineage_ids.append(id)
			var neighbors: Array = adjacency[id].duplicate()
			neighbors.sort()
			for neighbor: int in neighbors:
				if not visited.has(neighbor):
					pending.append(neighbor)
		network.road_lineage_ids.sort()
		network.settlement_lineage_ids.sort()
		var has_access: bool = false
		for link: TradeLinkState in links:
			if _contains(network, link.from_lineage_id) and _contains(network, link.to_lineage_id):
				network.links.append(link)
				has_access = has_access or link.explicit_access
		if has_access and not network.road_lineage_ids.is_empty() and not network.settlement_lineage_ids.is_empty():
			_assign_persisted_identity(state, network)
			result.append(network)
	return result


static func reconcile(state: RunState, source_id: int = 0) -> Array[CurrentTradeNetwork]:
	assert(state.trade != null)
	var current: Array[CurrentTradeNetwork] = rebuild(state)
	var signature: String = graph_signature(state)
	if signature == state.trade.topology_signature:
		return current
	var candidates: Array[Array] = []
	var uses: Dictionary[int, int] = {}
	for network: CurrentTradeNetwork in current:
		var parents: Array[int] = _candidate_ids(state, network)
		candidates.append(parents)
		for id: int in parents:
			uses[id] = uses.get(id, 0) + 1
	var retained: Array[int] = []
	for index: int in range(current.size()):
		var network: CurrentTradeNetwork = current[index]
		var parents: Array[int] = []
		parents.assign(candidates[index])
		var lineage: TradeNetworkLineageState
		var kind: StringName = &"network_created"
		var may_retain: bool = parents.size() == 1 and uses[parents[0]] == 1 and state.trade.lineage(parents[0]).active
		if may_retain:
			lineage = state.trade.lineage(parents[0])
			kind = &"network_grew" if _membership_changed(lineage, network) else &"network_links_changed"
		else:
			lineage = TradeNetworkLineageState.new()
			lineage.lineage_id = state.id_allocator.allocate()
			lineage.parent_ids = parents.duplicate()
			state.trade.lineages.append(lineage)
			if parents.size() > 1:
				kind = &"network_reconnected" if _shared_ancestry(state, parents) else &"network_merged"
			elif parents.size() == 1:
				kind = &"network_split" if uses[parents[0]] > 1 else &"network_reconnected"
		lineage.road_lineage_ids = network.road_lineage_ids.duplicate()
		lineage.settlement_lineage_ids = network.settlement_lineage_ids.duplicate()
		lineage.active = true
		network.lineage_id = lineage.lineage_id
		retained.append(lineage.lineage_id)
		_record(state, kind, lineage, source_id)
	for lineage: TradeNetworkLineageState in _sorted_lineages(state):
		if lineage.active and not retained.has(lineage.lineage_id):
			lineage.active = false
			if not uses.has(lineage.lineage_id):
				_record(state, &"network_dissolved", lineage, source_id)
	state.trade.topology_signature = signature
	state.trade.trade_revision += 1
	return current


static func graph_signature(state: RunState) -> String:
	var parts: Array[String] = []
	for link: TradeLinkState in access_links(state):
		parts.append(link.signature())
	return "trade/" + "|".join(parts)


static func network_for_road(state: RunState, id: int) -> CurrentTradeNetwork:
	for network: CurrentTradeNetwork in rebuild(state):
		if network.road_lineage_ids.has(id):
			return network
	return null


static func network_for_settlement(state: RunState, id: int) -> CurrentTradeNetwork:
	for network: CurrentTradeNetwork in rebuild(state):
		if network.settlement_lineage_ids.has(id):
			return network
	return null


static func settlements_reachable_from_road(state: RunState, id: int) -> Array[int]:
	var network: CurrentTradeNetwork = network_for_road(state, id)
	return network.settlement_lineage_ids.duplicate() if network != null else []


static func same_network(state: RunState, first_id: int, second_id: int) -> bool:
	for network: CurrentTradeNetwork in rebuild(state):
		if _contains(network, first_id) and _contains(network, second_id):
			return true
	return false


static func settlement_count(state: RunState, member_id: int) -> int:
	for network: CurrentTradeNetwork in rebuild(state):
		if _contains(network, member_id):
			return network.settlement_lineage_ids.size()
	return 0


static func get_ancestry_closure(state: RunState, id: int) -> Array[int]:
	var result: Array[int] = []
	if state.trade == null or state.trade.lineage(id) == null:
		return result
	var pending: Array[int] = state.trade.lineage(id).parent_ids.duplicate()
	while not pending.is_empty():
		var parent_id: int = pending.pop_back()
		if result.has(parent_id):
			continue
		result.append(parent_id)
		var parent: TradeNetworkLineageState = state.trade.lineage(parent_id)
		if parent != null:
			pending.append_array(parent.parent_ids)
	result.sort()
	return result


static func is_ancestor(state: RunState, candidate_id: int, lineage_id: int) -> bool:
	return get_ancestry_closure(state, lineage_id).has(candidate_id)


static func _current_member(state: RunState, id: int) -> bool:
	var member: FeatureLineageState = state.features.lineage(id)
	return member != null and member.active and member.feature_type in [DomainTypes.FeatureType.ROAD, DomainTypes.FeatureType.SETTLEMENT]


static func _contains(network: CurrentTradeNetwork, id: int) -> bool:
	return id in network.road_lineage_ids or id in network.settlement_lineage_ids


static func _sorted_lineages(state: RunState) -> Array[TradeNetworkLineageState]:
	var result: Array[TradeNetworkLineageState] = state.trade.lineages.duplicate()
	result.sort_custom(func(a: TradeNetworkLineageState, b: TradeNetworkLineageState) -> bool: return a.lineage_id < b.lineage_id)
	return result


static func _membership_changed(lineage: TradeNetworkLineageState, network: CurrentTradeNetwork) -> bool:
	var roads: Array[int] = lineage.road_lineage_ids.duplicate()
	var settlements: Array[int] = lineage.settlement_lineage_ids.duplicate()
	roads.sort()
	settlements.sort()
	return roads != network.road_lineage_ids or settlements != network.settlement_lineage_ids


static func _assign_persisted_identity(state: RunState, network: CurrentTradeNetwork) -> void:
	if state.trade == null:
		return
	for lineage: TradeNetworkLineageState in _sorted_lineages(state):
		if lineage.active and not _membership_changed(lineage, network):
			network.lineage_id = lineage.lineage_id
			return


static func _candidate_ids(state: RunState, network: CurrentTradeNetwork) -> Array[int]:
	var candidates: Array[int] = []
	for lineage: TradeNetworkLineageState in _sorted_lineages(state):
		var overlaps: bool = false
		for id: int in network.road_lineage_ids + network.settlement_lineage_ids:
			for old_id: int in lineage.road_lineage_ids + lineage.settlement_lineage_ids:
				if id == old_id or LineageService.is_ancestor(state, old_id, id):
					overlaps = true
		if overlaps:
			candidates.append(lineage.lineage_id)
	# Keep the most recent descendants, including dissolved identities. Removing
	# access entirely must not erase history when the same members reconnect later.
	var result: Array[int] = []
	for id: int in candidates:
		var superseded: bool = false
		for other: int in candidates:
			if is_ancestor(state, id, other):
				superseded = true
		if not superseded:
			result.append(id)
	return result


static func _shared_ancestry(state: RunState, parents: Array[int]) -> bool:
	var seen: Array[int] = []
	for id: int in parents:
		var ancestors: Array[int] = get_ancestry_closure(state, id)
		ancestors.append(id)
		for ancestor: int in ancestors:
			if ancestor in seen:
				return true
		seen.append_array(ancestors)
	return false


static func _record(state: RunState, kind: StringName, lineage: TradeNetworkLineageState, source_id: int) -> void:
	var event: TradeHistoryRecord = TradeHistoryRecord.new()
	event.event_id = state.id_allocator.allocate()
	event.kind = kind
	event.lineage_id = lineage.lineage_id
	event.act = state.expansion.current_act
	event.placement_index = state.expansion.normal_placements
	event.source_id = source_id
	event.parent_ids = lineage.parent_ids.duplicate()
	event.road_lineage_ids = lineage.road_lineage_ids.duplicate()
	event.settlement_lineage_ids = lineage.settlement_lineage_ids.duplicate()
	state.trade.history.append(event)
