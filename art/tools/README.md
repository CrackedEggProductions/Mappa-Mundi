# Art review tools

These project-owned Python tools require Pillow (already available locally).
They are art review tools and do not import or change gameplay code.

## Templates

`python3 art/tools/build_templates.py` builds the canonical template set once;
it refuses to overwrite it. Current outputs live in `../templates/`.
Use a **1254×1254 pixel production master**, uniformly mapped from the existing
1000×1000 design-unit specification. Existing 1254-pixel references remain
untouched. Trial generation returned native 1254px, so the master follows that
output without resampling. Road width is 125.4px (10%); River width is 250.8px
(20%), centered at 627px. Road endpoints are 564.3–689.7px; River endpoints are
501.6–752.4px. The initial 1024px template set is preserved under
`../templates/archived_1024/` for provenance, and is not the current master. The exact
continuous geometry lives in SVG/JSON; PNG masks encode fractional pixel area
coverage, symmetrically centered. The last fractional fringe is not a shifted
socket. Inspect the SVG when subpixel endpoints matter.

`ne_ownership_guide.png` and `ne_full_area.svg` describe the canonical N/E full
area and S/W Field topology used by both trial designs. The NW→SE diagonal is
an interior topology guide, not a required straight ink wall. Actual artwork
may have an organic interior boundary while keeping outer ownership exact.
At transition corners, the divider is a single point; it does not grant area
ownership along either Field edge. `road_*.png` and `river_*.png` show only
socket-to-center strips, not a prescribed complete tile design.

Templates are diagrams, never substitute art. Their correctness cannot prove
that an image model obeyed them. Review actual candidate pixels and seams.

## Seam sheets

```bash
python3 art/tools/build_seam_sheet.py seams \
  --candidate art/generated/candidates/forest_bend/forest_bend_v01.png \
  --output-dir art/reviews/trial_01/forest_bend
```

Creates three PNGs and a JSON manifest per candidate:

- `*_central_area_2x2.png`: four full-area corners meet at the center.
- `*_central_field_2x2.png`: four Field corners meet at the center.
- `*_alternating_3x3.png`: both seam types and repeated corner combinations.
- `*_seams.json`: original SHA256, dimensions, quarter turns and matching edges.

Images retain native resolution. Rotations are exact quarter-turn pixel
transposes, with no resampling, gap, border or label inside the seamless grids.
The tool validates declared N/E Area and S/W Field layouts; it does not classify
artwork or mechanically approve candidates. It refuses non-square candidates
and existing output names, and verifies source hashes after generating reviews.

## Comparison sheets

```bash
python3 art/tools/build_seam_sheet.py comparison \
  --item 'Style anchor=art/references/approved_style/example.png' \
  --item 'Candidate v01=art/generated/candidates/forest_bend/forest_bend_v01.png' \
  --output art/reviews/trial_01/forest_bend_comparison.png --columns 3
```

Repeat `--item 'Label=path'` for all desired images. Tiles retain original
dimensions, even when references and candidates differ. Labels sit in a
separate 64-pixel caption band outside the asset. The JSON manifest records
each image's native size, position and hash. Choose short single-line labels.
Do not judge apparent image scale differences as ink-weight changes without
also inspecting each source at the same display scale.

## Verification

`python3 -B art/tools/test_review_tools.py` checks all-pixel preservation,
clockwise rotation, gapless compositing, matching layout edges, refusal of
overwrites/non-square sources, socket widths and NE boundary ownership.
Example template seam outputs are stored in `../templates/seam_tests/`.
