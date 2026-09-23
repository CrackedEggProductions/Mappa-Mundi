extends "res://tests/framework/test_suite.gd"


func tests() -> Array[Callable]:
	return [
		loads_phase_five_roster, housing_metadata, mill_metadata, monastery_metadata,
		foresters_lodge_metadata, market_metadata, port_metadata, town_square_metadata,
		abbey_metadata, grand_market_metadata, preserves_fifty_five_expansion_bag,
		developments_are_edge_neutral, registry_owns_development_metadata,
		rejects_missing_development, rejects_unknown_development,
		rejects_wrong_family, rejects_wrong_host, rejects_wrong_unlock_act,
		rejects_wrong_prerequisite, rejects_wrong_class, rejects_wrong_reward_class,
		rejects_wrong_reward_quantity, rejects_missing_presentation_hook,
		rejects_development_geometry, rejects_development_starting_bag_entry,
		rejects_unregistered_development_behavior,
	]


func _manifest() -> ContentManifest:
	return (load(ContentRegistry.PHASE_FIVE_MANIFEST_PATH) as ContentManifest).duplicate(true) as ContentManifest


func _config() -> RunConfig:
	return (load(ContentRegistry.HOMESTEAD_CONFIG_PATH) as RunConfig).duplicate(true) as RunConfig


func _definition(stage: String) -> TileDefinition:
	return (load("res://content/tiles/developments/%s.tres" % stage) as TileDefinition).duplicate(true) as TileDefinition


func _metadata(stage: String, family: String, host: String, act: int, prerequisite: String = "") -> bool:
	var tile: TileDefinition = _definition(stage)
	expect_equal(tile.definition_id, StringName("tile.development." + stage), "Stable design identity")
	expect_equal(tile.development_stage, StringName(stage), "Stage is explicit metadata")
	expect_equal(tile.development_family_id, StringName("family." + family), "Family survives an Upgrade")
	expect_equal(tile.development_host_kind, StringName(host), "Canonical specific host kind")
	expect_equal(tile.unlock_act, act, "Canonical unlock Act")
	expect_equal(tile.tile_class, DomainTypes.TileClass.DEVELOPMENT if prerequisite.is_empty()
		else DomainTypes.TileClass.UPGRADE, "Physical tile class")
	expect_equal(tile.upgrade_from_definition_id, &"" if prerequisite.is_empty()
		else StringName("tile.development." + prerequisite), "Exact Upgrade prerequisite")
	expect_equal(tile.reward_class, DomainTypes.RewardClass.MAJOR_RARE if stage == "grand_market"
		else DomainTypes.RewardClass.ORDINARY_DEVELOPMENT, "Passive future reward class")
	expect_equal(tile.normal_reward_copy_count, 1 if stage == "grand_market" else 2, "Canonical future reward quantity")
	expect_equal(tile.presentation_id, StringName("overlay." + stage), "Stage-specific overlay hook")
	expect_true(ContentValidator.validate_development(tile).is_valid, "Canonical content validates")
	return true


func loads_phase_five_roster() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = registry.load_phase_five()
	expect_true(result.is_valid, result.user_message)
	expect_equal(registry.get_tile_ids().size(), 31, "22 existing designs plus nine Developments/Upgrades")
	return true


func housing_metadata() -> bool:
	return _metadata("housing", "housing", "settlement", 1)


func mill_metadata() -> bool:
	return _metadata("mill", "mill", "field", 1)


func monastery_metadata() -> bool:
	return _metadata("monastery", "monastery", "enclosure", 1)


func foresters_lodge_metadata() -> bool:
	return _metadata("foresters_lodge", "foresters_lodge", "forest", 1)


func market_metadata() -> bool:
	return _metadata("market", "market", "settlement", 2)


func port_metadata() -> bool:
	return _metadata("port", "port", "settlement", 2)


func town_square_metadata() -> bool:
	return _metadata("town_square", "town_square", "settlement", 2)


func abbey_metadata() -> bool:
	return _metadata("abbey", "monastery", "enclosure", 2, "monastery")


func grand_market_metadata() -> bool:
	return _metadata("grand_market", "market", "settlement", 3, "market")


func preserves_fifty_five_expansion_bag() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	expect_true(registry.load_phase_five().is_valid, "Phase-5 profile loads")
	var count: int = 0
	for entry: StartingBagEntry in registry.get_config().starting_bag:
		count += entry.count
		expect_equal(registry.get_tile(entry.definition_id).tile_class,
			DomainTypes.TileClass.EXPANSION, "Starting bag remains Expansion-only")
	expect_equal(count, 55, "Content expansion never seeds copies into starting bag")
	return true


func developments_are_edge_neutral() -> bool:
	for tile: TileDefinition in _manifest().tiles:
		if tile.tile_class == DomainTypes.TileClass.EXPANSION:
			continue
		expect_true(tile.canonical_edges.is_empty(), "Overlay carries no N/E/S/W edge geometry")
		expect_true(tile.feature_groups.is_empty(), "Overlay does not create base feature components")
		expect_true(tile.relationships.is_empty(), "Overlay does not rewrite base relationships")
	return true


func registry_owns_development_metadata() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	expect_true(registry.load_phase_five().is_valid, "Profile loads")
	var market: TileDefinition = registry.get_tile(&"tile.development.grand_market")
	market.development_family_id = &"changed"
	expect_equal(registry.get_tile(market.definition_id).development_family_id, &"family.market",
		"Callers cannot mutate shared static metadata")
	return true


func rejects_missing_development() -> bool:
	var manifest: ContentManifest = _manifest()
	manifest.tiles.pop_back()
	expect_true(not ContentValidator.validate(manifest, _config()).is_valid, "Full Phase-5 roster is required")
	return true


func rejects_unknown_development() -> bool:
	var tile: TileDefinition = _definition("housing")
	tile.definition_id = &"tile.development.unknown"
	expect_true(not ContentValidator.validate_development(tile).is_valid, "Unknown IDs rejected")
	return true


func rejects_wrong_family() -> bool:
	var tile: TileDefinition = _definition("abbey")
	tile.development_family_id = &"family.abbey"
	expect_true(not ContentValidator.validate_development(tile).is_valid, "Abbey remains Monastery family")
	return true


func rejects_wrong_host() -> bool:
	var tile: TileDefinition = _definition("mill")
	tile.development_host_kind = &"settlement"
	expect_true(not ContentValidator.validate_development(tile).is_valid, "Mill cannot bind one Settlement")
	return true


func rejects_wrong_unlock_act() -> bool:
	var tile: TileDefinition = _definition("market")
	tile.unlock_act = 1
	expect_true(not ContentValidator.validate_development(tile).is_valid, "Market requires Act II metadata")
	return true


func rejects_wrong_prerequisite() -> bool:
	var tile: TileDefinition = _definition("grand_market")
	tile.upgrade_from_definition_id = &"tile.development.housing"
	expect_true(not ContentValidator.validate_development(tile).is_valid, "Grand Market upgrades only Market")
	return true


func rejects_wrong_class() -> bool:
	var tile: TileDefinition = _definition("abbey")
	tile.tile_class = DomainTypes.TileClass.DEVELOPMENT
	expect_true(not ContentValidator.validate_development(tile).is_valid, "Abbey is an Upgrade")
	return true


func rejects_wrong_reward_class() -> bool:
	var tile: TileDefinition = _definition("grand_market")
	tile.reward_class = DomainTypes.RewardClass.ORDINARY_DEVELOPMENT
	expect_true(not ContentValidator.validate_development(tile).is_valid, "Grand Market is Major/Rare")
	return true


func rejects_wrong_reward_quantity() -> bool:
	var tile: TileDefinition = _definition("grand_market")
	tile.normal_reward_copy_count = 2
	expect_true(not ContentValidator.validate_development(tile).is_valid, "Normal reward differs from later automatic seeding")
	return true


func rejects_missing_presentation_hook() -> bool:
	var tile: TileDefinition = _definition("monastery")
	tile.presentation_id = &""
	expect_true(not ContentValidator.validate_development(tile).is_valid, "Presentation can resolve each overlay")
	return true


func rejects_development_geometry() -> bool:
	var tile: TileDefinition = _definition("housing")
	tile.canonical_edges.assign([0, 0, 0, 0])
	expect_true(not ContentValidator.validate_development(tile).is_valid, "Even Field edges are meaningless on overlays")
	return true


func rejects_development_starting_bag_entry() -> bool:
	var config: RunConfig = _config()
	config.starting_bag[0].definition_id = &"tile.development.housing"
	expect_true(not ContentValidator.validate(_manifest(), config).is_valid, "Development cannot enter starting bag")
	return true


func rejects_unregistered_development_behavior() -> bool:
	var tile: TileDefinition = _definition("housing")
	tile.effect_behavior_id = &"unexpected_bonus"
	expect_true(not ContentValidator.validate_development(tile).is_valid, "Resource cannot register arbitrary mechanics")
	return true
