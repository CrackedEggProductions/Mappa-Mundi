"""Geometry guarantees independent of image semantics or subjective review."""
import math
from pathlib import Path
import random
import sys
import unittest
from PIL import ImageChops

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from boundary_generator import generate_boundary, rotate_path
from mask_utils import make_masks, rotate_mask


class BoundaryTests(unittest.TestCase):
    def test_endpoints_and_native_column_count(self):
        path = generate_boundary()
        self.assertEqual(len(path), 1254)
        self.assertEqual(path[0], (0, 0))
        self.assertEqual(path[-1], (1253, 1253))
        self.assertEqual([x for x, _ in path], list(range(1254)))

    def test_seed_is_deterministic(self):
        self.assertEqual(generate_boundary(seed=17), generate_boundary(seed=17))

    def test_seed_changes_interior(self):
        self.assertNotEqual(generate_boundary(seed=17)[1:-1],
                            generate_boundary(seed=18)[1:-1])

    def test_zero_irregularity_is_diagonal(self):
        for x, y in generate_boundary(67, irregularity=0):
            self.assertAlmostEqual(x, y)

    def test_monotone_graph_cannot_self_intersect_or_double_back(self):
        for seed in range(20):
            path = generate_boundary(191, seed, 0.2)
            for (x0, y0), (x1, y1) in zip(path, path[1:]):
                self.assertGreater(x1, x0)
                self.assertGreater(y1, y0)
                self.assertGreaterEqual((y1-y0)/(x1-x0), 0.35 - 1e-10)
                # Nonadjacent segments have disjoint x intervals.
            self.assertTrue(all(0 < x < 190 and 0 < y < 190
                                for x, y in path[1:-1]))

    def test_displacement_is_bounded(self):
        path = generate_boundary(201, 55, 0.03)
        self.assertLessEqual(max(abs(y-x) for x, y in path), 201 * 0.03)

    def test_rotation_coordinates_and_round_trip(self):
        path = generate_boundary(31, 24)
        rotated = rotate_path(path, 31, 1)
        self.assertEqual(rotated[0], (30, 0))
        self.assertEqual(rotated[-1], (0, 30))
        for actual, expected in zip(rotate_path(rotated, 31, 3), path):
            self.assertAlmostEqual(actual[0], expected[0])
            self.assertAlmostEqual(actual[1], expected[1])

    def test_private_rng_does_not_consume_global_rng(self):
        before = random.getstate()
        generate_boundary(seed=123)
        self.assertEqual(before, random.getstate())

    def test_bad_parameters_rejected(self):
        for kwargs in ({'size': 2}, {'size': True}, {'irregularity': -0.1},
                       {'irregularity': math.nan}, {'irregularity': 0.3}):
            with self.assertRaises(ValueError):
                generate_boundary(**kwargs)


class MaskTests(unittest.TestCase):
    def setUp(self):
        self.size = 1254
        self.path = generate_boundary(self.size, 71)
        self.masks = make_masks(self.path, self.size, 60)

    def test_native_dimensions_and_binary_values(self):
        for mask in self.masks.values():
            self.assertEqual(mask.size, (1254, 1254))
            self.assertEqual(mask.mode, 'L')
            self.assertEqual(set(mask.tobytes()), {0, 255})

    def test_exact_full_edge_ownership_with_shared_corner_ties(self):
        m = self.masks['feature']
        last = self.size-1
        self.assertTrue(all(m.getpixel((x, 0)) == 255 for x in range(self.size)))
        self.assertTrue(all(m.getpixel((last, y)) == 255 for y in range(self.size)))
        self.assertTrue(all(m.getpixel((0, y)) == 0 for y in range(1, self.size)))
        self.assertTrue(all(m.getpixel((x, last)) == 0 for x in range(last)))

    def test_complement_has_neither_gaps_nor_overlap(self):
        feature, field = self.masks['feature'], self.masks['field']
        self.assertEqual(ImageChops.add(feature, field).getextrema(), (255, 255))
        self.assertEqual(ImageChops.multiply(feature, field).getextrema(), (0, 0))

    def test_band_has_no_outer_edge_pixels_and_bounded_column_width(self):
        band = self.masks['transition']
        for i in range(self.size):
            for point in ((0, i), (1253, i), (i, 0), (i, 1253)):
                self.assertEqual(band.getpixel(point), 0)
            self.assertLessEqual(sum(band.crop((i, 0, i+1, 1254)).tobytes()) // 255, 60)

    def test_zero_band_is_empty(self):
        self.assertIsNone(make_masks(self.path, self.size, 0)['transition'].getbbox())

    def test_rotation_preserves_each_pixel_and_complement(self):
        feature = self.masks['feature']
        rotated = rotate_mask(feature, 1)
        for x, y in ((0, 0), (1253, 1253), (86, 39), (867, 300), (32, 66)):
            self.assertEqual(rotated.getpixel((1253-y, x)), feature.getpixel((x, y)))
        self.assertEqual(rotate_mask(rotated, 3).tobytes(), feature.tobytes())
        self.assertEqual(ImageChops.add(rotated, rotate_mask(self.masks['field'], 1))
                         .getextrema(), (255, 255))

    def test_bad_path_or_band_rejected(self):
        for path, width in ((self.path[:-1], 60), (self.path, -1),
                            ([(0, 0)] * self.size, 60)):
            with self.assertRaises(ValueError):
                make_masks(path, self.size, width)


if __name__ == '__main__':
    unittest.main()
