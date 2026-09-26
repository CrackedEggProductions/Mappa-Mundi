# Geometry wave — eight candidates awaiting human review

2026-09-24. Art-only trial at **1254 × 1254**. Exactly two candidates each for Forest
Edge, Forest Belt, Settlement Throughway and Road Junction. No other design produced.
Every new candidate is **CANDIDATE — AWAITING HUMAN REVIEW**.

## Result

The reusable mechanical families pass exact ownership, connectivity and rotation
checks. Visual production is **provisionally proven**, not approved: Road Junction
v02 is strongest; Forest v02s improve proportions but retain corner compression;
neither Settlement Throughway is production-ready because buildings still warp.
Human review comes next. No additional generation is authorized by this wave.

## Accepted production anchors

Copied byte-for-byte, leaving originals intact:

- [forest_bend_anchor.png](../../references/production_anchors/forest_bend_anchor.png), from Trial-03 forest_bend_hybrid_v02.
- [settlement_corner_anchor.png](../../references/production_anchors/settlement_corner_anchor.png), from Trial-03 settlement_corner_hybrid_v02.

Both are **APPROVED PRODUCTION ANCHOR — NOT FINAL**, explicitly authorized by the
human. [The manifest](../../references/production_anchors/manifest.json) records
source identities/hashes. No newly generated asset was promoted. No final exists.

## Sources and workflow

Image generation was available and used exactly eight times for illustration source
material. Saved [requests](requests/) contain each exact prompt and direct local
reference paths; [sources](sources/) preserve the returned native PNGs.

- Forest Edge/Belt: Forest Bend production anchor + corresponding hard geometry template.
- Settlement Throughway: Settlement Corner production anchor + opposite-region template.
- Road Junction: approved mechanical REF-05 Straight Road, approved style REF-11 Road Junction, and three-way mask.

No external references or copyrighted board-game material were used. No prior
candidate/reference was overwritten. Existing Road/Field references also appear
unchanged in diagnostic seams: REF-05 Straight Road, REF-09 Bending Road, REF-01
probable Road End, REF-04 Open Fields. REF-01's identity remains provisional.

Masks preceded generation. The model supplied illustration, not exact edge
placement. Saved manual [calibrations](calibrations/) identify source treelines,
city walls and Road ports. Deterministic transport produces the corrected outputs.
Region boundaries preserve a 30px strip per side where room permits; Road socket
corrections release over a 240px smooth collar into unchanged central artwork.
Opposite v02 waist parameters preserve more of the original motif scale.
No palette processing, external patches or texture stamping was applied.

## Coordinate and socket contract

Inclusive pixel centers are 0..1253. Center is **626.5**, equivalent to continuous
canvas center 627. Quarter-turn rotations are exact transposes. Full-edge shared
transition pixels belong to feature; adjoining Field edges exclude those isolated
tie pixels. No other wrong-edge contacts are allowed.

| Socket | Continuous target | Hard raster width | Inclusive bounds | Center |
|---|---|---|---|---|
| Road | 10%, 125.4px | **126px** | **564..689** | 626.5 |
| River | 20%, 250.8px | **250px** | **502..751** | 626.5 |

Nearest-even-width rounding preserves exact centering; halfway rounds upward.
The integer widths need not be exactly 2:1. River template is tested, no River art
was generated. [Machine-readable grammar](../../templates/edge_grammar.json) keeps
continuous guides and binary production policy separately.

## Candidate assessments

All rows have candidate status regardless of their visual recommendation.
The pass is a mask/provenance/reconstruction result, not semantic image recognition.

| Candidate | Mechanical validation | Visual assessment | Debug |
|---|---|---|---|
| [forest_edge_geo_v01](../../generated/candidates/geometry_wave/forest_edge/forest_edge_geo_v01.png) | PASS 23/23 | Strong parchment/ink match; compressed and smeared crowns at both upper corners, stretched Field marks. **NEEDS VISUAL REVISION** | [debug](debug/forest_edge_geo_v01.png) |
| [forest_edge_geo_v02](../../generated/candidates/geometry_wave/forest_edge/forest_edge_geo_v02.png) | PASS 23/23 | Better crown proportions and restrained wash; upper-corner compression remains. **NEEDS HUMAN REVIEW** | [debug](debug/forest_edge_geo_v02.png) |
| [forest_belt_geo_v01](../../generated/candidates/geometry_wave/forest_belt/forest_belt_geo_v01.png) | PASS 23/23 | Connected woodland, but widened crowns and sheared edge trees are conspicuous. **NEEDS VISUAL REVISION** | [debug](debug/forest_belt_geo_v01.png) |
| [forest_belt_geo_v02](../../generated/candidates/geometry_wave/forest_belt/forest_belt_geo_v02.png) | PASS 23/23 | Coherent woodland scale and muted tint; four-corner compression/shear remains. **NEEDS HUMAN REVIEW** | [debug](debug/forest_belt_geo_v02.png) |
| [settlement_throughway_geo_v01](../../generated/candidates/geometry_wave/settlement_throughway/settlement_throughway_geo_v01.png) | PASS 23/23 | City vocabulary matches; widened houses and warped towers/walls are conspicuous. **NEEDS VISUAL REVISION** | [debug](debug/settlement_throughway_geo_v01.png) |
| [settlement_throughway_geo_v02](../../generated/candidates/geometry_wave/settlement_throughway/settlement_throughway_geo_v02.png) | PASS 23/23 | Better central building scale; walls and buildings still bow/shear near all four corners. Neither variant is production-ready. **NEEDS VISUAL REVISION** | [debug](debug/settlement_throughway_geo_v02.png) |
| [road_junction_geo_v01](../../generated/candidates/geometry_wave/road_junction/road_junction_geo_v01.png) | PASS 23/23 | Sepia/ochre and open parchment match; localized collars avoid rectangular pasted strips. Older-reference seams still mismatch. **NEEDS HUMAN REVIEW** | [debug](debug/road_junction_geo_v01.png) |
| [road_junction_geo_v02](../../generated/candidates/geometry_wave/road_junction/road_junction_geo_v02.png) | PASS 23/23 | Most natural routing and restrained treatment; strongest review choice. Legacy socket/tone differences remain. **NEEDS HUMAN REVIEW** | [debug](debug/road_junction_geo_v02.png) |

The tint remains restrained, parchment/sepia dominant, without brighter fantasy
color. No obvious repeated clone stamps were introduced. Warp artifacts, however,
are real: compressed crowns, bowed city walls and stretched houses must not be
hidden by a geometry pass. Source-frontier traces still need human scrutiny.

## Geometry-family status

| Family | Mechanical status | Overall art status |
|---|---|---|
| Adjacent full edges | PROVEN by Trial 03 | Two human-approved production anchors; not final |
| Single full edge | PROVEN | PROVISIONALLY PROVEN / NEEDS HUMAN REVIEW; endpoint compression |
| Opposite full edges | PROVEN | Forest provisional; distortion-free city treatment UNSOLVED |
| Centered narrow socket | PROVEN at126px | Road candidates need human review |
| Three-way Road | PROVEN; one connected component, exactly N/E/S ports | PROVISIONALLY PROVEN; v02 recommended for review |
| Centered broad socket | PROVEN at250px mask level | Illustrated River unproven in this wave |

## Review outputs

| Design | Comparison sheet | Native seams |
|---|---|---|
| Forest Edge | [comparison](forest_edge_comparison.png) | [8 sheets](seams/forest_edge/) |
| Forest Belt | [comparison](forest_belt_comparison.png) | [8 sheets](seams/forest_belt/) |
| Settlement Throughway | [comparison](settlement_throughway_comparison.png) | [8 sheets](seams/settlement_throughway/) |
| Road Junction | [comparison](road_junction_comparison.png) | [10 sheets](seams/road_junction/) |

All **34 seam sheets** preserve original 1254px tile bytes, including exact
rotations, with no tile resampling. Region sheets include feature/Field pairs,
rotated strips and 2x2 combinations. Road sheets include Straight/Bend/End neighbors,
Field seam and three-branch 3x3. Transparent cells are outside-board space.
Legacy Road references are not 126px-certified: their mismatches are intentionally
visible and unchanged. This trial does not prove compatibility with their old art.

The four comparison sheets use labeled 420px review thumbnails, including both
variant masks, anchor/reference, candidates and representative v01 seam previews.
They are not native seam-validation assets. [Eight debug overlays](debug/) mark
outer boundaries, endpoints/socket positions and regions separately from art.
[24 mask PNGs](masks/) retain destination, source and actual sampled provenance.

## Tools and verification

New modules: production_geometry.py, geometry_wave_compositor.py,
geometry_wave_validator.py and geometry_wave_reviews.py under art/tools/.
Six reusable PNG+JSON template pairs are in
[production_geometry](../../templates/production_geometry/).
The [hybrid specification](../../specs/hybrid_tile_compositing_spec.md) explains
transport, source tracing, hard ownership, raster rounding and limitations.

- **85 art-tool tests passed, 0 failed**, including all previous 43 tests.
- All eight compositions pass **23/23 checks**; exact saved RGB reconstruction,
  hashes, source preservation, masks and provenance agree.
- All eight candidates/masks round-trip through **0°,90°,180°,270°** losslessly;
  rotated expected edge arrays, exact sockets and connectivity pass.
- Six reusable templates pass their validation; no River-width regression.
- Every seam placement passes native pixel checks. See [mechanical evidence](mechanical_validation.json)
  and individual seam manifests.
- Final parser, preservation, link and Git evidence is recorded in [verification](verification.md).

Commands safe to repeat:

```bash
python3 -B -W error -m unittest discover -s art/tools -p 'test_*.py'
python3 -B art/tools/geometry_wave_validator.py art/reviews/geometry_wave/*_composition.json
```

Generation/build commands refuse existing output names. Reproduce from saved
source PNGs/calibrations; the image model itself is not a deterministic rebuild.
The separate [visual verdict](final_visual_verdict.json) is revise (82/100), not
approval. The user-capped eight-candidate trial stops here rather than generating
additional attempts. Recommended next action: human review of v02s, with Settlement
v02 only a revision starting point, then decide whether localized object-aware
retouching is worth a separate task.

## Git and scope

Branch remains phase-6. Art and original examples remain local/untracked. Tracked
and staged gameplay files are clean. No commit, push, merge or PR #4 operation;
no gameplay edits, gameplay tests, Phase7, additional roster or final promotion.
