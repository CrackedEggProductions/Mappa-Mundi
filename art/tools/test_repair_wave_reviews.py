"""Repair-wave review selection, native seam pixels and repair diagnostics."""
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from geometry_wave_reviews import check_placements, compose_tiles, validate_pixels
from repair_wave_reviews import (
    ANCHORS, EDGES, REFERENCE_EDGES, REFERENCE_PATHS, THROUGHWAY_EDGES,
    TILES, VERSIONS, comparison_items, layouts, mask_paths, repair_overlay, write_seam,
)


class RepairWaveReviewTests(unittest.TestCase):
    def setUp(self):
        self.image = Image.new('RGBA', (16, 16))
        self.image.putdata([(x * 13, y * 11, (x + y) * 7, 255)
                            for y in range(16) for x in range(16)])
        self.declarations = dict(REFERENCE_EDGES, throughway=THROUGHWAY_EDGES)

    def test_wave_contains_only_three_rejected_designs_and_new_versions(self):
        self.assertEqual(TILES, ('settlement_gate', 'riverside_hamlet', 'settlement_road_throughway'))
        self.assertEqual(VERSIONS, (3, 4))
        with self.assertRaises(ValueError):
            layouts('woodland_road')

    def test_every_layout_matches_declared_sides(self):
        for tile in TILES:
            declarations = dict(self.declarations, candidate=EDGES[tile])
            for layout in layouts(tile).values():
                self.assertTrue(check_placements(layout, declarations))

    def test_new_throughway_anchor_is_reviewed_for_each_design(self):
        for tile in TILES:
            cells = [cell for row in layouts(tile)['settlement_throughway_pair'] for cell in row]
            self.assertIn('throughway', [cell[0] for cell in cells])

    def test_throughway_grid_proves_both_axes_simultaneously(self):
        tile = 'settlement_road_throughway'
        grid = layouts(tile)['simultaneous_continuity_3x3']
        seams = check_placements(grid, dict(self.declarations, candidate=EDGES[tile]))
        self.assertEqual(len(seams), 12)
        self.assertEqual([s['feature'] for s in seams].count('Road'), 6)
        self.assertEqual([s['feature'] for s in seams].count('Settlement'), 6)

    def test_review_layouts_preserve_all_pixels(self):
        images = {key: self.image for key in (*self.declarations, 'candidate')}
        original = self.image.tobytes()
        for tile in TILES:
            for layout in layouts(tile).values():
                sheet = compose_tiles(images, layout, dict(self.declarations, candidate=EDGES[tile]))
                self.assertTrue(validate_pixels(sheet, images, layout))
        self.assertEqual(self.image.tobytes(), original)

    def test_no_road_end_or_new_remaining_roster_asset(self):
        allowed = set(REFERENCE_PATHS) | {'throughway', 'candidate'}
        for tile in TILES:
            for layout in layouts(tile).values():
                for row in layout:
                    for cell in row:
                        if cell:
                            self.assertIn(cell[0], allowed)
                            self.assertNotIn('road_end', cell[0])

    def test_comparison_uses_new_anchors_and_rejected_previous_candidate(self):
        art = Path('/example/art')
        paths = [art / f'candidate_v{version}.png' for version in VERSIONS]
        for tile in TILES:
            items = comparison_items(art, tile, paths, [])
            for anchor in ANCHORS[tile]:
                self.assertIn(art / f'references/production_anchors/{anchor}_anchor.png',
                              [path for _, path in items])
            self.assertTrue(any('visually rejected' in label and 'production_wave_01' in str(path)
                                for label, path in items))
            self.assertEqual([path for label, path in items if label.startswith('Candidate')], paths)

    def test_actual_candidate_masks_required_even_if_template_exists(self):
        with tempfile.TemporaryDirectory() as name:
            art = Path(name)
            template = art / 'templates/production_wave_01/settlement_gate'
            template.mkdir(parents=True)
            for feature in ('Settlement', 'Road', 'Field'):
                self.image.convert('L').save(template / f'{feature}.png')
            with self.assertRaises(FileNotFoundError):
                mask_paths(art, 'settlement_gate', Path('settlement_gate_v03.png'))

    def test_partial_actual_masks_rejected(self):
        with tempfile.TemporaryDirectory() as name:
            art = Path(name)
            folder = art / 'reviews/production_wave_02/masks/settlement_gate_v03'
            folder.mkdir(parents=True)
            self.image.convert('L').save(folder / 'Settlement.png')
            with self.assertRaises(FileNotFoundError):
                mask_paths(art, 'settlement_gate', Path('settlement_gate_v03.png'))

    def test_complete_actual_masks_resolve(self):
        with tempfile.TemporaryDirectory() as name:
            art = Path(name)
            folder = art / 'reviews/production_wave_02/masks/settlement_gate_v03'
            folder.mkdir(parents=True)
            for feature in ('Settlement', 'Road', 'Field'):
                self.image.convert('L').save(folder / f'{feature}.png')
            paths = mask_paths(art, 'settlement_gate', Path('settlement_gate_v03.png'))
            self.assertEqual({path.parent for path in paths.values()}, {folder})

    def test_debug_repairs_separate_and_inputs_unchanged(self):
        mask = Image.new('L', self.image.size, 255)
        repair = Image.new('L', self.image.size)
        repair.putpixel((7, 7), 255)
        before = (self.image.tobytes(), mask.tobytes(), repair.tobytes())
        without = repair_overlay(self.image, {'Field': mask}, ('Field',) * 4,
                                 Image.new('L', self.image.size), [])
        with_repair = repair_overlay(self.image, {'Field': mask}, ('Field',) * 4, repair, [])
        self.assertNotEqual(without.getpixel((7, 7)), with_repair.getpixel((7, 7)))
        self.assertEqual(before, (self.image.tobytes(), mask.tobytes(), repair.tobytes()))
        self.assertEqual(with_repair.size, self.image.size)

    def test_debug_rejects_wrong_repair_dimensions_and_soft_mask(self):
        for repair in (Image.new('L', (12, 12)), Image.new('L', (16, 16), 128)):
            with self.assertRaises(ValueError):
                repair_overlay(self.image, {'Field': Image.new('L', (16, 16), 255)},
                               ('Field',) * 4, repair, [])

    def test_seam_saved_native_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            source, output = root / 'source.png', root / 'seam.png'
            self.image.save(source)
            before = source.read_bytes()
            layout = [[('candidate', 0), ('candidate', 0)]]
            record = write_seam(output, {'candidate': source}, layout,
                                {'candidate': EDGES['settlement_road_throughway']}, root)
            self.assertTrue(record['exact_native_pixels'])
            self.assertEqual(record['size'], [32, 16])
            self.assertEqual(before, source.read_bytes())
            with self.assertRaises(FileExistsError):
                write_seam(output, {'candidate': source}, layout,
                           {'candidate': EDGES['settlement_road_throughway']}, root)


if __name__ == '__main__':
    unittest.main()
