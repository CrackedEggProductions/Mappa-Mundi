extends "res://tests/framework/test_suite.gd"


func tests() -> Array[Callable]:
	return [
		loads_phase_six_profile, urban_expansion_metadata, bridge_metadata, rewilding_metadata,
		urban_has_explicit_road_access, rewilding_has_one_through_forest, bridge_has_no_base_geometry,
		preserves_prior_profiles, preserves_exact_starting_bag, preserves_emergency_composition,
		registry_owns_transformation_metadata, rejects_missing_transformation, rejects_extra_transformation,
		rejects_wrong_class_or_unlock, rejects_wrong_reward_metadata, rejects_wrong_modes_or_prerequisite,
		rejects_geometry_changes, rejects_bad_internal_access, rejects_development_metadata,
		rejects_missing_presentation, rejects_unregistered_behavior, rejects_transformation_starting_bag,
		rejects_transformation_fields_on_old_content,
	]


func _manifest() -> ContentManifest:
	return (load(ContentRegistry.PHASE_SIX_MANIFEST_PATH) as ContentManifest).duplicate(true) as ContentManifest


func _config() -> RunConfig:
	return (load(ContentRegistry.HOMESTEAD_CONFIG_PATH) as RunConfig).duplicate(true) as RunConfig


func _tile(kind: String) -> TileDefinition:
	return (load("res://content/tiles/transformations/%s.tres" % kind) as TileDefinition).duplicate(true) as TileDefinition


func _metadata(kind: String, act: int, reward: DomainTypes.RewardClass, count: int,
		modes: Array[StringName], prerequisite: StringName) -> bool:
	var tile: TileDefinition = _tile(kind)
	expect_equal(tile.definition_id, StringName("tile.transformation." + kind), "Stable ID")
	expect_equal(tile.tile_class, DomainTypes.TileClass.TRANSFORMATION, "Single physical Transformation class")
	expect_equal(tile.transformation_kind, StringName(kind), "Explicit kind")
	expect_equal(tile.unlock_act, act, "Canonical unlock Act")
	expect_equal(tile.reward_class, reward, "Future reward classification")
	expect_equal(tile.normal_reward_copy_count, count, "Normal reward quantity, independent of future seeding")
	expect_equal(tile.transformation_placement_modes, modes, "Explicit supported placement categories")
	expect_equal(tile.transformation_prerequisite_id, prerequisite, "Occupied target prerequisite")
	expect_equal(tile.presentation_id, StringName("transformation." + kind), "Logical presentation hook")
	expect_true(TransformationContentValidator.validate_tile(tile).is_valid, "Canonical metadata validates")
	return true


func loads_phase_six_profile() -> bool:
	var content: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = content.load_phase_six()
	expect_true(result.is_valid, result.user_message)
	expect_equal(content.get_tile_ids().size(), 34, "31 previous designs plus three Transformations")
	return true


func urban_expansion_metadata() -> bool:
	return _metadata("urban_expansion", 2, DomainTypes.RewardClass.SPECIALIZED_EXPANSION, 2, [&"empty_square"], &"")


func bridge_metadata() -> bool:
	return _metadata("bridge", 3, DomainTypes.RewardClass.MAJOR_RARE, 1, [&"occupied_square"], &"underlying_straight_river_run")


func rewilding_metadata() -> bool:
	return _metadata("rewilding", 3, DomainTypes.RewardClass.MAJOR_RARE, 1,
		[&"empty_square", &"occupied_square"], &"eligible_field")


func urban_has_explicit_road_access() -> bool:
	var tile: TileDefinition = _tile("urban_expansion")
	expect_equal(tile.canonical_edges, [4, 3, 4, 0], "Canonical N/E/S/W Settlement/Road/Settlement/Field")
	expect_equal(tile.feature_groups.size(), 2, "Road and through Settlement remain separate components")
	for group: TileFeatureGroup in tile.feature_groups:
		expect_equal(group.directions, [1] if group.edge_type == DomainTypes.EdgeType.ROAD else [0, 2], "Explicit internal sockets")
	expect_equal(tile.relationships.size(), 1, "One explicit access relationship")
	expect_equal(tile.relationships[0].kind, TileFeatureRelationship.Kind.ROAD_SETTLEMENT_ACCESS, "Road access")
	expect_equal(tile.relationships[0].from_edge_type, DomainTypes.EdgeType.ROAD, "Road endpoint")
	expect_equal(tile.relationships[0].to_edge_type, DomainTypes.EdgeType.SETTLEMENT, "Settlement endpoint")
	expect_true(tile.field_supports_settlement, "Field geography supports the Settlement")
	return true


func rewilding_has_one_through_forest() -> bool:
	var tile: TileDefinition = _tile("rewilding")
	expect_equal(tile.canonical_edges, [1, 0, 1, 0], "Opposite Forest edges with two Field edges")
	expect_equal(tile.feature_groups.size(), 1, "One connected Forest")
	expect_equal(tile.feature_groups[0].edge_type, DomainTypes.EdgeType.FOREST, "Forest component")
	expect_equal(tile.feature_groups[0].directions, [0, 2], "Opposite Forest sockets")
	expect_true(tile.relationships.is_empty(), "No invented cross-feature contacts")
	return true


func bridge_has_no_base_geometry() -> bool:
	var tile: TileDefinition = _tile("bridge")
	expect_true(tile.canonical_edges.is_empty() and tile.feature_groups.is_empty()
		and tile.relationships.is_empty(), "Bridge modifies existing geometry through runtime intent")
	return true


func preserves_prior_profiles() -> bool:
	var content: ContentRegistry = ContentRegistry.new()
	expect_true(content.load_content().is_valid, "Foundation profile preserved")
	expect_equal(content.get_tile_ids().size(), 2, "Foundation count unchanged")
	expect_true(content.load_homestead().is_valid, "Homestead profile preserved")
	expect_equal(content.get_tile_ids().size(), 22, "Homestead count unchanged")
	expect_true(content.load_phase_five().is_valid, "Development profile preserved")
	expect_equal(content.get_tile_ids().size(), 31, "Phase-5 count unchanged")
	return true


func preserves_exact_starting_bag() -> bool:
	var content: ContentRegistry = ContentRegistry.new()
	expect_true(content.load_phase_six().is_valid, "Phase-6 content loads")
	var count: int = 0
	for entry: StartingBagEntry in content.get_config().starting_bag:
		count += entry.count
		expect_equal(content.get_tile(entry.definition_id).tile_class, DomainTypes.TileClass.EXPANSION, "Expansion-only starting copies")
	expect_equal(count, 55, "No automatic seeding or rewarded copies")
	return true


func preserves_emergency_composition() -> bool:
	expect_equal(_config().emergency_definitions, [&"tile.forest_edge", &"tile.hamlet_edge", &"tile.road_end"],
		"Emergency content remains the established three Expansions")
	return true


func registry_owns_transformation_metadata() -> bool:
	var content: ContentRegistry = ContentRegistry.new()
	expect_true(content.load_phase_six().is_valid, "Phase-6 content loads")
	var tile: TileDefinition = content.get_tile(&"tile.transformation.rewilding")
	tile.transformation_placement_modes.clear()
	tile.feature_groups[0].directions.clear()
	var fresh: TileDefinition = content.get_tile(tile.definition_id)
	expect_equal(fresh.transformation_placement_modes.size(), 2, "Mode metadata is owned")
	expect_equal(fresh.feature_groups[0].directions, [0, 2], "Nested component metadata is owned")
	return true


func rejects_missing_transformation() -> bool:
	var manifest: ContentManifest = _manifest()
	manifest.tiles.pop_back()
	expect_true(not ContentValidator.validate(manifest, _config()).is_valid, "Full Phase-6 roster required")
	return true


func rejects_extra_transformation() -> bool:
	var manifest: ContentManifest = _manifest()
	var extra: TileDefinition = _tile("bridge")
	extra.definition_id = &"tile.transformation.unknown"
	manifest.tiles.append(extra)
	expect_true(not ContentValidator.validate(manifest, _config()).is_valid, "Unknown designs rejected")
	return true


func _reject_changes(kind: String, changes: Dictionary) -> void:
	for property: String in changes:
		var tile: TileDefinition = _tile(kind)
		tile.set(property, changes[property])
		var result: ValidationResult = TransformationContentValidator.validate_tile(tile)
		expect_true(not result.is_valid, "%s rejects invalid %s" % [kind, property])
		expect_equal(result.error_code, &"invalid_transformation_content", "Structured content failure")


func rejects_wrong_class_or_unlock() -> bool:
	_reject_changes("urban_expansion", {"tile_class": DomainTypes.TileClass.EXPANSION, "unlock_act": 1})
	_reject_changes("bridge", {"unlock_act": 2, "transformation_kind": &"rewilding"})
	return true


func rejects_wrong_reward_metadata() -> bool:
	_reject_changes("urban_expansion", {"reward_class": DomainTypes.RewardClass.BASIC_EXPANSION, "normal_reward_copy_count": 3})
	_reject_changes("bridge", {"reward_class": DomainTypes.RewardClass.SPECIALIZED_EXPANSION, "normal_reward_copy_count": 2})
	_reject_changes("rewilding", {"normal_reward_copy_count": 2})
	return true


func rejects_wrong_modes_or_prerequisite() -> bool:
	var bridge: TileDefinition = _tile("bridge")
	bridge.transformation_placement_modes.assign([&"empty_square"])
	expect_true(not TransformationContentValidator.validate_tile(bridge).is_valid, "Bridge requires occupied target")
	var urban: TileDefinition = _tile("urban_expansion")
	urban.transformation_placement_modes.append(&"occupied_square")
	expect_true(not TransformationContentValidator.validate_tile(urban).is_valid, "Urban has only empty-square placement")
	var rewilding: TileDefinition = _tile("rewilding")
	rewilding.transformation_placement_modes.pop_back()
	expect_true(not TransformationContentValidator.validate_tile(rewilding).is_valid, "Rewilding retains both categories")
	_reject_changes("bridge", {"transformation_prerequisite_id": &"any_river"})
	_reject_changes("rewilding", {"transformation_prerequisite_id": &""})
	return true


func rejects_geometry_changes() -> bool:
	var urban: TileDefinition = _tile("urban_expansion")
	urban.canonical_edges[2] = DomainTypes.EdgeType.FIELD
	expect_true(not TransformationContentValidator.validate_tile(urban).is_valid, "Urban has two opposite Settlement edges")
	var rewilding: TileDefinition = _tile("rewilding")
	rewilding.feature_groups[0].directions.pop_back()
	expect_true(not TransformationContentValidator.validate_tile(rewilding).is_valid, "Forest component includes both sockets")
	var bridge: TileDefinition = _tile("bridge")
	bridge.canonical_edges.assign([2, 3, 2, 3])
	expect_true(not TransformationContentValidator.validate_tile(bridge).is_valid, "Bridge cannot override all base geometry")
	return true


func rejects_bad_internal_access() -> bool:
	var missing: TileDefinition = _tile("urban_expansion")
	missing.relationships.clear()
	expect_true(not TransformationContentValidator.validate_tile(missing).is_valid, "Urban requires explicit internal access")
	var wrong: TileDefinition = _tile("urban_expansion")
	wrong.relationships[0].to_edge_type = DomainTypes.EdgeType.RIVER
	expect_true(not TransformationContentValidator.validate_tile(wrong).is_valid, "Access endpoints must be Road/Settlement")
	return true


func rejects_development_metadata() -> bool:
	_reject_changes("bridge", {"development_family_id": &"family.bridge", "development_host_kind": &"river",
		"development_stage": &"bridge", "upgrade_from_definition_id": &"tile.river_run"})
	return true


func rejects_missing_presentation() -> bool:
	_reject_changes("rewilding", {"presentation_id": &""})
	return true


func rejects_unregistered_behavior() -> bool:
	_reject_changes("urban_expansion", {"placement_behavior_id": &"unexpected", "effect_behavior_id": &"unexpected"})
	return true


func rejects_transformation_starting_bag() -> bool:
	var config: RunConfig = _config()
	config.starting_bag[0].definition_id = &"tile.transformation.urban_expansion"
	expect_true(not ContentValidator.validate(_manifest(), config).is_valid, "Urban is not an initial Expansion copy")
	return true


func rejects_transformation_fields_on_old_content() -> bool:
	var manifest: ContentManifest = _manifest()
	manifest.tiles[0].transformation_kind = &"rewilding"
	expect_true(not ContentValidator.validate(manifest, _config()).is_valid, "Expansion cannot smuggle Transformation rules")
	return true
