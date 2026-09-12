class_name ContentManifest
extends Resource
## Explicit content pool. Phase 0 is a loading fixture, not a playable Homestead.

@export var manifest_id: StringName = &""
@export var implementation_phase: int = 0
@export var game_rules_version: String = ""
@export var tiles: Array[TileDefinition] = []
@export var relics: Array[RelicDefinition] = []
@export var specialists: Array[SpecialistDefinition] = []
@export var charters: Array[CharterDefinition] = []
