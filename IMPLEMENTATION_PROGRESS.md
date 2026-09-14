# Mappa Mundi — Implementation progress

## Phase 4 — in progress

Started 2026-09-14 on `phase-4`, after Ro explicitly authorized merging PR #1.
Accepted `main` merge `8b6b6ab` contains Phase-3 final `238b98e`. The full baseline
passed: **274 tests, 0 failures; 88 scripts without diagnostics**, command
`./tests/run_tests.sh`, exit 0, logs `builds/verification/run-GzeIObV5/`.
The new branch is pushed to `origin/phase-4`. Implementation and acceptance tests
are in progress; Phase 4 is not yet complete. Physical Road features remain
separate from the economic Trade graph. Ferry Rights and Phase 5 remain deferred.

## Phase 3 — complete

Verified 2026-09-13 on `phase-3`. Phase 4 has not started. Phase-2 baseline
`e0fea94` remains unchanged on `main` and `origin/main`.

### Architecture and behavior

- `FeatureComponentState` uses run-scoped IDs with type, coordinate and independent
  origin Act/source metadata. Founding creates four distinct stubs; hybrids retain
  separate components. Field never receives a component or lineage.
- `TopologyService` reconstructs same-type connectivity deterministically from
  effective sockets and local groups. `CurrentFeature` is derived and contains
  members, coordinates, open exits and current lineage ID. Rebuilds allocate
  nothing; reconciliation records the current board revision.
- `LineageService` retains identity through growth/reopening and creates a new
  descendant on merger. Sorted parents remain archived; ancestry and inherited
  component/support scoring sets persist. No arbitrary splitting is implemented.
- `CompletionSnapshot` recursively freezes a deep-owned primitive snapshot.
  Every simultaneous base calculation reads it before any result applies.
  `CompletionPipeline` drains child audit events FIFO after the batch and names
  future Development/Specialist/Relic/milestone/threshold extension stages without
  implementing their effects. Synchronous resolution has no pending player choice
  or serializable mid-batch continuation at this phase.
- `FeatureCompletionRecord` and `FeatureHistoryRecord` persist structured creation,
  growth, reopening, merger, completion, snapshot and Track-change facts. Historical
  largest completed feature sizes and qualified Settlement classes are retained.
  Six tiles without a Development do not automatically qualify for Village/Town;
  an earlier actually qualified class is retained.
- `RealmTrackState` holds cumulative Population/Trade/Culture/Ecology. Settlement
  scores +2 per new component and +1 per new Field/River support category. Forest
  scores +1 per new component plus reevaluated +2 undeveloped preservation. River
  scores floor(size/2) and new distinct Forest contacts; ordinary reopening is
  prohibited. Road scores only +1 per new component.
- **Road +2 per Settlement remains explicitly deferred to Phase 4.** No network
  graph, transitive access traversal, Ferry Rights, Market or Port behavior exists.
- `FeatureContactService` requires genuine shared-socket/internal contact. Explicit
  Settlement/Field metadata supplements the existing hybrid relationships; merely
  finding Field or River elsewhere on a neighboring tile does not qualify support.
  Support identity is the stable board-base ID, separately scoped by lineage and
  category; current contact and historical eligibility are distinct.
- `EnclosureState` and `EnclosureService` provide the Monastery foundation separately
  from connected features. All eight surrounding squares must be occupied; +5 Culture
  plus one per natural square scores once. Development ID zero explicitly denotes
  the deferred fixture context. Monastery is not playable or in the bag; Abbey
  upgrade gameplay remains deferred.
- `FeatureResolutionService` integrates after legal placement and before refill.
  Conservative counter-capacity checks preserve invalid-command atomicity.

### Persistence and invariants

`FeatureSerializer` explicitly encodes components, origins, lineage parents and
membership, scoring sets, completions, audit records, Tracks, enclosures and
revisions. Full-width counters/IDs remain decimal strings. Normalization sorts
unordered registries/sets while retaining FIFO histories and ordered physical zones.

On load, `FeatureInvariantValidator` rebuilds topology purely and checks persisted
membership/completion against the graph. It validates cross-kind IDs, origins,
acyclic ancestry, inactive parents, scoring sets against ancestral completion facts,
Track totals/children, genuine growth phases, support references and enclosures.
Loading never reconciles, allocates, emits events, scores or consumes RNG. Repeated
loads preserve exact fingerprints and continuation. Current explicit board fields
are required; older board shapes are rejected, not silently migrated. Legacy
foundation/Phase-2 fixture variants with null feature state remain supported.

Controlled tests use `phase_three_factory.gd` for invariant-valid physical states
and fixture-only geometry revisions. No Urban Expansion, Bridge, Rewilding or
Development player command was added to produce the scenarios.

### Acceptance evidence

`./tests/run_tests.sh` exited **0**, Godot `4.7.2.stable.mono.official.ed1daf0bf`:

```text
PASS: editor import
PASS: 88 GDScript files parsed without diagnostics
RESULT: 274 passed, 0 failed
```

Full logs: `builds/verification/run-STB3jRHO/`. All 191 earlier tests pass.
Phase 3 adds 83 tests: 25 topology/lineage, 20 scoring/snapshot/contact, 15 full-state
scenarios and 23 serialization/corruption tests.

The mandatory anti-farming cases pass: Settlement re-completion pays only new
growth/support; Forest re-completion preserves old scoring and reevaluates its flat
bonus; Road re-completion pays only new tiles; independently scored parents merge
without resetting eligibility. Settlement merger also preserves parental support
history. Current topology and persistent histories agree after every stable step.

The standalone command documented in README ran
`tests/replay/phase_three_demo.gd`, exit **0**, without diagnostics:

```text
DEMO Phase 3: 12 seeded legal placements; completed types=[1, 0, 2, 3]; Tracks=[10, 2, 0, 5]; save/load after 5; identical topology, lineage, history and scoring continuation.
DEMO RESULT: seeded four-feature scoring, shared completion snapshot, anti-farming, Monastery and save/load continuation passed.
```

Demo log: `builds/phase3-demo.log`. Separate controlled scenarios complete Road and
Settlement simultaneously, prove live peer mutation cannot change frozen scoring,
and complete a Monastery for 13 Culture. Crossing all four Track thresholds causes
no rewards or RNG consumption. Repeated load creates zero gains/events/IDs.

### Git, review and remaining scope

Tested checkpoints: `9875107` (topology/history/scoring foundation, 235 tests) and
`cf15bfa` (full acceptance and persistence coverage, 274 tests), pushed normally to
`origin/phase-3`. Final documentation is committed after those checkpoints. The
branch is prepared for an unmerged PR against `main`.

Review corrected incomplete delegated tests after a service usage limit, a typed
enclosure-array initialization error, and overly broad Settlement classification.
Fresh successful verification above supersedes intermediate failures. No known
gameplay errors, GDScript diagnostics, third-party dependencies or unresolved
specification ambiguities remain. All six source specifications are unchanged.

All Phase-3 exit conditions are satisfied, including canonical anti-farming
re-completion. Reserve impossibility remains deliberately conservative. Trade
Networks, playable Developments/Upgrades/Transformations, Specialists, Relics,
threshold rewards, Charters, Act transitions, UI and art remain deferred.
Recommended next action: review the Phase-3 PR. Do not begin Phase 4 without a new
explicit instruction; do not merge automatically.

## Phase-2 revalidation — 2026-09-13

The continuation request described Phase 2 as not started, but inspection of the
exact project root found the complete implementation recorded below. Reviewed
the existing board, static content, commands, RNG, serialization, invariants and
tests against the canonical rules and implementation specification. No gameplay
changes or additional tests were needed; Phase 0/1 infrastructure is preserved.

Fresh verification: `./tests/run_tests.sh`, exit **0**, Godot
`4.7.2.stable.mono.official.ed1daf0bf`:

```text
PASS: editor import
PASS: 63 GDScript files parsed without diagnostics
RESULT: 191 passed, 0 failed
DEMO Mappa Mundi: 12 placements; Reserve, Survey, rotation; save/load after 5; deterministic continuation verified.
```

Evidence: `builds/verification/run-tm3apOyc/`. All 104 Phase-0/1 tests and all
87 Phase-2 tests pass. Exact inventory is 55 Expansion copies across 21 designs,
plus the separate Founding copy; opening hand is 3 and remaining bag is 52.
Deterministic query ordering/deduplication, command rejection fingerprints,
Reserve/Survey in either order, free dead-hand cycles, global stalemate and
three successive empty-bag replenishments pass. Round-trip board/zone metadata,
RNG continuation, future IDs, fingerprints and invariants all pass.

README now links the existing visual authority,
`Mappa_Mundi_Visual_Design_Specification_v0.2.md`. Its v0.2 area-edge presentation
guidance introduces no Phase-2 gameplay conflict. All six source specifications
remain unchanged. README local-link validation and `bash -n tests/run_tests.sh`
also pass. Backups precede documentation edits (`*.bak-20260913-074845`).

No known gameplay errors or unresolved specification ambiguities were found.
Reserve proof deliberately remains `NOT_PROVABLY_IMPOSSIBLE` until later alpha
actions support a sound proof. Every Phase-2 exit condition remains satisfied;
Phase 3 has not started. Git remains on uncommitted `main`, with untracked source
and no repository-local author identity; no Git configuration was changed.
Next action: review the checkpoint and explicitly authorize Phase 3 when ready.

## Phase 2 — complete

Updated 2026-09-10. Implementation is scoped to board and basic Expansion placement;
Phase 3 has not started. The Phase-1 and Phase-0 records below are historical.

Components added:

- Sparse `BoardState` and `BoardCellState`, deterministic frontier and query ordering,
  clockwise rotation, exact edge matching and typed revision/signature previews.
- Full Homestead static profile: 21 Expansion definitions plus fixed Founding Tile,
  explicit internal feature groups/access/touch relationships and exact 55-copy bag.
- Typed commands and `RulesEngine`, seeded setup, ordered physical bag/hand/Reserve,
  Survey removal, engine-owned refill, dead-hand cycling and emergency replenishment.
- Optional typed `ExpansionState`, strict JSON encoding/decoding, normalized metadata,
  and invariants for physical zones, local geometry and placement history.
- Dedicated content, board/query, gameplay and serialization suites, including a
  scripted seeded placement/save/load continuation demonstration.

Decisions and scope:

- Preserve the working minimal Phase-0 content profile and Phase-1 SETUP fixtures.
  Initialized runs explicitly load the new Homestead profile. Schema 1 has an optional,
  strictly validated Expansion section; no existing field is reinterpreted.
- One qualifying free cycle resolves automatically after an action/opening draw;
  a still-dead redraw can request another free `CycleDeadHandCommand`. Reserve is
  ignored by the dead-hand/global-stalemate tests and is never removed heuristically.
- A global-stalemate emergency addition and dead-hand return form one batch with
  one full-bag shuffle. Empty-bag draws likewise add their entire three-copy batch.
- Act-I placement 18 stops at the deferred transition and retains its pending refill.
- `ReserveProofService` returns `NOT_PROVABLY_IMPOSSIBLE`. Proof coverage must expand
  with later alpha actions before automatic removal can be justified.
- Runtime counter capacity is checked before commands mutate, preventing partial
  resolution at integer exhaustion. Invalid commands preserve authoritative state.
- Visual specification read; no artwork, TileMap authority or presentation coupling
  added. All six source specifications are preserved.

Full verification on 2026-09-10: `./tests/run_tests.sh`, Godot
`4.7.2.stable.mono.official.ed1daf0bf`, process exit **0**:

```text
PASS: editor import
PASS: 63 GDScript files parsed without diagnostics
RESULT: 191 passed, 0 failed
```

Logs: `builds/verification/run-0EoiTGq5/` (ignored generated output).
All 104 previous tests remain passing. Phase 2 adds 87 tests: 24 content,
21 board/rotation/query, 16 serialization/invariant and 26 gameplay tests.

The scripted integration demonstration reports:

```text
DEMO Mappa Mundi: 12 placements; Reserve, Survey, rotation; save/load after 5; deterministic continuation verified.
```

It starts seeded Homestead with the fixed Founding Tile, verifies the exact
55-copy starting inventory (52 remaining after the opening three draws), places
from Reserve and hand, checks refills/physical identities, and compares original
and loaded states after every continued command. RNG results, future ID allocation,
zone order, board metadata and normalized SHA-256 fingerprints remain identical.
Separate tests prove free dead-hand cycling, Reserve exclusion, exact global and
repeatable empty-bag emergency sets, invalid-command atomicity, and the pending
refill at the deferred Act-I boundary.

Review found two issues, both corrected and regression-tested: commands now
reserve counter capacity before mutation, and every nonfounding board cell must
connect to an earlier placement. An integrated test also exposed engine-dependent
StringName sorting in emergency-set validation; explicit String comparison fixes
it without changing the canonical set. Final review of the corrected boundaries
and the full successful test output found no remaining implementation errors.
The initial sandbox socket failure and checks against incomplete test files were
superseded by the successful full run above.

Every Phase-2 exit condition is satisfied. No known GDScript warnings/errors,
third-party dependencies or unresolved specification ambiguities remain.
The conservative Reserve-proof limitation is intentional and remains deferred.
No feature topology, scoring, Acts transition behavior or presentation art was added.
No existing gameplay subsystem was restructured beyond the requested extensions.

Git: `main`, no commits; project sources remain untracked/uncommitted. Repository-local
author identity is still absent. No identity was invented and no Git configuration
was changed. Godot caches, verification logs and timestamped backups remain ignored.

Recommended next action: review this Phase-2 checkpoint, then explicitly authorize
Phase 3 (feature topology, lineage, completion and base scoring). Implementation
stops here until a new instruction.

## Phase 1 — complete (historical)

Phase-1 work covered identity, state, RNG and serialization foundations only.
The Phase-0 verification record is retained below.

Major components:

- `RunIdAllocator`: a positive monotonically increasing run-local ID space,
  serialized continuation cursor, overflow guard and no dependency on object IDs.
- `RunState`: authoritative metadata, SETUP phase, one allocator, one RunRNG,
  typed physical-copy and location registries. Seed/state/cursor getters forward
  the owners, avoiding duplicate continuation state.
- `TileCopyState` and `TileLocationState`: distinct physical identity, static
  definition ID, acquisition metadata and ID-only location references.
- `RunRNG`: explicit seed, exact native-state restoration, bounded range/index
  helpers, Fisher–Yates shuffle, ordered candidate selection and an operation
  counter with optional transient reason logging.
- `RunSerializer`: versioned human-readable JSON, typed success/failure results,
  explicit encodings, strict shape/version/range/reference checks and fresh objects
  on load. No files, autosaves, commands, events or player-facing SaveService.
- `StateNormalizer`: shared serialization mapping, sorted unordered registries,
  canonical representation and SHA-256 fingerprints. No presentation state.
- `InvariantValidator`, `InvariantReport`, `InvariantIssue`: ID uniqueness/cursor,
  static and physical references, exactly-one-location, acquisition metadata,
  supported phase and continuation owner checks. Internal failures have a separate
  diagnostic/assertion path from ordinary player validation.

Engineering decisions:

- Encode full-width signed 64-bit IDs, seeds, native RNG state and counters as
  canonical decimal strings. JSON floating-point parsing must not round them.
- Preserve schema version 1 and rules alpha-1: these are the first runtime saves;
  no gameplay behavior changed. Implementation phase is now 1, while the separate
  content-phase constant stays 0 so the working minimal registry is preserved.
- Require the exact Godot build recorded in a save; cross-version deterministic
  continuation has not been verified. No implicit conversion/migration is offered.
- Phase-1 fixtures contain removed-from-run physical copies, including allocation
  gaps. Only SETUP and REMOVED_FROM_RUN locations are enabled. Future location
  enum names do not implement bag/hand/board containers or placement behavior.
- The allocator cursor persists independently of surviving entities; missing old
  entities never cause their IDs to be reused. The maximum signed integer is an
  exhausted-cursor sentinel. Exhausted allocators/counters fail before overflow.
- RNG diagnostic reasons are transient; the operation counter is persisted.
  Empty/singleton shuffles count as one helper call while consuming no random draw.
- Native RNG state provenance cannot be proven from an arbitrary edited integer;
  validation checks the representable state, ownership, metadata and references.
  Saves are not authenticated or intended as a tamper-proof format.

Tests added: 20 identity/state/invariant tests, 13 RNG tests, 16 serialization/
normalization tests and 2 integration round-trip tests. All 53 Phase-0 tests remain.

Latest full verification: `./tests/run_tests.sh` on 2026-09-09, Godot
`4.7.2.stable.mono.official.ed1daf0bf`, exit 0:

```text
PASS: editor import
PASS: 35 GDScript files parsed without diagnostics
RESULT: 104 passed, 0 failed
```

Final verification logs: `builds/verification/run-fhbbrWrN/` (ignored generated output).
The representative round trip advances RNG before saving, restores its current
state, validates invariants, compares normalized state/fingerprints, continues
range/index/shuffle operations identically and allocates IDs 7–11 on both states
without reusing gaps. Extreme signed values and values above 2^53 round-trip exactly.
Malformed JSON, incompatible metadata, wrong types, unknown fields, invalid IDs,
duplicate/dangling/missing locations and unsupported future state are rejected.

No specification contradictions or Phase-1 blocking ambiguities were found.
No new third-party dependencies. No five-source-specification edits.
Git identity remains unavailable; no commit or Git configuration change made.
Cross-version replay, disk save recovery and all Phase-2 gameplay remain untested
and unimplemented by scope.

Independent review approved Phase 1 with zero actionable findings and independently
reproduced all 104 tests and 35 clean script checks. Final headless bootstrap smoke
test exited 0 and reported `Phase 0 content validated (2 tile definitions)`, confirming
the original static-content boundary still works. Log: `builds/phase1-bootstrap.log`.

Every Phase-1 exit condition is satisfied: seeded RNG tests, exact continuation,
basic and representative save/load round trips, fingerprints, invariant validation,
all Phase-0 regressions and zero-warning core diagnostics. No known implementation
errors remain. The five original specification hashes still match the Phase-0 baseline.
Git remains on `main`, with no commits and source files untracked; no local author
identity was available. Generated Godot cache and verification output are ignored.

Next recommended work is Phase 2 (board and basic tile placement), but it requires
a new instruction. Implementation stops here.

## Phase 0 — complete

Verified on 2026-09-09 with Godot **4.7.2.stable.mono.official.ed1daf0bf**.
The project uses GDScript only; the installed engine happens to be the .NET build.
This is the historical Phase-0 record; Phase-1 status is above.

Implemented:

- Godot project and minimal responsive bootstrap, Linux/Windows export presets.
- Domain/content/presentation/test directory boundaries from Implementation §3.
- Typed finite domain vocabulary, GamePhase vocabulary, ValidationResult.
- Implementation-spec version 1, save-schema version 1, rules version alpha-1.
- Passive Tile/Relic/Specialist/Charter/Manifest/RunConfig Resource classes.
- Explicit Phase-0 manifest with canonical Open Fields and Straight Road samples.
- Act limits 18/22/26 and Track thresholds 20/40/70/100 in configuration data.
- Scene-independent ContentRegistry and fail-closed structured static validation.
- Project-owned test framework, headless runner and diagnostics-checking wrapper.

At Phase 0 there was no gameplay state, ID allocator, RNG stream, physical tile bag, placement,
topology, lineage, scoring, reward behavior, or serializer yet. Reserved module
directories are intentionally empty. No canonical rule was replaced or simplified.

## Verification evidence

From the project root:

| Check | Command | Result |
| --- | --- | --- |
| Fresh import, all scripts, headless suite | `./tests/run_tests.sh` | Exit 0; `PASS: editor import`; `PASS: 18 GDScript files parsed without diagnostics`; `RESULT: 53 passed, 0 failed` |
| Assertion failure detection | `./tests/run_tests.sh --self-test-failure` | Expected exit 1; `RESULT: 0 passed, 1 failed` |
| Runtime failure detection | `./tests/run_tests.sh --self-test-runtime-error` | Expected exit 1; deliberate out-of-bounds error detected |
| Headless bootstrap | `godot --headless --path . --quit-after 2` | Exit 0; `Mappa Mundi: Phase 0 content validated (2 tile definitions)` |
| Desktop editor | `godot --editor --path . --quit-after 120` | Exit 0; editor initialized using Intel OpenGL |
| Desktop bootstrap | `godot --path . --quit-after 120` | Exit 0; same two-definition validation message |
| Shell syntax | `bash -n tests/run_tests.sh` | Exit 0 |

Verification isolates Godot data/config/cache using project-local XDG directories
under ignored `builds/`. Editor/desktop checks ran outside the restricted sandbox
because the editor opens local sockets. Wrapper logs for the successful run are
under `builds/verification/run-Apf09Qv4/`; these generated logs are not Git content.

Independent Codex review approved the implementation with zero actionable
architecture/specification findings. It also reproduced the 53 passing tests,
18 clean script checks, startup validation, and intentional failure exits.

All Phase-0 exit conditions are satisfied. No known GDScript warnings remain.
Warning-as-error policy and additional typing warnings are enabled in project
settings; the wrapper also rejects engine/script diagnostics independently of
Godot's exit status. This catches nested runtime errors that may not propagate
to the runner's test-completion sentinel.

## Issues and limits

- **Environment:** Desktop launch printed `failed to load driver: nvidia-drm`
  and a DRI3 initialization message, then successfully used Intel Arc OpenGL.
  This is a host graphics fallback, not a GDScript error; no driver changes made.
- **Git:** Repository initialized on `main`. No commit created: Git reports
  `Author identity unknown`. No identity was invented or global settings changed.
- **Workspace tooling:** `omx doctor` reported 9 passes, 2 warnings, 1 failed
  check: Codex CLI execution was denied by the sandbox (EPERM). Explore routing
  was disabled and project OMX state had not been created. OMX is not a game
  dependency; no setup/profile changes were made for this game task.
- **Content coverage:** Phase-0 validation is explicitly limited to its minimal
  sample pool. It does not claim the full 55-copy bag, reduced rosters, upgrade
  prerequisites or Charter checks are implemented. Future manifests are rejected.
- **Not tested:** desktop interaction such as F11/resizing, exports, and other
  Godot versions. No later-phase gameplay exists to test.

## Specification questions

No Phase-0 blocking contradictions or unresolved specification questions found.
The prompt's `~/home/Jane/MappaMundi` did not exist; implementation used the
existing five-document project at `/home/rochelle/Jane/MappaMundi`.
All five original specification documents retain their original names and bytes.

## Phase-0 handoff (historical)

The next assignment was Phase 1: run-scoped IDs, RunState/TileCopyState skeletons,
run-owned deterministic RNG, serialization, normalized fingerprints and invariant
foundations, with seeded RNG and basic save/load round-trip tests.
