#!/usr/bin/env python3
"""Flag corner-tile edge anomalies using calibrated image statistics, not semantics."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageStat


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def expected_mask(size):
    """NE owns x >= y; the diagonal pixel tie is only a raster convention."""
    mask = Image.new("L", (size, size))
    draw = ImageDraw.Draw(mask)
    draw.polygon([(0, 0), (size - 1, 0), (size - 1, size - 1)], fill=255)
    return mask


def stats(image, box):
    values = ImageStat.Stat(image.crop(box))
    return values.mean[0], values.stddev[0]


def analyze(image, mask=None, bins=32):
    if image.width != image.height or image.width < 64:
        raise ValueError("Use a square candidate of at least 64 pixels; no resizing occurs")
    if bins < 8 or bins > image.width // 2:
        raise ValueError("Bins must be between 8 and half the image width")
    size = image.width
    if mask is None:
        mask = expected_mask(size)
    if mask.size != image.size:
        raise ValueError("Mask and candidate dimensions must match exactly")
    mask = mask.convert("L")
    if any(mask.histogram()[1:255]):
        raise ValueError("Mask must be binary: white feature, black Field")
    if mask.tobytes() != expected_mask(size).tobytes():
        raise ValueError("This diagnostic requires canonical NE x >= y ownership")
    gray = image.convert("L")
    def box(x0, y0, x1, y1):
        return tuple(round(value * size) for value in (x0, y0, x1, y1))
    area_box = box(.62, .12, .88, .38)
    field_box = box(.12, .62, .38, .88)
    area_mean, area_texture = stats(gray, area_box)
    field_mean, field_texture = stats(gray, field_box)
    contrast = field_mean - area_mean
    reliable = abs(contrast) >= 8
    depth = max(2, round(size * .012))
    patches = []
    for edge in ("North", "East", "South", "West"):
        for index in range(bins):
            start, end = round(index * size / bins), round((index + 1) * size / bins)
            bounds = {"North": (start, 0, end, depth),
                      "East": (size - depth, start, size, end),
                      "South": (start, size - depth, end, size),
                      "West": (0, start, depth, end)}[edge]
            patches.append((f"{edge}_{index:02d}", bounds))
    corner = max(4, round(size * .04))
    patches.extend([("NE_shared_feature_corner", (size - corner, 0, size, corner)),
                    ("SW_Field_corner", (0, size - corner, corner, size)),
                    ("NW_transition_corner", (0, 0, corner, corner)),
                    ("SE_transition_corner", (size - corner, size - corner, size, size))])
    samples = []
    for name, bounds in patches:
        mean, texture = stats(gray, bounds)
        expected = ImageStat.Stat(mask.crop(bounds)).mean[0] / 255
        estimate = max(0, min(1, (field_mean - mean) / contrast)) if reliable else None
        deviation = abs(estimate - expected) if reliable else None
        suspicious = reliable and deviation > .35
        samples.append({"name": name, "box_xyxy": bounds,
                        "expected_feature_fraction": round(expected, 4),
                        "proxy_feature_fraction": round(estimate, 4) if reliable else None,
                        "mean_luminance": round(mean, 3), "luminance_stddev": round(texture, 3),
                        "absolute_deviation": round(deviation, 4) if reliable else None,
                        "result": "suspicious" if suspicious else "inconclusive" if not reliable else "no_proxy_anomaly"})
    anomalies = [sample["name"] for sample in samples if sample["result"] == "suspicious"]
    return {"method": "Calibrated luminance occupancy proxy; no semantic segmentation",
            "size_px": [size, size], "edge_bins": bins, "edge_sample_depth_px": depth,
            "thresholds": {"minimum_calibration_contrast": 8, "suspicious_deviation": .35},
            "calibration": {"feature_box": area_box, "field_box": field_box,
                            "feature_mean": round(area_mean, 3), "field_mean": round(field_mean, 3),
                            "feature_texture_stddev": round(area_texture, 3),
                            "field_texture_stddev": round(field_texture, 3),
                            "signed_luminance_contrast": round(contrast, 3), "reliable_proxy": reliable},
            "verdict": "suspicious" if anomalies else "inconclusive",
            "semantic_mechanical_pass": False,
            "reason": "Proxy anomalies require visual review" if anomalies else
                      "Insufficient calibration contrast" if not reliable else
                      "No proxy anomaly found; exact ownership still requires visual review",
            "suspicious_count": len(anomalies), "suspicious_samples": anomalies, "samples": samples,
            "limitations": ["Ink, texture, border aging and wash variations can cause false alarms.",
                            "Fine fringes smaller than the sample area may be missed.",
                            "Cannot identify roads, buildings, trees, false sockets or feature count semantically.",
                            "Corner patches and endpoint bins do not certify exact transition coordinates."]}


def write_review(candidate, mask_path, output_json, output_image, bins=32):
    paths = [output_json, output_image]
    if len(set(path.resolve() for path in paths)) != 2 or any(path.exists() for path in paths):
        raise FileExistsError("Choose new output names; existing files are never overwritten")
    original_hash = digest(candidate)
    with Image.open(candidate) as opened:
        image = opened.convert("RGB")
    mask = None
    if mask_path:
        with Image.open(mask_path) as opened:
            mask = opened.convert("L")
    result = analyze(image, mask, bins)
    result.update({"candidate": str(candidate.resolve()), "candidate_sha256": original_hash,
                   "mask": str(mask_path.resolve()) if mask_path else "canonical generated x >= y",
                   "mask_sha256": digest(mask_path) if mask_path else None})
    # Annotations are on a separate canvas. Source pixels are never rewritten.
    review = Image.new("RGB", (image.width, image.height + 70), "#f3efe6")
    review.paste(image, (0, 70))
    draw = ImageDraw.Draw(review)
    draw.text((8, 8), "REVIEW ONLY: " + result["verdict"].upper(), fill="black")
    draw.text((8, 28), "Red: proxy anomaly. Orange: inconclusive. Green: no proxy anomaly.", fill="black")
    draw.text((8, 46), "Image statistics cannot certify mechanical correctness.", fill="black")
    colors = {"suspicious": "#e12727", "inconclusive": "#db9100", "no_proxy_anomaly": "#27884a"}
    for sample in result["samples"]:
        x0, y0, x1, y1 = sample["box_xyxy"]
        draw.rectangle((x0, y0 + 70, x1 - 1, y1 + 69), outline=colors[sample["result"]], width=2)
    for path in paths:
        path.parent.mkdir(parents=True, exist_ok=True)
    with output_image.open("xb") as handle:
        review.save(handle, "PNG")
    if digest(candidate) != original_hash:
        raise RuntimeError("Candidate changed during review")
    with output_json.open("x") as handle:
        json.dump(result, handle, indent=2)
        handle.write("\n")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--mask", type=Path)
    parser.add_argument("--output-json", type=Path, required=True)
    parser.add_argument("--output-image", type=Path, required=True)
    parser.add_argument("--bins", type=int, default=32)
    args = parser.parse_args()
    result = write_review(args.candidate, args.mask, args.output_json, args.output_image, args.bins)
    print(f"{result['verdict']}: {result['suspicious_count']} suspicious samples; semantic pass not asserted")


if __name__ == "__main__":
    main()
