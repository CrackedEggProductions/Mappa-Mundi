# Trial 01 — Settlement Corner and corrected Forest Bend

2026-09-24. **Six candidates delivered; none mechanically accepted.** All remain
CANDIDATE — AWAITING HUMAN REVIEW. Nothing was promoted to approved production art.

Start with the [Settlement comparison](settlement_corner_comparison.png) and
[Forest comparison](forest_bend_comparison.png). Each includes local anchors and
all three candidates, with labels outside unmodified image pixels.

## Production setup

Built-in image generation was available and accepted direct local reference paths.
All 15 approved style images and relevant mechanical copies were inspected. No
external artwork was used. Templates are review diagrams, never substitute tile art.

Both canonical briefs specify a single northeast component: North/East Settlement
for Settlement Corner, North/East Forest for Forest Bend; South/West Field. No
Road or River exists on either design. The inner division broadly runs NW to SE.

The production master is **1254×1254**, matching the supplied references. The first
request asked for 1024×1024 but returned native 1254×1254. That result was preserved
and the templates rebuilt at native size; the initial 1024 set remains archived.
No source reference or candidate was resized. Road width is 125.4 pixels (10%),
River width 250.8 pixels (20%), both centered at 627; SVG/JSON retain exact fractional
coordinates and PNG masks encode symmetric fractional coverage. Socket checks are
not applicable to these two generated designs.

Use the [prompt template](../../specs/image_generation_prompt_template.md),
[edge grammar](../../templates/edge_grammar.json) and [tool instructions](../../tools/README.md).
The tools rotate by exact quarter turns and create gapless native-pixel composites.
They verify declared layout compatibility, not semantic correctness of artwork.

## Exact generation references

Every request attached the NE ownership guide first, as geometry rather than style.
Settlement v01 used the now-archived 1024 guide; the other five used the 1254 guide.

Settlement Corner attached these approved style files, in order after the guide:

- [ref_03_hamlet_edge.png](../../references/approved_style/ref_03_hamlet_edge.png): masonry, roofs, sepia ink.
- [ref_04_open_fields.png](../../references/approved_style/ref_04_open_fields.png): parchment and sparse Field marks.
- [ref_07_forest_bend.png](../../references/approved_style/ref_07_forest_bend.png): secondary corner/style context; its edge defects were explicitly prohibited.

Forest Bend attached:

- [ref_07_forest_bend.png](../../references/approved_style/ref_07_forest_bend.png): existing relevant example and tree vocabulary, not an exact geometry target.
- [ref_06_forest_edge.png](../../references/approved_style/ref_06_forest_edge.png): woodland ink detail.
- [ref_04_open_fields.png](../../references/approved_style/ref_04_open_fields.png): open Field vocabulary and parchment.

All exact prompts are in `requests/`. The [generation manifest](generation_manifest.json)
records their hashes, attachment hashes, output hashes and original tool paths.
Model version and seed were not exposed; neither is invented. The recipe is reusable,
but image generation is not claimed to reproduce identical pixels.

## Candidate assessment

Style and mechanics were reviewed independently, including a second visual review.
Style PASS below is a provisional assistant assessment, not human approval.

| Candidate | Style | Mechanics |
|---|---|---|
| [settlement_corner_v01](../../generated/candidates/settlement_corner/settlement_corner_v01.png) | PASS: Fine sepia map ink, restrained dusty roofs and sparse Field marks; strongest Settlement style starting point. | FAIL: Settlement wall reaches West below NW and ends on East above SE, leaving a Field gap on the required Settlement edge. |
| [settlement_corner_v02](../../generated/candidates/settlement_corner/settlement_corner_v02.png) | PASS: Close parchment and ink match; roof and Field tint are almost monochrome. | FAIL: Settlement wall reaches West below NW and ends on East above SE, leaving a Field gap on the required Settlement edge. |
| [settlement_corner_v03](../../generated/candidates/settlement_corner/settlement_corner_v03.png) | PASS: Compatible parchment with denser hatching and faint uneven Field tint. | FAIL: Settlement wall reaches West below NW and ends on East above SE, leaving a Field gap on the required Settlement edge. |
| [forest_bend_v01](../../generated/candidates/forest_bend/forest_bend_v01.png) | PASS: Fine mixed-tree ink and transparent muted olive; strongest Forest style starting point. | FAIL: Forest forms one NE mass, but NW and SE transition endpoints leave Field wedges/fringes along required Forest edges. |
| [forest_bend_v02](../../generated/candidates/forest_bend/forest_bend_v02.png) | PASS: Compatible old-map treatment, but the densest and darkest tree hatching of this set. | FAIL: Forest forms one NE mass, but NW and SE transition endpoints leave Field wedges/fringes along required Forest edges. |
| [forest_bend_v03](../../generated/candidates/forest_bend/forest_bend_v03.png) | PASS: Compatible mixed woodland ink, pale olive wash and visible paper texture. | FAIL: Forest forms one NE mass, but NW and SE transition endpoints leave Field wedges/fringes along required Forest edges. |

All six show one internally connected NE area rather than separate edge bumps.
None has an apparent false Road/River exit. These successes do not compensate for
missing full-edge coverage. Settlement walls reach the West edge below NW and leave
a Field gap near the lower East edge. Forest candidates improve the overall corner
mass but retain Field wedges/fringes at the transition endpoints.

The central area joins read continuously, but transition points step at seams.
Aged borders also produce visible tile divisions. Seam compatibility therefore
remains unproven for production. Full-resolution files are supplied for human
inspection; these are visual findings, not automated feature segmentation results.

Watercolor stayed restrained: mostly sepia and parchment, transparent olive/Field
tint and very mild dusty roof accents. Settlement tint is especially understated.
No candidate became a lush or opaque full-color scene.

**Recommendation:** v01 in each family is the strongest style starting point. No
candidate is recommended as a mechanically ready production asset. No art-direction
ambiguity was found; exact geometry is clear, and the generator failed to enforce it.

## Seam review files

Each row links to native 2508×2508 area/Field sheets and a 3762×3762 mixed sheet.
Matching rotated edge assignments are recorded in the adjacent seam JSON manifests.

| Candidate | Area-to-area, 2×2 | Field-to-Field, 2×2 | Mixed, 3×3 |
|---|---|---|---|
| settlement_corner_v01 | [Area](settlement_corner/settlement_corner_v01_central_area_2x2.png) | [Field](settlement_corner/settlement_corner_v01_central_field_2x2.png) | [Mixed](settlement_corner/settlement_corner_v01_alternating_3x3.png) |
| settlement_corner_v02 | [Area](settlement_corner/settlement_corner_v02_central_area_2x2.png) | [Field](settlement_corner/settlement_corner_v02_central_field_2x2.png) | [Mixed](settlement_corner/settlement_corner_v02_alternating_3x3.png) |
| settlement_corner_v03 | [Area](settlement_corner/settlement_corner_v03_central_area_2x2.png) | [Field](settlement_corner/settlement_corner_v03_central_field_2x2.png) | [Mixed](settlement_corner/settlement_corner_v03_alternating_3x3.png) |
| forest_bend_v01 | [Area](forest_bend/forest_bend_v01_central_area_2x2.png) | [Field](forest_bend/forest_bend_v01_central_field_2x2.png) | [Mixed](forest_bend/forest_bend_v01_alternating_3x3.png) |
| forest_bend_v02 | [Area](forest_bend/forest_bend_v02_central_area_2x2.png) | [Field](forest_bend/forest_bend_v02_central_field_2x2.png) | [Mixed](forest_bend/forest_bend_v02_alternating_3x3.png) |
| forest_bend_v03 | [Area](forest_bend/forest_bend_v03_central_area_2x2.png) | [Field](forest_bend/forest_bend_v03_central_field_2x2.png) | [Mixed](forest_bend/forest_bend_v03_alternating_3x3.png) |

## Iterations and stopping point

Exactly six generation calls produced the six requested versioned files. Later
numbered variants strengthened the corner-endpoint instructions and emphasized
rendering the geometry reference directly. Those attempts did not resolve the
mechanical failure. No extra replacement generations, procedural placeholder tiles,
post-generation geometry edits or unrequested roster designs were produced.

The first 1024 request returning 1254 was handled by preserving native pixels.
A large multi-image inspection exceeded tool output limits; smaller inspection
calls succeeded. A read command initially used the workspace parent directory;
it was rerun with the explicit project directory. Neither issue changed assets.

See [verification evidence](verification.md). Branch remains `phase-6`; all art
files remain local and uncommitted. No gameplay/source specification changes,
branch operations, PR edits or production promotions were made.

**Next action:** human visual review of these two comparison sheets before any
further generation or art-branch decision. The rest of the roster is paused.
