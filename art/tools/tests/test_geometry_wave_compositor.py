"""Deterministic illustration transport and saved-output provenance regressions."""
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from build_seam_sheet import sha
from geometry_wave_compositor import FAMILIES, interval_coordinates, render
from geometry_wave_validator import validate_record
from production_geometry import validate_mask


def source_image(size=64):
    image = Image.new('RGB', (size, size))
    image.putdata([(x * 3, y * 3, (x + y) % 128) for y in range(size) for x in range(size)])
    return image


def calibration_for(tile):
    if tile == 'forest_edge':
        return {'frontier': [[0, 10], [32, 32], [63, 10]]}
    if tile == 'road_junction':
        return {'collar': 12, 'ports': dict(N=[24, 39], E=[24, 39], S=[24, 39]),
                'polygon': [(24, 0), (39, 0), (39, 24), (63, 24), (63, 39),
                            (39, 39), (39, 63), (24, 63)]}
    return {'left': [[0, 6], [32, 16], [63, 6]],
            'right': [[0, 57], [32, 47], [63, 57]]}


class GeometryWaveCompositorTests(unittest.TestCase):
    def test_interval_mapping_monotonic(self):
        for source_lo, source_hi, target_lo, target_hi in (
                (10, 45, 0, 63), (0, 30, 0, 0), (8, 55, 16, 47), (8, 55, 0, 63)):
            coords = interval_coordinates(64, source_lo, source_hi, target_lo, target_hi)
            self.assertTrue((np.diff(coords) >= 0).all())
            self.assertTrue(((coords >= 0) & (coords <= 63)).all())

    def test_invalid_interval_rejected(self):
        with self.assertRaises(ValueError):
            interval_coordinates(64, 20, 10, 5, 50)

    def test_all_families_native_and_owned(self):
        source = source_image()
        for tile in FAMILIES:
            with self.subTest(tile=tile):
                output, mask, source_mask, provenance, xs, ys = render(source, tile, calibration_for(tile))
                self.assertEqual(output.size, source.size)
                self.assertTrue(validate_mask(mask, FAMILIES[tile])['valid'])
                self.assertEqual(mask.tobytes(), provenance.tobytes())
                actual = np.asarray(source_mask)[np.rint(ys).astype(int), np.rint(xs).astype(int)]
                self.assertTrue(np.array_equal(actual, np.asarray(mask)))

    def test_render_deterministic_and_source_unchanged(self):
        source = source_image()
        before = source.tobytes()
        for tile in FAMILIES:
            first = render(source, tile, calibration_for(tile), 41)
            again = render(source, tile, calibration_for(tile), 41)
            for index in range(4):
                self.assertEqual(first[index].tobytes(), again[index].tobytes())
            self.assertTrue(np.array_equal(first[4], again[4]))
            self.assertTrue(np.array_equal(first[5], again[5]))
        self.assertEqual(before, source.tobytes())

    def test_distinct_region_seed_changes_interior(self):
        source = source_image()
        a = render(source, 'forest_belt', calibration_for('forest_belt'), 41)
        b = render(source, 'forest_belt', calibration_for('forest_belt'), 83)
        self.assertNotEqual(a[1].tobytes(), b[1].tobytes())
        self.assertEqual(np.asarray(a[1])[0].tobytes(), np.asarray(b[1])[0].tobytes())

    def test_road_collar_exact_ports_and_preserved_center(self):
        source = source_image()
        output, mask, _, _, xs, ys = render(source, 'road_junction', calibration_for('road_junction'))
        pixels = np.asarray(mask)
        for edge in (pixels[0], pixels[-1], pixels[:, -1]):
            self.assertEqual(np.flatnonzero(edge).tolist(), list(range(29, 35)))
        self.assertEqual(xs[32, 32], 32)
        self.assertEqual(ys[32, 32], 32)
        self.assertEqual(output.getpixel((32, 32)), source.getpixel((32, 32)))

    def _record(self, root):
        tile = 'forest_belt'
        source = source_image()
        calibration = calibration_for(tile)
        source.save(root / 'source.png')
        output, mask, source_mask, provenance, xs, ys = render(source, tile, calibration)
        for name, image in [('candidate', output), ('mask', mask), ('source_mask', source_mask), ('provenance', provenance)]:
            image.save(root / f'{name}.png')
        (root / 'calibration.json').write_text(json.dumps(calibration))
        record = dict(tile=tile, family=FAMILIES[tile], seed=41, size=[64, 64],
                      source='source.png', source_sha256=sha(root / 'source.png'),
                      candidate='candidate.png', candidate_sha256=sha(root / 'candidate.png'),
                      mask='mask.png', source_mask='source_mask.png', provenance='provenance.png',
                      calibration=calibration, calibration_file='calibration.json',
                      coordinates_sha256=hashlib.sha256(xs.tobytes() + ys.tobytes()).hexdigest(),
                      geometry_validation=validate_mask(mask, FAMILIES[tile]))
        path = root / 'composition.json'
        path.write_text(json.dumps(record))
        return path

    def test_saved_reconstruction_passes(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
            root = Path(directory)
            report = validate_record(self._record(root), root)
            self.assertTrue(report['valid'], report)
            self.assertGreaterEqual(len(report['checks']), 20)

    def test_corrupted_output_rejected(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
            root = Path(directory)
            record = self._record(root)
            with Image.open(root / 'candidate.png') as opened:
                image = opened.copy()
            image.putpixel((0, 0), (255, 0, 0))
            image.save(root / 'candidate.png')
            report = validate_record(record, root)
            self.assertFalse(report['valid'])
            self.assertFalse(report['checks']['candidate_exact_reconstruction'])

    def test_orphan_mask_rejected(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
            root = Path(directory)
            record = self._record(root)
            Image.new('L', (64, 64)).save(root / 'mask.png')
            report = validate_record(record, root)
            self.assertFalse(report['valid'])
            self.assertFalse(report['checks']['mask_exact_reconstruction'])

    def test_corrupted_provenance_rejected(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
            root = Path(directory)
            record = self._record(root)
            Image.new('L', (64, 64)).save(root / 'provenance.png')
            report = validate_record(record, root)
            self.assertFalse(report['valid'])
            self.assertFalse(report['checks']['provenance_exact_reconstruction'])

    def test_calibration_change_rejected(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as directory:
            root = Path(directory)
            record = self._record(root)
            calibration = calibration_for('forest_belt')
            calibration['left'][1][1] = 17
            (root / 'calibration.json').write_text(json.dumps(calibration))
            report = validate_record(record, root)
            self.assertFalse(report['valid'])
            self.assertFalse(report['checks']['calibration_file_matches_record'])

    def test_non_square_source_rejected(self):
        with self.assertRaises(ValueError):
            render(Image.new('RGB', (64, 32)), 'forest_belt', calibration_for('forest_belt'))


if __name__ == '__main__':
    unittest.main()
