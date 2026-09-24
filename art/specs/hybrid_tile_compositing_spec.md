# Mappa Mundi — deterministic hybrid tile compositing

Trial 03, 2026-09-24. This is an art-only prototype. Every raster candidate remains
**CANDIDATE — AWAITING HUMAN REVIEW**. Mechanical proof is not production approval.

## Why this exists

Trials 01 and 02 established suitable parchment, ink and transparent watercolor,
but reference-guided generation repeatedly missed the exact NW/SE transitions.
Generative imagery supplies illustration; local deterministic tooling now controls
region ownership. The current prototype transports existing illustration instead
of cutting buildings or tree crowns with a raw diagonal alpha mask.

Read the [master art spec](master_tile_art_spec.md), [edge rules](tile_edge_alignment_spec.md)
and the relevant [tile brief](../briefs/tiles/) first. Approved local references
remain the visual authority. No gameplay definition or source specification changes.

## Coordinates and corner ties

Master size is **1254×1254**. Trial 03 paths use inclusive pixel-center coordinates:
NW=(0,0), NE=(1253,0), SE=(1253,1253), SW=(0,1253), x right, y down.
The earlier grammar's continuous canvas spans 0..1254; it is not changed. A
continuous normalized guide coordinate maps to the inclusive path by ×1253/1254.

The canonical corner feature occupies North and East, Field South and West.
The path starts at NW and ends at SE. A shared endpoint pixel cannot have two
binary owners. **NW and SE ties belong to the feature**; they are zero-length
transition points, not extra Field-side exits. Therefore the exact raster tests are:

- all 1254 North and all 1254 East samples: feature;
- all 1253 non-transition West samples: Field;
- all 1253 non-transition South samples: Field;
- both transition coordinates exact; no other path contact with the outer border.

This convention is explicit and has no tolerance or feathered edge fringe.

## Deterministic boundary and masks

[boundary_generator.py](../tools/boundary_generator.py) adds five seeded sine modes
to a diagonal. Both endpoints stay fixed. A derivative bound keeps slope above
0.35, making the path strictly monotone, broadly diagonal and non-self-intersecting.
Irregularity is bounded as a fraction of image width. A private seeded RNG avoids
consuming global random state. Paths contain one sample per integer column.

[mask_utils.py](../tools/mask_utils.py) assigns y <= path[x] to feature. Field is its
exact binary complement. Clockwise rotation uses exact transposition and coordinate
rotation, not duplicated orientation logic. The diagnostic transition mask is a
configurable **60px total vertical band per column** (not perpendicular distance),
clipped away from the outermost image pixels. It is not an alpha mask.

## Source-aware transport and transition treatment

[hybrid_compositor.py](../tools/hybrid_compositor.py) uses only the two requested
wave-2 source images. Hand-calibrated wall-foot and undergrowth traces are recorded
in each boundary JSON. They approximate the terrain frontier; they are not an
automatic semantic segmentation of every blade of grass or masonry pixel.

Each destination column maps continuously back to its source column. The source
frontier moves onto the hard destination divider. A 60px strip around the frontier
travels with unit slope wherever space permits; displacement is absorbed farther
away. Thus the wall, wall hatching, crowns and undergrowth move together. The strip
tapers near endpoints, where incompatible source fringe is cropped. This is
geometric transport, not opaque polygon painting or a diagonal cut through houses.

v01 anchors the distant Field border as an initial comparison. That compresses
Field decoration near SE. **v02 uses relaxed Field displacement:** the boundary
translation releases smoothly with a Gaussian falloff across the open Field. This
reduces the compression without changing topology. The feature side still uses
monotone anchored transport. Same-column linear interpolation preserves the source
palette; it does not increase saturation or paint a new wash.

The binary mask selects the sampling region. Both interpolation samples are clamped
to the same side of the calibrated source frontier. No cross-region alpha mixing
occurs at the tile edge. A persisted provenance mask records the sampled owner and
must equal the destination feature mask. Actual pixel reproduction is checked too.

### Feature-specific calibration

Settlement uses the existing exterior wall and moves it as a coherent transition.
Buildings stay behind it; no new gate or Road is drawn. Forest uses the existing
undergrowth/treeline strip so foliage remains organic rather than a green polygon.
No external patches, repeated texture stamps or image-generation patches were used.

Limitations: column transport can bend masonry, flatten a crown near NW and stretch
parchment detail. Existing source-frame color changes can remain visible across
seams. The two endpoint tie pixels and the manual source traces require visual
review; exact mask ownership alone cannot certify the depicted terrain semantics.

## Evidence and validation

For each variant, retain:

- original source filename/hash and candidate hash in a composition JSON;
- source trace, exact target path, seed, size and irregularity in boundary JSON;
- hard feature/Field masks, interior band and actual sampling provenance PNGs;
- separate debug overlay with region tint, border, path and endpoint marks;
- native-resolution seams and review-only comparison previews.

[seam_validator.py](../tools/seam_validator.py) reconstructs the output from recorded
inputs, compares every RGB pixel, hashes the coordinate map, checks binary masks,
complements, endpoints, all edge samples and provenance. Changing an output and
updating its hash still fails reconstruction. It also checks every rotated seam
pixel, not just grid dimensions. These are geometry/provenance tests, not an art
classifier. Visual review remains a separate decision.

## Reproduction

Dependencies already present: Python 3, Pillow 12.1.1, NumPy 2.3.5. Nothing installed.
Run from the project root. Writers refuse existing output names. To reproduce in
place, choose unused version numbers; do not overwrite earlier candidates.

```bash
python3 -B art/tools/hybrid_compositor.py --tile settlement_corner --version 1 --seed 31 --irregularity 0.025 --field-mode anchored
python3 -B art/tools/hybrid_compositor.py --tile forest_bend --version 1 --seed 31 --irregularity 0.025 --field-mode anchored
python3 -B art/tools/hybrid_compositor.py --tile settlement_corner --version 2 --seed 73 --irregularity 0.015 --field-mode relaxed
python3 -B art/tools/hybrid_compositor.py --tile forest_bend --version 2 --seed 73 --irregularity 0.015 --field-mode relaxed
python3 -B art/tools/build_hybrid_reviews.py
python3 -B -W error -m unittest discover -s art/tools -p 'test_*.py' -v
python3 -B art/tools/seam_validator.py --composition art/reviews/trial_03/forest_bend_hybrid_v02_composition.json
```

The first five commands describe the exact Trial 03 build on fresh paths; they
intentionally refuse to overwrite the delivered files. Validator/tests are safe
to repeat. Review builder produces native 2508px/3762px seam grids; only the labeled
comparison sheets use explicitly documented 420px previews. Labels never enter
candidate pixels. These utilities do not write to approved assets.

## Later generalization

Corner orientations already share one path/mask via rotation. Edge, Belt and
Throughway shapes will need their own region masks and calibrated donor frontiers;
they are not implemented or generated in this trial. Keep geometry, illustration,
source calibration and visual approval separate. Before scaling, inspect the Trial
03 comparisons at native size and choose whether the remaining warp/seam artifacts
are acceptable or need localized hand retouching.

## Geometry-wave generalization — 2026-09-24

The preceding sections describe the preserved Trial-03 corner method. The following
families are now implemented by [production_geometry.py](../tools/production_geometry.py):

| Family | Canonical connection | Interior construction |
|---|---|---|
| full_edge_single | N feature; E/S/W Field | Seeded single cap, NW to NE, inward treeline |
| full_edge_corner | N/E feature; S/W Field | Existing exact endpoint corner grammar |
| full_edge_opposite | N/S feature; E/W Field | Two seeded inward side boundaries; one connected corridor |
| road_socket | N/S Road | Centered 126px ports, organic interior spine |
| river_socket | N/S River | Centered 250px ports, no River art generated |
| road_three_way | N/E/S Road; W Field | Connected spine and east branch; fixed outer collars |

Native production remains 1254x1254. Seed controls interior variation, never edge
ownership. Opposite-region inset_fraction varies the corridor waist without
changing topology; default .24, Forest Belt v02 .28, Settlement Throughway v02 .34.
All orientations derive from lossless quarter-turn rotation. The
[templates](../templates/production_geometry/) include masks, corner/center coordinates,
edge counts, socket rounding, rotation metadata and validation. See the
[alignment spec](tile_edge_alignment_spec.md) for binary/continuous coordinate policy.

### Source-aware transport and sockets

[geometry_wave_compositor.py](../tools/geometry_wave_compositor.py) reads persisted
manual source-frontier calibrations. Single-edge correction transports columns;
opposite-edge correction transports row intervals. A 30px strip on each side of
the frontier is retained where space permits, then the remaining region stretches
smoothly to its destination. This keeps the illustrated treeline or city wall as
the transition, instead of cutting houses or tree crowns with a raw polygon.

Road correction moves N/S/E socket coordinates through smoothstep collars that
release into unchanged central artwork over 240px. The central illustrated junction
supplies the connection, and its traced polygon is sampled through the same map.
The mathematical three-way template establishes edge/connectivity constraints;
it does not require the illustration's center to match a rigid T silhouette.
No rectangular Road strips are pasted. No new gates or exits are drawn.

RGB uses bilinear interpolation; the authoritative owner/provenance mask stays
binary. Mask equality proves the recorded coordinate map reaches the calibrated
source region, not that every painted pixel has been semantically recognized.
Unlike the Trial-03 corner sampler, this generalized bilinear sampler is not a
blanket guarantee against cross-frontier color interpolation. Outer ownership is
hard in the mask; actual brushwork and trace accuracy require separate visual review.
No palette/saturation change or outside art is used.

### Validation, reproduction and known limits

[geometry_wave_validator.py](../tools/geometry_wave_validator.py) reproduces every
candidate RGB byte and owner mask from its source/calibration/seed, checks hashes,
connectivity, exact edge arrays and four lossless rotations. Review manifests verify
all native seam tile bytes. Only labeled comparison thumbnails are reduced.

Run safe read-only checks from the root:

```bash
python3 -B -W error -m unittest discover -s art/tools -p 'test_*.py'
python3 -B art/tools/geometry_wave_validator.py art/reviews/geometry_wave/*_composition.json
```

Fresh builds use production_geometry.py, geometry_wave_compositor.py with
--tile/--version/--seed, and geometry_wave_reviews.py. Writers refuse existing
output names. Original prompts, source PNGs, calibrations, seeds, hashes, masks and
composition records live in [the wave review folder](../reviews/geometry_wave/).
Reproduction reuses saved source PNGs; a fresh model call is not deterministic.
Do not use unused version numbers to expand the roster without authorization.

Geometry is proven for single/opposite regions and three-way sockets. Visual
production remains provisional: endpoint transport compresses trees; large
opposite-region corrections bend walls and stretch houses. Smaller waist changes
improve central proportions but cannot remove all corner distortion. Settlement
Throughway needs a later object-aware patch/retouch method before approval. This
wave did not implement that further method or generate extra candidates.
Legacy Road references have inconsistent sockets; their native seam comparisons
are diagnostic, not compatibility certification. [The report](../reviews/geometry_wave/TRIAL_REPORT.md)
separates each mask pass from the visual verdict. Human review is the next step.

## Production wave01 — multiple features without whole-image deformation

The eight-design wave combines canonical single/corner/opposite full-edge regions
with126px Road and250px River sockets. [hybrid_wave_geometry.py](../tools/hybrid_wave_geometry.py)
builds independent feature masks and explicit topology metadata from the briefs.
Each component must be4-connected; outer edge arrays, corner ties, socket centering
and rotated equivalents are checked. Required access/contact must have actual mask
adjacency, not merely a label saying it exists. No gameplay topology code changes.

[production_wave_compositor.py](../tools/production_wave_compositor.py) addresses
the previous city-warp problem by changing interior mask shape to match the source's
organic boundary, then rebuilding exact endpoints/sockets inside96px edge collars.
Interior shape is flexible; canonical feature identity, contacts and edge ownership
are not. Throughway preserves its traced connected city corridor and reconstructs
only corner fans. Every candidate saves its actual masks; the initial guide does
not pretend to represent the final internal treeline pixel-for-pixel.

Use manual source-region annotations, inspect them against the source, and retain
those annotations in the composition record. Final source and target ownership use
the same overlap policy. When source/target owners differ, copy a complete native
24px donor patch from the same feature, applying only the necessary pixels and
penalizing repeated donor use. No scaling, interpolation, palette shift or nonlinear
transport of illustration is allowed. Save integer source_x/source_y maps and the
actual sampled owner in compressed provenance data. Exact RGB reconstruction is
verified against immutable source hashes.

This is region-aware local reconstruction, not an automatic object segmentation
system. Patches can still repeat or cut a crown, wall or bank. A human trace can
mislabel ambiguous painted pixels. Known-label validation must never be reported
as automatic semantic proof that every ink mark agrees with its feature. Throughway
preserves99.66–99.78% of source pixels, but even a small repaired fraction may be
conspicuous on a seam. Prefer source material already close to the target geometry.

### Internal relationships

- Gate/Corner Gate: the visible approach terminates at the urban gate; no extra exit.
- Settlement Road Bend: a continuous bend touches a gate; access does not terminate it.
- Settlement Road Throughway: a continuous street crosses one urban footprint.
  Its independent Road/Settlement masks may overlap only inside the tile, retaining
  both connected identities. Do not cut the Settlement mask into two pieces or
  create dual-type outer edges. The street remains visually traceable.
- Riverside Hamlet: keep the River continuous with a shared inhabited bank. Avoid
  Port-scale docks, cranes or warehouses; no Road is introduced.
- Woodland River: woods meet the bank; the River remains open and continuous.
- Woodland Road: connected woods and Road remain separate; no extra access invented.

### Review and safe rebuild

[production_wave_reviews.py](../tools/production_wave_reviews.py) uses the saved
candidate masks for debug overlays. It composes exact native quarter-turned images
against relevant anchors/references and checks every saved tile pixel. Labels occur
only outside art on reduced comparison previews. Existing reference sockets may
still mismatch: preserve that evidence instead of silently correcting the reference.
Road End identity is outside this wave and never used in these seam layouts.

Run the full art tests and --verify over all composition JSON files. --rebuild is
explicit and backs up existing candidates/masks/records. Source images are never
modified. A fresh generation call is not deterministic; replay uses saved sources.

The [wave report](../reviews/production_wave_01/TRIAL_REPORT.md) contains all16
candidate assessments. Whole-image distortion is removed; invisible boundary
reconstruction is not solved for every hybrid. Gate, Riverside Hamlet and Settlement
Road Throughway currently have neither recommendation. Do not scale to Founding or
batch finalization before human review. No wave01 output is an approved anchor/final.


## Production Wave 02 — judge source suitability before repair

A source must already fit the intended scene composition. Regenerate it if correction
would require conspicuous repeated motifs, large translated patches, distant moves
of recognizable buildings, obvious cloning, heavy nonlinear warping or substantial
reconstruction of architectural objects. A low changed-area percentage alone is
not evidence of a good repair. Do not rescue an unsuitable illustration by stamping
city fragments into a mechanically valid mask.

Use the approved anchors directly in generation, together with the composition guide
and exact brief. The guide governs scene layout; local illustration anchors govern
style. Save the original image, exact prompt and references. Review source suitability
before composition and record rejection reasons. The image model supplies a coherent
scene; deterministic tooling remains the mechanical authority.

For this wave, [repair_wave_sampler.py](../tools/repair_wave_sampler.py) preserves
the traced Settlement footprint and rejects sources whose city edges would need
reconstruction. Road/River intervals ease into unchanged geometry through a **128px
edge collar**. A monotone inverse coordinate map keeps an 18px strip around each
bank at unit scale where space permits; quiet surrounding texture absorbs the small
adjustment. Sampling uses integer source coordinates, with no color interpolation.
Every changed destination and sampled source pixel must lie outside the Settlement
mask. The sampler rejects movement of architecture rather than repairing it later.
It does not clone donor blocks or transport whole buildings. This limited local
resampling can still bend grass or ripple lines; it is not a universal retouch tool.

Source annotations describe ground footprints and ink-bank boundaries. They are
human judgments, not automatic object segmentation. Inspect elevated roof/wall
marks at corners separately: mask proof cannot certify every painted detail.
Road/Settlement interior overlap retains the existing Throughway interpretation;
there are no dual outer sockets or changed gameplay rules.

[repair_wave_metrics.py](../tools/repair_wave_metrics.py) records transported area,
RGB-changed area, maximum/p95 travel, duplicate donor coordinates and a binary
repair-zone image. Donor reuse measures coordinates, not semantic motif repetition.
Required visual assessments record whether major objects moved, motifs repeated,
edge repair is visible at normal scale and the source was rejected before composition.
Unknown assessments remain pending; a numerical pass cannot approve an image.

The socket-mapping method uses fixed screening limits of **8% transported area,
80px p95 movement, 120px maximum movement and 25% repeated transported donor
coordinates**. These are art-review heuristics, not changes to mechanical standards.
They were chosen for continuous quiet-margin sampling, which touches more pixels
than isolated stamps but preserves bank lines. They do not override visual rejection.
The metrics module's generic patch defaults remain separate. Do not raise limits
merely to force a failing source through the gate.

[repair_wave_compositor.py](../tools/repair_wave_compositor.py) validates before
writing, saves cost/repair/provenance records and rejects unsuitable sources without
writing a candidate. Review candidates can retain a visible-repair failure so the
human can compare them; they cannot be recommended merely because geometry passes.
Prefer less visible correction when scene quality is otherwise comparable.

[repair_wave_reviews.py](../tools/repair_wave_reviews.py) produces native, lossless
seams, separate ownership/contact/repair overlays and labeled comparison sheets.
Comparison thumbnails alone are scaled. Sources, old candidates and approvals stay
unchanged. All six repair outputs remain **CANDIDATE — AWAITING HUMAN REVIEW**.

Verification from the project root:

    python3 -B -W error -m unittest discover -s art/tools -p 'test_*.py'
    python3 -B art/tools/repair_wave_compositor.py --verify art/reviews/production_wave_02/compositions/*.json

Fresh generation is not deterministic. Replay uses saved sources and calibrations.
Writers refuse existing names; explicit rebuild backs up prior evidence. A rejected
trace does not authorize changing mechanics: correct the annotation only when image
inspection supports it, preserving the rejected record. See the
[Wave 02 report](../reviews/production_wave_02/TRIAL_REPORT.md) for decisions and limits.

## Alpha acceptance supersedes the earlier polish gate

For the playable alpha, exact topology, edge ownership and sockets, readable features,
absence of false connections and broad parchment/ink/watercolor consistency are required.
Minor patching, local socket curvature, repeated motifs and small compositing artifacts
are deferred polish, not alpha blockers unless they obscure mechanics. Historical strict
visibility reports are preserved; they do not override explicit human alpha acceptance.
Wave02 v04 Gate, Riverside Hamlet and Road Throughway are accepted production anchors
with polish deferred. No further polishing is required before gameplay development.
This does not make them immutable final shipping assets.
