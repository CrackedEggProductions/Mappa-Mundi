"""Small socket corrections in quiet margins, preserving native city pixels.

No architecture is remapped. Source city footprints must already meet their
edges. Transport bank strips move together; integer samples retain original ink
and color. This is limited local resampling, not a whole-image warp or cloning.
"""
import numpy as np
from PIL import Image

from hybrid_wave_geometry import metadata, expected_edges, validate
from production_wave_compositor import source_masks, labels, fitted_targets, runs


def socket_map(length, source_interval, target_interval, bank=18, release=64):
    """Inverse line map; retain a unit-slope strip beside each bank."""
    slo, shi = source_interval
    tlo, thi = target_interval
    if not (0 <= slo < shi < length and 0 <= tlo < thi < length):
        raise ValueError('socket intervals outside image')
    bank = min(bank, (shi-slo)//3, (thi-tlo)//3)
    low = max(0, min(slo, tlo)-bank-release)
    high = min(length-1, max(shi, thi)+bank+release)
    target = [0, low, tlo-bank, tlo, tlo+bank,
              thi-bank, thi, thi+bank, high, length-1]
    source = [0, low, slo-bank, slo, slo+bank,
              shi-bank, shi, shi+bank, high, length-1]
    if any(b < a for a, b in zip(target, target[1:])) or any(
            b < a for a, b in zip(source, source[1:])):
        raise ValueError('insufficient quiet margin around socket')
    mapping = np.rint(np.interp(np.arange(length), target, source)).astype('int16')
    # Inclusive ownership is strict even where rounding reaches a bank early.
    mapping[:tlo] = np.minimum(mapping[:tlo], slo-1)
    mapping[tlo:thi+1] = np.clip(mapping[tlo:thi+1], slo, shi)
    mapping[thi+1:] = np.maximum(mapping[thi+1:], shi+1)
    return mapping


def render(source, calibration, tile):
    if source.size != (1254, 1254):
        raise ValueError('native 1254 source required')
    record = metadata(tile)
    origins = source_masks(calibration, 1254)
    transport = 'River' if tile == 'riverside_hamlet' else 'Road'
    if tile not in ('settlement_gate', 'riverside_hamlet', 'settlement_road_throughway'):
        raise ValueError('outside authorized repair designs')
    if set(origins) != {'Field', 'Settlement', transport}:
        raise ValueError('source feature count differs')
    city = np.asarray(origins['Settlement']) > 0
    if tile != 'settlement_road_throughway':
        a = np.asarray(origins[transport]).copy()
        a[city] = 0
        origins[transport] = Image.fromarray(a)
    target = fitted_targets(origins, tile, collar=128)
    # Preserve the source architecture footprint, not a preconceived inner wall.
    target['Settlement'] = origins['Settlement'].copy()
    edges = expected_edges(record, 'Settlement')
    a = np.asarray(target['Settlement'])
    if not all(np.array_equal(line, edges[side]) for side, line in
               zip('NESW', (a[0], a[:, -1], a[-1], a[:, 0]))):
        raise ValueError('source city edges require reconstruction; regenerate source')
    if tile != 'settlement_road_throughway':
        a = np.asarray(target[transport]).copy(); a[city] = 0
        target[transport] = Image.fromarray(a)
    covered = city | (np.asarray(target[transport]) > 0)
    target['Field'] = Image.fromarray(np.where(covered, 0, 255).astype('uint8'))
    yy, xx = np.indices((1254, 1254)); sy, sx = yy.copy(), xx.copy()
    original = np.asarray(origins[transport]); wanted = np.asarray(target[transport])
    for side, feature in record['edges'].items():
        if feature != transport:
            continue
        for depth in range(128):
            index = depth if side in ('N', 'W') else 1253-depth
            old = original[:, index] if side in ('E', 'W') else original[index]
            new = wanted[:, index] if side in ('E', 'W') else wanted[index]
            before, after = runs(old), runs(new)
            if len(before) != 1 or len(after) != 1:
                raise ValueError('source needs one continuous socket per margin')
            mapping = socket_map(1254, before[0], after[0])
            if side in ('E', 'W'):
                sy[:, index] = mapping
            else:
                sx[index] = mapping
    changed = (sx != xx) | (sy != yy)
    if np.any(changed & (city | city[sy, sx])):
        raise ValueError('correction would move architecture; regenerate source')
    if not np.array_equal(labels(origins)[sy, sx], labels(target)):
        raise ValueError('quiet socket mapping cannot supply target ownership')
    result = validate(target, record)
    if not result['valid']:
        raise ValueError('source topology unsuitable: ' + str(result))
    out = Image.fromarray(np.asarray(source.convert('RGB'))[sy, sx])
    return out, target, origins, sx.astype('int16'), sy.astype('int16'), changed
