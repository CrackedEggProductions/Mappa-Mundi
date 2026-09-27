# Alpha Playtest Revision 1: completion diagnostic

Historical sample checkpoint: `52f6a65`, before the second-playtest Act-II Market
seeding adjustment. Recorded end-of-transition fingerprints belong to that version;
rerunning the current script may change them. Act-I placement rules were unchanged.

This is a deterministic, non-canonical policy measurement, not a human playtest or a guarantee that a new player will obtain the same results. It does not change bag counts, legal actions, scoring or gameplay RNG.

The command below describes the historical invocation. The script now measures the
18-copy core and draft system; use the [current draft-cadence report](DRAFT_CADENCE_DIAGNOSTIC.md)
for its current output. Reproducing this older sample requires its historical checkout.

Historical invocation:

```bash
godot --headless --path . --script res://tests/scenarios/revision_completion_diagnostic.gd -- 100 1
```

The script starts 100 ordinary runs using seeds 1–100. Each starts with the generated nine-tile River and the revised 45-copy player inventory. It submits 18 ordinary placements through `RulesEngine`, then resolves the outgoing consequences and Charter transition before recording Act-I completion records.

## Policy

For every legal option of every occupied active-hand slot, a disposable projection queries authoritative topology and enclosure completion. The projection never changes the live run or consumes its RNG. Rank options by:

1. Most immediate genuine feature/enclosure completions, excluding environmental River.
2. Greatest decrease in unresolved exits belonging to existing physical features.
3. Fewest unresolved exits belonging to newly introduced physical features.
4. Existing hand-slot and authoritative option order as a deterministic tie-break.

The selected exact option is committed through the normal command path, including an explicit Boundary Stones direction when present. The policy declines optional Specialist assignment and Relay, finishes Grand Survey without removals, declines full-capacity Relic replacement, and otherwise chooses the first persisted reward/training option. It does not optimize Reserve or normal Survey. A truly dead hand uses the existing free cycling command.

The immediate-completion preference is deliberately stronger than typical first-time play. It provides evidence that closure is available, not that the interface already teaches it adequately.

## Recorded result

The final sample used seeds **1–100**, 18 normal placements each, under rules version `alpha-playtest-r1`. All 100 runs completed normally. **100%** completed at least one feature; the median was **6** and the mean **5.72**. No bag counts or gameplay rules were tuned to obtain these results.

| Completion type | Total | Mean per run | Median | Range |
|---|---:|---:|---:|---:|
| All features | 572 | 5.72 | 6 | 2–9 |
| Road | 263 | 2.63 | 3 | 0–5 |
| Settlement | 191 | 1.91 | 2 | 1–3 |
| Forest | 118 | 1.18 | 1 | 0–2 |
| Monastery-family enclosure | 0 | 0 | 0 | 0 |

Distribution by number of completions (count → number of runs):

- All features: 2→1, 3→5, 4→10, 5→27, 6→28, 7→21, 8→7, 9→1.
- Road: 0→2, 1→12, 2→29, 3→39, 4→14, 5→4.
- Settlement: 1→31, 2→47, 3→22.
- Forest: 0→13, 1→56, 2→31.

These exceed the suggested diagnostic indicators of 80% with a completion and a median of at least 2. They do not measure whether a human recognizes the best closure, enjoys the decisions, or understands the new River overlays.

The complete [machine-readable sample](reports/alpha_playtest_r1_completion_sample.json) retains all 100 seed rows and fingerprints. An independent rerun with explicit immediate-enclosure handling produced identical seed results. Environmental River generated no completion records.

## Verification and review evidence

The committed JSON report contains the aggregate statistics, every seed's completion counts, evaluated-option count and final fingerprint. The full three-Act fixtures separately cover actual River overlays, ordinary scoring, Specialist effects, threshold and Charter rewards, all transition checkpoints, final no-refill behavior, and failure/Victory/Exemplary outcomes. Their controlled acquisition recipes are integration fixtures, not natural-bag balance samples.

The mouse-facing natural-bag controller harness remains separate and does not acquire fixture tiles or edit RunState. A second human playtest is still required; use the revision playtest checklist to assess clarity, variety and obstruction from the River.
