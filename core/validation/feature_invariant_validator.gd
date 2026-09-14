class_name FeatureInvariantValidator
extends RefCounted
## Validate persisted identity against a fresh graph. Never reconcile, allocate or score.

const KINDS: Array[StringName] = [&"feature_created", &"feature_grew", &"feature_reopened",
	&"feature_merged", &"completion_snapshot", &"feature_completed", &"enclosure_completed",
	&"realm_track_changed"]


static func validate(state: RunState, _content: ContentRegistry, report: InvariantReport) -> void:
	if state.expansion == null or state.expansion.board == null:
		report.add(&"features_without_board", "Features require an authoritative board.")
		return
	var features: FeatureState = state.features
	var ids: Array[int] = []
	var tile_ids: Array[int] = []
	var board_ids: Array[int] = []
	for tile: TileCopyState in state.tile_copies:
		if tile != null:
			ids.append(tile.tile_copy_id)
			tile_ids.append(tile.tile_copy_id)
	for cell: BoardCellState in state.expansion.board.cells.values():
		if cell == null or cell.effective_edges.size() != 4:
			report.add(&"invalid_feature_host", "Feature hosts require valid cells and four sockets.")
			return
		board_ids.append(cell.base_tile_copy_id)
		for group: TileFeatureGroup in cell.feature_groups:
			if group == null or group.edge_type not in [1, 2, 3, 4]:
				report.add(&"invalid_feature_group", "Topology requires valid tracked groups.")
				return
			for direction: int in group.directions:
				if direction not in [0, 1, 2, 3]:
					report.add(&"invalid_feature_socket", "Topology sockets must be canonical directions.")
					return
	var hosts: Array[String] = []
	for component: FeatureComponentState in features.components:
		if component == null:
			report.add(&"null_component", "Component registry cannot contain null.")
			return
		_check_id(state, component.component_id, ids, report)
		var cell: BoardCellState = state.expansion.board.get_cell(component.coordinate)
		var host_key: String = "%s:%d" % [component.coordinate, component.feature_type]
		if cell == null or component.feature_type not in [0, 1, 2, 3] or host_key in hosts:
			report.add(&"invalid_component_host", "One component per present tracked type and square is required.")
			return
		hosts.append(host_key)
		if not _cell_has_type(cell, component.feature_type):
			report.add(&"absent_component_geometry", "Component type is absent from current geometry.")
		if component.origin_act < 1 or component.origin_act > state.expansion.current_act \
			or component.origin_source_runtime_id not in tile_ids \
			or component.origin_source_type not in [&"base_tile", &"fixture_growth"]:
			report.add(&"invalid_component_origin", "Component origin must resolve to a supported acquisition.")
		if component.origin_source_type == &"base_tile" and (component.origin_source_runtime_id != cell.base_tile_copy_id or component.origin_act != cell.act_placed):
			report.add(&"invalid_base_component_origin", "Base component origin must agree with its physical base.")
	for cell: BoardCellState in state.expansion.board.cells.values():
		for group: TileFeatureGroup in cell.feature_groups:
			if features.component_at(cell.coordinate, FeatureState.type_for_edge(group.edge_type)) == null:
				report.add(&"missing_feature_component", "Every tracked cell feature requires persistent identity.")
	for lineage: FeatureLineageState in features.lineages:
		if lineage == null:
			report.add(&"null_lineage", "Lineage registry cannot contain null.")
			return
		_check_id(state, lineage.lineage_id, ids, report)
		if lineage.feature_type not in [0, 1, 2, 3] or lineage.growth_phase < 1:
			report.add(&"invalid_lineage", "Lineage type and growth phase are invalid.")
		_validate_lineage(state, lineage, board_ids, report)
	for component: FeatureComponentState in features.components:
		var lineage: FeatureLineageState = features.lineage(component.lineage_id)
		if lineage == null or not lineage.active or lineage.feature_type != component.feature_type or component.component_id not in lineage.member_ids:
			report.add(&"invalid_component_lineage", "Current components must belong to one matching active lineage.")
	if features.topology_revision != state.expansion.board.revision:
		report.add(&"stale_topology_revision", "Topology must reflect current board revision.")
	if not report.is_valid:
		return # Do not traverse malformed graph references.
	_validate_current(state, report)
	_validate_history(state, ids, board_ids, report)
	_validate_enclosures(state, ids, report)


static func _check_id(state: RunState, id: int, ids: Array[int], report: InvariantReport) -> void:
	if id <= 0 or id in ids or state.id_allocator == null or id >= state.next_runtime_id:
		report.add(&"feature_id_collision", "Runtime identities must be unique and precede the allocation cursor.", id)
	ids.append(id)


static func _cell_has_type(cell: BoardCellState, type: int) -> bool:
	for group: TileFeatureGroup in cell.feature_groups:
		if group.edge_type == FeatureState.edge_for_type(type as DomainTypes.FeatureType):
			return true
	return false


static func _validate_lineage(state: RunState, lineage: FeatureLineageState, board_ids: Array[int], report: InvariantReport) -> void:
	for parents: int in lineage.parent_ids:
		var parent: FeatureLineageState = state.features.lineage(parents)
		if parent == null or parent.active or parent.feature_type != lineage.feature_type or parents >= lineage.lineage_id:
			report.add(&"invalid_lineage_parent", "Parents must be older inactive identities of the same type.")
	# Strictly increasing IDs along parent->child edges also prove ancestry acyclic.
	for key: String in ["parent_ids", "member_ids", "scored_component_ids", "scored_field_ids",
		"scored_river_ids", "scored_forest_ids", "scored_settlement_ids", "completion_ids"]:
		var values: Array[int] = lineage.get(key)
		if not _unique_positive(values):
			report.add(&"duplicate_history_identity", "Lineage sets require unique positive IDs.")
	for component_id: int in lineage.member_ids + lineage.scored_component_ids:
		var component: FeatureComponentState = state.features.component(component_id)
		if component == null or component.feature_type != lineage.feature_type:
			report.add(&"invalid_scored_component", "Historical component IDs must resolve with the lineage type.")
		elif component_id in lineage.scored_component_ids and component_id not in lineage.member_ids:
			report.add(&"unowned_scored_component", "Scored growth must belong to this historical membership.")
	for support_id: int in lineage.scored_field_ids + lineage.scored_river_ids + lineage.scored_forest_ids:
		if support_id not in board_ids:
			report.add(&"invalid_support_history", "Historical support requires a persistent board identity.")
	if not lineage.scored_settlement_ids.is_empty() and (state.trade == null or lineage.feature_type != DomainTypes.FeatureType.ROAD):
		report.add(&"invalid_trade_payment_owner", "Only initialized Road Trade history may retain Settlement payments.")
	for settlement_id: int in lineage.scored_settlement_ids:
		var settlement: FeatureLineageState = state.features.lineage(settlement_id)
		if settlement == null or settlement.feature_type != DomainTypes.FeatureType.SETTLEMENT:
			report.add(&"invalid_settlement_payment", "Road payment history must resolve historical Settlements.")
	if lineage.feature_type != DomainTypes.FeatureType.SETTLEMENT and (not lineage.scored_field_ids.is_empty() or not lineage.scored_river_ids.is_empty() or lineage.highest_settlement_class != 0):
		report.add(&"wrong_support_category", "Only Settlement lineages own Field/River support history.")
	if lineage.highest_settlement_class < 0 or lineage.highest_settlement_class > 2:
		report.add(&"unsupported_settlement_class", "Development-dependent classes are not available.")
	if lineage.feature_type != DomainTypes.FeatureType.RIVER and not lineage.scored_forest_ids.is_empty():
		report.add(&"wrong_contact_category", "Only River lineages own Forest-contact history.")
	if lineage.feature_type == DomainTypes.FeatureType.RIVER and not lineage.completion_ids.is_empty() and not lineage.completed:
		report.add(&"completed_river_reopened", "A historical completed River cannot become unfinished.")
	var expected_phase: int = 1
	for parent_id: int in lineage.parent_ids:
		var parent: FeatureLineageState = state.features.lineage(parent_id)
		if parent != null:
			expected_phase = maxi(expected_phase, parent.growth_phase)
	for event: FeatureHistoryRecord in state.features.history:
		if event != null and event.lineage_id == lineage.lineage_id and event.kind == &"feature_reopened":
			if expected_phase == 9223372036854775807:
				report.add(&"overflowing_growth_history", "Growth phase cannot overflow.")
			else:
				expected_phase += 1
	if lineage.growth_phase != expected_phase:
		report.add(&"growth_history_mismatch", "Growth phase must reflect inherited phases and genuine reopening records.")


static func _validate_current(state: RunState, report: InvariantReport) -> void:
	var current: Array[CurrentFeature] = TopologyService.rebuild(state)
	var current_ids: Array[int] = []
	for feature: CurrentFeature in current:
		var lineage: FeatureLineageState = state.features.lineage(feature.lineage_id)
		if lineage == null or feature.lineage_id in current_ids:
			report.add(&"disconnected_lineage", "Reconstructed connected features require distinct current lineages.")
			continue
		current_ids.append(feature.lineage_id)
		var members: Array[int] = lineage.member_ids.duplicate()
		members.sort()
		if members != feature.component_ids or lineage.completed != (feature.open_exits == 0):
			report.add(&"topology_lineage_mismatch", "Current membership and completion must agree with reconstructed exits.")
	for lineage: FeatureLineageState in state.features.lineages:
		if lineage.active != (lineage.lineage_id in current_ids):
			report.add(&"invalid_lineage_activity", "Exactly the reconstructed lineages may be current.")


static func _unique_positive(values: Array[int]) -> bool:
	var seen: Array[int] = []
	for value: int in values:
		if value <= 0 or value in seen:
			return false
		seen.append(value)
	return true


static func _validate_history(state: RunState, ids: Array[int], board_ids: Array[int], report: InvariantReport) -> void:
	var events: Dictionary[int, FeatureHistoryRecord] = {}
	var totals: Array[int] = [0, 0, 0, 0]
	var largest: Array[int] = [0, 0, 0, 0]
	for event: FeatureHistoryRecord in state.features.history:
		if event == null:
			report.add(&"null_history", "History records cannot be null.")
			return
		_check_id(state, event.event_id, ids, report)
		if event.kind not in KINDS or event.act < 1 or event.act > state.expansion.current_act \
			or event.placement_index < 0 or event.placement_index > state.expansion.normal_placements \
			or (event.source_id != 0 and PhysicalTileRules.find_copy(state, event.source_id) == null):
			report.add(&"invalid_history_record", "History kind, placement or source is invalid.")
		if event.lineage_id != 0 and state.features.lineage(event.lineage_id) == null:
			report.add(&"unresolved_history_lineage", "Historical lineage must resolve.")
		if event.kind in [&"feature_created", &"feature_grew", &"feature_reopened", &"feature_merged", &"feature_completed"]:
			var owner: FeatureLineageState = state.features.lineage(event.lineage_id)
			if owner == null or owner.feature_type != event.feature_type:
				report.add(&"invalid_feature_event", "Feature events require their typed lineage.")
		if not _unique_positive(event.component_ids) or not _unique_positive(event.parent_ids):
			report.add(&"duplicate_event_fact", "Event identity sets cannot contain duplicates.")
		for parent_id: int in event.parent_ids:
			if state.features.lineage(parent_id) == null:
				report.add(&"invalid_event_ancestry", "Event ancestry must resolve.")
		if event.parent_event_id != 0 and not events.has(event.parent_event_id):
			report.add(&"invalid_event_parent", "FIFO child must follow a recorded parent.")
		for component_id: int in event.component_ids:
			if state.features.component(component_id) == null:
				report.add(&"unresolved_event_component", "Event component identity must resolve.")
		if event.kind == &"realm_track_changed":
			if event.track not in [0, 1, 2, 3] or event.amount <= 0:
				report.add(&"invalid_track_event", "Track events require a positive gain.")
			if not events.has(event.parent_event_id) or events[event.parent_event_id].kind not in [&"feature_completed", &"enclosure_completed"]:
				report.add(&"invalid_track_parent", "Track gain must follow a completion parent.")
		elif event.track != -1 or event.amount != 0:
			report.add(&"unexpected_track_data", "Only Track-change events carry gains.")
		events[event.event_id] = event
	var record_ids: Array[int] = []
	for record: FeatureCompletionRecord in state.features.completions:
		if state.trade == null and record != null and (record.trade_network_id != 0 or not record.network_road_ids.is_empty() or not record.network_settlement_ids.is_empty() or not record.new_settlement_ids.is_empty()):
			report.add(&"trade_history_without_state", "Network completion facts require persistent Trade state.")
		if record == null:
			report.add(&"null_completion", "Completion records cannot be null.")
			return
		if record.record_id in record_ids or not events.has(record.record_id) or not events.has(record.snapshot_id):
			report.add(&"invalid_completion_identity", "Completion must share exactly one matching audit event and snapshot.")
			continue
		record_ids.append(record.record_id)
		var event: FeatureHistoryRecord = events[record.record_id]
		if events[record.snapshot_id].kind != &"completion_snapshot" or event.parent_event_id != record.snapshot_id \
			or event.lineage_id != record.lineage_id or event.feature_type != record.feature_type \
			or event.component_ids != record.component_ids or event.act != record.act or event.placement_index != record.placement_index:
			report.add(&"completion_event_mismatch", "Completion audit and frozen facts must agree.")
		if record.lineage_id != 0:
			var lineage: FeatureLineageState = state.features.lineage(record.lineage_id)
			if lineage == null or record.feature_type != lineage.feature_type or record.enclosure_id != 0 or event.kind != &"feature_completed":
				report.add(&"invalid_completion_lineage", "Completion lineage/type must resolve.")
				continue
			if record.total_size != record.component_ids.size() or record.total_size <= 0 or record.growth_phase < 1:
				report.add(&"invalid_completion_size", "Completion must retain its current members and growth phase.")
			largest[record.feature_type] = maxi(largest[record.feature_type], record.total_size)
			for component_id: int in record.component_ids:
				var component: FeatureComponentState = state.features.component(component_id)
				if component == null or component.feature_type != record.feature_type or component_id not in lineage.member_ids:
					report.add(&"invalid_completion_member", "Completed members must resolve to their historical lineage.")
		elif record.feature_type != -1 or record.enclosure_id <= 0 or record.total_size != 8 or event.kind != &"enclosure_completed":
			report.add(&"invalid_enclosure_completion", "Enclosure completion must retain eight-square context.")
		for pair: Array in [[record.component_ids, record.new_component_ids], [record.field_support_ids, record.new_field_ids],
			[record.river_support_ids, record.new_river_ids], [record.forest_contact_ids, record.new_forest_ids]]:
			if not _unique_positive(pair[0]) or not _unique_positive(pair[1]):
				report.add(&"duplicate_completion_fact", "Snapshot sets require unique positive identities.")
			for id: int in pair[1]:
				if id not in pair[0]:
					report.add(&"invalid_new_scoring_fact", "New scoring must be a subset of current snapshot facts.")
		for id: int in record.field_support_ids + record.river_support_ids + record.forest_contact_ids:
			if id not in board_ids:
				report.add(&"invalid_completion_support", "Recorded support must resolve to a board base.")
		if record.gains.size() != 4:
			report.add(&"invalid_completion_gains", "All four Track gains must be explicit.")
			continue
		for track: int in range(4):
			if record.gains[track] < 0 or totals[track] > 9223372036854775807 - record.gains[track]:
				report.add(&"invalid_cumulative_gain", "Completion gains must be nonnegative and representable.")
				continue
			totals[track] += record.gains[track]
	_validate_scoring_history(state, record_ids, report)
	if state.features.tracks == null or state.features.tracks.values != totals:
		report.add(&"track_history_mismatch", "Cumulative Tracks must equal recorded base gains.")
	if state.features.largest_completed_sizes != largest:
		report.add(&"largest_record_mismatch", "Historical size records must agree with completions.")


static func _validate_scoring_history(state: RunState, record_ids: Array[int], report: InvariantReport) -> void:
	for lineage: FeatureLineageState in state.features.lineages:
		var eligible_lineages: Array[int] = LineageService.get_ancestry_closure(state, lineage.lineage_id)
		eligible_lineages.append(lineage.lineage_id)
		var expected: Dictionary = {"completion_ids": [], "scored_component_ids": [],
			"scored_field_ids": [], "scored_river_ids": [], "scored_forest_ids": [], "scored_settlement_ids": []}
		var highest_class: int = 0
		for record: FeatureCompletionRecord in state.features.completions:
			if record.lineage_id not in eligible_lineages:
				continue
			expected["completion_ids"].append(record.record_id)
			highest_class = maxi(highest_class, record.settlement_class)
			for pair: Array in [["scored_component_ids", record.new_component_ids], ["scored_field_ids", record.new_field_ids],
				["scored_river_ids", record.new_river_ids], ["scored_forest_ids", record.new_forest_ids], ["scored_settlement_ids", record.new_settlement_ids]]:
				for id: int in pair[1]:
					if not expected[pair[0]].has(id):
						expected[pair[0]].append(id)
		for key: String in expected:
			var actual: Array[int] = lineage.get(key).duplicate()
			actual.sort()
			expected[key].sort()
			if actual != expected[key]:
				report.add(&"scoring_history_mismatch", "Lineage scoring sets must equal retained ancestral completion facts.")
		for id: int in lineage.completion_ids:
			if id not in record_ids:
				report.add(&"unresolved_completion", "Every lineage completion must resolve.")
		if lineage.highest_settlement_class != highest_class:
			report.add(&"historical_class_mismatch", "Highest class must agree with retained Establishment records.")
	for record: FeatureCompletionRecord in state.features.completions:
		var child_gains: Array[int] = [0, 0, 0, 0]
		for event: FeatureHistoryRecord in state.features.history:
			if event.kind == &"realm_track_changed" and event.parent_event_id == record.record_id and event.track in [0, 1, 2, 3] and event.amount > 0:
				if child_gains[event.track] != 0:
					report.add(&"duplicate_track_child", "One completion produces one child per gained Track.")
				child_gains[event.track] = event.amount
		if child_gains != record.gains:
			report.add(&"track_child_mismatch", "FIFO Track children must agree with completion gains.")
		if record.lineage_id == 0:
			continue
		var expected_gain: Array[int] = [0, 0, 0, 0]
		match record.feature_type:
			DomainTypes.FeatureType.ROAD: expected_gain[1] = record.new_component_ids.size() + 2 * record.new_settlement_ids.size()
			DomainTypes.FeatureType.SETTLEMENT: expected_gain[0] = 2 * record.new_component_ids.size() + record.new_field_ids.size() + record.new_river_ids.size()
			DomainTypes.FeatureType.FOREST: expected_gain[3] = record.new_component_ids.size() + 2
			DomainTypes.FeatureType.RIVER: expected_gain[3] = (floori(record.total_size / 2.0) if record.first_completion else 0) + record.new_forest_ids.size()
		if record.gains != expected_gain:
			report.add(&"base_scoring_mismatch", "Base gains must match recorded new growth/support and Trade payments.")
		var ancestors: Array[int] = LineageService.get_ancestry_closure(state, record.lineage_id)
		ancestors.append(record.lineage_id)
		var prior_completion: bool = false
		var historical_class: int = 0
		for prior: FeatureCompletionRecord in state.features.completions:
			if prior.record_id >= record.record_id or prior.lineage_id not in ancestors:
				continue
			prior_completion = true
			historical_class = maxi(historical_class, prior.settlement_class)
			if prior.lineage_id == record.lineage_id and prior.growth_phase >= record.growth_phase:
				report.add(&"completion_without_growth_phase", "Re-completion requires a genuinely new unfinished growth phase.")
			for pair: Array in [[record.new_component_ids, prior.new_component_ids], [record.new_field_ids, prior.new_field_ids],
				[record.new_river_ids, prior.new_river_ids], [record.new_forest_ids, prior.new_forest_ids]]:
				for id: int in pair[0]:
					if id in pair[1]:
						report.add(&"duplicate_base_scoring", "An ancestral scoring contribution cannot pay twice.")
			for settlement_id: int in record.new_settlement_ids:
				var settlement_ancestry: Array[int] = LineageService.get_ancestry_closure(state, settlement_id)
				settlement_ancestry.append(settlement_id)
				for paid_id: int in prior.new_settlement_ids:
					if paid_id in settlement_ancestry:
						report.add(&"duplicate_trade_payment", "A merged Settlement cannot repay an ancestral Road.")
		if record.first_completion == prior_completion:
			report.add(&"invalid_first_completion", "First completion must agree with historical ancestry.")
		if record.feature_type == DomainTypes.FeatureType.SETTLEMENT:
			var qualified: int = 1 if record.total_size <= 2 else (2 if record.total_size <= 5 else 0)
			if record.settlement_class != maxi(qualified, historical_class):
				report.add(&"invalid_establishment_class", "Establishment class requires canonical qualification or prior history.")
		elif record.settlement_class != 0:
			report.add(&"unexpected_settlement_class", "Other feature completions cannot establish a Settlement class.")


static func _validate_enclosures(state: RunState, ids: Array[int], report: InvariantReport) -> void:
	var hosts: Array[Vector2i] = []
	for enclosure: EnclosureState in state.features.enclosures:
		if enclosure == null:
			report.add(&"null_enclosure", "Enclosures cannot be null.")
			return
		_check_id(state, enclosure.enclosure_id, ids, report)
		if not state.expansion.board.cells.has(enclosure.coordinate) or enclosure.coordinate in hosts \
			or enclosure.family_id != &"monastery" or enclosure.stage != &"monastery" \
			or enclosure.development_tile_copy_id != 0 or enclosure.assigned_steward_id != 0:
			report.add(&"invalid_enclosure", "Phase 3 supports one deferred Monastery fixture per occupied host.")
		hosts.append(enclosure.coordinate)
		var occupied: int = 0
		var natural: int = 0
		for x: int in range(-1, 2):
			for y: int in range(-1, 2):
				if x == 0 and y == 0:
					continue
				var cell: BoardCellState = state.expansion.board.get_cell(enclosure.coordinate + Vector2i(x, y))
				if cell != null:
					occupied += 1
					if EnclosureService.has_natural_geography(cell):
						natural += 1
		var expected_ids: Array[int] = []
		for record: FeatureCompletionRecord in state.features.completions:
			if record.enclosure_id == enclosure.enclosure_id:
				expected_ids.append(record.record_id)
				if record.gains != [0, 0, 5 + natural, 0]:
					report.add(&"invalid_enclosure_gain", "Monastery scores base five plus distinct natural neighbors.")
		var expected_stages: Array[StringName] = []
		if occupied == 8:
			expected_stages.append(&"monastery")
		if enclosure.completed_stages != expected_stages or enclosure.completion_ids != expected_ids \
			or expected_ids.size() != expected_stages.size():
			report.add(&"enclosure_history_mismatch", "Eight-neighbor completion may score its stage only once.")
