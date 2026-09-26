"""Measure local repair cost; never infer object identity from artwork pixels.

Default limits are review heuristics, not gameplay/geometry rules: <=3% of pixels
transported, <=80 px p95 and <=160 px maximum travel, <=25% duplicate donors
among transported pixels. Limits must be recorded explicitly when overridden.
All displacement distances use native image pixels, over transported pixels only.
"""
import hashlib
import math

import numpy as np
from PIL import Image


DEFAULT_LIMITS = {
    'transported_percent': 3.0,
    'displacement_p95_px': 80.0,
    'displacement_max_px': 160.0,
    'transported_donor_reuse_ratio': 0.25,
}
ASSESSMENT_KEYS = (
    'major_recognizable_objects_moved', 'repeated_motifs_introduced',
    'edge_repair_visible_at_review_scale', 'source_rejected_before_composition',
)


def _maps(source_x, source_y):
    sx, sy = np.asarray(source_x), np.asarray(source_y)
    if sx.ndim != 2 or sx.shape != sy.shape or not sx.size:
        raise ValueError('provenance maps must be nonempty matching 2D arrays')
    if any(a.dtype.kind not in 'iu' for a in (sx, sy)):
        raise ValueError('provenance coordinates must be integers')
    height, width = sx.shape
    if np.any(sx < 0) or np.any(sx >= width) or np.any(sy < 0) or np.any(sy >= height):
        raise ValueError('provenance coordinate outside source image')
    return sx.astype('int64'), sy.astype('int64')


def repair_zone(source_x, source_y):
    """Binary native-resolution PNG-ready mask: 255 means a transported pixel."""
    sx, sy = _maps(source_x, source_y)
    yy, xx = np.indices(sx.shape)
    return Image.fromarray(np.where((sx != xx) | (sy != yy), 255, 0).astype('uint8'))


def measure_correction(source_x, source_y, source=None, candidate=None):
    """Measure map transport and, optionally, exact changed RGB area.

    Supplying both images also verifies every output pixel equals its recorded
    donor. A transported uniform pixel need not have changed visible RGB values.
    Reuse counts repeated coordinates, not repeated semantic objects.
    """
    sx, sy = _maps(source_x, source_y)
    height, width = sx.shape
    yy, xx = np.indices(sx.shape)
    changed = (sx != xx) | (sy != yy)
    count = int(changed.sum())
    distance = np.hypot(sx[changed] - xx[changed], sy[changed] - yy[changed])
    donor_ids = sy * width + sx
    unique = len(np.unique(donor_ids[changed]))
    reuse = count - unique
    visible_changed = None
    if (source is None) != (candidate is None):
        raise ValueError('source and candidate images must be supplied together')
    if source is not None:
        src, out = np.asarray(source), np.asarray(candidate)
        if src.shape != (height, width, 3) or out.shape != src.shape:
            raise ValueError('source and candidate must be matching native RGB arrays')
        if src.dtype != np.uint8 or out.dtype != np.uint8:
            raise ValueError('source and candidate RGB must be uint8')
        if not np.array_equal(out, src[sy, sx]):
            raise ValueError('candidate pixels disagree with provenance')
        visible_changed = int(np.any(src != out, axis=2).sum())
    # Hash normalized endian/dtype representation so saved maps can be verified.
    signature = hashlib.sha256()
    signature.update(np.asarray(sx.shape, dtype='<i8').tobytes())
    signature.update(sx.astype('<i8').tobytes())
    signature.update(sy.astype('<i8').tobytes())
    return {
        'resolution': [width, height], 'total_pixels': int(sx.size),
        'transported_pixels': count, 'transported_percent': count * 100 / sx.size,
        'unchanged_coordinate_pixels': int(sx.size) - count,
        'rgb_changed_pixels': visible_changed,
        'rgb_changed_percent': None if visible_changed is None else visible_changed * 100 / sx.size,
        'displacement_p95_px': float(np.percentile(distance, 95)) if count else 0.0,
        'displacement_max_px': float(distance.max()) if count else 0.0,
        'unique_transported_donors': unique, 'transported_donor_reuse_count': reuse,
        'transported_donor_reuse_ratio': reuse / count if count else 0.0,
        'all_output_duplicate_donor_count': int(sx.size) - len(np.unique(donor_ids)),
        'provenance_sha256': signature.hexdigest(),
    }


def correction_report(source_x, source_y, assessment, limits=None, source=None, candidate=None):
    """Return reproducible metrics plus a conservative source suitability gate.

    Human flags accept True/False/None; None means not yet reviewed. Any True
    rejects suitability, unknown flags prevent acceptance. Notes explain human
    observations. Numeric limit overrides are explicit and stored in the report.
    This gate concerns illustration repair cost only, never mechanical legality.
    """
    if not isinstance(assessment, dict) or set(assessment) != set(ASSESSMENT_KEYS) | {'notes'}:
        raise ValueError('assessment must contain all four flags and notes only')
    if any(v is not None and type(v) is not bool for k, v in assessment.items() if k != 'notes'):
        raise ValueError('assessment flags must be boolean or None')
    if not isinstance(assessment['notes'], str) or not assessment['notes'].strip():
        raise ValueError('assessment notes must explain observations or pending review')
    thresholds = dict(DEFAULT_LIMITS if limits is None else limits)
    if set(thresholds) != set(DEFAULT_LIMITS):
        raise ValueError('limits must include exactly the four documented metrics')
    if any(type(v) not in (int, float) or not math.isfinite(v) or v < 0 for v in thresholds.values()):
        raise ValueError('limits must be finite nonnegative numbers')
    if thresholds['transported_percent'] > 100 or thresholds['transported_donor_reuse_ratio'] > 1:
        raise ValueError('percentage/ratio limits exceed their defined range')
    metrics = measure_correction(source_x, source_y, source, candidate)
    reasons = ['limit:' + key for key, maximum in thresholds.items() if metrics[key] > maximum]
    reasons.extend('human:' + key for key in ASSESSMENT_KEYS if assessment[key] is True)
    pending = [key for key in ASSESSMENT_KEYS if assessment[key] is None]
    return {
        'schema_version': 1, 'metrics': metrics, 'limits': thresholds,
        'assessment': dict(assessment),
        'source_suitability': 'REJECT' if reasons else 'NEEDS_REVIEW' if pending else 'PASS',
        'rejection_reasons': reasons, 'pending_assessments': pending,
        'status': 'CANDIDATE — AWAITING HUMAN REVIEW',
        'limitation': 'Provenance counts coordinates, not objects; human judgments are supplied, not image recognition.',
    }


def verify_report(report, source_x, source_y, source=None, candidate=None):
    """Detect tampered metrics/decisions by recomputing against actual map data.

    This cannot authenticate human opinions or prove that chosen limits were
    approved. Callers should independently preserve their assessment provenance.
    """
    try:
        expected = correction_report(source_x, source_y, report['assessment'],
                                     report['limits'], source, candidate)
        return type(report) is dict and report == expected
    except (KeyError, TypeError, ValueError):
        return False
