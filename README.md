# Mappa Mundi

A peaceful tile-placement roguelite built with **Godot 4.x and strongly typed
GDScript**. Current implementation: **Phase 3 — feature topology, lineage, completion and base scoring**.
Act-I-style play runs headlessly; the application remains a minimal bootstrap. Tested engine: **Godot 4.7.2 stable**; no C# code, third-party
plugins, or external services are required.

## Specifications

The five historical design documents remain at the project root with their
original names. Authority, in order:

1. [Complete Alpha Rules](Carcassonne_Roguelite_Alpha_Complete_Rules.md): gameplay.
2. [Alpha Implementation Specification](Carcassonne_Roguelite_Implementation_Specification.md):
   architecture, ownership, serialization, testing and phase order.
3. [Mappa Mundi Visual Design v0.2](Mappa_Mundi_Visual_Design_Specification_v0.2.md): presentation only.
4. Core Design Bible, Tile Design Specification, and Relics/Specialists Prototype
   Specification: context only; superseded rules do not apply to the alpha.

If the two authoritative documents disagree on gameplay, Complete Alpha Rules wins.

## Launch

From this project's directory (on this machine, `/home/rochelle/Jane/MappaMundi`):

```sh
godot --editor --path .
godot --path .
```

The bootstrap loads and validates static content and shows a short status screen.
The window is resizable; F11 toggles fullscreen. The interface baseline is
1920×1080, with a 1280×720 initial/minimum window size.

## Tests

```sh
./tests/run_tests.sh
```

This project-owned Bash wrapper imports a fresh checkout, checks GDScript syntax
and warnings, then runs the headless suites without the bootstrap scene. It fails
on nonzero engine status or logged engine/script errors and warnings. Generated
test settings, data and logs stay in ignored `builds/`. Override `GODOT_BIN` if
your executable is named `godot4` or installed elsewhere.

The underlying Godot runner can also be invoked after editor import:

```sh
godot --headless --path . --script res://tests/test_runner.gd
```

Use the wrapper for acceptance/CI: Godot can report errors inside nested calls
without propagating a failed process status. Runner self-checks deliberately fail:

```sh
./tests/run_tests.sh --self-test-failure
./tests/run_tests.sh --self-test-runtime-error
```

Both must exit **1**. The ordinary suite must exit **0**. The editor import uses
local editor sockets; a sandbox that blocks them must permit the verification
process to run with those capabilities. No network service is a game dependency.

## Structure and ownership

- `core/`: typed run state, IDs, RNG, versioned JSON, fingerprints and validation. Reserved
  subdirectories match the implementation specification's later-phase modules.
- `content/`: passive typed Resource definitions and explicit `.tres` manifest/config.
- `autoload/content_registry.gd`: scene-independent static service. The bootstrap
  owns a `RefCounted` registry for now; no gameplay Autoload exists.
- `presentation/`: minimal application scene; reserved view/UI directories.
- `tests/`: project-owned framework, unit/integration suites, and future scenario/replay slots.
- `debug/`, `assets/`: reserved infrastructure/content locations.
- `export_presets.cfg`: Linux and Windows desktop presets. Export smoke tests
  belong to Phase 12 and have not been performed.

The domain owns gameplay state. Future views submit commands and display results.
Current board/derived topology and persistent lineage/history remain separate
responsibilities. Sparse placement, bag/hand, Reserve and Survey are implemented.
Connected feature topology, persistent scoring history and Phase-3 base scoring
are implemented. Trade Networks and player-facing Save/Continue remain deferred.

## Domain usage

Construct `RunState.new(seed)` explicitly. Its `id_allocator` and `rng` own the
continuation cursor and RNG state; RunState getters forward those values rather
than retaining duplicate snapshots. No scene or Autoload is required.

`RunSerializer.serialize(state, loaded_content_registry)` returns a typed result
with `validation` and `json_text`. `RunSerializer.deserialize(json_text, registry)`
returns `validation` and a fresh `state` only after all checks pass. These APIs
do not write files, trigger gameplay, or implement autosaving.

The JSON envelope includes schema/rules/spec/engine metadata. Signed 64-bit
IDs, seeds, RNG state and counters use canonical decimal strings to avoid
JSON numeric precision loss. Unsupported versions, engine builds, fields and
corrupt references are rejected; there are no silent migrations or repairs.

`StateNormalizer.normalize(state)` and `.fingerprint(state)` operate on
invariant-valid state. They sort unordered registries by ID and produce canonical
JSON / SHA-256 without changing the live state. Diagnostic RNG reason logs are
excluded. Ordered bag and hand containers retain their order; sparse board cells,
removed IDs and internal feature metadata normalize independently of insertion order.

`InvariantValidator.validate(state, registry)` returns an `InvariantReport` with
typed issues; `assert_valid(...)` reports internal corruption loudly. Phase-1
fixtures use archived physical copies with one ID-based `REMOVED_FROM_RUN`
location each in `SETUP`, with null `expansion`. Initialized Homestead runs carry
typed `ExpansionState` and `FeatureState`; validation covers physical zones,
reconstructed topology, lineage ancestry, completion history and cumulative Tracks.

RNG helpers provide bounded integer/index selection, a copied Fisher–Yates shuffle
of IDs and selection from unique, lexically ordered definition IDs. All require
the same run-owned stream. The diagnostic operation counter counts public helper
calls, not internal draws. Seed is restored before current RNG state, following
[Godot's RNG contract](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html).

## Static-content boundary

`alpha_content_manifest.tres` explicitly declares Phase 0 and contains only
`tile.open_fields` and `tile.straight_road`. They are canonical passive samples,
not a starting bag. `alpha_run_config.tres` holds the canonical 18/22/26 Act limits
and 20/40/70/100 thresholds as tunable data.

`ContentRegistry.load_content()` checks file/type availability, validates the
manifest/config, and publishes copies only after success. Rejected reloads clear
the registry. ID queries use explicit lexical string ordering. Consumers receive
independent Resource copies so they cannot mutate the registered definitions.

The validator rejects malformed samples, duplicates, invalid geometry/enums/Acts,
unregistered behaviors, and content outside the Phase-0 pool. Relic, Specialist
and Charter Resource classes are skeletons with empty manifest rosters. No
gameplay behavior is registered yet; blank behavior IDs mean passive data only.

The separate `homestead_content_manifest.tres` and `homestead_run_config.tres`
provide all 21 Act-I Expansion designs, the Founding Tile, exact 55-copy starting
composition, hand/Reserve capacities and emergency set. Load this profile with
`ContentRegistry.load_homestead()`. The original minimal profile remains available
for bootstrap and Phase-0 regressions. Both profiles reject unsupported content.
Canonical base orientations and explicit internal relationships are documented in
[the content notes](content/tiles/homestead/README.md).

## Headless Homestead play

```gdscript
var content: ContentRegistry = ContentRegistry.new()
assert(content.load_homestead().is_valid)
var state: RunState = HomesteadRunFactory.create(12345, content)
var copy_id: int = state.expansion.hand[0]
var tile: TileCopyState = PhysicalTileRules.find_copy(state, copy_id)
var options: Array[PlacementOption] = PlacementQueryService.query(
    state.expansion.board, content.get_tile(tile.definition_id), copy_id,
    state.expansion.state_revision
)
if not options.is_empty():
    var option: PlacementOption = options[0]
    var intent: PlaceTileCommand = PlaceTileCommand.new(
        copy_id, TileLocationState.Kind.ACTIVE_HAND, option.coordinate, option.rotation
    )
    assert(RulesEngine.execute(state, content, intent).is_valid)
```

All normal mutations use typed commands through `RulesEngine.execute`: placement,
`ReserveTileCommand`, `SurveyTileCommand`, and free `CycleDeadHandCommand`.
The engine performs draws and one qualifying full-hand cycle after resolution.
A redraw that is still dead remains eligible for another free cycle; no unbounded
redraw loop runs inside a command. Reserve is ignored by dead-hand/global-stalemate
queries and remains untouched. An individual unplayable tile is never auto-cycled.

The full suite includes a scripted seeded sequence with rotation, Reserve, Survey,
placements and mid-sequence save/load followed by identical continued play.
`RunSerializer` includes optional Expansion state with explicit coordinate pairs,
rotated sockets/relationships, ordered zones, counters and pending refill. Loading
never plays a command or draws a tile. Schema 1 retains the original foundation
variant alongside the initialized Expansion variant; unknown fields still fail.

At Act-I placement 18 the engine stops in `RESOLVING_ACT_TRANSITION`, retaining a
pending hand refill when applicable. Act transitions and their rewards are not
implemented. Reserve-impossibility assessment conservatively returns
`NOT_PROVABLY_IMPOSSIBLE`; later systems must expand proof before any automatic removal.

See [implementation progress](IMPLEMENTATION_PROGRESS.md) for verification and
remaining limits. Phase 4 requires a new instruction.

## Feature inspection and scoring

`HomesteadRunFactory.create(seed, content)` initializes the four Founding feature
components and lineages after constructing the deterministic physical inventory.
Each subsequent normal placement resolves features before hand refill.

`TopologyService.rebuild(state)` is a pure full reconstruction returning typed
`CurrentFeature` values: feature type, component IDs, occupied coordinates, open
exit count and persisted lineage ID. It consumes no RNG or runtime IDs. Views can
inspect this result and `state.features` without becoming gameplay authority.

Persistent components retain independent origin metadata. New geometry creates
lineages; ordinary growth and reopening retain identity; merging creates a
descendant with sorted parent IDs and the union of ancestral scoring sets.
`LineageService.is_ancestor(state, ancestor_id, lineage_id)` and
`get_ancestry_closure(state, lineage_id)` expose that history.

`FeatureScoringService.capture(...)` produces a deeply owned, read-only shared
`CompletionSnapshot`. `calculate(snapshot)` reads only those frozen facts. All
base gains are calculated before any completion updates Tracks or scoring sets;
structured child audit events drain FIFO after the batch. Later effect categories
are explicit extension stages and currently produce no effects or rewards.

Settlement support uses explicit internal Field/River contact and reachable
matching edge sockets; it never infers support from an unrelated feature elsewhere
on an adjacent tile. Homestead resources explicitly mark same-tile Settlement/Field
meeting. Historical support uses persistent board-base IDs separately per category
and lineage. Road scoring is **tile Trade only**; the +2 per network Settlement
bonus is deliberately absent until Phase 4.

Feature saves include components, ancestry, scoring sets, completion facts,
enclosures, structured audit records and Tracks. Loading reconstructs and validates
topology without reconciling lineages, scoring, RNG draws or allocations. Optional
feature state preserves the earlier fixture variant; current board records now
require explicit Field-support and geometry-revision fields. Older shapes are
rejected rather than silently migrated. There is no disk-save migration service.

The fixture-only geometry rewrite helper lives under `tests/fixtures/`; it preserves
physical identity, exact occupied-edge matching and all stable-state invariants.
There is no playable Transformation or Monastery command. A deferred enclosure
uses Development ID zero and supports testing its eight-neighbor completion.

After editor import, run the standalone headless demonstration from this root:

```sh
XDG_DATA_HOME="$PWD/builds/test-userdata" \
XDG_CONFIG_HOME="$PWD/builds/test-config" \
XDG_CACHE_HOME="$PWD/builds/test-cache" \
godot --headless --path . --script res://tests/replay/phase_three_demo.gd
```

The full `./tests/run_tests.sh` remains the acceptance command and checks engine
diagnostics as well as test assertions. Phase 3 has **274 tests** and **88 checked
scripts**. Its seed-16 demonstration completes all four tracked feature types in
twelve placements and resumes identically after loading at placement five.
