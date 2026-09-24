class_name ContentValidator
extends RefCounted
## Static boundary for foundation, Homestead, Developments and Transformations.

const PHASE_ZERO_TILE_IDS: Array[StringName] = [&"tile.open_fields", &"tile.straight_road"]
## Basic Expansion geometry needs no special handler. Content cannot register behavior.
const REGISTERED_PLACEMENT_BEHAVIOR_IDS: Array[StringName] = []
const REGISTERED_EFFECT_BEHAVIOR_IDS: Array[StringName] = []
const TRANSFORMATION_IDS: Array[StringName] = [
	&"tile.transformation.urban_expansion", &"tile.transformation.bridge", &"tile.transformation.rewilding",
]
## Canonical validation contract: family suffix, host, unlock Act, prerequisite suffix.
const DEVELOPMENT_ROSTER: Dictionary = {
	&"housing": [&"housing", &"settlement", 1, &""],
	&"mill": [&"mill", &"field", 1, &""],
	&"monastery": [&"monastery", &"enclosure", 1, &""],
	&"foresters_lodge": [&"foresters_lodge", &"forest", 1, &""],
	&"market": [&"market", &"settlement", 2, &""],
	&"port": [&"port", &"settlement", 2, &""],
	&"town_square": [&"town_square", &"settlement", 2, &""],
	&"abbey": [&"monastery", &"enclosure", 2, &"monastery"],
	&"grand_market": [&"market", &"settlement", 3, &"market"],
}


static func validate(manifest: ContentManifest, config: RunConfig) -> ValidationResult:
	if manifest == null or config == null:
		return _invalid(&"missing_resource", "The content manifest and configuration are required.")
	if String(manifest.manifest_id).strip_edges().is_empty():
		return _invalid(&"missing_manifest_id", "The content manifest needs a stable ID.")
	if manifest.implementation_phase not in [0, 2, 5, 6, 7]:
		return _invalid(&"unsupported_phase", "This build validates content profiles through Phase 7.")
	if manifest.game_rules_version != BuildVersions.GAME_RULES_VERSION:
		return _invalid(&"rules_version_mismatch", "Content rules version does not match this build.")
	if not manifest.relics.is_empty() or not manifest.charters.is_empty() \
			or (manifest.implementation_phase < 7 and not manifest.specialists.is_empty()):
		return _invalid(&"unsupported_roster", "Content profile contains a deferred roster.")
	if manifest.implementation_phase == 7:
		var specialists_result: ValidationResult = SpecialistContentValidator.validate(manifest.specialists)
		if not specialists_result.is_valid:
			return specialists_result
	var config_result: ValidationResult = _validate_config(config)
	if not config_result.is_valid:
		return config_result
	if manifest.tiles.is_empty():
		return _invalid(&"empty_tiles", "The minimal manifest must contain sample tiles.")
	var seen_ids: Array[StringName] = []
	var expansion_ids: Array[StringName] = []
	for tile: TileDefinition in manifest.tiles:
		if tile == null:
			return _invalid(&"null_definition", "The manifest contains a missing tile definition.")
		if tile.definition_id in seen_ids:
			return _invalid(&"duplicate_definition_id", "Definition IDs must be unique.", tile.definition_id)
		seen_ids.append(tile.definition_id)
		var tile_result: ValidationResult
		if tile.tile_class != DomainTypes.TileClass.TRANSFORMATION \
				and (not tile.transformation_kind.is_empty() or not tile.transformation_placement_modes.is_empty() \
				or not tile.transformation_prerequisite_id.is_empty()):
			return _invalid(&"unexpected_transformation_metadata", "Only Transformation designs declare Transformation metadata.", tile.definition_id)
		if manifest.implementation_phase >= 6 and tile.tile_class == DomainTypes.TileClass.TRANSFORMATION:
			tile_result = TransformationContentValidator.validate_tile(tile)
		elif manifest.implementation_phase in [5, 6, 7] and tile.tile_class != DomainTypes.TileClass.EXPANSION:
			tile_result = validate_development(tile)
		elif manifest.implementation_phase in [2, 5, 6, 7]:
			tile_result = HomesteadContentValidator.validate_tile(tile)
			expansion_ids.append(tile.definition_id)
		else:
			tile_result = _validate_tile(tile)
		if not tile_result.is_valid:
			return tile_result
	if manifest.implementation_phase == 2:
		return HomesteadContentValidator.validate_roster_and_config(seen_ids, config)
	if manifest.implementation_phase in [5, 6, 7]:
		for stage: StringName in DEVELOPMENT_ROSTER:
			if StringName("tile.development." + String(stage)) not in seen_ids:
				return _invalid(&"missing_development", "Phase 5 requires all nine Development designs.")
		if manifest.implementation_phase >= 6:
			for definition_id: StringName in TRANSFORMATION_IDS:
				if definition_id not in seen_ids:
					return _invalid(&"missing_transformation", "Phase 6 requires all three Transformation designs.", definition_id)
		return HomesteadContentValidator.validate_roster_and_config(expansion_ids, config)
	return ValidationResult.success()


static func validate_development(tile: TileDefinition) -> ValidationResult:
	if tile == null:
		return _invalid(&"null_definition", "Development definition is required.")
	var stage: StringName = tile.development_stage
	if stage not in DEVELOPMENT_ROSTER or tile.definition_id != StringName("tile.development." + String(stage)):
		return _invalid(&"unsupported_definition", "Development ID/stage is outside the Phase-5 roster.", tile.definition_id)
	var expected: Array = DEVELOPMENT_ROSTER[stage]
	var prerequisite: StringName = expected[3]
	var expected_class: DomainTypes.TileClass = DomainTypes.TileClass.DEVELOPMENT \
		if prerequisite.is_empty() else DomainTypes.TileClass.UPGRADE
	var expected_reward: DomainTypes.RewardClass = DomainTypes.RewardClass.MAJOR_RARE \
		if stage == &"grand_market" else DomainTypes.RewardClass.ORDINARY_DEVELOPMENT
	var expected_prerequisite: StringName = &"" if prerequisite.is_empty() \
		else StringName("tile.development." + String(prerequisite))
	if tile.display_name.strip_edges().is_empty() or tile.tile_class != expected_class \
			or tile.development_family_id != StringName("family." + String(expected[0])) \
			or tile.development_host_kind != expected[1] or tile.unlock_act != expected[2] \
			or tile.upgrade_from_definition_id != expected_prerequisite \
			or tile.reward_class != expected_reward \
			or tile.normal_reward_copy_count != (1 if stage == &"grand_market" else 2):
		return _invalid(&"invalid_development_metadata", "Development metadata differs from the canonical alpha roster.", tile.definition_id)
	if tile.presentation_id != StringName("overlay." + String(stage)):
		return _invalid(&"invalid_presentation_reference", "Development needs its logical overlay presentation reference.", tile.definition_id)
	if not tile.canonical_edges.is_empty() or not tile.feature_groups.is_empty() \
			or not tile.relationships.is_empty() or tile.field_supports_settlement:
		return _invalid(&"invalid_development_geometry", "Developments are edge-neutral overlays.", tile.definition_id)
	if not tile.placement_behavior_id.is_empty() or not tile.effect_behavior_id.is_empty() \
			or not tile.tags.is_empty():
		return _invalid(&"unregistered_behavior", "Development content cannot register additional rules.", tile.definition_id)
	return ValidationResult.success()


static func _validate_config(config: RunConfig) -> ValidationResult:
	if String(config.config_id).strip_edges().is_empty():
		return _invalid(&"missing_config_id", "The configuration needs a stable ID.")
	if config.act_placement_limits.size() != 3:
		return _invalid(&"invalid_act_limits", "Configure exactly three Act placement limits.")
	for limit: int in config.act_placement_limits:
		if limit <= 0:
			return _invalid(&"invalid_act_limits", "Act placement limits must be positive.")
	if config.track_thresholds.size() != 4:
		return _invalid(&"invalid_thresholds", "Configure exactly four Track thresholds.")
	var previous_threshold: int = 0
	for threshold: int in config.track_thresholds:
		if threshold <= previous_threshold:
			return _invalid(&"invalid_thresholds", "Track thresholds must be positive and increasing.")
		previous_threshold = threshold
	return ValidationResult.success()


static func _validate_tile(tile: TileDefinition) -> ValidationResult:
	var tile_id: StringName = tile.definition_id
	if tile_id not in PHASE_ZERO_TILE_IDS:
		return _invalid(&"unsupported_definition", "Tile is outside the Phase-0 sample pool.", tile_id)
	if tile.display_name.strip_edges().is_empty():
		return _invalid(&"missing_display_name", "Tile display name is required.", tile_id)
	if tile.tile_class not in DomainTypes.TileClass.values():
		return _invalid(&"invalid_tile_class", "Unknown tile class.", tile_id)
	if tile.reward_class not in DomainTypes.RewardClass.values():
		return _invalid(&"invalid_reward_class", "Unknown reward class.", tile_id)
	if tile.unlock_act < 1 or tile.unlock_act > 3:
		return _invalid(&"invalid_unlock_act", "Tile unlock Act must be 1, 2 or 3.", tile_id)
	if not tile.placement_behavior_id.is_empty() \
			and tile.placement_behavior_id not in REGISTERED_PLACEMENT_BEHAVIOR_IDS:
		return _invalid(&"unregistered_behavior", "Tile placement behavior is not registered.", tile_id)
	if not tile.effect_behavior_id.is_empty() \
			and tile.effect_behavior_id not in REGISTERED_EFFECT_BEHAVIOR_IDS:
		return _invalid(&"unregistered_behavior", "Tile effect behavior is not registered.", tile_id)
	if tile.canonical_edges.size() != 4:
		return _invalid(&"invalid_edges", "Expansion tiles require four N/E/S/W edges.", tile_id)
	for edge: DomainTypes.EdgeType in tile.canonical_edges:
		if edge not in DomainTypes.EdgeType.values():
			return _invalid(&"invalid_edges", "Unknown edge type.", tile_id)
	if tile.tile_class != DomainTypes.TileClass.EXPANSION \
			or tile.reward_class != DomainTypes.RewardClass.BASIC_EXPANSION or tile.unlock_act != 1:
		return _invalid(&"invalid_sample_class", "Sample tiles must be Act-I Basic Expansions.", tile_id)
	if not tile.development_family_id.is_empty() or not tile.upgrade_from_definition_id.is_empty():
		return _invalid(&"invalid_sample_class", "Expansion samples cannot declare Development fields.", tile_id)
	if not tile.tags.is_empty():
		return _invalid(&"unsupported_tags", "The Phase-0 samples have no rule tags.", tile_id)
	var expected_edges: Array[DomainTypes.EdgeType] = [
		DomainTypes.EdgeType.FIELD, DomainTypes.EdgeType.FIELD,
		DomainTypes.EdgeType.FIELD, DomainTypes.EdgeType.FIELD,
	]
	if tile_id == &"tile.straight_road":
		expected_edges[0] = DomainTypes.EdgeType.ROAD
		expected_edges[2] = DomainTypes.EdgeType.ROAD
	if tile.canonical_edges != expected_edges:
		return _invalid(&"invalid_sample_geometry", "Sample geometry differs from its canonical design.", tile_id)
	return ValidationResult.success()


static func _invalid(code: StringName, message: String, definition_id: StringName = &"") -> ValidationResult:
	return ValidationResult.failure(code, message, {"definition_id": String(definition_id)})
