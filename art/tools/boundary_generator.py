"""Deterministic organic corner dividers in inclusive image coordinates."""
import math
import random
from collections.abc import Sequence

Point = tuple[float, float]


def generate_boundary(
    size: int = 1254, seed: int = 1, irregularity: float = 0.035,
) -> list[Point]:
    """Return a strictly increasing NW-to-SE graph, one point per column.

    Coordinates include both endpoint pixel centers: 0 through size - 1.
    Irregularity bounds displacement as a fraction of the tile width. A
    derivative bound limits the sine displacement so slope stays above 0.35;
    therefore this curve cannot double back, cross itself, or hit other edges.
    This private random generator does not change Python's global RNG state.
    """
    if not isinstance(size, int) or isinstance(size, bool) or size < 3:
        raise ValueError('size must be an integer of at least 3')
    if not math.isfinite(irregularity) or not 0 <= irregularity <= 0.2:
        raise ValueError('irregularity must be finite and between 0 and 0.2')
    rng = random.Random(seed)
    coefficients = [rng.uniform(-1, 1) / k**1.5 for k in range(1, 6)]
    amplitude_bound = sum(abs(a) for a in coefficients)
    derivative_bound = sum(abs(a) * k * math.pi
                           for k, a in enumerate(coefficients, 1))
    scale = min(irregularity / max(amplitude_bound, 1e-12),
                0.65 / max(derivative_bound, 1e-12))
    extent = size - 1
    path = [(float(x), extent * (x / extent + scale * sum(
        a * math.sin(k * math.pi * x / extent)
        for k, a in enumerate(coefficients, 1)))) for x in range(size)]
    path[0], path[-1] = (0.0, 0.0), (float(extent), float(extent))
    return path


def rotate_path(path: Sequence[Point], size: int, quarter_turns: int) -> list[Point]:
    """Rotate clockwise around the square using inclusive pixel coordinates."""
    if not isinstance(quarter_turns, int):
        raise ValueError('quarter_turns must be an integer')
    extent = size - 1
    result = list(path)
    for _ in range(quarter_turns % 4):
        result = [(extent - y, x) for x, y in result]
    return result
