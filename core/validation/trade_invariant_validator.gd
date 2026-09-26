class_name TradeInvariantValidator
extends RefCounted
## Load validation reconstructs the graph without mutating its historical identity.

const KINDS: Array[StringName] = [&"network_created", &"network_grew", &"network_merged",
	&"network_split", &"network_reconnected", &"network_dissolved", &"network_links_changed"]


static func validate(state: RunState, report: InvariantReport) -> void:
	if state.features == null or state.expansion == null:
		report.add(&"trade_without_features", "Trade requires persistent physical feature identity.")
		return
	var ids: Array[int] = []
	for tile: TileCopyState in state.tile_copies:
		ids.append(tile.tile_copy_id)
	for component: FeatureComponentState in state.features.components:
		ids.append(component.component_id)
	for lineage: FeatureLineageState in state.features.lineages:
		ids.append(lineage.lineage_id)
	for event: FeatureHistoryRecord in state.features.history:
		ids.append(event.event_id)
	for enclosure: EnclosureState in state.features.enclosures:
		ids.append(enclosure.enclosure_id)
	if state.trade.trade_revision < 0:
		report.add(&"invalid_trade_revision", "Trade revision cannot be negative.")
	for lineage: TradeNetworkLineageState in state.trade.lineages:
		if lineage == null:
			report.add(&"null_trade_lineage", "Network registry cannot contain null.")
			return
		FeatureInvariantValidator._check_id(state, lineage.lineage_id, ids, report)
		_validate_members(state, lineage.road_lineage_ids, lineage.settlement_lineage_ids, lineage.active, report)
		if not FeatureInvariantValidator._unique_positive(lineage.parent_ids):
			report.add(&"duplicate_trade_parent", "Network parents must be unique positive identities.")
		for parent_id: int in lineage.parent_ids:
			var parent: TradeNetworkLineageState = state.trade.lineage(parent_id)
			if parent == null or parent.active or parent_id >= lineage.lineage_id:
				report.add(&"invalid_trade_parent", "Network ancestry requires older archived parents.")
	var signatures: Array[String] = []
	for link: TradeLinkState in state.trade.authorized_links:
		if link == null:
			report.add(&"null_trade_link", "Authorized links cannot contain null.")
			return
		if link.explicit_access or link.source_kind != &"fixture_authorized" \
			or link.from_lineage_id == link.to_lineage_id or not _current_member(state, link.from_lineage_id) \
			or not _current_member(state, link.to_lineage_id) \
			or (link.source_id != 0 and PhysicalTileRules.find_copy(state, link.source_id) == null):
			report.add(&"invalid_authorized_trade_link", "Fixture links require current economic members and a valid source; native access comes from board metadata.")
		if link.signature() in signatures:
			report.add(&"duplicate_trade_link", "Economic contributions must have distinct signatures.")
		signatures.append(link.signature())
	_validate_history(state, ids, report)
	if not report.is_valid:
		return
	var current_ids: Array[int] = []
	for network: CurrentTradeNetwork in TradeNetworkService.rebuild(state):
		if network.lineage_id <= 0 or network.lineage_id in current_ids:
			report.add(&"invalid_current_trade_identity", "Each economic connected component requires one distinct persistent network identity.")
		current_ids.append(network.lineage_id)
	for lineage: TradeNetworkLineageState in state.trade.lineages:
		if lineage.active != (lineage.lineage_id in current_ids):
			report.add(&"trade_membership_mismatch", "Active network identity must agree with the reconstructed economic graph.")
	if state.trade.topology_signature != TradeNetworkService.graph_signature(state):
		report.add(&"stale_trade_topology", "Trade signature must match current authoritative access and feature identity.")
	_validate_completions(state, report)


static func _current_member(state: RunState, id: int) -> bool:
	var lineage: FeatureLineageState = state.features.lineage(id)
	return lineage != null and lineage.active and lineage.feature_type in [DomainTypes.FeatureType.ROAD, DomainTypes.FeatureType.SETTLEMENT]


static func _validate_members(state: RunState, roads: Array[int], settlements: Array[int], current: bool, report: InvariantReport) -> void:
	if roads.is_empty() or settlements.is_empty() or not FeatureInvariantValidator._unique_positive(roads) \
		or not FeatureInvariantValidator._unique_positive(settlements):
		report.add(&"invalid_trade_members", "Every qualifying network needs distinct Road and Settlement members.")
	for pair: Array in [[roads, DomainTypes.FeatureType.ROAD], [settlements, DomainTypes.FeatureType.SETTLEMENT]]:
		for id: int in pair[0]:
			var member: FeatureLineageState = state.features.lineage(id)
			if member == null or member.feature_type != pair[1] or (current and not member.active):
				report.add(&"unresolved_trade_member", "Economic members must resolve with their physical feature type and activity.")


static func _validate_history(state: RunState, ids: Array[int], report: InvariantReport) -> void:
	var previous: int = 0
	var latest: Dictionary[int, TradeHistoryRecord] = {}
	for event: TradeHistoryRecord in state.trade.history:
		if event == null:
			report.add(&"null_trade_history", "Network history cannot contain null.")
			return
		FeatureInvariantValidator._check_id(state, event.event_id, ids, report)
		var lineage: TradeNetworkLineageState = state.trade.lineage(event.lineage_id)
		if lineage == null or event.kind not in KINDS or event.event_id <= previous \
			or event.lineage_id >= event.event_id or event.act < 1 or event.act > state.expansion.current_act \
			or event.placement_index < 0 or event.placement_index > PlacementChronology.count_for_act(state, event.act):
			report.add(&"invalid_trade_history", "Network audit identity, chronology and type must resolve.")
		previous = event.event_id
		if lineage != null and not _same_set(event.parent_ids, lineage.parent_ids):
			report.add(&"trade_history_ancestry", "Audit ancestry must agree with its persistent lineage.")
		if not latest.has(event.lineage_id):
			if event.kind not in [&"network_created", &"network_merged", &"network_split", &"network_reconnected"]:
				report.add(&"missing_trade_origin", "Network history must start with a creation or ancestry event.")
			if (event.kind == &"network_created" and not event.parent_ids.is_empty()) \
				or (event.kind == &"network_merged" and event.parent_ids.size() < 2) \
				or (event.kind in [&"network_split", &"network_reconnected"] and event.parent_ids.is_empty()):
				report.add(&"trade_origin_ancestry", "Split, merger and reconnection history must retain appropriate parents.")
		if event.source_id != 0 and PhysicalTileRules.find_copy(state, event.source_id) == null and not _relic_source(state, event.source_id):
			report.add(&"trade_history_source", "Network change source must resolve.")
		_validate_members(state, event.road_lineage_ids, event.settlement_lineage_ids, false, report)
		latest[event.lineage_id] = event
	for lineage: TradeNetworkLineageState in state.trade.lineages:
		if not latest.has(lineage.lineage_id):
			report.add(&"missing_trade_history", "Each network identity needs its structured creation history.")
			continue
		var event: TradeHistoryRecord = latest[lineage.lineage_id]
		if not _same_set(lineage.road_lineage_ids, event.road_lineage_ids) \
			or not _same_set(lineage.settlement_lineage_ids, event.settlement_lineage_ids):
			report.add(&"trade_history_membership", "Last recorded membership must agree with reconciliation metadata.")


static func _validate_completions(state: RunState, report: InvariantReport) -> void:
	for record: FeatureCompletionRecord in state.features.completions:
		if record.trade_network_id == 0:
			if not record.network_road_ids.is_empty() or not record.network_settlement_ids.is_empty() or not record.new_settlement_ids.is_empty():
				report.add(&"missing_completion_network", "Network scoring facts require a historical network identity.")
			continue
		if record.feature_type != DomainTypes.FeatureType.ROAD or state.trade.lineage(record.trade_network_id) == null \
			or record.trade_network_id >= record.record_id or record.lineage_id not in record.network_road_ids:
			report.add(&"invalid_completion_network", "Only Road completions reference containing historical networks.")
		_validate_members(state, record.network_road_ids, record.network_settlement_ids, false, report)
		if not FeatureInvariantValidator._unique_positive(record.new_settlement_ids):
			report.add(&"duplicate_completion_payment", "Settlement payments must be distinct.")
		var historical: TradeHistoryRecord = null
		for event: TradeHistoryRecord in state.trade.history:
			if event.lineage_id == record.trade_network_id and event.event_id < record.snapshot_id:
				historical = event
		if historical == null or not _same_set(historical.road_lineage_ids, record.network_road_ids) \
			or not _same_set(historical.settlement_lineage_ids, record.network_settlement_ids):
			report.add(&"completion_network_snapshot", "Completion membership must match the network at its shared snapshot.")
		var paid: Array[int] = []
		var road_ancestors: Array[int] = LineageService.get_ancestry_closure(state, record.lineage_id)
		road_ancestors.append(record.lineage_id)
		for prior: FeatureCompletionRecord in state.features.completions:
			if prior.record_id < record.record_id and prior.lineage_id in road_ancestors and prior.base_multiplier != 0:
				paid.append_array(prior.new_settlement_ids)
		var expected: Array[int] = []
		for settlement_id: int in record.network_settlement_ids:
			var ancestors: Array[int] = LineageService.get_ancestry_closure(state, settlement_id)
			ancestors.append(settlement_id)
			var already_paid: bool = false
			for id: int in ancestors:
				already_paid = already_paid or id in paid
			if not already_paid:
				expected.append(settlement_id)
		if not _same_set(expected, record.new_settlement_ids):
			report.add(&"completion_payment_eligibility", "Road payments must equal unscored Settlement ancestry at completion.")


static func _same_set(first: Array[int], second: Array[int]) -> bool:
	var a: Array[int] = first.duplicate()
	var b: Array[int] = second.duplicate()
	a.sort()
	b.sort()
	return a == b


static func _relic_source(state: RunState, source_id: int) -> bool:
	if state.relics != null:
		for instance: RelicInstanceState in state.relics.instances:
			if instance.runtime_id == source_id:
				return true
	return false
