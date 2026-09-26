# Alpha Playtest Revision 1 — Second human playtest

This is a core-loop revision after Phase 10, not Phase 11. Start a **new run**:
pre-revision saves are intentionally incompatible with rules `alpha-playtest-r1`
and schema 2. No Save/Continue or export work is part of this revision.

## What changed

- Player starting bag: 45 copies. Open Fields, Road End and pure River pieces no
  longer appear in hands or rewards. Field geography remains important.
- The world starts with Founding plus five River Runs, two River Bends and one
  River End: one connected nine-tile River. River itself never completes/scores.
- Junctions terminate separate Roads while connecting their Trade Networks.
  Empty Junction arms create no unfinished Road obligation; Junctions add no
  physical Road length or flat bonus.
- Riverside Hamlet adds a Settlement bank to an existing straight River Run.
  Woodland River adds Forest to both banks of an existing Bend. Both use normal
  placements, preserve River and leave the Development slot available.
- Forest completion gains base Ecology for newly scoring River-tile contacts.
  Riverkeeper works River-touching Forests; Harbormaster works River-touching
  Settlements. Neither targets River.
- Living Landscape, Stewardship of Land and Living Heritage now ask for River
  interactions. Riverside Hamlet, Woodland River, Port and Bridge each count.
  River Stewardship rewards genuine Settlement/Forest completion touching three
  distinct River tiles, once per run.
- Parchment Charter/Grand Charter text uses dark ink.

## Mouse playtest checklist

Launch with `godot --path .` from the project root. Record seed, window size,
Act reached and any confusing tile/choice before reporting a problem.

1. Start a New Run. Confirm Founding and the complete River are visible. Use Fit
   Board, pan and zoom; inspect River tiles as existing environment.
2. Read the Act-I Charter. Verify normal body/progress text is dark and readable
   on parchment. Check Grand forecast and exact requirements later too.
3. Play all 18 Act-I placements. Record Road, Settlement and Forest completions.
   Does at least one feature usually complete? Where did closure feel blocked?
4. Try a Road Junction as an endpoint. Do separate Roads and Trade continuation
   make sense? Are Roads easier to plan without Road End?
5. Observe hand quality without Open Fields. Does the 45-copy bag retain useful
   variety, or are too many choices interchangeable/unplayable?
6. Select Riverside Hamlet. Preview different legal banks on an occupied Run;
   cancel, then confirm. Is the preserved River and added Settlement readable?
7. Select Woodland River. Preview/confirm on an occupied Bend. Are its two Forest
   exits clear? Does it feel like working with geography rather than extending it?
8. Assign/train Riverkeeper on an eligible Forest and Harbormaster on an eligible
   Settlement when offered. Are their target and bonus descriptions clear?
9. In later Acts try Port, Ferry Rights and Bridge where available. Inspect their
   River relationships and Trade reach. Verify River never announces completion.
10. Assess the revised nature Charters. Do interaction counts feel achievable
    while still demanding deliberate choices?
11. Finish later Acts if practical; inspect results and final map. Report River
    size as geography, not a player completion achievement.

Record whether the generated River makes the opening more interesting or
obstructs too much build space. Compare a few seeds before drawing conclusions.
Also report modal/input failures, unreadable text and any interaction whose
mechanical result differs from its preview.

## Completion-density diagnostic

The automated Act-I diagnostic is **not human play** and does not establish game
balance. It samples at least 100 deterministic seeds with a closure-preferring
heuristic: immediate genuine completion first, then fewer unresolved exits,
then fewer newly introduced exits, with deterministic tie-breaking. Choices use
a documented deterministic policy. Report percentage with at least one
completion, median/mean totals and Road/Settlement/Forest distributions.

Suggested health indicators are ≥80% of runs with a completion and median ≥2.
They are observations, not canonical invariants and not permission to change the
specified bag or rules. Record actual measured results in the implementation
report; do not treat this checklist as evidence of a completed human playtest.
