# Draft-cadence diagnostic

This non-canonical diagnostic measures the revised 18-copy core plus Starter, cadence and Act-entry drafts. It does not add weighting to gameplay offers, inject tiles, alter Charters, or claim to reproduce human play. The historical [45-copy sample](PLAYTEST_REVISION_1_DIAGNOSTIC.md) is retained separately.

## Reproduction and policy

Run from the project root:

```bash
godot --headless --path . --script res://tests/scenarios/revision_completion_diagnostic.gd -- 100 1
godot --headless --path . --script res://tests/scenarios/draft_access_diagnostic.gd -- 30 1 3
```

Both scripts use `draft_diagnostic_policy.gd`. Every acquisition and placement passes through ordinary `RulesEngine` commands. Each run resolves its actual persisted Starter Draft before opening input; cadence and entry drafts resolve through `ResolveTileDraftCommand`, including their bag shuffle and refill continuations.

The placement heuristic examines every legal option in the occupied active hand using disposable, read-only projections. It prefers most immediate genuine completions, then the greatest reduction in existing feature exits, then fewest new feature exits. Authoritative hand/option order breaks ties. It does not predict points or consume RNG during comparison.

Choices normally select the first persisted offered option. The policy declines optional Specialist assignment and Relay, declines full-capacity Relic replacement, finishes Grand Survey without removals, and chooses the first saved training role. It does not optimize Reserve or normal Survey; genuine dead hands use the existing cycling command. The Market sample alone prefers an offered Market during Act II until two copies have actually been acquired.

## Act-I completion sample

All **100 seeds (1–100)** completed their 18 ordinary Act-I placements under `alpha-playtest-r1-draft-cadence`. Every run had an actual three-design Starter offer and ten one-copy Act-I drafts: Starter plus cadence at placements 2, 4, …, 18. Opening inventory was exactly 19 unplaced physical copies: 18 fixed core copies plus the selected Starter copy.

**100%** completed at least one feature. Median completions were **7**, mean **6.48**, range **4–9**. The River generated no completion records.

| Completion type | Total | Mean | Median | Range |
|---|---:|---:|---:|---:|
| All | 648 | 6.48 | 7 | 4–9 |
| Road | 257 | 2.57 | 2 | 1–5 |
| Settlement | 238 | 2.38 | 2 | 1–4 |
| Forest | 151 | 1.51 | 2 | 0–3 |
| Monastery-family | 2 | 0.02 | 0 | 0–1 |

Distributions (completion count → runs):

- Completions: 4→5, 5→16, 6→28, 7→32, 8→15, 9→4.
- Road: 1→9, 2→43, 3→31, 4→16, 5→1.
- Settlement: 1→5, 2→53, 3→41, 4→1.
- Forest: 0→3, 1→45, 2→50, 3→2.

The earlier 45-copy sample recorded median 6 and mean 5.72. These are different acquisition systems and RNG paths, not a controlled estimate of the effect on human difficulty. Neither sample measures whether a new player recognizes closures.

## Starter and acquired-inventory diversity

The 100 runs produced **59 distinct unordered Starter triples** (90 ordered triples) and **100 distinct Act-I acquired design/count profiles**. Of 1,000 draft selections, **204 (20.4%)** selected a design previously selected in that run. This means repeated choices, not duplicate options within an offer.

Non-core variety counts distinct acquired designs absent from the fixed core; it includes placed and removed copies because this measures acquisition history. The mean was **4.42 distinct non-core designs** per run. Runs acquired 2–8 distinct non-core designs: 2 designs→7 runs, 3 designs→14 runs, 4 designs→29 runs, 5 designs→36 runs, 6 designs→9 runs, 7 designs→4 runs, 8 designs→1 runs.

| Starter design | Offers containing design | Selected | Runs acquiring design in Act I |
|---|---:|---:|---:|
| Foresters Lodge | 32 | 11 | 44 |
| Housing | 29 | 8 | 34 |
| Mill | 33 | 9 | 44 |
| Monastery | 24 | 7 | 49 |
| Riverside Hamlet | 29 | 10 | 43 |
| Settlement Corner Gate | 25 | 11 | 52 |
| Settlement Road Bend | 35 | 10 | 36 |
| Settlement Road Throughway | 28 | 9 | 44 |
| Woodland River | 35 | 11 | 49 |
| Woodland Road | 30 | 14 | 47 |

The [Act-I raw report](reports/draft_cadence_act_one_sample.json) retains every exact offer, selection, physical inventory checkpoint, design frequency, completion count and fingerprint. All 100 seeds reproduced every offer, inventory checkpoint, completion metric and fingerprint in an independent replay.

## Market Towns access

The sampler screened consecutive seeds **1–107** and continued the **30 runs that naturally selected Market Towns** through all 22 Act-II placements and into Act III. It did not force a Charter, inject a Market, or reroll an offer. While fewer than two Market copies had been acquired, it selected Market whenever present in an actual Act-II draft or Tile Reward; otherwise it selected the first persisted option.

| Access measure | Runs | Rate |
|---|---:|---:|
| Market visible in the Act-II entry offer | 21/30 | 70% |
| At least one Market acquired at entry | 21/30 | 70% |
| At least two Markets acquired at entry | 0/30 | 0% |
| At least one Market acquired by end of Act II | 28/30 | 93.33% |
| At least two Markets acquired by end of Act II | 22/30 | 73.33% |

There is one entry offer containing distinct designs, and it grants one copy. Two Market appearances or acquisitions at that entry are therefore unavailable by design. End-of-Act-II acquisition counts were: **0 copies in 2 runs, 1 in 6, 2 in 16, and 3 in 6**. More than two can result from a normal multi-copy Tile Reward or a later first-option choice after the priority ends.

Among the 28 runs acquiring a first Market, the median acquisition was **entry (placement 0)**, range 0–14. Among the 22 acquiring a second, the median was **placement 8**, range 2–22. These conditional medians exclude runs that never acquired the corresponding copy. A Market acquired after placement 22 is too late to place for that Act’s Charter evaluation.

First-copy timing: entry→21 runs; placement 2→2; 4→1; 6→1; 10→1; 12→1; 14→1. Second-copy timing: placement 2→1; 4→7; 6→3; 10→3; 12→1; 18→2; 20→4; 22→1.

**Access remains a limitation:** even this policy that takes offered Markets acquired fewer than two in **8/30 runs (26.67%)**. Acquisition is weaker evidence than placing Markets in two distinct Settlements, and it does not establish full Charter feasibility. No rules, offer weights or quantities were changed in response to these results.

## Representative unplaced inventory

Three natural runs (seeds 1–3) reached `RUN_COMPLETE` after **66 normal placements and 35 one-copy drafts each**. These use first persisted choices throughout, including Act II; they are separate from the Market-priority sample.

Unplaced inventory means bag + active hand + Reserve + inspected copies, excluding placed and permanently removed copies. “Core source” counts copies originally supplied by the fixed core; “choice source” counts acquired copies from drafts/rewards. A drafted core-design copy belongs to the latter source. Emergency copies are separate. Exact per-design and per-source counts and physical IDs are in the raw report.

I end is captured after all outgoing Act-I consequences/rewards, just before the first Act-II entry draft choice. The Act has already advanced; the final hand refill is still pending. II/III entry are after entry draft and refill. II midpoint is after placement 11 consequences.

| Seed | Checkpoint | Copies | Designs | Core source | Choice source | Emergency | Dev/Upgrade | Transformation | Dev/Trans share |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | Opening | 19 | 11 | 18 | 1 | 0 | 0 | 0 | 0.0% |
| 1 | I placement 6 | 16 | 11 | 12 | 4 | 0 | 0 | 0 | 0.0% |
| 1 | I placement 12 | 13 | 7 | 7 | 6 | 0 | 0 | 0 | 0.0% |
| 1 | I end | 10 | 7 | 4 | 6 | 0 | 0 | 1 | 10.0% |
| 1 | II entry | 11 | 8 | 4 | 7 | 0 | 1 | 1 | 18.2% |
| 1 | II midpoint | 5 | 4 | 0 | 5 | 0 | 2 | 2 | 80.0% |
| 1 | III entry | 4 | 3 | 0 | 4 | 0 | 3 | 0 | 75.0% |
| 2 | Opening | 19 | 11 | 18 | 1 | 0 | 0 | 1 | 5.3% |
| 2 | I placement 6 | 16 | 11 | 12 | 4 | 0 | 1 | 1 | 12.5% |
| 2 | I placement 12 | 13 | 8 | 7 | 6 | 0 | 0 | 1 | 7.7% |
| 2 | I end | 13 | 9 | 3 | 10 | 0 | 2 | 1 | 23.1% |
| 2 | II entry | 14 | 10 | 3 | 11 | 0 | 3 | 1 | 28.6% |
| 2 | II midpoint | 8 | 4 | 1 | 7 | 0 | 0 | 0 | 0.0% |
| 2 | III entry | 4 | 4 | 0 | 4 | 0 | 1 | 0 | 25.0% |
| 3 | Opening | 19 | 11 | 18 | 1 | 0 | 1 | 0 | 5.3% |
| 3 | I placement 6 | 16 | 11 | 12 | 4 | 0 | 2 | 0 | 12.5% |
| 3 | I placement 12 | 13 | 10 | 9 | 4 | 0 | 2 | 0 | 15.4% |
| 3 | I end | 12 | 8 | 4 | 8 | 0 | 4 | 0 | 33.3% |
| 3 | II entry | 13 | 9 | 4 | 9 | 0 | 5 | 0 | 38.5% |
| 3 | II midpoint | 7 | 6 | 1 | 6 | 0 | 2 | 0 | 28.6% |
| 3 | III entry | 6 | 6 | 0 | 4 | 2 | 1 | 0 | 16.7% |

The three runs finished with scores **197, 160 and 161**, all completed without victory. The table shows substantial consumption of the core: no original core copies remain at Act-III entry in these runs. Development/Transformation proportions vary considerably, so these three examples are descriptive snapshots rather than population estimates.

## Verification and complete-run fingerprints

The [Market-access and inventory raw report](reports/draft_cadence_market_access_sample.json) retains the 107 screened Charter selections, 30 qualified acquisition traces, all physical checkpoint inventories, and three final results. Each qualified run was independently replayed through the same actual commands. Every offer, acquisition and checkpoint matched.

A serialization-normalization fix landed during measurement: StringName sets now sort by explicit lexical strings. Rechecking all samples left every gameplay metric unchanged. Only Market sample seed 15 needed a refreshed normalized fingerprint; all 100 Act-I fingerprints and all three complete-run fingerprints matched.

| Complete run seed | Normal placements | Drafts | Score | Result |
|---:|---:|---:|---:|---|
| 1 | 66 | 35 | 197 | Completed, no victory |
| 2 | 66 | 35 | 160 | Completed, no victory |
| 3 | 66 | 35 | 161 | Completed, no victory |

Final canonical fingerprints:

- Seed 1: `99765e482615c8f7d0c04b7ba16d6f31346609b31c23721697ce70902eac13bb`
- Seed 2: `70f70dd7aeab239c69102809b49799f2097c4450f6958a1dfbfdade9f0d062bb`
- Seed 3: `f6ee405c93ffb3495042fa4be4d4f1329b6d907c461f6efa600ada5f0db8b3e3`

Native Godot parsing passed for the shared policy and both scenario scripts. Both final replay logs contained zero script errors or warnings; `git diff --check` passed. The 100-seed replay verified 1,000 one-copy Act-I drafts and exactly 19 opening copies per run. The three complete runs each resolved 35 one-copy drafts, with no cadence draft after final Act-III placement 26.

No manual mouse playtest was performed for this diagnostic. These samples neither demonstrate optimal play nor guarantee Charter fulfillment. Review the Market access shortfall in a human playtest before making any further balance decision.
