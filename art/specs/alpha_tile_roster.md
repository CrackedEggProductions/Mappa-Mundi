# Mappa Mundi — Alpha base tile-art roster

Prepared 2026-09-24. This is the art checklist for **22 designs: one fixed Founding Tile plus 21 Homestead starting-bag Expansion designs**. The bag contains **55 physical copies**; the setup Founding Tile is additional, so the initial collection uses 56 physical tiles but needs only 22 base designs.

## Authority and orientation

The [Complete Alpha Rules Specification](../../Carcassonne_Roguelite_Alpha_Complete_Rules.md) controls this roster: **RULE-SETUP-001–004**, **RULE-CAT-001–021**, **RULE-BAG-001–004** and **RULE-BOARD-003–007**. The [Implementation Specification](../../Carcassonne_Roguelite_Implementation_Specification.md) supplies definition/physical-copy context; the [Visual Design Specification v0.2](../../Mappa_Mundi_Visual_Design_Specification_v0.2.md) controls presentation. The older [Tile Design Specification](../../Carcassonne_Roguelite_Tile_Design_Specification.md) is supplemental only.

Edges below are **North / East / South / West**, viewed from above. Founding orientation is fixed by the rules. Other rows use the existing [Homestead content definitions](../../content/tiles/homestead/) as a consistent **production orientation** for the canonically specified topology; this does not restrict the normal 90-degree gameplay rotations. Do not mirror a tile as a substitute for rotation.

Each edge has one mechanical type. Same-type exits form one connected component unless explicitly specified otherwise. Road–Settlement access and other same-tile contacts listed here do not merge different feature types. Forest/Settlement occupy full sides corner-to-corner; Road/River cross centered sockets. Follow the [alignment spec](tile_edge_alignment_spec.md) for the exact art-production geometry.

## Status meaning

- **HAS EXAMPLE**: an existing local study plausibly matches this design; it is not an approved production export.
- **NEEDS REVISION**: a matching study exists, but its connections or edge coverage need correction.
- **NEEDS REVIEW**: the likely identity itself needs confirmation before mechanical use.
- **NEEDS ART**: no exact matching study exists; related styles may still guide a new candidate.

Style approval does not certify sockets, full edge coverage, seamless joins or final resolution. Reference numbers below match the [image inventory](../TILE_ART_STATUS.md).

## Founding Tile

| Design / brief | Copies | N / E / S / W | Internal feature relationships | Existing example / interpretation | Art status |
|---|---:|---|---|---|---|
| [Founding Tile](../briefs/tiles/founding_homestead.md) | Setup ×1; not bag | Settlement / Road / River / Forest | Separate Settlement, Road, River and Forest stubs. The east Road terminates at/connects to the north Settlement: explicit Trade access. Forest and River have no additional explicit same-tile relationship. | No exact example; combine treatments without borrowing unintended relationships. | **NEEDS ART** |

## Homestead bag — exactly 21 Expansion designs

| Design / brief | Bag copies | N / E / S / W | Internal feature relationships | Existing example / interpretation | Art status |
|---|---:|---|---|---|---|
| [Open Fields](../briefs/tiles/open_fields.md) | 4 | Field / Field / Field / Field | All four edges are Field. No tracked Road, River, Forest or Settlement component. | [ref_04_open_fields](../references/approved_style/ref_04_open_fields.png); All-Field example; retain its open parchment. | **HAS EXAMPLE** |
| [Forest Edge](../briefs/tiles/forest_edge.md) | 3 | Forest / Field / Field / Field | One Forest component enters north and terminates internally. Other sides remain Field. | [ref_06_forest_edge](../references/approved_style/ref_06_forest_edge.png); Forest stub is recognizable; extend the north Forest to both corners. | **NEEDS REVISION** |
| [Forest Bend](../briefs/tiles/forest_bend.md) | 3 | Forest / Forest / Field / Field | One connected Forest component joins north and east; south and west remain Field. | [ref_07_forest_bend](../references/approved_style/ref_07_forest_bend.png); Adjacent Forest is recognizable; fill the complete north/east spans and outer endpoints. | **NEEDS REVISION** |
| [Forest Belt](../briefs/tiles/forest_belt.md) | 2 | Forest / Field / Forest / Field | One connected Forest component runs north–south; east and west remain Field. | [ref_14_forest_belt_study](../references/approved_style/ref_14_forest_belt_study.png); Study separates north/south woods with an open horizontal strip; restore one continuous Forest. | **NEEDS REVISION** |
| [River End](../briefs/tiles/river_end.md) | 2 | River / Field / Field / Field | One River component meets north and ends within the tile; east, south and west remain Field. | [ref_15_river_end](../references/approved_style/ref_15_river_end.png); North water endpoint/pool is a useful match. | **HAS EXAMPLE** |
| [River Run](../briefs/tiles/river_run.md) | 3 | River / Field / River / Field | One continuous River component joins north and south; east and west remain Field. | [ref_10_river_run](../references/approved_style/ref_10_river_run.png); North–south River is recognizable; standardize centered banks and width. | **HAS EXAMPLE** |
| [River Bend](../briefs/tiles/river_bend.md) | 3 | River / River / Field / Field | One continuous River component joins north and east; south and west remain Field. | [ref_13_river_bend](../references/approved_style/ref_13_river_bend.png); North–east River bend is a useful match. | **HAS EXAMPLE** |
| [Road End](../briefs/tiles/road_end.md) | 3 | Road / Field / Field / Field | One Road component meets north and ends internally; other sides remain Field. | [ref_01_road_end](../references/approved_style/ref_01_road_end.png); Probable south Road endpoint; reeds and the rounded terminus create water ambiguity. Confirm identity before treating it as mechanical evidence. | **NEEDS REVIEW** |
| [Straight Road](../briefs/tiles/straight_road.md) | 4 | Road / Field / Road / Field | One continuous Road component joins north and south; east and west remain Field. | [ref_05_straight_road](../references/approved_style/ref_05_straight_road.png); East–west example rotates to the north–south production orientation. | **HAS EXAMPLE** |
| [Bending Road](../briefs/tiles/bending_road.md) | 4 | Road / Road / Field / Field | One continuous Road component joins north and east; south and west remain Field. | [ref_09_bending_road](../references/approved_style/ref_09_bending_road.png); North–west example rotates to north–east. | **HAS EXAMPLE** |
| [Road Junction](../briefs/tiles/road_junction.md) | 2 | Road / Road / Road / Field | North, east and south Roads form one connected Road component; west is Field. | [ref_11_road_junction](../references/approved_style/ref_11_road_junction.png); East/south/west three-arm example has east/west sockets above midpoint; recenter and rotate for production. | **NEEDS REVISION** |
| [Hamlet Edge](../briefs/tiles/hamlet_edge.md) | 3 | Settlement / Field / Field / Field | One Settlement component occupies north and ends internally; other sides remain Field. | [ref_03_hamlet_edge](../references/approved_style/ref_03_hamlet_edge.png); North Settlement example; the short decorative gate approach is not a Road edge. | **HAS EXAMPLE** |
| [Settlement Corner](../briefs/tiles/settlement_corner.md) | 3 | Settlement / Settlement / Field / Field | One continuous Settlement component joins north and east; south and west remain Field. | No exact example; Use Hamlet for built treatment; Forest Bend only for adjacent-region layout, not its trees or incomplete edge coverage. | **NEEDS ART** |
| [Settlement Throughway](../briefs/tiles/settlement_throughway.md) | 2 | Settlement / Field / Settlement / Field | One continuous Settlement component joins north and south; east and west remain Field. There is no Road component. | No exact example; use Hamlet's built treatment as a palette/ink reference. | **NEEDS ART** |
| [Settlement Gate](../briefs/tiles/settlement_gate.md) | 2 | Settlement / Road / Field / Field | North Settlement and east Road are separate components. The Road terminates at/connects to the Settlement internally; south and west are Field. | No exact example; an edge-reaching Road connection must be added deliberately. | **NEEDS ART** |
| [Riverside Hamlet](../briefs/tiles/riverside_hamlet.md) | 2 | Settlement / River / Field / River | One straight River joins east and west. The north Settlement is distinct but explicitly touches that River internally. South is Field. | No exact example; compose an explicit Settlement–River contact. | **NEEDS ART** |
| [Woodland Road](../briefs/tiles/woodland_road.md) | 2 | Forest / Forest / Road / Road | North/east Forest is one component; south/west Road is another. They remain distinct; no extra explicit access relationship is defined. | No exact example; The Woodland Road study has opposite Road/Forest pairs and separated woods: style only, not canonical topology. The required pairs are adjacent. | **NEEDS ART** |
| [Woodland River](../briefs/tiles/woodland_river.md) | 2 | Forest / Forest / River / River | North/east Forest is one component; south/west River is another. Forest and River remain distinct but explicitly touch internally. | No exact example; compose the two adjacent pairs with explicit internal contact. | **NEEDS ART** |
| [Settlement Corner Gate](../briefs/tiles/settlement_corner_gate.md) | 2 | Settlement / Settlement / Road / Field | North/east Settlement forms one continuous corner. South Road terminates at/connects to that Settlement internally; west is Field. | No exact example; build the continuous corner plus a terminating gate Road. | **NEEDS ART** |
| [Settlement Road Bend](../briefs/tiles/settlement_road_bend.md) | 2 | Settlement / Settlement / Road / Road | North/east Settlement is one continuous component. South/west Road is one continuous component. They have explicit internal Road–Settlement access; neither is required to terminate here. | No exact example; keep both bends continuous and add explicit access. | **NEEDS ART** |
| [Settlement Road Throughway](../briefs/tiles/settlement_road_throughway.md) | 2 | Settlement / Road / Settlement / Road | North/south Settlement is one continuous component. East/west Road is one continuous component. Both remain distinct with explicit internal Road–Settlement access. | No exact example; keep the urban through-region and the gated through-road simultaneously legible. | **NEEDS ART** |
| **Total** | **55** | | | **21 bag designs** | |

## Coverage and remaining work

**12 designs are plausibly represented:** 7 HAS EXAMPLE, 4 NEEDS REVISION and 1 NEEDS REVIEW. That is 11 clear design matches plus the provisional Road End identification.

- **HAS EXAMPLE (7):** Open Fields, Straight Road, Bending Road, River End, River Run, River Bend, Hamlet Edge.
- **NEEDS REVISION (4):** Forest Edge, Forest Bend, Forest Belt, Road Junction.
- **NEEDS REVIEW (1):** Road End; the narrow tan south-facing terminus may be a Road, but reeds/end shape make the reading uncertain.
- **NEEDS ART (10):** Founding Tile, Settlement Corner, Settlement Throughway, Settlement Gate, Riverside Hamlet, Woodland Road, Woodland River, Settlement Corner Gate, Settlement Road Bend, Settlement Road Throughway.

The [Woodland Road study](../references/approved_style/ref_02_woodland_road_study.png) remains valuable for style, but opposite Road/Forest pairs and disconnected woodland do **not** represent canonical Woodland Road's two adjacent pairs. The [four-way Road study](../references/approved_style/ref_08_four_way_road_study.png) is outside this alpha starting roster. The [Bridge study](../references/approved_style/ref_12_bridge_study.png) illustrates later content, not a starting Expansion.

## Scope guard

- The canonical **River End** serves both source and terminus. Do not add the older prototype's separate River Source design.
- **Road End** serves start and terminus; there is no separate Road Start.
- Road Junction has exactly three exits. Four-way crossroads are deferred.
- Settlement Throughway has no Road. Settlement **Road** Throughway has both an opposite Settlement pair and an opposite Road pair, with explicit internal access.
- The 55-copy bag contains no Developments, Upgrades or Transformations. Housing, Mill, Monastery, Forester's Lodge, Market, Port, Town Square, Abbey, Grand Market, Urban Expansion, Bridge and Rewilding are outside this base-art brief set.
- Optional later overlays must preserve base geography and layer identity. No later gameplay or asset batch is introduced by this roster.

Use the [master art spec](master_tile_art_spec.md), [edge alignment spec](tile_edge_alignment_spec.md), selected linked brief and local approved references together for each future candidate.
