# Alpha Playtest Revision 1 — Relic Rarity playtest

This is a core-loop revision after Phase 10, not Phase 11. Start a **new run**:
pre-revision saves are intentionally incompatible with rules `alpha-playtest-r1-relic-rarity`
and schema 3. No Save/Continue or export work is part of this revision.

## What changed

- The core bag has 18 copies across nine Expansion designs plus Monastery. Choose one
  directional Act-I Starter Draft before opening draws. Every draft adds one physical
  copy and shuffles the bag; Normal Tile Rewards keep their usual quantities.
- Cadence drafts occur after even normal placements: Act I 2–18, Act II 2–22,
  Act III 2–24. Act entry unlocks content and offers one restricted draft; no
  automatic seed batches remain. Track rewards are now **20 Relic, 40 Train,
  70 Relic, 100 Major**; the temporary empty 20 threshold is superseded.
- Relic rarity is separate from minimum Act. Common/Uncommon/Rare weights are
  60/30/10 **per eligible Relic**, sampled without replacement for up to three
  choices. Boundary Stones, Compass and Satchel are Common; Village Green,
  Mixed-Use Charter and Historic Routes are Uncommon; Ferry Rights, Relay,
  One Great City and The Long Road are Rare. Only Mixed-Use Charter and Historic
  Routes wait until Act II; the other eight may appear in Act I. Effects and
  capacity 2/4/5 are unchanged.
- Blank New Run seed uses fresh external entropy. Enter an integer to replay a
  run, or use Randomize to fill a candidate without starting. The full seed is
  readable/copyable in the Act HUD and remains in results.
- Hover hand and Reserve tiles for their category, placement requirement and
  concise effect on parchment. Draft cards share the same rules information.
- Open Fields, Road End and pure River pieces never appear in hands/rewards.
  Field geography remains important.
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

1. Start a New Run with the seed blank and record the displayed seed. Also try
   entering a previous seed and following the same choices. Confirm Founding and the complete River are visible. Use Fit
   Board, pan and zoom; inspect River tiles as existing environment. Before choosing
   the Starter Draft, verify the hand is empty; afterward it has three tiles.
2. Read the Act-I Charter. Verify normal body/progress text is dark and readable
   on parchment. Check Grand forecast and exact requirements later too.
3. Play all 18 Act-I placements. Record Road, Settlement and Forest completions.
   Does at least one feature usually complete? Where did closure feel blocked?
4. Try a Road Junction as an endpoint. Do separate Roads and Trade continuation
   make sense? Are Roads easier to plan without Road End?
5. Observe the smaller core and drafts. Does each single-copy choice meaningfully
   shape the bag? Does the guaranteed Monastery help Culture without making later choices predictable?
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
11. Check an even-placement draft appears after all other consequences and before
    replacement draw. At Act I placement 18 and Act II placement 22, resolve it
    before the outgoing Charter rewards. Bonus placements grant no extra drafts.
12. At each Act entry, inspect the restricted new-design offer. Confirm the chosen
    tile is one physical copy and may become the pending hand replacement. There
    should be no automatic batch of new tiles or extra transition shuffle.
13. Cross Track 20: a Relic Offer should appear once per Track after the scoring
    package resolves. Check rarity labels and replacement/decline when capacity
    is full. Training at 40, Relic at 70, Major Reward at 100 and Charter rewards
    remain unchanged.
14. Finish later Acts if practical; inspect results and final map. Report River
    size as geography, not a player completion achievement. Act III placement 26
    should resolve its consequences then end without a cadence draft or hand refill.

Record whether the generated River makes the opening more interesting or
obstructs too much build space. Compare a few seeds before drawing conclusions.
Also report modal/input failures, unreadable text and any interaction whose
mechanical result differs from its preview.

## Draft-cadence feedback

Record a short answer and a concrete example where possible. Compare more than
one seed before judging variety.

1. Does the 18-copy core feel dependable or repetitive?
2. Does the Starter Draft give the run a useful direction?
3. Is a draft every two placements welcome, or does it interrupt play too often?
4. Can you read the three options and make a choice quickly?
5. Do different draft choices make runs develop differently?
6. Can you respond to the current map through draft choices?
7. Can you choose useful closure/endpoint tools when features need finishing?
8. Does tile supply ever feel starved? Record when emergency replenishment appears.
9. Does the bag become bloated with tiles you no longer want to draw?
10. Can you access newly unlocked designs reliably enough without automatic seeding?
11. When Market Towns is selected, is Market-family access sufficient to pursue it?
12. Does the Act Entry Draft make entering a new Act feel meaningful?
13. Do Track-20 Relics add useful early choices without overwhelming draft decisions?
14. Do multi-copy Normal Tile Rewards still feel special beside single-copy drafts?

## Tile information, seeds and Relic feedback

Record concrete examples rather than treating one offer or run as proof of balance.

1. Are tile hover rules concise enough? Which placement exception or effect is still missing?
2. Hover Monastery, Forester's Lodge, Abbey and Grand Market when available. Can you
   tell where each belongs and when it pays without leaving the game?
3. Do fresh seeds noticeably vary the Charter, River and Starter Draft? Is entering
   and copying a previous seed easy enough?
4. How early does each Track reach 20? Record the Act/placement and the offered Relics.
5. Do Relics now feel important to the run? Are too many offered before capacity expands?
6. Does replacing or declining at full capacity feel interesting or annoying?
7. Do Rare Relics feel exciting, and do they appear too often or too rarely?
8. Does an early One Great City or The Long Road create a useful build pivot?
9. Are Common Relics still worth choosing over a Rare when they fit the map?

The rarity diagnostic samples 10,000 offers per Act-I/Act-II pool and reports
individual appearance rates, Rare/Uncommon offer presence and slot representation.
It is automated evidence about **60/30/10 per-item weights**, not human play or
permission to retune them. Track-20 timing, when measured, is a separate diagnostic.

## Completion-density diagnostic

The automated Act-I diagnostic is **not human play** and does not establish game
balance. Each report must name its rules version: earlier 45-copy results do not
measure the current 18-copy/draft system. It samples at least 100 deterministic seeds with a closure-preferring
heuristic: immediate genuine completion first, then fewer unresolved exits,
then fewer newly introduced exits, with deterministic tie-breaking. Choices use
a documented deterministic policy. Report percentage with at least one
completion, median/mean totals and Road/Settlement/Forest distributions.

Suggested health indicators are ≥80% of runs with a completion and median ≥2.
They are observations, not canonical invariants and not permission to change the
specified bag or rules. Record actual measured results in the implementation
report; do not treat this checklist as evidence of a completed human playtest.

## Usability pass — 2026-10-01

Use the compact top cards to find Act/placements, all four Tracks, Charter condition
count and the next draft. Toggle the right-side Charter overlay; verify it reserves
no empty space when closed and the current map remains available. Inspect each
Relic/Steward through its compact slot. Select a tile and check the gold frame;
rotate, preview, Cancel and Confirm. Use Reserve, Survey, Fit and both zoom buttons.
Check event cards are readable and easy to dismiss. Repeat at 1280×720 and a larger
window, including a crowded late-run board and long tile names.

- Can you comfortably read and use this interface for an hour?
- Does the map remain the main focus while the hand is easy to scan?
- Can you tell which action is available now without reading a long status block?
- Does the Charter popout explain current and historical requirements clearly?
- Are one-click draft decisions fast enough? Can you inspect the Starter Charter?
- Does the fixed Monastery feel useful? Settlement Throughway should still appear
  in ordinary drafts and rewards, and Monastery may still be drafted again.
- Observe Abbey eligibility with Monastery in bag, then only hand/Reserve, then
  board. Repeat Grand Market with Market. Only board/bag qualifies for a **new draft**;
  existing offers and Normal Tile Rewards are unaffected.

No human hour-long test has been performed by the implementation agent. Automated
mouse smoke and screenshots are verification aids, not a replacement for this playtest.
