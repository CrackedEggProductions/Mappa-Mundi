# Mappa Mundi — master tile art production spec

Revision 1 • 2026-09-24 • Local art direction, not a gameplay specification.

## Authority and reference priority

Use [Complete Alpha Rules](../../Carcassonne_Roguelite_Alpha_Complete_Rules.md)
for the roster, edges and internal relationships; the
[Implementation Specification](../../Carcassonne_Roguelite_Implementation_Specification.md)
for runtime/presentation boundaries; [Visual Design v0.2](../../Mappa_Mundi_Visual_Design_Specification_v0.2.md)
for presentation. [Tile Design](../../Carcassonne_Roguelite_Tile_Design_Specification.md)
is supplemental historical context only. Its older starter roster is superseded.

Use the relevant [production anchor](../references/production_anchors/) first,
then approved local mechanical references, approved local style references,
canonical geometry templates, and optional external conceptual references. Inspect
the images themselves. Production anchors preserve the parchment, ink and miniature
map language; they are **APPROVED PRODUCTION ANCHOR — NOT FINAL**. Read each
limitation in [the inventory](../TILE_ART_STATUS.md). This visual-reference order
never overrides canonical geometry: masks and briefs remain mechanical constraints.
Road artwork uses the relevant Road examples as its primary illustration references.

External inspiration is secondary. Carcassonne may inform topology, edge
conventions and historical comparison, never the target aesthetic; do not copy
official artwork. Match the local examples whenever outside inspiration differs.
No external images were needed for this setup.

## Style identity

**Parchment first, ink second, color third.** The dominant impression is an old
hand-drawn fantasy map or antique cartographic board. Preserve the examples'
sepia outlines, small grass tufts, restrained tree symbols and spare open space.
The result should feel like one manuscript map, not an illustrated diorama.

Use controlled, lightly whimsical drawing. Add enough detail to identify a
feature, then stop. Keep miniature buildings and trees legible at board scale.
The examples' near-monochrome treatment is a strong anchor; the requested tint
pass should be lighter than a painted landscape, with parchment visible below it.

## Color wash recipe

| Feature | Treatment |
|---|---|
| Background | Warm cream/bone parchment; low-contrast fibers and uneven age |
| Field / grassland | Faint desaturated light green wash, mostly open parchment |
| Forest | Deeper muted dark green wash beneath sepia canopy outlines |
| River | Faint desaturated light blue wash bounded by clear ink banks |
| Road | Soft tan wash or near-parchment fill between narrow ink margins |
| Settlement | Muted white/plaster and sparse terracotta or dusty clay roof accents |

Keep saturation low and washes translucent. Match perceived color across the
whole set, not one attractive standalone tile. The source visual spec's pigment
swatches are guidance, not opaque fill colors. This production pass follows Ro's
light-green Field and light-blue River direction. Ink remains the primary
structure in grayscale; color reinforces meaning without carrying it alone.

## Line and surface language

Use brown/dark sepia cartographic line work: fine outlines, modest pressure
variation and restrained hatching. The visual spec's approximate 1024-pixel
weights (6–8 structural, 3–4 secondary, 1.5–2 fine) are starting guides; preserve
the local examples' finesse and test reduced views before increasing detail.
No painterly brush-heavy scene rendering, 3D lighting, toy icons or photorealism.

Parchment is foundational. Existing baked parchment and mild aged borders are
acceptable in reference previews. For eventual board exports, avoid a dark frame
around every square: the board should read as continuous parchment. Keep texture
subtle enough that it does not obscure sockets, corners or internal connections.
Do not repeat the examples' strongest perimeter staining across a tiled board.

## Geometry before ornament

Read the [edge alignment spec](tile_edge_alignment_spec.md) and the exact
[tile brief](../briefs/tiles/) before drawing. Build the feature silhouette first,
then ink, then a light wash, then optional detail. Every side has one edge type.
Road and River cross the edge midpoint; Forest and Settlement fill the entire
specified edge corner-to-corner. Adjacent same-feature edges share a continuous
corner mass. Opposite connected edges must visibly connect through the interior.

Use one global Road width and one global River width. Do not inherit inconsistent
socket widths or off-center exits from an otherwise approved style anchor.
Do not add a watercourse, path, gate approach or tree cluster that implies an
extra mechanical exit or unlisted same-tile access. Feature art communicates
the brief; art and scene nodes never define gameplay topology.

## Production recipe and reusable prompt block

1. Load this document, the alignment spec, the tile brief and actual local images.
2. State the four edges and each internal connection in the generation request.
3. Attach the local style anchors and the relevant mechanical references. Explicitly
   state which aspects to borrow and which documented defects to correct.
4. Request one square candidate in the brief's production orientation, with no
   text, labels, border frame, perspective tilt or extra exits.
5. Save the untouched candidate and its request/reference record. Review geometry
   before spending another pass on ornament or tint.

Suggested shared prompt language:

> Mappa Mundi antique parchment map tile. Follow the attached local references:
> fine dark-sepia cartographic ink, restrained handmade detail, open parchment
> and faint desaturated watercolor washes. Parchment first, ink second, color
> third. Match the supplied four-edge map and internal connections exactly.
> Center Road sockets at 10% tile width and River sockets at 20%. Forest and
> Settlement occupy their full assigned edges and connect through shared corners
> where specified. Keep mechanical boundaries clear and interiors uncluttered.

Append the specific brief; this block alone is not a sufficient tile prompt.
If a generator cannot enforce boundaries exactly, keep its output a candidate
and correct/validate the geometry before approval. Do not quietly weaken the spec.

## Negative style rules

- No bright, lush, full-color Carcassonne-style scenic painting or generic fantasy landscape.
- No glossy highlights, heavy atmospheric shading, 3D bevels or raised card shadows.
- No dense clutter, large scenic focal point or decorative text that hides topology.
- No ambiguous edge occupancy, off-center socket or per-tile width variation.
- No isolated edge bumps where a continuous corner region is intended.
- No decorative roads, rivers, walls or forest clumps that suggest extra exits.
- No opaque color fields that bury the parchment or drift away from the approved examples.

## Delivery and review

Use a square lossless PNG candidate, retaining its original resolution. Current
references are 1254×1254; the alignment spec uses normalized coordinates, so no
reference resizing is needed. Trial 01 adopts **1254×1254 as the production master**,
matching native image-generation output. Any later runtime export size is a separate
derivative decision. Keep export sizes consistent and use the same socket
rasterization convention; see [template/tool instructions](../tools/README.md).

Keep base geography, later Development overlays and Transformation history
visually separable in future layered masters. This task prepares the 22 base
briefs only; it does not flatten future overlays into base art or add runtime code.

Review at full size and at 128/256-pixel tile previews, then in seam pairs and a
small map patch. Save findings using [the review template](../reviews/tile_review_template.md).
Approval must cover both style and mechanics. A style match alone is not a final.

## Geometry-wave production update

Relevant [production anchors](../references/production_anchors/) now lead visual reference priority,
followed by approved local mechanical references, approved local style references,
canonical geometry templates and optional external conceptual inspiration.
Canonical masks still determine geometry; reference priority never overrides legality.
Generate illustration material, preserve the raw source, then apply deterministic
compositing and validate the saved candidate. A generated image alone is not a
mechanically accepted output. No asset is FINAL without explicit human approval.

Hard 1254px binary sockets use nearest-even width: Road 126 pixels (564..689),
River 250 pixels (502..751); inclusive center 626.5, continuous center 627.
These are symmetric rasterizations of the unchanged 10%/20% design widths.
