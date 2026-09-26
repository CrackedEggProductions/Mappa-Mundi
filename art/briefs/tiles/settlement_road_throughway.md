# Settlement Road Throughway

## 1. Tile name

**Settlement Road Throughway** — production filename stem: `settlement_road_throughway`. Art status: **NEEDS ART**.

## 2. Authoritative role

Specialized/Hybrid Act-I Expansion; perpendicular through-connections with explicit access. Starting bag: **2 copies**.

Source: [Complete Alpha Rules](../../../Carcassonne_Roguelite_Alpha_Complete_Rules.md), **RULE-CAT-021**; bag counts follow **RULE-BAG-002**. This brief defines art, not gameplay.

## 3. Edge occupancy

- North: **Settlement**
- East: **Road**
- South: **Settlement**
- West: **Road**

This is the production orientation, cross-checked against the existing Homestead content definition; the catalogue defines the topology, not a new fixed play orientation. Rotate the whole tile in 90-degree steps during play; do not mirror it.

## 4. Internal feature relationships

North/south Settlement is one continuous component. East/west Road is one continuous component. Both remain distinct with explicit internal Road–Settlement access.

## 5. Visual communication goals

An east–west road passes through gates/streets in a continuous north–south district. Keep urban continuity and the through-road legible together. Follow the [master art recipe](../../specs/master_tile_art_spec.md): parchment first, fine sepia ink second, restrained color wash third. No scenic painting or 3D rendering.

## 6. Alignment requirements

- Use the [edge alignment specification](../../specs/tile_edge_alignment_spec.md): 1000 × 1000 design units, consistent edge clarity bands, no artwork frame that interrupts joins.
- Road sockets: exact edge midpoint, 100-unit width (10%); same width/treatment across all Road designs.
- Every listed Forest/Settlement edge spans corner to corner. Adjacent same-type sides share one continuous corner mass; opposite same-type sides remain connected inside. Distinct area types may meet at a corner without becoming one feature.

## 7. Color wash guidance

- Settlement: muted white walls with restrained terracotta/dusty clay roofs.
- Road: soft tan wash with fine sepia track boundaries.

Wash stays low-saturation and translucent. Do not use decorative color to imply an unlisted gameplay feature.

## 8. Reference images to use

Inspect the entire [approved style set](../../references/approved_style/) first, then these relevant studies:

- [03 hamlet edge](../../references/approved_style/ref_03_hamlet_edge.png) — style anchor; [mechanical study](../../references/approved_mechanical/ref_03_hamlet_edge.png) (conceptual topology only; recheck sockets).
- [05 straight road](../../references/approved_style/ref_05_straight_road.png) — style anchor; [mechanical study](../../references/approved_mechanical/ref_05_straight_road.png) (conceptual topology only; recheck sockets).

No exact example; keep the urban through-region and the gated through-road simultaneously legible. Example orientation/width is subordinate to this brief and the alignment spec; “approved reference” does not mean final production art.

## 9. Forbidden mistakes

Do not break the Settlement into separate halves or stop the Road inside town. Do not imply a Bridge/River, dual-type edge or extra exit. Do not copy texture borders, off-center sockets or topology defects from a reference. Never let scenery imply additional feature exits.
