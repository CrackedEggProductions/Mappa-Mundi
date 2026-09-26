# Alpha tile presentation

`TileArtRegistry` owns this mapping. Core content and rules never load textures.
Accepted sources remain unchanged under `art/references/`. `art/.gdignore` stays
in place: the registry loads individual images once at runtime, caches textures
and mipmaps, and caches canonical thumbnails separately. This is project runtime
support; export packaging remains Phase 12 work.

## Production anchors

These thirteen designs use their matching `<design>_anchor.png` from
`art/references/production_anchors/`:

- Forest Edge, Forest Bend, Forest Belt
- Settlement Corner, Settlement Throughway, Settlement Gate
- Riverside Hamlet, Road Junction
- Woodland Road, Woodland River
- Settlement Corner Gate, Settlement Road Bend, Settlement Road Throughway

## Existing references

| Design | File below `art/references/` | Clockwise source correction |
|---|---|---|
| Open Fields | approved_mechanical/ref_04_open_fields.png | 0 |
| Hamlet Edge | approved_mechanical/ref_03_hamlet_edge.png | 0 |
| Straight Road | approved_mechanical/ref_05_straight_road.png | 90° |
| Bending Road | approved_mechanical/ref_09_bending_road.png | 90° |
| River End | approved_mechanical/ref_15_river_end.png | 0 |
| River Run | approved_style/ref_10_river_run.png | 0 |
| River Bend | approved_mechanical/ref_13_river_bend.png | 0 |

The Road source corrections align the historical illustration orientation to
canonical content; the board then adds the authoritative tile rotation. This
does not alter or reclassify the source references.

## Fallback and overlays

Founding Homestead and Road End deliberately use presentation-generated
mechanical geography. Road End's source identity remains unresolved. Every
Development, Upgrade and Transformation uses a named badge and simple thumbnail
when dedicated imagery is absent. TileView's current geometry replaces obsolete
base imagery after a Transformation. All of these are disposable presentation,
never a source of game rules or new production art.

`mapping_report(content)` exposes missing paths and the complete resolved asset
categories for startup diagnostics. Missing optional imagery falls back; missing
authoritative content remains a content-validation error.
