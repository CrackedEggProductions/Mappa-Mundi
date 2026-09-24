class_name TransformationContentValidator
extends RefCounted
## Static Phase-6 contract; runtime target eligibility stays in placement queries.


static func validate_tile(tile: TileDefinition) -> ValidationResult:
	if tile == null:
		return _invalid("Transformation definition is required.")
	if tile.transformation_kind not in [&"urban_expansion", &"bridge", &"rewilding"] \
			or tile.definition_id != StringName("tile.transformation." + String(tile.transformation_kind)):
		return _invalid("Transformation definition ID and kind must match the canonical roster.", tile.definition_id)
	var urban: bool = tile.transformation_kind == &"urban_expansion"
	if tile.tile_class != DomainTypes.TileClass.TRANSFORMATION or tile.display_name.strip_edges().is_empty() \
			or tile.unlock_act != (2 if urban else 3) \
			or tile.reward_class != (DomainTypes.RewardClass.SPECIALIZED_EXPANSION if urban else DomainTypes.RewardClass.MAJOR_RARE) \
			or tile.normal_reward_copy_count != (2 if urban else 1):
		return _invalid("Transformation class, unlock and reward metadata must match alpha rules.", tile.definition_id)
	if not tile.development_family_id.is_empty() or not tile.development_host_kind.is_empty() \
			or not tile.development_stage.is_empty() or not tile.upgrade_from_definition_id.is_empty():
		return _invalid("Transformation metadata cannot claim a Development host, family or Upgrade.", tile.definition_id)
	if not tile.placement_behavior_id.is_empty() or not tile.effect_behavior_id.is_empty() or not tile.tags.is_empty():
		return _invalid("Content cannot register arbitrary Transformation behavior.", tile.definition_id)
	if tile.presentation_id != StringName("transformation." + String(tile.transformation_kind)):
		return _invalid("Transformation needs its logical presentation hook.", tile.definition_id)
	var modes: Array[StringName] = [&"empty_square"]
	var prerequisite: StringName = &""
	match tile.transformation_kind:
		&"bridge":
			modes = [&"occupied_square"]
			prerequisite = &"underlying_straight_river_run"
		&"rewilding":
			modes = [&"empty_square", &"occupied_square"]
			prerequisite = &"eligible_field"
	if tile.transformation_placement_modes != modes or tile.transformation_prerequisite_id != prerequisite:
		return _invalid("Transformation placement modes and target prerequisite are canonical metadata.", tile.definition_id)
	return _validate_geometry(tile)


static func _validate_geometry(tile: TileDefinition) -> ValidationResult:
	var expected_edges: Array[DomainTypes.EdgeType] = []
	var expected_groups: Dictionary = {}
	match tile.transformation_kind:
		&"urban_expansion":
			expected_edges.assign([4, 3, 4, 0])
			expected_groups = {3: [1], 4: [0, 2]}
		&"rewilding":
			expected_edges.assign([1, 0, 1, 0])
			expected_groups = {1: [0, 2]}
	if tile.canonical_edges != expected_edges or tile.feature_groups.size() != expected_groups.size():
		return _invalid("Transformation base geometry differs from its canonical orientation.", tile.definition_id)
	var seen: Array[int] = []
	for group: TileFeatureGroup in tile.feature_groups:
		if group == null or group.edge_type not in expected_groups or group.edge_type in seen:
			return _invalid("Transformation feature components must be complete and distinct.", tile.definition_id)
		seen.append(group.edge_type)
		if group.directions != expected_groups[group.edge_type]:
			return _invalid("Transformation component sockets differ from canonical geometry.", tile.definition_id)
	if tile.transformation_kind == &"urban_expansion":
		if not tile.field_supports_settlement or tile.relationships.size() != 1 or tile.relationships[0] == null:
			return _invalid("Urban Expansion requires Field support and explicit Road–Settlement access.", tile.definition_id)
		var access: TileFeatureRelationship = tile.relationships[0]
		if access.from_edge_type != DomainTypes.EdgeType.ROAD or access.to_edge_type != DomainTypes.EdgeType.SETTLEMENT \
				or access.kind != TileFeatureRelationship.Kind.ROAD_SETTLEMENT_ACCESS:
			return _invalid("Urban Expansion Road must connect internally to its Settlement.", tile.definition_id)
	elif not tile.relationships.is_empty() or tile.field_supports_settlement:
		return _invalid("This Transformation has no static cross-feature relationship.", tile.definition_id)
	return ValidationResult.success()


static func _invalid(message: String, definition_id: StringName = &"") -> ValidationResult:
	return ValidationResult.failure(&"invalid_transformation_content", message, {"definition_id": String(definition_id)})
