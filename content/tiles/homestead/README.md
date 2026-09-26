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
They are the only Transformation-style exception in the starting bag.

The manifest and starting-bag entries are ordered by stable definition ID.
`homestead_run_config.tres` contains the canonical **45 player copies**:
Forest Edge 4, Forest Bend 3, Forest Belt 2; Straight Road 4, Bending Road 4,
Road Junction 4; Hamlet Edge 4, Settlement Corner 3, Settlement Throughway 2,
Settlement Gate 3; Riverside Hamlet 2, Woodland Road 2, Woodland River 2,
Settlement Corner Gate 2, Settlement Road Bend 2, Settlement Road Throughway 2.
Founding and eight environmental River copies are additional board setup pieces.
The emergency player set is Hamlet Edge, Road Junction and Forest Edge.

Cross-feature access/touch metadata remains distinct from physical connectivity.
Founding has Road–Settlement access. Overlay effects declare same-tile River
contact authoritatively. Art remains presentation-owned; it cannot change these
mechanical facts.
