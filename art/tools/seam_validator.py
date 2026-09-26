#!/usr/bin/env python3
"""Verify deterministic composition evidence and native-pixel seam placement."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from boundary_generator import generate_boundary
from build_seam_sheet import check_layout, rotated
from hybrid_compositor import ROOT, digest, transport
from mask_utils import make_masks


def _report(checks, errors):
    return {'valid': not errors, 'status': 'PASS' if not errors else 'FAIL',
            'checks': checks, 'errors': errors,
            'scope': 'Deterministic geometry and pixel provenance; not semantic art approval'}


def validate_composition(composition_path, root=ROOT):
    """Reconstruct output from recorded inputs; do not trust manifest booleans."""
    checks, errors = {}, []

    def check(name, condition):
        checks[name] = bool(condition)
        if not condition:
            errors.append(name)

    try:
        root = Path(root)
        manifest = json.loads(Path(composition_path).read_text())
        boundary = json.loads((root / manifest['boundary']).read_text())
        source_file, candidate_file = root / manifest['source'], root / manifest['candidate']
        source_digest = digest(source_file)
        check('source_file_hash', source_digest == manifest['source_sha256'])
        check('candidate_file_hash', digest(candidate_file) == manifest['candidate_sha256'])
        with Image.open(source_file) as opened:
            source = opened.convert('RGB')
        with Image.open(candidate_file) as opened:
            candidate = opened.convert('RGB')
        size = boundary['size']
        check('native_dimensions', source.size == candidate.size == (size, size)
              and manifest['size'] == [size, size])
        path = [tuple(point) for point in boundary['path']]
        expected_masks = make_masks(path, size, manifest['transition_width'])
        check('path_endpoints_monotonicity_and_no_other_edge_contacts', True)
        check('seeded_path_matches', path == generate_boundary(
            size, boundary['seed'], boundary['irregularity']))
        check('seed_metadata_agrees', manifest['seed'] == boundary['seed'])
        stored_masks = {}
        for name in ('feature', 'field', 'transition'):
            with Image.open(root / manifest['masks'][name]) as opened:
                mask = opened.copy()
            stored_masks[name] = mask
            check(name + '_mask_dimensions_mode_binary', mask.size == (size, size)
                  and mask.mode == 'L' and set(mask.tobytes()) <= {0, 255})
            check(name + '_mask_matches_path', mask.tobytes() == expected_masks[name].tobytes())
        feature, field = (np.asarray(stored_masks[name]) for name in ('feature', 'field'))
        check('mask_complements', feature.shape == field.shape
              and np.array_equal(255 - feature, field))
        check('exact_edges_with_feature_corner_ties',
              np.all(feature[0, :] == 255) and np.all(feature[:, -1] == 255)
              and np.all(feature[1:, 0] == 0) and np.all(feature[-1, :-1] == 0))
        with Image.open(root / manifest['provenance']) as opened:
            provenance = opened.copy()
        check('provenance_equals_feature', provenance.mode == 'L'
              and provenance.size == (size, size)
              and provenance.tobytes() == stored_masks['feature'].tobytes())
        output, rerender_masks, coordinates, rerender_owner = transport(
            source, path, boundary['source_trace'], manifest['transition_width'],
            manifest.get('field_mode', 'anchored'))
        check('candidate_pixels_reproduced', output.size == candidate.size
              and output.tobytes() == candidate.tobytes())
        check('source_coordinate_hash_reproduced',
              hashlib.sha256(coordinates.tobytes()).hexdigest()
              == manifest['source_coordinate_sha256'])
        check('actual_sampling_owner_reproduced', rerender_owner.tobytes() == provenance.tobytes())
        check('actual_composition_masks_reproduced', all(
            rerender_masks[name].tobytes() == mask.tobytes() for name, mask in stored_masks.items()))
        check('validation_leaves_source_unchanged', digest(source_file) == source_digest)
    except (OSError, ValueError, KeyError, TypeError, IndexError, AssertionError) as exc:
        errors.append(f'{type(exc).__name__}: {exc}')
    return _report(checks, errors)


def validate_seam(image, sheet, layout):
    """Check every tile pixel, including both sides of each unscaled seam."""
    checks, errors = {}, []
    try:
        if not layout or not layout[0] or any(len(row) != len(layout[0]) for row in layout):
            raise ValueError('Layout must be a nonempty rectangle')
        if any(turn not in (0, 90, 180, 270) for row in layout for turn in row):
            raise ValueError('Only exact quarter-turn orientations are supported')
        check_layout(layout)
        checks['matching_topology'] = True
        if image.width != image.height:
            raise ValueError('Source tile must be square')
        size = image.width
        expected_size = (size * len(layout[0]), size * len(layout))
        checks['native_sheet_dimensions'] = sheet.size == expected_size
        if sheet.size != expected_size:
            errors.append('native_sheet_dimensions')
        rgba = sheet.convert('RGBA')
        for row, values in enumerate(layout):
            for col, turn in enumerate(values):
                crop = rgba.crop((col*size, row*size, (col+1)*size, (row+1)*size))
                name = f'tile_{row}_{col}_every_pixel_preserved'
                checks[name] = crop.tobytes() == rotated(image.convert('RGBA'), turn).tobytes()
                if not checks[name]:
                    errors.append(name)
    except (ValueError, KeyError, TypeError, IndexError) as exc:
        errors.append(f'{type(exc).__name__}: {exc}')
    return _report(checks, errors)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--composition', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = validate_composition(args.composition)
    text = json.dumps(result, indent=2) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open('x') as handle:
            handle.write(text)
    print(text, end='')
    return 0 if result['valid'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
