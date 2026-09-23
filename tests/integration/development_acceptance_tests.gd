extends "res://tests/framework/test_suite.gd"

const F = preload("res://tests/fixtures/phase_five_factory.gd")
const P = preload("res://tests/fixtures/phase_three_factory.gd")
const TYPE = DomainTypes.FeatureType


func tests() -> Array[Callable]:
	var result: Array[Callable] = [port_multiple_rivers, mill_multiple_completed_hosts,
		lodge_follows_forest_merger, unfinished_class_survives_growth,
		legacy_enclosure_excluded, network_changes_never_trigger,
		mixed_development_batch, completed_market_and_lodge_load_inert,
		ports_complete_in_shared_batch, enclosure_and_settlement_share_snapshot]
	for stage: String in ["housing", "market", "grand_market", "town_square", "port"]:
		result.append(settlement_host_follows_merger.bind(stage))
	return result


func port_multiple_rivers() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry, 2)
	F.complete_settlement(state, registry)
	P.add(state, registry, &"tile.river_end", Vector2i(1, -1), 1)
	P.add(state, registry, &"tile.river_end", Vector2i(-1, -1), 3)
	var copy_id: int = F.acquire_hand(state, &"tile.development.port")
	var options: Array[PlacementOption] = []
	for option: PlacementOption in F.options(state, registry, copy_id):
		if option.coordinate == Vector2i.UP:
			options.append(option)
	expect_equal(options.size(), 3, "Shared orthogonal edges expose three distinct Rivers despite Field sockets")
	if options.size() != 3:
		return true
	expect_true(options[0].river_lineage_id < options[1].river_lineage_id and options[1].river_lineage_id < options[2].river_lineage_id, "River intent order is stable")
	var forged: PlaceTileCommand = F.command(options[0])
	forged.river_lineage_id = options[1].river_lineage_id
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, registry, forged).is_valid, "Signature binds selected River")
	expect_equal(StateNormalizer.fingerprint(state), before, "Forged association is atomic")
	expect_true(RulesEngine.execute(state, registry, F.command(options[2])).is_valid, "Explicit selected River commits")
	expect_equal(F.development(state, Vector2i.UP).river_lineage_id, options[2].river_lineage_id, "No arbitrary River selection after commit")
	return true


func mill_multiple_completed_hosts() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	F.complete_settlement(state, registry)
	P.add(state, registry, &"tile.open_fields", Vector2i(1, -1))
	P.add(state, registry, &"tile.hamlet_edge", Vector2i(2, -1), 2)
	P.add(state, registry, &"tile.hamlet_edge", Vector2i(2, 0))
	P.add(state, registry, &"tile.river_end", Vector2i(1, -2))
	var before: Array[int] = state.features.tracks.values.duplicate()
	var completions: int = state.features.completions.size()
	F.play(state, registry, &"tile.development.mill", Vector2i(1, -1))
	expect_equal(state.features.tracks.values[0] - before[0], 4, "New Mill resolves for each distinct completed touching Settlement")
	expect_equal(state.features.tracks.values[1] - before[1], 2, "Orthogonal River bonus applies to each Mill resolution")
	expect_equal(state.features.completions.size(), completions, "No fake feature completion")
	return true


func settlement_host_follows_merger(stage: String) -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry, 3)
	F.complete_settlement(state, registry)
	if stage == "port":
		P.add(state, registry, &"tile.river_end", Vector2i.DOWN)
	if stage == "grand_market":
		F.play(state, registry, &"tile.development.market", Vector2i.ZERO)
	var copy_id: int = F.play(state, registry, StringName("tile.development." + stage), Vector2i.ZERO)
	var development: DevelopmentState = DevelopmentService.find(state, copy_id)
	var parent: int = development.host_lineage_id
	var river: int = development.river_lineage_id
	P.add(state, registry, &"tile.open_fields", Vector2i(1, -1))
	P.add(state, registry, &"tile.open_fields", Vector2i(1, -2))
	P.add(state, registry, &"tile.hamlet_edge", Vector2i(1, -3), 3)
	P.add(state, registry, &"tile.hamlet_edge", Vector2i(0, -3), 1)
	assert(P.rewrite(state, registry, Vector2i.UP, [4, 0, 4, 0]).is_valid)
	assert(P.rewrite(state, registry, Vector2i(0, -3), [0, 4, 4, 0]).is_valid)
	P.add(state, registry, &"tile.settlement_throughway", Vector2i(0, -2))
	expect_true(development.host_lineage_id != parent, stage + " follows new descendant")
	expect_true(LineageService.is_ancestor(state, parent, development.host_lineage_id), "Canonical lineage ancestry preserved")
	expect_equal(development.river_lineage_id, river, "Settlement merger preserves River association")
	expect_true(RunSerializer.serialize(state, registry).validation.is_valid, "Merged host saves with invariants intact")
	return true


func lodge_follows_forest_merger() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	P.add(state, registry, &"tile.forest_edge", Vector2i.LEFT, 1)
	var copy_id: int = F.play(state, registry, &"tile.development.foresters_lodge", Vector2i.LEFT)
	var parent: int = DevelopmentService.find(state, copy_id).host_lineage_id
	P.add(state, registry, &"tile.open_fields", Vector2i(-2, 0))
	P.add(state, registry, &"tile.open_fields", Vector2i(-2, 1))
	P.add(state, registry, &"tile.forest_edge", Vector2i(-2, 2), 1)
	P.add(state, registry, &"tile.forest_edge", Vector2i(-1, 2), 3)
	assert(P.rewrite(state, registry, Vector2i.LEFT, [0, 1, 1, 0]).is_valid)
	assert(P.rewrite(state, registry, Vector2i(-1, 2), [1, 0, 0, 1]).is_valid)
	P.add(state, registry, &"tile.forest_belt", Vector2i(-1, 1))
	var descendant: int = DevelopmentService.find(state, copy_id).host_lineage_id
	expect_true(parent != descendant and LineageService.is_ancestor(state, parent, descendant), "Lodge follows merged Forest")
	expect_true(state.features.completions[-1].forest_undeveloped, "Lodge retains preservation after merger")
	return true


func unfinished_class_survives_growth() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry, 3)
	F.play(state, registry, &"tile.development.housing", Vector2i.ZERO)
	for index: int in range(1, 8):
		P.add(state, registry, &"tile.settlement_throughway", Vector2i(0, -index))
	var lineage: FeatureLineageState = P.lineage_at(state, Vector2i.ZERO, TYPE.SETTLEMENT)
	expect_equal(lineage.highest_settlement_class, 3, "Unfinished eight-tile Settlement has qualified as Town")
	P.add(state, registry, &"tile.hamlet_edge", Vector2i(0, -8), 2)
	expect_equal(DevelopmentService.current_class(state, lineage.lineage_id), 0, "Nine tiles with one family do not currently qualify for City")
	expect_equal(lineage.highest_settlement_class, 3, "Prior Town qualification is retained")
	var record: FeatureCompletionRecord = state.features.completions[-1]
	expect_equal(record.highest_class_before_completion, 3, "Completion freezes prior unfinished qualification")
	expect_equal(record.settlement_class, 3, "Establishment retains Town")
	var saved: SerializationResult = RunSerializer.serialize(state, registry)
	expect_true(saved.validation.is_valid, "Historical class passes save invariant")
	expect_true(RunSerializer.deserialize(saved.json_text, registry).validation.is_valid, "Historical class survives reconstruction")
	F.play(state, registry, &"tile.development.town_square", Vector2i.UP)
	expect_equal(DevelopmentService.current_class(state, lineage.lineage_id), 4, "Actual second family qualifies City")
	expect_equal(lineage.highest_settlement_class, 4, "Immediate Development updates highest qualification")
	return true


func legacy_enclosure_excluded() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	F.complete_settlement(state, registry)
	P.add_monastery(state, registry, Vector2i.UP)
	var copy_id: int = F.acquire_hand(state, &"tile.development.monastery")
	expect_true(F.options(state, registry, copy_id).is_empty(), "Existing fixture enclosure cannot acquire duplicate live enclosure")
	var command: PlaceTileCommand = PlaceTileCommand.new(copy_id, TileLocationState.Kind.ACTIVE_HAND, Vector2i.UP)
	command.placement_mode = DomainTypes.PlacementMode.DEVELOPMENT
	var before: String = StateNormalizer.fingerprint(state)
	expect_true(not RulesEngine.execute(state, registry, command).is_valid, "Duplicate enclosure command rejected before mutation")
	expect_equal(StateNormalizer.fingerprint(state), before, "Rejected enclosure preserves state")
	return true


func network_changes_never_trigger() -> bool:
	var registry: ContentRegistry = F.content()
	for upgrade: bool in [false, true]:
		var state: RunState = F.Previous.pair(registry)
		state.expansion.current_act = 3
		F.complete_settlement(state, registry)
		F.play(state, registry, &"tile.development.market", Vector2i.ZERO)
		if upgrade:
			F.play(state, registry, &"tile.development.grand_market", Vector2i.ZERO)
		var before: Array[int] = state.features.tracks.values.duplicate()
		var events: int = state.features.history.size()
		F.Previous.connect_pair(state)
		F.Previous.disconnect_pair(state)
		F.Previous.connect_pair(state)
		expect_equal(state.features.tracks.values, before, "Network merger/split/reconnection alone pays neither Market stage")
		expect_equal(state.features.history.size(), events, "Economic changes do not emit Development triggers")
		assert(P.rewrite(state, registry, Vector2i.UP, [4, 0, 4, 0]).is_valid)
		P.add(state, registry, &"tile.hamlet_edge", Vector2i(0, -2), 2)
		expect_equal(state.features.tracks.values[1] - before[1], 2 if upgrade else 1, "Genuine later completion uses current full network")
	return true


func mixed_development_batch() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry, 3)
	for index: int in range(1, 6):
		P.add(state, registry, &"tile.settlement_throughway", Vector2i(0, -index))
	P.add(state, registry, &"tile.river_end", Vector2i(1, -3), 1)
	P.add(state, registry, &"tile.open_fields", Vector2i(1, -4))
	P.add(state, registry, &"tile.settlement_gate", Vector2i.RIGHT, 2)
	P.add(state, registry, &"tile.settlement_gate", Vector2i.ONE)
	P.add(state, registry, &"tile.settlement_gate", Vector2i(2, 1), 2)
	var copies: Array[int] = []
	var stages: Array[String] = ["housing", "housing", "market", "port", "town_square", "market"]
	for index: int in range(stages.size()):
		copies.append(F.play(state, registry, StringName("tile.development." + stages[index]), Vector2i(0, -index)))
	var removed_market: int = copies.pop_back()
	copies.append(F.play(state, registry, &"tile.development.grand_market", Vector2i(0, -5)))
	copies.append(F.play(state, registry, &"tile.development.mill", Vector2i(1, -4)))
	var history_start: int = state.features.history.size()
	F.play(state, registry, &"tile.hamlet_edge", Vector2i(0, -6))
	var triggered: Array[int] = []
	var parent_ids: Array[int] = []
	var gains: Array[int] = [0, 0, 0, 0]
	var base_seen: bool = false
	for event: FeatureHistoryRecord in state.features.history.slice(history_start):
		if event.kind == &"feature_completed":
			base_seen = true
		if event.kind == &"development_completion_trigger":
			expect_true(base_seen, "Base completion precedes Development batch")
			triggered.append(event.source_id)
			if not parent_ids.has(event.parent_event_id):
				parent_ids.append(event.parent_event_id)
		if event.kind == &"realm_track_changed" and copies.has(event.source_id):
			gains[event.track] += event.amount
	triggered.sort()
	copies.sort()
	expect_equal(triggered, copies, "All seven physical Developments trigger independently")
	expect_equal(parent_ids.size(), 1, "Every Development shares the same completion snapshot")
	expect_equal(gains, [6, 9, 8, 0], "Housing duplicates, transitive Market stages, Port, family diversity and River Mill batch")
	expect_true(not triggered.has(removed_market), "Replaced Market is absent from trigger batch")
	var record: FeatureCompletionRecord = state.features.completions[-1]
	expect_equal(record.development_families, [&"family.housing", &"family.market", &"family.port", &"family.town_square"], "Snapshot deduplicates Housing and Market stages, excludes Mill")
	expect_equal(record.settlement_class, 3, "Seven tiles with Developments qualifies Town")
	return true


func completed_market_and_lodge_load_inert() -> bool:
	var registry: ContentRegistry = F.content()
	for stage: String in ["market", "foresters_lodge"]:
		var state: RunState = F.create(registry, 2)
		if stage == "market":
			F.complete_settlement(state, registry)
		else:
			P.add(state, registry, &"tile.forest_edge", Vector2i.LEFT, 1)
		F.play(state, registry, StringName("tile.development." + stage), Vector2i.ZERO)
		var before: String = StateNormalizer.fingerprint(state)
		for iteration: int in range(3):
			var saved: SerializationResult = RunSerializer.serialize(state, registry)
			expect_true(saved.validation.is_valid, "Completed host saves")
			var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, registry)
			expect_true(loaded.validation.is_valid, "Completed host loads")
			if loaded.state == null:
				return true
			state = loaded.state
			expect_equal(StateNormalizer.fingerprint(state), before, stage + " repeated load emits no scoring, event, ID or RNG change")
	return true


func ports_complete_in_shared_batch() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry, 2)
	P.add(state, registry, &"tile.settlement_throughway", Vector2i.UP)
	P.add(state, registry, &"tile.settlement_throughway", Vector2i(0, -2))
	P.add(state, registry, &"tile.river_end", Vector2i(1, -1))
	P.add(state, registry, &"tile.river_end", Vector2i(1, -2), 2)
	var river: int = state.features.component_at(Vector2i(1, -1), TYPE.RIVER).lineage_id
	var first: int = F.play(state, registry, &"tile.development.port", Vector2i.UP, river)
	var second: int = F.play(state, registry, &"tile.development.port", Vector2i(0, -2), river)
	var before: int = state.features.tracks.values[1]
	F.play(state, registry, &"tile.hamlet_edge", Vector2i(0, -3))
	expect_equal(state.features.tracks.values[1] - before, 6, "Both Ports see each other in the same River snapshot")
	var parents: Array[int] = []
	for event: FeatureHistoryRecord in state.features.history:
		if event.kind == &"development_completion_trigger" and event.source_id in [first, second]:
			parents.append(event.parent_event_id)
	expect_equal(parents.size(), 2, "Both physical Ports triggered")
	if parents.size() == 2:
		expect_equal(parents[0], parents[1], "Port peer calculations share immutable snapshot")
	return true


func enclosure_and_settlement_share_snapshot() -> bool:
	var registry: ContentRegistry = F.content()
	var state: RunState = F.create(registry)
	P.add(state, registry, &"tile.settlement_throughway", Vector2i.UP)
	P.add(state, registry, &"tile.road_end", Vector2i.RIGHT, 3)
	P.add(state, registry, &"tile.open_fields", Vector2i(1, -1))
	P.add(state, registry, &"tile.open_fields", Vector2i(1, -2))
	P.add(state, registry, &"tile.open_fields", Vector2i(2, -2))
	P.add(state, registry, &"tile.open_fields", Vector2i(2, -1))
	P.add(state, registry, &"tile.open_fields", Vector2i(2, 0))
	F.play(state, registry, &"tile.development.housing", Vector2i.ZERO)
	F.play(state, registry, &"tile.development.monastery", Vector2i(1, -1))
	var before: int = state.features.completions.size()
	F.play(state, registry, &"tile.hamlet_edge", Vector2i(0, -2))
	expect_equal(state.features.completions.size() - before, 2, "Eighth square simultaneously completes Settlement and live Monastery")
	var records: Array[FeatureCompletionRecord] = state.features.completions
	expect_equal(records[-1].snapshot_id, records[-2].snapshot_id, "Enclosure and edge-connected feature share completion package")
	expect_equal(state.features.tracks.values[2], 13, "Mixed natural neighbors count once for Monastery")
	return true
