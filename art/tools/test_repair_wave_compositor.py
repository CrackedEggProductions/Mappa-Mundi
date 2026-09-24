"""Wave 02 must gate unsuitable sources before writing and preserve all evidence."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import numpy as np
from PIL import Image

import repair_wave_compositor as wave
from hybrid_wave_geometry import generate
from repair_wave_metrics import ASSESSMENT_KEYS


class RepairWaveCompositorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.masks = generate('settlement_gate')
        cls.yy, cls.xx = np.indices((1254, 1254), dtype='int16')

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.root_patch = patch.object(wave, 'ROOT', self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        self.p = wave.paths('settlement_gate', 3)
        for key in ('source', 'calibration', 'assessment'):
            self.p[key].parent.mkdir(parents=True, exist_ok=True)
        self.source = Image.new('RGB', (1254, 1254), (201, 190, 162))
        self.source.save(self.p['source'])
        self.p['calibration'].write_text('{}')
        self.assessment = {key: False for key in ASSESSMENT_KEYS}
        self.assessment['notes'] = 'Synthetic identity fixture; visual flags are explicitly supplied.'
        self.save_assessment()
        self.sx, self.sy = self.xx.copy(), self.yy.copy()
        self.changed = np.zeros((1254, 1254), dtype=bool)
        self.render_patch = patch.object(wave.sampler, 'render', side_effect=self.render)
        self.render_patch.start(); self.addCleanup(self.render_patch.stop)

    def save_assessment(self):
        self.p['assessment'].write_text(json.dumps({'assessment': self.assessment}))

    def render(self, source, calibration, tile):
        out = Image.fromarray(np.asarray(source)[self.sy, self.sx])
        return out, self.masks, self.masks, self.sx, self.sy, self.changed

    def build(self, **kwargs):
        return wave.build('settlement_gate', 3, **kwargs)

    def assert_no_candidate(self):
        for key in ('candidate', 'record', 'provenance', 'repair_zone', 'correction_cost'):
            self.assertFalse(self.p[key].exists(), key)

    def test_scope_rejects_other_tiles_and_versions(self):
        for tile, version in [('forest_bend', 3), ('settlement_gate', 1), ('settlement_gate', True)]:
            with self.subTest(tile=tile, version=version), self.assertRaises(ValueError):
                wave.paths(tile, version)

    def test_valid_source_writes_review_candidate_and_verifies(self):
        record = self.build()
        self.assertEqual(record['status'], 'CANDIDATE — AWAITING HUMAN REVIEW')
        self.assertEqual(record['source_suitability'], 'PASS')
        self.assertTrue(wave.verify(self.p['record'])['valid'])
        with Image.open(self.p['candidate']) as image:
            self.assertEqual(image.size, (1254, 1254))
            self.assertEqual(image.tobytes(), self.source.tobytes())

    def test_sampler_limits_recorded_before_source_evaluation(self):
        self.build()
        cost = json.loads(self.p['correction_cost'].read_text())
        self.assertEqual(cost['limits'], {'transported_percent': 8.0,
            'displacement_p95_px': 80.0, 'displacement_max_px': 120.0,
            'transported_donor_reuse_ratio': .25})

    def test_verification_uses_sampler_without_mutating_old_module(self):
        old_root = wave.original.ROOT
        self.build()
        with patch.object(wave.original, 'render', side_effect=AssertionError('old renderer used')):
            with patch.object(wave.original, 'verify', side_effect=AssertionError('old verifier used')):
                self.assertTrue(wave.verify(self.p['record'])['valid'])
        self.assertEqual(wave.original.ROOT, old_root)

    def test_method_metadata_tamper_invalidates_verification(self):
        self.build()
        record = json.loads(self.p['record'].read_text())
        record['method'] = 'unrecorded architectural warp'
        self.p['record'].write_text(json.dumps(record))
        result = wave.verify(self.p['record'])
        self.assertFalse(result['valid'])
        self.assertFalse(result['checks']['method'])

    def test_pending_visual_review_allowed_but_not_pass(self):
        self.assessment['edge_repair_visible_at_review_scale'] = None
        self.save_assessment()
        self.assertEqual(self.build()['source_suitability'], 'NEEDS_REVIEW')
        self.assertTrue(wave.verify(self.p['record'])['valid'])

    def test_visible_edge_artifact_can_be_saved_only_as_rejected_review_candidate(self):
        self.assessment['edge_repair_visible_at_review_scale'] = True
        self.save_assessment()
        self.assertEqual(self.build()['source_suitability'], 'REJECT')
        self.assertTrue(self.p['candidate'].exists())

    def test_major_object_transport_rejected_before_candidate_write(self):
        self.assessment['major_recognizable_objects_moved'] = True
        self.save_assessment()
        result = self.build()
        self.assertIn('human:major_recognizable_objects_moved', result['reasons'])
        self.assert_no_candidate()
        self.assertTrue(self.p['source'].exists())

    def test_repeated_motifs_rejected_before_candidate_write(self):
        self.assessment['repeated_motifs_introduced'] = True
        self.save_assessment()
        self.assertIn('human:repeated_motifs_introduced', self.build()['reasons'])
        self.assert_no_candidate()

    def test_previously_rejected_source_stays_rejected(self):
        self.assessment['source_rejected_before_composition'] = True
        self.save_assessment()
        self.assertIn('human:source_rejected_before_composition', self.build()['reasons'])
        self.assert_no_candidate()

    def test_numeric_gate_rejects_long_transport_even_with_positive_human_review(self):
        self.sx[0, 0] = 200
        self.changed[0, 0] = True
        self.assertIn('limit:displacement_max_px', self.build()['reasons'])
        self.assert_no_candidate()

    def test_geometry_gate_rejects_before_candidate_write(self):
        with patch.object(wave, 'validate', return_value={'valid': False, 'checks': {'fixture': False}}):
            self.assertIn('geometry:invalid', self.build()['reasons'])
        self.assert_no_candidate()

    def test_sampler_source_rejection_records_diagnostic_without_candidate(self):
        with patch.object(wave.sampler, 'render', side_effect=ValueError('correction would move architecture')):
            result = self.build()
        self.assertEqual(result['reasons'], ['source:correction would move architecture'])
        self.assertIsNone(result['correction_cost'])
        self.assertTrue(self.p['rejection'].exists())
        self.assert_no_candidate()

    def test_missing_assessment_fails_without_output(self):
        self.p['assessment'].rename(self.p['assessment'].with_suffix('.held'))
        with self.assertRaises(FileNotFoundError):
            self.build()
        self.assert_no_candidate()

    def test_existing_products_refused_without_rebuild(self):
        self.build()
        before = self.p['candidate'].read_bytes()
        with self.assertRaises(FileExistsError):
            self.build()
        self.assertEqual(before, self.p['candidate'].read_bytes())

    def test_rebuild_backs_up_every_modified_product(self):
        self.build()
        products = [self.p[key] for key in ('candidate', 'record', 'provenance', 'repair_zone', 'correction_cost')]
        products += list(self.p['masks'].glob('*.png'))
        before = {path: path.read_bytes() for path in products}
        self.build(rebuild=True)
        for path, content in before.items():
            backups = list(path.parent.glob(path.name + '.bak-*'))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_bytes(), content)

    def test_rejection_on_rebuild_preserves_previous_candidate(self):
        self.build()
        before = self.p['candidate'].read_bytes()
        self.assessment['source_rejected_before_composition'] = True
        self.save_assessment()
        self.assertIn('reasons', self.build(rebuild=True))
        self.assertEqual(before, self.p['candidate'].read_bytes())

    def test_source_and_calibration_preserved(self):
        before = {key: self.p[key].read_bytes() for key in ('source', 'calibration', 'assessment')}
        self.build()
        self.assertEqual(before, {key: self.p[key].read_bytes() for key in before})

    def update_product_hash(self, key):
        record = json.loads(self.p['record'].read_text())
        record[key + '_sha256'] = wave.original.digest(self.p[key])
        self.p['record'].write_text(json.dumps(record))

    def test_cost_tamper_rejected_even_with_updated_hash(self):
        self.build()
        cost = json.loads(self.p['correction_cost'].read_text())
        cost['metrics']['transported_pixels'] = 1
        self.p['correction_cost'].write_text(json.dumps(cost))
        self.update_product_hash('correction_cost')
        report = wave.verify(self.p['record'])
        self.assertFalse(report['valid'])
        self.assertFalse(report['checks']['cost_recomputed'])

    def test_repair_zone_tamper_rejected_even_with_updated_hash(self):
        self.build()
        Image.new('L', (1254, 1254), 255).save(self.p['repair_zone'])
        self.update_product_hash('repair_zone')
        report = wave.verify(self.p['record'])
        self.assertFalse(report['valid'])
        self.assertFalse(report['checks']['repair_zone_exact'])

    def test_assessment_tamper_rejected_even_with_updated_hash(self):
        self.build()
        self.assessment['major_recognizable_objects_moved'] = True
        self.save_assessment()
        self.update_product_hash('assessment')
        report = wave.verify(self.p['record'])
        self.assertFalse(report['valid'])
        self.assertFalse(report['checks']['assessment_matches_cost'])

    def test_unreadable_record_is_structured_verification_failure(self):
        result = wave.verify(self.root / 'absent.json')
        self.assertFalse(result['valid'])
        self.assertIn('error', result)

    def test_repair_zone_matches_integer_coordinate_changes(self):
        self.sx[0, 0] = 1
        self.changed[0, 0] = True
        self.build()
        with Image.open(self.p['repair_zone']) as image:
            self.assertEqual(image.getpixel((0, 0)), 255)
            self.assertEqual(np.count_nonzero(image), 1)
        self.assertTrue(wave.verify(self.p['record'])['valid'])


class RepairWaveSamplerContractTests(unittest.TestCase):
    def test_socket_map_has_exact_inclusive_target_ownership(self):
        mapping = wave.sampler.socket_map(1254, (457, 706), (502, 751))
        membership = (mapping >= 457) & (mapping <= 706)
        expected = np.zeros(1254, dtype=bool)
        expected[502:752] = True
        self.assertTrue(np.array_equal(membership, expected))
        self.assertEqual(mapping[0], 0)
        self.assertEqual(mapping[-1], 1253)
        self.assertTrue(np.all(np.diff(mapping) >= 0))

    def test_socket_map_retains_bank_strip_scale(self):
        mapping = wave.sampler.socket_map(1254, (457, 706), (502, 751))
        self.assertTrue(np.all(np.diff(mapping[484:521]) == 1))
        self.assertTrue(np.all(np.diff(mapping[733:770]) == 1))

    def test_socket_map_identity_and_invalid_intervals(self):
        self.assertTrue(np.array_equal(wave.sampler.socket_map(1254, (564, 689), (564, 689)), np.arange(1254)))
        for interval in ((-1, 100), (100, 100), (500, 1254)):
            with self.subTest(interval=interval), self.assertRaises(ValueError):
                wave.sampler.socket_map(1254, interval, (564, 689))

    def test_sampler_refuses_city_edge_reconstruction(self):
        origins = generate('settlement_gate')
        origins['Settlement'].putpixel((100, 0), 0)
        source = Image.new('RGB', (1254, 1254), (201, 190, 162))
        before = source.tobytes()
        with patch.object(wave.sampler, 'source_masks', return_value=origins):
            with self.assertRaisesRegex(ValueError, 'city edges require reconstruction'):
                wave.sampler.render(source, {}, 'settlement_gate')
        self.assertEqual(source.tobytes(), before)

    def test_sampler_blocks_mapping_that_moves_architecture(self):
        origins = generate('settlement_gate')
        source = Image.new('RGB', (1254, 1254), (201, 190, 162))
        illegal_mapping = np.minimum(np.arange(1254) + 1, 1253).astype('int16')
        with patch.object(wave.sampler, 'source_masks', return_value=origins):
            with patch.object(wave.sampler, 'socket_map', return_value=illegal_mapping):
                with self.assertRaisesRegex(ValueError, 'move architecture'):
                    wave.sampler.render(source, {}, 'settlement_gate')


if __name__ == '__main__':
    unittest.main()
