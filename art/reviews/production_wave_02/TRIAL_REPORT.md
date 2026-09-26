# Production Wave 02 — focused repair and promotion

Date: 2026-09-24. Branch: alpha-art. **CANDIDATE — AWAITING HUMAN REVIEW** applies to all six new outputs.

Five human-approved Wave 01 winners were copied, byte-identically, to production anchors. Exactly six new sources and six corrected candidates were produced. No prior candidate or reference image changed. No final assets were created.

## Decision

**v04 is the preferred comparison candidate for all three designs.** It is not a promotion recommendation while the strict visible-repair gate remains unresolved. v03 has more noticeable socket curvature. Both versions retain visible local correction, so the correction-cost records deliberately say **REJECT**, even though every numerical limit and mechanical check passes. Neither version receives production clearance. Human review may accept the minor v04 curvature or request another focused repair.

Architecture is substantially cleaner than Wave 01: no conspicuous transported towers, repeated pasted blocks or clipped city banks were found. Riverside planting is restrained and buildings read clearly. Sepia ink, parchment and translucent tint remain consistent. No correction recolors the source.

## Approved copies — NOT FINAL

- [settlement_throughway_anchor.png](../../references/production_anchors/settlement_throughway_anchor.png) ← art/generated/candidates/production_wave_01/settlement_throughway/settlement_throughway_v02.png
- [woodland_road_anchor.png](../../references/production_anchors/woodland_road_anchor.png) ← art/generated/candidates/production_wave_01/woodland_road/woodland_road_v02.png
- [woodland_river_anchor.png](../../references/production_anchors/woodland_river_anchor.png) ← art/generated/candidates/production_wave_01/woodland_river/woodland_river_v02.png
- [settlement_corner_gate_anchor.png](../../references/production_anchors/settlement_corner_gate_anchor.png) ← art/generated/candidates/production_wave_01/settlement_corner_gate/settlement_corner_gate_v01.png
- [settlement_road_bend_anchor.png](../../references/production_anchors/settlement_road_bend_anchor.png) ← art/generated/candidates/production_wave_01/settlement_road_bend/settlement_road_bend_v02.png

## Candidate results

Transport is the percentage of output pixels sampled from a different source coordinate. It is not a percentage of moved buildings. Every candidate has zero moved Settlement-mask pixels. No recognizable-object transport or conspicuous repeated motif was found; no source was rejected for excessive correction before final composition.

| Candidate | Transported area | Maximum travel | Mechanics / rotations | Visual assessment |
|---|---:|---:|---|---|
| [settlement_gate_v03](../../generated/candidates/production_wave_02/settlement_gate/settlement_gate_v03.png) | 1.546% | 33px | PASS / all four | The wall and gate read coherently, with believable native houses and restrained stone/terracotta. The east approach visibly dips into its final socket; no pasted masonry is apparent. Visible mild bend in the eastmost Road collar. |
| [settlement_gate_v04](../../generated/candidates/production_wave_02/settlement_gate/settlement_gate_v04.png) | 2.022% | 40px | PASS / all four | The curved approach terminates clearly at one gate, with intact roof/tower proportions and open Field. Stronger composition than v03; slight east socket curvature remains. Small course change at the east edge, not a conspicuous cloned patch. |
| [riverside_hamlet_v03](../../generated/candidates/production_wave_02/riverside_hamlet/riverside_hamlet_v03.png) | 6.580% | 50px | PASS / all four | The continuous River and modest building frontage are much clearer than Wave 01. Sparse planting replaces the previous woodland dominance. Both outer bank collars visibly curve toward the sockets. Bank bends at both edges are noticeable; no clipped buildings or copied bank blocks are apparent at normal review scale. |
| [riverside_hamlet_v04](../../generated/candidates/production_wave_02/riverside_hamlet/riverside_hamlet_v04.png) | 6.474% | 41px | PASS / all four | The clean waterside frontage, restrained trees and continuous pale-blue River communicate the intended hamlet. Buildings retain natural proportions. The bank approach is smoother than v03. Gentle outer-bank convergence remains visible on comparison; it reads as continuous bank curvature. |
| [settlement_road_throughway_v03](../../generated/candidates/production_wave_02/settlement_road_throughway/settlement_road_throughway_v03.png) | 3.694% | 38px | PASS / all four | One coherent walled district surrounds the readable cross-town Road. Roofs and walls no longer show obvious pasted/clipped repeats. The west Road lip has a noticeable curved flare. The west socket collar forms a visible shallow flare; no architectural relocation is apparent. |
| [settlement_road_throughway_v04](../../generated/candidates/production_wave_02/settlement_road_throughway/settlement_road_throughway_v04.png) | 3.716% | 30px | PASS / all four | Best continuous-city reading of the pair: natural buildings frame a clear through-road with access. Mild edge curvature remains, without the repeated towers/clipped corner blocks of Wave 01. Small curvature adjustment at Road endpoints remains visible, especially east, but lacks a rectangular patch boundary. |

All six have visible-repair=true, major-objects-moved=false, repeated-motifs=false and source-rejected-before-composition=false. Source suitability initially passed scene review; the later visibility rejection is retained separately. See [cost records](correction_cost/), [assessments](assessments/) and the [independent visual review](independent_visual_review.json). Coordinate reuse is 4.5–9.7%; this local integer sampling statistic is not repeated architectural imagery.

## Exact direct generation references

New image generation was used for **each** candidate. v03/v04 use the same reference set per design. The guide is a composition constraint; local art anchors govern style. No external imagery was used. Exact prompts and tool reference paths are saved in [requests](requests/).

### Settlement Gate

- art/templates/production_wave_01/settlement_gate/guide.png
- art/references/production_anchors/settlement_corner_anchor.png
- art/references/production_anchors/settlement_throughway_anchor.png
- art/references/production_anchors/settlement_corner_gate_anchor.png
- art/references/approved_style/ref_05_straight_road.png

### Riverside Hamlet

- art/templates/production_wave_01/riverside_hamlet/guide.png
- art/references/production_anchors/settlement_throughway_anchor.png
- art/references/approved_style/ref_10_river_run.png
- art/references/approved_style/ref_13_river_bend.png
- art/references/approved_style/ref_04_open_fields.png

### Settlement Road Throughway

- art/templates/production_wave_01/settlement_road_throughway/guide.png
- art/references/production_anchors/settlement_throughway_anchor.png
- art/references/production_anchors/settlement_corner_anchor.png
- art/references/production_anchors/settlement_road_bend_anchor.png
- art/references/production_anchors/road_junction_anchor.png

The generation tool accepts at most five image references. Initial Riverside/Throughway requests exceeded that cap and were rejected without producing images; redundant references were removed. The six successful outputs were preserved at native 1254×1254 in [sources](sources/), with hashes in [generation_manifest.json](generation_manifest.json).

## Source-first correction method

Read the exact tile brief, select a source with an already-correct city footprint, trace its ground regions/banks, then correct only Road/River sockets. A 128px edge collar eases into unchanged interior content. An 18px bank strip retains local scale where possible; surrounding quiet texture absorbs the adjustment. Integer donor coordinates preserve original RGB values. Settlement pixels cannot move. No source patches from other assets were pasted into the candidates.

An early isolated-stamp experiment reused too many donor pixels and was discarded before candidate production. A 96px collar left visible curvature; a 128px collar reduced it without moving architecture. Throughway v03 initially failed one-pixel traced edge ownership; inspection supported a trace correction at the northeast corner. The rejected diagnostic is preserved in [rejections](rejections/). This was an annotation correction, not a relaxed edge rule or regenerated source.

Method limits were fixed before evaluation: ≤8% transported area, ≤80px p95 travel, ≤120px maximum travel, ≤25% reused transported donor coordinates. All six pass these limits. Any visible repair still prevents strict visual acceptance; saving a rejected review candidate does not authorize its promotion.

## Geometry and verification

- Resolution: 1254×1254 throughout. Road:126px, indices564–689. River:250px, indices502–751. Both centered at626.5. Existing mechanical standards and topology code are unchanged.
- Gate: N Settlement, E Road, S/W Field; separate features with Road–Settlement access and one terminating Road.
- Riverside: N Settlement, E/W River, S Field; one continuous River, separate Settlement and explicit contact.
- Road Throughway: N/S Settlement and E/W Road; both connected, distinct identities and explicit access. Interior shared street space uses the existing layered topology interpretation.
- All six pass reconstruction, known donor membership, stored masks/provenance, exact socket/edge/connectivity and topology checks. All 0°/90°/180°/270° rotations pass without interpolation.
- **208 art-tooling tests passed, 0 failed; 34 Python files parsed.** Existing144 tests remain passing. No dependencies added. Gameplay tests were not run because gameplay was unchanged.
- **44 native seam sheets,120 exact placements,84 declared matching seams** passed independent hash/pixel audit. Six debug overlays and three labeled comparison sheets were produced.
- All prior image hashes match the prewave inventory. All ten anchors match their source copies. New sources retain original generation hashes. Final assessment rebuild left all candidate hashes unchanged.

Commands and per-check evidence: [verification.json](verification.json).

    python3 -B -W error -m unittest discover -s art/tools -p 'test_*.py'
    python3 -B art/tools/repair_wave_compositor.py --verify art/reviews/production_wave_02/compositions/*.json

## Review files

- [settlement_gate comparison](settlement_gate_comparison.png); [native seams](seams/settlement_gate/)
  - [v03 debug](debug/settlement_gate_v03.png), [repair zone](repair_zones/settlement_gate_v03.png), [composition](compositions/settlement_gate_v03.json)
  - [v04 debug](debug/settlement_gate_v04.png), [repair zone](repair_zones/settlement_gate_v04.png), [composition](compositions/settlement_gate_v04.json)
- [riverside_hamlet comparison](riverside_hamlet_comparison.png); [native seams](seams/riverside_hamlet/)
  - [v03 debug](debug/riverside_hamlet_v03.png), [repair zone](repair_zones/riverside_hamlet_v03.png), [composition](compositions/riverside_hamlet_v03.json)
  - [v04 debug](debug/riverside_hamlet_v04.png), [repair zone](repair_zones/riverside_hamlet_v04.png), [composition](compositions/riverside_hamlet_v04.json)
- [settlement_road_throughway comparison](settlement_road_throughway_comparison.png); [native seams](seams/settlement_road_throughway/)
  - [v03 debug](debug/settlement_road_throughway_v03.png), [repair zone](repair_zones/settlement_road_throughway_v03.png), [composition](compositions/settlement_road_throughway_v03.json)
  - [v04 debug](debug/settlement_road_throughway_v04.png), [repair zone](repair_zones/settlement_road_throughway_v04.png), [composition](compositions/settlement_road_throughway_v04.json)

Debug overlays show actual masks, sockets, contacts and magenta repair areas; they are separate from candidates. Labels sit outside comparison artwork. Seam assets retain native pixels; only comparison thumbnails are scaled.

## Limits and scope

Exact masks prove declared mechanics, not semantic classification of every ink stroke. Manual source traces require visual judgment. Slight edge course changes remain; existing unaltered Road/River references also differ in painted width and tone, so a lossless seam audit is not a claim that every visual seam is seamless. No claim of zero local resampling distortion is made for grass/ripples. The protected architecture retains native proportions.

New files: repair_wave_sampler.py, repair_wave_compositor.py, repair_wave_metrics.py, repair_wave_reviews.py and three test modules. Old pipeline modules were reused without edits. The hybrid specification now requires source suitability checks before substantial repair.

Git checkpoints: promotions6446766; tooling659742b; this report and all sources/assets/evidence form the final Wave02 commit. Git history records its full hash. Work remains on alpha-art; no merge, gameplay edit, PR change, Phase7, Founding generation or Road End identity decision occurred. Remaining nine designs were neither reviewed for promotion nor reclassified. Stop for human review.
