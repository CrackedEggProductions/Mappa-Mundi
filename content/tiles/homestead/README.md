# Mappa Mundi — Homestead Expansion content

These passive definitions implement Complete Alpha Rules sections 3, 5.1 and 6.
The historical Phase-0 samples remain separate loading fixtures. A playable
Phase-2 run loads `ContentRegistry.load_homestead()`.

Canonical edges use North, East, South, West. Single-edge pieces point North;
bends occupy North/East; opposite-edge pieces occupy North/South; Road Junction
occupies North/East/South. The first named feature of a hybrid occupies North
and, when it has an adjacent pair, East. Settlement Gate uses Settlement North
and Road East. Riverside Hamlet uses Settlement North and River East/West.
Settlement Road Throughway uses Settlement North/South and Road East/West.
The Founding Tile is fixed at Settlement/Road/River/Forest.

Each non-Field feature type has one explicit group listing its directional
sockets. Cross-feature relationships refer to the participating types, so they
survive rotation while each group's directional sockets rotate. Access and touch
do not merge unlike feature types. Woodland Road has no cross-feature link;
Founding has only Road–Settlement access. These are local facts, not connected
board topology.

The manifest and starting-bag entries are ordered by stable definition ID.
Starting copy counts live in `homestead_run_config.tres`; startup validation
checks them against the canonical 55-copy contract. The Founding Tile has reward
class NONE and no bag entry. River End replaces the historical River Source.

No art or presentation geometry is stored here. Mechanical sockets remain exact
regardless of the later continuous parchment presentation.
