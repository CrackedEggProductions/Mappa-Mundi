# Mappa Mundi — Revision-1 Homestead content

These passive definitions implement Complete Alpha Rules sections 3, 5 and 6.
The historical Phase-0 samples remain separate loading fixtures. The current
playable run uses the full content profile; `load_homestead()` remains the
focused board/content foundation profile.

Canonical edges use North, East, South, West. Single-edge pieces point North;
bends occupy North/East; opposite-edge pieces occupy North/South; Road Junction
occupies North/East/South. Settlement Gate uses Settlement North and Road East.
Settlement Road Throughway uses Settlement North/South and Road East/West.
Founding is fixed at Settlement/Road/River/Forest.

Non-Field feature groups normally list internally connected sockets. Road
Junction is the explicit exception: `intersection_hub` declares terminal Road
sockets but no physical Road group. The base physical copy ID identifies its
Trade hub. Roads meeting different arms remain separate and terminate there;
Trade continues through the hub and matching neighboring Junction hubs.

River End, River Run and River Bend are `setup_environment`, not
`player_drawable`. Setup places five Runs, two Bends and one End, connected to
Founding's South River. Their stable physical copies remain on the board; River
has connected size/contact identity but no completion/scoring lifecycle.
Open Fields and Road End retain legacy definitions/art and are neither player
nor setup content.

Riverside Hamlet and Woodland River are Act-I player Transformation overlays,
not empty-square Expansions. They target a straight River Run and River Bend
respectively, preserve River and add explicit Settlement/Forest contact. They
retain Specialized/Hybrid reward class (two copies) and Masterwork eligibility.
They enter through Starter/regular drafts and rewards, not automatic core copies.

The manifest and starting-bag entries are ordered by stable definition ID.
`homestead_run_config.tres` contains the canonical **18 core copies**:
Forest Edge 3, Forest Bend 1, Forest Belt 1; Straight Road 2, Bending Road 2,
Road Junction 2; Hamlet Edge 3, Settlement Corner 1, Monastery 1,
Settlement Gate 2. No other design starts in the core.

The full run offers a Starter Draft from Riverside Hamlet, Woodland Road, Woodland
River, Settlement Corner Gate, Settlement Road Bend, Settlement Road Throughway,
Housing, Mill, Monastery and Forester's Lodge. It grants one selected copy and
shuffles before opening draws. Regular draft pools contain 20/25/28 unlocked player
designs. Act entry unlocks five/three designs and offers one restricted single-copy
draft; no automatic Act-seed batch exists. Normal Tile Reward quantities are unchanged.
Founding and eight environmental River copies are additional board setup pieces.
The emergency player set is Hamlet Edge, Road Junction and Forest Edge.

Cross-feature access/touch metadata remains distinct from physical connectivity.
Founding has Road–Settlement access. Overlay effects declare same-tile River
contact authoritatively. Art remains presentation-owned; it cannot change these
mechanical facts.

Settlement Throughway stays in unlocked draft/reward pools. Abbey and Grand Market
Tile Draft offers require an actual non-upgraded base Development on board or in
bag; hand/Reserve/history do not count. Normal Tile Rewards are unaffected.
