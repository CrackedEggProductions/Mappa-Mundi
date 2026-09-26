"""Correction-cost evidence must reflect real donor maps and human review limits."""
import copy
import unittest

import numpy as np

from repair_wave_metrics import (
    ASSESSMENT_KEYS, DEFAULT_LIMITS, correction_report, measure_correction,
    repair_zone, verify_report,
)


def assessment(**overrides):
    result = {key: False for key in ASSESSMENT_KEYS}
    result['notes'] = 'Reviewed native source and candidate side by side.'
    result.update(overrides)
    return result


class RepairWaveMetricsTests(unittest.TestCase):
    def setUp(self):
        self.sy, self.sx = np.indices((100, 100))

    def report(self, **kwargs):
        return correction_report(self.sx, self.sy, assessment(), **kwargs)

    def test_identity_cost_is_zero(self):
        m = measure_correction(self.sx, self.sy)
        self.assertEqual(m['transported_pixels'], 0)
        self.assertEqual(m['displacement_max_px'], 0)
        self.assertEqual(m['transported_donor_reuse_ratio'], 0)
        self.assertEqual(self.report()['source_suitability'], 'PASS')

    def test_transport_area_distance_and_reuse(self):
        self.sx[0, :5] = 10
        m = measure_correction(self.sx, self.sy)
        self.assertEqual(m['transported_pixels'], 5)
        self.assertEqual(m['transported_percent'], .05)
        self.assertEqual(m['displacement_max_px'], 10)
        self.assertAlmostEqual(m['displacement_p95_px'], 9.8)
        self.assertEqual(m['unique_transported_donors'], 1)
        self.assertEqual(m['transported_donor_reuse_count'], 4)
        self.assertEqual(m['transported_donor_reuse_ratio'], .8)
        self.assertEqual(m['all_output_duplicate_donor_count'], 5)

    def test_transported_uniform_pixels_are_not_rgb_changes(self):
        self.sx[0, 0] = 1
        src = np.zeros((100, 100, 3), dtype='uint8')
        m = measure_correction(self.sx, self.sy, src, src)
        self.assertEqual(m['transported_pixels'], 1)
        self.assertEqual(m['rgb_changed_pixels'], 0)

    def test_actual_rgb_changes_and_reconstruction(self):
        self.sx[0, 0] = 1
        src = np.stack((self.sx % 256, self.sy % 256, self.sy % 256), axis=-1).astype('uint8')
        src[0, 0] = 255
        out = src[self.sy, self.sx]
        self.assertEqual(measure_correction(self.sx, self.sy, src, out)['rgb_changed_pixels'], 1)
        out[1, 1] = 255
        with self.assertRaisesRegex(ValueError, 'disagree'):
            measure_correction(self.sx, self.sy, src, out)

    def test_zone_exact_native_shape_binary_and_no_input_mutation(self):
        self.sx[0, 0] = 1
        before = self.sx.copy()
        zone = repair_zone(self.sx, self.sy)
        self.assertEqual(zone.size, (100, 100))
        self.assertEqual(zone.mode, 'L')
        self.assertEqual(set(np.unique(zone)), {0, 255})
        self.assertEqual(np.count_nonzero(zone), 1)
        self.assertTrue(np.array_equal(self.sx, before))

    def test_native_production_dimensions_preserved(self):
        yy, xx = np.indices((1254, 1254), dtype='int16')
        self.assertEqual(repair_zone(xx, yy).size, (1254, 1254))
        self.assertEqual(measure_correction(xx, yy)['resolution'], [1254, 1254])

    def test_invalid_map_shapes(self):
        for x, y in [(np.array([]), np.array([])), (np.zeros((0, 1), dtype=int), np.zeros((0, 1), dtype=int)),
                     (self.sx, self.sy[:50]), (self.sx[..., None], self.sy[..., None])]:
            with self.subTest(shape=x.shape), self.assertRaises(ValueError):
                measure_correction(x, y)

    def test_noninteger_coordinates_rejected(self):
        for dtype in ('float64', 'bool', 'object'):
            with self.subTest(dtype=dtype), self.assertRaisesRegex(ValueError, 'integers'):
                measure_correction(self.sx.astype(dtype), self.sy)

    def test_negative_and_out_of_range_coordinates_rejected(self):
        for bad in (-1, 100):
            for axis in ('x', 'y'):
                x, y = self.sx.copy(), self.sy.copy()
                (x if axis == 'x' else y)[0, 0] = bad
                with self.subTest(bad=bad, axis=axis), self.assertRaises(ValueError):
                    measure_correction(x, y)

    def test_optional_image_pair_shape_and_dtype_checks(self):
        src = np.zeros((100, 100, 3), dtype='uint8')
        cases = [(src, None), (src, src[:50]), (src[..., 0], src[..., 0]),
                 (src.astype(float), src.astype(float))]
        for source, candidate in cases:
            with self.subTest(), self.assertRaises(ValueError):
                measure_correction(self.sx, self.sy, source, candidate)

    def test_large_area_rejected(self):
        self.sx[:4] = np.roll(self.sx[:4], 1, axis=1)
        r = self.report()
        self.assertEqual(r['source_suitability'], 'REJECT')
        self.assertIn('limit:transported_percent', r['rejection_reasons'])

    def test_long_distance_rejected_even_for_small_area(self):
        yy, xx = np.indices((300, 300))
        xx[0, 0] = 200
        r = correction_report(xx, yy, assessment())
        self.assertIn('limit:displacement_max_px', r['rejection_reasons'])
        self.assertIn('limit:displacement_p95_px', r['rejection_reasons'])

    def test_repeated_donor_gate(self):
        self.sx[0, :5] = 10
        self.assertIn('limit:transported_donor_reuse_ratio', self.report()['rejection_reasons'])

    def test_each_human_flag_rejects_even_zero_cost(self):
        for key in ASSESSMENT_KEYS:
            r = correction_report(self.sx, self.sy, assessment(**{key: True}))
            self.assertEqual(r['source_suitability'], 'REJECT')
            self.assertIn('human:' + key, r['rejection_reasons'])

    def test_pending_review_never_passes(self):
        r = correction_report(self.sx, self.sy, assessment(major_recognizable_objects_moved=None))
        self.assertEqual(r['source_suitability'], 'NEEDS_REVIEW')
        self.assertEqual(r['pending_assessments'], ['major_recognizable_objects_moved'])

    def test_assessment_required_fields_and_types(self):
        cases = [{}, assessment(notes=''), assessment(notes=None),
                 assessment(major_recognizable_objects_moved=0), assessment(extra=False)]
        for value in cases:
            with self.subTest(value=value), self.assertRaises(ValueError):
                correction_report(self.sx, self.sy, value)

    def test_limits_validated_and_explicit_override_retained(self):
        for value in (-1, float('nan'), float('inf'), True):
            limits = dict(DEFAULT_LIMITS, displacement_max_px=value)
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.report(limits=limits)
        for limits in ({}, dict(DEFAULT_LIMITS, transported_percent=101),
                       dict(DEFAULT_LIMITS, transported_donor_reuse_ratio=2)):
            with self.assertRaises(ValueError):
                self.report(limits=limits)
        limits = dict(DEFAULT_LIMITS, displacement_max_px=200)
        self.assertEqual(self.report(limits=limits)['limits'], limits)

    def test_threshold_equality_passes(self):
        self.sx[0, 0] = 1
        limits = dict(DEFAULT_LIMITS, transported_percent=.01,
                      displacement_max_px=1, displacement_p95_px=1)
        self.assertEqual(self.report(limits=limits)['source_suitability'], 'PASS')

    def test_report_recomputation_detects_tampered_metrics(self):
        r = self.report()
        self.assertTrue(verify_report(r, self.sx, self.sy))
        for key, value in [('transported_pixels', 1), ('provenance_sha256', 'forged'),
                           ('resolution', [50, 200])]:
            bad = copy.deepcopy(r)
            bad['metrics'][key] = value
            self.assertFalse(verify_report(bad, self.sx, self.sy))

    def test_report_detects_tampered_gate_or_extra_metadata(self):
        r = self.report()
        for key, value in [('source_suitability', 'APPROVED'), ('rejection_reasons', ['invented']),
                           ('extra', 'unexpected'), ('schema_version', 2)]:
            bad = copy.deepcopy(r)
            bad[key] = value
            self.assertFalse(verify_report(bad, self.sx, self.sy))

    def test_map_change_invalidates_report(self):
        r = self.report()
        self.sx[0, 0] = 1
        self.assertFalse(verify_report(r, self.sx, self.sy))
        self.assertFalse(verify_report({}, self.sx, self.sy))

    def test_hash_stable_across_integer_storage_dtypes(self):
        first = measure_correction(self.sx, self.sy)
        second = measure_correction(self.sx.astype('int16'), self.sy.astype('uint16'))
        self.assertEqual(first, second)

    def test_rgb_report_requires_same_evidence_to_verify(self):
        src = np.zeros((100, 100, 3), dtype='uint8')
        r = self.report(source=src, candidate=src)
        self.assertTrue(verify_report(r, self.sx, self.sy, src, src))
        self.assertFalse(verify_report(r, self.sx, self.sy))


if __name__ == '__main__':
    unittest.main()
