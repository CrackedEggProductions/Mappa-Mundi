class_name HomesteadContentValidator
extends RefCounted
## Canonical Phase-2 content boundary; no runtime topology or placement behavior.

const FOUNDING_ID: StringName = &"tile.founding.homestead"
const EXPANSION_IDS: Array[StringName] = [
	&"tile.bending_road", &"tile.forest_belt", &"tile.forest_bend", &"tile.forest_edge",
	&"tile.hamlet_edge", &"tile.open_fields", &"tile.river_bend", &"tile.river_end",
	&"tile.river_run", &"tile.riverside_hamlet", &"tile.road_end", &"tile.road_junction",
	&"tile.settlement_corner", &"tile.settlement_corner_gate", &"tile.settlement_gate",
	&"tile.settlement_road_bend", &"tile.settlement_road_throughway",
	&"tile.settlement_throughway", &"tile.straight_road", &"tile.woodland_river",
	&"tile.woodland_road",
]
const SPECIALIZED_IDS: Array[StringName] = [
	&"tile.road_junction", &"tile.settlement_gate", &"tile.riverside_hamlet",
	&"tile.woodland_road", &"tile.woodland_river", &"tile.settlement_corner_gate",
	&"tile.settlement_road_bend", &"tile.settlement_road_throughway",
]


static func validate_roster_and_config(ids: Array[StringName], config: RunConfig) -> ValidationResult:
	if ids.size() != EXPANSION_IDS.size() + 1 or FOUNDING_ID not in ids:
		return _invalid("Homestead requires all 21 Expansion designs and the Founding Tile.")
	for definition_id: StringName in EXPANSION_IDS:
		if definition_id not in ids:
			return _invalid("Missing Homestead Expansion definition.", definition_id)
	if config.hand_capacity != 3 or config.reserve_capacity != 1 or config.initial_survey_charges != 1:
		return _invalid("Homestead requires a three-tile hand, one Reserve slot and one initial Survey.")
	if config.starting_bag.size() != EXPANSION_IDS.size():
		return _invalid("Every Homestead Expansion design needs a starting bag entry.")
	var bag_ids: Array[StringName] = []
	var total_copies: int = 0
	for entry: StartingBagEntry in config.starting_bag:
		if entry == null or entry.count <= 0:
			return _invalid("Starting bag entries must be present with positive copy counts.")
		if entry.definition_id not in EXPANSION_IDS or entry.definition_id in bag_ids:
			return _invalid("Starting bag definitions must resolve uniquely to Expansions.", entry.definition_id)
		if entry.count != _canonical_starting_count(entry.definition_id):
			return _invalid("Starting bag copy count differs from RULE-BAG-002.", entry.definition_id)
		bag_ids.append(entry.definition_id)
		total_copies += entry.count
	if total_copies != 55:
		return _invalid("The Homestead starting bag must contain exactly 55 physical copies.")
	var emergency_ids: Array[StringName] = config.emergency_definitions.duplicate()
	emergency_ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	var expected_emergency: Array[StringName] = [&"tile.forest_edge", &"tile.hamlet_edge", &"tile.road_end"]
	if emergency_ids != expected_emergency:
		return _invalid("Emergency replenishment must contain Forest Edge, Hamlet Edge and Road End once each.")
	return ValidationResult.success()


static func _canonical_starting_count(definition_id: StringName) -> int:
	# Validation contract only. Gameplay allocates exclusively from RunConfig data.
	match definition_id:
		&"tile.open_fields", &"tile.straight_road", &"tile.bending_road": return 4
		&"tile.forest_edge", &"tile.forest_bend", &"tile.river_run", &"tile.river_bend", \
				&"tile.road_end", &"tile.hamlet_edge", &"tile.settlement_corner": return 3
	return 2


static func validate_tile(tile: TileDefinition) -> ValidationResult:
	var tile_id: StringName = tile.definition_id
	if tile_id not in EXPANSION_IDS and tile_id != FOUNDING_ID:
		return _invalid("Tile is outside the canonical Homestead roster.", tile_id)
	if tile.display_name.strip_edges().is_empty() or tile.display_name == "River Source":
		return _invalid("Canonical tile display name is missing or superseded.", tile_id)
	if tile.tile_class != DomainTypes.TileClass.EXPANSION or tile.unlock_act != 1:
		return _invalid("Homestead tile definitions must be Act-I Expansion geometry.", tile_id)
	var expected_reward: DomainTypes.RewardClass = DomainTypes.RewardClass.BASIC_EXPANSION
	if tile_id == FOUNDING_ID:
		expected_reward = DomainTypes.RewardClass.NONE
	elif tile_id in SPECIALIZED_IDS:
		expected_reward = DomainTypes.RewardClass.SPECIALIZED_EXPANSION
	if tile.reward_class != expected_reward:
		return _invalid("Tile reward class differs from the canonical catalogue.", tile_id)
	if not tile.placement_behavior_id.is_empty() or not tile.effect_behavior_id.is_empty() \
			or not tile.development_family_id.is_empty() or not tile.upgrade_from_definition_id.is_empty() \
			or not tile.tags.is_empty():
		return _invalid("Phase-2 Expansion content cannot declare unimplemented behavior or overlays.", tile_id)
	if tile.canonical_edges != canonical_edges_for(tile_id):
		return _invalid("Tile edges differ from the documented canonical orientation.", tile_id)
	var groups_result: ValidationResult = _validate_groups(tile)
	if not groups_result.is_valid:
		return groups_result
	return _validate_relationships(tile)


static func _validate_groups(tile: TileDefinition) -> ValidationResult:
	var covered: Array[int] = []
	var feature_types: Array[int] = []
	for group: TileFeatureGroup in tile.feature_groups:
		if group == null or group.edge_type == DomainTypes.EdgeType.FIELD \
				or group.edge_type not in DomainTypes.EdgeType.values() \
				or group.edge_type in feature_types or group.directions.is_empty():
			return _invalid("Each feature type needs exactly one nonempty component.", tile.definition_id)
		feature_types.append(group.edge_type)
		for direction: int in group.directions:
			if direction not in [0, 1, 2, 3] or direction in covered:
				return _invalid("Feature sockets must be valid and unique.", tile.definition_id)
			if tile.canonical_edges[direction] != group.edge_type:
				return _invalid("Feature socket type must match its canonical edge.", tile.definition_id)
			covered.append(direction)
	for direction: int in range(4):
		if tile.canonical_edges[direction] != DomainTypes.EdgeType.FIELD and direction not in covered:
			return _invalid("Every non-Field edge needs an explicit internal feature component.", tile.definition_id)
	return ValidationResult.success()


static func _invalid(message: String, definition_id: StringName = &"") -> ValidationResult:
	return ValidationResult.failure(&"invalid_homestead_content", message, {"definition_id": String(definition_id)})


static func _validate_relationships(tile: TileDefinition) -> ValidationResult:
	var expected: Array[int] = []
	match tile.definition_id:
		FOUNDING_ID, &"tile.settlement_gate", &"tile.settlement_corner_gate", \
				&"tile.settlement_road_bend", &"tile.settlement_road_throughway":
			expected = [DomainTypes.EdgeType.ROAD, DomainTypes.EdgeType.SETTLEMENT,
				TileFeatureRelationship.Kind.ROAD_SETTLEMENT_ACCESS]
		&"tile.riverside_hamlet":
			expected = [DomainTypes.EdgeType.SETTLEMENT, DomainTypes.EdgeType.RIVER,
				TileFeatureRelationship.Kind.SETTLEMENT_RIVER_TOUCH]
		&"tile.woodland_river":
			expected = [DomainTypes.EdgeType.FOREST, DomainTypes.EdgeType.RIVER,
				TileFeatureRelationship.Kind.FOREST_RIVER_TOUCH]
	if expected.is_empty():
		if not tile.relationships.is_empty():
			return _invalid("This design has no canonical cross-feature relationship.", tile.definition_id)
		return ValidationResult.success()
	if tile.relationships.size() != 1 or tile.relationships[0] == null:
		return _invalid("The tile requires one explicit cross-feature relationship.", tile.definition_id)
	var relationship: TileFeatureRelationship = tile.relationships[0]
	if relationship.from_edge_type != expected[0] or relationship.to_edge_type != expected[1] \
			or relationship.kind != expected[2]:
		return _invalid("The tile's explicit internal relationship is incorrect.", tile.definition_id)
	return ValidationResult.success()


static func canonical_edges_for(definition_id: StringName) -> Array[DomainTypes.EdgeType]:
	# This validation contract fixes the base orientations documented with the content.
	match definition_id:
		&"tile.open_fields": return [0, 0, 0, 0]
		&"tile.forest_edge": return [1, 0, 0, 0]
		&"tile.forest_bend": return [1, 1, 0, 0]
		&"tile.forest_belt": return [1, 0, 1, 0]
		&"tile.river_end": return [2, 0, 0, 0]
		&"tile.river_run": return [2, 0, 2, 0]
		&"tile.river_bend": return [2, 2, 0, 0]
		&"tile.road_end": return [3, 0, 0, 0]
		&"tile.straight_road": return [3, 0, 3, 0]
		&"tile.bending_road": return [3, 3, 0, 0]
		&"tile.road_junction": return [3, 3, 3, 0]
		&"tile.hamlet_edge": return [4, 0, 0, 0]
		&"tile.settlement_corner": return [4, 4, 0, 0]
		&"tile.settlement_throughway": return [4, 0, 4, 0]
		&"tile.settlement_gate": return [4, 3, 0, 0]
		&"tile.riverside_hamlet": return [4, 2, 0, 2]
		&"tile.woodland_road": return [1, 1, 3, 3]
		&"tile.woodland_river": return [1, 1, 2, 2]
		&"tile.settlement_corner_gate": return [4, 4, 3, 0]
		&"tile.settlement_road_bend": return [4, 4, 3, 3]
		&"tile.settlement_road_throughway": return [4, 3, 4, 3]
		FOUNDING_ID: return [4, 3, 2, 1]
	return []
