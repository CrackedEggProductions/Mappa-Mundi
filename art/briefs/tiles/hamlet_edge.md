# Hamlet Edge

## 1. Tile name

**Hamlet Edge** — production filename stem: `hamlet_edge`. Art status: **HAS EXAMPLE**.

## 2. Authoritative role

Basic Act-I Expansion; Settlement endpoint that starts or closes a Settlement. Starting bag: **3 copies**.

Source: [Complete Alpha Rules](../../../Carcassonne_Roguelite_Alpha_Complete_Rules.md), **RULE-CAT-012**; bag counts follow **RULE-BAG-002**. This brief defines art, not gameplay.

## 3. Edge occupancy

- North: **Settlement**
- East: **Field**
- South: **Field**
- West: **Field**

This is the production orientation, cross-checked against the existing Homestead content definition; the catalogue defines the topology, not a new fixed play orientation. Rotate the whole tile in 90-degree steps during play; do not mirror it.

## 4. Internal feature relationships

One Settlement component occupies north and ends internally; other sides remain Field.

## 5. Visual communication goals

A modest district spans the full north edge, then closes inland with a legible boundary; restrained buildings and dusty roofs. Follow the [master art recipe](../../specs/master_tile_art_spec.md): parchment first, fine sepia ink second, restrained color wash third. No scenic painting or 3D rendering.

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

North Settlement example; the short decorative gate approach is not a Road edge. Example orientation/width is subordinate to this brief and the alignment spec; “approved reference” does not mean final production art.

## 9. Forbidden mistakes

Do not draw a centered village blob with Field gaps at north corners. Do not add a Road socket or imply Settlement on the other sides. Do not copy texture borders, off-center sockets or topology defects from a reference. Never let scenery imply additional feature exits.
