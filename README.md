# Mappa Mundi

A peaceful tile-placement roguelite built with **Godot 4.x and strongly typed
GDScript**. Current implementation: **Alpha Playtest Revision 1**, after Phase 10.
Launch New Run to play all three Acts with the mouse. The authoritative engine also
runs all 66 placements, rewards, transitions and final results headlessly. Tested engine: **Godot 4.7.2 stable**; no C# code, third-party
plugins, or external services are required.

## Alpha Playtest Revision 1

This is a core-loop revision after the first human Phase-10 playtest, not Phase 11.
The canonical Complete Rules and Implementation Specification have been rewritten
for rules version `alpha-playtest-r1`, save schema **2**. Older active-run development
saves are rejected; no migration or player-facing Save/Continue UX is included.

New Run places Founding plus an eight-tile environmental River before shuffling the
**45-copy player bag** and selecting the Act-I Charter. The River has five Runs, two
Bends and one End, selected from 24 valid templates with one RunRNG choice. The saved
board is authoritative; loading never regenerates it. Pure River pieces, Open Fields
and Road End are excluded from player inventory/reward/rescue pools.

Road Junctions terminate separate physical Roads while connecting Trade Networks.
Their three Road sockets create no Road component, length or tile-scoring credit.
Riverside Hamlet adds a Settlement bank to an occupied River Run; Woodland River adds
Forest banks to an occupied River Bend. Both preserve River and use one normal turn.

River no longer completes or scores. Forest completion gains +1 Ecology per newly
paid distinct River contact, preserving base history. Riverkeeper works River-touching
Forest; Harbormaster works River-touching Settlement and counts same-River Settlements
and Ports. Generic Stewards cannot occupy River. Three affected Charters use interaction
creation/current counts. River Stewardship awards the River milestone for genuine
Settlement/Forest completion touching three River tiles.

The opening camera frames the environment; interaction previews target occupied
squares. River/Junction inspection explains the revised mechanics. Parchment Charter
and Grand Charter panels use dark ink through the correct RichTextLabel theme property.

See [the revision playtest checklist](docs/ALPHA_PLAYTEST_R1.md). The diagnostic script
`tests/scenarios/revision_completion_diagnostic.gd` measures a documented deterministic
closure heuristic. The [100-seed report](docs/PLAYTEST_REVISION_1_DIAGNOSTIC.md) records
100% with at least one Act-I completion, median 6 and mean 5.72; these are not human
completion rates. Phase-specific
sections below retain earlier architectural milestones; the revised canonical rules
supersede their old balance/lifecycle descriptions.

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

The default scene opens New Run with an optional integer seed. Select a hand tile,
choose a highlighted target or exact option, then Confirm. Rotate and Cancel remain
local previews. Store sends a hand tile to Reserve; Survey spends a charge. Required
choices appear in a blocking panel. Every decision has a visible mouse control.

Wheel zooms; middle/right drag pans; Center / Fit Board frames the map. Optional
shortcuts: 1/2/3 select, Q/E rotate, Enter confirms, Escape cancels, F fits, F11
toggles fullscreen. The window is resizable; layout targets 1920×1080 and remains
usable at 1280×720. [Playtest checklist](docs/PHASE_10_PLAYTEST.md) describes the
full run and current limitations. Save & Quit/Continue UX remains Phase 11.

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
are implemented, including separate Trade Networks and full-network Road scoring.
Player-facing Save/Continue remains deferred.

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
unregistered behaviors, and content outside the Phase-0 pool. The historical
Phase-0 profile keeps empty Relic, Specialist and Charter rosters.
The preserved Phase-7 profile registers exactly eight passive Specialist definitions.
The current Phase-9 profile adds the exact ten Relics and nine Charters; centralized
domain services own all behavior. Earlier profiles remain regression fixtures.

The separate `homestead_content_manifest.tres` and `homestead_run_config.tres`
retain the legacy 22-design catalogue, with 16 player designs in the exact 45-copy
starting bag, eight setup-only River copies beside Founding, and the revised emergency set. Load this profile with
`ContentRegistry.load_homestead()`. The original minimal profile remains available
for Phase-0 regressions; the bootstrap loads the complete Phase-9 content profile with Revision-1 rules. Both profiles reject
unsupported content.
Canonical base orientations and explicit internal relationships are documented in
[the content notes](content/tiles/homestead/README.md).

## Headless Homestead play

```gdscript
var content: ContentRegistry = ContentRegistry.new()
assert(content.load_phase_nine().is_valid)
var state: RunState = HomesteadRunFactory.create(12345, content)
var copy_id: int = state.expansion.hand[0]
var options: Array[PlacementOption] = PlacementQueryService.query_for_copy(
    state, content, copy_id
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

Earlier profiles stop at the deferred Act boundary. The Phase-9 profile resolves
outgoing Charter rewards, transitions and seeding before the pending hand refill. Reserve-impossibility assessment conservatively returns
`NOT_PROVABLY_IMPOSSIBLE`; later systems must expand proof before any automatic removal.

See [implementation progress](IMPLEMENTATION_PROGRESS.md) for verification and
remaining limits. Phase 8 requires a new instruction.

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
Development effects use that same snapshot after base scoring; structured child
audit events drain FIFO after the scoring batches. Specialist effects use the same
snapshot after Developments, then completing pieces return. Relic and threshold
stages remain deferred hooks without gameplay effects or rewards.

Settlement support uses explicit internal Field/River contact and reachable
matching edge sockets; it never infers support from an unrelated feature elsewhere
on an adjacent tile. Homestead resources explicitly mark same-tile Settlement/Field
meeting. Historical support uses persistent board-base IDs separately per category
and lineage. Road scoring adds +1 per new Road component and +2 per eligible
Settlement in the full current Trade Network. Explicit legacy fixtures with null
Trade state continue to exercise the earlier tile-only scoring boundary.

Feature saves include components, ancestry, scoring sets, completion facts,
enclosures, structured audit records and Tracks. Loading reconstructs and validates
topology without reconciling lineages, scoring, RNG draws or allocations. Optional
feature state preserves the earlier fixture variant; current board records now
require explicit Field-support and geometry-revision fields. Older shapes are
rejected rather than silently migrated. There is no disk-save migration service.

The fixture-only geometry rewrite helper lives under `tests/fixtures/`; it preserves
physical identity, exact occupied-edge matching and all stable-state invariants.
Monastery and Abbey are playable physical overlays with persistent enclosures.
Legacy enclosure fixtures with Development ID zero remain supported. Urban
Expansion, Bridge and Rewilding use authoritative physical commands and effective
geometry.

After editor import, run the standalone headless demonstration from this root:

```sh
XDG_DATA_HOME="$PWD/builds/test-userdata" \
XDG_CONFIG_HOME="$PWD/builds/test-config" \
XDG_CACHE_HOME="$PWD/builds/test-cache" \
godot --headless --path . --script res://tests/replay/phase_three_demo.gd
```

The full `./tests/run_tests.sh` remains the acceptance command and checks engine
diagnostics as well as test assertions. Phase 3 has **274 tests** and **88 checked
scripts** at the Phase-3 checkpoint. Its seed-16 demonstration completes all four tracked feature types in
twelve placements and resumes identically after loading at placement five.

## Trade Network inspection

Normal Homestead setup initializes `state.trade`. A physical Road Feature and an
economic Trade Network retain separate identities. Only explicit Road–Settlement
access joins the economic graph; adjacency and completion status do not grant
access. Settlement hubs propagate connectivity through other unfinished Roads
and Settlements immediately.

`TradeNetworkService.rebuild(state)` returns deterministic `CurrentTradeNetwork`
values with sorted Road/Settlement lineage IDs, access links and historical network
IDs. Queries include `network_for_road`, `network_for_settlement`,
`settlements_reachable_from_road`, `same_network`, `settlement_count`,
`get_ancestry_closure` and `is_ancestor`.

Normal placement reconstructs feature lineages, reconciles Trade history, then
captures simultaneous completions before calculating any base score. Ordinary
network growth retains identity; merger, split and reconnection preserve ancestry.
Topology changes alone award nothing. Road payment history belongs to the Road
lineage and survives all economic changes and physical lineage mergers. If any
ancestor of a current Settlement already paid that Road, it cannot pay again.

Network saves persist genealogy, audit records, reconciliation metadata and
per-Road payments. Loading rebuilds connectivity purely and verifies the saved
identities without reconciling, allocating, scoring, emitting events or using RNG.
The current save shape requires explicit Trade snapshot fields on completion
records; older shapes are rejected rather than silently migrated. The optional
null-Trade fixture variant remains supported. There is no player migration flow.

`TradeState.authorized_links` is an extension input for later economic rules.
Phase 4 accepts only controlled fixture contributions there; ordinary access comes
from board metadata. Developments consume these networks without altering their
topology. Ferry Rights, Bridge and Urban Expansion remain unimplemented. Future rule layers must maintain valid current lineage endpoints
and reconcile after adding or removing their authorized links.

Run the standalone Phase-4 demonstration after editor import:

```sh
XDG_DATA_HOME="$PWD/builds/test-userdata" \
XDG_CONFIG_HOME="$PWD/builds/test-config" \
XDG_CACHE_HOME="$PWD/builds/test-cache" \
godot --headless --path . --script res://tests/replay/phase_four_demo.gd
```

It combines twelve seeded legal placements and save/load continuation with
controlled transitive-network, re-completion, merger and split/reconnection
scenarios. These fixture actions do not expose future gameplay commands.

Phase-4 acceptance: **329 tests passed, 0 failed; 102 scripts parsed without
diagnostics**, including all 274 prior tests. See implementation progress for
exact logs, genealogy and anti-farming evidence.

## Developments and Upgrades

Load `ContentRegistry.load_phase_five()` to expose the 22 existing Expansion
designs and nine Development/Upgrade designs. `load_homestead()` preserves the
historical 22-design catalogue. Both now use the revised 45-copy player bag,
including the two explicit Act-I River overlay exceptions.
Development acquisition is currently controlled by scenario helpers; rewards,
automatic seeding and Act transitions remain deferred.

`PlacementQueryService.query_for_copy(state, content, copy_id)` dispatches by the
physical copy's class. Pass the selected option's mode, coordinate, rotation,
host lineage, River lineage, target Development copy, enclosure ID, revisions
and signature into `PlaceTileCommand`. Rotation is zero for overlays. Distinct
Port Rivers and Upgrade targets are distinct intents; commands revalidate all
fields before moving a copy or consuming a placement.

Each `BoardCellState.developments` array currently permits one physical overlay.
The overlay retains its family, stage, host, placement history and replacement
identity. `DevelopmentService.families` includes only Settlement-hosted families;
`current_class` reports current qualification separately from historical highest
class. Base geography stays authoritative and visible to future presentation.

Housing, Mill, Market, Port, Forester's Lodge and Town Square resolve only on a
genuine relevant completion or their own placement into a currently complete
host. `DevelopmentEffects` captures shared primitive facts before scoring,
calculates each effect from the immutable snapshot, and applies the batch after
base gains. New placements never retrigger existing peers. Monastery/Abbey track
separate enclosure stages; Abbey/Grand Market permanently remove their physical
prerequisites while preserving history and family identity.

Saves require explicit overlay arrays and frozen Development/enclosure completion
facts. Earlier board save shapes are rejected rather than migrated. Loading only
decodes and validates: it never reconciles hosts, resolves effects, draws tiles,
emits events, allocates IDs or consumes RNG. Current null-feature/Trade fixture
variants remain supported.

Run the Phase-5 demonstration after editor import:

```sh
XDG_DATA_HOME="$PWD/builds/test-userdata" \
XDG_CONFIG_HOME="$PWD/builds/test-config" \
XDG_CACHE_HOME="$PWD/builds/test-cache" \
godot --headless --path . --script res://tests/replay/phase_five_demo.gd
```

It combines a seed-16 inventory, legal Development queries, completed-host effects,
physical Upgrade replacement and identical save/load continuation with controlled
Port, enclosure, merger and shared-batch scenarios. The full acceptance command
remains `./tests/run_tests.sh`, including script diagnostics and all earlier tests.

Phase-5 acceptance: **447 tests passed, 0 failed; 117 scripts parsed without
diagnostics**. [PR #3](https://github.com/CrackedEggProductions/Mappa-Mundi/pull/3)
was merged into main at `8d0074df5bda0e03edb49d077fd07b0af8d1b0f2`.


## Headless Transformations

Load `ContentRegistry.load_phase_six()` for the 34-design profile. The initial
Homestead bag now contains exactly 45 player copies, including River overlays; controlled scenarios acquire
Urban Expansion (Act II), Bridge and Rewilding (Act III) directly. There are no
reward offers, automatic seeding or Act transitions.

`PlacementQueryService.query_for_copy(state, content, copy_id)` returns complete
Transformation intents. Copy the option's ordinary identity/revision fields plus
`transformation_mode`, `target_base_copy_id`, and `transformation_signature` to
`PlaceTileCommand`, then execute through `RulesEngine`. The scenario helper
`tests/fixtures/phase_six_factory.gd` demonstrates that mapping. Preview plans are
read-only information; the engine revalidates against current authoritative state.

Urban Expansion and Rewilding expansion become new physical bases. Bridge and
occupied Rewilding retain the base and add physical Transformation instances.
Effective edges, Field interiors, per-component origin Acts and exact rewrite
histories persist independently of original Resources and Development overlays.
Completion effects use one snapshot after every rewrite and topology change.

Run the deterministic Transformation demonstration after editor import:

```sh
XDG_DATA_HOME="$PWD/builds/test-userdata" \
XDG_CONFIG_HOME="$PWD/builds/test-config" \
XDG_CACHE_HOME="$PWD/builds/test-cache" \
godot --headless --path . --script res://tests/replay/phase_six_demo.gd
```

Phase-6 canonical rulings distinguish target shape from current rewrite legality.
A Rewilded straight River Run retains Bridge's underlying shape prerequisite, but
Forest banks cannot become Road: the command rejects them with
`bridge_effective_edge_not_rewriteable`. Abbey depends on its persistent enclosure,
not continued Field geography, so otherwise-legal Rewilding preserves its copy,
host and stage history. Mill and ordinary Monastery remain Field-dependent.
See implementation progress for the resolved rule references and verification.

## Stewards, Specialists and pending choices

`ContentRegistry.load_phase_seven()` loads the historical Specialist-only profile, retaining
all Phase-6 tiles and exactly eight trainable roles. `HomesteadRunFactory.create`
then starts two available generic Stewards with stable IDs. Earlier manifests
remain explicit historical fixture profiles without Specialist state.

A successful placement may leave `state.phase == PENDING_CHOICE`: the board and
placement count are already committed, while scoring and hand refill wait. Read
`state.pending_choice.options` for authoritative local piece/target combinations.
Resolve exactly one option or decline through `RulesEngine.execute`:

```gdscript
var choice: PendingChoice = state.pending_choice
if choice != null and choice.kind == &"specialist_assignment":
    # A client may instead submit one exact offered piece/target combination.
    assert(RulesEngine.execute(state, content,
        ResolveSpecialistAssignmentCommand.new(choice.choice_id, 0, -1, 0, true)
    ).is_valid)
```

The phase blocks other placement/Reserve/Survey commands until resolved. A saved
`ResolutionState` owns the immutable completion snapshot and deferred immediate
Development effect. Load validates this continuation without replaying anything.
Reserve placement never refills the active hand; final-Act placement finishes its
choice and consequences before Charter evaluation, Act transition or finalization.

Reward integrations may submit `RecruitStewardCommand` (hard cap three) or
`RequestSpecialistTrainingCommand.new(piece_id)`. Training persists the exact
filtered uniform offer; resolve it with `ResolveSpecialistTrainingCommand` and an
offered role ID. Training preserves physical identity and existing commitment.
If no generic piece can train, request piece ID zero to obtain a persisted typed
normal Tile Reward handoff in `state.specialists.deferred_rewards`. These are reward
integration APIs, not a complete reward entitlement/threshold system.

Cartographer/Forester track stable new component IDs, not size differences.
Components seen elsewhere before a later merger never become qualifying growth.
Training either growth role in place starts growth credit at conversion while
retaining the original assignment Act/index; pre-training growth earns no bonus.
Generic Stewards may occupy an unfinished Monastery-family enclosure at either
Monastery or Abbey stage; none of the trained alpha roles may occupy it. This
Abbey behavior is explicitly human-confirmed. New assignments still require a
normal local opportunity and an unfinished enclosure.

Run the standalone Specialist demonstration after import:

```sh
godot --headless --path . --script res://tests/scenarios/specialist_demo.gd
```

It exercises live commands and prints roster/status, legal training pools,
persisted assignment offers, growth IDs, completion gains and returned pieces.

## Phase 8: Relics and serializable rewards

Load `ContentRegistry.load_phase_eight()` for the preserved 34-design, eight-Specialist,
ten-Relic profile. Earlier profiles remain available for regression fixtures.
`RulesEngine` remains the command boundary. The new commands resolve persisted
reward selections, Compass physical-copy selections, sequential Grand Survey
removals, and same-piece Relay choices.

A committed placement resolves the frozen base/Development/Specialist batch and
returns, then optional Relay assignments, frozen Relic effects, Relic milestones,
and finally Realm Track thresholds. Only after every reward chain resolves does
the pending hand slot draw. Milestones use Settlement/Road/Forest/River order;
thresholds use Population/Trade/Culture/Ecology order, lower threshold first.
20/40/70/100 yield Tile Reward/training/Relic/Major Reward respectively.

Tile offers use sorted unlocked content, without a board-playability filter.
Normal quantities are 3 Basic, 2 Specialized/Hybrid, 2 ordinary Development/Act-II
Upgrade, and 1 Major/Rare. Masterwork grants three copies. Every reward allocates
physical copies, records their source and randomizes the whole remaining bag.
Recruit, Masterwork, Relic Cache followed by a Tile Reward, and Grand Survey use
the same queue. The existing training fallback now grants a real Tile Reward.

Relic state retains slot/acquisition order, exhausted lifetime history, replacement
history and once-per-Act uses. Capacity is 2/4/5. No inactive inventory exists.
Boundary Stones persists a hard Field/Forest seam; Compass persists inspected
physical copies; Satchel generalizes Reserve to two independent slots. Mixed-Use
allows only Housing/Market families. Ferry Rights extends the existing Trade
Network graph and can split it on removal without retroactive scoring. Village
Green, Historic Routes and both Legacy effects use immutable completion facts.
Relay reuses normal eligibility and assignment, with only the returned piece.

Zero Legacy base payout leaves those base elements unpaid, consistent with the
canonical paid-history rules. Genuine completion, other effects and size records
still occur. A later qualifying genuine completion may pay the previously unpaid
elements; paid elements cannot score again.

Masterwork eligibility follows the accepted canonical ruling: Specialized/Hybrid,
Major/Rare, and Upgrades including Abbey. Basic Expansions and ordinary Developments
are excluded. Existing Act unlocks still apply; immediate playability does not.
Masterwork grants three copies even when the Upgrade's normal reward grants two.

Useful verification/diagnostics:

```sh
./tests/run_tests.sh
godot --headless --path . --script res://tests/scenarios/relic_reward_demo.gd
```

The demonstration prints capacity, equipped order/use state, current modifiers,
Ferry links, exact offers, threshold/milestone queues and reward-copy IDs before
running command-level continuation scenarios. `RelicRules.refresh_act()` and
Act-frozen reward eligibility now support the Phase-9 Act pipeline. Presentation
dialogs remain outside the implemented headless rules layer.


## Charters, Acts and complete runs

Use `ContentRegistry.load_phase_nine()` with `HomesteadRunFactory.create()` for the
current alpha. Setup initializes the civilization and pieces, shuffles the starting
bag, selects one Act-I Charter, then draws the opening hand. Selection uses sorted
canonical pools and the sole RunRNG stream.

`CharterRules.evaluate(state, content, id)` returns typed `CharterProgress` with
numeric condition keys, targets, satisfaction, current-state/history sources and
stable witness IDs. All nine evaluators require fulfillment before exceed. Current
Trade Network queries include Ferry Rights; genuine completion history survives
lineage mergers without counting inherited records twice. Upgrades retain their
base Development families.

Use `visible_ordinary()` and `visible_grand()` for future presentation. Act II
selects its ordinary Charter and then the Grand Charter once. Until all consequences
of normal placement 11 finish, the Grand query exposes only its forecast. Exact
reveal uses no RNG and waits through assignment, rewards and bonus chains.

`ActRules` persists the fourteen canonical transition steps in `ActTransitionState`.
Outgoing rewards use the outgoing Act pool and capacity. Only afterward do Act,
capacity, Survey and Relic refresh, unlocks, seeding, shuffle, information selection,
counter reset and refill occur. Act II adds Market/Port/Urban Expansion/Town Square/
Abbey twice each (10 copies); Act III adds Bridge/Rewilding/Grand Market twice each
(6 copies). All are physical identities with incoming-Act acquisition provenance.
A saved transition can resume through `ResumeActTransitionCommand` without replaying
completed steps. Normal reward commands resume pending transition rewards.

The generic `BonusPlacementRules.enqueue()` effect hook retains FIFO bonus work.
Bonus input permits placement only, reuses the full consequence pipeline, and does
not consume a normal placement. Its own hand refill precedes the next bonus; the
original normal-placement refill remains deferred through the chain and transition.
No current alpha content grants bonus placements.

Act III normal placement 26 finishes all consequences and rewards, then stores a
`RunResult` and enters `RUN_COMPLETE` without a final hand refill. Score is the sum
of all four uncapped Tracks. No-victory, Victory and Exemplary Victory are separate
outcomes. Final statistics preserve historical size records, Relics, Specialist
training, Charter evaluations and seed. Completed runs reject gameplay commands.

Accepted Grand Charter rulings: Great Metropolis requires its fulfillment witness
to be currently completed at size 8+; its additional size-10 exceed witness may be
any current Settlement. Merchant Republic accepts a current Road lineage with
genuine completion history even after reopening. These rulings are recorded in
the canonical Complete Alpha Rules.

`PhaseNineDebug.inspect(state, content)` exposes read-only Charter progress,
transition state, unlock pool, seed records, counters and final statistics. Its
optional `reveal_secret=true` flag is explicitly for debug inspection; ordinary
visibility queries never expose unrevealed exact Grand requirements.

```sh
./tests/run_tests.sh
godot --headless --path . --script res://tests/scenarios/three_act_demo.gd
```

The complete-run fixture controls tile acquisition and one initial training reward;
all placements, scoring, selections, rewards and transitions use real rules. Five
66-placement runs cover failure, Victory, Exemplary Victory, deterministic replay
and save-at-every-boundary replay. This is an integration proof, not a balance or
human-play optimization claim. Phase 10 adds the playable interface described
below. Save & Quit/Continue UX and export acceptance remain later phases.


## Playable presentation architecture

The existing `presentation/scenes/bootstrap.tscn` is the default entry and gameplay
scene. `GameController` owns one headless-compatible `GameSession`, which delegates
commands unchanged to `RulesEngine`. `ResolutionResult` captures validation,
ordered audit deltas and Track changes after synchronous rules resolution.
Presentation never determines topology, legality, scoring, offers or Act order.

`BoardView` renders signed grid coordinates as 192-pixel `TileView` nodes beneath a
Camera2D in a SubViewport. World parchment has no gaps/card shadows. Base artwork
uses exact quarter turns. Effective geometry overrides misleading transformed art;
Development/Upgrade badges and assigned-piece markers draw above it. Legal targets
and ghosts are separate, disposable layers. Inspection uses authoritative feature
and Trade Network queries.

`TileArtRegistry` caches thirteen approved production anchors and seven reference
images. Founding and Road End use clear canonical fallbacks; the twelve Development,
Upgrade and Transformation designs have generated thumbnails/badges. The source
archive is unchanged. [Exact mappings](presentation/assets/README.md) include source
orientation corrections. No image generation or seam-polish work occurred.

`PendingChoicePresenter` supports all eleven current kinds, including training-piece
selection and sequential Grand Survey. Buttons preserve saved order, IDs and state
revision. A stale choice/preview is rejected by the engine and the view resynchronizes.
Required choices block normal input; mouse double clicks cannot accept a fresh next
offer accidentally. Assignment and Relay expose only persisted legal targets.

`PresentationQueries` supplies HUD/inspection text and frozen final statistics.
Grand secrecy uses `visible_grand()` exclusively. Transition/reveal notices describe
completed authoritative events; dismissing them changes no run state. Results retain
the map, allow returning to statistics and starting a fresh run, and disable gameplay.

Run the independent presentation tests:

```sh
./tests/run_presentation_tests.sh
godot --headless --path . --script res://tests/scenarios/presentation_demo.gd
godot --path . --script res://tests/scenarios/presentation_mouse_smoke.gd
```

The controller harness plays two complete natural-bag runs through actual Confirm
and choice handlers without injected tiles or direct RunState changes. Graphical
mouse-event smoke coverage supplements it. Neither is a claim that a human completed
the manual checklist. Gameplay regressions still run independently with
`./tests/run_tests.sh`; no textures or presentation scenes are required by rules.

Simple fallback art, badges, typography and cue polish remain alpha quality.
Save/Continue/recovery UX and release exports remain later phases. Runtime image
loading reads the ignored art archive; Phase-12 packaging must explicitly stage or
include the selected sources. The presentation branch is left unmerged for review.
