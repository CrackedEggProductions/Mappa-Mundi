#!/usr/bin/env python3
"""Transport an illustrated frontier onto exact masks without alpha-cutting motifs.

Uses Pillow plus already-installed NumPy. Never writes the source. The calibrated
frontier is an art annotation, not automatic semantic segmentation.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from boundary_generator import generate_boundary
from mask_utils import make_masks
from build_seam_sheet import save_new

ROOT = Path(__file__).resolve().parents[2]
SOURCES = {
    'settlement_corner': 'settlement_corner_wave2_v02.png',
    'forest_bend': 'forest_bend_wave2_v01.png',
}
# Source wall foot / undergrowth edge, in native inclusive pixel coordinates.
# Preserve the drawn frontier as a coherent strip; do not segment buildings.
TRACES = {
    'settlement_corner': [(0,8),(100,116),(200,190),(300,275),(400,354),
        (500,425),(600,514),(700,577),(800,666),(900,756),(1000,850),
        (1100,924),(1180,1024),(1253,1164)],
    'forest_bend': [(0,32),(100,143),(200,222),(300,315),(400,386),
        (500,461),(600,560),(700,651),(800,735),(900,822),(1000,940),
        (1100,1004),(1180,1100),(1253,1192)],
}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def transport(source, path, source_trace, transition_width=60, field_mode='anchored'):
    """Inverse, monotone column transport; hard masks select interpolation side.

    The 60px frontier strip travels intact wherever room permits; remote pixels
    absorb displacement gradually. At the two endpoints the strip tapers and
    the incompatible source fringe is cropped. No drawn wall/tree is alpha-cut.
    """
    size = source.width
    if source.size != (size, size) or size < 3:
        raise ValueError('Source must be square and at least three pixels')
    if len(path) != size or not 0 < transition_width < size:
        raise ValueError('Path/transition width must match source dimensions')
    if field_mode not in ('anchored','relaxed'):
        raise ValueError('Unknown Field transport mode')
    masks = make_masks(path, size, transition_width)
    owner = np.asarray(masks['feature']) == 255
    rows = np.arange(size, dtype=float)
    src_y = np.empty((size, size), dtype=np.float32)
    trace = np.interp(rows, *zip(*source_trace))
    pixels = np.asarray(source.convert('RGB'))
    result = np.empty_like(pixels)
    source_owner = np.empty((size, size), dtype=np.uint8)
    for x in range(size):
        target = int(np.count_nonzero(owner[:, x])) - 1
        original = float(trace[x])
        half = transition_width / 2
        # Preserve continuous value and slope across the frontier where possible.
        left = min(half, target, original)
        right = min(half, size-1-target, size-1-original)
        knots = {0: 0.0, size-1: float(size-1)}
        knots.update({target-left: original-left, target: original,
                      target+right: original+right})
        xs = sorted(knots)
        ys = [knots[k] for k in xs]
        coords = np.interp(rows, xs, ys)
        if field_mode == 'relaxed':
            # A displacement field releases toward the remote Field interior.
            # Unlike anchoring the bottom, it does not squeeze decorations into
            # a vanishing southeast wedge. The first half-band translates whole.
            distance = np.maximum(0, rows-target-half)
            falloff = max(size*0.45, abs(target-original)*3)
            relaxed = rows-(target-original)*np.exp(-(distance/falloff)**2)
            coords = np.where(owner[:,x],coords,np.clip(relaxed,original,size-1))
        # Prevent bilinear sampling across the source ownership boundary.
        lo = np.floor(coords).astype(int)
        hi = np.minimum(lo+1, size-1)
        boundary_pixel = int(np.floor(original))
        lo = np.where(owner[:,x], np.minimum(lo,boundary_pixel),
                      np.maximum(lo,boundary_pixel+1))
        hi = np.where(owner[:,x], np.minimum(hi,boundary_pixel),
                      np.maximum(hi,boundary_pixel+1))
        lo, hi = np.clip(lo,0,size-1), np.clip(hi,0,size-1)
        fraction = (coords-np.floor(coords))[:,None]
        result[:,x] = np.rint(pixels[lo,x]*(1-fraction)+pixels[hi,x]*fraction).astype('uint8')
        src_y[:,x] = coords
        source_owner[:,x] = np.where(lo <= boundary_pixel,255,0)
    assert np.array_equal(source_owner, np.asarray(masks['feature']))
    return Image.fromarray(result), masks, src_y, Image.fromarray(source_owner)


def json_new(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x') as handle:
        json.dump(data, handle, indent=2)
        handle.write('\n')


def run(tile, version, seed, irregularity, transition_width=60, field_mode='anchored'):
    source = ROOT/'art/generated/candidates'/tile/SOURCES[tile]
    before = digest(source)
    with Image.open(source) as opened:
        image = opened.convert('RGB')
    if image.size != (1254,1254):
        raise ValueError('Calibrated source trace requires native 1254 square')
    path = generate_boundary(image.width, seed, irregularity)
    output, masks, coordinates, provenance = transport(image,path,TRACES[tile],transition_width,field_mode)
    stem = f'{tile}_hybrid_v{version:02d}'
    dest = ROOT/'art/generated/candidates/hybrid_corrected'/tile/f'{stem}.png'
    maskdir = ROOT/'art/templates/hybrid_masks'
    boundarydir = ROOT/'art/templates/hybrid_boundaries'
    review = ROOT/'art/reviews/trial_03'
    targets = [dest, review/'debug'/f'{stem}_debug.png',
               boundarydir/f'{stem}.json', boundarydir/f'{stem}.png',
               review/f'{stem}_composition.json',maskdir/f'{stem}_provenance.png']
    targets += [maskdir/f'{stem}_{key}.png' for key in masks]
    if any(p.exists() for p in targets):
        raise FileExistsError('Output exists; choose a fresh version; never overwrite')
    save_new(output,dest)
    for key, mask in masks.items(): save_new(mask,maskdir/f'{stem}_{key}.png')
    save_new(provenance,maskdir/f'{stem}_provenance.png')
    json_new(boundarydir/f'{stem}.json',{'size':1254,'seed':seed,'irregularity':irregularity,
        'coordinate_convention':'inclusive pixel centers 0..1253; NW/SE ties feature',
        'source_trace':TRACES[tile],'path':path})
    diagram = Image.composite(Image.new('RGB',image.size,'#75805c'),
                              Image.new('RGB',image.size,'#ece0be'),masks['feature'])
    ImageDraw.Draw(diagram).line(path, fill='#613e27',width=3)
    save_new(diagram,boundarydir/f'{stem}.png')
    debug = Image.blend(output,diagram,0.25)
    draw = ImageDraw.Draw(debug)
    draw.rectangle((0,0,1253,1253),outline='#b33d85',width=2)
    draw.line(path,fill='#ca2582',width=2)
    for x,y in (path[0],path[-1]): draw.ellipse((x-9,y-9,x+9,y+9),fill='#12bde6')
    save_new(debug,review/'debug'/f'{stem}_debug.png')
    json_new(review/f'{stem}_composition.json',{
        'status':'CANDIDATE — AWAITING HUMAN REVIEW','source':str(source.relative_to(ROOT)),
        'source_sha256':before,'candidate':str(dest.relative_to(ROOT)),
        'candidate_sha256':digest(dest),'size':[1254,1254], 'seed':seed,
        'transition_width':transition_width,'method':'continuous region-aware column transport',
        'field_mode':field_mode,
        'boundary':str((boundarydir/f'{stem}.json').relative_to(ROOT)),
        'masks':{k:str((maskdir/f'{stem}_{k}.png').relative_to(ROOT)) for k in masks},
        'provenance':str((maskdir/f'{stem}_provenance.png').relative_to(ROOT)),
        'source_coordinate_sha256':hashlib.sha256(coordinates.tobytes()).hexdigest(),
        'source_trace_is':'manual wall-foot/undergrowth calibration; not semantic certification',
        'palette_changes':'none; same-column linear interpolation only',
        'source_owner_equals_output_mask':True})
    assert digest(source)==before
    print(dest.relative_to(ROOT))
    return dest


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tile',choices=SOURCES,required=True)
    parser.add_argument('--version',type=int,required=True)
    parser.add_argument('--seed',type=int,default=31)
    parser.add_argument('--irregularity',type=float,default=0.025)
    parser.add_argument('--transition-width',type=int,default=60)
    parser.add_argument('--field-mode',choices=['anchored','relaxed'],default='relaxed')
    args=parser.parse_args()
    run(args.tile,args.version,args.seed,args.irregularity,args.transition_width,args.field_mode)
