# Mappa Mundi — tile edge alignment spec

Revision 1 • 2026-09-24 • Art-production geometry only.

Sources: [Complete Alpha Rules](../../Carcassonne_Roguelite_Alpha_Complete_Rules.md),
RULE-SETUP-001/002 and RULE-CAT-001–021; [Visual Design v0.2](../../Mappa_Mundi_Visual_Design_Specification_v0.2.md),
§0.1 and §5–12. Rules determine feature connectivity; this document standardizes
how that connectivity is drawn. It does not introduce new sockets or rules.

## Coordinate system and global sockets

Use a square 1000×1000 design-unit canvas. North is top, East right, South bottom,
West left; x increases right and y down. A pixel export scales these normalized
coordinates uniformly. Never stretch one axis or crop inside the tile boundary.

| Edge | Exact midpoint | Road opening endpoints | River opening endpoints |
|---|---|---|---|
| North | (500, 0) | (450, 0) to (550, 0) | (400, 0) to (600, 0) |
| East | (1000, 500) | (1000, 450) to (1000, 550) | (1000, 400) to (1000, 600) |
| South | (500, 1000) | (450, 1000) to (550, 1000) | (400, 1000) to (600, 1000) |
| West | (0, 500) | (0, 450) to (0, 550) | (0, 400) to (0, 600) |

**Production standard: Road = 100 units (10%); River = 200 units (20%).**
These fixed choices sit within the source visual spec's Road 8–11% and River
18–22% ranges. They are local art-production settings, not gameplay changes or
measurements claiming the references already comply. River is twice Road width.
Do not select a different value within the range per tile.

The opening is the feature ribbon between the centerlines of its two boundary
ink strokes; use matching stroke weights so the visible widths also match.
Maintain a perpendicular, parallel-sided approach for the final 50 units before
each boundary. Interior curvature can begin beyond that approach. Keep structural
detail quiet in the outer 120–150 units, as the visual spec recommends.

At raster export, use the same symmetric rounding and antialiasing convention
for all tiles. The mathematical center stays at 50%; a one-pixel rounding fringe
is not permission to shift the axis. Validate paired exports after resampling.

## Five edge types

| Type | Required treatment |
|---|---|
| Field | Open parchment/light Field wash; no structural exit |
| Road | One narrow centered ribbon, identical socket width on every Road tile |
| River | One wider centered ribbon, identical socket width on every River tile |
| Forest | Continuous occupied boundary over the entire side, corner to corner |
| Settlement | Continuous built area over the entire side, corner to corner |

One side has exactly one edge type. Field-looking space beside a centered Road
or River is background, not extra edge sockets. No dual Road/Forest edge is
created by drawing. For full-edge areas, canopy/building texture may vary, but
the underlying area/wash must reach the full boundary; no large parchment gaps
at edge ends. Interior area depth is flexible when connectivity remains clear.

## Corner and interior continuity

For adjacent Forest edges N+E, a single Forest mass spans the whole North and
East boundaries and fills their NE corner wedge; rotate this rule for other
pairs. Settlement corners follow the same rule with angular urban fabric.
Do not draw two rounded caps that barely touch, a pinched neck or isolated bumps.
Two matching neighboring area edges should make one woodland/city region,
not repeated circles, clovers or four lobes around seams.

Opposite same-feature edges must visibly connect through the tile when the brief
says they are one component. Forest Belt needs a continuous forest corridor
from N to S, not separate tree bands divided by an open cross-tile field strip.
Settlement Throughway likewise has a continuous built region across its axis.

When different area types meet at a corner (Founding's North Settlement and West
Forest), take their visible divider to that corner. Preserve both full edges
without blending the types or inventing an internal contact/access relationship.
At the single shared corner point, the divider is the convention; no extra socket.
Where a full area edge meets a Field side, end its boundary footprint at the
corner and taper inward, rather than suggesting another area exit along Field.

Keep the outer 70×70 corner areas quiet where no area feature mechanically
occupies them. Quiet corners never override required Forest/Settlement coverage.
Corner drawing does not grant diagonal gameplay adjacency.

## Road rules

- Center all exits and use the same tan wash, sepia margins and 100-unit socket.
- Straight Road connects its opposite sockets; a slight interior bow is fine.
- Bending Road visibly connects exactly its adjacent pair with a controlled curve.
- Road Junction has exactly three connected exits. The four-way example is style
  context only; four-way crossroads are outside the starting alpha roster.
- Road End closes inside the tile, with no accidental continuation into scenery.
- Use subtle ruts/earth to distinguish Road from water, never water ripples/reeds
  as its primary identifying marks. Do not widen a road to River width.

## River rules

- Center all exits and keep 200-unit sockets and blue wash consistent.
- Use clear banks and sparse flow/ripple marks; avoid a road-like dry track.
- Meander inside the tile without displacing exits or changing their edge type.
- River Bend uses adjacent exits; River Run uses opposite exits even if curved.
- River End has one edge and an interior source/terminus pool. Source and end
  share one canonical design; no separate River Source asset is required.
- Decorative water must not imply another River exit or contact.

## Settlement and Forest rules

Walls/buildings identify the full occupied Settlement side. Gates show only
the Road connections specified in the brief. A Hamlet Edge gate can have a short
decorative approach, but no path may reach a Field boundary. For Settlement Road
Throughway, show a continuing road through gates/urban space while retaining one
continuous Settlement region; these are distinct components with explicit access.

Forest canopy and wash form a continuous mass. Small individual trees should
support that silhouette, not make a required edge dissolve into uncertain foliage.
Road/Forest and River/Forest hybrids preserve both distinct components. Same-tile
contacts must follow the brief, not an attractive incidental overlap.

## Mechanical acceptance checklist

1. Compare N/E/S/W to the brief; count actual boundary exits before judging beauty.
2. Overlay midpoint and endpoint guides from the socket table on a review copy.
   Check the full edge, not only the image center; originals remain untouched.
3. Pair every Road/River exit with the matching straight reference geometry after
   rotation. Banks/margins should continue at identical positions and thickness.
4. Pair Forest and Settlement sides with full-edge counterparts. Check both ends
   and any four-tile corner; no white seam, cap bulge or false continuation.
5. Trace each connected feature through the interior. Confirm Road termination,
   throughways, distinct hybrid components and explicit contacts exactly.
6. Review all four rotations for ordinary tiles. Founding remains fixed at setup.
7. Review at 128/256-pixel scale and in grayscale: no false exits from texture,
   no Road/River confusion, no unreadable corner mass.
8. Record measured defects and status in the review. Generated approximation is
   not precision approval; repair geometry or regenerate before final acceptance.

No example has been certified against these exact numeric sockets yet. Mechanical
reference status identifies useful topology demonstrations, not final export quality.

## Geometry-wave hard raster policy — 1254px

The continuous Road/River design widths remain 10%/20% (125.4/250.8px).
Hard binary masks use the nearest **even** integer width to retain exact symmetry
around the center of an even-sized raster. Road is **126px**, inclusive indices
**564..689**; River is **250px**, inclusive indices **502..751**. Their midpoint is
626.5 in inclusive pixel-center coordinates, corresponding to continuous canvas
center 627. This is a single explicit raster rounding policy, not a new gameplay
width rule. Integer River width is not exactly twice integer Road width.

Use exact clockwise quarter-turn transposes. At full-region transition corners,
the shared tie pixel belongs to the feature; a neighboring Field edge excludes that
single transition point. All other Field-edge pixels remain Field. The binary
policy is recorded separately from older antialiased SVG coverage in
[edge_grammar.json](../templates/edge_grammar.json), and implemented/tested in
[production_geometry.py](../tools/production_geometry.py). Existing reference art
is not retrospectively certified to these sockets.
