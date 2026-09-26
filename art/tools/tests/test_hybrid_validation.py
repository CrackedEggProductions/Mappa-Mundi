"""Verify proof records fail when artifacts drift or declared masks are detached."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from boundary_generator import generate_boundary
from build_seam_sheet import composite, LAYOUTS
from hybrid_compositor import digest, transport
from seam_validator import validate_composition, validate_seam


class CompositionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=Path(__file__).parent)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        size = 37
        y, x = np.indices((size, size))
        array = np.stack((x * 5, y * 6, (x+y)*3), axis=-1).astype('uint8')
        self.source = Image.fromarray(array)
        self.source.save(self.root / 'source.png')
        self.path = generate_boundary(size, 91)
        self.trace = [(0, 1), (18, 15), (36, 34)]
        output, masks, coordinates, owner = transport(self.source, self.path, self.trace, 8)
        output.save(self.root / 'candidate.png')
        for name, mask in masks.items():
            mask.save(self.root / f'{name}.png')
        owner.save(self.root / 'provenance.png')
        (self.root / 'boundary.json').write_text(json.dumps({
            'size': size, 'seed': 91, 'irregularity': 0.035,
            'path': self.path, 'source_trace': self.trace}))
        self.manifest = {
            'source': 'source.png', 'source_sha256': digest(self.root / 'source.png'),
            'candidate': 'candidate.png', 'candidate_sha256': digest(self.root / 'candidate.png'),
            'boundary': 'boundary.json', 'size': [size, size], 'seed': 91,
            'transition_width': 8, 'masks': {name: f'{name}.png' for name in masks},
            'provenance': 'provenance.png',
            'source_coordinate_sha256': hashlib.sha256(coordinates.tobytes()).hexdigest()}
        self.write_manifest()

    def write_manifest(self):
        (self.root / 'composition.json').write_text(json.dumps(self.manifest))

    def validate(self):
        return validate_composition(self.root / 'composition.json', self.root)

    def test_valid_composition_proves_all_pixels_and_keeps_sources(self):
        before = {p.name: digest(p) for p in self.root.iterdir()}
        result = self.validate()
        self.assertTrue(result['valid'], result)
        self.assertTrue(result['checks']['candidate_pixels_reproduced'])
        self.assertEqual(before, {p.name: digest(p) for p in self.root.iterdir()})

    def test_changed_candidate_fails_hash_and_rerender(self):
        with Image.open(self.root / 'candidate.png') as opened:
            image = opened.copy()
        image.putpixel((10, 10), (255, 0, 255))
        image.save(self.root / 'candidate.png')
        result = self.validate()
        self.assertFalse(result['valid'])
        self.assertIn('candidate_file_hash', result['errors'])
        self.assertIn('candidate_pixels_reproduced', result['errors'])

    def test_rehashed_wrong_candidate_still_fails_true_pixel_linkage(self):
        Image.new('RGB', (37, 37), 'white').save(self.root / 'candidate.png')
        self.manifest['candidate_sha256'] = digest(self.root / 'candidate.png')
        self.write_manifest()
        result = self.validate()
        self.assertTrue(result['checks']['candidate_file_hash'])
        self.assertFalse(result['checks']['candidate_pixels_reproduced'])

    def test_provenance_mismatch_rejected(self):
        Image.new('L', (37, 37)).save(self.root / 'provenance.png')
        result = self.validate()
        self.assertFalse(result['valid'])
        self.assertIn('provenance_equals_feature', result['errors'])

    def test_nonbinary_mask_and_edge_corruption_rejected(self):
        with Image.open(self.root / 'feature.png') as opened:
            image = opened.copy()
        image.putpixel((10, 0), 128)
        image.save(self.root / 'feature.png')
        result = self.validate()
        self.assertIn('feature_mask_dimensions_mode_binary', result['errors'])
        self.assertIn('exact_edges_with_feature_corner_ties', result['errors'])

    def test_corrupt_coordinate_hash_rejected(self):
        self.manifest['source_coordinate_sha256'] = 'incorrect'
        self.write_manifest()
        self.assertIn('source_coordinate_hash_reproduced', self.validate()['errors'])

    def test_changed_source_rejected(self):
        Image.new('RGB', (37, 37), '#123456').save(self.root / 'source.png')
        self.assertIn('source_file_hash', self.validate()['errors'])

    def test_transport_is_deterministic_and_preserves_native_size(self):
        before = self.source.tobytes()
        first = transport(self.source, self.path, self.trace, 8)
        second = transport(self.source, self.path, self.trace, 8)
        self.assertEqual(first[0].size, self.source.size)
        self.assertEqual(first[0].tobytes(), second[0].tobytes())
        self.assertEqual(first[2].tobytes(), second[2].tobytes())
        self.assertEqual(before, self.source.tobytes())

    def test_relaxed_field_mode_manifest_reproduces(self):
        output, _, coordinates, _ = transport(self.source, self.path, self.trace, 8, 'relaxed')
        output.save(self.root / 'candidate.png')
        self.manifest['field_mode'] = 'relaxed'
        self.manifest['candidate_sha256'] = digest(self.root / 'candidate.png')
        self.manifest['source_coordinate_sha256'] = hashlib.sha256(coordinates.tobytes()).hexdigest()
        self.write_manifest()
        result = self.validate()
        self.assertTrue(result['valid'], result)

    def test_missing_evidence_is_structured_failure(self):
        self.manifest['boundary'] = 'missing.json'
        self.write_manifest()
        self.assertFalse(self.validate()['valid'])


class SeamTests(unittest.TestCase):
    def test_all_layouts_preserve_every_pixel_including_edges(self):
        values = np.arange(13*13*3, dtype=np.uint16).reshape((13, 13, 3))
        image = Image.fromarray((values % 256).astype('uint8'))
        for layout in LAYOUTS.values():
            self.assertTrue(validate_seam(image, composite(image, layout), layout)['valid'])

    def test_single_corrupted_seam_pixel_fails(self):
        image = Image.new('RGB', (13, 13), '#234567')
        layout = LAYOUTS['central_area_2x2']
        sheet = composite(image, layout)
        sheet.putpixel((12, 6), (255, 0, 0, 255))
        self.assertFalse(validate_seam(image, sheet, layout)['valid'])

    def test_resized_sheet_and_bad_layout_fail(self):
        image = Image.new('RGB', (13, 13))
        layout = LAYOUTS['central_area_2x2']
        self.assertFalse(validate_seam(image, composite(image, layout).resize((25, 25)), layout)['valid'])
        self.assertFalse(validate_seam(image, image, [[0], [0, 90]])['valid'])


if __name__ == '__main__':
    unittest.main()
