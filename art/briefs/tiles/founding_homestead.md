# Founding Tile

## 1. Tile name

**Founding Tile** — production filename stem: `founding_homestead`. Art status: **NEEDS ART**.

## 2. Authoritative role

Setup-only Homestead tile; one copy at (0,0), outside the 55-tile bag.

Source: [Complete Alpha Rules](../../../Carcassonne_Roguelite_Alpha_Complete_Rules.md), **RULE-SETUP-001–004**; bag counts follow **RULE-BAG-002**. This brief defines art, not gameplay.

## 3. Edge occupancy

- North: **Settlement**
- East: **Road**
- South: **River**
- West: **Forest**

This orientation is fixed by RULE-SETUP-001 and must not rotate during setup.

## 4. Internal feature relationships

Separate Settlement, Road, River and Forest stubs. The east Road terminates at/connects to the north Settlement: explicit Trade access. Forest and River have no additional explicit same-tile relationship.

## 5. Visual communication goals

Make four distinct systems legible at small scale. A north district meets an east gate road; a south water stub and west woodland remain distinct. Follow the [master art recipe](../../specs/master_tile_art_spec.md): parchment first, fine sepia ink second, restrained color wash third. No scenic painting or 3D rendering.

## 6. Alignment requirements

- Use the [edge alignment specification](../../specs/tile_edge_alignment_spec.md): 1000 × 1000 design units, consistent edge clarity bands, no artwork frame that interrupts joins.
- Road sockets: exact edge midpoint, 100-unit width (10%); same width/treatment across all Road designs.
- River sockets: exact edge midpoint, 200-unit width (20%); distinct from the narrower Road standard.
- Every listed Forest/Settlement edge spans corner to corner. Adjacent same-type sides share one continuous corner mass; opposite same-type sides remain connected inside. Distinct area types may meet at a corner without becoming one feature.

## 7. Color wash guidance

- Settlement: muted white walls with restrained terracotta/dusty clay roofs.
- Road: soft tan wash with fine sepia track boundaries.
- River: faint desaturated light blue with clear sepia banks.
- Forest: muted dark green wash beneath sepia tree marks.

Wash stays low-saturation and translucent. Do not use decorative color to imply an unlisted gameplay feature.

## 8. Reference images to use

Inspect the entire [approved style set](../../references/approved_style/) first, then these relevant studies:

- [03 hamlet edge](../../references/approved_style/ref_03_hamlet_edge.png) — style anchor; [mechanical study](../../references/approved_mechanical/ref_03_hamlet_edge.png) (conceptual topology only; recheck sockets).
- [05 straight road](../../references/approved_style/ref_05_straight_road.png) — style anchor; [mechanical study](../../references/approved_mechanical/ref_05_straight_road.png) (conceptual topology only; recheck sockets).
- [10 river run](../../references/approved_style/ref_10_river_run.png) — style anchor; not a mechanically certified final.
- [06 forest edge](../../references/approved_style/ref_06_forest_edge.png) — style anchor; not a mechanically certified final.

No exact example; combine treatments without borrowing unintended relationships. Example orientation/width is subordinate to this brief and the alignment spec; “approved reference” does not mean final production art.

## 9. Forbidden mistakes

Do not rotate this setup asset. Do not draw extra exits, a through-River, or a Road continuing west. Do not imply extra Forest–River or Settlement–River contact. Do not copy texture borders, off-center sockets or topology defects from a reference. Never let scenery imply additional feature exits.
