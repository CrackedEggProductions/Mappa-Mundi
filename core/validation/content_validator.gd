class_name ContentValidator
extends RefCounted
## Static boundary for the minimal foundation fixture and Phase-2 Homestead.
## Later content families remain excluded until their implementation phase.

const PHASE_ZERO_TILE_IDS: Array[StringName] = [&"tile.open_fields", &"tile.straight_road"]
## Basic Expansion geometry needs no special handler. Content cannot register behavior.
const REGISTERED_PLACEMENT_BEHAVIOR_IDS: Array[StringName] = []
const REGISTERED_EFFECT_BEHAVIOR_IDS: Array[StringName] = []


static func validate(manifest: ContentManifest, config: RunConfig) -> ValidationResult:
	if manifest == null or config == null:
		return _invalid(&"missing_resource", "The content manifest and configuration are required.")
	if String(manifest.manifest_id).strip_edges().is_empty():
		return _invalid(&"missing_manifest_id", "The content manifest needs a stable ID.")
	if manifest.implementation_phase not in [0, 2]:
		return _invalid(&"unsupported_phase", "This build validates the foundation and Homestead profiles.")
	if manifest.game_rules_version != BuildVersions.GAME_RULES_VERSION:
		return _invalid(&"rules_version_mismatch", "Content rules version does not match this build.")
	if not manifest.relics.is_empty() or not manifest.specialists.is_empty() \
			or not manifest.charters.is_empty():
		return _invalid(&"unsupported_roster", "Relic, Specialist and Charter content is not ready yet.")
	var config_result: ValidationResult = _validate_config(config)
	if not config_result.is_valid:
		return config_result
	if manifest.tiles.is_empty():
		return _invalid(&"empty_tiles", "The minimal manifest must contain sample tiles.")
	var seen_ids: Array[StringName] = []
	for tile: TileDefinition in manifest.tiles:
		if tile == null:
			return _invalid(&"null_definition", "The manifest contains a missing tile definition.")
		if tile.definition_id in seen_ids:
			return _invalid(&"duplicate_definition_id", "Definition IDs must be unique.", tile.definition_id)
		seen_ids.append(tile.definition_id)
		var tile_result: ValidationResult
		if manifest.implementation_phase == 2:
			tile_result = HomesteadContentValidator.validate_tile(tile)
		else:
			tile_result = _validate_tile(tile)
		if not tile_result.is_valid:
			return tile_result
	if manifest.implementation_phase == 2:
		return HomesteadContentValidator.validate_roster_and_config(seen_ids, config)
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
