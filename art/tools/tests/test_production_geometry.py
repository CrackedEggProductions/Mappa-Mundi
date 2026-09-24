"""Production families preserve full-edge ownership and exact socket grammar."""
import hashlib
import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from mask_utils import rotate_mask
from production_geometry import (FAMILIES, generate_mask, metadata, socket_bounds,
                                 socket_width, validate_mask)


class ProductionGeometryTests(unittest.TestCase):
    def test_all_native_families_valid(self):
        for family in FAMILIES:
            with self.subTest(family=family):
                mask = generate_mask(family)
                self.assertEqual(mask.size, (1254, 1254))
                self.assertEqual(mask.mode, 'L')
                self.assertTrue(validate_mask(mask, family)['valid'])

    def test_single_edge_corner_endpoints(self):
        pixels = np.asarray(generate_mask('full_edge_single', 128))
        self.assertTrue((pixels[0] == 255).all())
        self.assertTrue((pixels[1:, 0] == 0).all())
        self.assertTrue((pixels[1:, -1] == 0).all())
        self.assertTrue((pixels[-1] == 0).all())
        self.assertGreater(np.count_nonzero(pixels[:, 64]), 35)

    def test_opposite_connected_corridor(self):
        pixels = np.asarray(generate_mask('full_edge_opposite', 128))
        self.assertTrue((pixels[[0, -1]] == 255).all())
        self.assertTrue((pixels[1:-1, [0, -1]] == 0).all())
        self.assertTrue((pixels[:, 64] == 255).all())

    def test_road_native_socket_exact(self):
        self.assertEqual(socket_width(1254, .1), 126)
        self.assertEqual(socket_bounds(1254, .1), (564, 689))
        self.assertEqual(sum(socket_bounds(1254, .1)) / 2, 626.5)

    def test_river_native_socket_preserved(self):
        self.assertEqual(socket_width(1254, .2), 250)
        self.assertEqual(socket_bounds(1254, .2), (502, 751))
        self.assertEqual(sum(socket_bounds(1254, .2)) / 2, 626.5)
        pixels = np.asarray(generate_mask('river_socket'))
        self.assertEqual(np.count_nonzero(pixels[0]), 250)
        self.assertEqual(np.count_nonzero(pixels[-1]), 250)

    def test_three_way_only_has_canonical_exits(self):
        pixels = np.asarray(generate_mask('road_three_way'))
        for edge in (pixels[0], pixels[-1], pixels[:, -1]):
            self.assertEqual(np.flatnonzero(edge).tolist(), list(range(564, 690)))
        self.assertEqual(np.count_nonzero(pixels[:, 0]), 0)

    def test_socket_collar_stays_rigid(self):
        pixels = np.asarray(generate_mask('road_three_way'))
        for y in range(60):
            self.assertTrue(np.array_equal(pixels[y], pixels[0]))
            self.assertTrue(np.array_equal(pixels[-y - 1], pixels[-1]))
        for x in range(1194, 1254):
            self.assertTrue(np.array_equal(pixels[:, x], pixels[:, -1]))

    def test_seed_repeatability_and_variation(self):
        for family in FAMILIES:
            first = generate_mask(family, 128, 41).tobytes()
            self.assertEqual(first, generate_mask(family, 128, 41).tobytes())
            self.assertNotEqual(first, generate_mask(family, 128, 83).tobytes())

    def test_all_rotations_preserve_binary_pixels(self):
        for family in FAMILIES:
            original = generate_mask(family, 128)
            count = np.count_nonzero(np.asarray(original))
            for turns in range(4):
                rotated = rotate_mask(original, turns)
                self.assertEqual(np.count_nonzero(np.asarray(rotated)), count)
                self.assertEqual(rotate_mask(rotated, -turns).tobytes(), original.tobytes())

    def test_rotation_maps_north_socket_to_east(self):
        original = generate_mask('road_three_way', 128)
        rotated = np.asarray(rotate_mask(original, 1))
        self.assertTrue(np.array_equal(rotated[:, -1], np.asarray(original)[0]))
        self.assertEqual(np.count_nonzero(rotated[0]), 0)

    def test_validator_rejects_edge_leak(self):
        mask = generate_mask('full_edge_single', 128)
        mask.putpixel((0, 60), 255)
        report = validate_mask(mask, 'full_edge_single')
        self.assertFalse(report['valid'])
        self.assertFalse(report['checks']['edge_W'])

    def test_validator_rejects_disconnected_island(self):
        mask = generate_mask('full_edge_single', 128)
        mask.putpixel((64, 120), 255)
        report = validate_mask(mask, 'full_edge_single')
        self.assertEqual(report['feature_components'], 2)
        self.assertFalse(report['valid'])

    def test_validator_rejects_broken_belt(self):
        mask = generate_mask('full_edge_opposite', 128)
        pixels = np.asarray(mask).copy()
        pixels[64] = 0
        report = validate_mask(Image.fromarray(pixels), 'full_edge_opposite')
        self.assertFalse(report['valid'])
        self.assertEqual(report['feature_components'], 2)

    def test_validator_rejects_soft_mask(self):
        mask = generate_mask('road_three_way', 128)
        mask.putpixel((64, 64), 127)
        self.assertFalse(validate_mask(mask, 'road_three_way')['checks']['binary'])

    def test_validation_does_not_modify_source(self):
        mask = generate_mask('full_edge_opposite', 128)
        before = hashlib.sha256(mask.tobytes()).hexdigest()
        validate_mask(mask, 'full_edge_opposite')
        self.assertEqual(hashlib.sha256(mask.tobytes()).hexdigest(), before)

    def test_metadata_records_coordinates_and_widths(self):
        record = metadata('road_three_way')
        self.assertEqual(record['center_inclusive'], [626.5, 626.5])
        self.assertEqual(record['center_continuous'], [627, 627])
        self.assertEqual(record['edge_feature_pixel_counts'], dict(N=126, E=126, S=126, W=0))
        self.assertEqual(record['corners']['SE'], [1253, 1253])

    def test_odd_or_invalid_master_rejected(self):
        for size in (1253, 0, True):
            with self.assertRaises(ValueError):
                generate_mask('road_socket', size)
        with self.assertRaises(ValueError):
            generate_mask('unknown')

    def test_custom_opposite_inset_valid_and_deterministic(self):
        default = generate_mask('full_edge_opposite', 128)
        narrow = generate_mask('full_edge_opposite', 128, inset_fraction=0.37)
        again = generate_mask('full_edge_opposite', 128, inset_fraction=0.37)
        self.assertTrue(validate_mask(narrow, 'full_edge_opposite')['valid'])
        self.assertEqual(narrow.tobytes(), again.tobytes())
        self.assertLess(np.count_nonzero(np.asarray(narrow)[64]),
                        np.count_nonzero(np.asarray(default)[64]))
        for inset in (0.1, 0.4):
            mask = generate_mask('full_edge_opposite', 128, inset_fraction=inset)
            self.assertTrue(validate_mask(mask, 'full_edge_opposite')['valid'])

    def test_invalid_or_inapplicable_inset_rejected(self):
        for inset in (0.099, 0.401, float('nan'), float('inf')):
            with self.assertRaises(ValueError):
                generate_mask('full_edge_opposite', 128, inset_fraction=inset)
        with self.assertRaises(ValueError):
            generate_mask('full_edge_single', 128, inset_fraction=0.37)


if __name__ == '__main__':
    unittest.main()
