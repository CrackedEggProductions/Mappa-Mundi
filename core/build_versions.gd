class_name BuildVersions
extends RefCounted
## Save schema and gameplay rules evolve independently (implementation spec §40).

const IMPLEMENTATION_SPEC_VERSION: int = 1
const SAVE_SCHEMA_VERSION: int = 3
const GAME_RULES_VERSION: String = "alpha-playtest-r1-relic-rarity"
const IMPLEMENTATION_PHASE: int = 10
## Legacy minimal profile remains Phase 0; Homestead explicitly declares Phase 2.
const CONTENT_IMPLEMENTATION_PHASE: int = 0


static func godot_version() -> String:
	return str(Engine.get_version_info()["string"])
