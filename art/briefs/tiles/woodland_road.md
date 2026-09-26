# Woodland Road

## 1. Tile name

**Woodland Road** — production filename stem: `woodland_road`. Art status: **NEEDS ART**.

## 2. Authoritative role

Specialized/Hybrid Act-I Expansion; adjacent Forest pair beside adjacent Road pair. Starting bag: **2 copies**.

Source: [Complete Alpha Rules](../../../Carcassonne_Roguelite_Alpha_Complete_Rules.md), **RULE-CAT-017**; bag counts follow **RULE-BAG-002**. This brief defines art, not gameplay.

## 3. Edge occupancy

- North: **Forest**
- East: **Forest**
- South: **Road**
- West: **Road**

This is the production orientation, cross-checked against the existing Homestead content definition; the catalogue defines the topology, not a new fixed play orientation. Rotate the whole tile in 90-degree steps during play; do not mirror it.

## 4. Internal feature relationships

North/east Forest is one component; south/west Road is another. They remain distinct; no extra explicit access relationship is defined.

## 5. Visual communication goals

A dense northeast corner woodland and a clear southwest road bend coexist. Trees must not hide the road's connectivity. Follow the [master art recipe](../../specs/master_tile_art_spec.md): parchment first, fine sepia ink second, restrained color wash third. No scenic painting or 3D rendering.

## 6. Alignment requirements

- Use the [edge alignment specification](../../specs/tile_edge_alignment_spec.md): 1000 × 1000 design units, consistent edge clarity bands, no artwork frame that interrupts joins.
- Road sockets: exact edge midpoint, 100-unit width (10%); same width/treatment across all Road designs.
- Every listed Forest/Settlement edge spans corner to corner. Adjacent same-type sides share one continuous corner mass; opposite same-type sides remain connected inside. Distinct area types may meet at a corner without becoming one feature.

## 7. Color wash guidance

- Forest: muted dark green wash beneath sepia tree marks.
- Road: soft tan wash with fine sepia track boundaries.

Wash stays low-saturation and translucent. Do not use decorative color to imply an unlisted gameplay feature.

## 8. Reference images to use

Inspect the entire [approved style set](../../references/approved_style/) first, then these relevant studies:

- [02 woodland road study](../../references/approved_style/ref_02_woodland_road_study.png) — style anchor; not a mechanically certified final.
- [07 forest bend](../../references/approved_style/ref_07_forest_bend.png) — style anchor; not a mechanically certified final.
- [09 bending road](../../references/approved_style/ref_09_bending_road.png) — style anchor; [mechanical study](../../references/approved_mechanical/ref_09_bending_road.png) (conceptual topology only; recheck sockets).

The Woodland Road study has opposite Road/Forest pairs and separated woods: style only, not canonical topology. The required pairs are adjacent. Example orientation/width is subordinate to this brief and the alignment spec; “approved reference” does not mean final production art.

## 9. Forbidden mistakes

Do not split the Forest corner, join Road to Forest as one feature, add an invented access relation, or allow tree decoration to obscure Road sockets. Do not copy texture borders, off-center sockets or topology defects from a reference. Never let scenery imply additional feature exits.
