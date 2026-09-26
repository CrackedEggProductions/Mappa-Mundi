# Corner geometry diagnostics

`check_corner_geometry.py` is an art-review aid for the canonical unrotated
Settlement Corner and Forest Bend: North/East feature, South/West Field. It uses
Pillow already available to the other art tools; it adds no dependency.

```bash
python3 -B art/tools/check_corner_geometry.py \
  --candidate art/generated/candidates/forest_bend/forest_bend_wave2_v01.png \
  --output-json art/reviews/trial_02/forest_bend/forest_bend_wave2_v01_geometry.json \
  --output-image art/reviews/trial_02/forest_bend/forest_bend_wave2_v01_geometry_review.png
```

An optional `--mask path.png` accepts a native-size binary mask: white means the
NE feature and black means Field. Its raster must match `x >= y`, including the
diagonal tie pixels. Omit the argument to construct that same mask in memory.
A labeled/color geometry guide is not a binary mask and is intentionally rejected.
No input is resized. `--bins 32` is the default; change it only when documenting
why a different sample scale is needed.

## What the check measures

The diagnostic calibrates feature and Field mean luminance in two interior
patches, then samples 32 segments along each edge at 1.2% tile depth. It also
samples the NE shared feature corner, SW Field corner, and both NW/SE transition
corners. Expected fractions come from the exact diagonal mask. JSON records
all 132 sample boxes, expected fractions, estimated fractions, luminance and
texture statistics, thresholds, source hash and optional mask hash.

For adequate calibration contrast (at least 8 luminance levels), a deviation
larger than 0.35 flags a **suspicious** sample. A separate annotated review image
marks those boxes red, low-contrast/inconclusive boxes orange, and boxes without
a proxy anomaly green. Labels are outside the tile; colored boxes appear only
on this review copy. The source candidate stays unchanged.

## What the check cannot establish

This is a luminance occupancy proxy, **not semantic segmentation**. Tree ink,
wall hatching, aged borders and washes can produce false alarms. Thin fringes
can escape detection. A building, Road or false socket cannot be identified by
this method. Texture statistics are reported for inspection, not treated as
proof of topology. Organic interior boundaries need not follow the mask exactly.

The tool never returns a semantic mechanical pass. If no anomaly is found, its
verdict is still **inconclusive**, pending visual checks of every edge, corner,
and rotated seam. An annotation's green outline means only “no proxy anomaly.”
It is not approval. Exact transition endpoints still require human inspection.

The output files must be new. Existing outputs are refused, and a SHA-256 check
confirms that review generation did not change the candidate. Exit zero means
the diagnostic ran; inspect the JSON verdict to learn its result.

## Verification

```bash
python3 -B -W error -m unittest discover -s art/tools -p test_corner_geometry.py -v
```

Eight synthetic checks cover a correct NE triangle without semantic approval,
a shifted diagonal, feature-edge fringe, wrong-edge leak, shared-corner gap,
uniform/low-contrast input, invalid masks, and native-size output/source hash
preservation/non-overwrite behavior. These tests validate the proxy mechanics;
they do not certify any generated art.
