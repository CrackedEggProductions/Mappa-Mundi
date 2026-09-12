extends "res://tests/framework/test_suite.gd"


func tests() -> Array[Callable]:
	return [
		loads_complete_homestead_profile, preserves_minimal_profile,
		canonical_edges_cover_all_designs, exact_starting_bag_counts,
		founding_has_four_stubs_and_only_road_access, hybrids_keep_explicit_relationships,
		all_non_field_edges_have_connected_groups, rejects_river_source,
		rejects_missing_definition, rejects_missing_feature_socket,
		rejects_duplicate_feature_group, rejects_invalid_feature_direction,
		rejects_missing_access, rejects_spurious_cross_feature_link,
		rejects_wrong_touch_endpoints, rejects_wrong_canonical_geometry,
		rejects_wrong_reward_class, rejects_incorrect_bag_count,
		rejects_same_total_wrong_composition, rejects_duplicate_bag_entry,
		rejects_founding_bag_entry, rejects_invalid_emergency_set,
		rejects_invalid_hand_capacity, registry_owns_nested_content,
	]


func _manifest() -> ContentManifest:
	return (load(ContentRegistry.HOMESTEAD_MANIFEST_PATH) as ContentManifest).duplicate(true) as ContentManifest


func _config() -> RunConfig:
	return (load(ContentRegistry.HOMESTEAD_CONFIG_PATH) as RunConfig).duplicate(true) as RunConfig


func _tile(manifest: ContentManifest, definition_id: StringName) -> TileDefinition:
	for tile: TileDefinition in manifest.tiles:
		if tile.definition_id == definition_id:
			return tile
	return null


func _rejected(manifest: ContentManifest, config: RunConfig) -> void:
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed Homestead content must be rejected")
	expect_true(not result.error_code.is_empty(), "Rejection has a structured diagnostic")


func loads_complete_homestead_profile() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = registry.load_homestead()
	expect_true(result.is_valid, result.user_message)
	expect_equal(registry.get_tile_ids().size(), 22, "21 Expansion definitions plus Founding")
	expect_equal(registry.get_config().initial_survey_charges, 1, "One initial Survey")
	expect_equal(registry.get_config().reserve_capacity, 1, "One Reserve slot")
	return true


func preserves_minimal_profile() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	expect_true(registry.load_content().is_valid, "Foundation manifest still loads")
	expect_equal(registry.get_tile_ids(), [&"tile.open_fields", &"tile.straight_road"], "Default profile stays minimal")
	return true


func canonical_edges_cover_all_designs() -> bool:
	var manifest: ContentManifest = _manifest()
	var ids: Array[StringName] = [
		&"tile.open_fields", &"tile.forest_edge", &"tile.forest_bend", &"tile.forest_belt",
		&"tile.river_end", &"tile.river_run", &"tile.river_bend", &"tile.road_end",
		&"tile.straight_road", &"tile.bending_road", &"tile.road_junction", &"tile.hamlet_edge",
		&"tile.settlement_corner", &"tile.settlement_throughway", &"tile.settlement_gate",
		&"tile.riverside_hamlet", &"tile.woodland_road", &"tile.woodland_river",
		&"tile.settlement_corner_gate", &"tile.settlement_road_bend", &"tile.settlement_road_throughway",
	]
	var edges: Array[PackedInt32Array] = [
		PackedInt32Array([0,0,0,0]), PackedInt32Array([1,0,0,0]), PackedInt32Array([1,1,0,0]),
		PackedInt32Array([1,0,1,0]), PackedInt32Array([2,0,0,0]), PackedInt32Array([2,0,2,0]),
		PackedInt32Array([2,2,0,0]), PackedInt32Array([3,0,0,0]), PackedInt32Array([3,0,3,0]),
		PackedInt32Array([3,3,0,0]), PackedInt32Array([3,3,3,0]), PackedInt32Array([4,0,0,0]),
		PackedInt32Array([4,4,0,0]), PackedInt32Array([4,0,4,0]), PackedInt32Array([4,3,0,0]),
		PackedInt32Array([4,2,0,2]), PackedInt32Array([1,1,3,3]), PackedInt32Array([1,1,2,2]),
		PackedInt32Array([4,4,3,0]), PackedInt32Array([4,4,3,3]), PackedInt32Array([4,3,4,3]),
	]
	for index: int in range(ids.size()):
		var tile: TileDefinition = _tile(manifest, ids[index])
		expect_true(tile != null, "Canonical design exists: %s" % ids[index])
		if tile != null:
			expect_equal(PackedInt32Array(tile.canonical_edges), edges[index], "Canonical N/E/S/W geometry")
			expect_equal(tile.unlock_act, 1, "Every starting Expansion unlocks in Act I")
	return true


func exact_starting_bag_counts() -> bool:
	# Independent expected counts in the documented deterministic ID order.
	var ids: Array[StringName] = [
		&"tile.bending_road", &"tile.forest_belt", &"tile.forest_bend", &"tile.forest_edge",
		&"tile.hamlet_edge", &"tile.open_fields", &"tile.river_bend", &"tile.river_end",
		&"tile.river_run", &"tile.riverside_hamlet", &"tile.road_end", &"tile.road_junction",
		&"tile.settlement_corner", &"tile.settlement_corner_gate", &"tile.settlement_gate",
		&"tile.settlement_road_bend", &"tile.settlement_road_throughway", &"tile.settlement_throughway",
		&"tile.straight_road", &"tile.woodland_river", &"tile.woodland_road",
	]
	var counts: Array[int] = [4,2,3,3,3,4,3,2,3,2,3,2,3,2,2,2,2,2,4,2,2]
	var config: RunConfig = _config()
	var total: int = 0
	expect_equal(config.starting_bag.size(), 21, "Exactly 21 starting designs")
	for index: int in range(config.starting_bag.size()):
		var entry: StartingBagEntry = config.starting_bag[index]
		expect_equal(entry.definition_id, ids[index], "Starting bag stable definition order")
		expect_equal(entry.count, counts[index], "Canonical count for %s" % entry.definition_id)
		total += entry.count
	expect_equal(total, 55, "Exactly 55 starting physical copies")
	return true


func founding_has_four_stubs_and_only_road_access() -> bool:
	var tile: TileDefinition = _tile(_manifest(), &"tile.founding.homestead")
	expect_equal(tile.canonical_edges, [4, 3, 2, 1], "Fixed Settlement/Road/River/Forest orientation")
	expect_equal(tile.feature_groups.size(), 4, "Four distinct Founding stubs")
	for group: TileFeatureGroup in tile.feature_groups:
		expect_equal(group.directions.size(), 1, "Each Founding feature is a single stub")
	expect_equal(tile.reward_class, DomainTypes.RewardClass.NONE, "Founding is not reward content")
	expect_equal(tile.relationships.size(), 1, "Only the Road–Settlement pair has an internal relationship")
	expect_equal(tile.relationships[0].kind, TileFeatureRelationship.Kind.ROAD_SETTLEMENT_ACCESS, "Explicit access")
	return true


func hybrids_keep_explicit_relationships() -> bool:
	var manifest: ContentManifest = _manifest()
	for definition_id: StringName in [&"tile.settlement_gate", &"tile.settlement_corner_gate",
			&"tile.settlement_road_bend", &"tile.settlement_road_throughway"]:
		var tile: TileDefinition = _tile(manifest, definition_id)
		expect_equal(tile.feature_groups.size(), 2, "Road and Settlement stay distinct")
		expect_equal(tile.relationships[0].kind, TileFeatureRelationship.Kind.ROAD_SETTLEMENT_ACCESS, "Road access")
	var riverside: TileDefinition = _tile(manifest, &"tile.riverside_hamlet")
	expect_equal(riverside.relationships[0].kind, TileFeatureRelationship.Kind.SETTLEMENT_RIVER_TOUCH, "Settlement touches River")
	var woodland: TileDefinition = _tile(manifest, &"tile.woodland_river")
	expect_equal(woodland.relationships[0].kind, TileFeatureRelationship.Kind.FOREST_RIVER_TOUCH, "Forest touches River")
	expect_true(_tile(manifest, &"tile.woodland_road").relationships.is_empty(), "Woodland Road invents no access/touch")
	return true


func all_non_field_edges_have_connected_groups() -> bool:
	for tile: TileDefinition in _manifest().tiles:
		var covered: Array[int] = []
		var types: Array[int] = []
		for group: TileFeatureGroup in tile.feature_groups:
			expect_true(group.edge_type not in types, "Each same-type pair/junction is one connected component")
			types.append(group.edge_type)
			for direction: int in group.directions:
				expect_true(direction not in covered, "Socket belongs to exactly one component")
				covered.append(direction)
				expect_equal(tile.canonical_edges[direction], group.edge_type, "Component socket matches edge")
		for direction: int in range(4):
			expect_equal(direction in covered, tile.canonical_edges[direction] != DomainTypes.EdgeType.FIELD,
				"Exactly the non-Field sockets have feature metadata")
	return true


func rejects_river_source() -> bool:
	var manifest: ContentManifest = _manifest()
	_tile(manifest, &"tile.river_end").definition_id = &"tile.river_source"
	_rejected(manifest, _config())
	return true


func rejects_missing_definition() -> bool:
	var manifest: ContentManifest = _manifest()
	manifest.tiles.pop_back()
	_rejected(manifest, _config())
	return true


func rejects_missing_feature_socket() -> bool:
	var manifest: ContentManifest = _manifest()
	_tile(manifest, &"tile.straight_road").feature_groups[0].directions.pop_back()
	_rejected(manifest, _config())
	return true


func rejects_duplicate_feature_group() -> bool:
	var manifest: ContentManifest = _manifest()
	var tile: TileDefinition = _tile(manifest, &"tile.straight_road")
	tile.feature_groups.append(tile.feature_groups[0].duplicate(true))
	_rejected(manifest, _config())
	return true


func rejects_invalid_feature_direction() -> bool:
	var manifest: ContentManifest = _manifest()
	_tile(manifest, &"tile.straight_road").feature_groups[0].directions[0] = 4
	_rejected(manifest, _config())
	return true


func rejects_missing_access() -> bool:
	var manifest: ContentManifest = _manifest()
	_tile(manifest, &"tile.settlement_road_bend").relationships.clear()
	_rejected(manifest, _config())
	return true


func rejects_spurious_cross_feature_link() -> bool:
	var manifest: ContentManifest = _manifest()
	_tile(manifest, &"tile.woodland_road").relationships.append(TileFeatureRelationship.new())
	_rejected(manifest, _config())
	return true


func rejects_wrong_touch_endpoints() -> bool:
	var manifest: ContentManifest = _manifest()
	_tile(manifest, &"tile.woodland_river").relationships[0].from_edge_type = DomainTypes.EdgeType.SETTLEMENT
	_rejected(manifest, _config())
	return true


func rejects_wrong_canonical_geometry() -> bool:
	var manifest: ContentManifest = _manifest()
	_tile(manifest, &"tile.river_bend").canonical_edges.assign([2, 0, 2, 0])
	_rejected(manifest, _config())
	return true


func rejects_wrong_reward_class() -> bool:
	var manifest: ContentManifest = _manifest()
	_tile(manifest, &"tile.road_junction").reward_class = DomainTypes.RewardClass.BASIC_EXPANSION
	_rejected(manifest, _config())
	return true


func rejects_incorrect_bag_count() -> bool:
	var config: RunConfig = _config()
	config.starting_bag[0].count += 1
	_rejected(_manifest(), config)
	return true


func rejects_same_total_wrong_composition() -> bool:
	var config: RunConfig = _config()
	config.starting_bag[0].count -= 1
	config.starting_bag[1].count += 1
	_rejected(_manifest(), config)
	return true


func rejects_duplicate_bag_entry() -> bool:
	var config: RunConfig = _config()
	config.starting_bag[1].definition_id = config.starting_bag[0].definition_id
	_rejected(_manifest(), config)
	return true


func rejects_founding_bag_entry() -> bool:
	var config: RunConfig = _config()
	config.starting_bag[0].definition_id = &"tile.founding.homestead"
	_rejected(_manifest(), config)
	return true


func rejects_invalid_emergency_set() -> bool:
	var config: RunConfig = _config()
	config.emergency_definitions[0] = &"tile.open_fields"
	_rejected(_manifest(), config)
	return true


func rejects_invalid_hand_capacity() -> bool:
	var config: RunConfig = _config()
	config.hand_capacity = 4
	_rejected(_manifest(), config)
	return true


func registry_owns_nested_content() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	expect_true(registry.load_homestead().is_valid, "Homestead loads")
	var tile: TileDefinition = registry.get_tile(&"tile.settlement_gate")
	tile.feature_groups[0].directions.clear()
	tile.relationships[0].from_edge_type = DomainTypes.EdgeType.FOREST
	var config: RunConfig = registry.get_config()
	config.starting_bag[0].count = 999
	var fresh: TileDefinition = registry.get_tile(&"tile.settlement_gate")
	expect_true(not fresh.feature_groups[0].directions.is_empty(), "Group mutation cannot change registry content")
	expect_equal(fresh.relationships[0].from_edge_type, DomainTypes.EdgeType.ROAD, "Relationship data is owned")
	expect_equal(registry.get_config().starting_bag[0].count, 4, "Bag entries are owned")
	return true
