"""Reconstruct saved geometry-wave candidates and verify persisted provenance."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

from build_seam_sheet import rotated, sha
from geometry_wave_compositor import FAMILIES, render
from production_geometry import validate_mask


def validate_record(record_path: Path, root: Path | None = None) -> dict:
    root = root or Path(__file__).resolve().parents[2]
    checks = {}
    errors = []
    try:
        record = json.loads(record_path.read_text())
        source_path = root / record['source']
        candidate_path = root / record['candidate']
        before = sha(source_path)
        checks['source_hash'] = before == record['source_sha256']
        checks['candidate_hash'] = sha(candidate_path) == record['candidate_sha256']
        calibration = json.loads((root / record['calibration_file']).read_text())
        checks['calibration_file_matches_record'] = calibration == record['calibration']
        checks['family_matches_tile'] = record['family'] == FAMILIES[record['tile']]
        with Image.open(source_path) as opened:
            source = opened.convert('RGB')
        with Image.open(candidate_path) as opened:
            candidate = opened.copy()
        expected, mask, source_mask, provenance, xs, ys = render(
            source, record['tile'], calibration, record['seed'])
        checks['native_dimensions'] = (source.size == candidate.size == mask.size
                                       == tuple(record['size']))
        checks['candidate_rgb'] = candidate.mode == 'RGB'
        checks['candidate_exact_reconstruction'] = candidate.tobytes() == expected.tobytes()
        checks['coordinate_hash'] = hashlib.sha256(xs.tobytes() + ys.tobytes()).hexdigest() == record['coordinates_sha256']
        for key, reconstructed in (('mask', mask), ('source_mask', source_mask), ('provenance', provenance)):
            with Image.open(root / record[key]) as opened:
                saved = opened.copy()
            checks[f'{key}_exact_reconstruction'] = (
                saved.mode == 'L' and saved.size == reconstructed.size
                and saved.tobytes() == reconstructed.tobytes())
        checks['provenance_matches_authoritative_mask'] = provenance.tobytes() == mask.tobytes()
        fresh = validate_mask(mask, record['family'])
        checks['fresh_geometry_valid'] = fresh['valid']
        checks['geometry_record_matches_fresh'] = fresh == record['geometry_validation']
        for angle in (0, 90, 180, 270):
            inverse = (-angle) % 360
            for name, image in (('candidate', candidate), ('mask', mask)):
                checks[f'{name}_rotation_{angle}_lossless'] = (
                    rotated(rotated(image, angle), inverse).tobytes() == image.tobytes())
        checks['source_unchanged'] = sha(source_path) == before
    except (OSError, ValueError, KeyError, TypeError) as error:
        errors.append(f'{type(error).__name__}: {error}')
    return {'record': str(record_path), 'valid': bool(checks) and all(checks.values()) and not errors,
            'checks': checks, 'errors': errors,
            'scope': 'Exact deterministic mask/pixel provenance; source semantic traces still require human review.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('records', type=Path, nargs='+')
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.output and args.output.exists():
        raise FileExistsError('validation output exists; choose an unused output path')
    results = [validate_record(path, args.root) for path in args.records]
    report = dict(valid=all(result['valid'] for result in results), results=results)
    encoded = json.dumps(report, indent=2) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open('x') as handle:
            handle.write(encoded)
    for result in results:
        print(('PASS' if result['valid'] else 'FAIL'), Path(result['record']).name,
              f"{sum(result['checks'].values())}/{len(result['checks'])} checks")
    raise SystemExit(0 if report['valid'] else 1)


if __name__ == '__main__':
    main()
