#!/usr/bin/env python3
"""Checks exact review-pixel behavior; does not certify candidate artwork."""
import unittest
from pathlib import Path

from PIL import Image

from build_seam_sheet import LAYOUTS, check_layout, composite, preflight, rotated


class ReviewToolsTests(unittest.TestCase):
    def setUp(self):
        self.image = Image.new("RGBA", (8, 8))
        self.image.putdata([(x * 31, y * 31, (x + y) * 15, 255)
                            for y in range(8) for x in range(8)])

    def test_rotations_preserve_every_pixel(self):
        original = sorted(self.image.getpixel((x, y)) for y in range(8) for x in range(8))
        for angle in (0, 90, 180, 270):
            result = rotated(self.image, angle)
            self.assertEqual(sorted(result.getpixel((x, y)) for y in range(8) for x in range(8)), original)
        result = self.image
        for _ in range(4):
            result = rotated(result, 90)
        self.assertEqual(result.tobytes(), self.image.tobytes())
        self.assertEqual(rotated(self.image, 90).getpixel((7, 0)), self.image.getpixel((0, 0)))

    def test_composites_preserve_native_pixels_without_seam_gaps(self):
        original = self.image.tobytes()
        for layout in LAYOUTS.values():
            sheet = composite(self.image, layout)
            self.assertEqual(sheet.size, (8 * len(layout[0]), 8 * len(layout)))
            for row, values in enumerate(layout):
                for col, turn in enumerate(values):
                    crop = sheet.crop((col * 8, row * 8, (col + 1) * 8, (row + 1) * 8))
                    self.assertEqual(crop.tobytes(), rotated(self.image, turn).tobytes())
        self.assertEqual(self.image.tobytes(), original)

    def test_every_layout_matches_and_exercises_both_edge_types(self):
        all_edges = set()
        for layout in LAYOUTS.values():
            all_edges.update(seam["edge"] for seam in check_layout(layout))
        self.assertEqual(all_edges, {"Area", "Field"})
        with self.assertRaises(ValueError):
            check_layout([[0, 0]])

    def test_non_square_rejected_without_resizing(self):
        with self.assertRaises(ValueError):
            composite(Image.new("RGB", (8, 7)), LAYOUTS["central_area_2x2"])

    def test_existing_or_repeated_output_refused(self):
        with self.assertRaises(FileExistsError):
            preflight([Path(__file__)])
        with self.assertRaises(FileExistsError):
            preflight([Path("unused.png"), Path("unused.png")])

    def test_template_sockets_and_area_coverage(self):
        root = Path(__file__).resolve().parents[1] / "templates" / "edge_masks"
        for feature, width in (("road", 125.4), ("river", 250.8)):
            with Image.open(root / f"{feature}_north.png") as mask:
                self.assertEqual(mask.size, (1254, 1254))
                row = [mask.getpixel((x, 0)) for x in range(mask.width)]
                self.assertEqual(row, list(reversed(row)))
                self.assertAlmostEqual(sum(row) / 255, width, delta=0.01)
        with Image.open(root / "ne_full_area.png") as mask:
            last = mask.width - 1
            self.assertEqual(mask.getpixel((last, 0)), 255)
            self.assertTrue(all(mask.getpixel((x, 0)) == 255 for x in range(1, mask.width)))
            self.assertTrue(all(mask.getpixel((last, y)) == 255 for y in range(last)))
            self.assertTrue(all(mask.getpixel((0, y)) == 0 for y in range(1, mask.height)))
            self.assertTrue(all(mask.getpixel((x, last)) == 0 for x in range(last)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
