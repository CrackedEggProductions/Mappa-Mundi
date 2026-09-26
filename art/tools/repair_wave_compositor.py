"""Source-first Wave 02 wrapper around native edge-local socket sampling.

Fixed method limits are set before source evaluation: 8% transported area, 80px
p95, 120px maximum travel, 25% duplicate transported donors. Continuous sampling
of quiet bank margins can touch more pixels than isolated stamps while avoiding
visible bank cuts. These limits never authorize moving recognizable architecture;
the separate human flags remain mandatory and independently block unsuitable art.
"""
import argparse
import json
import shutil
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image

import production_wave_compositor as original
import repair_wave_sampler as sampler
from hybrid_wave_geometry import metadata, validate
from repair_wave_metrics import correction_report, repair_zone, verify_report

ROOT = original.ROOT
TILES = ('settlement_gate', 'riverside_hamlet', 'settlement_road_throughway')
BLOCKING_FLAGS = ('major_recognizable_objects_moved', 'repeated_motifs_introduced',
                  'source_rejected_before_composition')
METHOD_LIMITS = {'transported_percent': 8.0, 'displacement_p95_px': 80.0,
                 'displacement_max_px': 120.0, 'transported_donor_reuse_ratio': 0.25}
METHOD = 'native edge-local socket mapping; bank detail retained, no architectural remapping; integer provenance'


def paths(tile, version):
    if tile not in TILES or type(version) is not int or version not in (3, 4):
        raise ValueError('Wave 02 permits only its three designs at versions 3 or 4')
    stem = f'{tile}_v{version:02d}'
    review = ROOT / 'art/reviews/production_wave_02'
    return {
        'source': review / 'sources' / (stem + '.png'),
        'calibration': review / 'calibrations' / (stem + '.json'),
        'assessment': review / 'assessments' / (stem + '.json'),
        'candidate': ROOT / 'art/generated/candidates/production_wave_02' / tile / (stem + '.png'),
        'record': review / 'compositions' / (stem + '.json'),
        'provenance': review / 'provenance' / (stem + '.npz'),
        'masks': review / 'masks' / stem,
        'repair_zone': review / 'repair_zones' / (stem + '.png'),
        'correction_cost': review / 'correction_cost' / (stem + '.json'),
        'rejection': review / 'rejections' / (stem + '.json'),
    }


def _assessment(path):
    value = json.loads(path.read_text())
    if 'assessment' in value:
        if set(value) - {'assessment', 'limits'}:
            raise ValueError('unknown assessment file keys')
        limits = value.get('limits')
        return value['assessment'], dict(METHOD_LIMITS) if limits is None else limits
    return value, dict(METHOD_LIMITS)


def _backup(existing, rebuild):
    present = [p for p in existing if p.exists()]
    if present and not rebuild:
        raise FileExistsError('Existing products require --rebuild: ' + str(present[0]))
    stamp = datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    for path in present:
        shutil.copy2(path, str(path) + '.bak-' + stamp)


def _json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def build(tile, version, rebuild=False):
    p = paths(tile, version)
    products = [p[k] for k in ('candidate', 'record', 'provenance', 'repair_zone', 'correction_cost')]
    products += list(p['masks'].glob('*.png'))
    if not rebuild and any(path.exists() for path in products + [p['rejection']]):
        raise FileExistsError('Wave 02 products already exist; explicit --rebuild required')
    calibration = json.loads(p['calibration'].read_text())
    assessment, limits = _assessment(p['assessment'])
    with Image.open(p['source']) as image:
        source = image.convert('RGB')
    try:
        out, masks, origins, sx, sy, changed = sampler.render(source, calibration, tile)
    except ValueError as error:
        diagnostic = {'status': 'SOURCE REJECTED — NO NEW CANDIDATE WRITTEN',
                      'tile': tile, 'version': version, 'reasons': ['source:' + str(error)],
                      'correction_cost': None, 'geometry_validation': None,
                      'source': str(p['source'].relative_to(ROOT)),
                      'source_sha256': original.digest(p['source'])}
        _backup([p['rejection']], rebuild)
        _json(p['rejection'], diagnostic)
        return diagnostic
    geometry = validate(masks, metadata(tile))
    cost = correction_report(sx, sy, assessment, limits, source, out)
    blocked = [r for r in cost['rejection_reasons'] if r.startswith('limit:')]
    blocked += ['human:' + flag for flag in BLOCKING_FLAGS if assessment[flag] is True]
    if not geometry['valid']:
        blocked.append('geometry:invalid')
    if blocked:
        diagnostic = {'status': 'SOURCE REJECTED — NO NEW CANDIDATE WRITTEN',
                      'tile': tile, 'version': version, 'reasons': blocked,
                      'correction_cost': cost, 'geometry_validation': geometry,
                      'source': str(p['source'].relative_to(ROOT)),
                      'source_sha256': original.digest(p['source'])}
        _backup([p['rejection']], rebuild)
        _json(p['rejection'], diagnostic)
        return diagnostic
    # Rendering and every gate finish before any candidate product is touched.
    _backup(products, rebuild)
    for path in products:
        path.parent.mkdir(parents=True, exist_ok=True)
    p['masks'].mkdir(parents=True, exist_ok=True)
    for feature, mask in masks.items():
        mask.save(p['masks'] / (feature + '.png'))
    out.save(p['candidate'])
    np.savez_compressed(p['provenance'], source_x=sx, source_y=sy, owner=original.labels(masks))
    repair_zone(sx, sy).save(p['repair_zone'])
    _json(p['correction_cost'], cost)
    record = {
        'status': 'CANDIDATE — AWAITING HUMAN REVIEW', 'tile': tile, 'version': version,
        'method': METHOD,
        'repaired_pixels': int(changed.sum()), 'original_pixels_retained': int((~changed).sum()),
        'topology': metadata(tile), 'geometry_validation': geometry,
        'masks': str(p['masks'].relative_to(ROOT)), 'source_suitability': cost['source_suitability'],
        'limitation': 'Known geometry and donor provenance do not establish visual acceptance.',
    }
    for key in ('source', 'candidate', 'calibration', 'provenance', 'assessment', 'repair_zone', 'correction_cost'):
        record[key] = str(p[key].relative_to(ROOT))
        record[key + '_sha256'] = original.digest(p[key])
    _json(p['record'], record)
    return record


def _reconstruction_checks(record, source, candidate):
    """Rebuild the exact sampler output without changing another module's globals."""
    calibration = json.loads((ROOT / record['calibration']).read_text())
    out, masks, origins, sx, sy, changed = sampler.render(source, calibration, record['tile'])
    checks = {key + '_hash': original.digest(ROOT / record[key]) == record[key + '_sha256']
              for key in ('source', 'candidate', 'calibration', 'provenance')}
    checks['exact_reconstruction'] = candidate.tobytes() == out.tobytes() and candidate.size == out.size
    with np.load(ROOT / record['provenance'], allow_pickle=False) as maps:
        checks['coordinate_map'] = np.array_equal(maps['source_x'], sx) and np.array_equal(maps['source_y'], sy)
        checks['owner'] = np.array_equal(maps['owner'], original.labels(masks))
        checks['actual_donor_membership'] = np.array_equal(original.labels(origins)[sy, sx], maps['owner'])
    saved_masks_match = True
    for name, mask in masks.items():
        with Image.open(ROOT / record['masks'] / (name + '.png')) as saved:
            saved_masks_match &= saved.size == mask.size and saved.mode == mask.mode and saved.tobytes() == mask.tobytes()
    checks['saved_masks'] = saved_masks_match
    geometry = validate(masks, record['topology'])
    checks['geometry'] = geometry['valid']
    checks['canonical_topology'] = record['topology'] == metadata(record['tile'])
    checks['history_matches_geometry'] = geometry == record['geometry_validation']
    checks['retained_pixels'] = record['original_pixels_retained'] == int((~changed).sum())
    checks['repaired_pixels'] = record['repaired_pixels'] == int(changed.sum())
    checks['source_unchanged'] = original.digest(ROOT / record['source']) == record['source_sha256']
    checks['method'] = record['method'] == METHOD
    checks['native_resolution'] = out.size == candidate.size == source.size == (1254, 1254)
    pixels = np.asarray(out)
    for k in range(4):
        checks[f'rotation_{90*k}'] = np.array_equal(np.rot90(np.rot90(pixels, k), -k), pixels)
    return checks


def verify(path):
    """Replay sampler geometry/pixels, then authenticate cost and repair-zone data."""
    try:
        record = json.loads(Path(path).read_text())
        paths(record['tile'], record['version'])  # Restrict this wrapper's scope.
        cost = json.loads((ROOT / record['correction_cost']).read_text())
        assessment, limits = _assessment(ROOT / record['assessment'])
        with Image.open(ROOT / record['source']) as im:
            source = im.convert('RGB')
        with Image.open(ROOT / record['candidate']) as im:
            candidate = im.convert('RGB')
        checks = _reconstruction_checks(record, source, candidate)
        for key in ('assessment', 'repair_zone', 'correction_cost'):
            checks[key + '_hash'] = original.digest(ROOT / record[key]) == record[key + '_sha256']
        with np.load(ROOT / record['provenance'], allow_pickle=False) as maps:
            sx, sy = maps['source_x'], maps['source_y']
            expected = correction_report(sx, sy, assessment, limits, source, candidate)
            checks['cost_recomputed'] = verify_report(cost, sx, sy, source, candidate)
            checks['assessment_matches_cost'] = cost == expected
            checks['source_suitability_matches'] = record['source_suitability'] == cost['source_suitability']
            checks['source_not_blocked'] = not any(r.startswith('limit:') for r in cost['rejection_reasons'])
            checks['source_not_blocked'] &= not any(assessment[flag] is True for flag in BLOCKING_FLAGS)
            with Image.open(ROOT / record['repair_zone']) as image:
                zone = repair_zone(sx, sy)
                checks['repair_zone_exact'] = image.mode == 'L' and image.size == zone.size and image.tobytes() == zone.tobytes()
        return {'record': str(path), 'valid': all(checks.values()), 'checks': checks}
    except (KeyError, TypeError, ValueError, OSError) as error:
        return {'record': str(path), 'valid': False, 'checks': {'readable_evidence': False}, 'error': str(error)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tile', choices=TILES)
    parser.add_argument('--version', type=int, choices=(3, 4))
    parser.add_argument('--verify', nargs='+')
    parser.add_argument('--rebuild', action='store_true')
    args = parser.parse_args()
    if args.verify:
        results = [verify(path) for path in args.verify]
        for result in results:
            print('PASS' if result['valid'] else 'FAIL', result['record'],
                  sum(result['checks'].values()), '/', len(result['checks']))
        raise SystemExit(0 if all(r['valid'] for r in results) else 1)
    if args.tile is None or args.version is None:
        parser.error('--tile and --version required for composition')
    result = build(args.tile, args.version, args.rebuild)
    print(json.dumps({'status': result['status'], 'tile': result['tile'], 'version': result['version'],
                      'source_suitability': result.get('source_suitability'), 'reasons': result.get('reasons', [])}))
    raise SystemExit(2 if 'reasons' in result else 0)
