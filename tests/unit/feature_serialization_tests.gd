extends "res://tests/framework/test_suite.gd"

const Fixture = preload("res://tests/fixtures/phase_three_factory.gd")
const Scenarios = preload("res://tests/integration/feature_scenario_tests.gd")


func tests() -> Array[Callable]:
	return [phase_three_round_trip_preserves_history_and_topology,
		repeated_load_never_scores_allocates_or_consumes_rng,
		loaded_rng_and_id_continuation_match, normalization_ignores_feature_registry_order,
		rejects_missing_feature_fields, rejects_duplicate_runtime_identity,
		rejects_invalid_component_type_and_origin, rejects_dangling_component_lineage,
		rejects_ancestry_cycle, rejects_active_merged_parent,
		rejects_missing_current_component, rejects_wrong_completion_status,
		rejects_unresolved_scoring_history, rejects_erased_scoring_history,
		rejects_duplicate_support_history, rejects_invalid_completion_reference,
		rejects_track_corruption, rejects_negative_track_encoding,
		rejects_topology_revision_mismatch, rejects_fake_network_history,
		rejects_invalid_enclosure_host, rejects_replayed_completion,
		loaded_reopened_feature_scores_only_new_growth]


func phase_three_round_trip_preserves_history_and_topology() -> bool:
	var content: ContentRegistry = Fixture.content()
	var original: RunState = _representative(content)
	var saved: SerializationResult = RunSerializer.serialize(original, content)
	expect_true(saved.validation.is_valid, saved.validation.user_message)
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	expect_true(loaded.validation.is_valid, loaded.validation.user_message)
	if loaded.state != null:
		expect_equal(ExpansionSerializer.encode(loaded.state.expansion), ExpansionSerializer.encode(original.expansion), "Physical board and all ordered zones exact")
		expect_equal(FeatureSerializer.encode(loaded.state.features), FeatureSerializer.encode(original.features), "Components, origins, lineages, ancestry, history, Tracks, enclosure exact")
		expect_equal(_topology(loaded.state), _topology(original), "Current topology reconstructs identically")
		expect_equal(StateNormalizer.fingerprint(loaded.state), StateNormalizer.fingerprint(original), "Phase-3 fingerprint exact")
		expect_true(InvariantValidator.validate(loaded.state, content).is_valid, "Loaded feature invariants")
		loaded.state.features.components[0].origin_act = 3
		expect_equal(original.features.components[0].origin_act, 1, "Fresh objects do not alias original")
	return true


func repeated_load_never_scores_allocates_or_consumes_rng() -> bool:
	var content: ContentRegistry = Fixture.content()
	var original: RunState = _representative(content)
	var saved: SerializationResult = RunSerializer.serialize(original, content)
	for repetition: int in range(5):
		var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
		expect_true(loaded.validation.is_valid, loaded.validation.user_message)
		if loaded.state == null:
			return true
		expect_equal(loaded.state.features.completions.size(), original.features.completions.size(), "Load creates no completion")
		expect_equal(loaded.state.features.history.size(), original.features.history.size(), "Load creates no event")
		expect_equal(loaded.state.features.tracks.values, original.features.tracks.values, "Load produces zero Track gain")
		expect_equal(loaded.state.current_rng_state, original.current_rng_state, "Load consumes no RNG")
		expect_equal(loaded.state.next_runtime_id, original.next_runtime_id, "Load allocates no replacement lineage IDs")
		expect_equal(StateNormalizer.fingerprint(loaded.state), StateNormalizer.fingerprint(original), "Repeated load is observationally identical")
	return true


func loaded_rng_and_id_continuation_match() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = _representative(content)
	var loaded: RunState = RunSerializer.deserialize(RunSerializer.serialize(state, content).json_text, content).state
	for index: int in range(10):
		expect_equal(loaded.rng.select_index(1000), state.rng.select_index(1000), "Exact future RNG continuation")
		expect_equal(loaded.id_allocator.allocate(), state.id_allocator.allocate(), "Exact future runtime IDs")
	expect_equal(StateNormalizer.fingerprint(loaded), StateNormalizer.fingerprint(state), "Continuation fingerprints identical")
	return true


func normalization_ignores_feature_registry_order() -> bool:
	var state: RunState = _representative(Fixture.content())
	var before: String = StateNormalizer.fingerprint(state)
	state.features.components.reverse()
	state.features.lineages.reverse()
	for lineage: FeatureLineageState in state.features.lineages:
		lineage.member_ids.reverse()
		lineage.parent_ids.reverse()
		lineage.scored_component_ids.reverse()
		lineage.completion_ids.reverse()
	expect_equal(StateNormalizer.fingerprint(state), before, "Unordered component/lineage/history sets normalize")
	return true


func rejects_missing_feature_fields() -> bool:
	var data: Dictionary = _envelope()
	data["run_state"]["features"].erase("components")
	_rejected(data, "Missing components rejected")
	data = _envelope()
	data["run_state"]["features"]["unexpected"] = 1
	_rejected(data, "Unknown feature field rejected")
	return true


func rejects_duplicate_runtime_identity() -> bool:
	var data: Dictionary = _envelope()
	data["run_state"]["features"]["components"][0]["component_id"] = data["run_state"]["tile_copies"][0]["tile_copy_id"]
	_rejected(data, "Component cannot collide with physical base")
	return true


func rejects_invalid_component_type_and_origin() -> bool:
	var data: Dictionary = _envelope()
	data["run_state"]["features"]["components"][0]["feature_type"] = 5
	_rejected(data, "Invalid feature type")
	data = _envelope()
	data["run_state"]["features"]["components"][0]["origin_source_runtime_id"] = "900000"
	_rejected(data, "Origin must resolve")
	return true


func rejects_dangling_component_lineage() -> bool:
	var data: Dictionary = _envelope()
	data["run_state"]["features"]["components"][0]["lineage_id"] = "900000"
	_rejected(data, "Current component requires valid lineage")
	return true


func rejects_ancestry_cycle() -> bool:
	var data: Dictionary = _envelope()
	var lineage: Dictionary = data["run_state"]["features"]["lineages"][0]
	lineage["parent_ids"] = [lineage["lineage_id"]]
	_rejected(data, "Self ancestry is invalid")
	return true


func rejects_active_merged_parent() -> bool:
	var data: Dictionary = _envelope()
	for lineage: Dictionary in data["run_state"]["features"]["lineages"]:
		if not lineage["active"]:
			lineage["active"] = true
			break
	_rejected(data, "Inactive parent must not become current")
	return true


func rejects_missing_current_component() -> bool:
	var data: Dictionary = _envelope()
	data["run_state"]["features"]["components"].pop_back()
	_rejected(data, "Tracked geometry must have a component")
	return true


func rejects_wrong_completion_status() -> bool:
	var data: Dictionary = _envelope()
	for lineage: Dictionary in data["run_state"]["features"]["lineages"]:
		if lineage["active"]:
			lineage["completed"] = not lineage["completed"]
			break
	_rejected(data, "Current completion must agree with exits")
	return true


func rejects_unresolved_scoring_history() -> bool:
	var data: Dictionary = _envelope()
	data["run_state"]["features"]["lineages"][0]["scored_component_ids"] = ["900000"]
	_rejected(data, "Scored identities must resolve")
	return true


func rejects_erased_scoring_history() -> bool:
	var data: Dictionary = _envelope()
	for lineage: Dictionary in data["run_state"]["features"]["lineages"]:
		if not lineage["scored_component_ids"].is_empty():
			lineage["scored_component_ids"] = []
			break
	_rejected(data, "Erasing historical eligibility cannot make components pay twice")
	return true


func rejects_duplicate_support_history() -> bool:
	var content: ContentRegistry = Fixture.content()
	var state: RunState = Fixture.create(content)
	Fixture.add(state, content, &"tile.hamlet_edge", Vector2i.UP, 2)
	var data: Dictionary = RunSerializer.to_envelope(state)
	for lineage: Dictionary in data["run_state"]["features"]["lineages"]:
		if not lineage["scored_field_ids"].is_empty():
			lineage["scored_field_ids"].append(lineage["scored_field_ids"][0])
			break
	_rejected(data, "Support sets cannot duplicate an identity")
	return true


func rejects_invalid_completion_reference() -> bool:
	var data: Dictionary = _envelope()
	data["run_state"]["features"]["completions"][0]["snapshot_id"] = "900000"
	_rejected(data, "Completion must resolve shared snapshot event")
	return true


func rejects_track_corruption() -> bool:
	var data: Dictionary = _envelope()
	data["run_state"]["features"]["tracks"][0] = "1"
	_rejected(data, "Unrecorded Track gain rejected")
	return true


func rejects_negative_track_encoding() -> bool:
	var data: Dictionary = _envelope()
	data["run_state"]["features"]["tracks"][0] = "-1"
	_rejected(data, "Negative cumulative Track rejected")
	return true


func rejects_topology_revision_mismatch() -> bool:
	var data: Dictionary = _envelope()
	data["run_state"]["features"]["topology_revision"] = "0"
	_rejected(data, "Stale reconstructed topology rejected")
	return true


func rejects_fake_network_history() -> bool:
	var data: Dictionary = _envelope()
	data["run_state"]["features"]["lineages"][0]["scored_settlement_ids"] = ["1"]
	_rejected(data, "Phase-4 scoring history cannot be populated early")
	return true


func rejects_invalid_enclosure_host() -> bool:
	var data: Dictionary = _envelope()
	data["run_state"]["features"]["enclosures"][0]["coordinate"] = [1000, -1000]
	_rejected(data, "Enclosure host must be occupied")
	return true


func rejects_replayed_completion() -> bool:
	var data: Dictionary = _envelope()
	data["run_state"]["features"]["completions"].append(data["run_state"]["features"]["completions"][0].duplicate(true))
	_rejected(data, "Duplicate historical completion rejected")
	return true


func loaded_reopened_feature_scores_only_new_growth() -> bool:
	var content: ContentRegistry = Fixture.content()
	var original: RunState = Fixture.create(content)
	Fixture.add(original, content, &"tile.hamlet_edge", Vector2i.UP, 2)
	expect_true(Fixture.rewrite(original, content, Vector2i.UP, [4, 0, 4, 0]).is_valid, "Reopened Settlement valid before save")
	var loaded: DeserializationResult = RunSerializer.deserialize(RunSerializer.serialize(original, content).json_text, content)
	expect_true(loaded.validation.is_valid, loaded.validation.user_message)
	if loaded.state != null:
		Fixture.add(original, content, &"tile.hamlet_edge", Vector2i(0, -2), 2)
		Fixture.add(loaded.state, content, &"tile.hamlet_edge", Vector2i(0, -2), 2)
		expect_equal(loaded.state.features.tracks.values[0], 8, "Loaded re-completion only pays new growth/support")
		expect_equal(StateNormalizer.fingerprint(loaded.state), StateNormalizer.fingerprint(original), "Reopening history survives continuing play")
	return true


func _representative(content: ContentRegistry) -> RunState:
	var scenarios: RefCounted = Scenarios.new()
	var state: RunState = scenarios._merge_fixture(content, true)
	Fixture.add_monastery(state, content, Vector2i.ZERO)
	expect_true(RulesEngine.execute(state, content, ReserveTileCommand.new(state.expansion.hand[0])).is_valid, "Fixture Reserve")
	expect_true(RulesEngine.execute(state, content, SurveyTileCommand.new(state.expansion.hand[1])).is_valid, "Fixture Survey")
	return state


func _envelope() -> Dictionary:
	return RunSerializer.to_envelope(_representative(Fixture.content()))


func _rejected(data: Dictionary, message: String) -> void:
	var result: DeserializationResult = RunSerializer.deserialize(JSON.stringify(data), Fixture.content())
	expect_true(not result.validation.is_valid, message)
	expect_true(result.state == null, "Rejected save never publishes state")


func _topology(state: RunState) -> Array[String]:
	var result: Array[String] = []
	for feature: CurrentFeature in TopologyService.rebuild(state):
		result.append(str([feature.feature_type, feature.component_ids, feature.coordinates, feature.open_exits, feature.lineage_id]))
	return result
