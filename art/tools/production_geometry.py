"""Deterministic full-edge regions and centered sockets for tile-art production."""
import argparse
import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image

from boundary_generator import generate_boundary
from mask_utils import make_masks, rotate_mask

FAMILIES = ('full_edge_single', 'full_edge_corner', 'full_edge_opposite',
            'road_socket', 'river_socket', 'road_three_way')


def socket_width(size: int, fraction: float) -> int:
    """Nearest positive even pixel width; exact half cases round upward.

    Even native masters have a half-pixel center. Even widths therefore give
    integer inclusive endpoints with exactly symmetric socket coverage.
    """
    return max(2, 2 * math.floor(size * fraction / 2 + 0.5))


def socket_bounds(size: int, fraction: float) -> tuple[int, int]:
    width = socket_width(size, fraction)
    start = (size - width) // 2
    return start, start + width - 1


def _check(family: str, size: int) -> None:
    if family not in FAMILIES:
        raise ValueError(f'unknown geometry family: {family}')
    if not isinstance(size, int) or isinstance(size, bool) or size < 16 or size % 2:
        raise ValueError('production master size must be an even integer >= 16')


def generate_mask(family: str, size: int = 1254, seed: int = 41, *,
                  inset_fraction: float = 0.24) -> Image.Image:
    """Return one connected, binary native-resolution feature region.

    Pixel centers are inclusive 0..size-1. Full-edge features own shared corner
    pixels. Field sides exclude only those explicitly shared transition pixels.
    Quarter-turn orientations use rotate_mask, never separate geometry code.
    """
    _check(family, size)
    if not math.isfinite(inset_fraction) or not 0.1 <= inset_fraction <= 0.4:
        raise ValueError('inset_fraction must be finite and between 0.1 and 0.4')
    if family != 'full_edge_opposite' and inset_fraction != 0.24:
        raise ValueError('custom inset_fraction applies only to opposite-edge regions')
    if family == 'full_edge_corner':
        return make_masks(generate_boundary(size, seed), size)['feature']
    rng = random.Random(seed)
    phase, phase2 = rng.uniform(-math.pi, math.pi), rng.uniform(-math.pi, math.pi)
    extent = size - 1
    t = np.arange(size, dtype=float) / extent
    envelope = np.sin(np.pi * t)
    wave = (np.sin(4 * np.pi * t + phase) * 0.014
            + np.sin(7 * np.pi * t + phase2) * 0.006) * envelope
    pixels = np.zeros((size, size), dtype=np.uint8)
    if family == 'full_edge_single':
        depths = extent * (0.44 * envelope ** 0.72 + wave)
        depths[0] = depths[-1] = 0
        for x, depth in enumerate(depths):
            pixels[:int(math.floor(depth)) + 1, x] = 255
    elif family == 'full_edge_opposite':
        left = extent * (inset_fraction * envelope ** 0.72 + wave)
        right = extent * (1 - inset_fraction * envelope ** 0.72 + wave * 0.65)
        left[0] = left[-1] = 0
        right[0] = right[-1] = extent
        for y in range(size):
            pixels[y, int(math.ceil(left[y])):int(math.floor(right[y])) + 1] = 255
    else:
        fraction = 0.20 if family == 'river_socket' else 0.10
        start, end = socket_bounds(size, fraction)
        # Flat collars retain canonical socket pixels for at least 60px at 1254.
        collar = max(2, round(size * 60 / 1254))
        offsets = np.rint(extent * wave * 0.8).astype(int)
        offsets[:collar] = offsets[-collar:] = 0
        for y, offset in enumerate(offsets):
            pixels[y, start + offset:end + offset + 1] = 255
        if family == 'road_three_way':
            # An east arm joins the middle of the existing north/south spine.
            for x in range(size // 2, size):
                offset = offsets[x]
                pixels[start + offset:end + offset + 1, x] = 255
    return Image.fromarray(pixels)


def expected_edges(family: str, size: int) -> dict[str, np.ndarray]:
    _check(family, size)
    edges = {key: np.zeros(size, dtype=np.uint8) for key in 'NESW'}
    if family.startswith('full_edge'):
        feature_sides = {'full_edge_single': 'N', 'full_edge_corner': 'NE',
                         'full_edge_opposite': 'NS'}[family]
        for side in feature_sides:
            edges[side][:] = 255
        # Arrays follow screen order: N/S left-to-right; E/W top-to-bottom.
        if family == 'full_edge_single':
            edges['W'][0] = edges['E'][0] = 255
        elif family == 'full_edge_corner':
            edges['W'][0] = edges['S'][-1] = 255
        else:
            edges['W'][[0, -1]] = edges['E'][[0, -1]] = 255
    else:
        start, end = socket_bounds(size, 0.20 if family == 'river_socket' else 0.10)
        for side in ('NES' if family == 'road_three_way' else 'NS'):
            edges[side][start:end + 1] = 255
    return edges


def _edges(array: np.ndarray) -> dict[str, np.ndarray]:
    return dict(N=array[0], E=array[:, -1], S=array[-1], W=array[:, 0])


def _component_count(array: np.ndarray) -> int:
    """Four-connected scanline union; avoids a Python queue per image pixel."""
    parents: list[int] = []
    previous = []

    def root(index: int) -> int:
        while parents[index] != index:
            parents[index] = parents[parents[index]]
            index = parents[index]
        return index

    for row in array:
        changes = np.diff(np.pad(row != 0, (1, 1)).astype(np.int8))
        starts, ends = np.flatnonzero(changes == 1), np.flatnonzero(changes == -1) - 1
        current = []
        old = 0
        for start, end in zip(starts, ends):
            index = len(parents)
            parents.append(index)
            while old < len(previous) and previous[old][1] < start:
                old += 1
            match = old
            while match < len(previous) and previous[match][0] <= end:
                parents[root(previous[match][2])] = root(index)
                match += 1
            current.append((start, end, index))
        previous = current
    return len({root(index) for index in range(len(parents))})


def validate_mask(mask: Image.Image, family: str) -> dict:
    _check(family, mask.width)
    checks = {'square': mask.width == mask.height, 'mode_l': mask.mode == 'L'}
    if not all(checks.values()):
        return {'valid': False, 'checks': checks}
    array = np.asarray(mask)
    checks['binary'] = bool(np.isin(array, [0, 255]).all())
    expected = expected_edges(family, mask.width)
    for side, edge in _edges(array).items():
        checks[f'edge_{side}'] = bool(np.array_equal(edge, expected[side]))
    components = _component_count(array)
    checks['one_connected_feature'] = components == 1
    rotated_expected = expected
    for turns in range(4):
        rotated = rotate_mask(mask, turns)
        checks[f'rotation_{turns * 90}_roundtrip'] = (
            rotate_mask(rotated, -turns).tobytes() == mask.tobytes())
        checks[f'rotation_{turns * 90}_edges'] = all(
            np.array_equal(edge, rotated_expected[side])
            for side, edge in _edges(np.asarray(rotated)).items())
        rotated_expected = dict(N=rotated_expected['W'][::-1], E=rotated_expected['N'],
                                S=rotated_expected['E'][::-1], W=rotated_expected['S'])
    return {'valid': all(checks.values()), 'checks': checks,
            'feature_components': components}


def metadata(family: str, size: int = 1254, seed: int = 41) -> dict:
    _check(family, size)
    edges = expected_edges(family, size)
    return {'family': family, 'resolution': [size, size], 'seed': seed,
            'coordinate_convention': 'inclusive pixel centers 0..size-1',
            'center_inclusive': [(size - 1) / 2] * 2,
            'center_continuous': [size / 2] * 2,
            'corner_tie_rule': 'full-edge feature owns shared transition pixels',
            'corners': dict(NW=[0, 0], NE=[size - 1, 0],
                            SE=[size - 1, size - 1], SW=[0, size - 1]),
            'edge_feature_pixel_counts': {key: int(np.count_nonzero(value))
                                          for key, value in edges.items()},
            'road_socket_width': socket_width(size, .10),
            'road_socket_inclusive': list(socket_bounds(size, .10)),
            'river_socket_width': socket_width(size, .20),
            'river_socket_inclusive': list(socket_bounds(size, .20)),
            'width_rounding': 'nearest even integer; exact half rounds up',
            'rotation': 'clockwise exact 90-degree transpose: (x,y) -> (size-1-y,x)',
            'mask_values': {'feature': 255, 'field': 0}}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path,
                        default=Path(__file__).resolve().parents[1] / 'templates/production_geometry')
    parser.add_argument('--size', type=int, default=1254)
    parser.add_argument('--seed', type=int, default=41)
    args = parser.parse_args()
    targets = [args.output_dir / f'{family}.{suffix}' for family in FAMILIES
               for suffix in ('png', 'json')]
    if any(path.exists() for path in targets):
        raise FileExistsError('template output exists; choose a new output directory')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for family in FAMILIES:
        mask = generate_mask(family, args.size, args.seed)
        record = metadata(family, args.size, args.seed)
        record['validation'] = validate_mask(mask, family)
        if not record['validation']['valid']:
            raise ValueError(f'invalid generated mask: {family}')
        mask.save(args.output_dir / f'{family}.png')
        (args.output_dir / f'{family}.json').write_text(json.dumps(record, indent=2) + '\n')
        print(f'{family}: PASS')


if __name__ == '__main__':
    main()
