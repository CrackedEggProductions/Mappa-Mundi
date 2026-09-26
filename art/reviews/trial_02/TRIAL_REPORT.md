# Trial 02 — fixed-corner generation experiment

2026-09-24. **Four candidates delivered; exact corner ownership is not solved.**
All are CANDIDATE — AWAITING HUMAN REVIEW. No final production asset was selected.

View the [Settlement comparison](settlement_corner_wave2_comparison.png) and
[Forest comparison](forest_bend_wave2_comparison.png). Both show approved references,
wave-1 v01, the hard geometry guide and both new candidates. Labels are outside
asset pixels; source images retain native resolution.

## Geometry controls and generation

The canonical briefs were re-read: North/East Settlement or Forest, South/West
Field, one connected northeast feature, fixed transition points NW and SE.
Outer geometry is rigid; the interior line may be organic. No Road/River exists.

Master resolution remains **1254×1254**, matching all references and all four
returned outputs. Sources and generated candidates were not resized or edited.

Created under `art/templates/geometry_guides/`:

- [Settlement labeled guide](../../templates/geometry_guides/settlement_corner_guide.png)
- [Settlement clean underlay](../../templates/geometry_guides/settlement_corner_underlay.png)
- [Forest labeled guide](../../templates/geometry_guides/forest_bend_guide.png)
- [Forest clean underlay](../../templates/geometry_guides/forest_bend_underlay.png)
- [Exact coordinate contract](../../templates/geometry_guides/wave2_geometry.json)

Created binary masks under `art/templates/control_masks/`:

- [Settlement NE mask](../../templates/control_masks/settlement_corner_ne_mask.png)
- [Forest NE mask](../../templates/control_masks/forest_bend_ne_mask.png)

The masks assign white to x >= y and black otherwise. Continuous corner coordinates
are (0,0) and (1254,1254); raster indices end at 1253. Diagonal tie pixels do not
create another edge exit. Labels, border and magenta divider belong only to guides.
The [guide builder](../../tools/build_wave2_guides.py) verifies full N/E ownership and
S/W exclusion, apart from the single transition points, and refuses overwrites.

Built-in image generation was available. All calls supplied direct image paths:
labeled guide first, clean underlay second, wave-1 v01 third as PRIMARY STYLE,
then two supporting approved examples. The tool accepts reference images but
exposes no dedicated mask-lock parameter. Therefore hard geometry was a stated
and illustrated requirement, not a guaranteed pixel-level constraint.

## Exact references used

Settlement, both versions:

1. `art/templates/geometry_guides/settlement_corner_guide.png`
2. `art/templates/geometry_guides/settlement_corner_underlay.png`
3. `art/generated/candidates/settlement_corner/settlement_corner_v01.png`
4. `art/references/approved_style/ref_03_hamlet_edge.png`
5. `art/references/approved_style/ref_04_open_fields.png`

Forest, both versions:

1. `art/templates/geometry_guides/forest_bend_guide.png`
2. `art/templates/geometry_guides/forest_bend_underlay.png`
3. `art/generated/candidates/forest_bend/forest_bend_v01.png`
4. `art/references/approved_style/ref_07_forest_bend.png`
5. `art/references/approved_style/ref_04_open_fields.png`

All 15 approved style images, all six mechanical copies, six wave-1 candidates and
both wave-1 comparison sheets were inspected. No web artwork was used. Exact
submitted prompts live in `requests/`; [generation manifest](generation_manifest.json)
retains input/output hashes. Model version and seed were not exposed.

## Candidate results

| Candidate | Style | Mechanical result | Proxy flags |
|---|---|---|---|
| [settlement_corner_wave2_v01](../../generated/candidates/settlement_corner/settlement_corner_wave2_v01.png) | Strong v01 style continuity; dusty roofs, warm masonry and more visible but restrained green Field wash. | FAIL: NW/SE endpoints; lower-East Field fringe | 7 / 132 |
| [settlement_corner_wave2_v02](../../generated/candidates/settlement_corner/settlement_corner_wave2_v02.png) | Compatible dense sepia buildings and muted terracotta; slightly smaller lower-East gap makes this the best Settlement wave-2 attempt. | FAIL: NW/SE endpoints; lower-East Field fringe | 13 / 132 |
| [forest_bend_wave2_v01](../../generated/candidates/forest_bend/forest_bend_wave2_v01.png) | Best Forest wave-2 balance: mixed tree texture, muted olive, visible parchment and controlled ink density. | FAIL: NW/SE endpoints; lower-East Field fringe | 3 / 132 |
| [forest_bend_wave2_v02](../../generated/candidates/forest_bend/forest_bend_wave2_v02.png) | Compatible woodland style with larger broadleaf crowns; no clear endpoint improvement over v01. | FAIL: NW/SE endpoints; lower-East Field fringe | 7 / 132 |

Every candidate has one continuous northeast region and no apparent false Road,
River, socket or disconnected bump. The shared NE corner reads as occupied.
South and West otherwise read as Field, but NW endpoint precision is not certified.
The lower East edge still becomes Field before reaching SE. Exact full-edge
ownership consequently fails in all four; seam intersections show stepped endpoints.

**Best wave-2 attempts:** Settlement v02 (smaller lower-East gap), Forest v01
(best style/geometry balance). These recommendations are not approvals. Tint remains
within range: faint green Field, muted olive woodland, warm pale stone and dusty
terracotta, with visible parchment beneath dominant sepia ink. No style reset needed.

## Automated checks and their limits

[check_corner_geometry.py](../../tools/check_corner_geometry.py) samples 32 bins
per edge plus four corner patches, using the exact binary mask for expected
occupancy. Feature/Field interior luminance calibrates a diagnostic proxy. JSON
records sample coordinates, means, texture statistics and anomaly thresholds;
separate annotated review images locate warnings. See [method](../../tools/CORNER_CHECKS.md).

All four flag `East_31`, the final East-edge bin, matching the visually observed
SE fringe. Other warnings may reflect tree ink, wall hatching or aged borders.
Counts are not a ranking: a higher count need not mean worse mechanical geometry.
The same diagnostic gives 33 flags for original Settlement v01 and four for
original Forest v01; these baseline outputs are preserved beside the wave-2 checks.
No statistical result is called an exact semantic pass. Endpoint precision,
false exits and feature identity were also assessed visually, with independent
review agreeing that all four fail. Tiny fringes can escape the proxy.

## Seam and diagnostic outputs

Twelve gapless seam PNGs preserve native pixels: 2×2 sheets are 2508×2508;
3×3 sheets are 3762×3762. Exact clockwise quarter-turns retain source pixels.

| Candidate | Feature seams | Field seams | Mixed seams | Automated check |
|---|---|---|---|---|
| settlement_corner_wave2_v01 | [2×2](settlement_corner/settlement_corner_wave2_v01_central_area_2x2.png) | [2×2](settlement_corner/settlement_corner_wave2_v01_central_field_2x2.png) | [3×3](settlement_corner/settlement_corner_wave2_v01_alternating_3x3.png) | [JSON](settlement_corner/settlement_corner_wave2_v01_geometry.json), [annotated](settlement_corner/settlement_corner_wave2_v01_geometry_review.png) |
| settlement_corner_wave2_v02 | [2×2](settlement_corner/settlement_corner_wave2_v02_central_area_2x2.png) | [2×2](settlement_corner/settlement_corner_wave2_v02_central_field_2x2.png) | [3×3](settlement_corner/settlement_corner_wave2_v02_alternating_3x3.png) | [JSON](settlement_corner/settlement_corner_wave2_v02_geometry.json), [annotated](settlement_corner/settlement_corner_wave2_v02_geometry_review.png) |
| forest_bend_wave2_v01 | [2×2](forest_bend/forest_bend_wave2_v01_central_area_2x2.png) | [2×2](forest_bend/forest_bend_wave2_v01_central_field_2x2.png) | [3×3](forest_bend/forest_bend_wave2_v01_alternating_3x3.png) | [JSON](forest_bend/forest_bend_wave2_v01_geometry.json), [annotated](forest_bend/forest_bend_wave2_v01_geometry_review.png) |
| forest_bend_wave2_v02 | [2×2](forest_bend/forest_bend_wave2_v02_central_area_2x2.png) | [2×2](forest_bend/forest_bend_wave2_v02_central_field_2x2.png) | [3×3](forest_bend/forest_bend_wave2_v02_alternating_3x3.png) | [JSON](forest_bend/forest_bend_wave2_v02_geometry.json), [annotated](forest_bend/forest_bend_wave2_v02_geometry_review.png) |

## Stopping point

Exactly four generation calls were made. Each second version sharpened endpoint
instructions after inspecting the first; neither solved exact geometry. No extra
variants, geometry postprocessing, first-wave overwrites or remaining-roster work.

[Verification evidence](verification.md) covers 14 passing art-tool tests,
source preservation and native-pixel review composition. Gameplay tests were not
run because no gameplay files changed. Branch remains `phase-6`; art stays local
and uncommitted. No PR #4, branch, merge, gameplay or final-approval action occurred.

The requirements are clear; the limitation is reference-guided image generation's
failure to lock exact endpoints. Stop for human review of the two comparison sheets.
