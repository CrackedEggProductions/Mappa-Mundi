extends "res://tests/framework/test_suite.gd"


func tests() -> Array[Callable]:
	return [all_templates_are_legal, setup_has_one_nine_tile_river, setup_inventory_and_provenance,
		setup_does_not_play_or_score, same_seed_reproduces_everything, seeds_vary_valid_paths,
		setup_rng_order_is_explicit, save_load_never_regenerates, old_versions_are_rejected,
		player_pools_exclude_environment, river_overlays_keep_two_copy_rewards,
		emergency_uses_junction, content_rejects_player_environment_leaks,
		content_rejects_legacy_starting_copies, environment_cannot_enter_inventory,
		environment_spine_cannot_lose_a_tile]


func _content() -> ContentRegistry:
	var content: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = content.load_phase_nine()
	assert(result.is_valid, result.user_message)
	return content


func _new(seed_value: int = 71) -> RunState:
	return HomesteadRunFactory.create(seed_value, _content())


func all_templates_are_legal() -> bool:
	var content: ContentRegistry = _content()
	var board: BoardState = BoardState.new()
	board.add_cell(BoardCellState.from_definition(content.get_tile(&"tile.founding.homestead"), 1, Vector2i.ZERO, 0, 1, 0))
	var templates: Array[Array] = EnvironmentalRiverService.templates()
	expect_equal(templates.size(), 24, "Finite template catalogue has 24 equally sampled paths")
	for entries: Array in templates:
		expect_true(EnvironmentalRiverService.valid_path(board, entries), "No collision or incompatible occupied neighbor")
		expect_equal(entries.size(), 8, "Eight environmental squares")
		var runs: int = 0
		var bends: int = 0
		for item: Dictionary in entries:
			runs += int(item["definition_id"] == &"tile.river_run")
			bends += int(item["definition_id"] == &"tile.river_bend")
		expect_equal([runs, bends], [5, 2], "Exact continuation composition")
		expect_equal(entries[0]["definition_id"], &"tile.river_run", "First continuation is Run")
		expect_equal(entries[6]["definition_id"], &"tile.river_run", "Last continuation is Run")
		expect_equal(entries[7]["definition_id"], &"tile.river_end", "Only final piece is End")
	return true


func setup_has_one_nine_tile_river() -> bool:
	var state: RunState = _new()
	var rivers: Array[CurrentFeature] = []
	for current: CurrentFeature in TopologyService.rebuild(state):
		if current.feature_type == DomainTypes.FeatureType.RIVER:
			rivers.append(current)
	expect_equal(rivers.size(), 1, "One connected spine")
	expect_equal(rivers[0].coordinates.size(), 9, "Founding plus eight environment tiles")
	expect_true(Vector2i.ZERO in rivers[0].coordinates, "Founding participates")
	expect_equal(rivers[0].open_exits, 0, "Both River ends are closed geometry, not completion state")
	expect_true(not state.features.lineage(rivers[0].lineage_id).completed, "Environmental River never completes")
	return true


func setup_inventory_and_provenance() -> bool:
	var state: RunState = _new()
	var player_ids: Array[int] = []
	var environment_ids: Array[int] = []
	for copy: TileCopyState in state.tile_copies:
		if copy.acquisition_source == &"homestead_starting_bag":
			player_ids.append(copy.tile_copy_id)
		elif copy.acquisition_source == EnvironmentalRiverService.SOURCE:
			environment_ids.append(copy.tile_copy_id)
			expect_equal(copy.acquired_act, 1, "Environment is Act-I age")
	expect_equal(player_ids.size(), 45, "Exact physical player inventory before play")
	expect_equal(environment_ids.size(), 8, "Separate setup acquisitions")
	expect_equal(state.expansion.bag.size(), 42, "Only three player tiles drawn")
	for copy_id: int in environment_ids:
		expect_true(copy_id not in player_ids and copy_id not in state.expansion.hand and copy_id not in state.expansion.bag,
			"Environmental identities never consume player inventory")
	return true


func setup_does_not_play_or_score() -> bool:
	var state: RunState = _new()
	expect_equal(state.expansion.normal_placements, 0, "Environment consumes no turn")
	expect_true(state.charters.placement_history.is_empty(), "No player placement journal")
	expect_true(state.features.completions.is_empty(), "No completion event")
	expect_equal(state.features.tracks.values, [0, 0, 0, 0], "No setup score")
	expect_true(state.rewards.milestone_flags.is_empty() and state.rewards.threshold_flags.is_empty(), "No setup rewards")
	expect_true(state.pending_choice == null and state.resolution == null, "No setup assignment or reward choices")
	return true


func same_seed_reproduces_everything() -> bool:
	var first: RunState = _new(1010)
	var second: RunState = _new(1010)
	expect_equal(EnvironmentalRiverService.path(first), EnvironmentalRiverService.path(second), "Same seed fixes physical environment")
	expect_equal(StateNormalizer.fingerprint(first), StateNormalizer.fingerprint(second), "Bag, Charter and all identities deterministic")
	return true


func seeds_vary_valid_paths() -> bool:
	var paths: Dictionary = {}
	for seed_value: int in range(32):
		var state: RunState = _new(seed_value)
		paths[JSON.stringify(EnvironmentalRiverService.path(state))] = true
		expect_true(InvariantValidator.validate(state, _content()).is_valid, "Each sampled environment is valid")
	expect_true(paths.size() > 1, "Different seeds produce distinct River layouts")
	return true


func setup_rng_order_is_explicit() -> bool:
	var state: RunState = _new(92)
	var expected: RunRNG = RunRNG.new(92)
	var template_index: int = expected.select_index(24, &"environmental_river_path")
	var ordered_ids: Array[int] = []
	for copy: TileCopyState in state.tile_copies:
		if copy.acquisition_source == &"homestead_starting_bag":
			ordered_ids.append(copy.tile_copy_id)
	var shuffled: Array[int] = expected.shuffled_ids(ordered_ids, &"starting_bag_shuffle")
	var charters: Array[StringName] = [&"charter.a1_growing_realm", &"charter.a1_living_landscape", &"charter.a1_open_roads"]
	expected.choose_definition_id(charters, &"act_charter_selection")
	expect_equal(state.rng.operation_count, 3, "Exactly River selection, bag shuffle, Charter selection")
	expect_equal(state.current_rng_state, expected.current_state, "Exact RNG order preserved")
	expect_equal(state.expansion.hand, shuffled.slice(0, 3), "Opening draw follows Charter and consumes no RNG")
	expect_equal(EnvironmentalRiverService.path(state)[0]["rotation"], EnvironmentalRiverService.templates()[template_index][0]["rotation"], "Selected River precedes shuffle")
	return true


func save_load_never_regenerates() -> bool:
	var content: ContentRegistry = _content()
	var state: RunState = HomesteadRunFactory.create(810, content)
	var expected: String = StateNormalizer.fingerprint(state)
	var river: Array[Dictionary] = EnvironmentalRiverService.path(state)
	for iteration: int in range(3):
		var saved: SerializationResult = RunSerializer.serialize(state, content)
		expect_true(saved.validation.is_valid, saved.validation.user_message)
		var loaded: DeserializationResult = RunSerializer.deserialize(saved.json_text, content)
		expect_true(loaded.validation.is_valid, loaded.validation.user_message)
		state = loaded.state
		expect_equal(EnvironmentalRiverService.path(state), river, "Exact physical path survives save/load")
		expect_equal(StateNormalizer.fingerprint(state), expected, "No replay, RNG, scoring or identity changes")
	return true


func old_versions_are_rejected() -> bool:
	var state: RunState = _new()
	var envelope: Dictionary = RunSerializer.to_envelope(state)
	envelope["game_rules_version"] = "alpha-1"
	var result: DeserializationResult = RunSerializer.deserialize(JSON.stringify(envelope), _content())
	expect_equal(result.validation.error_code, &"incompatible_version", "Old active-run rules rejected clearly")
	envelope = RunSerializer.to_envelope(state)
	envelope["save_schema_version"] = 1
	result = RunSerializer.deserialize(JSON.stringify(envelope), _content())
	expect_equal(result.validation.error_code, &"incompatible_version", "Old shape rejected without migration")
	return true


func player_pools_exclude_environment() -> bool:
	var content: ContentRegistry = _content()
	var act_one: Array[StringName] = RewardRules.tile_pool(content, 1)
	expect_equal(act_one.size(), 20, "Sixteen player starting designs plus four ordinary Act-I Developments")
	for entry: StartingBagEntry in content.get_config().starting_bag:
		expect_true(entry.definition_id in act_one, "Every starting player design is reward eligible")
	for id: StringName in [&"tile.development.housing", &"tile.development.mill", &"tile.development.monastery", &"tile.development.foresters_lodge"]:
		expect_true(id in act_one, "Each canonical Act-I Development is available")
	for act: int in range(1, 4):
		for masterwork: bool in [false, true]:
			var pool: Array[StringName] = RewardRules.tile_pool(content, act, masterwork)
			for definition_id: StringName in HomesteadContentValidator.NON_PLAYER_IDS:
				expect_true(definition_id not in pool, "Non-player definition excluded at every Act")
			expect_true(&"tile.riverside_hamlet" in pool and &"tile.woodland_river" in pool, "River overlays remain eligible")
	return true


func river_overlays_keep_two_copy_rewards() -> bool:
	var content: ContentRegistry = _content()
	for definition_id: StringName in HomesteadContentValidator.RIVER_OVERLAY_IDS:
		var tile: TileDefinition = content.get_tile(definition_id)
		expect_equal(tile.tile_class, DomainTypes.TileClass.TRANSFORMATION, "Occupied-target interaction classification")
		expect_equal(RewardRules.copy_quantity(tile), 2, "Specialized normal reward grants two copies")
		expect_true(RewardRules.masterwork_eligible(tile), "Specialized Masterwork remains legal")
	return true


func emergency_uses_junction() -> bool:
	var config: RunConfig = _content().get_config()
	expect_equal(config.emergency_definitions, [&"tile.forest_edge", &"tile.hamlet_edge", &"tile.road_junction"], "Canonical three-design emergency set")
	return true


func content_rejects_player_environment_leaks() -> bool:
	var config: RunConfig = _content().get_config()
	for definition_id: StringName in HomesteadContentValidator.NON_PLAYER_IDS:
		var manifest: ContentManifest = (load(ContentRegistry.PHASE_NINE_MANIFEST_PATH) as ContentManifest).duplicate(true)
		for tile: TileDefinition in manifest.tiles:
			if tile.definition_id == definition_id:
				tile.player_drawable = true
		expect_true(not ContentValidator.validate(manifest, config).is_valid, "Invalid pool flag fails loudly")
		for tile: TileDefinition in manifest.tiles:
			if tile.definition_id == definition_id:
				tile.player_drawable = false
	return true


func content_rejects_legacy_starting_copies() -> bool:
	var manifest: ContentManifest = load(ContentRegistry.PHASE_NINE_MANIFEST_PATH)
	for definition_id: StringName in HomesteadContentValidator.NON_PLAYER_IDS:
		var config: RunConfig = _content().get_config()
		config.starting_bag[0].definition_id = definition_id
		expect_true(not ContentValidator.validate(manifest, config).is_valid, "Removed/setup designs cannot enter starting manifest")
	return true


func environment_cannot_enter_inventory() -> bool:
	var state: RunState = _new()
	var copy_id: int = EnvironmentalRiverService.path(state)[0]["tile_copy_id"]
	state.expansion.bag.append(copy_id)
	expect_true(not InvariantValidator.validate(state, _content()).is_valid, "Environmental physical tile cannot be player inventory")
	return true


func environment_spine_cannot_lose_a_tile() -> bool:
	var state: RunState = _new()
	var entry: Dictionary = EnvironmentalRiverService.path(state)[0]
	state.expansion.board.cells.erase(Vector2i(entry["coordinate"][0], entry["coordinate"][1]))
	expect_true(not InvariantValidator.validate(state, _content()).is_valid, "Every setup tile must remain represented")
	return true
