# Mappa Mundi — tile art status

Prepared 2026-09-24. Scope: local alpha base-tile art production setup.
No gameplay, source specification or existing example image was changed.

## Production wave01 — current review checkpoint

Work now lives on **alpha-art**, created after PR#4 merged normally into main at
3ffc899689c3b9f497725a552696df8cd68348a6. Merged baseline:569 tests,133 parsed scripts.
The previously local art framework is committed/pushed on its own branch.

Five assets are **APPROVED PRODUCTION ANCHOR — NOT FINAL**:
[Forest Bend](references/production_anchors/forest_bend_anchor.png),
[Settlement Corner](references/production_anchors/settlement_corner_anchor.png),
[Forest Edge](references/production_anchors/forest_edge_anchor.png),
[Forest Belt](references/production_anchors/forest_belt_anchor.png),
[Road Junction](references/production_anchors/road_junction_anchor.png).
Copies match original candidates byte-for-byte. This approval supersedes historical
pending statuses below for those five assets only. Settlement Throughway geo_v02
remains **REVISION SOURCE — NOT APPROVED**.

All16 new outputs below are **CANDIDATE — AWAITING HUMAN REVIEW**, never anchors or
finals. All pass deterministic masks/provenance; visual judgment is separate.

| Design | Candidate01 | Candidate02 | Mechanics | Recommendation |
|---|---|---|---|---|
| Settlement Throughway | [v01](generated/candidates/production_wave_01/settlement_throughway/settlement_throughway_v01.png) | [v02](generated/candidates/production_wave_01/settlement_throughway/settlement_throughway_v02.png) | Both PASS | v02 |
| Settlement Gate | [v01](generated/candidates/production_wave_01/settlement_gate/settlement_gate_v01.png) | [v02](generated/candidates/production_wave_01/settlement_gate/settlement_gate_v02.png) | Both PASS | neither |
| Riverside Hamlet | [v01](generated/candidates/production_wave_01/riverside_hamlet/riverside_hamlet_v01.png) | [v02](generated/candidates/production_wave_01/riverside_hamlet/riverside_hamlet_v02.png) | Both PASS | neither |
| Woodland Road | [v01](generated/candidates/production_wave_01/woodland_road/woodland_road_v01.png) | [v02](generated/candidates/production_wave_01/woodland_road/woodland_road_v02.png) | Both PASS | v02 |
| Woodland River | [v01](generated/candidates/production_wave_01/woodland_river/woodland_river_v01.png) | [v02](generated/candidates/production_wave_01/woodland_river/woodland_river_v02.png) | Both PASS | v02 |
| Settlement Corner Gate | [v01](generated/candidates/production_wave_01/settlement_corner_gate/settlement_corner_gate_v01.png) | [v02](generated/candidates/production_wave_01/settlement_corner_gate/settlement_corner_gate_v02.png) | Both PASS | v01 |
| Settlement Road Bend | [v01](generated/candidates/production_wave_01/settlement_road_bend/settlement_road_bend_v01.png) | [v02](generated/candidates/production_wave_01/settlement_road_bend/settlement_road_bend_v02.png) | Both PASS | v02 |
| Settlement Road Throughway | [v01](generated/candidates/production_wave_01/settlement_road_throughway/settlement_road_throughway_v01.png) | [v02](generated/candidates/production_wave_01/settlement_road_throughway/settlement_road_throughway_v02.png) | Both PASS | neither |

**144 art tests pass;16×17 reconstruction checks pass; all four rotations pass.**
94 native seam sheets,16 debug overlays and8 comparison sheets are linked in the
[wave report](reviews/production_wave_01/TRIAL_REPORT.md). Houses retain native
proportions; local collar repetition/cut details remain. Gate, Riverside Hamlet and
Settlement Road Throughway need further visual repair. No extra generation follows.

Mechanically proven geometry: single/corner/opposite regions, narrow/broad sockets,
hybrid combinations, separate component identities and explicit contacts. Visually
approved sources: only the five anchors above. Final assets: **none**.
Remaining9 designs outside current candidates/anchors: Founding Tile, Open Fields,
River End, River Run, River Bend, Road End, Straight Road, Bending Road, Hamlet Edge.
Older examples for most remain useful, not approved final exports. Founding is still
ungenerated; Road End identity remains unchanged/unresolved. All22 base designs
still require final shipping approval. Phase7 and gameplay implementation excluded.

## Current approval and reference priority — geometry wave

The human has approved these two assets as **APPROVED PRODUCTION ANCHOR — NOT FINAL**:

- [Forest Bend anchor](references/production_anchors/forest_bend_anchor.png), copied unchanged from Trial-03 hybrid v02.
- [Settlement Corner anchor](references/production_anchors/settlement_corner_anchor.png), copied unchanged from Trial-03 hybrid v02.

The original candidate files remain unchanged. Earlier trial reports record their
historical review status; this approval supersedes it for these two assets only.

| Category | Meaning |
|---|---|
| Style anchor | Approved visual language, not proof of exact mechanics |
| Mechanical reference | Useful topology reference; may need socket correction |
| Production anchor | Human-approved source for subsequent production; NOT FINAL |
| Final production asset | Requires explicit final approval; none currently exist |

Reference priority: relevant production anchor → approved local mechanical reference
→ approved local style reference → canonical geometry template → optional external
conceptual inspiration. This is visual-reference priority: canonical topology/masks
remain hard constraints even when a higher-priority reference has different geometry.
Road work uses Road references as its primary stylistic sources.

## Geometry wave — current review checkpoint

Exactly eight new 1254px candidates. **CANDIDATE — AWAITING HUMAN REVIEW** applies
to every link below. Eight mechanical reconstructions pass23/23; all four rotations
pass; 85 art-tool tests pass. The two accepted Trial-03 anchors above remain the
only production anchors. There are no final production assets.

| Design | v01 | v02 | Review recommendation |
|---|---|---|---|
| Forest Edge | [v01](generated/candidates/geometry_wave/forest_edge/forest_edge_geo_v01.png) | [v02](generated/candidates/geometry_wave/forest_edge/forest_edge_geo_v02.png) | v02 for human review; no promotion |
| Forest Belt | [v01](generated/candidates/geometry_wave/forest_belt/forest_belt_geo_v01.png) | [v02](generated/candidates/geometry_wave/forest_belt/forest_belt_geo_v02.png) | v02 for human review; no promotion |
| Settlement Throughway | [v01](generated/candidates/geometry_wave/settlement_throughway/settlement_throughway_geo_v01.png) | [v02](generated/candidates/geometry_wave/settlement_throughway/settlement_throughway_geo_v02.png) | v02 as revision starting point only; warped buildings remain |
| Road Junction | [v01](generated/candidates/geometry_wave/road_junction/road_junction_geo_v01.png) | [v02](generated/candidates/geometry_wave/road_junction/road_junction_geo_v02.png) | v02 for human review; no promotion |

Geometry: adjacent, single and opposite full-edge masks, narrow/broad sockets and
three-way Road are **PROVEN mathematically**. Overall single-edge/Forest-belt/Road
production is **PROVISIONALLY PROVEN / NEEDS HUMAN REVIEW**. Distortion-free city
corridor compositing remains **UNSOLVED**; both Throughway candidates need revision.
Illustrated River production was not attempted. Legacy Road sockets still mismatch.

[Geometry-wave report](reviews/geometry_wave/TRIAL_REPORT.md) contains per-candidate
style findings, 34 native seams, eight debug overlays and four comparison sheets.
[Hybrid method](specs/hybrid_tile_compositing_spec.md) preserves Trial-03 lessons and
adds these families. Older trial statuses below are historical; explicit anchor
approval above supersedes Trial03's pending status for the two v02 images only.

## Start here

- [Master art direction](specs/master_tile_art_spec.md)
- [Edge and topology alignment](specs/tile_edge_alignment_spec.md)
- [Canonical alpha roster and brief links](specs/alpha_tile_roster.md)
- [Trial 02 results and comparison sheets](reviews/trial_02/TRIAL_REPORT.md)
- [Trial 01 results and comparison sheets](reviews/trial_01/TRIAL_REPORT.md)
- [Repeatable generation prompt](specs/image_generation_prompt_template.md)
- [Geometry templates and seam tools](tools/README.md)
- [Review template](reviews/tile_review_template.md)
- [Reference provenance and SHA-256 manifest](references/reference_manifest.json)

## Directory contract

```text
art/
  .gdignore                       production sources stay outside Godot imports
  TILE_ART_STATUS.md               inventory and workflow entry point
  references/
    reference_manifest.json       original paths, copies, dimensions, hashes
    approved_style/               15 unchanged local examples
    approved_mechanical/          6 identical copies; scoped topology guidance
    needs_revision/               future revision work; no originals moved
    rejected/                     future rejected candidates, with reasons
  specs/
    master_tile_art_spec.md
    tile_edge_alignment_spec.md
    alpha_tile_roster.md
    image_generation_prompt_template.md
  templates/                      1254px masks, JSON/SVG geometry, seam diagrams
  tools/                          template builder and native-pixel review tools
  briefs/tiles/                   22 individual base-design briefs
  generated/
    candidates/                   Trials 01–03 + eight geometry-wave candidates
    approved/                     future explicitly approved finals
  reviews/                        review template and production records
  exports/                        later engine-ready derivatives
```

Empty destinations contain `.gitkeep` files so version control can preserve the
structure. Trials 01–03 contain fourteen candidates; this wave adds eight. No final asset has been approved.
Future engine integration should copy only reviewed exports to an appropriate
runtime asset location; this setup does not change runtime assets or imports.

## Existing reference inventory

All 15 originals remain in `assets/Example Tiles/` with their original names.
All are 1254×1254 PNGs. Copies have stable descriptive names below; their full
original filenames and SHA-256 checksums are in the manifest. Filename identities
are visual interpretations, not recovered original generation prompts.

**APPROVED STYLE ANCHOR** means useful for the requested old-map look, even if
not mechanically ready. **APPROVED STYLE + MECHANICAL ANCHOR** also identifies a
useful topology example; it does not certify exact sockets or seamless exports.
Production readiness is a separate column. No supplied image is rejected for style.

| ID / copied image | Original timestamp (filename) | Likely identity and visible N/E/S/W | Reference status / strongest use | Production notes |
|---|---|---|---|---|
| [REF-01 road_end](references/approved_style/ref_01_road_end.png) | Sep 10 2026, 12_54_57 AM | Probable Road End: Field / Field / Road / Field; interior rounded terminus | APPROVED STYLE ANCHOR — sparse parchment and endpoint drawing | NEEDS REVIEW: dry-looking track suggests Road, but reeds/rounded pool shape could suggest River. Do not use as mechanical authority. |
| [REF-02 woodland_road_study](references/approved_style/ref_02_woodland_road_study.png) | Sep 14 2026, 05_48_37 PM | Forest / Road / Forest / Road; separated top/bottom tree bands and E–W road | APPROVED STYLE ANCHOR — woodland/road ink vocabulary | UNKNOWN / UNCLASSIFIED as an alpha design. Canonical Woodland Road uses adjacent pairs, not opposite pairs. Preserve as style context. |
| [REF-03 hamlet_edge](references/approved_style/ref_03_hamlet_edge.png) | Sep 16 2026, 08_35_27 AM | Settlement / Field / Field / Field; north built strip with gate | APPROVED STYLE + MECHANICAL ANCHOR — built edge and open Field | HAS EXAMPLE. Short gate approach does not reach an edge; this is not Settlement Gate. Useful full-edge urban treatment. |
| [REF-04 open_fields](references/approved_style/ref_04_open_fields.png) | Sep 9 2026, 03_39_03 PM | Field / Field / Field / Field | APPROVED STYLE + MECHANICAL ANCHOR — negative space, grass marks, parchment | HAS EXAMPLE. Baseline for open boundaries and the set's restrained detail. |
| [REF-05 straight_road](references/approved_style/ref_05_straight_road.png) | Sep 9 2026, 03_41_05 PM | Field / Road / Field / Road; one connected E–W road | APPROVED STYLE + MECHANICAL ANCHOR — clear opposite road connection | HAS EXAMPLE. Normalize socket width/center before production; rotate for brief orientation. |
| [REF-06 forest_edge](references/approved_style/ref_06_forest_edge.png) | Sep 9 2026, 03_43_54 PM | Forest / Field / Field / Field; rounded northern tree stub | APPROVED STYLE ANCHOR — tree/ink language | NEEDS REVISION: north woodland must reach both corners instead of narrowing into an edge bump. |
| [REF-07 forest_bend](references/approved_style/ref_07_forest_bend.png) | Sep 9 2026, 03_46_41 PM | Forest / Forest / Field / Field; joined NE woodland | APPROVED STYLE ANCHOR — recognizable continuous corner | NEEDS REVISION: keep the corner connection and extend the complete N/E spans through NW/SE endpoints. |
| [REF-08 four_way_road_study](references/approved_style/ref_08_four_way_road_study.png) | Sep 9 2026, 03_48_57 PM | Road / Road / Road / Road; four-way junction | APPROVED STYLE ANCHOR — road margin/rut language only | Outside starting alpha; four-way crossroads are deferred. Do not substitute for three-exit Road Junction. |
| [REF-09 bending_road](references/approved_style/ref_09_bending_road.png) | Sep 9 2026, 03_51_22 PM | Road / Field / Field / Road; one N–W bend | APPROVED STYLE + MECHANICAL ANCHOR — connected adjacent Road pair | HAS EXAMPLE. Standardize socket width/center and rotate for the brief. |
| [REF-10 river_run](references/approved_style/ref_10_river_run.png) | Sep 9 2026, 03_54_05 PM | River / Field / River / Field; continuous meander | APPROVED STYLE ANCHOR — water ripples, reeds and bank treatment | HAS EXAMPLE. Strong River reading; existing bank widths and endpoint alignment need the shared template. |
| [REF-11 road_junction](references/approved_style/ref_11_road_junction.png) | Sep 9 2026, 03_56_30 PM | Field / Road / Road / Road; connected three-arm junction | APPROVED STYLE ANCHOR — clear three-exit intent | NEEDS REVISION: E/W exits sit noticeably above their midpoints; recenter, then rotate to the brief. |
| [REF-12 bridge_study](references/approved_style/ref_12_bridge_study.png) | Sep 9 2026, 03_57_39 PM | River / Road / River / Road; perpendicular bridge | APPROVED STYLE ANCHOR — bridge structure and preserved water | Later Act-III Bridge composition study only; not one of the 21 starting Expansion designs or an overlay-ready final. |
| [REF-13 river_bend](references/approved_style/ref_13_river_bend.png) | Sep 9 2026, 07_17_38 PM | River / River / Field / Field; connected N–E curve | APPROVED STYLE + MECHANICAL ANCHOR — clear River bend | HAS EXAMPLE. Use topology and water vocabulary; enforce the new common socket width at export. |
| [REF-14 forest_belt_study](references/approved_style/ref_14_forest_belt_study.png) | Sep 9 2026, 07_31_38 PM | Forest / Field / Forest / Field is the likely intent; woods visibly disconnected | APPROVED STYLE ANCHOR — dense woodland texture | NEEDS REVISION: likely Forest Belt, but the Field strip must not sever its one N–S Forest component. |
| [REF-15 river_end](references/approved_style/ref_15_river_end.png) | Sep 9 2026, 07_34_37 PM | River / Field / Field / Field; interior pool | APPROVED STYLE + MECHANICAL ANCHOR — one water exit and interior termination | HAS EXAMPLE. Same canonical design serves River source and terminus. |

REF-03, 04, 05, 09, 13 and 15 also have identical copies in
`references/approved_mechanical/`. All others remain available as style references.
Revision notes above are instructions for future derived candidates; reference
masters stay unchanged, including the studies with topology mismatches.

## Alpha asset coverage

The canonical scope is **22 designs: Founding Tile + 21 Expansion designs**.
The latter make the **55-copy Homestead bag**. Founding is a separate setup tile.
There are **12 plausible design matches** among the examples: 7 HAS EXAMPLE,
4 NEEDS REVISION and 1 NEEDS REVIEW. This is not a count of production-ready art.

- HAS EXAMPLE: Open Fields, Straight Road, Bending Road, River End, River Run,
  River Bend, Hamlet Edge.
- NEEDS REVISION: Forest Edge, Forest Bend, Forest Belt, Road Junction.
- NEEDS REVIEW: Road End. The Forest Belt name is also inferred, but its required
  connection correction is clear if it is used for that canonical design.
- NEEDS ART: Founding Tile, Settlement Corner, Settlement Throughway, Settlement
  Gate, Riverside Hamlet, Woodland Road, Woodland River, Settlement Corner Gate,
  Settlement Road Bend, Settlement Road Throughway.

No separate River Source or Road Start brief is needed. Later Developments,
Upgrades and Transformations are outside this base-roster asset checklist.

## Recommended repeatable generation workflow

1. Read `specs/master_tile_art_spec.md`.
2. Read `specs/tile_edge_alignment_spec.md`.
3. Read the chosen brief in `briefs/tiles/`; copy its exact four-edge intent.
4. Inspect **all actual images** in `references/approved_style/` and their caveats.
5. Inspect the relevant `approved_mechanical/` copies; these do not override rules.
6. Attach/reference those same local files in the image-generation request. Preserve
   the brief revision, chosen reference IDs, exact prompt, tool/model and settings
   in `reviews/<tile_stem>_vNN_request.md`. Record seed only if the tool supplies one.
7. Save a new image under `generated/candidates/<tile_stem>/<tile_stem>_vNN.png`.
   Use snake_case brief stems: `forest_edge_v01.png`, `forest_edge_v02.png`,
   `settlement_gate_v01.png`. Never reuse a version or overwrite an approved reference.
8. Review topology, numerical sockets, corner continuity, style and wash in that
   order. Test seam pairs, rotations, grayscale and reduced-size map patches.
   Record results in `reviews/<tile_stem>_vNN_review.md` using the template.
9. With explicit final-art acceptance, copy the accepted version to
   `generated/approved/`, preserving the candidate and review trail. Record the
   approver/date, checksum and selected version here. Only then make export derivatives.
10. Put engine-ready derivatives in `exports/` with their source/review linkage.
    Keep original base art and any later overlay masters separate; do not integrate
    with gameplay as part of an image-generation task.

The initial setup generated no art. Trial 01 is now delivered below. Stop for human
visual review; do not batch the roster or promote a candidate automatically.

## Trial 01 — delivered for human visual review

Updated 2026-09-24. Built-in image generation used direct local image references.
Production master: **1254×1254**, matching all originals and returned candidates.
Six calls produced exactly three versions of each requested design. No resampling.

All six have compatible parchment/sepia style and restrained watercolor, but
**none passes exact edge ownership**: the NW/SE transition endpoints miss the
canonical corners. Continuous NE regions alone are insufficient.

| Candidate | Status | Style assessment | Mechanics |
|---|---|---|---|
| [forest_bend_v01](generated/candidates/forest_bend/forest_bend_v01.png) | CANDIDATE — AWAITING HUMAN REVIEW | Fine mixed-tree ink and transparent muted olive; strongest Forest style starting point. | FAIL: corner endpoints / full-edge coverage |
| [forest_bend_v02](generated/candidates/forest_bend/forest_bend_v02.png) | CANDIDATE — AWAITING HUMAN REVIEW | Compatible old-map treatment, but the densest and darkest tree hatching of this set. | FAIL: corner endpoints / full-edge coverage |
| [forest_bend_v03](generated/candidates/forest_bend/forest_bend_v03.png) | CANDIDATE — AWAITING HUMAN REVIEW | Compatible mixed woodland ink, pale olive wash and visible paper texture. | FAIL: corner endpoints / full-edge coverage |
| [settlement_corner_v01](generated/candidates/settlement_corner/settlement_corner_v01.png) | CANDIDATE — AWAITING HUMAN REVIEW | Fine sepia map ink, restrained dusty roofs and sparse Field marks; strongest Settlement style starting point. | FAIL: corner endpoints / full-edge coverage |
| [settlement_corner_v02](generated/candidates/settlement_corner/settlement_corner_v02.png) | CANDIDATE — AWAITING HUMAN REVIEW | Close parchment and ink match; roof and Field tint are almost monochrome. | FAIL: corner endpoints / full-edge coverage |
| [settlement_corner_v03](generated/candidates/settlement_corner/settlement_corner_v03.png) | CANDIDATE — AWAITING HUMAN REVIEW | Compatible parchment with denser hatching and faint uneven Field tint. | FAIL: corner endpoints / full-edge coverage |

V01 in each family is recommended as a style starting point only. Neither is a
production recommendation. See [full review and all seam links](reviews/trial_01/TRIAL_REPORT.md),
[Settlement comparison](reviews/trial_01/settlement_corner_comparison.png) and
[Forest comparison](reviews/trial_01/forest_bend_comparison.png). Eighteen native-pixel
seam sheets cover area seams, Field seams and rotated 3×3 layouts.

The request JSONs and generation manifest preserve exact prompts, references and
hashes. Automated tooling checks preserve pixels and validate declared layouts;
they do not certify the generated artwork. Art remains local and uncommitted on
phase-6. No gameplay, authoritative source specs or original references changed.

## Trial 02 — four candidates awaiting human review

2026-09-24. Generated exactly two Settlement Corner and two Forest Bend candidates,
using labeled corner guides, clean underlays, prior v01 style targets and direct
approved reference attachments. Native 1254×1254; originals untouched.

**Exact corner ownership remains unsolved.** All four preserve the successful
parchment/sepia style and restrained tint, but retain NW/SE endpoint defects.

| Candidate | Status | Mechanical result |
|---|---|---|
| [settlement_corner_wave2_v01](generated/candidates/settlement_corner/settlement_corner_wave2_v01.png) | CANDIDATE — AWAITING HUMAN REVIEW | FAIL: exact transition endpoints / lower-East fringe |
| [settlement_corner_wave2_v02](generated/candidates/settlement_corner/settlement_corner_wave2_v02.png) | CANDIDATE — AWAITING HUMAN REVIEW | FAIL: exact transition endpoints / lower-East fringe |
| [forest_bend_wave2_v01](generated/candidates/forest_bend/forest_bend_wave2_v01.png) | CANDIDATE — AWAITING HUMAN REVIEW | FAIL: exact transition endpoints / lower-East fringe |
| [forest_bend_wave2_v02](generated/candidates/forest_bend/forest_bend_wave2_v02.png) | CANDIDATE — AWAITING HUMAN REVIEW | FAIL: exact transition endpoints / lower-East fringe |

Best wave-2 attempts: Settlement v02 and Forest v01, neither approved.
See [Trial 02 report](reviews/trial_02/TRIAL_REPORT.md) for exact references, geometry
guides, automated edge/corner results, 12 seam sheets and both comparison sheets.
The luminance proxy flags the final East-edge bin in every candidate; it cannot
certify feature semantics. Fourteen art-tool tests pass. Stop for human review.
Art remains uncommitted on phase-6; no gameplay tracked files or PR #4 changed.

## Trial 03 — deterministic hybrid prototype

2026-09-24: Four 1254px corrected candidates are **CANDIDATE — AWAITING HUMAN REVIEW**.
The [hybrid compositing spec](specs/hybrid_tile_compositing_spec.md) documents seeded
organic boundaries, hard mask ownership, source-frontier transport and pixel reproduction.
See the [Trial 03 report](reviews/trial_03/TRIAL_REPORT.md),
[Settlement comparison](reviews/trial_03/settlement_corner_hybrid_comparison.png) and
[Forest comparison](reviews/trial_03/forest_bend_hybrid_comparison.png).
All four pass exact mask/provenance checks; visible warping and texture seams still
need human review. v02 of each is recommended for comparison, not approval.
No image generation, final promotion, gameplay change or Git commit occurred.

- [settlement_corner_hybrid_v01](generated/candidates/hybrid_corrected/settlement_corner/settlement_corner_hybrid_v01.png) — **CANDIDATE — AWAITING HUMAN REVIEW**

- [settlement_corner_hybrid_v02](generated/candidates/hybrid_corrected/settlement_corner/settlement_corner_hybrid_v02.png) — **CANDIDATE — AWAITING HUMAN REVIEW**

- [forest_bend_hybrid_v01](generated/candidates/hybrid_corrected/forest_bend/forest_bend_hybrid_v01.png) — **CANDIDATE — AWAITING HUMAN REVIEW**

- [forest_bend_hybrid_v02](generated/candidates/hybrid_corrected/forest_bend/forest_bend_hybrid_v02.png) — **CANDIDATE — AWAITING HUMAN REVIEW**
