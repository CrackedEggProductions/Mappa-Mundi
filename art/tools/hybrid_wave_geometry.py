"""Known multi-feature geometry for the first hybrid tile production wave.

Masks describe feature membership, not inferred image semantics. Settlement
Road Throughway alone permits interior Road/Settlement overlap: a street in a
connected district. It never introduces a dual-type outer edge.
"""
import argparse
import json
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from production_geometry import generate_mask, socket_bounds, socket_width
from production_geometry import _component_count, _edges

TILES = {
    'settlement_throughway': ('Settlement', 'Field', 'Settlement', 'Field'),
    'settlement_gate': ('Settlement', 'Road', 'Field', 'Field'),
    'riverside_hamlet': ('Settlement', 'River', 'Field', 'River'),
    'woodland_road': ('Forest', 'Forest', 'Road', 'Road'),
    'woodland_river': ('Forest', 'Forest', 'River', 'River'),
    'settlement_corner_gate': ('Settlement', 'Settlement', 'Road', 'Field'),
    'settlement_road_bend': ('Settlement', 'Settlement', 'Road', 'Road'),
    'settlement_road_throughway': ('Settlement', 'Road', 'Settlement', 'Road'),
}
RELATIONSHIPS = {
    'settlement_gate': ('Road', 'Settlement', 'access', 'terminates'),
    'riverside_hamlet': ('River', 'Settlement', 'touch', 'through'),
    'woodland_river': ('River', 'Forest', 'touch', 'through'),
    'settlement_corner_gate': ('Road', 'Settlement', 'access', 'terminates'),
    'settlement_road_bend': ('Road', 'Settlement', 'access', 'through'),
    'settlement_road_throughway': ('Road', 'Settlement', 'access', 'through'),
}
COLORS = {'Settlement': '#c6a288', 'Forest': '#76876c', 'Road': '#c6ab79',
          'River': '#9ebdc6', 'Field': '#e4dfc7'}


def _curve(points: list[tuple[float, float]], size: int) -> list[tuple[int, int]]:
    """Cubic Bezier at dense integer samples, joined without interpolation."""
    result = []
    for t in np.linspace(0, 1, size * 2):
        weights = ((1-t)**3, 3*(1-t)**2*t, 3*(1-t)*t*t, t**3)
        result.append(tuple(round(sum(w*p[d] for w, p in zip(weights, points))
                                  * (size-1)) for d in (0, 1)))
    return result


def _transport(tile: str, feature: str, size: int, seed: int) -> np.ndarray:
    fraction = .2 if feature == 'River' else .1
    width = socket_width(size, fraction)
    rng = random.Random(seed)
    delta = rng.uniform(-.012, .012)
    if tile == 'settlement_gate':
        points = [(1,.5), (.77,.5), (.59,.41+delta), (.50,.30)]
    elif tile == 'settlement_corner_gate':
        points = [(.5,1), (.5,.75), (.47,.59+delta), (.60,.39)]
    elif tile in ('riverside_hamlet', 'settlement_road_throughway'):
        points = [(0,.5), (.32,.5+delta), (.68,.5-delta), (1,.5)]
    elif tile == 'woodland_road':
        points = [(0,.5), (.51,.49+delta), (.51,.49+delta), (.5,1)]
    else:
        # Deliberately approaches the diagonal region. Clipping the transport
        # against that region creates an explicit shared bank/gate boundary.
        points = [(0,.5), (.59,.46+delta), (.54,.42+delta), (.5,1)]
    image = Image.new('L', (size, size))
    ImageDraw.Draw(image).line(_curve(points, size), fill=255, width=width,
                               joint='curve')
    pixels = np.array(image)
    lo, hi = socket_bounds(size, fraction)
    # Rigid socket collars; connected to the same continuously drawn path.
    collar = max(2, round(size * 24 / 1254))
    for side, edge_feature in zip('NESW', TILES[tile]):
        if edge_feature == feature:
            if side == 'N': pixels[:collar, lo:hi+1] = 255
            if side == 'E': pixels[lo:hi+1, -collar:] = 255
            if side == 'S': pixels[-collar:, lo:hi+1] = 255
            if side == 'W': pixels[lo:hi+1, :collar] = 255
    pixels[[0,-1], :] = 0
    pixels[:, [0,-1]] = 0
    for side, edge_feature in zip('NESW', TILES[tile]):
        if edge_feature == feature:
            _edges(pixels)[side][lo:hi+1] = 255
    return pixels


def generate(tile: str, seed: int = 41, size: int = 1254) -> dict[str, Image.Image]:
    if tile not in TILES:
        raise ValueError(f'unknown production-wave tile: {tile}')
    region = 'Forest' if tile.startswith('woodland') else 'Settlement'
    family = ('full_edge_opposite' if tile.endswith('throughway') else
              'full_edge_single' if tile in ('settlement_gate', 'riverside_hamlet')
              else 'full_edge_corner')
    array = np.array(generate_mask(family, size, seed))
    masks = {region: array}
    transport = next((f for f in TILES[tile] if f in ('Road', 'River')), None)
    if transport:
        pixels = _transport(tile, transport, size, seed)
        if tile != 'settlement_road_throughway':
            pixels[array != 0] = 0
        masks[transport] = pixels
    masks['Field'] = np.where(np.logical_or.reduce([p != 0 for p in masks.values()]),
                             0, 255).astype(np.uint8)
    return {name: Image.fromarray(pixels) for name, pixels in masks.items()}


def metadata(tile: str, seed: int = 41, size: int = 1254) -> dict:
    edges = dict(zip('NESW', TILES[tile]))
    relationship = RELATIONSHIPS.get(tile)
    return {
        'tile': tile, 'seed': seed, 'resolution': [size, size], 'edges': edges,
        'coordinate_convention': 'inclusive pixel centers 0..size-1',
        'corner_tie_rule': 'full-edge feature owns shared transition pixel',
        'components': {name: 1 for name in sorted(set(edges.values()) - {'Field'})},
        'relationships': ([dict(first=relationship[0], second=relationship[1],
                                kind=relationship[2], route=relationship[3])]
                          if relationship else []),
        'allowed_interior_overlap': ([['Road', 'Settlement']]
                                     if tile == 'settlement_road_throughway' else []),
        'overlap_meaning': 'A distinct Road street inside one connected district; '
                           'never a dual-type edge or merged feature identity.',
        'road_socket': dict(width=socket_width(size,.1),
                            inclusive=list(socket_bounds(size,.1)), center=(size-1)/2),
        'river_socket': dict(width=socket_width(size,.2),
                             inclusive=list(socket_bounds(size,.2)), center=(size-1)/2),
        'rotation': 'clockwise exact 90-degree transpose; no resampling',
        'brief': f'art/briefs/tiles/{tile}.md',
    }


def expected_edges(record: dict, feature: str) -> dict[str, np.ndarray]:
    size = record['resolution'][0]
    expected = {side: np.zeros(size, dtype=np.uint8) for side in 'NESW'}
    for side, edge_feature in record['edges'].items():
        if edge_feature != feature:
            continue
        if feature in ('Road', 'River'):
            lo, hi = record[f'{feature.lower()}_socket']['inclusive']
            expected[side][lo:hi+1] = 255
        elif feature != 'Field':
            expected[side][:] = 255
    if feature in ('Forest', 'Settlement'):
        # Each corner is a shared pixel; full-edge ownership wins the tie.
        for a, ai, b, bi in (('N',0,'W',0), ('N',-1,'E',0),
                             ('S',0,'W',-1), ('S',-1,'E',-1)):
            if expected[a][ai] or expected[b][bi]:
                expected[a][ai] = expected[b][bi] = 255
    if feature == 'Field':
        for name in record['components']:
            other = expected_edges(record, name)
            for side in expected:
                expected[side] |= other[side]
        expected = {side: 255-pixels for side,pixels in expected.items()}
    return expected


def _touch_count(first: np.ndarray, second: np.ndarray) -> int:
    a, b = first != 0, second != 0
    count = np.count_nonzero(a & b)
    for shifted_a, shifted_b in ((a[1:], b[:-1]), (a[:-1], b[1:]),
                                 (a[:,1:], b[:,:-1]), (a[:,:-1], b[:,1:])):
        count += np.count_nonzero(shifted_a & shifted_b)
    return int(count)


def validate(masks: dict[str, Image.Image], record: dict) -> dict:
    checks = {}
    size = record['resolution'][0]
    canonical = metadata(record['tile'],record['seed'],size)
    checks['canonical_topology'] = all(record.get(key) == canonical[key] for key in
        ('edges','components','relationships','allowed_interior_overlap',
         'road_socket','river_socket','coordinate_convention','corner_tie_rule'))
    names = set(record['components']) | {'Field'}
    checks['correct_feature_identities'] = set(masks) == names
    checks['native_dimensions'] = all(m.size == (size,size) and m.mode == 'L'
                                     for m in masks.values())
    if not all(checks.values()):
        return dict(valid=False, checks=checks)
    arrays = {name: np.asarray(image) for name,image in masks.items()}
    components = {}
    for name, pixels in arrays.items():
        checks[f'{name}_binary'] = bool(np.isin(pixels, [0,255]).all())
        expected = expected_edges(record, name)
        for side, values in _edges(pixels).items():
            checks[f'{name}_edge_{side}'] = bool(np.array_equal(values,expected[side]))
        if name != 'Field':
            components[name] = _component_count(pixels)
            checks[f'{name}_one_connected_component'] = components[name] == 1
        for turns in range(4):
            rotated = np.rot90(pixels, -turns)
            rotated_expected = expected
            for _ in range(turns):
                rotated_expected = dict(N=rotated_expected['W'][::-1],
                                        E=rotated_expected['N'],
                                        S=rotated_expected['E'][::-1],
                                        W=rotated_expected['S'])
            checks[f'{name}_rotation_{turns*90}'] = bool(
                np.array_equal(np.rot90(rotated,turns),pixels) and all(
                    np.array_equal(values,rotated_expected[side])
                    for side,values in _edges(rotated).items()))
    checks['complete_coverage'] = bool(np.logical_or.reduce(
        [a != 0 for a in arrays.values()]).all())
    allowed = {frozenset(pair) for pair in record['allowed_interior_overlap']}
    for i, first in enumerate(sorted(arrays)):
        for second in sorted(arrays)[i+1:]:
            overlap = (arrays[first] != 0) & (arrays[second] != 0)
            permitted = frozenset((first,second)) in allowed
            checks[f'{first}_{second}_overlap'] = bool(
                not overlap.any() or (permitted and not any(e.any()
                                      for e in _edges(overlap).values())))
    contacts = {}
    for relation in record['relationships']:
        key = f"{relation['first']}_{relation['second']}_{relation['kind']}"
        contacts[key] = _touch_count(arrays[relation['first']], arrays[relation['second']])
        checks[key] = contacts[key] > 0
    return dict(valid=all(checks.values()), checks=checks,
                feature_components=components, contact_pixel_pairs=contacts)


def guide(masks: dict[str, Image.Image], record: dict) -> Image.Image:
    """Colored mechanical underlay; labels belong to this guide, never art."""
    size = record['resolution'][0]
    image = Image.new('RGB', (size,size), COLORS['Field'])
    for name in ('Settlement', 'Forest', 'Road', 'River'):
        if name in masks:
            image.paste(COLORS[name], mask=masks[name])
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default(size=max(12,round(size*.021)))
    for name in ('Settlement', 'Forest', 'Road', 'River', 'Field'):
        if name not in masks:
            continue
        ys,xs = np.nonzero(np.asarray(masks[name]))
        if len(xs):
            if name in ('Settlement','Forest'):
                target = (.70,.20) if record['edges']['E']==name else (.50,.20)
            elif name == 'Field':
                target = (.10,.30) if record['tile'].endswith('throughway') else (.18,.82)
            else:
                side = next(s for s,f in record['edges'].items() if f==name)
                target = dict(N=(.5,.15),E=(.85,.5),S=(.5,.85),W=(.15,.5))[side]
            nearest = np.argmin((xs-size*target[0])**2+(ys-size*target[1])**2)
            draw.text((int(xs[nearest]),int(ys[nearest])), name,
                      fill='#332a20', font=font, anchor='mm', stroke_width=1,
                      stroke_fill=COLORS[name])
    return image


def export(output: Path, seed: int = 41, size: int = 1254) -> None:
    """Never overwrite existing masks; a changed template is a new version."""
    if output.exists() and any(output.iterdir()):
        raise FileExistsError(f'template destination is not empty: {output}')
    built = []
    for tile in TILES:
        masks, record = generate(tile,seed,size), metadata(tile,seed,size)
        record['validation'] = validate(masks,record)
        if not record['validation']['valid']:
            raise ValueError(f'invalid template for {tile}: {record["validation"]}')
        built.append((tile,masks,record))
    for tile,masks,record in built:
        folder = output / tile
        folder.mkdir(parents=True,exist_ok=True)
        for feature,image in masks.items():
            image.save(folder / f'{feature}.png')
        guide(masks,record).save(folder / 'guide.png')
        (folder / 'topology.json').write_text(json.dumps(record,indent=2)+'\n')
        print(f'{tile}: PASS ({sum(record["validation"]["checks"].values())} checks)')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]
                        / 'templates/production_wave_01')
    parser.add_argument('--seed',type=int,default=41)
    args = parser.parse_args()
    export(args.output,args.seed)


if __name__ == '__main__':
    main()
