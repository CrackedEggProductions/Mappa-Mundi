extends "res://tests/framework/test_suite.gd"


func tests() -> Array[Callable]:
	return [canonical_ten_relics, canonical_tiers, passive_relic_copies,
		missing_relic_rejected, deferred_relic_rejected, duplicate_relic_rejected,
		wrong_behavior_rejected, wrong_tier_rejected, wrong_use_metadata_rejected,
		phase_seven_preserved, new_run_empty_relics, fresh_round_trip,
		acquired_round_trip, replaced_round_trip, consumed_use_round_trip,
		repeated_load_is_inert, full_width_identity_round_trip, relic_registry_normalizes,
		malformed_relic_shape_rejected, malformed_reward_shape_rejected,
		duplicate_relic_rejected_in_save, illegal_slot_rejected, bad_capacity_rejected,
		bad_use_state_rejected, missing_replacement_history_rejected,
		bad_threshold_flag_rejected, duplicate_threshold_flag_rejected,
		bad_milestone_flag_rejected, unknown_queue_job_rejected,
		tile_offer_round_trip, forged_tile_offer_rejected, missing_threshold_flag_rejected,
		missing_milestone_flag_rejected, incomplete_queue_job_rejected, forged_acquisition_rejected,
		forged_use_recharge_rejected, duplicate_threshold_history_rejected,
		malformed_nested_feature_rejected, malformed_relic_geometry_rejected,
		malformed_specialist_snapshot_rejected]


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	expect_true(content.load_phase_eight().is_valid, "Phase-8 canonical content loads")
	return content


func _state(content: ContentRegistry) -> RunState:
	return HomesteadRunFactory.create(808, content)


func _definitions(content: ContentRegistry) -> Array[RelicDefinition]:
	var values: Array[RelicDefinition] = []
	for id: StringName in content.get_relic_ids():
		values.append(content.get_relic(id))
	return values


func _round_trip(state: RunState, content: ContentRegistry) -> RunState:
	var saved: SerializationResult = RunSerializer.serialize(state, content)
	expect_true(saved.validation.is_valid, str(saved.validation.debug_details))
	if not saved.validation.is_valid:
		return null
	var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
	expect_true(loaded.validation.is_valid, str(loaded.validation.debug_details))
	if loaded.state != null:
		expect_equal(StateNormalizer.fingerprint(loaded.state), StateNormalizer.fingerprint(state), "Lossless authoritative state")
	return loaded.state


func _reject(state: RunState, content: ContentRegistry) -> void:
	var result: DeserializationResult = RunSerializer.deserialize(JSON.stringify(RunSerializer.to_envelope(state)), content)
	expect_true(not result.validation.is_valid and result.state == null, "Invalid snapshot rejected before use")


func canonical_ten_relics() -> bool:
	var content: ContentRegistry = _content()
	expect_equal(content.get_relic_ids().size(), 10, "Exactly reduced alpha roster")
	for id: StringName in RelicContentValidator.ROSTER:
		expect_true(id in content.get_relic_ids(), "Canonical role " + String(id))
	return true


func canonical_tiers() -> bool:
	var content: ContentRegistry = _content()
	var counts: Array[int] = [0, 0, 0]
	for definition: RelicDefinition in _definitions(content):
		counts[definition.unlock_act - 1] += 1
	expect_equal(counts, [5, 3, 2], "Foundational/Developed/Legacy reduced pool")
	return true


func passive_relic_copies() -> bool:
	var content: ContentRegistry = _content()
	var definition: RelicDefinition = content.get_relic(&"relic.boundary_stones")
	definition.behavior_id = &"modified"
	expect_equal(content.get_relic(&"relic.boundary_stones").behavior_id, &"boundary_stones", "Consumers cannot mutate registry content")
	return true


func missing_relic_rejected() -> bool:
	var definitions: Array[RelicDefinition] = _definitions(_content())
	definitions.pop_back()
	expect_true(not RelicContentValidator.validate(definitions).is_valid, "Missing required Relic rejected")
	return true


func deferred_relic_rejected() -> bool:
	var definitions: Array[RelicDefinition] = _definitions(_content())
	definitions[0].definition_id = &"relic.roadside_inns"
	expect_true(not RelicContentValidator.validate(definitions).is_valid, "Prototype Relic excluded")
	return true


func duplicate_relic_rejected() -> bool:
	var definitions: Array[RelicDefinition] = _definitions(_content())
	definitions[1] = definitions[0]
	expect_true(not RelicContentValidator.validate(definitions).is_valid, "Duplicate definition rejected")
	return true


func wrong_behavior_rejected() -> bool:
	var definitions: Array[RelicDefinition] = _definitions(_content())
	definitions[0].behavior_id = &"prototype_behavior"
	expect_true(not RelicContentValidator.validate(definitions).is_valid, "Unknown behavior rejected")
	return true


func wrong_tier_rejected() -> bool:
	var definitions: Array[RelicDefinition] = _definitions(_content())
	definitions[0].tier = &"legacy"
	expect_true(not RelicContentValidator.validate(definitions).is_valid, "Wrong tier rejected")
	return true


func wrong_use_metadata_rejected() -> bool:
	var definitions: Array[RelicDefinition] = _definitions(_content())
	definitions[0].once_per_act = not definitions[0].once_per_act
	expect_true(not RelicContentValidator.validate(definitions).is_valid, "Use metadata is canonical passive content")
	return true


func phase_seven_preserved() -> bool:
	var content: ContentRegistry = ContentRegistry.new()
	expect_true(content.load_phase_seven().is_valid, "Legacy profile remains supported")
	var state: RunState = _state(content)
	expect_true(state.relics == null and state.rewards == null, "Legacy runs do not unexpectedly activate rewards")
	return true


func new_run_empty_relics() -> bool:
	var state: RunState = _state(_content())
	expect_equal(state.relics.capacity, 2, "Act-I capacity")
	expect_true(state.relics.instances.is_empty(), "No starting Relics")
	expect_true(state.rewards.queue.is_empty(), "No phantom starting rewards")
	return true


func fresh_round_trip() -> bool:
	var content: ContentRegistry = _content()
	_round_trip(_state(content), content)
	return true


func _acquired(content: ContentRegistry) -> RunState:
	var state: RunState = _state(content)
	expect_true(RelicRules.acquire(state, content, &"relic.boundary_stones").is_valid, "Acquire canonical Relic")
	return state


func acquired_round_trip() -> bool:
	var content: ContentRegistry = _content()
	_round_trip(_acquired(content), content)
	return true


func replaced_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _acquired(content)
	expect_true(RelicRules.acquire(state, content, &"relic.village_green").is_valid, "Fill remaining slot")
	expect_true(RelicRules.acquire(state, content, &"relic.wayfarers_satchel", &"relic.boundary_stones").is_valid, "Replace without inventory")
	var restored: RunState = _round_trip(state, content)
	if restored != null:
		expect_equal(restored.relics.instances.size(), 3, "Replaced history retained")
		expect_true(&"relic.boundary_stones" not in RelicRules.eligible_ids(restored, content), "Replaced remains exhausted")
	return true


func consumed_use_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _acquired(content)
	expect_true(RelicRules.consume_use(state, &"relic.boundary_stones").is_valid, "Consume current-Act use")
	_round_trip(state, content)
	return true


func repeated_load_is_inert() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _acquired(content)
	var original: String = StateNormalizer.fingerprint(state)
	for index: int in range(3):
		state = _round_trip(state, content)
		if state == null:
			return true
		expect_equal(StateNormalizer.fingerprint(state), original, "Load creates no effects, events, allocations or RNG")
	return true


func full_width_identity_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.id_allocator = RunIdAllocator.new(9223372036854770000)
	expect_true(RelicRules.acquire(state, content, &"relic.boundary_stones").is_valid, "Acquire high-ID instance")
	var restored: RunState = _round_trip(state, content)
	if restored != null:
		expect_equal(restored.relics.instances[0].runtime_id, 9223372036854770000, "No JSON numeric precision loss")
	return true


func relic_registry_normalizes() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _acquired(content)
	RelicRules.acquire(state, content, &"relic.village_green")
	var original: String = StateNormalizer.fingerprint(state)
	state.relics.instances.reverse()
	expect_equal(StateNormalizer.fingerprint(state), original, "Registry iteration order has no meaning; acquisition order does")
	return true


func malformed_relic_shape_rejected() -> bool:
	var content: ContentRegistry = _content()
	var envelope: Dictionary = RunSerializer.to_envelope(_acquired(content))
	var data: Dictionary = SpecialistValueCodec.decode(envelope["run_state"]["relics"])
	data["instances"][0]["runtime_id"] = 1.5
	envelope["run_state"]["relics"] = SpecialistValueCodec.encode(data)
	expect_true(not RunSerializer.deserialize(JSON.stringify(envelope), content).validation.is_valid, "Float identities rejected before typed assignment")
	return true


func malformed_reward_shape_rejected() -> bool:
	var content: ContentRegistry = _content()
	var envelope: Dictionary = RunSerializer.to_envelope(_state(content))
	envelope["run_state"]["rewards"] = SpecialistValueCodec.encode({"queue": []})
	expect_true(not RunSerializer.deserialize(JSON.stringify(envelope), content).validation.is_valid, "Incomplete reward state rejected")
	return true


func duplicate_relic_rejected_in_save() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _acquired(content)
	state.relics.instances.append(state.relics.instances[0])
	_reject(state, content)
	return true


func illegal_slot_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _acquired(content)
	state.relics.instances[0].equipped_slot = 2
	_reject(state, content)
	return true


func bad_capacity_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.relics.capacity = 5
	_reject(state, content)
	return true


func bad_use_state_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _acquired(content)
	state.relics.instances[0].uses_remaining = 2
	_reject(state, content)
	return true


func missing_replacement_history_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _acquired(content)
	state.relics.instances[0].equipped_slot = -1
	_reject(state, content)
	return true


func bad_threshold_flag_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.rewards.threshold_flags.append("0:30")
	_reject(state, content)
	return true


func duplicate_threshold_flag_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.rewards.threshold_flags.assign(["0:20", "0:20"])
	_reject(state, content)
	return true


func bad_milestone_flag_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.rewards.milestone_flags.append(&"monastery")
	_reject(state, content)
	return true


func unknown_queue_job_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.rewards.queue.append({"kind": "prototype_charter_reward", "eligibility_act": 1})
	_reject(state, content)
	return true


func _offered(content: ContentRegistry) -> RunState:
	var state: RunState = _state(content)
	state.resolution = ResolutionState.new()
	state.resolution.stage = &"reward_queue"
	state.resolution.context["mode"] = "reward"
	RewardRules.enqueue(state, &"tile_reward")
	RewardRules.advance(state, content)
	return state


func tile_offer_round_trip() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _offered(content)
	var restored: RunState = _round_trip(state, content)
	if restored != null:
		expect_equal(restored.pending_choice.options, state.pending_choice.options, "Persisted choices never reroll")
	return true


func forged_tile_offer_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _offered(content)
	state.pending_choice.options[0]["definition_id"] = "tile.development.grand_market"
	_reject(state, content)
	return true


func missing_threshold_flag_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	RewardRules.record(state, &"track_threshold_crossed", {"track": 0, "threshold": 20})
	_reject(state, content)
	return true


func missing_milestone_flag_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	RewardRules.record(state, &"milestone_earned", {"milestone": "settlement", "lineage_id": state.features.lineages[0].lineage_id})
	_reject(state, content)
	return true


func incomplete_queue_job_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.resolution = ResolutionState.new()
	state.resolution.stage = &"reward_queue"
	state.resolution.context["mode"] = "reward"
	state.rewards.queue.append({"kind": "tile_reward"})
	_reject(state, content)
	return true


func forged_acquisition_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _acquired(content)
	state.relics.history.clear()
	_reject(state, content)
	return true


func forged_use_recharge_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _acquired(content)
	RelicRules.consume_use(state, &"relic.boundary_stones")
	state.relics.instances[0].uses_remaining = 1
	_reject(state, content)
	return true


func duplicate_threshold_history_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _state(content)
	state.rewards.threshold_flags.append("0:20")
	for index: int in range(2):
		RewardRules.record(state, &"track_threshold_crossed", {"track": 0, "threshold": 20})
	_reject(state, content)
	return true


func malformed_nested_feature_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _offered(content)
	state.resolution.completion_snapshot = FeatureScoringService.capture(state, TopologyService.rebuild(state)).data()
	state.resolution.completion_snapshot["features"].append({"lineage_id": state.features.lineages[0].lineage_id,
		"new_component_ids": "malformed nested collection"})
	_reject(state, content)
	return true


func malformed_relic_geometry_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _offered(content)
	state.resolution.completion_snapshot = FeatureScoringService.capture(state, TopologyService.rebuild(state)).data()
	state.resolution.completion_snapshot["relics"]["feature_facts"] = ["not a dictionary"]
	_reject(state, content)
	return true


func malformed_specialist_snapshot_rejected() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = _offered(content)
	state.resolution.completion_snapshot = FeatureScoringService.capture(state, TopologyService.rebuild(state)).data()
	state.resolution.completion_snapshot["specialists"].append({"piece_id": state.specialists.pieces[0].piece_id,
		"target_type": 999, "growth_count": {"not": "a count"}})
	_reject(state, content)
	return true
