extends "res://tests/framework/test_suite.gd"


func tests() -> Array[Callable]:
	return [
		starts_unloaded,
		loads_manifest_without_presentation,
		returns_sorted_definition_ids,
		returns_null_for_unknown_definition,
		returns_null_config_before_loading,
		protects_registered_tile_from_caller_mutation,
		protects_registered_config_from_caller_mutation,
		rejects_wrong_manifest_resource_type,
		rejects_wrong_config_resource_type,
		clears_content_after_failed_reload,
		loads_canonical_alpha_act_limits,
		loads_canonical_alpha_track_thresholds,
	]


func starts_unloaded() -> bool:
	expect_true(not ContentRegistry.new().is_loaded(), "Registry begins unloaded")
	return true


func loads_manifest_without_presentation() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = registry.load_content()
	expect_true(result.is_valid and registry.is_loaded(), result.user_message)
	return true


func returns_sorted_definition_ids() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	registry.load_content()
	expect_equal(registry.get_tile_ids(), [&"tile.open_fields", &"tile.straight_road"], "Stable ID order")
	return true


func returns_null_for_unknown_definition() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	registry.load_content()
	expect_true(registry.get_tile(&"tile.unknown") == null, "Unknown IDs have no definition")
	return true


func returns_null_config_before_loading() -> bool:
	expect_true(ContentRegistry.new().get_config() == null, "Unloaded registry exposes no config")
	return true


func protects_registered_tile_from_caller_mutation() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	registry.load_content()
	var tile: TileDefinition = registry.get_tile(&"tile.open_fields")
	tile.canonical_edges[0] = DomainTypes.EdgeType.ROAD
	expect_equal(registry.get_tile(&"tile.open_fields").canonical_edges[0], DomainTypes.EdgeType.FIELD, "Returned tile is an independent copy")
	return true


func protects_registered_config_from_caller_mutation() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	registry.load_content()
	var config: RunConfig = registry.get_config()
	config.act_placement_limits[0] = 999
	expect_equal(registry.get_config().act_placement_limits[0], 18, "Returned config is an independent copy")
	return true


func rejects_wrong_manifest_resource_type() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = registry.load_content("res://content/manifests/alpha_run_config.tres")
	expect_true(not result.is_valid, "RunConfig cannot substitute for ContentManifest")
	return true


func rejects_wrong_config_resource_type() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	var result: ValidationResult = registry.load_content(
		"res://content/manifests/alpha_content_manifest.tres",
		"res://content/manifests/alpha_content_manifest.tres"
	)
	expect_true(not result.is_valid, "ContentManifest cannot substitute for RunConfig")
	return true


func clears_content_after_failed_reload() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	registry.load_content()
	registry.load_content("res://content/manifests/alpha_run_config.tres")
	expect_true(
		not registry.is_loaded() and registry.get_tile_ids().is_empty()
		and registry.get_tile(&"tile.open_fields") == null and registry.get_config() == null,
		"Failed reload clears all previously exposed content"
	)
	return true


func loads_canonical_alpha_act_limits() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	registry.load_content()
	expect_equal(registry.get_config().act_placement_limits, [18, 22, 26], "RULE-RUN-002 defaults")
	return true


func loads_canonical_alpha_track_thresholds() -> bool:
	var registry: ContentRegistry = ContentRegistry.new()
	registry.load_content()
	expect_equal(registry.get_config().track_thresholds, [20, 40, 70, 100], "Canonical Track defaults")
	return true
