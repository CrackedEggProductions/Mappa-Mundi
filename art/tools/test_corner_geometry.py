#!/usr/bin/env python3
"""Synthetic checks for the art-review proxy; no gameplay or model calls."""
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

from check_corner_geometry import analyze, digest, expected_mask, write_review


class CornerGeometryTests(unittest.TestCase):
    def correct(self):
        return Image.composite(Image.new("RGB", (256, 256), (70, 80, 60)),
                               Image.new("RGB", (256, 256), (220, 215, 190)), expected_mask(256))

    def test_correct_geometry_has_no_proxy_anomalies_but_never_semantic_pass(self):
        result = analyze(self.correct())
        self.assertEqual(result["suspicious_count"], 0)
        self.assertEqual(result["verdict"], "inconclusive")
        self.assertFalse(result["semantic_mechanical_pass"])
        self.assertEqual(len(result["samples"]), 132)

    def test_shifted_diagonal_flags_transition_endpoints(self):
        image = Image.new("RGB", (256, 256), (220, 215, 190))
        ImageDraw.Draw(image).polygon([(40, 0), (255, 0), (255, 215)], fill=(70, 80, 60))
        result = analyze(image)
        self.assertEqual(result["verdict"], "suspicious")
        self.assertIn("North_00", result["suspicious_samples"])
        self.assertIn("East_31", result["suspicious_samples"])

    def test_feature_edge_fringe_is_detected(self):
        image = self.correct()
        ImageDraw.Draw(image).rectangle((248, 0, 255, 255), fill=(220, 215, 190))
        result = analyze(image)
        self.assertIn("East_16", result["suspicious_samples"])

    def test_wrong_edge_leak_is_detected(self):
        image = self.correct()
        ImageDraw.Draw(image).rectangle((0, 40, 7, 220), fill=(70, 80, 60))
        result = analyze(image)
        self.assertIn("West_16", result["suspicious_samples"])

    def test_shared_corner_gap_is_detected(self):
        image = self.correct()
        ImageDraw.Draw(image).rectangle((240, 0, 255, 16), fill=(220, 215, 190))
        self.assertIn("NE_shared_feature_corner", analyze(image)["suspicious_samples"])

    def test_uniform_image_is_inconclusive(self):
        result = analyze(Image.new("RGB", (256, 256), "tan"))
        self.assertFalse(result["calibration"]["reliable_proxy"])
        self.assertEqual(result["verdict"], "inconclusive")
        self.assertFalse(result["semantic_mechanical_pass"])
        self.assertTrue(all(sample["proxy_feature_fraction"] is None for sample in result["samples"]))

    def test_dimension_and_nonbinary_masks_rejected(self):
        with self.assertRaises(ValueError):
            analyze(self.correct(), Image.new("L", (128, 128)))
        with self.assertRaises(ValueError):
            analyze(self.correct(), Image.new("L", (256, 256), 127))
        with self.assertRaises(ValueError):
            analyze(self.correct(), Image.new("L", (256, 256), 255))

    def test_native_review_preserves_source_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            folder = Path(folder)
            source, mask = folder / "source.png", folder / "mask.png"
            output, annotation = folder / "review.json", folder / "review.png"
            self.correct().save(source)
            expected_mask(256).save(mask)
            original = digest(source)
            result = write_review(source, mask, output, annotation)
            self.assertEqual(digest(source), original)
            self.assertEqual(result["candidate_sha256"], original)
            with Image.open(annotation) as image:
                self.assertEqual(image.size, (256, 326))
            with self.assertRaises(FileExistsError):
                write_review(source, mask, output, annotation)
            self.assertEqual(digest(source), original)


if __name__ == "__main__":
    unittest.main()
