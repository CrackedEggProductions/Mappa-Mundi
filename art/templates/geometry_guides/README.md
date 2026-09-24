# Fixed-corner geometry guides

These are mechanical controls, not tile illustrations. Current size: 1254×1254.
Each design has a labeled guide and clean underlay. Labels/borders must never
appear in generated art. Binary masks live in ../control_masks/.

Coordinates: x right, y down. NE feature occupies x >= y; SW is Field. The
continuous divider runs (0,0) to (1254,1254). Raster indices are 0–1253;
diagonal tie pixels belong to the feature. Only the corner point is shared.
N/E are full feature sides, S/W are Field. The interior divider may be organic;
outer transition endpoints may not move or leave wrong-terrain fringes.

Rebuild with python3 -B art/tools/build_wave2_guides.py from project root. It
refuses existing outputs and asserts edge ownership. The built-in generation
tool receives the guide/underlay as references, not an enforced mask channel.
Always inspect generated pixels independently. A correct guide cannot certify art.
