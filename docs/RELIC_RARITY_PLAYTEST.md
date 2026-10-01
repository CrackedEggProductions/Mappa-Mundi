# Relic access and player information — human-playtest handoff

Current rules: `alpha-playtest-r1-relic-rarity`; save schema **3**. Starting accepted tip: `f508cfc4ccce4ee2dce2da8518dedc5629fa673c`.

## Diagnostic method

Non-canonical diagnostic: 10,000 independent normal offers for each of Act I and Act II, seeds 1–10,000. Each sample starts with no acquired Relics. It uses the actual sorted, integer-weighted offer generator; each offer has three distinct items. It measures fresh-pool offers, not whole-run probabilities after exhaustion or human preferences. Weights remain Common 60 / Uncommon 30 / Rare 10 per eligible Relic.

Reproduce: `godot --headless --path . --script res://tests/scenarios/relic_rarity_diagnostic.gd`.
Raw evidence: [diagnostic JSON](reports/ui_usability/relic-rarity-diagnostic.json).

| Relic | Rarity | Minimum Act | Act I appearance | Act II appearance |
|---|---|---|---:|---:|
| Boundary Stones | Common | I | 66.86% | 53.58% |
| Surveyor’s Compass | Common | I | 67.11% | 54.12% |
| Wayfarer’s Satchel | Common | I | 66.47% | 54.45% |
| Village Green | Uncommon | I | 40.37% | 31.05% |
| Mixed-Use Charter | Uncommon | II | 0.00% | 30.31% |
| Historic Routes | Uncommon | II | 0.00% | 31.61% |
| Ferry Rights | Rare | I | 14.41% | 10.92% |
| Steward’s Relay | Rare | I | 14.94% | 10.74% |
| One Great City | Rare | I | 14.89% | 11.48% |
| The Long Road | Rare | I | 14.95% | 11.74% |

| Metric | Act I | Act II |
|---|---:|---:|
| Offer contains at least one Rare | 52.06% | 40.57% |
| Offer contains at least one Uncommon | 40.37% | 73.81% |
| Common share of all slots | 66.81% | 54.05% |
| Uncommon share of all slots | 13.46% | 30.99% |
| Rare share of all slots | 19.73% | 14.96% |

These results reflect per-item weights, the eligible pool size and removal after each selection. They are not a 60%/30%/10% rarity-category roll. No fixed rarity composition is enforced. The optional Track-20 timing diagnostic was not run; scoring was not retuned.

## Reproducible setup examples

| Seed | Act-I Charter | Starter offer | River end |
|---|---|---|---|
| 783451920 | Growing Realm | Housing, Woodland Road, Settlement Road Bend | (-2,-2) |
| 2026 | Open Roads | Riverside Hamlet, Housing, Woodland River | (-2,-2) |
| 1 | Growing Realm | Woodland Road, Riverside Hamlet, Housing | (4,4) |

Every seed retains its exact gameplay stream. Blank entry requests external entropy once; explicit input bypasses it. The full signed-64 range is validated and round-tripped.

## Scope

Tile Draft pools/cadence, starting core, Charter requirements, scoring, Specialists, Relic effects and capacities are unchanged. No new Relics or art. Phase 11/12 did not begin; branch remains unmerged.

## Final verification results

- `./tests/run_tests.sh`: **1,375 passed, 0 failed**; **258 scripts parsed without diagnostics**, exit 0. Log directory: `builds/verification/run-psqCJF0R`.
- `./tests/run_presentation_tests.sh`: **157 passed, 0 failed**, exit 0. Log directory: `builds/verification/presentation-qy0PnTyN`.
- Graphical smoke: **42 checks, 0 failures** at each target resolution; logs `builds/relic-info-720-reviewed.log` and `builds/relic-info-1080-reviewed.log`.
- Full three-outcome, deterministic, save/load and natural-controller replay checks passed. No parser warnings or Godot script errors.
- Independent review found no outstanding production issue. Scope check confirmed all 28 tile resource edits are help text only and all ten Relic resources retain their effect/behavior fields.

## Verification coverage and replay fixtures

Baseline was clean at **1,327 gameplay / 142 presentation / 250 parsed scripts**.
New coverage adds 18 static tile-help checks, 30 Relic access checks, eight seed-entry
presentation checks and seven hover/rarity presentation checks. Existing threshold,
version-envelope and completion-queue assertions were updated only where they
encoded the superseded rules.

The weighted sampler is checked against an independent integer-ticket oracle for
64 seeds across Common-only, Common/Uncommon, Common/Rare and all-rarity pools.
Tests cover sorted input order, no repeated selection, small/empty pools, exhaustion,
Cache sharing the generator, exact persisted offers and RNG continuation. Each of
four Tracks covers 19→20,19→21,0→25; four simultaneous crossings resolve in Track
order, including capacity replacement and decline. Early City/Long Road snapshots
and Act-I Relay preserve current effects and prevent retroactive scoring.

Full scripted fixtures keep actual 66-placement commands and all three outcome
assertions. Their explicit seed is now **123**, found deterministically after the
new reward RNG changed later Charter/training draws; recipes and outcome criteria
were not weakened. Natural-bag controller fixtures retain explicit seed **1010**
and run twice with matching results. Explicit seed **1** remains covered for setup
replay and existing graphical fixtures.

| Run | Fingerprint |
|---|---|
| No victory, seed123 | `48ddbe8c07385f73c4b8927cc0cf13429b09d1bc25d6a4bbe3e7cf9aa6f22124` |
| Victory and save/load replay, seed123 | `d22f101755cbca388bb718a8943750d8486cd4efaa2b2a737701274a4df7ecc4` |
| Exemplary, seed123 | `9d8d23fc26e24469a9d0cd8ebefc1a883cbd18c8e38e9311672c46ddee2fad86` |
| Natural-bag controller replay pair, seed1010 | `a3046eb104aa1345a9d9289ada0c8fdc8c8100c5a63e536519605e96d6d64530` |

## Graphical verification

Automated real viewport mouse smoke passes **42 checks at 1280×720 and 42 at 1920×1080**.
It starts blank with real OS entropy, verifies the full displayed seed, restarts with
explicit seed 2, chooses the Starter Draft, hovers the naturally drawn Monastery,
uses Reserve, hovers a fixture-acquired Forester’s Lodge, then uses genuine scripted
Forest completions to reach Ecology 20. It clicks a weighted Relic offer, resolves
the following cadence draft and inspects the equipped Relic. Hover fingerprints
remain unchanged. The fixture uses real scoring/history, not edited Track totals.

The hover harness waits for native desktop warp events to settle before the
Godot tooltip timer; a fixed immediate one-second wait was unreliable at 1080p.
The final runs have no Godot script errors. This machine prints a pre-existing
NVIDIA driver probe failure before successfully rendering with Intel Mesa; this
is separate from Godot parser diagnostics. These are automated tests, not a human
hour-long usability assessment.

Captures use the existing report directory. Each resolution has `new-run`,
`monastery`, `reserve`, `lodge`, `relic-offer` and `equipped-relic` states:

- [720p New Run](reports/ui_usability/relic-information-1280x720-reviewed-new-run.png)
- [720p Monastery hover](reports/ui_usability/relic-information-1280x720-reviewed-monastery.png)
- [720p Lodge hover](reports/ui_usability/relic-information-1280x720-reviewed-lodge.png)
- [1080p Relic offer](reports/ui_usability/relic-information-1920x1080-reviewed-relic-offer.png)
- [1080p equipped detail](reports/ui_usability/relic-information-1920x1080-reviewed-equipped-relic.png)

The existing flat tabletop/parchment layout and art fallbacks remain. Tooltips
use a 340px text column and dark ink; seed placeholder/read-only text also has
explicit contrast. A long signed seed can scroll within its compact HUD field;
the full value remains selectable/copyable and available on hover.

Reproduce graphical smoke with a fresh capture suffix:

```sh
godot --path . --script res://tests/scenarios/relic_information_mouse_smoke.gd -- 1280 720 fresh-capture
godot --path . --script res://tests/scenarios/relic_information_mouse_smoke.gd -- 1920 1080 fresh-capture
```
