# Trial 03 — hybrid compositor prototype

2026-09-24. **Four CANDIDATE — AWAITING HUMAN REVIEW outputs.**
Deterministic boundary/mask/composition tooling is implemented and verified. Exact
raster ownership is solved under the documented transition-point convention.
Visible artwork still needs review: mask proof does not imply flawless semantic
edges or seamless parchment. No production asset is approved.

## Sources and method

Settlement source: [wave2 v02](../../generated/candidates/settlement_corner/settlement_corner_wave2_v02.png).
Forest source: [wave2 v01](../../generated/candidates/forest_bend/forest_bend_wave2_v01.png).
All 15 approved style references, six mechanical reference copies and ten earlier
candidates were inspected in the [source inventory](source_inventory_preview.png).
Only the two preferred sources supplied pixels. No extra patch assets, external
art or image generation was used. Palette/saturation adjustments: none.

The [permanent spec](../../specs/hybrid_tile_compositing_spec.md) describes inclusive
0..1253 coordinates, NW/SE feature ties, seeded monotone sine paths and transport.
v01 uses seed 31 / irregularity 0.025 / anchored Field. v02 uses seed 73 /
irregularity 0.015 / relaxed Field. Both preserve a configurable 60px frontier
strip instead of alpha-cutting buildings or crowns; outer ownership remains hard.

## Candidates and visual assessment

| Candidate | Geometry / reproduction | Visual assessment |
|---|---|---|
| [settlement_corner_hybrid_v01](../../generated/candidates/hybrid_corrected/settlement_corner/settlement_corner_hybrid_v01.png) | PASS, 20 checks | Faithful source palette/ink; southeast Field compression remains. |
| [settlement_corner_hybrid_v02](../../generated/candidates/hybrid_corrected/settlement_corner/settlement_corner_hybrid_v02.png) | PASS, 20 checks | Recommended prototype: less Field compression; some corner/motif warping remains. |
| [forest_bend_hybrid_v01](../../generated/candidates/hybrid_corrected/forest_bend/forest_bend_hybrid_v01.png) | PASS, 20 checks | Faithful source palette/ink; southeast Field compression remains. |
| [forest_bend_hybrid_v02](../../generated/candidates/hybrid_corrected/forest_bend/forest_bend_hybrid_v02.png) | PASS, 20 checks | Recommended prototype: less Field compression; some corner/motif warping remains. |

All four have mathematically exact region ownership. N/E are feature; S/W are
Field except their shared single transition pixels. The NE mass remains connected;
no Road/River or separate socket was added. This proves deterministic terrain labels
and their sampling provenance, not automatic recognition of every tree/stone pixel.
The manual source-frontier calibration remains a visual assumption.

No raw diagonal guillotine runs through the interiors. Remaining artifacts are
warp/shear in masonry, flattened foliage near NW, possible tiny source-fringe
ambiguity at transition pixels, and source-tone lines in seam composites. v02
reduces the obvious compressed Field decorations in v01. Inspect the
[corner-detail preview](corner_detail_preview.png) and native assets before approval.
Watercolor stays within the requested range because the original pixel palette
is reused without a saturation change. Both v02 recommendations are provisional.

## Review outputs

- [Settlement comparison](settlement_corner_hybrid_comparison.png)
- [Forest comparison](forest_bend_hybrid_comparison.png)
- [Debug overlays](debug/)
- [Native seam sheets](seams/)
- [Geometry masks](../../templates/hybrid_masks/)
- [Organic boundary paths and diagrams](../../templates/hybrid_boundaries/)
- [Validation summary](validation/summary.json)

Comparison panels are labeled 420px review previews; candidates and seam sheets
remain native. Each candidate has these exact review paths:

- settlement_corner_hybrid_v01: [debug](debug/settlement_corner_hybrid_v01_debug.png), [feature 2×2](seams/settlement_corner/settlement_corner_hybrid_v01_central_area_2x2.png), [Field 2×2](seams/settlement_corner/settlement_corner_hybrid_v01_central_field_2x2.png), [mixed 3×3](seams/settlement_corner/settlement_corner_hybrid_v01_alternating_3x3.png), [composition record](settlement_corner_hybrid_v01_composition.json).
- settlement_corner_hybrid_v02: [debug](debug/settlement_corner_hybrid_v02_debug.png), [feature 2×2](seams/settlement_corner/settlement_corner_hybrid_v02_central_area_2x2.png), [Field 2×2](seams/settlement_corner/settlement_corner_hybrid_v02_central_field_2x2.png), [mixed 3×3](seams/settlement_corner/settlement_corner_hybrid_v02_alternating_3x3.png), [composition record](settlement_corner_hybrid_v02_composition.json).
- forest_bend_hybrid_v01: [debug](debug/forest_bend_hybrid_v01_debug.png), [feature 2×2](seams/forest_bend/forest_bend_hybrid_v01_central_area_2x2.png), [Field 2×2](seams/forest_bend/forest_bend_hybrid_v01_central_field_2x2.png), [mixed 3×3](seams/forest_bend/forest_bend_hybrid_v01_alternating_3x3.png), [composition record](forest_bend_hybrid_v01_composition.json).
- forest_bend_hybrid_v02: [debug](debug/forest_bend_hybrid_v02_debug.png), [feature 2×2](seams/forest_bend/forest_bend_hybrid_v02_central_area_2x2.png), [Field 2×2](seams/forest_bend/forest_bend_hybrid_v02_central_field_2x2.png), [mixed 3×3](seams/forest_bend/forest_bend_hybrid_v02_alternating_3x3.png), [composition record](forest_bend_hybrid_v02_composition.json).

## Verification

Command: `python3 -B -W error -m unittest discover -s art/tools -p 'test_*.py' -v`
→ **Ran 43 tests; OK; exit 0** (14 existing + 29 new).
**14 Python files parsed** with Python AST; no syntax errors. No separate linter
was installed or run. All four native compositions passed **20 checks each**.
All **12 native seam sheets** passed full pixel comparison, including edge pixels.
Repeated in-memory reconstruction exactly matched candidate RGB bytes, source
coordinate hashes, masks and provenance. Corruption tests cover dishonest updated
hashes, altered masks/sources/provenance and one-pixel seam damage.

Prior-file preservation: 244 files unchanged; only TILE_ART_STATUS.md was
updated with a timestamped backup. Source PNGs and previous trials are intact.
No approved output was created. Gameplay tests were intentionally not run.

## Tools and limits

New tools: boundary_generator.py, mask_utils.py, hybrid_compositor.py,
seam_validator.py, build_hybrid_reviews.py, and two test modules under
art/tools/tests/. Existing seam utilities are reused unchanged. Pillow and NumPy
were already installed; no dependency installation occurred.

This prototype supports rotated corners. Other region shapes will need separate
masks/calibration; no other tile was produced. Column transport is not a semantic
segmentation or universal retouching tool. Geometry proof and aesthetic approval
remain separate.

## Git and stopping point

Branch `phase-6`; tracked and staged diffs empty. Art and assets/Example Tiles remain
untracked. No commit/push/branch/PR operation occurred; PR #4 was untouched.
Nothing was promoted to final. Phase 7 and batch production have not started.
Stop for human visual review of the two v02 candidates and their seams.
