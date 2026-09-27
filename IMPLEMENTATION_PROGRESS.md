# Mappa Mundi — Implementation progress

## Second playtest — draft cadence (current rules)

The active rules version is `alpha-playtest-r1-draft-cadence`, save schema 3.
This replaces both the 45-copy starting bag and all automatic Act-II/III seeding,
including the previous four-Market experiment. Older active-run development saves
are rejected explicitly; no migration or Phase-11 Save/Continue UI was added.

The fixed core has 18 copies across ten designs: Forest Edge ×3, Forest Bend ×1,
Forest Belt ×1, Straight Road ×2, Bending Road ×2, Road Junction ×2, Hamlet Edge ×3,
Settlement Corner ×1, Settlement Throughway ×1 and Settlement Gate ×2.

Canonical setup now consumes RNG for the environmental path, Act-I Charter and
three distinct Starter Draft options, then pauses before drawing any hand tile.
The chosen directional design creates one physical copy; one full-bag shuffle
precedes the opening draw from 19 copies. There is no initial core shuffle.

`TileDraftService` uses configured sorted pools and persisted `tile_draft` choices.
`ResolveTileDraftCommand` validates the exact offer before acquiring one copy and
shuffling the bag. Draft offers and acquisitions are recorded in reward history,
with starter/cadence/act-entry sources, sequence, Act, placement and physical ID.
Normal Tile Rewards retain their larger existing class quantities.

Cadence drafts follow every second normal placement: nine in Act I, eleven in
Act II and twelve in Act III. Act III placement 26 has no draft. All consequences,
reward chains and bonus placements finish first; the draft precedes refill and,
on Act I/II's final placement, outgoing Charter evaluation. Reserve placements
count normally; bonus placements do not advance cadence.

Act transitions retain outgoing rewards and refresh ordering, then unlock content,
reveal the required Charter information and pause at an Entry Draft. Act II offers
three of its five new designs; Act III offers all three new designs. The single
chosen copy is shuffled before the placement counter resets and the pending hand
refills. No automatic transition copies are created. Regular draft pools grow
from 20 to 25 to 28 designs. Unlocking a tile means it can enter the player's
choices; it does not mean every run automatically contains it.

Track 20 records a crossing but has reward `NONE`: no queued job, choice, copy or
RNG. Track 40/70/100 remain training/Relic/Major rewards. Market Towns and Market
placement are unchanged; no Market guarantee, helpfulness weighting, Specialist,
Relic, scoring or victory redesign was added.

The presentation has one-click draft cards, Starter Charter inspection, Entry Draft
explanations, a next-draft HUD indication and acquisition feedback. Core rules
remain headless. The branch remains `alpha-playtest-r1`, unmerged.

Baseline before editing: `bfbd476a6917397262251d380066966c5ff756cd`, clean;
1,243 gameplay tests, 95 presentation tests and 232 scripts passed with no failures
or parser diagnostics.

The verification work exposed one existing fingerprint-only defect: sorting
`StringName` enclosure stages/Development families could follow process-specific
intern identities. `StateNormalizer` now compares their text explicitly. A 64-name
regression covers this; before/after authoritative JSON envelopes match exactly.
No scoring, topology, acquisition or RNG behavior changed as part of this fix.

The non-canonical 100-seed Act-I closure sample achieved 100% with at least one
completion, median 7 and mean 6.48 (Road 257, Settlement 238, Forest 151,
Monastery-family 2). It produced 59 unordered Starter triples and 100 acquired
design/count profiles. Of 1,000 draft choices, 204 repeated a previously chosen
design. These are automated heuristic results, not human-play evidence.
The full current diagnostic policy, Market-access sample and inventory snapshots
are in [the draft-cadence report](docs/DRAFT_CADENCE_DIAGNOSTIC.md).

Final verification on 2026-09-27:

- `./tests/run_tests.sh`: **1296 passed, 0 failed; 240 scripts parsed without
  diagnostics**, exit 0 (`builds/verification/run-Gf2VxiBN`).
- `./tests/run_presentation_tests.sh`: **108 passed, 0 failed**, exit 0
  (`builds/verification/presentation-7SgSEzV9`). Both wrappers reject engine errors
  and warnings. Net increases from baseline: 53 gameplay and 13 presentation tests.
- Five complete scripted runs cover no victory, Victory, Exemplary Victory,
  deterministic replay and save/load replay. Each resolves 66 normal placements
  and all 35 drafts through commands. Two natural-bag controller runs resolve the
  same decisions through visible choice buttons and match exactly.
- Three additional natural diagnostic runs finish all 66 placements/35 drafts;
  their independent replays match. The 100-seed Act-I sample and 30 naturally
  selected Market Towns cases were independently replayed without changed offers,
  acquisition outcomes or inventory checkpoints.
- Automated graphical mouse smoke: 15 checks passed at 1280×720, including
  Starter Draft, Charter inspection, returning to the same offer, and choosing.
  This was automated input; no new human manual playtest was performed.
- Save/load covers Starter, cadence, both entry drafts, outgoing Charter reward
  chains, stable transition steps, reveal and completed results. No offer rerolls,
  duplicate copies, replayed shuffles or duplicate refills occur.

Current scripted seed-22 fingerprints:

- No victory: `7c23799622dca9fd54db3610f0b853a79ad334044721e607600b7bcff7d87315`
- Victory and save/load replay: `d514178bbf23ebb4bae864268b5c0c767944101b89331e2c90d7d34c9b29328b`
- Exemplary Victory: `7a0522e3b48861e71d191544fa606ee8a29d4396d28ff5039abdc9dce1f92115`
- Natural controller seed 1010 and replay: `65ecf013a5bb4de1ef1c28e417d7c822c7fd67392154c2b425cf1d1887033c43`

Market access remains a human-review concern: of 30 naturally selected Market
Towns runs (107 seeds screened), 70% saw Market at entry, 93.33% acquired one by
Act-II end and 73.33% acquired two. Conditional median first/second acquisition
was entry/placement 8. Eight runs failed to acquire two; acquisition does not prove
that two distinct legal host Settlements can receive them before evaluation.
No guarantee, weighting or Charter adjustment was added.

Superseded tests now assert the 18-copy core, setup paused at Starter choice,
one-copy entry acquisition instead of 10/6 automatic seeds, and no reward at 20.
Existing completion/topology/Market/Charter/Relic/Specialist expectations remain.
There is no unresolved gameplay ambiguity or known blocking presentation defect.
No Phase 11/12 work, new art, deferred content or unrelated balance change was made.
Next step: another human playtest using `docs/ALPHA_PLAYTEST_R1.md`.

All subsequent sections are historical implementation checkpoints. Their old bag,
seeding, threshold and fingerprint values are superseded by this section and the
current canonical specifications.

## Superseded experiment — Act-II Market availability

This historical checkpoint used **Market ×4, Port ×2, Urban Expansion ×2,
Town Square ×1, Abbey ×1: exactly 10 physical copies**. This replaces the previous
2/2/2/2/2 distribution. Market Towns still requires two distinct current Market-family
Settlements, Trade 40+ and its historical-Road/current-network condition. Market
placement, occupied-host immediate effects, Mixed-Use legality and Grand Market's
Act-III unlock are unchanged. Act III still seeds its three designs twice each.

Ordered design/count entries now live in `RunConfig.act_two_seeds` and
`act_three_seeds`, configured in `homestead_run_config.tres`. The transition,
seed-history invariant and presentation summary consume this single definition.
Copy identity/provenance and the separate full-bag shuffle before pending refill
retain their existing implementation. No unrelated balancing or Phase 11 work.

Optional non-canonical draw diagnostic: exact sampling without replacement, with
four Markets and 22 accessible draws, gives the following conditional probabilities:

| Bag at Act-II seeding/shuffle | At least one Market | At least two |
| --- | ---: | ---: |
| 35 copies | 98.634% | 86.618% |
| 45 copies | 94.057% | 67.907% |
| 55 copies | 88.002% | 52.808% |

The 35-copy case assumes 45 initial player copies, 18 Act-I active-hand placements,
two retained hand tiles and ten new seeds, with no reward additions, Survey, Reserve
or cycling. Its 22 draws include the incoming transition refill and 21 Act-II refills;
the final Act-II refill belongs to Act III. The old two-Market case gives 86.891%
for at least one and 38.824% for both. Compute exactly with `math.comb`:
`P(0)=C(N-M,22)/C(N,22)`, `P(1)=M*C(N-M,21)/C(N,22)`.
These are draw-access estimates, not placement or Charter-success probabilities.
Real rewards and player actions change the bag and sampling process.

Updated seed-25 scripted full-run fingerprints:

- No victory: `5b8eda81c351a271b9f8f5085f2a583d90b0746ecdec04bc7999de9260f5fb4c`
- Victory: `3f660fb67f2efd1136735c75fd7ae551ff72652bca2e1fbd35407a4b41f616df`
- Exemplary: `4a395f248aa89af6ff3d74a064c7b213aaed96c9c3dc09d11e892d9dc49df105`

Verified 2026-09-27: `./tests/run_tests.sh` exited zero with **1243 passed, 0 failed**
and **232 scripts parsed without diagnostics** (`builds/verification/run-NEIzkuWc`).
`./tests/run_presentation_tests.sh` exited zero with **95 passed, 0 failed**
(`builds/verification/presentation-s6HYn4ol`). Both wrappers reject Godot errors/warnings.
Five complete scripted runs retain all outcomes, deterministic replay and save/load
replay; the restored Victory fingerprint matches the fresh Victory above.
Two complete natural-bag controller runs retain [18,22,26] placement counts and share
fingerprint `eb576b5429eb83f7282b110b3bbd6aeae3a49060e840cc7d2b71efa333e1c232`.
Tests verify exact seed quantities/identity/provenance, full-bag shuffle, seed-before-refill,
Market/Grand Market unlocks, malformed seed configuration, transition text and the
unchanged requirement for two distinct Market-family Settlements.

## Alpha Playtest Revision 1 — first revision checkpoint (superseded seeding/fingerprints)

Implementation commits: `15caab4` (canonical gameplay/content/tests) and `9fa20f6`
(presentation/readability/tests). Final documentation follows on the same branch.

This revision follows the first human Phase-10 playtest. It deliberately replaces
the old bag, River lifecycle and Junction topology; it does not begin Phase 11.
Rules version is `alpha-playtest-r1`, save schema **2**. Incompatible older active-run
saves are rejected clearly, without migration or new Save/Continue presentation.

### Accepted Phase-10 closeout

Accepted tip `f1e841739411770e161bd30d774bc45a5b376c68` was clean and matched origin.
Fresh verification before and after normal [PR #8](https://github.com/CrackedEggProductions/Mappa-Mundi/pull/8)
merge passed **1167 gameplay tests, 86 presentation tests and 223 script parses**,
with zero failures or Godot diagnostics. Merged main is
`7055150c81a98a078696f8520e4e6746eb22ecb7`. `alpha-playtest-r1` was created and pushed
from that clean main. This revision remains on its review branch.

### Canonical changes and authoritative services

The Complete Rules and Implementation Specification now describe the revision in
place, with an explicit supersession section. Open Fields and Road End remain legacy
definitions/art but cannot enter player inventory, rewards or emergency injection.
Pure River definitions are setup-only. Emergency replenishment uses Hamlet Edge,
Road Junction and Forest Edge.

| Starting design | Copies | Starting design | Copies |
| --- | ---: | --- | ---: |
| Forest Edge | 4 | Forest Bend | 3 |
| Forest Belt | 2 | Straight Road | 4 |
| Bending Road | 4 | Road Junction | 4 |
| Hamlet Edge | 4 | Settlement Corner | 3 |
| Settlement Throughway | 2 | Settlement Gate | 3 |
| Riverside Hamlet | 2 | Woodland Road | 2 |
| Woodland River | 2 | Settlement Corner Gate | 2 |
| Settlement Road Bend | 2 | Settlement Road Throughway | 2 |

The exact total is **45 unique physical player copies**, including the two explicit
Act-I overlay exceptions. Normal rewards grant those Specialized/Hybrid overlays
two copies; Masterwork remains eligible and grants three.

`EnvironmentalRiverService` selects one of 24 validated paths using one RunRNG
selection before bag randomization and Act-I Charter selection. Founding's South
River joins five Runs, two separated Bends and a final End: nine connected River
tiles, eight setup-acquired copies, no collisions, normal placements or rewards.
Seed 1 bends at `(0,2)` and `(4,2)`; seed 42 at `(0,3)` and `(3,3)`; seed 1010 at
`(0,3)` and `(2,3)`. Saves retain physical coordinates/orientations rather than
regenerating a path. River remains current topology with no completion/reopening.

`IntersectionHubState/Service` extends the existing Trade Network graph. Junction
sockets terminate attached Roads without creating a Road component. Separate Roads
can complete simultaneously, stay separate lineages, and share commercial reach
through Junction, Settlement and Ferry links. Junction-to-Junction links add zero
length. Stable hub IDs, attachment queries, genealogy and serialization are covered.

Riverside Hamlet and Woodland River use existing Transformation query/command paths
on occupied Run/Bend cells. Bank matching is validated before mutation; River and
Development capacity survive. `RiverInteractionService` queries active overlays,
Ports and Bridges, and creation history. Setup geography and Ferry Rights do not count.
Port/Bridge/Ferry regressions include generated environmental River targets.

Forest base Ecology now pays new Forest tiles, newly paid distinct River tiles and
the existing undeveloped bonus. Paid River IDs survive Forest merger/recompletion;
same-tile and adjacent duplicate contact count once. Riverkeeper targets unfinished
River-touching Forest and adds full current contact Ecology. Harbormaster targets
unfinished River-touching Settlement and pays same-River Settlements/Ports, including
its host. Generic Stewards exclude River. Training and Relay reuse central eligibility.

Living Landscape uses interaction creation history; Stewardship of Land and Living
Heritage use two/three active interactions. River Stewardship checks genuine
Settlement/Forest completion touching three River tiles, once per run in the existing
fourth milestone slot. Final River statistics report connected size, not completion.

### Presentation and playtest evidence

New Run displays and frames all nine environmental tiles. Occupied-cell overlay
preview/Confirm flows preserve River geometry. Inspection identifies environment,
interactions and Junction termination/Trade behavior. `RichTextLabel.default_color`
in the parchment theme supplies dark ink for Charter progress, forecast and exact
Grand requirements; an inherited-theme regression test protects the fix.

Native 1280×720 captures of the opening map and Charter panel were visually inspected.
Automated viewport mouse input passed **12 checks, zero failures**. These are automated
checks, not a second human playtest. Use [the revision checklist](docs/ALPHA_PLAYTEST_R1.md)
for that next review. Existing art and fallbacks are unchanged; no images were generated.

The [100-seed closure diagnostic](docs/PLAYTEST_REVISION_1_DIAGNOSTIC.md) completed
1,800 Act-I placements: **100%** of runs completed at least one feature, **median 6**,
**mean 5.72**, range 2–9. Totals: **263 Roads, 191 Settlements, 118 Forests**. Its
deterministic policy and all seed counts/fingerprints are retained in the linked JSON.
This tests available closure under a deliberate heuristic, not human completion rates.

Five complete scripted three-Act runs cover failure, Victory, Exemplary Victory,
deterministic replay and save/load at every pending boundary. Two additional natural-bag
runs use the same presentation/controller command path as mouse play, without fixture
acquisitions or direct RunState edits. Seed-25 scripted fingerprints:

- No victory, score 162: `ed05682574b36f6322464c22c5af72ff88d8bd16dbd445a7f6f77e061d7b170a`
- Victory/replay/save-load, score 176: `9a526c7cf19f3418214eabced9baa7ecb2be4bcd7463bba9bc93dd085e4d4e3b`
- Exemplary, score 190: `48cd1051e7459f3afec1c20eb669585d8b071864142ab48804c1e86c7d95d87e`

### Superseded tests and boundaries

Final verification on 2026-09-27:

| Check | Result |
| --- | --- |
| `./tests/run_tests.sh` | **1241 passed, 0 failed** |
| Native parse/import gate | **232 scripts; no diagnostics/warnings** |
| `./tests/run_presentation_tests.sh` | **95 passed, 0 failed** |
| Automated graphical mouse smoke | **12 checks, 0 failures at 1280×720** |
| Scripted full-run suite | **14 scenarios, including five complete three-Act runs** |
| Natural-bag controller harness | **Two complete 66-placement runs; identical fingerprints** |
| Closure diagnostic | **100 seeds; 1,800 normal placements; 94,937 options evaluated** |

Gameplay logs: `builds/verification/run-JQqY64cj`. Presentation logs:
`builds/verification/presentation-3ODsDFAW`. Both wrappers exited zero and reject
Godot error/warning lines. This is a net increase of 74 gameplay and nine presentation
tests over accepted Phase 10, alongside rewritten superseded assertions.
The two seed-1010 natural-bag controller runs share fingerprint
`bac650b865be01ae1fd3f77649f4ff35bce439b25c5ebf91cbdf0b9b9cd510e0`.

Old tests asserting the 55-copy bag, drawable Field/endpoint/River pieces, continuous
Junction Roads, River completion/scoring, old River Specialist targets, River milestone
or Charter River-size/completion requirements were rewritten with explicit replacement
coverage. Unaffected assertions remain protected; synthetic geometry fixtures are
separate from legal player inventories. Existing completion snapshots, FIFO resolution,
threshold/reward order, Act transitions, score formula and victory outcomes are unchanged.

No unresolved gameplay ambiguity remains. Phase 11 Save/Continue, Phase 12 exports,
new art and unrelated balancing were not started. The branch is not merged automatically.

## Phase 10 — playable alpha; ready for human review

Implementation checkpoint: `77369d147d76a52bff8f2200b669aca469ab9b29`.

Verified 2026-09-27. The default project scene now provides New Run and a mouse-first
interface for the complete three-Act engine. The earlier sections below are historical
checkpoints; their branch/scope descriptions apply to their respective phases.

### Accepted branch integration

- Phase-9 tip: `79a1467020f69b9831525195b9481f2e73f18103`.
- Fresh Phase-9 verification: **1167 passed, zero failed, 205 scripts parsed cleanly**.
- PR #7 merged normally: https://github.com/CrackedEggProductions/Mappa-Mundi/pull/7
- Merged gameplay main: `ec33b42fc26c0b56312196eb6f2e5dafd1b8ce41`;
  the full gameplay suite passed again.
- Inspected alpha-art tip: `ea5858a5f57716b57d4cb01c4a967c7856463bc8`.
  Its branch diff contained only 984 art files and 16 Example Tiles assets.
- Normal art merge: `ad6f4ae7474975799bddbf1c25dafdfbddc5c373`; no conflicts,
  no gameplay changes, full gameplay suite **1167/0** after integration.
- Main was pushed, then phase-10 was created and pushed from that clean merge.
  No accepted source artwork was changed during presentation work.

### Scene and command boundaries

`presentation/scenes/bootstrap.tscn` remains the default entry and gameplay scene.
GameController owns GameSession and submits typed commands to existing RulesEngine.
ResolutionResult adapts validation, ordered structured audit records and Track deltas
for presentation. Neither new session class requires scenes, textures or a display.
No existing rules behavior was redesigned or rebalanced.

GameShell uses responsive containers, a board SubViewport and scrollable side/modal
panels. New Run accepts an optional integer seed. Mouse controls cover hand and
Reserve selection, Store, Survey, quarter turns, exact option selection, preview,
Confirm/Cancel, camera pan/zoom/Fit, required choices, notices and final-map viewing.
Keyboard accelerators are optional. Stale options retain revision/signature and are
revalidated by the engine. Input locking and double-click guards prevent duplicate
commands. Preview, cancellation and cosmetic dismissal leave RunState unchanged.

### Board and assets

BoardView synchronizes disposable TileViews from authoritative cells at 192 pixels
per signed grid coordinate. Parchment, subtle seams, exact artwork quarter turns,
Development/Upgrade badges, Specialist markers and effective Transformation geometry
remain readable. Occupied hosts and multiple materially different Port/Transformation
options are individually selectable. Inspection exposes authoritative feature and
Trade Network information without covering the board in runtime IDs.

The registry caches **13 production anchors, seven existing references and 14
mechanical fallbacks**. The exact mapping is in `presentation/assets/README.md`.
Founding Homestead and Road End use fallbacks without changing their art status;
Developments/Upgrades/Transformations use simple badges/thumbnails. Missing optional
images report diagnostics and fall back. No image generation or art polish occurred.
Review caught and fixed art drawing over badges and ambiguous same-cell Port labels;
regression coverage protects both. Camera drag release outside the viewport is safe.

### Choices, HUD and results

All **11** current PendingChoice kinds have a playable presenter: Specialist assignment,
training-piece selection, Specialist training, Tile Reward, Masterwork, Major Reward,
Relic offer, replacement/decline, Compass, Relay and sequential Grand Survey. Frozen
saved order, physical IDs, choice IDs and revision are preserved. Unknown types report
a visible development failure instead of silently blocking. Required choices lock
ordinary actions; the rules engine remains the final validator.

HUD shows Acts/placements, four Tracks, Survey, Reserve, hand, Relics/capacity/uses,
all physical Specialists and authoritative Charter progress. Early Grand information
uses only the permitted forecast query. Reveal and transition notices describe events
already resolved by rules; dismissing them performs no rule command. Fast feedback
uses ordered event text, Track gains and completed-feature highlights.

Results display the stored final score, outcome, Tracks, historical records, Charter
results, Relic/training history and seed. All three outcomes are covered. The final map
remains inspectable, results can be restored, and ordinary play stays disabled.

### Verification evidence

| Check | Result |
| --- | --- |
| Full independent gameplay suite | **1167 passed, 0 failed** |
| Native Godot parse gate | **223 scripts, no diagnostics/warnings** |
| Presentation suite | **86 passed, 0 failed** |
| Board/asset tests | 20 |
| PendingChoice tests | 27 |
| Read-only presentation query tests | 13 |
| Controller interaction tests | 19 |
| Complete-run integration tests | 7 |
| Automated graphical viewport mouse input | **11 checks, 0 failures at 1280×720** |

Commands: `./tests/run_tests.sh` and `./tests/run_presentation_tests.sh` both exited 0.
Logs: `builds/verification/run-Loqkky5F` and
`builds/verification/presentation-MSmzImwl`. Graphical input evidence:
`builds/p10-mouse-smoke.log`. Native graphical captures also verified the entry,
board/preview, modal readability and overlay drawing order.

Two complete **natural-bag** runs (seed 1010) used actual controller Confirm and
choice handlers: 18 + 22 + 26 placements, transitions, Grand reveal, rewards and
RUN_COMPLETE. No fixture tile injection or direct RunState writes. Both ended in
no-victory with identical complete-state fingerprint:
`c74dfd90cc86e3bc4b375ec331bbf2de9502e2250d2629053ec9ecce757e9562`.
Victory/Exemplary results have separate valid-state controller/query coverage.
Core tests still execute without presentation scenes. Preview, stale commands,
cosmetic overlays and view rebuilds preserve authoritative state/RNG where required.

### Human playtest and boundaries

The graphical application was launched and driven with automated mouse events;
**a human has not completed the manual playtest checklist**. Instructions and the
21-step checklist are in `docs/PHASE_10_PLAYTEST.md`.

Fallback art, compact badges and UI/animation polish remain alpha limitations.
The ignored source-art archive loads at project runtime; Phase-12 packaging must
explicitly include/stage the selected images. No export acceptance is claimed.
No Save/Continue/recovery UX, Phase-11 integration, Phase-12 work, new art,
Legendary Projects or deferred gameplay content was added. Phase-10 remains
unmerged for human review. No known blocking presentation bug remains.

## Phase 9 — complete; awaiting human review

Verified 2026-09-27. Phase 9 implements the complete headless three-Act run.
Implementation checkpoint: `a9c8a6ce83ce349711310b878ad8360655bd42b3`.
No Phase 10 presentation, Phase 11 save UX, Phase 12 export work or art changes.

### Phase-8 closeout

Final accepted Phase-8 tip: `87adae16c7d7c73bc69a1ed40e7c622baec18d91`.
The Masterwork ruling is committed: currently unlocked Specialized/Hybrid,
Major/Rare and Upgrades including Abbey; no Basic or ordinary Development designs;
three physical copies. Fresh verification passed **985 tests, zero failures,
183 script parses without diagnostics** (`builds/verification/run-tCCWX4QG`).
PR #6 merged normally: https://github.com/CrackedEggProductions/Mappa-Mundi/pull/6
Merged main `3062f6355e3cb70f1aac402dce348d0b2ed6b195` contains the Phase-8 tip
and independently passed the same baseline (`builds/verification/run-kS1bYVG3`).
`phase-9` was created and pushed from that clean main. `alpha-art` remains unchanged
and unmerged at `ea5858a5f57716b57d4cb01c4a967c7856463bc8`.

### Canonical Charter content and evaluation

The new profile validates exactly three Act-I, three Act-II and three Grand
Charters alongside the existing 34 tiles, eight Specialists and ten Relics.
Typed CharterProgress/ConditionProgress expose condition keys, values, targets,
satisfaction, current-state/history sources and stable witnesses. Evaluations
consume no RNG and mutate no board state. Exceed always requires fulfillment.

| Charter | Evaluator and representative coverage |
| --- | --- |
| Growing Realm | Population 20/30 plus two genuine Settlement completions; Population alone fails and genuine re-completions count. |
| Open Roads | Trade 20/30, two genuine Road completions and current full-network reach of two Settlements; Ferry and distinct reach covered. |
| Living Landscape | Ecology 20/30 plus both Forest and River genuine completion history. |
| Market Towns | Trade 40/55, two current Market-family Settlements and a historically completed Road lineage with current network reach of three; Grand Market and Ferry count. |
| Growing Communities | Population 40/55 and the same current Settlement meeting size six and two Developments. |
| Stewardship of Land | Ecology 40/55 plus current Forest and River size six. |
| Great Metropolis | Population 70/90; one currently completed size-eight Settlement with three distinct Development families and two OTHER network Settlements; any current size-ten Settlement supplies the extra exceed witness. |
| Merchant Republic | Trade 70/90; historically completed Road lineage in a current network of four/five Settlements, with two Market-family-or-Port Settlements; reopening and Ferry supported. |
| Living Heritage | Ecology 60/80, Culture 40/60, current size-eight Forest and River, and genuine Monastery-family enclosure completion including Abbey. |

Current-state facts use current topology. Completion counts use persistent genuine
history, deduplicating inherited records. Upgrades use their base family.
Ordinary Charter rewards reuse the Phase-8 serialized reward engine:
Act I fulfilled = Tile; exceeded = Tile then Relic. Act II fulfilled = Relic then
Tile; exceeded adds Major last. Failure adds no reward or punishment.

### Selection, visibility and transitions

New-run ordering is civilization setup, starting-bag shuffle, uniform Act-I Charter
selection, opening hand. The Act-II information step selects its ordinary Charter
then secretly selects the Grand Charter exactly once. Public queries initially
expose only the forecast. After Act-II placement 11 and every consequence/bonus
chain finishes, exact reveal occurs before turn input and consumes no RNG.
Act III selects no ordinary Charter and never rerolls the Grand Charter.

ActTransitionState stores each of the fourteen canonical steps and completion flags:
outgoing Charter evaluation; ordered outgoing rewards; no-op Legendary hook;
Act advance; capacity; fresh Survey; Relic refresh; unlock; physical seeding;
full-bag shuffle; Charter information; counter reset; deferred refill; turn input.
Outgoing rewards retain the outgoing pool and capacity, including nested Major
reward chains. Act II seeds exactly 10 copies (Market, Port, Urban Expansion,
Town Square, Abbey in quantities 4/2/2/1/1 respectively, revised after the second
human playtest). Act III seeds six (Bridge, Rewilding, Grand Market
twice each). Stable IDs, incoming acquisition Act and seed provenance persist.
Seeded tiles can become the deferred refill. Board, bag, hand, Reserve, Tracks,
pieces, Relics, scoring history, lineages, networks and reward history persist.

The generic FIFO bonus-placement hook reuses authoritative placement/consequences,
does not increment normal counts, defers the original normal refill and outgoing
transition, and permits placement rather than ordinary Survey/Reserve input.
No alpha content grants bonus placements. ResumeActTransitionCommand resumes
serialized intermediate boundaries exactly once.

### Finalization and diagnostics

Act III placement 26 resolves every consequence and reward, then finalizes without
another draw or ordinary transition. RunResult stores the four uncapped Tracks,
their sum, separate no-victory/Victory/Exemplary outcome, Grand evaluation, seed,
historical feature-size records, Relic history, training history and Charter results.
RUN_COMPLETE rejects gameplay mutation commands. Integer representation limits
are checked before mutation; Track rules remain cumulative and uncapped by design.
PhaseNineDebug.inspect exposes pure diagnostic progress, transitions, unlocks,
seed records, counters and final statistics. Exact hidden Grand data is opt-in debug.

### Verification evidence

`./tests/run_tests.sh` exited 0: **1167 passed, 0 failed**; **205 GDScript files
parsed without diagnostics**, including fresh editor import.
Evidence: `builds/verification/run-PfEVSQnY`.
Standalone demos also passed: 14 Phase-9, 20 Relic/reward, 42 Specialist and
40 Transformation scenarios, all without diagnostics. The application bootstrap
validates Phase-9 content cleanly. Logs: `builds/phase9-final-*.log`.
The final bootstrap-only log-label correction was parsed and smoke-tested afterward.

All **985 previous tests** pass. The **182 new tests** comprise:
58 Charter, 34 state/serialization/invariants, 40 Act rules, seven engine integration,
14 complete-run integration, and 29 transition/save integration tests.

Transition saves cover all steps 2–14 for both transitions (26 whole-run snapshots),
three inert reloads at each, actual pending Charter rewards/nested choices, and exact
public-command continuation. Step-one state is covered by codec/unit tests.
The complete-run save replay adds 84 save boundaries. Tests cover hidden/revealed
Grand state, final results, exact offers, RNG/ID continuity, no duplicate seeding,
shuffle, refresh, reward or refill, malformed saves, and atomic invalid commands.

Five complete scripted runs execute **330 normal placements**: failure, Victory,
Exemplary Victory, identical replay and save/load replay. Seed 212 naturally selects
Living Landscape, Stewardship of Land and Living Heritage. The fixture controls
physical tile acquisition and one initial training reward; scoring, placements,
Charter selection/evaluation, outgoing rewards, seeding and finalization all use
normal authoritative rules. Final placement triggers a real Ecology-70 reward
before the tested no-refill ending. These fixtures prove integration, not balance.

| Outcome | Score | Final fingerprint |
| --- | --- | --- |
| No victory | 82 | `ed1c9abbe4bb40ea381cee61c69368c42592d5431fcbb22fe2386fc23a09e899` |
| Victory | 131 | `0eb56ccf1749c06ff823570eb193d12538ef82279203bc7d514d8a3a09d3af84` |
| Exemplary Victory | 180 | `a8831c344740b862cabcf5009ca3131711b83f924280cb71fb93c9f38190dc5e` |

### Human rulings and boundaries

Three user rulings are implemented and recorded in Complete Alpha Rules:
Great Metropolis fulfillment requires a CURRENTLY COMPLETED size-eight Settlement;
Merchant Republic accepts a reopened Road with genuine completion history;
Great Metropolis exceed may use ANY current size-ten Settlement.
No blocking gameplay ambiguity remains.

No presentation UI, save/continue UX, export work, Legendary Projects or deferred
content was added. The bootstrap's existing loader now selects Phase-9 content.
No art files changed. `alpha-art` is untouched. Leave `phase-9` unmerged for review.

## Phase 8 — unconditionally complete

### Phase-7 closeout and branch baseline

Accepted Phase-7 tip, including the Abbey clarification:
`b21fc7077bbfa6de7d99b0707aef6858ba6003a8`. Fresh verification on that tip
passed **717 tests, zero failures, 155 scripts without diagnostics**
(`builds/verification/run-oGRBMG5z`). PR #5 was created against main and merged
normally, without squash or history rewriting:
https://github.com/CrackedEggProductions/Mappa-Mundi/pull/5

Merged main is `28f316ba65b79a0db498d7d2fdd2704daf3cb7c4`. Phase-7 ancestry
was verified, and merged main independently passed the same 717/155 baseline
(`builds/verification/run-avPaMQk7`). `phase-8` was created and pushed from clean
verified main. `alpha-art` remains unmerged and unchanged at
`ea5858a5f57716b57d4cb01c4a967c7856463bc8`.

### Runtime, queues and physical rewards

`RelicInstanceState`, `RelicState` and `RewardState` extend authoritative RunState.
The Phase-8 content profile contains exactly ten passive Relic definitions; deferred
roles/Relics/Charters fail static validation. Earlier profiles remain fixture APIs.
All persisted entities use run-local IDs and all random selection uses RunRNG.

Resolution order is frozen snapshot, base scoring, Development effects, Specialist
effects, returns/Relay, Relic effects, milestones, threshold queue, final hand
refill. FIFO child records preserve ordering without nested UI callbacks.
`ResolutionState.context` and typed PendingChoice preserve the precise suspension
stage. No committed placement is replayed after loading.

All sixteen one-time thresholds queue in Population/Trade/Culture/Ecology order,
then 20/40/70/100 order within each Track. Every crossed threshold earns its reward.
Rewards use one serialized queue, including nested Cache/Relic replacement/Tile
Reward and Specialist training continuations. Training reuses Phase 7; its typed
fallback now becomes a real Tile Reward.

Normal Tile Rewards uniformly offer up to three distinct unlocked designs,
including presently unplayable designs. Copy quantities follow existing metadata:
Basic 3, Specialized/Hybrid 2, ordinary Development/Act-II Upgrade 2, Major/Rare 1.
Every copy has a stable ID, acquisition Act and source history. The full remaining
bag shuffles before the pending ordinary replacement draw. The eligibility Act is
frozen in each job, exposing the future outgoing-Charter hook without Charters.

All four Major Rewards exist. Recruit delegates to the cap-three Steward API.
Masterwork offers Specialized/Hybrid, Major/Rare and Upgrades (including Abbey),
subject to normal Act unlocks, and grants three copies. Relic Cache resolves a
normal Relic offer/replacement and then a Normal Tile Reward. Grand Survey freezes occupied active-hand copies, removes
up to two original choices with sequential emergency-safe draws, then awards one
Survey charge. It neither spends a charge nor triggers Compass, and never selects
Reserve tiles or the empty pending-placement hand slot.

### Relic behavior and representative coverage

| Relic | Runtime behavior and verification |
| --- | --- |
| Boundary Stones | Explicit once-per-Act Expansion intent permits one Field/Forest mismatch, including empty Urban/Rewilding plays. Reciprocal hard seams persist with audited provenance, close Forest exits and survive removal/load; built-edge and multiple mismatches reject atomically. |
| Surveyor's Compass | First normal Survey history gates next-three physical-copy inspection; pending set persists, one chosen replacement enters hand, others return before shuffle. Earlier Survey before acquisition prevents retroactive use; emergency and small bags covered. |
| Wayfarer's Satchel | Two independent Reserve slots reuse normal reservation/draw/placement. Occupied extra-slot removal is forbidden; exact copy zones and round trips covered. |
| Village Green | Exterior Field OR Forest OR River contact awards full current Settlement size in Culture; frozen facts and re-completion/current-state tests preserve base anti-farming separation. |
| Ferry Rights | Existing Trade graph gains same-connected-River Settlement links, propagated through Road/Settlement hubs. Acquisition/removal reconcile genealogy immediately, including splitting, without scoring. Merchant, Road base, Market, Grand Market and milestone consumers tested; physical Road size unchanged. |
| Mixed-Use Charter | Exactly Housing-family plus Market-family coexistence; Grand Market upgrades retain family. Other pairs reject; removal while a square depends on coexistence is illegal. |
| Historic Routes | Act-II/III Road completion awards Culture per current Act-I-origin Road component. Transformation age is independent of old base-square age; shared snapshot/current-state behavior tested. |
| Steward's Relay | Stable piece-ID-ordered returns offer only that piece's role-legal touching unfinished targets. Explicit same-tile contacts and orthogonal member-tile contacts apply; enclosure has its canonical neighbor exception. Earlier choices exclude occupied targets from later choices; exact continuation/save and forged-return rejection tested. |
| One Great City | Current-largest Settlement ties double only newly paying base Population; smaller base is zero while Housing/Mill/Specialist/Relic effects still run. Real completion checks retain +2 each Housing/Mill/Steward and undoubled Village Green. |
| The Long Road | Compares full physical size with pre-batch historical record, doubles only eligible new base Trade, preserves non-base effects. Real Bridge merger joins a previously paid three-tile Road, suppressed two-tile Road and new Bridge into six; only three unpaid components pay doubled, then record becomes six. |

Capacity is 2/4/5, with no inactive inventory. Equipped and replaced acquisitions
remain exhausted forever; merely offered or declined Relics remain eligible.
Replacement validates state legality first. Uses refresh once at Act start; unused
uses never stack and mid-Act acquisition gets the current use. Numeric effects
share immutable facts; sequential bookkeeping uses acquisition order. Central
precedence is prohibition, specificity, then later acquisition.

### Milestones, save validation and regressions

Settlement 8+, Road network five distinct Settlements, Forest 10+ and River 10+
require genuine completion and each trigger once per run. Their offers resolve in
Settlement/Road/Forest/River order before thresholds. Real board-growth and final
placement scenarios verify no premature awards, one-time behavior, serial offers,
saved continuation and deferred hand refill.

Save/load stores exact offers, inspected copies, replacement/Relay/training choices,
Grand Survey progress, queue jobs, threshold/milestone flags, acquisition/use history,
Trade topology, hard seams and both Reserve slots. Loading allocates no identities,
runs no scoring/effects, awards nothing and consumes no RNG. Validation checks exact
job shapes, flag/audit consistency, original frozen Relic facts against geometry
and historical equipment, paid completion records, and authentic Specialist returns.
Malformed nested saves reject cleanly; invalid commands preserve state/RNG/history.

### Verification checkpoint

Initial implementation commit: `25a4f1a6d5ce47b0163d33b82aa3370aa466f59b`.
The post-ruling checkpoint below includes five additional Masterwork regression cases.
Fresh complete acceptance command `./tests/run_tests.sh` exited **0**:

- **985 passed, 0 failed**: all 717 prior tests plus **268 Phase-8 tests**.
- **183 GDScript files parsed without diagnostics**; editor import clean.
- Evidence: `builds/verification/run-a1C6BUnC` (post-ruling full verification).
- Phase-8 command demonstration: **20 scenarios passed**.
- Prior Specialist and Transformation demonstrations: **42 and 40 passed**.
- Fresh bootstrap: Phase-8 content validated, 34 tile definitions, Godot 4.7.2.
- No script errors, engine errors or warnings in acceptance/demonstration logs.
- `git diff --check` clean; no `art/` or `assets/` changes.

New coverage by suite: state/content/save 40; Relic runtime 38; Ferry 20;
Relic completion facts 10; real Legacy scenarios 2; rewards 61; hand/Reserve 44;
geometry 23; real milestones 10; command pipeline 20. Exact offers, RNG state,
physical copy IDs, bag continuation and repeated inert load are covered.

### Resolved canonical rulings

**Resolved from canonical text:** Legacy zero payout leaves otherwise-new base
elements unpaid. RULE-SCORE-ROAD-001/003 and the Implementation Specification describe
paid-element history separately from completion. Completion records retain the
base multiplier and eligible facts; history unions only actual payment. Later
qualifying genuine re-completion can pay those elements for the first time.

**Human ruling applied (2026-09-24):** RULE-REWARD-MAJOR-003 includes
Specialized/Hybrid, Major/Rare and Upgrades, explicitly including Abbey. Ordinary
Developments and Basic Expansions are excluded; normal Act unlocks still apply.
The existing TileClass.UPGRADE metadata distinguishes Abbey from ordinary
Developments without changing normal reward quantities or adding a classification
system. Five regression scenarios cover all three Acts, exclusions, unchanged
normal Abbey quantity, deterministic real Abbey offers, repeated inert saves,
three physical Masterwork copies and identical post-load bag/RNG continuation.
No unresolved Phase-8 specification ambiguity remains. All Phase-8 exit conditions
are satisfied; the branch remains unmerged for human review.

Phase 9, Charter/Grand Charter evaluation, full Act transitions, automatic Act
seeding, final scoring/results, deferred Relics and presentation UI remain outside
this work. Only capacity/use refresh and frozen reward-pool hooks are exposed.
No art files or alpha-art branch contents changed.

## Phase 7 — complete

### Art closeout and gameplay baseline

The human-approved Wave-02 v04 Settlement Gate, Riverside Hamlet and Settlement
Road Throughway images were copied to their corresponding `*_anchor.png` files
on `alpha-art`. Status: **APPROVED PRODUCTION ANCHOR — ALPHA ACCEPTED — POLISH
DEFERRED**. Exact topology, readable features and the established parchment/ink/
watercolor style are required; minor patching, socket curvature and repeated
motifs are deferred polish. No image generation, Founding Tile or Road End work
occurred. Commit `ea5858a5f57716b57d4cb01c4a967c7856463bc8` was pushed to
`origin/alpha-art`; that branch was not merged.

Gameplay resumed from clean merged Phase-6 `main`,
`3ffc899689c3b9f497725a552696df8cd68348a6`. Phase-6 final `db2527c` is an
ancestor. Before creating/pushing `phase-7`, the baseline passed **569 tests,
0 failures and 133 clean script parses** (`builds/verification/run-SCRxvCSx`).
All gameplay implementation below belongs only to `phase-7`.

### Runtime and authoritative commands

`SpecialistPieceState` retains a stable physical ID, generic marker or permanent
role ID, AVAILABLE/ASSIGNED status, target type/lineage or enclosure ID, original
assignment Act/index, observed component IDs, qualifying new-growth IDs and
training history. `SpecialistState` owns the roster, structured audit details and
typed deferred reward handoffs. The Phase-7 manifest contains exactly Merchant,
Cartographer, Architect, Homesteader, Naturalist, Forester, Riverkeeper and
Harbormaster. Deferred roles, Relics and Charters fail content validation.

The Phase-7 bootstrap used `ContentRegistry.load_phase_seven()`. A standard run
starts two available generic Stewards. `RecruitStewardCommand` adds a third and
rejects a fourth without mutation. Earlier manifests remain explicitly historical
fixture profiles, preserving every prior regression without retrofitting their
scripted input sequences with new player choices.

Commands are the mutation boundary: `ResolveSpecialistAssignmentCommand`,
`RequestSpecialistTrainingCommand`, `ResolveSpecialistTrainingCommand` and
`RecruitStewardCommand` execute through `RulesEngine`. No UI or scene is required.
Reward requests are integration APIs; entitlement, thresholds and reward offers
remain future work. No general reward engine was added.

### Local assignment and suspended placement

A physical placement commits geometry, counter changes, component/lineage
reconciliation, host remapping and Trade topology before generating one local
assignment opportunity. `SpecialistPlacementService` derives affected features
from the actual base, Development or exact Transformation changes. Housing,
Market, Town Square, Port and Lodge use their specific host; Mill offers touching
unfinished Settlements; Monastery-family stages use their persistent enclosure.
Bridge-created Settlement access and Rewilding's removed same-tile Field support
also make their directly altered Settlement eligible.

Closed features are excluded before scoring. The player assigns one offered
available piece/target pair or declines. `PendingChoice` persists exact options;
`ResolutionState` persists the committed source, local targets, frozen completion
snapshot and any deferred immediate Development effect. No hand refill, scoring
or unrelated input happens while that choice is pending. Reserve and final-Act
refill behavior remain unchanged. The final normal placement can save while
pending, then resume into the existing deferred Act-transition boundary.

Private projected topology rejects every merger of two occupied unfinished
features before physical mutation, even if the proposed result would close.
This implements Implementation §25.2 for ordinary placement, Urban Expansion,
Bridge and Rewilding. Legal mergers remap the one assignment to its descendant
without changing the piece, original assignment timing or earned growth credit.

### Completion effects and growth attribution

One immutable batch snapshot supplies base scoring, Developments and Specialist
calculations. Effects apply in that order, then all completing pieces return;
later Relic/reward/threshold stages remain no-op boundaries. Returned pieces
cannot use the placement's already-resolved assignment opportunity. Indirect
and simultaneous completions use the same lifecycle. Generic bonuses are +2
Trade/Road, Population/Settlement, Ecology/Forest or River, Culture/enclosure.
They never enter base anti-farming sets.

| Role | Implemented completion calculation and representative checks |
| --- | --- |
| Merchant | `max(0, distinct current network Settlements - 1) * 2` Trade; authoritative Trade service, one/two/three nodes, unchanged snapshot after live changes. |
| Cartographer | +1 Trade per qualifying newly created Road component; Bridge target/neighbor growth, old and foreign-built absorbed components excluded, payout and persistence. |
| Architect | +2 Culture per current distinct Development family; duplicate families once, Grand Market remains Market family. |
| Homesteader | +1 Population per distinct current Field support tile; full current relationships, including already base-paid support. |
| Naturalist | +1 Ecology per Forest tile only while undeveloped under current rules; Lodge permitted, other ordinary Development blocks. |
| Forester | +1 Ecology per qualifying new Forest component; Rewilding-created growth counts, pre-existing absorbed Forest does not. |
| Riverkeeper | +1 Ecology per distinct current touching Forest tile, independently stacking with base contact gains. |
| Harbormaster | Requires current canonical Settlement contact; +2 Trade per touching distinct Settlement plus +1 for each containing Port. |

Growth attribution stores global component identities observed since commitment
and a separate qualifying set. Each topology change credits only newly created
components now in the assigned feature, then observes every component globally.
Thus a Road/Forest built elsewhere after assignment and merged later still does
not count. This replaces neither feature genealogy nor base scoring history.

### Training, persistence and interpretations

Training converts an existing generic piece permanently, with duplicate roles
allowed across distinct features. Available pieces draw three distinct roles
uniformly without replacement from the lexically sorted eight-role pool. Assigned
pieces filter first by current feature/Harbormaster eligibility; a pool of at most
three is offered in full. Only randomized training offers use new gameplay RNG.
Recruitment and training selection do not trigger unrelated dead-hand redraws.
The exact offer and original commitment are saved; load never rerolls or recalls.
If all pieces are trained or no generic can legally train, one typed normal Tile
Reward handoff is recorded, not discarded or implemented as a full reward.

The growth interpretation and confirmed Abbey ruling are explicit:

- **Growth training in place:** Cartographer/Forester credit starts at conversion,
  excluding pre-training growth as this assignment explicitly requires. Original
  assignment Act/index remains intact; training history records the conversion.
- **Abbey — explicit human ruling:** generic assignment targets the persistent
  Monastery-family enclosure, including its unfinished Abbey stage. The user
  confirmed this behavior after Phase-7 review. An Upgrade or other directly
  affecting action may offer a new generic assignment under normal locality and
  unfinished-target rules. It adds no trained Abbey role. Existing
  commitment survives Upgrade, completed stages cannot receive last-second
  assignment, and a genuine Abbey completion returns its generic Steward.

No source specification was rewritten. No Phase-7-blocking ambiguity remains
under the documented growth interpretation and confirmed Abbey ruling.

Optional schema-1 Specialist records preserve signed 64-bit IDs, roles, histories,
growth sets, choice options/context, frozen snapshots and continuation stages.
Repeated load is inert: zero placement replay, scoring, effects, assignments,
returns, training, events, ID allocation or RNG consumption. Identical choices
produce identical fingerprints and future IDs/RNG after load.

Invariants cover cap/identity, active targets, one piece per connected feature,
canonical roles, permanent training history, growth references, exact local
options, most-recent physical source, frozen snapshot integrity and deferred
Development effects. Malformed snapshot collections, historical completed
assignments, duplicate reward handoffs and forged locality are rejected before
commands mutate or loaders publish state. Resume also rechecks ID, Track and RNG
capacity rather than assuming the pre-save reservation remains sufficient.

### Verification and scope

Verified 2026-09-24, Godot 4.7.2 stable. Runtime/test commit:
`72a7bcdd105cbfed9d2b6027e0d3ece376176ab6`.

| Check | Evidence |
| --- | --- |
| `./tests/run_tests.sh` | Exit 0; **717 passed, 0 failed**; **155 GDScript files parsed without diagnostics**. |
| Prior regressions | All **569** previous tests retained and passing; no old assertion weakened. |
| Specialist coverage | **148 new tests**: 40 state/content, 49 rules/training, 42 live scenarios, 17 continuation/boundary scenarios. |
| Specialist demo | **42 scenarios passed**; readable roster, pools, choices, growth, gains and returns. |
| Transformation demo | **40 scenarios passed**, retaining Bridge bank and Abbey/Rewilding rulings. |
| Headless bootstrap | Exit 0; Phase-7 content validated, 34 tile definitions. |
| Diff/branch scope | `git diff --check` clean; no art or canonical source-specification changes on `phase-7`. |

Acceptance logs: `builds/verification/run-hRKCKUe6/`; summary
`builds/phase7-acceptance.log`. Demonstration logs:
`builds/phase7-specialist-demo-verified.log` and
`builds/phase7-transform-demo-verified.log`. These generated logs are ignored.

The prior art branch's 15 orphan Godot `.png.import` sidecars were preserved
byte-for-byte under `/home/rochelle/Jane/Artifacts/MappaMundi/phase7-art-import-sidecars-20260924/`;
source images and approved anchors remain unchanged on `alpha-art`.
All Phase-7 exit conditions are satisfied under the documented growth interpretation and confirmed Abbey ruling above.
The next action is human gameplay/code review; Phase 8 requires a new instruction.

No Phase 8, Relic gameplay, Steward's Relay, Ferry Rights, Charters, Grand Charters,
full rewards, Act transitions, deferred Specialists, presentation polish or tile
art was added on `phase-7`. Art stays on its unmerged branch. Gameplay remains
headless with a minimal bootstrap; player-facing Specialist UI is deferred.

## Phase 6 — complete

Verified 2026-09-24 on `phase-6`. PR #3 was merged normally, retaining the
`phase-5` branch and final commit `8746e07b5f6346fd1739cf0493930cbd34ccd83c`.
The merged `main` baseline is `8d0074df5bda0e03edb49d077fd07b0af8d1b0f2`.
The ancestor check succeeded; baseline verification passed 447 tests and 117
script parses (`builds/verification/run-KCd61v3a/`). `phase-6` was created and
published from that verified baseline before implementation.

### Physical runtime and effective geography

`TransformationState` records physical copy/definition, application Act/index,
mode, orientation, target base copy and an ordered set of `TransformationChange`
facts. Each change retains coordinate, exact before/after edges, Field geography,
associated historical lineages and newly created component IDs. Board cells own
array-shaped Transformation histories alongside Development arrays and original
base identity. Transformations use no Development slot.

Urban Expansion and Rewilding expansion are physical new bases. Their
Transformation records audit growth without counting a second physical location.
Bridge and occupied Rewilding retain the base copy and place their own copies in
`BOARD_TRANSFORMATION`. Multiple compatible instances persist separately. Base
Act/definition/rotation and static Resource edges remain historical truth.

`effective_edges` drive current placement and topology. `has_field_geography`
records current interior Field separately from boundary sockets: Bridge and
boundary-only rewrites preserve interior geography, while occupied Rewilding
consumes it. A remaining Field-facing socket cannot recreate consumed Field
support or authorize a Field-dependent Development. This also preserves a Mill,
Monastery or Abbey on a Bridge target even when both bank edges become Road.

### Queries and atomic resolution

`TransformationPlacementQuery` generates purpose-built options for all four
runtime modes. Options contain coordinate, mechanically distinct quarter-turn,
mode, target physical base, complete geometry/lineage signature and revisions.
Urban keeps four orientations; symmetric Rewilding and Bridge axes normalize to
two, with Bridge admitting only the perpendicular one. Frontier coordinates,
occupied targets and rewrite facts have deterministic order. Queries use private
projected cells/components and never allocate a run ID or consume gameplay RNG.

`TransformationGeometry` validates the complete resulting board, occupied edge
matches, preserved Development dependencies and lineage constraints before live
mutation. The command revalidates complete intent and captures its plan before
removing a hand/Reserve copy or advancing counters. Stale and forged commands
leave the fingerprint unchanged. There is no partial mutation/rollback path.

The commit applies every cell rewrite, creates missing feature components, then
uses the existing single resolution boundary: physical topology, lineage
growth/merger/reopening, Development host remapping, Trade reconstruction, one
immutable completion snapshot, base scoring, Development batch, deferred hooks
and hand refill. A normal Transformation consumes one placement. Reserve play
has no hand refill; Survey and dead-hand/global-stalemate queries use the same
physical inventory and actual-class legality. Emergency composition is unchanged.

### Implemented designs and growth behavior

- **Urban Expansion:** Act II specialized/hybrid metadata; opposite Settlement
  edges, distinct Road with explicit Settlement access, one Field edge. It starts
  a new Settlement under exact matching or rewrites up to two opposite eligible
  Settlement Field boundaries. Road/Field sides retain exact matching. Open
  growth/mergers do not score. Closed mergers immediately complete genuinely,
  retaining ancestor component/support history. Housing, both Market stages,
  Port and Town Square follow descendants; Port keeps its River association.
  Attached Trade Networks meet at one descendant hub without automatic Trade.
- **Bridge:** Act III Major/Rare, straight River Run prerequisite, perpendicular
  Road and persistent flanking Field-to-Road rewrites only for Road/Settlement
  neighbors. Empty sides remain open. It preserves the original River and all
  existing Developments. Its target Road and a newly Road-bearing Settlement
  neighbor get current-Act Transformation origins. Existing Road components
  retain identity and age. Physical Road mergers/reopening/closed re-completion
  preserve component and per-Road Settlement payment histories. River completion
  history and scoring do not change merely because Bridge is applied.
- **Rewilding:** Act III Major/Rare, opposite Forest pair and two Field edges.
  Empty-square exact matching, one completed-Forest boundary extension and
  occupied Field conversion are separate intents. Occupied Forest edges replace
  eligible Field edges and must face Forest or empty space. Road, Settlement,
  River and legal Settlement Developments survive. Mill/Monastery block the
  occupied mode. Existing Forest components keep their IDs and age; only a
  genuinely new Forest contribution gets a current-Act Transformation origin.
  Forest mergers inherit scored history, remap Lodges, reevaluate preservation
  and trigger existing Lodges on genuine completion. Rewilding itself is not a
  Development. Consumed current Field support disappears without removing earned
  Population or historical support records.

Component allocation takes explicit source Act/kind/copy arguments and allocates
only absent feature types. Genuine non-River growth into one completed lineage
starts a new growth phase even when final geometry is already closed. Existing
scored components and support/payment sets remain intact. Features with retained
identity can represent zero exits without creating replacement components.

New-square Transformations can complete Monastery/Abbey enclosures. Occupied
Transformations cannot add surrounding occupancy. Live acceptance cases prove
simultaneous Urban Road/Settlement completion with Housing, Market, Port, Town
Square and Mill on one snapshot, and simultaneous Rewilding Forest/Abbey
completion on one snapshot.

### Persistence and invariants

Serialization stores current edges/geography, all physical instances, exact
modification history, component origins, lineages, Development hosts, economic
genealogy and structured `transformation_applied` records. Loading decodes and
validates; it never executes a Transformation or reconciles by generating new
history. Repeated loads preserve Tracks, completion/event counts, future ID
cursor, RNG state/operation count and normalized fingerprint exactly.

Invariants validate physical zones, unique placement accounting, source-copy
origins and Acts, canonical axes/scope, allowed edge deltas, chronological geometry
chains, current geometry agreement, pre-existing boundary/Bridge hosts and
explicit Bridge Settlement access. Corrupt saves are rejected. Transformation
arrays and identity sets normalize independently of insertion order. Continuation
from saved transformed states produces identical options, commands, scoring,
topology, Trade genealogy, IDs, future draws and RNG. Older board records missing
new required fields are rejected, consistent with the existing strict schema;
no migration or gameplay replay is performed.

### Resolved canonical rulings — 2026-09-24

Ro accepted Phase 6 and supplied authoritative rulings for the two previously
gated interactions. The Complete Alpha Rules were amended narrowly with
`RULE-BRIDGE-002a` and `RULE-REWILD-007a`; unrelated rules and older prototype
specifications were not changed.

- **Bridge on a Rewilded River Run:** underlying straight-River classification
  remains valid, but it is not sufficient for placement. Both perpendicular
  current edges must permit Field-to-Road rewriting. Either Forest bank makes
  Bridge illegal; stale/forged attempts return structured rejection and preserve
  the entire state. The canonical reason is
  `bridge_effective_edge_not_rewriteable`. No Forest removal, dual edge sockets,
  splitting or generic overwrite permission was introduced.
- **Abbey and Rewilding:** continued legality follows the current Development
  stage, not its historical prerequisite. `DevelopmentState.requires_field_geography`
  now supplies one shared dependency check for queries, projected geometry and
  persistence invariants. Mill and ordinary Monastery still require Field.
  Abbey requires its persistent enclosure and therefore permits otherwise-legal
  Rewilding. Its physical copy, enclosure ID/coordinate, family and prior stage
  history remain intact. No Abbey stage or score is created merely by Rewilding.
  Incomplete Abbeys still complete through ordinary surrounding-eight occupancy;
  completed stages remain recorded and never replay.

The former ambiguity tests were converted into canonical behavior tests. Nine
additional ruling tests cover normal Run/Bend/End targeting, stale and forged
Bridge rejection, continued rejection after load, Mill/Monastery blockers,
physical Upgrade preservation, Abbey completion after Rewilding, completed-stage
history, occupied-edge conflicts, repeated inert loads and identical continuation.
A surrounded Abbey still cannot bypass conflicting occupied edges: its exemption
removes only the continued Field dependency, not ordinary Rewilding geometry.

### Verification and demonstration

Final ruling-patch gate `./tests/run_tests.sh` exited 0:

```text
PASS: 133 GDScript files parsed without diagnostics
RESULT: 569 passed, 0 failed
```

Evidence: `builds/verification/run-ra0apZLS/`. All previous 560 cases remain covered,
including the two converted ambiguity tests, plus nine new ruling cases. All
prior 447 pre-Transformation tests still pass. Phase 6 now has 122 added cases.
The old implementation checkpoint passed 560/132 at
`builds/verification/run-d4djaTjW/`; the ruling patch supersedes that final report.

The headless `tests/replay/phase_six_demo.gd` now runs 40 deterministic scenarios:
the original 31 plus all nine canonical ruling scenarios. Evidence:
`builds/phase6-rulings-demo.log`. Repeated saves/loads of Rewilded River rejection
states and incomplete/completed Abbey + Rewilding states preserve fingerprints,
physical zones, topology, enclosure histories, Track values, future ID cursors,
RNG state and operation count. Reconstruction produces zero effects, completions,
scoring, events, allocations or RNG consumption. Identical future placements
complete the original and restored Abbey identically.

### Review boundary

The original Phase-6 implementation checkpoint was
`5a4a6e28a2aa8326d712914bef9ef80af71f00f6`; its review handoff was `116945e`.
The ruling patch remains on `phase-6` and is published through
[PR #4 — Phase 6 — Transformations and Growth Rewrites](https://github.com/CrackedEggProductions/Mappa-Mundi/pull/4),
which remains open against `main` and unmerged. Main remains the merged Phase-5
baseline. The final ruling commit is recorded in Git and the Jane continuity note.

Every Phase-6 exit condition is now unconditionally satisfied. No unresolved
Phase-6 specification ambiguity remains. Phase 7 has not started. No Specialists,
Relics, rewards, thresholds, Charters, automatic seeding, Act transitions or final
UI were implemented. No generated caches or backups are staged.

Recommended next action: final review of PR #4. Do not merge it or begin Phase 7
without Ro's next explicit instruction.

---


## Phase 5 — complete

Verified 2026-09-23 on `phase-5`. Ro authorized Phase-4 PR #2 to merge normally.
Main merge `a57a83e` retains final Phase-4 commit
`da30d0100ba6d07d3feb139d351832968b4d3c8e`; the ancestry check exited 0.
The merged baseline passed 329 tests and 102 clean script parses in
`builds/verification/run-oaMrTxlk/`. The new branch was published before implementation.
At that Phase-5 checkpoint, Phase 6 had not started.

### Runtime and placement

`DevelopmentState` is a physical overlay in `BoardCellState.developments`, an array
whose normal current capacity is one. It stores copy identity, family/stage,
specific host kind and lineage, Port River, enclosure, placement Act/index and
replaced-copy identity. Definition and coordinate resolve through the physical
copy and owning board cell, avoiding duplicate registries. Geography stays intact;
no rendering node or artwork determines rules. Presentation IDs live in content.

`DevelopmentService` supplies host/family/current-class queries and descendant
remapping after Phase-3 lineage reconciliation. Housing, Market stages, Town Square
and Port follow Settlement descendants; Lodge follows Forest descendants. Port's
River association is reconciled independently. Mill stays tile-based and evaluates
current contacts. Enclosures retain their own IDs rather than feature lineages.
Families exclude unrelated Field, Forest and enclosure systems on shared squares.
Current classification and highest historical classification are distinct; frozen
completion records preserve families and qualifications earned while unfinished.

`PlacementQueryService.query_for_copy` dispatches by physical tile class.
Occupied squares and targets are enumerated deterministically. Complete typed
intents carry host/River/enclosure/replacement IDs, revisions and signatures.
Distinct Port Rivers are separate choices, upgrades require an exact physical
prerequisite, and meaningless rotations are rejected. Full validation precedes
mutation; rejected/stale/forged intents preserve fingerprints, scores, zones,
history, allocation cursors and RNG. Existing fixture enclosures cannot receive
a duplicate physical enclosure.

RulesEngine retains one physical hand/Reserve/bag system. A Development or Upgrade
uses one normal placement; hand slots stay empty through effects and refill after
resolution, while Reserve empties without a hand draw. Survey removes either
class. Dead-hand and bag-wide stalemate checks call the class-aware query. Emergency
fallback remains the original three Expansion designs. Board revision remains
geometry-only; state revision also invalidates overlay previews.

### Effects and physical upgrades

| Design | Implemented behavior |
| --- | --- |
| Housing | Each copy gives +2 Population at Settlement completion or its own immediate completed-host placement. |
| Mill | Each touching completed Settlement gives +2 Population and current River contact adds +1 Trade; contacts are dynamic. |
| Forester's Lodge | Each copy gives +1 Ecology and preserves the Forest's undeveloped status. |
| Market | +1 Trade per distinct other Settlement in the full current Phase-4 network. |
| Port | Specific River association; +2 Trade plus each other Port on that connected River. |
| Town Square | +2 Culture per distinct Settlement-hosted family, including itself. |
| Monastery | Live surrounding-eight enclosure; +5 Culture plus one natural bonus per surrounding square. |
| Abbey | Physical Monastery replacement, same enclosure; new stage gives +8 Culture plus natural and Settlement bonuses. |
| Grand Market | Physical Market replacement; +2 Trade per other Settlement in the full current network. |

The nine canonical resources preserve unlock Acts, family, host, prerequisite,
reward class/quantity and presentation hooks. Abbey remains Monastery family;
Grand Market remains Market family and Major/Rare (one future reward copy).
`ContentRegistry.load_phase_five()` exposes 31 designs, while historical profiles
remain available. The starting bag remains exactly 55 Expansion copies. No reward
generation, automatic seeding or Act transitions were introduced; fixtures use
controlled acquisition and Act contexts.

Only the newly installed copy resolves its immediate effect, based on current
completion rather than historical Establishment. A Mill may resolve once for each
currently complete touching Settlement. These events do not create feature
completions or modify base anti-farming history. Genuine later re-completion
triggers surviving Developments again. Network changes and new peer Ports do not
passively retrigger old copies. Orthogonal Development contact follows RULE-TILE-008;
same-tile contact requires explicit topology, and diagonals never count for Mill/Port.

The completion snapshot freezes host families, Trade membership, Port peers and
Mill contacts before any gains. Base scoring applies first, then the complete
Development batch; FIFO child history drains afterward. Specialist, Relic and
threshold stages remain deferred hooks. Tests include seven simultaneous physical
Developments across six stages, duplicate Housing, both Market stages,
Port and Mill, plus a simultaneous Settlement/Monastery completion.

Upgrades remove their prerequisite copy permanently into removed-from-run state,
install the new physical copy in the same slot, and retain reciprocal structured
replacement audits. Abbey preserves enclosure identity and old completed-stage
history; an incomplete replaced Monastery never scores its abandoned stage.
Each enclosure stage scores at most once. Ordinary Developments cancel future
Forest preservation except Lodge; previously earned bonuses remain untouched.

### Persistence and acceptance evidence

DevelopmentSerializer adds strict overlay records to the existing save boundary.
Feature records freeze Development families, prior highest classification, Forest
undeveloped status, enclosure stage and natural/Settlement neighbor counts.
Structured placement, upgrade, replacement, immediate-effect and completion-trigger
records remain audit data; RunState is authoritative. Normalization sorts overlay
and family sets, retaining ordered history. Validation checks physical zones,
placement accounting, slots, hosts, valid Port contact, stage/family identity,
replacement audits, enclosure history, frozen gains and cumulative Tracks.

Loading only decodes and validates. Repeated completed-host/enclosure loads preserve
fingerprints, Track totals, history counts, future IDs, RNG state and operation
counts: zero new effects, completions, events, allocations or RNG consumption.
Earlier board shapes missing these required fields are rejected, not migrated.
The existing null-feature/null-Trade fixture variants remain supported.

Final `./tests/run_tests.sh` exited **0** on Godot 4.7.2:

```text
PASS: editor import
PASS: 117 GDScript files parsed without diagnostics
RESULT: 447 passed, 0 failed
```

Evidence: `builds/verification/run-qjNHF3bb/`. The 329 prior cases remain passing;
the former Abbey-deferred assertion now verifies its authorized stage behavior.
There are 118 new tests across content (26), effects (18), placement (18),
persistence/corruption (17), gameplay scenarios (24) and acceptance regressions (15).
No lint/typecheck tool is separately configured; the established Godot import and
per-script diagnostics gate checks syntax and warnings. `git diff --check` is clean.

`tests/replay/phase_five_demo.gd` uses seed 16 and controlled content acquisition.
It demonstrates physical hand/query/host placement, immediate effects, full-network
Market, Grand Market replacement, save/load and identical future draw/continuation.
Standalone final demo exited 0 without diagnostics (`builds/phase5-demo-final.log`):

```text
DEMO seed=16; normal placements=8; Tracks=[13, 20, 0, 0]; completed-host Housing, full-network Market, physical Grand Market replacement; identical save/load continuation and future draw.
DEMO RESULT: immediate isolation, shared Development batches, Port River intents, Monastery/Abbey stages, host mergers, Forest preservation, physical zones, inert loading and deterministic continuation passed.
```

Controlled scenarios cover Port, enclosure progression, genuine re-completion,
host mergers, shared snapshots and non-triggering reconstruction. Demo logs are
under ignored `builds/`; no final art, dependencies or caches are committed.

### Review and scope

Review found and fixed orthogonal Mill/Port contact, retained unfinished Settlement
classification, duplicate fixture enclosure placement and deterministic family
ordering. Interrupted native-agent work was recovered from disk and integrated
by Codex; service usage limits did not discard work. All source specifications
remain unchanged. No known gameplay defect or unresolved specification ambiguity
remains. Phase-5 exit condition is satisfied. No Transformation, Specialist, Relic,
Charter, reward, Act-transition or full presentation gameplay was added.

Implementation checkpoint `226092560cf35817ee3fd7f41ece98759138295d` was committed
after the full 447-test/117-script gate and pushed normally to `origin/phase-5`.
[PR #3 — Phase 5 — Developments and Upgrades](https://github.com/CrackedEggProductions/Mappa-Mundi/pull/3)
targets `main` and remains open for review. The final documentation checkpoint
records this PR and evidence without changing gameplay. Phase-4 branch is retained.
Recommended next action: review the Phase-5 PR. Do not begin Phase 6 without a new
explicit instruction. Exact checkpoint/PR identity is recorded in Jane continuity.

## Phase 4 — complete (historical checkpoint)

Verified 2026-09-14 on `phase-4`. Ro explicitly authorized merging PR #1;
accepted `main` merge `8b6b6ab` contains Phase-3 final `238b98e`. Before branching,
`./tests/run_tests.sh` passed 274 tests with 88 scripts without diagnostics
(`builds/verification/run-GzeIObV5/`). Phase 5 has not started.

### Architecture and scoring

- `core/trade/trade_network_service.gd` rebuilds the economic graph deterministically
  from explicit board access and authorized rule-layer contributions. Current
  networks expose sorted Road and Settlement lineage members, access links,
  distinct reach and persistent network identity. Simple adjacency never grants
  access. Settlement hubs connect separate physical Roads transitively, including
  unfinished Roads and Settlements. Isolated members do not form networks.
- `TradeState`, `TradeNetworkLineageState` and `TradeHistoryRecord` persist economic
  genealogy separately from physical feature lineage and per-Road payments.
  Current membership is derived; last reconciled member sets identify historical
  continuity and are validated against reconstruction. Ordinary growth retains
  identity; mergers create descendants with sorted parents; splits create ancestry-
  aware descendants; reconnection recombines ancestry. Completely dissolved networks
  also retain history when access returns. Parent records remain archived.
- `trade_revision` advances when the canonical access graph changes. Unchanged
  reconciliation is inert. Graph traversal, tie-breaking and ID allocation order
  are independent of registry insertion order and consume no gameplay RNG.
- Normal placement resolves physical lineages, reconciles Trade identity, then
  captures one immutable completion snapshot before any base score applies.
  Each completing Road sees its entire current network. Road base Trade is
  +1 per new component plus +2 per eligible distinct Settlement. Two independent
  Roads can each score the same Settlement; simultaneous membership is frozen.
- Per-Road `scored_settlement_ids` survive network growth, leaving/rejoining,
  split/reconnection and physical Road mergers. If any ancestor of a merged
  Settlement paid that Road, the descendant cannot repay. Network changes alone
  never award Trade. Genuine later re-completion may pay newly reachable Settlements.
- Public queries cover network by Road/Settlement, reachable Settlements, members,
  same-network checks, current counts and ancestry. Presentation remains non-authoritative.

### Persistence, invariants and scope

`TradeSerializer` persists genealogy, audit records, authorized inputs and revision;
`FeatureSerializer` adds immutable network membership/payment facts to completion
records. Normalization sorts unordered registries and historical sets while
preserving ordered history. `TradeInvariantValidator` checks current graph identity,
member types, historical parents, split/reconnection origins, ID collisions,
completion snapshots and per-Road eligibility against ancestral payments.

Loading reconstructs current connectivity purely and verifies persisted identity;
it never calls reconciliation or gameplay resolution. Repeated loads preserve
fingerprints, current graphs, all scoring/history, future IDs and RNG exactly.
The current completion-record schema requires explicit Trade fields. Older shapes
are rejected rather than silently migrated. Explicit null-Trade legacy fixture
states remain supported; new Homestead runs initialize Trade normally.

Authorized economic links are a narrow extension input. Only controlled fixture
contributions are accepted in Phase 4. No Ferry Rights, River commerce, Bridge,
Urban Expansion, Development, Specialist, Relic, threshold reward, Charter, Act
transition, UI or art gameplay was added. Future rule layers must maintain current
lineage endpoints when adding/removing their links. Reserve proof stays conservative.

### Acceptance evidence

Final `./tests/run_tests.sh` exited **0**, Godot `4.7.2.stable.mono.official.ed1daf0bf`:

```text
PASS: editor import
PASS: 102 GDScript files parsed without diagnostics
RESULT: 329 passed, 0 failed
```

Logs: `builds/verification/run-vL5sv1zR/`. All 274 earlier tests remain passing.
Phase 4 adds 55 tests: 15 graph/genealogy, 16 scoring/snapshot, 14 persistence/
corruption, and 10 invariant-valid integration scenarios.

Acceptance covers every canonical access source; adjacency exclusion; transitive
Settlement hubs; unfinished participation; growth, merger, split, reconnection
and dissolution ancestry; full-network +2/+4/+6 connection scoring; distinct
payments; no retroactive gain; paid/unpaid merged-Settlement ancestry; inherited
Road payment histories; simultaneous immutable Road snapshots; deterministic
allocation/order/revisions; malformed saves; and repeated non-triggering loads.

The standalone README command for `tests/replay/phase_four_demo.gd` exited **0**
without diagnostics (`builds/phase4-demo.log`):

```text
DEMO Phase 4: 12 seeded legal placements; Tracks=[10, 4, 0, 5]; connection payments=1; save/load after 5; identical economic graph, genealogy, history, IDs and RNG continuation.
DEMO RESULT: transitive full-network scoring, unfinished hubs, no retroactive gain, leave/rejoin and merger anti-farming, split/reconnection genealogy and non-triggering save/load passed.
```

The seeded sequence uses normal Expansion commands. Controlled board scenarios
separately demonstrate larger transitive networks and later re-completion, plus
simultaneous Road transitions and synthetic economic link removal/reconnection.
Those fixtures do not introduce future player actions. Invariant checks pass at
every stable scenario boundary. All Phase-4 exit conditions are satisfied.

### Git and review

Implementation checkpoint `ee2d6b2` was committed after 328 passing tests and
102 clean script parses and pushed normally to `origin/phase-4`. Final review added
the allocation-order/revision regression, bringing the total to 329. The final
verification/documentation commit follows this checkpoint and is pushed before
opening the Phase-4 PR against `main`. No Phase-4 merge is authorized or performed.

The delegated service reached its usage limit; the remaining code and tests were
completed and reviewed directly. One test passed an untyped array to a typed
GDScript helper; that call was corrected and the full suite rerun successfully.
No known gameplay defects, diagnostic warnings, third-party dependencies or
unresolved specification ambiguities remain. All six source specifications are
unchanged. Recommended next action: review the Phase-4 PR; do not start Phase 5
without a new explicit instruction.

## Phase 3 — complete

Verified 2026-09-13 on `phase-3`. Phase 4 has not started. At that historical checkpoint, Phase-2 baseline
`e0fea94` remained on `main` and `origin/main`; the Phase-4 section above records
the subsequent authorized merge.

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
