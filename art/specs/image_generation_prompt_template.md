# Mappa Mundi — repeatable image-generation request

Trial standard: 1254×1254 production master. The first trial output returned native 1254×1254 despite a 1024 request, so we adopted the reference-native size instead of resampling. Existing 1254×1254 references remain
unchanged. Geometry uses the normalized 1000-unit alignment spec, uniformly scaled.
See [machine-readable coordinates](../templates/edge_grammar.json) and
[template/tool instructions](../tools/README.md).

## Required request fields

Copy and complete this block for each candidate. Record the exact submitted prompt
and reference paths, not merely a summary. No field may be inferred from a name.

```text
Use case: stylized-concept
Asset: Mappa Mundi base tile, candidate only
Tile name / brief path / version:
Output destination: art/generated/candidates/<stem>/<stem>_vNN.png
Status: CANDIDATE — AWAITING HUMAN REVIEW
Master request: 1254×1254 square PNG; single tile, no labels or frame

Reference priority:
Match the supplied local Mappa Mundi reference images before consulting any outside visual inspiration.
Input 1: <geometry template path> — edge ownership only, not illustration style
Input 2: <approved local reference path> — <specific style traits>
Input 3: <approved local reference path> — <specific style traits>
Additional references and their roles:
Reference defects that must NOT be copied:

Exact edges, north at top:
North:
East:
South:
West:
Internal connected components:
Required same-tile contacts:
Required separations:
Forbidden/absent features:

Geometry:
Road sockets if present: centered 50%, width 10%; normalized endpoints 450–550.
River sockets if present: centered 50%, width 20%; normalized endpoints 400–600.
At 1254 px: Road 125.4 px, endpoints 564.3–689.7; River 250.8 px, endpoints 501.6–752.4.
Absent Road/River: explicitly say none, do not draw sockets.
Forest/Settlement sides: full corner-to-corner ownership of each assigned side.
Adjacent same-type sides: one continuous shared-corner region, no isolated bumps.
Boundary endpoint coordinates and expected interior division:
Exact outer boundary, organic inner boundary. No Field gaps in occupied sides.

Style:
Antique parchment, dominant fine sepia ink, medieval manuscript map symbols.
Mostly monochrome with translucent desaturated watercolor; visible paper under every wash.
Field faint light green; Forest muted woodland green; River pale blue;
Road soft tan; Settlement warm off-white stone and sparse dusty terracotta.
Use only colors for features actually present. Sparse grass/flowers/stones.
No lush scenic rendering,3D,glossy color,heavy shading,commercial board-game style.
No extra roads/streams/forest exits/buildings,labels,borders or false connections.

Variant variable: <one limited interior-detail or tint emphasis; geometry is fixed>
```

## Submission and preservation

Use the built-in reference-image generation tool when available. Submit each
candidate separately with the same geometry and primary style files. Do not
substitute procedural tile drawings if generation is unavailable. Store request
JSON under `art/reviews/trial_01/requests/` for this trial. Record returned tool
information and actual dimensions; do not invent a model version or seed.

Copy the unmodified generated PNG into its requested version path. If the tool
returns a different resolution, retain it and report the deviation; do not silently
resize a candidate to claim compliance. Review sheets may contain labeled previews,
but seam composites must preserve native pixels using exact quarter-turn transposes.

## Review and stopping rule

Compare independently on STYLE and MECHANICS. Geometry-guide compliance cannot be
assumed from the prompt or inferred from color thresholds alone. Inspect all four
boundaries, the shared corner, transition endpoints, component continuity and
false exits, then review native-resolution 2×2 and 3×3 composites. Road/River socket
checks are N/A for the two current area-only designs; their templates still exist.

Record structured verdicts and concrete defects even for attractive candidates.
Neither a machine check nor a favorable assistant review grants production approval.
For Trial 01 deliver exactly three versions of each requested design, retain failures
with their verdicts, and stop for human review. No autonomous promotion or roster batch.

## Wave-2 fixed-corner addendum

For Settlement Corner and Forest Bend, attach the design's labeled guide and clean
underlay from art/templates/geometry_guides/ as core mechanical references, then
wave-1 v01 as primary STYLE reference and approved supporting style files.
Explicitly prohibit copying v01's wrong silhouette. North/East full feature,
South/West Field; endpoints exactly NW (0,0) and SE (1254,1254). Outer geometry
rigid, interior line organic. Never permit edge leaks or wrong-terrain fringes.

Store exact requests in art/reviews/trial_02/requests/. The guide is a direct image
reference, not a tool-enforced mask. Run the corner diagnostic using the binary
mask and inspect actual edges, corner endpoints, false exits and rotated seams.
Exactly two new versions per family are authorized for wave 2; stop after four
candidates regardless of verdict. No automatic production approval or roster batch.

## Geometry-wave production update

Relevant [production anchors](../references/production_anchors/) now lead visual reference priority,
followed by approved local mechanical references, approved local style references,
canonical geometry templates and optional external conceptual inspiration.
Canonical masks still determine geometry; reference priority never overrides legality.
Generate illustration material, preserve the raw source, then apply deterministic
compositing and validate the saved candidate. A generated image alone is not a
mechanically accepted output. No asset is FINAL without explicit human approval.

Hard 1254px binary sockets use nearest-even width: Road 126 pixels (564..689),
River 250 pixels (502..751); inclusive center 626.5, continuous center 627.
These are symmetric rasterizations of the unchanged 10%/20% design widths.
