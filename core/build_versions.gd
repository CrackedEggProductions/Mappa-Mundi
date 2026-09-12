class_name BuildVersions
extends RefCounted
## Save schema and gameplay rules evolve independently (implementation spec §40).

const IMPLEMENTATION_SPEC_VERSION: int = 1
const SAVE_SCHEMA_VERSION: int = 1
const GAME_RULES_VERSION: String = "alpha-1"
const IMPLEMENTATION_PHASE: int = 2
## Legacy minimal profile remains Phase 0; Homestead explicitly declares Phase 2.
const CONTENT_IMPLEMENTATION_PHASE: int = 0


static func godot_version() -> String:
	return str(Engine.get_version_info()["string"])
