"""Hybrid review layouts remain canonical, native and independent of source assets."""
import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from production_wave_reviews import (EDGES, REFERENCE_EDGES, REFERENCE_PATHS,
                                     comparison, debug_overlay, layouts,
                                     mask_paths, matching_reference, validate_template, write_seam)
from geometry_wave_reviews import (check_placements, compose_tiles, rotated_edges,
                                   validate_pixels)


class ProductionWaveReviewTests(unittest.TestCase):
    def setUp(self):
        self.image = Image.new('RGBA', (16, 16))
        self.image.putdata([(x * 13, y * 11, (x + y) * 7, 255)
                            for y in range(16) for x in range(16)])

    def test_all_layouts_match_all_four_canonical_sides(self):
        for tile, edges in EDGES.items():
            declarations = dict(REFERENCE_EDGES, candidate=edges)
            for layout in layouts(tile).values():
                self.assertTrue(check_placements(layout, declarations))
            cross = check_placements(layouts(tile)['combined_3x3'], declarations)
            self.assertEqual(sorted(item['feature'] for item in cross), sorted(edges))

    def test_every_used_native_pixel_survives(self):
        images = {key: self.image for key in (*REFERENCE_EDGES, 'candidate')}
        original = self.image.tobytes()
        for tile, edges in EDGES.items():
            for layout in layouts(tile).values():
                sheet = compose_tiles(images, layout, dict(REFERENCE_EDGES, candidate=edges))
                self.assertTrue(validate_pixels(sheet, images, layout))
        self.assertEqual(self.image.tobytes(), original)

    def test_no_road_end_or_out_of_scope_reference(self):
        self.assertFalse(any('road_end' in path for path in REFERENCE_PATHS.values()))
        for tile in EDGES:
            for layout in layouts(tile).values():
                for row in layout:
                    for cell in row:
                        if cell:
                            self.assertIn(cell[0], (*REFERENCE_PATHS, 'candidate'))

    def test_reference_matching_all_rotations(self):
        for feature in ('Forest', 'Settlement', 'Road', 'River', 'Field'):
            for side in range(4):
                key, angle = matching_reference(feature, side)
                self.assertEqual(rotated_edges(REFERENCE_EDGES[key], angle)[side], feature)

    def test_linear_branches_receive_bend_review(self):
        for tile, edges in EDGES.items():
            for feature in ('Road', 'River'):
                self.assertEqual(feature.lower() + '_bend_pair' in layouts(tile), feature in edges)

    def test_four_rotations_keep_full_native_pixels(self):
        for angle in (0, 90, 180, 270):
            layout = [[('field', angle)]]
            images = {'field': self.image}
            sheet = compose_tiles(images, layout, REFERENCE_EDGES)
            self.assertTrue(validate_pixels(sheet, images, layout))

    def test_template_orientation_mismatch_rejected(self):
        record = {'edges': dict(zip(('N', 'E', 'S', 'W'), EDGES['woodland_road']))}
        validate_template('woodland_road', record)
        with self.assertRaises(ValueError):
            validate_template('woodland_river', record)

    def test_actual_candidate_mask_set_overrides_canonical(self):
        with tempfile.TemporaryDirectory() as name:
            art = Path(name)
            tile = 'settlement_throughway'
            candidate = Path('settlement_throughway_v01.png')
            canonical = art / 'templates/production_wave_01' / tile
            canonical.mkdir(parents=True)
            for feature in ('Settlement', 'Field'):
                Image.new('L', (16, 16)).save(canonical / f'{feature}.png')
            self.assertEqual(mask_paths(art, tile, candidate)['Settlement'].parent, canonical)
            override = art / 'reviews/production_wave_01/masks' / candidate.stem
            override.mkdir(parents=True)
            for feature in ('Settlement', 'Field'):
                Image.new('L', (16, 16), 255).save(override / f'{feature}.png')
            self.assertEqual(mask_paths(art, tile, candidate)['Settlement'].parent, override)

    def test_incomplete_candidate_masks_do_not_mix_with_templates(self):
        with tempfile.TemporaryDirectory() as name:
            art = Path(name)
            candidate = Path('settlement_throughway_v01.png')
            override = art / 'reviews/production_wave_01/masks' / candidate.stem
            override.mkdir(parents=True)
            Image.new('L', (16, 16)).save(override / 'Settlement.png')
            with self.assertRaises(FileNotFoundError):
                mask_paths(art, 'settlement_throughway', candidate)

    def test_debug_does_not_mutate_sources(self):
        feature = Image.new('L', (16, 16), 0)
        for x in range(16):
            for y in range(x + 1):
                feature.putpixel((x, y), 255)
        field = feature.point(lambda value: 255 - value)
        originals = (self.image.tobytes(), feature.tobytes(), field.tobytes())
        debug = debug_overlay(self.image, {'Settlement': feature, 'Field': field},
                              REFERENCE_EDGES['settlement'])
        self.assertEqual(debug.size, self.image.size)
        self.assertNotEqual(debug.tobytes(), self.image.tobytes())
        self.assertEqual(originals, (self.image.tobytes(), feature.tobytes(), field.tobytes()))

    def test_debug_mismatched_dimensions_rejected(self):
        with self.assertRaises(ValueError):
            debug_overlay(self.image, {'Field': Image.new('L', (12, 12))}, REFERENCE_EDGES['field'])

    def test_saved_native_sheet_provenance_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            source = root / 'source.png'
            self.image.save(source)
            original = source.read_bytes()
            output = root / 'seam.png'
            layout = [[('field', 90), ('field', 180)]]
            record = write_seam(output, {'field': source}, layout, REFERENCE_EDGES, root)
            self.assertEqual(record['size'], [32, 16])
            self.assertTrue(record['exact_native_pixels'])
            self.assertEqual(record['placements'][0]['source'], 'source.png')
            self.assertEqual(record['placements'][1]['rotation_clockwise'], 180)
            self.assertEqual(original, source.read_bytes())
            with self.assertRaises(FileExistsError):
                write_seam(output, {'field': source}, layout, REFERENCE_EDGES, root)

    def test_corrupt_saved_seam_pixel_detected(self):
        images = {'field': self.image}
        layout = [[('field', 0), ('field', 0)]]
        sheet = compose_tiles(images, layout, REFERENCE_EDGES)
        sheet.putpixel((15, 7), (0, 0, 0, 0))
        self.assertFalse(validate_pixels(sheet, images, layout))

    def test_comparison_labels_are_separate_and_source_unchanged(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            source, output = root / 'source.png', root / 'comparison.png'
            self.image.save(source)
            original = source.read_bytes()
            comparison([('Candidate test', source)], output, root)
            metadata = json.loads(output.with_suffix('.json').read_text())
            self.assertEqual(metadata['labels'], 'outside artwork')
            self.assertEqual(metadata['items'][0]['native_size'], [16, 16])
            self.assertEqual(source.read_bytes(), original)


if __name__ == '__main__':
    unittest.main()
