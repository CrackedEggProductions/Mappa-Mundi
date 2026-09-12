class_name ContentRegistry
extends RefCounted
## Application-wide static service, usable without an Autoload Node or any scene.
## The bootstrap owns it for now. No run state or gameplay RNG belongs here.

const ALPHA_MANIFEST_PATH: String = "res://content/manifests/alpha_content_manifest.tres"
const ALPHA_CONFIG_PATH: String = "res://content/manifests/alpha_run_config.tres"
const HOMESTEAD_MANIFEST_PATH: String = "res://content/manifests/homestead_content_manifest.tres"
const HOMESTEAD_CONFIG_PATH: String = "res://content/manifests/homestead_run_config.tres"

var _manifest: ContentManifest
var _config: RunConfig


func load_homestead() -> ValidationResult:
	return load_content(HOMESTEAD_MANIFEST_PATH, HOMESTEAD_CONFIG_PATH)


func load_content(
	manifest_path: String = ALPHA_MANIFEST_PATH, config_path: String = ALPHA_CONFIG_PATH
) -> ValidationResult:
	# Fail closed: callers cannot keep using a prior pool after a rejected reload.
	_manifest = null
	_config = null
	if not ResourceLoader.exists(manifest_path) or not ResourceLoader.exists(config_path):
		return ValidationResult.failure(&"missing_resource", "Content resource file is missing.")
	var manifest_resource: Resource = ResourceLoader.load(manifest_path)
	var config_resource: Resource = ResourceLoader.load(config_path)
	if not manifest_resource is ContentManifest or not config_resource is RunConfig:
		return ValidationResult.failure(&"wrong_resource_type", "Content resource has the wrong type.")
	var manifest: ContentManifest = manifest_resource as ContentManifest
	var config: RunConfig = config_resource as RunConfig
	var result: ValidationResult = ContentValidator.validate(manifest, config)
	if result.is_valid:
		_manifest = manifest.duplicate(true) as ContentManifest
		_config = config.duplicate(true) as RunConfig
	return result


func is_loaded() -> bool:
	return _manifest != null and _config != null


func get_tile_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if _manifest != null:
		for tile: TileDefinition in _manifest.tiles:
			ids.append(tile.definition_id)
	ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	return ids


func get_tile(definition_id: StringName) -> TileDefinition:
	if _manifest != null:
		for tile: TileDefinition in _manifest.tiles:
			if tile.definition_id == definition_id:
				return tile.duplicate(true) as TileDefinition
	return null


func get_config() -> RunConfig:
	if _config == null:
		return null
	return _config.duplicate(true) as RunConfig
