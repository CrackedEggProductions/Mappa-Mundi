"""Hard region ownership masks; interior transition bands never touch edges."""
import math
from collections.abc import Sequence
from PIL import Image, ImageChops, ImageDraw
from boundary_generator import Point


def make_masks(
    path: Sequence[Point], size: int, transition_width: int = 60,
) -> dict[str, Image.Image]:
    """Rasterize a canonical NE feature graph and its exact complement.

    FEATURE owns y <= path[x]. The shared NW and SE divider pixels belong to
    FEATURE. Thus N/E are entirely feature, W except NW and S except SE are
    Field. There is no tolerance zone on any outer edge.

    The binary interior transition mask is at most transition_width pixels
    high per column, centered on the curve and clipped away from all edges.
    It is a cleanup region, not a softening of authoritative ownership.
    """
    if not isinstance(size, int) or isinstance(size, bool) or size < 3:
        raise ValueError('size must be an integer of at least 3')
    if not isinstance(transition_width, int) or transition_width < 0:
        raise ValueError('transition_width must be a nonnegative integer')
    extent = size - 1
    if len(path) != size or path[0] != (0, 0) or path[-1] != (extent, extent):
        raise ValueError('path must have one point per column and exact NW/SE endpoints')
    for index, (x, y) in enumerate(path):
        if x != index or not math.isfinite(y) or not 0 <= y <= extent:
            raise ValueError('path must be a finite graph over integer columns')
        if index and y <= path[index - 1][1]:
            raise ValueError('path must increase strictly in both axes')
    feature = Image.new('L', (size, size), 0)
    transition = Image.new('L', (size, size), 0)
    fd, td = ImageDraw.Draw(feature), ImageDraw.Draw(transition)
    for x, (_, y) in enumerate(path):
        fd.line((x, 0, x, math.floor(y)), fill=255)
        if 0 < x < extent and transition_width:
            low = max(1, math.ceil(y - transition_width / 2))
            high = min(extent - 1, math.ceil(y + transition_width / 2) - 1)
            if low <= high:
                td.line((x, low, x, high), fill=255)
    return {'feature': feature, 'field': ImageChops.invert(feature),
            'transition': transition}


def rotate_mask(mask: Image.Image, quarter_turns: int) -> Image.Image:
    """Rotate clockwise by exact transposition, without interpolation."""
    if not isinstance(quarter_turns, int):
        raise ValueError('quarter_turns must be an integer')
    if mask.width != mask.height:
        raise ValueError('tile mask must be square')
    rotations = {1: Image.Transpose.ROTATE_270, 2: Image.Transpose.ROTATE_180,
                 3: Image.Transpose.ROTATE_90}
    turns = quarter_turns % 4
    return mask.transpose(rotations[turns]) if turns else mask.copy()
