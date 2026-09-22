extends "res://tests/framework/test_suite.gd"

const Fixture = preload("res://tests/fixtures/phase_four_factory.gd")


func tests() -> Array[Callable]:
	return [genealogy_round_trip, repeated_load_has_no_effects, payment_history_round_trip,
		normalization_ignores_registry_order, history_changes_fingerprint,
		invalid_parent_rejected, current_membership_corruption_rejected,
		missing_current_identity_rejected, bad_revision_rejected, bad_payment_rejected,
		network_snapshot_corruption_rejected, network_id_collision_rejected,
		multiple_current_networks_round_trip, split_origin_cannot_lose_ancestry]


func genealogy_round_trip() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.genealogy(registry)
	var loaded: RunState = _load(state, registry)
	if loaded == null: return true
	expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Network genealogy and all physical state round-trip exactly")
	expect_equal(TradeNetworkService.rebuild(loaded)[0].signature(), TradeNetworkService.rebuild(state)[0].signature(), "Pure current graph reconstruction is identical")
	expect_equal(loaded.id_allocator.allocate(), state.id_allocator.allocate(), "Future IDs remain exact")
	expect_equal(loaded.rng.select_index(37), state.rng.select_index(37), "Future RNG remains exact")
	return true


func repeated_load_has_no_effects() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.genealogy(registry)
	var fingerprint: String = StateNormalizer.fingerprint(state)
	var ids: int = state.next_runtime_id
	var rng: int = state.current_rng_state
	var draws: int = state.rng.operation_count
	var events: int = state.trade.history.size() + state.features.history.size()
	var tracks: Array[int] = state.features.tracks.values.duplicate()
	for index: int in range(4):
		state = _load(state, registry)
		if state == null: return true
		expect_equal(StateNormalizer.fingerprint(state), fingerprint, "Repeated load is stable")
		expect_equal(state.next_runtime_id, ids, "No IDs allocated on load")
		expect_equal([state.current_rng_state, state.rng.operation_count], [rng, draws], "No RNG use on load")
		expect_equal(state.trade.history.size() + state.features.history.size(), events, "No graph or completion history emitted on load")
		expect_equal(state.features.tracks.values, tracks, "No loading score")
	return true


func payment_history_round_trip() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.chain(registry)
	Fixture.reopen_first_road(state, registry)
	Fixture.close_first_road(state, registry)
	var loaded: RunState = _load(state, registry)
	if loaded != null:
		expect_equal(StateNormalizer.normalize(loaded), StateNormalizer.normalize(state), "Recompletion eligibility and snapshots persist")
	return true


func normalization_ignores_registry_order() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.genealogy(registry)
	var before: String = StateNormalizer.fingerprint(state)
	state.trade.lineages.reverse()
	state.trade.authorized_links.reverse()
	for lineage: TradeNetworkLineageState in state.trade.lineages:
		lineage.parent_ids.reverse()
		lineage.road_lineage_ids.reverse()
		lineage.settlement_lineage_ids.reverse()
	for event: TradeHistoryRecord in state.trade.history:
		event.parent_ids.reverse()
		event.road_lineage_ids.reverse()
		event.settlement_lineage_ids.reverse()
	expect_equal(StateNormalizer.fingerprint(state), before, "Unordered history sets normalize deterministically")
	expect_true(InvariantValidator.validate(state, registry).is_valid, "Insertion order has no invariant meaning")
	return true


func history_changes_fingerprint() -> bool:
	var state: RunState = Fixture.pair(Fixture.content())
	var before: String = StateNormalizer.fingerprint(state)
	Fixture.connect_pair(state)
	Fixture.disconnect_pair(state)
	expect_true(StateNormalizer.fingerprint(state) != before, "Same graph with split history is meaningfully different")
	return true


func _corrupt(kind: String) -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.genealogy(registry)
	var data: Dictionary = RunSerializer.to_envelope(state)
	var trade: Dictionary = data["run_state"]["trade"]
	match kind:
		"parent": trade["lineages"][-1]["parent_ids"] = [trade["lineages"][-1]["lineage_id"]]
		"membership": trade["lineages"][-1]["road_lineage_ids"] = []
		"identity": trade["lineages"][-1]["active"] = false
		"revision": trade["trade_revision"] = "-1"
		"collision": trade["lineages"][-1]["lineage_id"] = data["run_state"]["tile_copies"][0]["tile_copy_id"]
		"payment": data["run_state"]["features"]["completions"][0]["new_settlement_ids"] = ["1"]
		"snapshot": data["run_state"]["features"]["completions"][0]["network_settlement_ids"] = []
	var result: DeserializationResult = RunSerializer.deserialize(JSON.stringify(data), registry)
	expect_true(not result.validation.is_valid and result.state == null, "Malformed Trade state rejected: " + kind)
	return true


func invalid_parent_rejected() -> bool: return _corrupt("parent")
func current_membership_corruption_rejected() -> bool: return _corrupt("membership")
func missing_current_identity_rejected() -> bool: return _corrupt("identity")
func bad_revision_rejected() -> bool: return _corrupt("revision")
func bad_payment_rejected() -> bool: return _corrupt("payment")
func network_snapshot_corruption_rejected() -> bool: return _corrupt("snapshot")
func network_id_collision_rejected() -> bool: return _corrupt("collision")


func _load(state: RunState, registry: ContentRegistry) -> RunState:
	var saved: SerializationResult = RunSerializer.serialize(state, registry)
	expect_true(saved.validation.is_valid, saved.validation.user_message)
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, registry)
	expect_true(loaded.validation.is_valid, loaded.validation.user_message)
	return loaded.state


func multiple_current_networks_round_trip() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.genealogy(registry)
	Fixture.disconnect_pair(state)
	var loaded: RunState = _load(state, registry)
	if loaded == null: return true
	expect_equal(TradeNetworkService.rebuild(loaded).size(), 2, "Several current networks reconstruct alongside old merged/reconnected ancestry")
	expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Split state and historical reconnection survive exactly")
	return true


func split_origin_cannot_lose_ancestry() -> bool:
	var registry: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.genealogy(registry)
	for event: TradeHistoryRecord in state.trade.history:
		if event.kind == &"network_split":
			event.parent_ids.clear()
			state.trade.lineage(event.lineage_id).parent_ids.clear()
			break
	expect_true(not InvariantValidator.validate(state, registry).is_valid, "A split cannot become history-free by erasing parents")
	return true
