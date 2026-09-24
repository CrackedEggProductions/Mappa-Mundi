# Settlement Corner

## 1. Tile name

**Settlement Corner** — production filename stem: `settlement_corner`. Art status: **NEEDS ART**.

## 2. Authoritative role

Basic Act-I Expansion; connects adjacent Settlement sides. Starting bag: **3 copies**.

Source: [Complete Alpha Rules](../../../Carcassonne_Roguelite_Alpha_Complete_Rules.md), **RULE-CAT-013**; bag counts follow **RULE-BAG-002**. This brief defines art, not gameplay.

## 3. Edge occupancy

- North: **Settlement**
- East: **Settlement**
- South: **Field**
- West: **Field**

This is the production orientation, cross-checked against the existing Homestead content definition; the catalogue defines the topology, not a new fixed play orientation. Rotate the whole tile in 90-degree steps during play; do not mirror it.

## 4. Internal feature relationships

One continuous Settlement component joins north and east; south and west remain Field.

## 5. Visual communication goals

A clean northeast urban corner, with continuous built fabric across the full north/east boundaries and shared corner. Follow the [master art recipe](../../specs/master_tile_art_spec.md): parchment first, fine sepia ink second, restrained color wash third. No scenic painting or 3D rendering.

## 6. Alignment requirements

- Use the [edge alignment specification](../../specs/tile_edge_alignment_spec.md): 1000 × 1000 design units, consistent edge clarity bands, no artwork frame that interrupts joins.
- Every listed Forest/Settlement edge spans corner to corner. Adjacent same-type sides share one continuous corner mass; opposite same-type sides remain connected inside. Distinct area types may meet at a corner without becoming one feature.
- Keep Field boundaries open and visually quiet; no unlisted feature may acquire an edge exit. Area-feature corner endpoints do not create an extra Field-side connection.

## 7. Color wash guidance

- Settlement: muted white walls with restrained terracotta/dusty clay roofs.
- Field: faint desaturated light green; keep the parchment visible.

Wash stays low-saturation and translucent. Do not use decorative color to imply an unlisted gameplay feature.

## 8. Reference images to use

Inspect the entire [approved style set](../../references/approved_style/) first, then these relevant studies:

- [03 hamlet edge](../../references/approved_style/ref_03_hamlet_edge.png) — style anchor; [mechanical study](../../references/approved_mechanical/ref_03_hamlet_edge.png) (conceptual topology only; recheck sockets).
- [07 forest bend](../../references/approved_style/ref_07_forest_bend.png) — style anchor; not a mechanically certified final.

Use Hamlet for built treatment; Forest Bend only for adjacent-region layout, not its trees or incomplete edge coverage. Example orientation/width is subordinate to this brief and the alignment spec; “approved reference” does not mean final production art.

## 9. Forbidden mistakes

Do not draw two isolated towns or rounded edge bumps. Do not add road-like exits on Field boundaries. Do not copy texture borders, off-center sockets or topology defects from a reference. Never let scenery imply additional feature exits.
