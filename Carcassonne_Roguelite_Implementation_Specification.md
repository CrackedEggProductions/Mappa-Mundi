# Carcassonne Roguelite — Alpha Implementation Specification

**Status:** Canonical engineering handoff for the first playable alpha  
**Target engine:** Godot 4.x  
**Language:** GDScript  
**Primary target platforms:** Windows and Linux desktop  
**Implementation-spec version:** 1  

---

# 0. Authority, Purpose, and Scope

## 0.1 Source-of-truth hierarchy

This document specifies **how to implement** the game. It does not replace the gameplay rules.

For the alpha, authority is:

1. **`Carcassonne Roguelite — Complete Alpha Rules Specification`** — canonical authority for gameplay behavior.
2. **This Implementation Specification** — canonical authority for engineering architecture, state ownership, serialization, testing, presentation boundaries, and implementation conventions.
3. Older Core Design Bible / Tile Design / Relics & Specialists prototype documents — design history and broader future direction only.

If this document accidentally describes gameplay behavior that conflicts with the Complete Alpha Rules Specification, **the Complete Alpha Rules Specification wins**.

## 0.2 Alpha goal

Implement a stripped-down but complete three-Act playable alpha capable of executing every rule in the Complete Alpha Rules Specification, including:

- one persistent board across Acts I–III;
- the complete 18 / 22 / 26 normal-placement cadence;
- Expansion, Development, Upgrade, and Transformation play;
- feature completion, reopening, merging, and persistent history;
- transitive Trade Networks distinct from physical Road Features;
- Realm Tracks, thresholds, rewards, milestones, Relics, Stewards, and Specialists;
- Act I and Act II Charters plus Grand Charter forecast/reveal/evaluation;
- deterministic seeded randomness;
- Save & Quit / Continue;
- final score and victory result;
- automated rule verification and development debug tooling.

Deferred systems remain deferred exactly as specified by the Complete Alpha Rules Specification. In particular, do **not** implement Legendary Projects, meta-progression, extra Foundations, the full future Relic/Specialist pools, advanced River reopening, or unlisted future tile families merely because older design files discuss them.

## 0.3 Core implementation principle

The architectural foundation of the alpha is:

> **Current board state determines what is true now; persistent lineage/history determines what has already scored or been accomplished.**

Do not collapse these concepts into one data structure.

---

# 1. Locked Technology Decisions

## 1.1 Engine and language

Use **Godot 4.x + GDScript**.

The alpha is desktop-first and entirely local/offline.

No external server, database, account system, cloud dependency, or online service is required.

## 1.2 Dependency policy

Godot itself is the only required runtime dependency.

Do not make the project dependent on third-party Godot plugins or gameplay frameworks. Optional editor tooling may be introduced later only if the project still opens, runs, tests, and exports without that tooling.

In particular, the automated test harness must be project-owned rather than depending on a third-party test plugin.

## 1.3 Desktop targets

Create export presets for:

- Windows desktop;
- Linux desktop.

macOS, mobile, and gamepad-first interfaces are deferred.

## 1.4 Window/UI baseline

Design the main desktop interface around **1920×1080** while remaining usable at **1280×720**.

Requirements:

- resizable window;
- windowed/fullscreen support;
- responsive Godot `Control` container layouts;
- a sensible minimum window size;
- board camera pan/zoom independent of window size.

Do not hard-code the entire UI to fixed pixel positions.

---

# 2. Architectural Boundaries

## 2.1 Rules engine is authoritative

The rules/domain layer is the sole authority over gameplay state.

The presentation layer may:

- display state;
- request legal actions;
- preview actions;
- submit player commands;
- animate resolved outcomes.

The presentation layer must **not** mutate authoritative game state directly.

A sprite moving, disappearing, rotating, or animating is never itself a rules action.

## 2.2 Headless-capable domain layer

Core gameplay classes should use typed GDScript and extend `RefCounted` or `Resource` where appropriate, not depend on active scenes or rendered nodes.

A complete run must be executable under a headless test/scenario runner without creating the normal gameplay scene.

Godot `Node`, `Node2D`, and `Control` classes belong primarily to presentation/application layers.

## 2.3 Run-scoped gameplay ownership

Do not make `RunState`, `RulesEngine`, Board state, RNG, current hand, or current Charter Autoload singletons.

One active game session owns one run.

Recommended relationship:

```text
GameScene / GameController (Node)
    └── GameSession (RefCounted)
            ├── RunState
            ├── RulesEngine
            ├── RunRNG
            └── rule/query services
```

The presentation `GameController` owns the current `GameSession` and translates its results into UI updates/signals.

Headless tests can instantiate `GameSession` directly.

## 2.4 Permitted Autoloads

Autoloads should be limited to application-wide services such as:

- `ContentRegistry` — static content loading and validation;
- `SaveService` — save/load/schema handling;
- `AppSettings` — audio/display/input/application preferences;
- optional lightweight `SceneRouter` — title/game/results navigation.

No Autoload should become a hidden second source of gameplay truth.

## 2.5 Synchronous rules, asynchronous-looking presentation

Rules execution is synchronous until the engine reaches a genuine player-choice boundary.

Do not use animation callbacks, Godot signals, timers, or scene events to determine rules ordering.

Presentation can animate the already-resolved results independently.

---

# 3. Recommended Project Layout

Use a clear domain/content/presentation separation. Exact names may vary, but preserve these responsibilities.

```text
res://
    autoload/
        content_registry.gd
        save_service.gd
        app_settings.gd
        scene_router.gd

    core/
        session/
            game_session.gd
            run_state.gd
            game_phase.gd
            resolution_state.gd

        commands/
            player_command.gd
            reserve_tile_command.gd
            survey_tile_command.gd
            place_tile_command.gd
            resolve_choice_command.gd
            ...

        state/
            board_state.gd
            board_cell_state.gd
            tile_copy_state.gd
            feature_component_state.gd
            feature_lineage_state.gd
            trade_network_lineage_state.gd
            development_state.gd
            transformation_state.gd
            specialist_piece_state.gd
            relic_state.gd
            charter_state.gd
            run_records.gd

        topology/
            topology_service.gd
            trade_network_service.gd
            lineage_service.gd

        rules/
            rules_engine.gd
            placement_rules.gd
            scoring_rules.gd
            development_rules.gd
            transformation_rules.gd
            specialist_rules.gd
            relic_rules.gd
            reward_rules.gd
            charter_rules.gd
            act_rules.gd
            stalemate_rules.gd

        events/
            rule_event.gd
            event_snapshot.gd
            completion_snapshot.gd
            run_event_record.gd
            presentation_cue.gd

        queries/
            placement_query_service.gd
            board_query_service.gd
            charter_progress_service.gd

        rng/
            run_rng.gd

        ids/
            run_id_allocator.gd

        validation/
            validation_result.gd
            invariant_validator.gd
            content_validator.gd

        serialization/
            run_serializer.gd
            state_normalizer.gd

    content/
        manifests/
            alpha_content_manifest.tres
            alpha_run_config.tres
        tiles/
        relics/
        specialists/
        charters/

    presentation/
        scenes/
        board/
            board_view.gd
            tile_view.gd
            board_camera.gd
        hud/
        choices/
        menus/
        results/

    debug/
        debug_overlay.gd
        debug_console.gd
        debug_commands.gd

    tests/
        test_runner.gd
        framework/
        unit/
        scenarios/
        replay/
        fixtures/

    assets/
```

Do not scatter authoritative rules code through view scenes.

---

# 4. Static Content Model

## 4.1 Typed Godot Resources

Static game definitions and tunable configuration live in typed Godot custom `Resource` classes and `.tres` files.

At minimum define typed resources for:

- `TileDefinition`;
- `RelicDefinition`;
- `SpecialistDefinition`;
- `CharterDefinition`;
- `RunConfig`;
- `ContentManifest`.

## 4.2 One physical-tile definition type

Prefer one `TileDefinition` family for every physical design that can exist in the bag/hand/Reserve, with fields describing its class and behavior.

Suggested fields include:

```text
definition_id: StringName
display_name: String
tile_class: TileClass
unlock_act: int
reward_class: RewardClass
canonical_edges: Array[EdgeType]
placement_behavior_id: StringName
effect_behavior_id: StringName
development_family_id: StringName
upgrade_from_definition_id: StringName
tags: Array[StringName]
parameters: typed configuration resource / dictionary
presentation references
```

Not every field applies to every tile class.

The Founding Tile is a static definition but is not a normal bag-eligible reward design.

## 4.3 Stable human-readable definition IDs

Static definitions use stable IDs such as:

```text
tile.straight_road
tile.urban_expansion
tile.bridge
relic.ferry_rights
specialist.merchant
charter.a1_growing_realm
charter.grand_great_metropolis
```

Player-facing names must never be used as logic identifiers.

Changing a stable definition ID after saves exist is a schema/content migration problem, not a cosmetic rename.

## 4.4 Passive Resources, centralized behavior

Static Resources remain primarily passive data.

Complex game behavior is implemented by centralized rule-system classes and reached through stable behavior IDs.

Example:

```text
RelicDefinition
    definition_id = relic.ferry_rights
    behavior_id   = ferry_rights
```

`RelicRules` owns the implementation of `ferry_rights`.

Do not attach a unique arbitrary gameplay script to every `.tres` resource.

## 4.5 Data vs code boundary

Store tunable values in data/configuration:

- Act lengths;
- Track thresholds;
- starting bag copy counts;
- transition seeding quantities;
- scoring numbers;
- Charter targets;
- reward copy quantities;
- Settlement-class thresholds;
- Relic/Specialist numeric parameters.

Keep structural rule algorithms in GDScript:

- topology;
- completion detection;
- merging/reopening;
- Trade Network construction;
- Bridge/Urban Expansion/Rewilding rewrites;
- event timing;
- anti-farming history;
- rule precedence.

## 4.6 Explicit alpha manifest

Use an `AlphaContentManifest.tres` rather than relying on arbitrary filesystem enumeration order.

The manifest identifies the exact alpha content pool.

This helps prevent accidental reintroduction of deferred prototype content.

## 4.7 Deterministic content ordering

Whenever a random offer is constructed from a candidate set:

1. filter eligible definitions;
2. sort them by stable definition ID;
3. perform random selection through `RunRNG`.

Never rely on Dictionary iteration, filesystem order, Resource load order, or scene order for RNG candidate ordering.

This is mandatory for deterministic replay.

## 4.8 Startup content validation

`ContentRegistry` validates the loaded alpha manifest before gameplay begins.

At minimum validate:

- all definition IDs are unique;
- all referenced behavior IDs are registered;
- every tile has valid class fields;
- edge arrays contain exactly four valid edge types where applicable;
- upgrade prerequisites exist and use valid Development families;
- Act eligibility is valid;
- reward classes are valid;
- required Charter/Relic/Specialist definitions exist;
- Homestead starting-bag counts total exactly 55 and match the canonical rules;
- the alpha Specialist pool contains exactly the canonical reduced roster;
- the alpha Relic pool contains exactly the canonical reduced roster;
- deferred content is not accidentally included in the alpha manifest.

Content errors should fail loudly in development builds.

---

# 5. Type Discipline and Coding Conventions

## 5.1 Strong typing

Use strongly typed GDScript wherever Godot permits it.

Important domain classes should use `class_name` and explicit property/function types.

Prefer:

```gdscript
func validate_command(command: PlayerCommand, state: RunState) -> ValidationResult:
```

over loosely typed generic functions.

## 5.2 Enums and `StringName`

Use enums for finite concepts such as:

- `EdgeType`;
- `FeatureType`;
- `TileClass`;
- `PlacementMode`;
- `TrackType`;
- `GamePhase`;
- `ChoiceType`;
- `EventType`;
- `RewardClass`;
- `EntityKind`.

Use `StringName` for stable static IDs in runtime memory and convert to strings at serialization boundaries.

## 5.3 Dictionary usage

Raw Dictionaries are acceptable at:

- JSON serialization boundaries;
- flexible diagnostic payloads;
- narrowly scoped event payloads where a typed object would add no value.

Do not build the normal domain model as a nested untyped Dictionary tree.

## 5.4 Core warning standard

Target **zero GDScript warnings** in the core rules/domain directories before an implementation milestone is considered complete.

Use assertions aggressively in development builds for impossible internal conditions.

---

# 6. Runtime Identity

## 6.1 Stable run-scoped IDs

Every persistent runtime entity receives a stable ID allocated by the run.

Use one monotonically increasing integer ID space or an equivalently deterministic run-local allocator.

Persistent entity categories include at least:

- physical tile copies;
- feature components created on board squares;
- feature lineages;
- Trade Network lineages;
- Development/Upgrade instances where separately represented;
- Transformation instances;
- Specialist pieces;
- enclosure objects;
- completion/history events.

Do not serialize Godot object instance IDs.

## 6.2 Debug formatting

The runtime ID may be numeric internally while debug formatting adds a type prefix:

```text
tile_42
feature_17
trade_6
specialist_2
```

## 6.3 No serialized object references

Persistent relationships are stored as stable IDs.

Never depend on a live Godot object pointer/reference surviving a save/load cycle.

---

# 7. Core `RunState`

`RunState` is mutable authoritative state for the current run.

It must be fully serializable at every allowed save boundary.

Recommended top-level responsibilities include:

```text
save/rules version metadata
run seed + RNG state
next runtime ID
current GamePhase
current Act
normal placement count
board state
physical tile registry
bag order
active hand tile IDs
Reserve tile IDs
removed-from-run tile IDs
Realm Track values
threshold-awarded flags
Survey state
Relic state/history/capacity
Specialist pieces/assignments/training
Charter and Grand Charter state
feature lineage/history state
Trade Network lineage/history state
milestone-awarded flags
historical records
structured run-event history
in-progress ResolutionState / PendingChoice
```

The UI has no independent authoritative copies of these values.

---

# 8. Physical Tile Copies and Zones

## 8.1 Physical copies are real runtime entities

Every physical tile copy has a stable `tile_copy_id` and static `definition_id`.

Suggested metadata:

```text
tile_copy_id
definition_id
acquired_act
acquisition_source
```

Current location is represented by authoritative containers/references rather than duplicated inconsistently.

## 8.2 Exactly-one-location invariant

Every physical tile copy must be in exactly one legal runtime location/state, such as:

- bag;
- active hand;
- Reserve;
- board as base Expansion tile;
- board as Development/Upgrade overlay;
- board as applied Transformation;
- removed from run.

No copy may exist in two places simultaneously.

## 8.3 Bag representation

Represent the bag as an ordered Array of physical `tile_copy_id`s.

Standardize **index 0 as the next draw** for clarity in debugging and Surveyor's Compass handling.

Bag sizes are small enough that front removal cost is irrelevant.

Whenever the canonical rules require full bag randomization, shuffle the entire remaining physical-copy array using `RunRNG`.

---

# 9. Board Representation

## 9.1 Sparse authoritative board

Use a sparse map:

```text
Vector2i -> BoardCellState
```

Do not use a fixed-size gameplay array.

Do not make Godot `TileMap` authoritative state.

The alpha board is effectively unbounded.

## 9.2 `BoardCellState`

A board cell should retain enough persistent information to reconstruct current effective geometry and history.

Recommended fields/concepts:

```text
coordinate: Vector2i
base_tile_copy_id
base_definition_id
base_rotation
base_placed_act
base_placement_index

effective_edges[N,E,S,W]
feature_components by FeatureType
development/upgrade tile-copy IDs
transformation instances
explicit internal access/relationship metadata
```

## 9.3 Effective edges are runtime state

Do not derive current edge legality only by rereading the original tile definition.

Urban Expansion, Bridge, Rewilding, Boundary Stones, and future rule effects can create persistent edge state different from the original static Resource.

Store current **effective edges** in runtime state and update them only through validated rule behavior.

## 9.4 Feature components on cells

Each tracked feature type present on a square should have a persistent `FeatureComponentState`.

This is important because a Transformation can create new feature growth on an old square.

Suggested fields:

```text
component_id
feature_type
origin_act
origin_source_type
origin_source_runtime_id
current_lineage_id
```

The component ID identifies the scoring-relevant feature contribution occupying that square.

Example:

- an Act I River Run has an Act I River component;
- Bridge in Act III creates an Act III Road component on that same board square;
- the square remains an Act I base tile;
- the Road component is not Act I Road growth.

This directly supports the alpha's tile-age rules.

## 9.5 One component per feature type per square in alpha

The alpha grammar never requires two disconnected Road components of the same type on one square.

All same-type edges on a tile are internally connected unless an explicit future rule says otherwise.

Therefore one `FeatureComponentState` per tracked `FeatureType` per board square is sufficient for the alpha.

---

# 10. Derived Topology

## 10.1 Current topology is derived

Road, Settlement, Forest, and River connected components are derived from:

- current board occupancy;
- effective edge types;
- same-type internal connectivity;
- explicit Transformation rewrites.

Field is not a tracked feature object.

Monastery/Abbey enclosure is tracked separately as an enclosure object.

## 10.2 Recompute rather than fragile incremental mutation

The alpha board is small. Favor correctness over micro-optimization.

After any topology-changing action, rebuild affected/current connected components from the authoritative board rather than attempting a highly optimized incremental graph algorithm with complex mutation bookkeeping.

A full current-feature recomputation is acceptable at alpha scale.

Do not rebuild topology for a purely edge-neutral Development if no rule affected connectivity.

## 10.3 Topology revision counters

Maintain simple revision numbers such as:

- `board_revision`;
- `topology_revision`;
- `trade_revision`.

Use these for:

- invalidating query/preview caches;
- detecting stale placement options;
- debugging.

They are not gameplay counters.

## 10.4 No premature topology cache

Legal options and connected components should be cheap enough to calculate directly.

Do not add complicated persistent caches until profiling demonstrates a need.

If a cache is later introduced, it must be keyed/invalidateable by the appropriate authoritative revision.

---

# 11. Feature Lineages and Historical Identity

## 11.1 Current component vs lineage

A **derived component** answers: “what is physically connected now?”

A **feature lineage** answers: “what historical feature identity does this growth belong to, and what has it already scored/done?”

Keep them separate.

## 11.2 New feature creation

When a newly derived feature contains no existing lineage-labelled feature components, create a new lineage ID.

Assign its current components to that lineage.

## 11.3 Ordinary growth

If current topology extends one existing lineage with new feature growth, retain the same lineage ID.

Do not create a new lineage merely because its size changed.

## 11.4 Reopening

A genuinely reopened completed feature retains the same lineage ID.

Record a new growth phase/reopening event rather than inventing a new identity.

## 11.5 Merging

When topology merges multiple existing lineages into one current physical feature:

1. create a new descendant lineage;
2. record every merged lineage as a parent/ancestor;
3. combine their persistent scoring/history sets;
4. mark parent lineages historical/inactive as current identities;
5. remap current member components, hosted Developments, and any legally following Specialist to the descendant lineage.

Old lineages remain in history and are never deleted merely because they merged.

## 11.6 Feature splitting

The alpha does not presently require arbitrary physical Road/Settlement/Forest/River splitting.

Do not engineer a generalized feature-splitting system into the critical path unless needed by a canonical alpha rule.

Retain clean extension points for future content.

## 11.7 Ancestry query

`LineageService` should provide ancestry queries such as:

```text
is_ancestor(candidate_id, lineage_id)
get_ancestry_closure(lineage_id)
```

Memoization is optional; data size is small.

These queries are required for anti-farming rules involving merged Settlements/Roads.

---

# 12. Scoring History / Anti-Farming Data

Do not infer “already scored” solely from completion count.

Store explicit scoring-history sets on the appropriate feature lineage.

## 12.1 Settlement lineage history

Track at minimum:

- Settlement feature-component IDs that have paid base +2 Population;
- Field-support board-cell relationships already paid to this Settlement lineage;
- River-support board-cell relationships already paid to this Settlement lineage;
- completion/growth-phase records;
- highest historical Settlement class achieved.

Support identity should represent:

```text
support board cell -> Settlement lineage -> support category
```

## 12.2 Road lineage history

Track at minimum:

- Road feature-component IDs that have paid base +1 Trade;
- Settlement lineage IDs/ancestries that have already paid the Road's +2 connection bonus;
- completion history;
- growth history.

When checking whether a current merged Settlement can pay a Road connection bonus, treat it as already paid if **any ancestor** of the current Settlement lineage previously paid that Road lineage.

## 12.3 Forest lineage history

Track at minimum:

- Forest feature-component IDs that have paid base +1 Ecology;
- completion history;
- current/historical development context as needed.

The flat preservation bonus is reevaluated on every genuine completion rather than permanently exhausted.

## 12.4 River lineage history

Track at minimum:

- completion history;
- Forest-contact board cells that have already paid the River's base contact Ecology.

Normal alpha Rivers cannot reopen, but keep the explicit contact history required by the canonical specification.

## 12.5 Bonus systems are not base history

Development, Specialist, and Relic effects that explicitly evaluate the full current completion state may trigger again on a later genuine re-completion if their own rule permits it.

Do not accidentally add them to base anti-farming sets.

---

# 13. Growth Attribution for Push-Your-Luck Specialists

Cartographer and Forester require more than a “size when assigned” integer because merging can absorb old feature tiles that must not count as growth added after assignment.

Store Specialist assignment growth metadata that distinguishes:

- genuinely new feature components created/added after assignment;
- pre-existing components merely absorbed through a later merge.

A robust approach is to maintain on the assignment state a set/count of **qualifying newly created component IDs** appended after assignment.

When a legal merger absorbs an existing lineage:

- the new bridge/connecting component may count as new growth when appropriate;
- pre-existing absorbed components do not.

Preserve this metadata when the Specialist follows a merged lineage.

---

# 14. Trade Network Architecture

## 14.1 Physical Roads and Trade Networks are different graphs

A Road Feature is physical same-type Road connectivity.

A Trade Network is the economic graph formed from:

- Road Features;
- Settlements acting as hubs;
- explicit Road–Settlement access relationships;
- Ferry Rights links when active.

Do not merge these concepts into one feature object.

## 14.2 Explicit access only

Trade Network construction must use explicit Road–Settlement access metadata from canonical tile topology/Transformations.

Simple orthogonal visual adjacency is insufficient.

## 14.3 Current Trade graph rebuild

`TradeNetworkService` should rebuild current Trade Network graph/components whenever relevant state changes, including:

- Road feature topology;
- Settlement topology;
- explicit Road–Settlement access;
- Urban Expansion Settlement merger;
- Bridge Road/access changes;
- Ferry Rights acquisition/removal.

Unfinished Roads and unfinished Settlements participate immediately as specified by the rules.

## 14.4 Persistent Trade Network genealogy

Trade Network history must survive:

- growth;
- merge;
- split;
- reconnection.

Current membership is derived. Historical lineage is persistent.

When one old network becomes multiple disconnected networks, create ancestry-aware descendant network lineages.

When descendants reconnect, create/reuse a lineage whose ancestry records the reconnection rather than producing history-free networks.

## 14.5 Trade membership identity

Use Road lineage IDs and Settlement lineage IDs as the durable members of the economic graph.

Persist network lineage history, but do not make current network membership a substitute for Road/Settlement anti-farming histories.

## 14.6 Trade history records

Record enough network history to answer canonical historical Charter/debug questions, including current/past Settlement reach and network ancestry.

A topology/network-change audit record should include current distinct Settlement count and member lineage IDs.

---

# 15. Monastery / Abbey Enclosures

Monastery/Abbey is not a normal edge-connected feature lineage.

Represent it as a persistent enclosure object centered on one board coordinate.

Suggested state:

```text
enclosure_id
host_coordinate
current_development_tile_copy_id
family_id = monastery
stage = monastery | abbey
completed_stage_history
assigned_steward_id
```

Surrounding-eight occupancy is derived from board occupancy.

Upgrading Monastery to Abbey preserves the location/family history but replaces the physical Development tile copy as specified by the rules and creates the Abbey's new scoring stage.

---

# 16. Developments, Upgrades, and Transformations in Runtime State

## 16.1 Development slots

Store Development overlays as an Array/list rather than one nullable field, because Mixed-Use Charter can explicitly permit more than one Development on a Settlement tile.

Normal validation still enforces one Development per tile.

## 16.2 Development host association

Persist the specific host relationship required by the canonical rules.

Examples:

- Housing -> Settlement lineage;
- Market/Grand Market -> Settlement lineage;
- Forester's Lodge -> Forest lineage;
- Port -> Settlement lineage plus associated River lineage;
- Mill -> host board tile and dynamically evaluated touching features;
- Monastery/Abbey -> enclosure object.

When host feature lineages merge, remap hosts to the resulting descendant lineage.

## 16.3 Upgrades are physical replacement

When Abbey/Grand Market upgrades a base Development:

- remove the old Development physical tile copy from board overlay state and place it in removed-from-run history/state;
- install the Upgrade physical tile copy in the slot;
- preserve historical evidence that the old Development existed;
- retain Development family identity for diversity rules.

## 16.4 Transformation instances

A Transformation applied to an occupied square remains a persistent runtime Transformation instance associated with that square, including:

- physical tile-copy ID;
- definition ID;
- Act applied;
- placement index;
- exact modification metadata.

This is required for age/history and future save/debug inspection.

Transformations do not replace the base tile's historical placement Act.

---

# 17. Placement Query and Interaction Model

## 17.1 Rules engine generates legal options

The UI never determines legal placement by itself.

Use a `PlacementQueryService` that returns typed `PlacementOption` objects for a selected physical tile copy.

Suggested shape:

```text
PlacementOption
    mode
    coordinate
    rotation_quarters
    target runtime IDs
    edge rewrite choices
    relationship choices
    affected feature references
    state_revision
    canonical signature
```

## 17.2 Expansion candidate enumeration

For ordinary Expansion tiles:

1. collect all empty orthogonal neighbors of occupied board cells;
2. sort coordinates deterministically;
3. evaluate all four 90° rotations;
4. validate exact edge matching plus active explicit exceptions;
5. deduplicate rotationally equivalent options.

## 17.3 Development/Upgrade candidates

Evaluate occupied board squares in deterministic coordinate order and delegate exact eligibility to the relevant behavior implementation.

## 17.4 Complex placement modes

Urban Expansion, Bridge, and Rewilding use purpose-written placement-option generators.

If one coordinate supports multiple materially different legal intents — for example, different rewrites, modes, or target lineages — return separate `PlacementOption`s.

## 17.5 Preview is not authoritative state

Tile selection, hover, rotation preview, and legal-option highlighting are local presentation state.

They are not written into `RunState` and do not need to survive Save/Continue.

## 17.6 Commit intent must be revalidated

A `PlaceTileCommand` sends the complete canonical intent, not merely “the user clicked coordinate X.”

The engine revalidates that intent against current `RunState` before mutation.

A state revision/signature may be included to reject stale UI previews, but final legality always comes from current authoritative state.

## 17.7 Two-step irreversible placement UX

Normal player flow:

```text
select tile
-> highlight legal options
-> hover/click option to preview
-> explicit Confirm
-> authoritative PlaceTileCommand
```

There is no player-facing Undo in the alpha.

Do not provide a full predicted scoring-total preview in the first alpha.

---

# 18. Command Architecture

## 18.1 Commands are the only normal mutation entry point

Presentation and normal tests mutate gameplay by submitting typed `PlayerCommand`s to `RulesEngine` / `GameSession`.

Representative commands:

- `ReserveTileCommand`;
- `SurveyTileCommand`;
- `PlaceTileCommand`;
- `ResolveSpecialistAssignmentCommand`;
- `ResolvePendingChoiceCommand` or typed reward-choice subclasses;
- `ChooseRelicReplacementCommand` where needed.

Debug tooling uses explicit debug APIs/commands, never arbitrary field edits from UI scripts.

## 18.2 Validate before mutate

Every command follows:

```text
validate
-> if invalid: return structured failure; state unchanged
-> if valid: commit initial mutation
-> resolve canonical consequences
-> stop at next stable player-input boundary
```

A placement must not rewrite half the board before discovering that a later edge/merge condition makes it illegal.

## 18.3 Validation result

Use a typed `ValidationResult` containing at least:

```text
is_valid
error_code
user_message
debug_details
```

Do not communicate gameplay validation through `null`, thrown exceptions, or unstructured strings alone.

## 18.4 Internal errors are different from player-invalid commands

An illegal player request is normal validation failure.

A violated invariant or impossible engine state is a development/programming error and should fail loudly in development builds.

---

# 19. Authoritative Game Phases

Use an explicit `GamePhase` state machine to constrain which commands are accepted.

Recommended authoritative phases:

```text
SETUP
TURN_INPUT
RESOLVING_PLACEMENT
RESOLVING_ACT_TRANSITION
PENDING_CHOICE
RUN_COMPLETE
```

UI-only preview/selection states are not authoritative game phases.

## 19.1 `TURN_INPUT`

Permits legal pre-placement actions and the required placement command.

## 19.2 `RESOLVING_PLACEMENT`

Internal engine resolution. Ordinary player commands are rejected.

If a real choice is required, transition to `PENDING_CHOICE` with serializable resolution context.

## 19.3 `RESOLVING_ACT_TRANSITION`

Executes the exact canonical Act-transition sequence.

Charter reward choices may pause this process through `PENDING_CHOICE` and later resume it at the correct transition step.

## 19.4 `PENDING_CHOICE`

Only commands legal for the active `PendingChoice` are accepted.

## 19.5 `RUN_COMPLETE`

No further gameplay mutation commands are accepted.

---

# 20. Resolution State, Pending Choices, and Save Boundaries

## 20.1 Real choices are serializable engine state

Do not have rules code directly open a dialog and wait for a callback.

When rules require input, create a typed `PendingChoice` in authoritative state.

Examples include:

- optional Specialist assignment after a committed placement;
- Specialist training choice;
- Surveyor's Compass inspected-tile choice;
- Tile Reward choice;
- Relic offer choice;
- full-slot Relic replacement/decline;
- Major Reward choice;
- Steward's Relay reassignment/decline.

## 20.2 Placement may be committed before Specialist choice

The canonical rules assign the Specialist after the placement is committed but before completion resolution.

Therefore a valid save may exist with:

- the tile already placed on the board;
- the placement counter already updated as appropriate;
- completion consequences not yet resolved;
- a pending optional Specialist-assignment choice.

Persist enough `ResolutionState` to resume without duplicating the placement or losing the pre-resolution context.

## 20.3 Serializable `ResolutionState`

When a player choice pauses resolution, persist the continuation context, including as needed:

- parent event / placement runtime ID;
- current canonical resolution stage;
- serialized immutable snapshot data already calculated;
- remaining batch actions;
- FIFO child-event queue;
- threshold queue;
- pending Act-transition step;
- pending active-hand refill state;
- `PendingChoice`.

Do not save halfway through a purely deterministic internal mutation step.

## 20.4 Stable save boundaries

Autosave is permitted when the engine is waiting for player input at a stable boundary, principally:

- `TURN_INPUT`;
- `PENDING_CHOICE`;
- completed transition/result boundaries.

Do not serialize a half-applied internal batch.

---

# 21. Event Resolution Architecture

## 21.1 Typed ephemeral rule events

Use typed serializable/resumable rule-event objects for internal resolution.

At minimum support the canonical event categories:

- `tile_placed`;
- `development_placed`;
- `transformation_applied`;
- `feature_merged`;
- `feature_reopened`;
- `feature_completed`;
- `specialist_returned`;
- `relic_triggered`;
- `milestone_earned`;
- `track_threshold_crossed`;
- `reward_resolved`;
- `bonus_placement_granted`;
- `act_transition_started`;
- `act_started`;
- `run_ended`.

Additional explicit event types may be added where they improve clarity, but never conflate merger, reopening, Development placement, and genuine feature completion.

## 21.2 Shared immutable snapshots

When one placement completes multiple features, create a `CompletionSnapshot` representing the shared state required by all simultaneous calculations.

Treat snapshots as immutable after creation.

Do not let resolution of the first completed feature mutate what the second simultaneous completion “saw.”

## 21.3 Canonical batch pipeline

Implement the canonical completion sequence exactly:

```text
snapshot
-> base feature scoring
-> Development effects
-> Specialist effects
-> Specialist returns / Relay handling
-> Relic effects
-> Relic milestones
-> queue crossed Track thresholds
-> resolve threshold queue
```

Subsystem-specific rules can add child events, but no child event interrupts the middle of its parent batch.

## 21.4 FIFO child-event queue

Use FIFO creation order.

Do not recursively execute child events immediately from inside arbitrary rule handlers.

A simple Array plus read index is sufficient and avoids expensive front removals.

## 21.5 Stable simultaneous ordering

Whenever the rules do not already define an order, use stable runtime/static ID ordering to break ties so deterministic replay cannot depend on Dictionary iteration order.

Established canonical subsystem orders still take precedence.

---

# 22. Structured Run History / Audit Log

## 22.1 Run history is not event sourcing

Maintain a structured serializable `RunEventRecord` audit/history log.

`RunState` remains authoritative current state.

Do **not** reconstruct normal saves by replaying the entire history log.

## 22.2 Record shape

Suggested fields:

```text
event_record_id
event_type
act
normal_placement_index
parent_event_record_id
source runtime IDs
affected runtime IDs
structured payload
```

## 22.3 Required completion detail

Completion records must retain at least the detail required by the canonical rules, including:

- feature lineage ID;
- Act;
- placement index;
- first completion vs genuine re-completion;
- total feature size;
- new/scoring growth;
- relevant completion relationships/state;
- Realm Track gains;
- triggered effects.

Settlement Establishment records additionally retain the canonical growth/class/development/support information.

## 22.4 Uses

The structured history supports:

- historical Charter conditions;
- anti-farming/history inspection;
- final statistics;
- debugging;
- deterministic divergence investigation;
- future player-facing “what happened?” logs.

Generate human-readable debug text from structured records rather than storing prose as canonical history.

---

# 23. RNG Architecture

## 23.1 One authoritative gameplay stream

Every rules-affecting random choice uses one run-owned `RunRNG` instance.

No gameplay class may independently call uncontrolled random helpers.

The one stream governs all canonical randomness, including:

- starting bag shuffle;
- draws;
- bag re-randomization;
- dead-hand cycling;
- Tile Reward offers;
- Specialist offers;
- Relic offers;
- Charter selection;
- Grand Charter selection;
- other alpha random choices.

## 23.2 Cosmetic randomness is separate

Particles, sound pitch variation, animation offsets, visual wobble, and other cosmetic randomness must never consume the gameplay RNG stream.

## 23.3 Seed and RNG state

Persist both:

- original run seed;
- current Godot RNG state.

Save/Continue restores the current RNG state directly.

Seed replay tests still verify same seed + same player decisions reproduces the same gameplay random sequence.

## 23.4 Godot version discipline

Record the Godot version used for a build in implementation/build metadata.

When upgrading Godot versions, rerun deterministic replay fixtures before accepting the upgrade.

Do not assume an engine upgrade preserves RNG implementation behavior without verification.

## 23.5 RNG debug sequence

Development builds should optionally record an incrementing RNG-operation counter and concise reason, e.g.:

```text
RNG 0001 starting_bag_shuffle
RNG 0002 act_1_charter_selection
RNG 0003 opening_draw
```

This log is diagnostic; it need not be player-facing.

---

# 24. Bag, Hand, Reserve, and Stalemate Implementation

Implement exact gameplay behavior from the canonical Alpha Rules Specification. Engineering-specific requirements follow.

## 24.1 Batch shuffle operations

When an effect adds several physical copies, add the entire batch then perform the required full-bag shuffle once unless the canonical effect explicitly requires sequential draws between additions.

## 24.2 Hand refill is a resolution step

Do not let the presentation layer automatically refill a visual hand slot.

The engine owns pending hand-refill state and performs it at the canonical point after consequences/rewards/bag additions.

## 24.3 Final-placement transition refill

On the final normal placement of Act I/II, retain a pending refill marker if the tile came from active hand.

The Act-transition service must seed/unlock/randomize the new Act content **before** performing that pending replacement draw.

## 24.4 No Act III final refill

After Act III placement 26 and its full consequence queue, do not perform a replacement draw.

## 24.5 Conservative “provably impossible” Reserve safeguard

The Reserve safeguard requires proof that a tile can never become legally playable through any remaining alpha action.

Implement this conservatively.

If the engine cannot prove impossibility, **do not remove the Reserve tile**.

Never use heuristic guesses such as “this looks unlikely to become playable.”

## 24.6 Dead-hand/global-stalemate queries

Because alpha state is small, legality checks may enumerate candidate placements directly.

For bag-wide stalemate checks, identical physical copies of the same static definition may share a legality query result when their runtime state is equivalent; physical identity must still remain intact when actual tiles are moved.

## 24.7 Bonus-placement support

Implement the generic bonus-placement machinery even though the current alpha content roster does not grant bonus placements. The Complete Alpha Rules Specification explicitly requires the engine behavior and handoff tests.

Represent outstanding bonus placements in serializable resolution state/queue. A bonus placement:

- consumes the chosen physical tile copy;
- does not increment the normal Act placement counter;
- uses the normal placement/completion/scoring/Specialist/Relic/milestone/threshold pipeline;
- may chain if a future effect explicitly grants another bonus placement;
- does not permit normal Survey/Reserve/start-of-turn actions unless the granting effect explicitly says so.

If a bonus placement uses an active-hand tile, perform its canonical replacement draw after that bonus placement's complete consequences and before the next queued bonus placement. If it uses Reserve, do not refill the active hand.

If the outgoing Act's final normal placement starts a bonus chain, keep the outgoing Act active until the entire bonus chain and all child events are exhausted. Only then begin Charter evaluation/Act transition.

---

# 25. Specialists Runtime Model

## 25.1 Specialist piece state

Suggested `SpecialistPieceState`:

```text
piece_id
role_definition_id or generic Steward marker
current_status
assigned_target_type
assigned_target_id
assigned_act
assigned_placement_index
assignment_growth_metadata
training_history
```

## 25.2 One Specialist per unfinished connected feature

Enforce this as both:

- command/placement validation;
- post-mutation invariant.

Any placement/Transformation that would merge two unfinished features each containing a piece is illegal before commit.

## 25.3 Assignment locality

Placement resolution should generate the legal Specialist-assignment target list from only features directly affected by that committed tile/Development/Transformation.

The UI must not offer global unrelated features.

## 25.4 No last-second assignment

A feature completed by the committed placement itself is not an assignment candidate.

## 25.5 Training in place

If a generic Steward is committed when the 40-point reward occurs, filter trainable roles by legality on that current occupied feature and leave the piece committed.

The offer generator must use the canonical uniform filtered pool.

## 25.6 Relay

Steward's Relay creates a `PendingChoice` after the Specialist-return step when legal touching unfinished targets exist.

Normal same-resolution reassignment remains forbidden without Relay.

---

# 26. Relic Runtime Model

## 26.1 Relic state

Persist at minimum:

```text
definition_id
acquisition_order
acquired_act
equipped_slot
once_per_act_use_state
replacement/removal history as run records
```

A Relic actually acquired is permanently exhausted from future offer pools even if later replaced.

## 26.2 No inactive inventory

Acquisition immediately equips or triggers the canonical replacement/decline choice if capacity is full.

## 26.3 Removal legality

Before permitting a Relic replacement, validate that removing the selected Relic will not make current runtime state illegal.

Example: do not remove Wayfarer's Satchel while its extra Reserve slot is occupied if the resulting state would have nowhere legal to retain that tile.

## 26.4 Rule precedence

Centralize Relic rule-conflict handling in the Relic/rule systems.

Apply canonical precedence:

1. explicit prohibition over permission;
2. more specific over more general;
3. if still tied, later-acquired Relic wins.

Triggered sequential choice handling uses canonical acquisition order where specified.

Do not reproduce precedence logic independently in UI code.

## 26.5 Ferry Rights network recomputation

Acquiring, equipping, replacing, or otherwise losing Ferry Rights is a Trade Network topology change.

Rebuild the current Trade Network graph and update genealogy without retroactive scoring.

---

# 27. Reward / Pending-Choice Architecture

## 27.1 Offer candidates

Every offer service follows the canonical filtering rules first, deterministic sort second, gameplay RNG selection third.

No contextual helpfulness weighting exists in the alpha.

## 27.2 Choice objects

Persist the exact physical/static options selected by RNG in the `PendingChoice`.

Do not regenerate an offer when loading a save.

Doing so would consume RNG again and could change the run.

## 27.3 Reward chaining

When one reward creates another reward/choice, resume through the serialized ResolutionState and canonical queue rather than nesting UI dialogs as gameplay control flow.

## 27.4 Charter reward order

Represent Charter rewards as ordered reward steps matching the canonical rules.

Resolve all outgoing-Act Charter reward steps before advancing the Act.

This naturally preserves the outgoing-Act tile eligibility restriction.

---

# 28. Charter Implementation

## 28.1 Static definition + behavior evaluator

Each Charter definition contains:

- stable definition ID;
- display title/text;
- Act/tier;
- forecast text where applicable;
- tunable target parameters;
- behavior/evaluator ID;
- ordered reward definition.

Complex Charter condition evaluation lives in `CharterRules` / evaluator behavior code.

Do not build a large generic rules DSL for the first nine alpha Charters unless the implementation becomes clearly simpler by doing so.

## 28.2 Progress model for UI

Charter evaluation service should return structured `CharterProgress`, for example:

```text
CharterProgress
    overall_state
    conditions: Array[ConditionProgress]

ConditionProgress
    label
    current_value/description
    target
    satisfied
    source = CURRENT_STATE | HISTORY
```

This allows the HUD to distinguish current-state and historical requirements without duplicating Charter logic.

## 28.3 Grand Charter secret selection

At Act II start:

- consume RNG once to select the exact Grand Charter;
- store the exact selected ID in authoritative state;
- expose only its forecast to normal presentation until midpoint reveal.

Do not delay actual RNG selection until midpoint.

## 28.4 Midpoint reveal

After Act II normal placement 11 and its entire consequence/bonus/event/threshold queue resolves, mark the exact Grand Charter revealed before the next normal turn begins.

This reveal consumes no RNG because the Charter was already selected at Act II start.

---

# 29. Act Transition Service

Implement Act transition as an explicit resumable pipeline, not a pile of scene callbacks.

The transition must preserve exact canonical ordering.

Recommended `ActTransitionState` fields:

```text
outgoing_act
incoming_act
current_transition_step
pending_charter_reward_index
pending_hand_refill
```

Canonical transition implementation order:

```text
1. evaluate outgoing Act Charter
2. award all fulfillment/exceed rewards
3. no-op Legendary Project hook
4. advance Act
5. increase Relic capacity
6. expire/grant Survey charge
7. refresh once-per-Act Relics
8. unlock new Act content
9. seed new Act tiles into bag
10. randomize bag
11. reveal/select required Charter information
12. reset placement counter
13. perform pending final-placement hand refill
14. enter TURN_INPUT
```

Any reward choice can pause transition through `PENDING_CHOICE`, save safely, and later resume at the exact step.

Do not clear strategic state that the canonical rules say persists.

---

# 30. Presentation Architecture

## 30.1 Individual tile views

Do not use Godot `TileMap` as the primary/authoritative board representation.

Render each occupied square with a lightweight `TileView` scene under a pannable/zoomable `BoardView` (`Node2D`).

Conceptual structure:

```text
BoardView
    TileView
        base artwork
        Development overlay(s)
        Transformation overlay(s)
        Specialist marker
        selection/highlight layer
        optional debug layer
```

## 30.2 Board coordinate conversion

Rules use `Vector2i` grid coordinates only.

Presentation converts grid coordinates to local pixel positions using a presentation-owned tile display size.

## 30.3 Board camera

Desktop controls:

- mouse wheel zoom;
- middle- or right-drag pan;
- optional keyboard pan shortcuts;
- reasonable min/max zoom.

Controller support is deferred.

## 30.4 Mouse-first input

Every required gameplay action must be possible with visible mouse UI.

Keyboard shortcuts are accelerators, not mandatory hidden controls.

Suggested shortcuts include:

- hand slot selection `1` / `2` / `3`;
- rotate clockwise/counter-clockwise;
- confirm/cancel preview;
- Survey/Reserve convenience keys;
- debug-overlay toggle in development builds.

## 30.5 Main HUD

Use a board-centered fixed desktop HUD.

Always-visible core information:

- current Act;
- normal placements used/remaining;
- Population;
- Trade;
- Culture;
- Ecology;
- current Charter/Grand Charter summary;
- Survey charges;
- Relics and capacity;
- Specialists and availability/commitment;
- Reserve;
- active hand of three tiles.

Recommended arrangement:

```text
Top:    Act / placements / Tracks / Charter
Side:   Relics / Specialists / Survey / Reserve
Center: Board
Bottom: Active hand + contextual tile controls
```

## 30.6 Inspection rather than map clutter

Do not permanently plaster feature scores/IDs over the normal board.

Use hover/selection inspection panels for richer details.

Debug overlays are separate development features.

---

# 31. Rules Resolution vs Presentation Cues

## 31.1 Rules do not wait for animation

A submitted command resolves authoritatively to the next genuine player-input boundary without waiting for animations.

`ResolutionResult` may contain:

- structured history records;
- ordered presentation cues;
- updated phase/state information;
- `PendingChoice` if required.

## 31.2 Presentation cues

Examples:

- highlight completed feature;
- show base scoring gain;
- show Development trigger;
- animate Specialist return;
- show Relic trigger;
- animate Track change;
- announce milestone;
- announce threshold;
- open reward choice.

Cues are not authoritative and do not control rule timing.

## 31.3 Cues need not be saved

Presentation cues do not need to survive Save/Continue.

On load, reconstruct visible state directly from `RunState` and show any authoritative `PendingChoice`.

It is acceptable for a player who quits after a rule result but before all cosmetic animations to skip those prior animations on resume.

## 31.4 Instant-resolution development option

Development builds should support accelerated/instant presentation to make repeated playtesting practical.

Rules results remain identical.

---

# 32. Save / Continue

## 32.1 Player-facing policy

The alpha supports:

- **one active run slot**;
- automatic saving at every stable player-input boundary;
- **Save & Quit**;
- **Continue** from title screen.

No normal multi-slot manual-save system is required.

Starting a new run while an unfinished run exists requires a warning that the active run will be replaced.

No player-facing Undo/rewind is provided.

## 32.2 JSON format

Use human-readable versioned JSON for run saves.

Top level should include at minimum:

```json
{
  "save_schema_version": 1,
  "game_rules_version": "alpha-1",
  "implementation_spec_version": 1,
  "godot_version": "...",
  "run_state": { }
}
```

Store only JSON-safe primitive/collection data.

Encode Godot-specific types explicitly, e.g.:

```json
"coordinate": [4, -7]
```

## 32.3 Separate schema and rules versions

`save_schema_version` answers: “what shape is this serialized file?”

`game_rules_version` answers: “which gameplay implementation created this run?”

Do not silently load an incompatible rules-version save and hope for the best.

Early alpha saves are not guaranteed to survive incompatible development revisions.

## 32.4 Save RNG state

Persist the current gameplay RNG state in addition to the original seed.

A normal Continue restores exact current state; it does not replay the run from seed.

## 32.5 Atomic save writing

Use an atomic-ish replacement flow:

1. serialize to temporary file;
2. parse/basic-validate temporary output;
3. preserve previous valid primary as backup;
4. replace primary with new validated save.

Maintain exactly one automatic previous-save corruption-recovery backup.

The backup is not exposed as a normal “load previous turn” interface.

## 32.6 Corruption fallback

If primary save fails parsing/schema/invariant validation:

- attempt the backup;
- if backup is valid, recover it and inform the player appropriately;
- if both are invalid/incompatible, do not silently repair gameplay state.

Preserve diagnostic files where practical.

## 32.7 Post-load reconstruction

Load process:

1. load/validate static content registry;
2. parse versioned JSON;
3. deserialize runtime entities/IDs;
4. rebuild ID lookup tables;
5. rebuild derived board feature topology in **reconstruction mode**;
6. rebuild current Trade Network graph in reconstruction mode;
7. reconnect current runtime references by stable IDs;
8. verify saved lineage/network identity agrees with derived current topology;
9. validate all invariants;
10. restore pending resolution/choice state;
11. enter the saved stable phase.

Loading must not generate gameplay events, score features, cross thresholds, or trigger rewards.

## 32.8 Completed run handling

At run end, construct a `RunResult` containing canonical final statistics and seed.

The active-run save may be cleared only after the final result/history is safely available to the results screen and any desired alpha last-run/debug summary storage.

Meta-progression remains deferred.

---

# 33. Invariant Validation

Create an `InvariantValidator` callable:

- automatically after every successfully resolved command in development builds;
- after save load;
- manually from debug tools;
- from automated tests.

At minimum enforce all canonical Alpha invariants, including:

- occupied orthogonal edges are legal outside explicit exceptions;
- at most one Specialist per connected unfinished feature;
- Development slot/stacking rules are legal;
- upgrades replace rather than illegally stack with their base;
- base scoring history never resets through reopening/merging/network topology changes;
- no retroactive rewards occur by default;
- every physical tile copy has exactly one legal location/state;
- all persistent IDs/references resolve;
- deterministic gameplay state uses only the run RNG;
- Act transitions have not silently reset persistent strategic state.

Additional engineering invariants should include:

- current feature-component lineage labels are consistent within a derived connected feature;
- Development hosts point to valid current descendant lineages;
- assigned Specialists point to valid unfinished targets;
- active Trade Network membership agrees with the rebuilt economic graph;
- pending-choice options reference valid current entities/content;
- no duplicate runtime IDs exist.

---

# 34. Development Debug / Playtest Toolkit

A development-only toolkit is an explicit alpha requirement.

## 34.1 Seed controls

Provide:

- start run from typed/entered seed;
- display/copy current seed;
- display RNG operation counter/state summary.

## 34.2 Board/topology overlay

Toggleable overlay should be able to display per tile/feature as appropriate:

- grid coordinate;
- physical tile-copy ID;
- base definition ID;
- effective edges;
- feature component IDs;
- current feature lineage IDs;
- open exits;
- Trade Network lineage ID/membership;
- base-placement Act;
- Transformation Act/identity;
- Development identity;
- Specialist assignment.

## 34.3 Inspectors

Provide development inspection for:

- board square;
- feature lineage and ancestry;
- Trade Network lineage and ancestry;
- physical tile copy;
- Development/Transformation;
- Specialist piece;
- equipped/acquired Relics;
- bag contents and current draw order;
- event/history log;
- PendingChoice / ResolutionState;
- threshold/milestone flags.

## 34.4 State tools

Provide:

- dump current RunState to readable JSON;
- load debug fixture;
- run invariants on demand;
- copy state/replay fingerprint;
- instant/fast presentation mode.

## 34.5 Controlled cheat/debug commands

Examples:

```text
add_track population 20
grant_tile tile.bridge 1
grant_survey
offer_relic
```

Debug commands may bypass normal player acquisition rules, but must use controlled state-mutation services and finish in an invariant-valid state.

Do not implement the debug console as unrestricted reflection-based variable editing.

---

# 35. Automated Test Harness

Automated tests are part of the alpha definition of done.

## 35.1 No third-party test dependency

Provide a lightweight project-owned headless runner callable approximately as:

```text
godot --headless --path . --script res://tests/test_runner.gd
```

Exit nonzero on any failure.

A small internal assertion/test-suite framework is sufficient.

## 35.2 Unit tests

Cover narrow deterministic rules, including at minimum:

- rotation and effective edge calculations;
- exact edge matching;
- board coordinate neighbors;
- basic placement legality;
- feature connectivity/completion;
- lineage ancestry helpers;
- scoring-history anti-farming helpers;
- Development eligibility/upgrade replacement;
- Specialist assignment legality;
- Relic capacity/removal legality;
- RNG shuffle/sample helpers;
- reward candidate filtering/sorting;
- Charter condition evaluators;
- serialization of domain types.

## 35.3 Scenario/integration tests

Build explicit board-state scenarios for:

- simultaneous multi-feature completion;
- Settlement reopening/re-completion;
- Settlement merge through Urban Expansion;
- Road merge/reopening through Bridge;
- Rewilding expansion, occupied transformation, reopening, and Forest merge;
- scoring-history preservation after mergers;
- Development placed on an already-completed feature;
- Abbey/Grand Market immediate upgraded-stage effect;
- Specialist follow-through on legal merger;
- illegal merge of two Specialist-occupied unfinished features;
- Cartographer/Forester excluding pre-existing absorbed merge tiles;
- Ferry Rights adding/removing Trade connectivity;
- Trade Network split/reconnection genealogy;
- multiple simultaneous threshold crossings;
- multiple Relic milestone ordering;
- outgoing Charter rewards before Act advance;
- Act-transition seeding before pending refill;
- Act II midpoint Grand Charter reveal;
- final Act III no-refill ending.

## 35.4 Scenario fixtures

Provide a `ScenarioFactory` or explicit fixture format capable of constructing complex invariant-valid states directly for focused tests.

Not every complex test should require playing 40 turns from the Founding Tile first.

Fixtures must still pass invariant validation before the tested action begins.

## 35.5 Deterministic replay tests

Store replay fixtures containing:

```text
seed
ordered player commands / choices
expected RNG decisions and/or state fingerprints
expected final assertions
```

Run the same replay repeatedly and require identical gameplay results.

## 35.6 Save/load round-trip tests

At multiple stable boundaries:

1. serialize RunState;
2. deserialize;
3. rebuild derived topology;
4. compare normalized gameplay state;
5. continue with identical commands;
6. verify RNG and final results remain identical.

Include saves during real `PendingChoice`s, not only turn starts.

## 35.7 Rules handoff checklist

Every item in Section 24 of the Complete Alpha Rules Specification must have at least one automated test or explicit integration demonstration before alpha implementation is declared faithful.

---

# 36. Deterministic State Fingerprints

For debugging/replay tests, implement a normalized gameplay-state fingerprint.

The fingerprint should exclude cosmetic/view state and include authoritative gameplay state relevant to deterministic continuation.

Normalize/sort unordered structures before hashing.

A SHA-256 or equivalent stable digest is suitable.

Uses:

- replay divergence detection;
- save/load round-trip verification;
- bug reports;
- stale-query diagnostics.

This fingerprint is development infrastructure, not gameplay scoring.

---

# 37. Performance Policy

The alpha's expected board/state size is small.

Prioritize:

1. correctness;
2. deterministic behavior;
3. readability/testability;
4. profiling evidence;
5. optimization.

Specific decisions:

- rules run on the main thread for alpha;
- no multithreaded topology engine;
- recompute current feature connectivity after topology mutations;
- recompute Trade Network connectivity after relevant economic topology changes;
- enumerate legal placements directly;
- no elaborate ECS or spatial database;
- no TileView pooling required unless profiling later proves useful.

Do not add complexity merely to optimize dozens of board cells.

---

# 38. Error Handling

## 38.1 Player legality errors

Return structured validation errors to UI without mutating state.

Examples:

- illegal edge mismatch;
- no valid Development host;
- illegal Specialist merge;
- occupied target;
- stale placement preview.

## 38.2 Internal invariant failures

Development builds should stop loudly with:

- assertion/error;
- relevant runtime IDs;
- state fingerprint;
- seed;
- recent event records where possible.

Do not quietly continue a corrupted rules state.

## 38.3 Release/debug-alpha behavior

If an unrecoverable internal/save/content error occurs in an exported alpha, show a clear error screen and preserve diagnostic data where practical rather than silently inventing state repairs.

---

# 39. Presentation Accessibility / Readability Baseline

Without expanding alpha scope into a full accessibility pass, follow these baseline rules:

- do not rely solely on color to distinguish legal/illegal/current selection states;
- combine color with outlines/icons/patterns;
- keep rules-critical text at readable scalable UI sizes;
- expose hover/click textual explanations for Relics, Specialists, tile effects, and Charter conditions;
- maintain usable contrast;
- keyboard shortcuts supplement rather than replace mouse-accessible controls.

---

# 40. Build and Version Metadata

Maintain explicit constants/build metadata for:

```text
IMPLEMENTATION_SPEC_VERSION = 1
SAVE_SCHEMA_VERSION = 1
GAME_RULES_VERSION = "alpha-1"
```

Expose these in development diagnostics and save headers.

Record the Godot version used for test/export builds.

Changing gameplay behavior that invalidates deterministic fixtures should require deliberate `GAME_RULES_VERSION` consideration.

---

# 41. Implementation Order for Local Codex

Codex should build the alpha in testable layers. Avoid attempting the entire UI and entire rules engine simultaneously.

## Phase 0 — Project skeleton

Implement:

- Godot project structure;
- type/enums foundations;
- project-owned test runner;
- version constants;
- `ContentRegistry` skeleton;
- alpha content manifest/config skeleton.

**Exit condition:** headless runner works and content registry can load/validate a minimal manifest.

## Phase 1 — Identity, state, RNG, serialization foundations

Implement:

- run-scoped ID allocator;
- `RunState` skeleton;
- physical `TileCopyState`;
- `RunRNG`;
- JSON serializer/deserializer framework;
- state normalizer/fingerprint;
- invariant framework.

**Exit condition:** seeded RNG tests and basic save/load round-trip pass.

## Phase 2 — Board and basic tile placement

Implement:

- sparse board;
- Founding Tile;
- basic Expansion definitions;
- rotation;
- exact edge matching;
- placement query service;
- basic `PlaceTileCommand`;
- 55-tile Homestead bag;
- active hand;
- Reserve;
- Survey;
- dead-hand/emergency draw rules.

**Exit condition:** deterministic Act-I-style tile placement works headlessly with no scoring systems yet.

## Phase 3 — Feature topology, lineage, completion, base scoring

Implement:

- Road/Settlement/Forest/River feature components;
- topology rebuild;
- feature lineage creation/growth/merge/reopen history;
- completion detection;
- Monastery enclosure object;
- base scoring histories;
- Realm Track state;
- completion records.

**Exit condition:** anti-farming feature re-completion tests pass.

## Phase 4 — Trade Networks

Implement:

- explicit Road–Settlement access;
- Settlement hubs;
- transitive Trade graph;
- current network reconstruction;
- network genealogy;
- Road completion network scoring.

**Exit condition:** canonical Road/Trade scenarios and network history tests pass.

## Phase 5 — Developments and Upgrades

Implement:

- Development slots/hosts;
- Housing;
- Mill;
- Monastery completion behavior;
- Forester's Lodge;
- Market;
- Port;
- Town Square;
- Abbey;
- Grand Market;
- immediate effects on already-completed hosts;
- Upgrade physical replacement.

**Exit condition:** Development/Upgrade scenario suite passes.

## Phase 6 — Transformations and growth rewrites

Implement:

- Urban Expansion;
- Bridge;
- Rewilding;
- effective-edge rewrites;
- new feature-component age;
- merge/reopen behavior;
- Transformation stacking legality.

**Exit condition:** all canonical Transformation checklist scenarios pass.

## Phase 7 — Stewards and Specialists

Implement:

- 2 starting Stewards / cap 3;
- assignment locality;
- one-per-feature and merge legality;
- completion return;
- in-place training;
- exact reduced alpha Specialist roster;
- push-your-luck growth attribution.

**Exit condition:** Specialist lifecycle/merge/training tests pass.

## Phase 8 — Relics, thresholds, rewards, milestones

Implement:

- Track threshold queue;
- Tile Reward offers/copy quantities;
- Major Rewards;
- Relic capacity/acquisition/replacement/exhaustion;
- exact reduced 10-Relic pool;
- Relic milestones;
- canonical precedence/order;
- Ferry Rights Trade Network changes.

**Exit condition:** deterministic reward ordering and Relic suite pass.

## Phase 9 — Charters, Acts, complete run

Implement:

- all 3 Act I Charters;
- all 3 Act II Charters;
- all 3 Grand Charters;
- forecast/exact reveal;
- Act transitions;
- Act II/III automatic seeding;
- final Act III no-refill behavior;
- final score/result.

**Exit condition:** a full three-Act run can be executed headlessly under scripted choices and all canonical handoff checklist tests pass.

## Phase 10 — Playable presentation

Implement/refine:

- BoardView/TileView;
- camera pan/zoom;
- hand/Reserve/Survey controls;
- legal placement highlighting/preview/confirm;
- HUD;
- Specialist assignment UI;
- reward/Relic/Charter modals;
- Act-transition presentation;
- results screen;
- presentation cue playback.

**Exit condition:** full run playable with mouse and optional keyboard shortcuts.

## Phase 11 — Save/Continue + development tools integration

Finalize:

- autosave boundaries;
- Save & Quit/Continue;
- pending-choice resume;
- atomic backup recovery;
- debug overlay/console;
- state dump/load fixtures;
- instant animations.

Save infrastructure should already exist from early phases; this phase completes player-facing integration.

## Phase 12 — Alpha acceptance and exports

Run:

- all unit tests;
- all integration scenarios;
- deterministic replay fixtures;
- save/load fixtures;
- full canonical checklist;
- Windows export smoke test;
- Linux export smoke test;
- zero-warning core-rules review.

Only then label the implementation as the first complete playable alpha.

---

# 42. Engineering Acceptance Criteria

In addition to the Complete Alpha Rules Specification's 25-item Codex handoff checklist, the implementation is not complete until all of the following are true:

1. Core rules execute without the gameplay scene and can be driven by headless commands.
2. Static content passes startup validation.
3. The exact alpha content manifest excludes deferred prototype content.
4. All gameplay RNG passes through one run-owned stream.
5. Candidate ordering is deterministic before random selection.
6. Same seed + same commands produces identical replay fingerprints under the tested build.
7. Save/load round-trip preserves gameplay state and RNG continuation.
8. Saves during supported `PendingChoice`s resume correctly.
9. Loading a save does not trigger gameplay effects.
10. Primary-save corruption recovery can fall back to one previous valid backup.
11. Every physical tile copy exists in exactly one valid runtime location.
12. Current topology can be rebuilt from board state without relying on scene objects.
13. Feature lineage/history survives reopening and merging without score farming.
14. Trade Network genealogy survives merge, split, and reconnection.
15. All canonical invariants run successfully after every development-build command.
16. Presentation animations cannot change gameplay result or ordering.
17. Debug overlay can expose topology, lineage, Trade Network, seed, and IDs.
18. Headless test command exits nonzero on failure.
19. Core rules code reaches the zero-warning target.
20. Windows and Linux exported builds can start, create a run, save, continue, and finish a run.

---

# 43. Explicit Non-Goals for Alpha Engineering

Do not allow “future-proofing” to balloon the first implementation.

Not required:

- ECS architecture;
- multiplayer/network synchronization;
- cloud saves;
- online accounts;
- achievements/platform APIs;
- meta-progression database;
- arbitrary feature splitting beyond current rules;
- generalized scripting language for all content;
- controller navigation;
- mobile UI;
- complex predictive AI/scoring preview;
- procedural art system;
- high-end optimization for enormous maps;
- mod support;
- replay video/player-facing timeline system;
- backwards compatibility for every development save revision.

Clean extension hooks are desirable; unused framework complexity is not.

---

# 44. Codex Implementation Rules

When implementing this specification, Codex should follow these rules:

1. **Read the Complete Alpha Rules Specification before implementing any gameplay behavior.** Do not infer canonical gameplay from the older prototype files.
2. **Do not silently simplify a canonical rule because it is inconvenient to code.** If an implementation obstacle appears, preserve the rule and restructure the code.
3. **Do not add gameplay content from older design files that the alpha explicitly defers.**
4. **Do not hard-code prototype balance values throughout rule functions.** Put tunable numbers in Resources/configuration.
5. **Do not let scene nodes become the source of board or game state.**
6. **Do not use uncontrolled randomness anywhere gameplay-relevant.**
7. **Do not trust UI legality calculations.** Revalidate commands in the rules engine.
8. **Do not mutate state before the entire command is known to be legal.**
9. **Do not reset scoring history when features merge/reopen.**
10. **Do not recursively fire child events through arbitrary callbacks.** Use the canonical batch/FIFO queue model.
11. **Do not regenerate persisted random offers after Save/Continue.** Persist the actual offered options.
12. **Do not repair corrupted/incompatible saves silently.** Validate, migrate explicitly if supported, or reject/recover backup.
13. **Add automated tests alongside each rules subsystem.** Do not postpone the entire test suite until the end.
14. **Favor readable, explicit alpha code over speculative abstraction.**
15. **Keep the map as the build.** Engineering choices must preserve the visibility and inspectability of the actual board state.

---

# 45. Final Architecture Summary

The alpha implementation should be understood as five cooperating layers:

```text
STATIC CONTENT
Typed .tres definitions + AlphaContentManifest + AlphaRunConfig
        |
        v
AUTHORITATIVE DOMAIN
GameSession + RunState + stable runtime IDs
        |
        v
RULE / QUERY SERVICES
Placement, topology, lineage, Trade Networks, scoring,
Developments, Transformations, Specialists, Relics,
rewards, Charters, Acts, RNG, events
        |
        v
SERIALIZABLE RESOLUTION BOUNDARY
Commands -> validation -> mutation -> snapshots/batches/FIFO queue
-> PendingChoice or stable TURN_INPUT
        |
        v
PRESENTATION
BoardView / TileView / HUD / dialogs / animations / debug overlays
```

The crucial separation is:

```text
Current board + derived topology
        = what is true now

Persistent lineage + scoring/event history
        = what already happened / scored
```

Everything involving Settlement reopening, feature merging, Bridge, Rewilding, Trade Network growth, Charters, and anti-farming depends on preserving that distinction.

The resulting engine should be simple enough for Codex to reason about, explicit enough to debug, deterministic enough to reproduce, and modular enough that the eventual broader game can grow beyond the alpha without requiring the core rules implementation to be discarded.

---

# 46. Definition of Done

The first implementation pass is done when:

- a player can launch the Godot project on Windows or Linux;
- start a seeded Homestead run;
- play a legal persistent realm through all three Acts;
- use the complete alpha hand/Reserve/Survey system;
- trigger completion/scoring/reopening/merging correctly;
- acquire and use the exact alpha Developments, Transformations, Specialists, and Relics;
- receive deterministic threshold/milestone/Charter rewards;
- see the Grand Charter forecast and midpoint reveal at the correct times;
- Save & Quit at supported boundaries and Continue without divergence;
- finish Act III and receive correct score/victory result;
- reproduce the same random results from the same seed and decisions;
- pass the Complete Alpha Rules handoff checklist and the automated engineering acceptance suite.

At that point the project is ready for actual alpha playtesting and balance iteration rather than further rules reconstruction.
