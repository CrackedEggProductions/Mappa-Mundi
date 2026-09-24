"""Native mixed-reference seam reviews preserve exact pixels and topology."""
import sys
import unittest
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from build_seam_sheet import rotated
from geometry_wave_reviews import (DECLARED, TILES, check_placements, compose_tiles,
                                   layouts, rotated_edges, validate_pixels)


class GeometryWaveReviewTests(unittest.TestCase):
    def setUp(self):
        self.image = Image.new('RGBA', (16, 16))
        self.image.putdata([(x * 13, y * 11, (x + y) * 7, 255)
                            for y in range(16) for x in range(16)])

    def test_all_declared_layouts_match(self):
        for tile in TILES:
            declarations = dict(DECLARED, candidate=DECLARED[tile])
            seen = set()
            for layout in layouts(tile).values():
                seams = check_placements(layout, declarations)
                seen.update(seam['feature'] for seam in seams)
            self.assertIn('Field', seen)
            self.assertIn(DECLARED[tile][0], seen)

    def test_all_native_layout_pixels_match(self):
        images = {key: self.image for key in ('candidate', 'straight', 'bend', 'end', 'field')}
        before = self.image.tobytes()
        for tile in TILES:
            for layout in layouts(tile).values():
                sheet = compose_tiles(images, layout, dict(DECLARED, candidate=DECLARED[tile]))
                self.assertTrue(validate_pixels(sheet, images, layout))
                self.assertEqual(sheet.size, (16 * len(layout[0]), 16 * len(layout)))
        self.assertEqual(self.image.tobytes(), before)

    def test_invalid_seam_rejected_before_paste(self):
        with self.assertRaises(ValueError):
            compose_tiles({'candidate': self.image, 'field': self.image},
                          [[('candidate', 0), ('field', 0)]],
                          dict(DECLARED, candidate=DECLARED['road_junction']))

    def test_rotation_changes_declared_edges_correctly(self):
        self.assertEqual(rotated_edges(DECLARED['road_junction'], 90),
                         ('Field', 'Road', 'Road', 'Road'))
        self.assertEqual(rotated_edges(DECLARED['end'], 90),
                         ('Field', 'Field', 'Field', 'Road'))

    def test_all_rotation_pixels_exact(self):
        for angle in (0, 90, 180, 270):
            layout = [[('field', angle)]]
            result = compose_tiles({'field': self.image}, layout, DECLARED)
            self.assertEqual(result.tobytes(), rotated(self.image, angle).tobytes())

    def test_unsupported_angle_rejected(self):
        with self.assertRaises(ValueError):
            check_placements([[('field', 45)]], DECLARED)

    def test_mixed_native_dimensions_rejected(self):
        with self.assertRaises(ValueError):
            compose_tiles({'a': self.image, 'b': Image.new('RGB', (17, 17))},
                          [[('a', 0), ('b', 0)]], dict(a=DECLARED['field'], b=DECLARED['field']))

    def test_void_is_transparent_outside_board(self):
        sheet = compose_tiles({'field': self.image}, [[None, ('field', 0)]], DECLARED)
        self.assertEqual(sheet.crop((0, 0, 16, 16)).tobytes(), Image.new('RGBA', (16, 16)).tobytes())
        self.assertTrue(validate_pixels(sheet, {'field': self.image}, [[None, ('field', 0)]]))

    def test_corrupted_edge_pixel_is_detected(self):
        layout = [[('field', 0), ('field', 0)]]
        sheet = compose_tiles({'field': self.image}, layout, DECLARED)
        sheet.putpixel((15, 8), (0, 0, 0, 0))
        self.assertFalse(validate_pixels(sheet, {'field': self.image}, layout))

    def test_ragged_and_all_empty_layouts_rejected(self):
        with self.assertRaises(ValueError):
            check_placements([[('field', 0)], []], DECLARED)
        with self.assertRaises(ValueError):
            compose_tiles({}, [[None]], DECLARED)

    def test_road_cross_uses_all_three_legacy_road_types(self):
        cross = layouts('road_junction')['three_branch_3x3']
        keys = {value[0] for row in cross for value in row if value is not None}
        self.assertEqual(keys, {'candidate', 'straight', 'bend', 'end', 'field'})
        seams = check_placements(cross, dict(DECLARED, candidate=DECLARED['road_junction']))
        self.assertEqual(sum(seam['feature'] == 'Road' for seam in seams), 3)
        self.assertEqual(sum(seam['feature'] == 'Field' for seam in seams), 1)


if __name__ == '__main__':
    unittest.main()
