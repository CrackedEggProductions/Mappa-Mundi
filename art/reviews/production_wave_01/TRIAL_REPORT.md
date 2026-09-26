# Production wave01 — hybrid candidates for human review

2026-09-24. Exactly eight designs × two candidates = **16 native1254×1254 PNGs**.
Every new output is **CANDIDATE — AWAITING HUMAN REVIEW**. No final approval.

## Git migration and baseline

PR#4 merged normally as **3ffc899689c3b9f497725a552696df8cd68348a6**. Approved
Phase6 commit db2527c17bf9b5d2324afcb97e76fbcaad9fe37c is an ancestor of main.
Merged baseline: **569 passed,0 failed;133 GDScript files parsed without diagnostics**.
All496 preexisting art/example files were hashed before and after both branch
switches and remained intact. No destructive commands, squash or history rewrite.

alpha-art was created from that healthy main and published. Existing art was
committed/pushed separately from gameplay:

- **5b1127d930baa452be693bbd5523bfbc254fc839** — art pipeline baseline.
- **7eed88fb38d966cb6764af1980bdd1819ffe63f0** — approved geometry anchors.
- **becb2958b8118ddd3528cb663a33ab967bda7442** — hybrid tooling/templates/tests.

Final assets/docs checkpoint is the commit containing this report; see git log
on alpha-art and the final delivery report. PR#4 received only its authorized merge.
No gameplay implementation changed on alpha-art. Phase7 remains unstarted.

## Production anchors

Five unchanged copies are **APPROVED PRODUCTION ANCHOR — NOT FINAL**:

- [Forest Bend](../../references/production_anchors/forest_bend_anchor.png)
- [Settlement Corner](../../references/production_anchors/settlement_corner_anchor.png)
- [Forest Edge](../../references/production_anchors/forest_edge_anchor.png)
- [Forest Belt](../../references/production_anchors/forest_belt_anchor.png)
- [Road Junction](../../references/production_anchors/road_junction_anchor.png)

The final three were explicitly human-approved for this wave. Their original
geometry-wave v02 files remain unchanged. Settlement Throughway geo_v02 remains
**REVISION SOURCE — NOT APPROVED**. No new wave01 candidate became an anchor.

## Production method

Canonical briefs/RULE-CAT-014..021 determine edge assignments, feature identities
and same-tile relations. Initial deterministic masks preceded all generation.
Sixteen built-in image-generation calls supplied organic source material using
direct local anchors plus topology guides. [Requests](requests/), immutable
[sources](sources/) and [generation manifest](generation_manifest.json) are retained.
No outside art or extra variants. First four calls overlapped a label-only guide
revision; both guide versions are retained, with identical mask geometry.

The illustration is not rescaled or globally warped. Manual source-region traces
preserve the generated organic interior; exact edge/socket interval endpoints ease
into that shape within a96px collar. Throughway reconstructs only north/south corner
fans around the traced city corridor. Thus topology stays fixed without forcing a
particular illustrated wall onto an unrelated internal curve.

Misowned pixels receive translated24px donor patches from the same traced feature.
Repeated donor use is penalized. Each output RGB pixel either retains its original
coordinate or comes from a recorded integer source coordinate. No interpolation,
scale, nonlinear image deformation, palette shift or external texture occurs.
This protects architectural proportions but does not guarantee invisible patch
joins. See per-candidate findings below.

Separate Settlement/Road/Forest/River masks retain independent identity. Only
Settlement Road Throughway permits interior street/Settlement membership overlap,
so a street does not mathematically split the city. This is not a dual edge.
Access/contact metadata is validated by actual mask adjacency or allowed interior
overlap. Road stays through-connected where required and terminates only on the
two Gate designs. Forest/Water touch is preserved; Woodland Road invents no access.

Road sockets remain **126px,564..689**; River **250px,502..751**; center626.5.
Full-edge shared corner ties belong to the area feature. Every other outer sample
matches the brief. Candidate-specific masks live in [masks](masks/); the initial
[templates](../../templates/production_wave_01/) remain reference geometry.

## Candidate-by-candidate assessment

All16 pass mask geometry and17 reconstruction/provenance checks each. This is
**known-label geometry**, not semantic recognition of arbitrary painted pixels.
A wrong manual trace could label ambiguous brushwork; human review must assess it.

| Candidate | Mechanical result | Visual/style assessment |
|---|---|---|
| [settlement_throughway_v01](../../generated/candidates/production_wave_01/settlement_throughway/settlement_throughway_v01.png) | PASS | Natural house proportions and coherent city connection; narrow central district and minor corner patching remain. |
| [settlement_throughway_v02](../../generated/candidates/production_wave_01/settlement_throughway/settlement_throughway_v02.png) | PASS | Best Throughway revision: coherent walls and believable houses, no whole-image deformation; inspect the narrow waist and repaired endpoint pixels. |
| [settlement_gate_v01](../../generated/candidates/production_wave_01/settlement_gate/settlement_gate_v01.png) | PASS | Gate approach reads clearly and palette matches; repeated masonry/foliage in the east collar and an abrupt urban edge remain. |
| [settlement_gate_v02](../../generated/candidates/production_wave_01/settlement_gate/settlement_gate_v02.png) | PASS | More consistent house scale and readable gate; east boundary still looks patched/cut. Better revision source, not a visual pass. |
| [riverside_hamlet_v01](../../generated/candidates/production_wave_01/riverside_hamlet/riverside_hamlet_v01.png) | PASS | Continuous pale-blue River and small homes, no Port machinery; bank collars show cut/repeated textures and tree-heavy north can read as Forest. |
| [riverside_hamlet_v02](../../generated/candidates/production_wave_01/riverside_hamlet/riverside_hamlet_v02.png) | PASS | Good waterside village/continuous River, restrained color; wider water and abrupt edge repair remain, with too much tree dominance for unequivocal Settlement ownership. |
| [woodland_road_v01](../../generated/candidates/production_wave_01/woodland_road/woodland_road_v01.png) | PASS | Dense connected woodland and continuous separate Road, native tree proportions; small socket/corner patch discontinuities. |
| [woodland_road_v02](../../generated/candidates/production_wave_01/woodland_road/woodland_road_v02.png) | PASS | Strongest woodland/road balance, restrained olive and ochre; clear continuous route and intact trees. Minor collars and legacy-reference seam differences remain. |
| [woodland_river_v01](../../generated/candidates/production_wave_01/woodland_river/woodland_river_v01.png) | PASS | Forest meets an unmistakable River, no blocked channel; south socket repair forms a visible jog and clipped bank detail. |
| [woodland_river_v02](../../generated/candidates/production_wave_01/woodland_river/woodland_river_v02.png) | PASS | Better continuous bank/woodland contact and native trees; south collar still needs close review for texture/line discontinuity. |
| [settlement_corner_gate_v01](../../generated/candidates/production_wave_01/settlement_corner_gate/settlement_corner_gate_v01.png) | PASS | Clear single gate approach, continuous corner city and believable architecture; east/south corner fill and socket patching remain. |
| [settlement_corner_gate_v02](../../generated/candidates/production_wave_01/settlement_corner_gate/settlement_corner_gate_v02.png) | PASS | Good city scale and pale stone palette; south Road correction is more conspicuous and lower east city texture needs retouch. |
| [settlement_road_bend_v01](../../generated/candidates/production_wave_01/settlement_road_bend/settlement_road_bend_v01.png) | PASS | Road stays continuous west-to-south beside an access gate; natural buildings. Gate-foot trace refined; collar and lower-east patches remain. |
| [settlement_road_bend_v02](../../generated/candidates/production_wave_01/settlement_road_bend/settlement_road_bend_v02.png) | PASS | Clear through-bend plus urban access, intact buildings, restrained color; better central join. Small south/east repair artifacts persist. |
| [settlement_road_throughway_v01](../../generated/candidates/production_wave_01/settlement_road_throughway/settlement_road_throughway_v01.png) | PASS | Road is visibly traceable across city and buildings retain scale; north/south corner fill repeats/cuts motifs and urban continuity can read as two districts. |
| [settlement_road_throughway_v02](../../generated/candidates/production_wave_01/settlement_road_throughway/settlement_road_throughway_v02.png) | PASS | Continuous Road and coherent urban style; top/bottom repairs are more obvious, with repeated/cut edge buildings. Needs local reconstruction before recommendation. |

Parchment and sepia remain dominant. Roof and water tints are low-saturation;
water reads slightly more strongly than older monochrome references. No opaque
fantasy painting. No stretched houses or globally distorted tree crowns were
introduced. Remaining defects include clipped local details, repeated texture,
abrupt collars and source-to-reference tone/socket differences.

## Recommendations

- **Settlement Throughway: v02**. This is a review choice, not approval.
- **Settlement Gate: neither**. This is a review choice, not approval.
- **Riverside Hamlet: neither**. This is a review choice, not approval.
- **Woodland Road: v02**. This is a review choice, not approval.
- **Woodland River: v02**. This is a review choice, not approval.
- **Settlement Corner Gate: v01**. This is a review choice, not approval.
- **Settlement Road Bend: v02**. This is a review choice, not approval.
- **Settlement Road Throughway: neither**. This is a review choice, not approval.

Throughway revision is a measurable improvement:99.78%/99.66% original source
pixels retained, and every relocated pixel uses translation only. It still has a
narrow city waist and small endpoint repairs. The result does not prove a universal
artifact-free hybrid compositor. The final visual verdict is revise82/100; the
user-capped wave stops here for review rather than generating additional attempts.

## Review materials and checks

- **Settlement Throughway**: [comparison](settlement_throughway_comparison.png), [native seams](seams/settlement_throughway/), [v01 debug](debug/settlement_throughway_v01.png), [v02 debug](debug/settlement_throughway_v02.png).
- **Settlement Gate**: [comparison](settlement_gate_comparison.png), [native seams](seams/settlement_gate/), [v01 debug](debug/settlement_gate_v01.png), [v02 debug](debug/settlement_gate_v02.png).
- **Riverside Hamlet**: [comparison](riverside_hamlet_comparison.png), [native seams](seams/riverside_hamlet/), [v01 debug](debug/riverside_hamlet_v01.png), [v02 debug](debug/riverside_hamlet_v02.png).
- **Woodland Road**: [comparison](woodland_road_comparison.png), [native seams](seams/woodland_road/), [v01 debug](debug/woodland_road_v01.png), [v02 debug](debug/woodland_road_v02.png).
- **Woodland River**: [comparison](woodland_river_comparison.png), [native seams](seams/woodland_river/), [v01 debug](debug/woodland_river_v01.png), [v02 debug](debug/woodland_river_v02.png).
- **Settlement Corner Gate**: [comparison](settlement_corner_gate_comparison.png), [native seams](seams/settlement_corner_gate/), [v01 debug](debug/settlement_corner_gate_v01.png), [v02 debug](debug/settlement_corner_gate_v02.png).
- **Settlement Road Bend**: [comparison](settlement_road_bend_comparison.png), [native seams](seams/settlement_road_bend/), [v01 debug](debug/settlement_road_bend_v01.png), [v02 debug](debug/settlement_road_bend_v02.png).
- **Settlement Road Throughway**: [comparison](settlement_road_throughway_comparison.png), [native seams](seams/settlement_road_throughway/), [v01 debug](debug/settlement_road_throughway_v01.png), [v02 debug](debug/settlement_road_throughway_v02.png).

Comparisons contain anchors/mechanical references, canonical guide, actual variant
masks, both candidates and seam previews, with labels outside art. Native seams
use exact1254px tiles and quarter-turn transposes. Road End is never used in these
reviews. Older Straight/Bending Road and River references remain unchanged and
are not retrospectively certified to the new sockets; visible mismatch is evidence
for later work, not grounds to modify them in this task.

- **144 art-tool tests passed,0 failed**, including all85 previous tests.
- All16 candidates pass17 reconstruction checks, saved masks/provenance and hashes.
- All16 pass their24/36/37 topology checks (design-dependent), including exact
  edges, one connected component per feature, contacts and equivalent rotations.
- All candidates/masks tested at0°,90°,180°,270° without interpolation.
- Native seam and final preservation evidence is recorded in [verification](verification.md).

An initial Gate composition produced obvious repeated fragments. It was repaired
in place with timestamped backups after switching to source-aware interior contours.
One Road Bend was stopped before writing because its gate trace lacked contact;
refining the gate-foot annotation restored required adjacency. Neither issue was
hidden by weakening validation. The earlier broad patch attempt is documented in
iteration_01_visual_verdict.json and candidate_preview_01.jpg.

Safe reproduction/verification:

```bash
python3 -B -W error -m unittest discover -s art/tools -p 'test_*.py'
python3 -B art/tools/production_wave_compositor.py --verify art/reviews/production_wave_01/compositions/*.json
```

Saved source PNGs and calibrations make composition deterministic; fresh image-model
calls are not deterministic. Writers refuse existing outputs; explicit --rebuild
backs up candidates, masks and records before replacing them. Python caches,
regenerable .import metadata and timestamped backup copies remain ignored/local.
Valuable source images, candidates, templates and all review sheets are committed.

## Remaining alpha-art roster

The22 base designs now have: **5 approved non-final production anchors**, **8 designs
with this wave's candidates**, and **9 designs still outside production approval**:
Founding Tile, Open Fields, River End, River Run, River Bend, Road End, Straight Road,
Bending Road and Hamlet Edge. Most of those have older examples, not approved final
exports. Founding remains ungenerated; Road End identity remains unresolved and
unchanged. Every design still needs final shipping approval. No Development,
Transformation, extra roster design or batch finalization was attempted.
