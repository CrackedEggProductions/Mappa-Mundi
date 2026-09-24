class_name RunState
extends RefCounted
## Mutable authoritative domain state; never an Autoload or a presentation Node.
## Later topology is derived from board state; lineage/history will remain separate.

var save_schema_version: int = BuildVersions.SAVE_SCHEMA_VERSION
var game_rules_version: String = BuildVersions.GAME_RULES_VERSION
var implementation_spec_version: int = BuildVersions.IMPLEMENTATION_SPEC_VERSION
var godot_version: String = BuildVersions.godot_version()
var phase: GamePhase.Type = GamePhase.Type.SETUP

var id_allocator: RunIdAllocator
var rng: RunRNG
## Unordered registries, normalized by stable ID at serialization boundaries.
var tile_copies: Array[TileCopyState] = []
var tile_locations: Array[TileLocationState] = []
## Null only for the identity/serialization foundation, before Homestead setup.
var expansion: ExpansionState = null
## Null for the preserved Phase-0/1/2 fixture/save variants.
var features: FeatureState = null
## Null for preserved pre-Trade fixtures; economic history is separate from features.
var trade: TradeState = null
## Optional only for preserved earlier-phase fixtures.
var specialists: SpecialistState = null
var relics: RelicState = null
var rewards: RewardState = null
var pending_choice: PendingChoice = null
var resolution: ResolutionState = null

## Forwarding properties prevent stale duplicate continuation metadata.
var original_seed: int:
	get:
		return rng.original_seed
var current_rng_state: int:
	get:
		return rng.current_state
var next_runtime_id: int:
	get:
		return id_allocator.get_next_id()


func _init(seed_value: int) -> void:
	id_allocator = RunIdAllocator.new()
	rng = RunRNG.new(seed_value)
