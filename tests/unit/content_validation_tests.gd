extends "res://tests/framework/test_suite.gd"

const MANIFEST_PATH: String = "res://content/manifests/alpha_content_manifest.tres"
const CONFIG_PATH: String = "res://content/manifests/alpha_run_config.tres"


func tests() -> Array[Callable]:
	return [
		accepts_known_good_minimal_content,
		accepts_tuned_positive_config_values,
		rejects_missing_manifest,
		rejects_missing_config,
		rejects_empty_manifest_id,
		rejects_wrong_rules_version,
		rejects_future_phase_manifest,
		rejects_empty_tile_pool,
		rejects_null_tile,
		rejects_duplicate_definition_id,
		rejects_empty_definition_id,
		rejects_unsupported_tile_definition,
		rejects_blank_display_name,
		rejects_three_edges,
		rejects_invalid_edge_value,
		rejects_noncanonical_sample_edges,
		rejects_invalid_tile_class,
		rejects_development_in_phase_zero,
		rejects_invalid_unlock_act,
		rejects_noncanonical_sample_act,
		rejects_invalid_reward_class,
		rejects_noncanonical_sample_reward,
		rejects_unknown_placement_behavior,
		rejects_unknown_effect_behavior,
		rejects_upgrade_reference_on_expansion,
		rejects_development_family_on_expansion,
		rejects_future_relic_roster,
		rejects_future_specialist_roster,
		rejects_future_charter_roster,
		rejects_empty_config_id,
		rejects_wrong_act_count,
		rejects_nonpositive_act_limit,
		rejects_wrong_threshold_count,
		rejects_nonpositive_threshold,
		rejects_repeated_thresholds,
		rejects_descending_thresholds,
	]


func _manifest() -> ContentManifest:
	return (load(MANIFEST_PATH) as ContentManifest).duplicate(true) as ContentManifest


func _config() -> RunConfig:
	return (load(CONFIG_PATH) as RunConfig).duplicate(true) as RunConfig


func accepts_known_good_minimal_content() -> bool:
	var result: ValidationResult = ContentValidator.validate(_manifest(), _config())
	expect_true(result.is_valid, result.user_message)
	return true


func accepts_tuned_positive_config_values() -> bool:
	var config: RunConfig = _config()
	config.act_placement_limits.assign([10, 15, 20])
	config.track_thresholds.assign([5, 10, 15, 20])
	var result: ValidationResult = ContentValidator.validate(_manifest(), config)
	expect_true(result.is_valid, "Alpha balance values remain tunable")
	return true


func rejects_missing_manifest() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest = null
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_missing_config() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	config = null
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_empty_manifest_id() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.manifest_id = &""
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_wrong_rules_version() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.game_rules_version = "unsupported"
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_future_phase_manifest() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.implementation_phase = 1
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_empty_tile_pool() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles.clear()
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_null_tile() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles.append(null)
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_duplicate_definition_id() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles.append(manifest.tiles[0].duplicate(true))
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_empty_definition_id() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].definition_id = &""
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_unsupported_tile_definition() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].definition_id = &"tile.bridge"
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_blank_display_name() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].display_name = "  "
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_three_edges() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].canonical_edges.pop_back()
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_invalid_edge_value() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].canonical_edges.assign([99, 0, 0, 0])
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_noncanonical_sample_edges() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].canonical_edges.assign([1, 0, 0, 0])
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_invalid_tile_class() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].set("tile_class", 99)
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_development_in_phase_zero() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].tile_class = DomainTypes.TileClass.DEVELOPMENT
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_invalid_unlock_act() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].unlock_act = 0
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_noncanonical_sample_act() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].unlock_act = 2
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_invalid_reward_class() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].set("reward_class", 99)
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_noncanonical_sample_reward() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].reward_class = DomainTypes.RewardClass.MAJOR_RARE
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_unknown_placement_behavior() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].placement_behavior_id = &"missing"
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_unknown_effect_behavior() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].effect_behavior_id = &"missing"
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_upgrade_reference_on_expansion() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].upgrade_from_definition_id = &"tile.missing"
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_development_family_on_expansion() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.tiles[0].development_family_id = &"family.missing"
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_future_relic_roster() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.relics.append(RelicDefinition.new())
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_future_specialist_roster() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.specialists.append(SpecialistDefinition.new())
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_future_charter_roster() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	manifest.charters.append(CharterDefinition.new())
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_empty_config_id() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	config.config_id = &""
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_wrong_act_count() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	config.act_placement_limits.assign([18, 22])
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_nonpositive_act_limit() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	config.act_placement_limits[0] = 0
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_wrong_threshold_count() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	config.track_thresholds.assign([20, 40, 70])
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_nonpositive_threshold() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	config.track_thresholds[0] = 0
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_repeated_thresholds() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	config.track_thresholds.assign([20, 40, 40, 100])
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true


func rejects_descending_thresholds() -> bool:
	var manifest: ContentManifest = _manifest()
	var config: RunConfig = _config()
	config.track_thresholds.assign([20, 70, 40, 100])
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	expect_true(not result.is_valid, "Malformed content must fail validation")
	return true
