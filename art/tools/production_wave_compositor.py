"""Translation-only local repairs for multi-feature tile illustration sources.

No coordinate scaling/warping is permitted. Manual source membership traces are
review inputs, not automatic semantic recognition. Known target masks own geometry.
"""
import argparse
import hashlib
import json
import shutil
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from hybrid_wave_geometry import generate, metadata, validate, TILES, expected_edges

ROOT = Path(__file__).resolve().parents[2]
ORDER = ('Field', 'Settlement', 'Forest', 'Road', 'River')


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def labels(masks):
    result = np.zeros(np.asarray(next(iter(masks.values()))).shape, dtype=np.uint8)
    for i, name in enumerate(ORDER):
        if name in masks:
            result[np.asarray(masks[name]) > 0] = i
    return result


def source_masks(calibration, size):
    """Human-traced source polygons; separate interior street/urban membership."""
    masks = {}
    for feature, polygons in calibration['polygons'].items():
        im = Image.new('L', (size, size)); draw = ImageDraw.Draw(im)
        for polygon in polygons:
            draw.polygon([tuple(point) for point in polygon], fill=255)
        masks[feature] = im
    covered = np.logical_or.reduce([np.asarray(m)>0 for m in masks.values()])
    masks['Field'] = Image.fromarray(np.where(covered,0,255).astype('uint8'))
    return masks


def repair(source, source_membership, target_membership, block=24):
    """Fill misclassified areas with nearby complete translated donor blocks.

    Unchanged locations retain their exact original RGB bytes. Every repaired
    pixel records its integer donor coordinate; no interpolation or stretching.
    """
    src = np.asarray(source.convert('RGB')); h,w = src.shape[:2]
    src_owner, target_owner = labels(source_membership), labels(target_membership)
    if src_owner.shape != (h,w) or target_owner.shape != (h,w):
        raise ValueError('membership dimensions must match native image')
    out = src.copy(); yy,xx = np.indices((h,w)); sy,sx = yy.copy(),xx.copy()
    changed = src_owner != target_owner
    for owner in np.unique(target_owner):
        wrong = changed & (target_owner == owner)
        if not wrong.any(): continue
        binary = Image.fromarray(np.where(src_owner == owner,255,0).astype('uint8'))
        # Patch centers need a complete same-feature donor rectangle.
        safe = np.asarray(binary.filter(ImageFilter.MinFilter(block+1))) > 0
        safe[:block]=False;safe[-block:]=False;safe[:,:block]=False;safe[:,-block:]=False
        dy,dx = np.nonzero(safe[::8,::8]);dy*=8;dx*=8
        if not len(dx): raise ValueError(f'No safe source donor for {ORDER[owner]}')
        used=np.zeros(len(dx),dtype='int32')
        by,bx=np.nonzero(wrong)
        occupied=sorted(set(zip((by//block).tolist(),(bx//block).tolist())))
        for row,col in occupied:
            y,x=row*block,col*block; y2,x2=min(y+block,h),min(x+block,w)
            cy,cx=y+(y2-y)//2,x+(x2-x)//2
            distance=(dy-cy)**2+(dx-cx)**2+used*(block*block*12)
            nearest=int(np.argmin(distance)); oy,ox=int(dy[nearest]-cy),int(dx[nearest]-cx)
            used[nearest]+=1
            local=wrong[y:y2,x:x2]; ys,xs=np.nonzero(local);ys+=y;xs+=x
            ty,tx=ys+oy,xs+ox
            assert np.all(src_owner[ty,tx]==owner)
            out[ys,xs]=src[ty,tx];sy[ys,xs]=ty;sx[ys,xs]=tx
    provenance=src_owner[sy,sx]
    assert np.array_equal(provenance,target_owner)
    return Image.fromarray(out),sx.astype('int16'),sy.astype('int16'),changed


def throughway_target(origins, collar=96):
    """Keep a traced organic city interior; reconstruct only N/S corner fans.

    The family constrains endpoints/connectivity, not a fixed corridor waist.
    No RGB coordinate moves merely because this interior mask is narrower.
    """
    city=np.asarray(origins['Settlement']).copy();size=len(city)
    for y in range(size):
        occupied=np.flatnonzero(city[y])
        if not len(occupied):raise ValueError('city trace must connect every row')
        left,right=int(occupied[0]),int(occupied[-1])
        distance=min(y,size-1-y)
        if distance<collar:
            t=distance/collar;t=t*t*(3-2*t)
            left=round(left*t);right=round((size-1)*(1-t)+right*t)
        if distance>0:left=max(1,left);right=min(size-2,right)
        city[y]=0;city[y,left:right+1]=255
    return {'Settlement':Image.fromarray(city),'Field':Image.fromarray(255-city)}


def runs(values):
    padded=np.pad(values.astype(bool),(1,1)).astype('int8')
    delta=np.diff(padded)
    return list(zip(np.flatnonzero(delta==1),np.flatnonzero(delta==-1)-1))


def fitted_targets(origins, tile, collar=96):
    """Adapt interior contours, not illustration coordinates, to exact ports.

    At the outer pixel use the canonical edge verbatim. Within a bounded collar,
    ease interval endpoints from that grammar into the human-traced source shape.
    Features are still validated independently; streets do not split Settlement.
    """
    record=metadata(tile); n=record['resolution'][0]; result={}
    for name in record['components']:
        original=np.asarray(origins[name]); a=original.copy()
        expected=expected_edges(record,name)
        for side in ('N','S','W','E'):
            wanted=runs(expected[side])
            for depth in range(collar):
                t=depth/collar;t=t*t*(3-2*t)
                index=depth if side in ('N','W') else n-1-depth
                source=original[index,:] if side in ('N','S') else original[:,index]
                existing=runs(source); line=np.zeros(n,dtype='uint8')
                if wanted:
                    for lo,hi in wanted:
                        near=min(existing,key=lambda r:abs((r[0]+r[1])-(lo+hi))) if existing else (lo,hi)
                        left=round(lo*(1-t)+near[0]*t);right=round(hi*(1-t)+near[1]*t)
                        line[left:right+1]=255
                elif depth:
                    for lo,hi in existing:
                        center=(lo+hi)/2;half=(hi-lo+1)*t/2
                        if half>=.5:line[round(center-half):round(center+half)+1]=255
                if side in ('N','S'):a[index,:]=line
                else:a[:,index]=line
        a[0,:]=expected['N'];a[-1,:]=expected['S'];a[:,0]=expected['W'];a[:,-1]=expected['E']
        result[name]=a
    if tile!='settlement_road_throughway':
        for transport in ('Road','River'):
            if transport in result:
                for region in ('Settlement','Forest'):
                    if region in result:result[transport][result[region]>0]=0
    covered=np.logical_or.reduce([a>0 for a in result.values()])
    result['Field']=np.where(covered,0,255).astype('uint8')
    return {name:Image.fromarray(a) for name,a in result.items()}


def render(source, calibration, tile):
    if source.size!=(1254,1254):raise ValueError('native1254 source required')
    targets=generate(tile); origins=source_masks(calibration,source.width)
    if tile!='settlement_road_throughway':
        for transport in ('Road','River'):
            if transport in origins:
                a=np.asarray(origins[transport]).copy()
                for region in ('Settlement','Forest'):
                    if region in origins:a[np.asarray(origins[region])>0]=0
                origins[transport]=Image.fromarray(a)
    if tile=='settlement_throughway':targets=throughway_target(origins)
    else:targets=fitted_targets(origins,tile)
    expected=set(targets)-{'Field'}
    if set(origins)-{'Field'} != expected:raise ValueError('source feature count differs')
    output,sx,sy,changed=repair(source,origins,targets)
    return output,targets,origins,sx,sy,changed


def build(tile,version,rebuild=False):
    stem=f'{tile}_v{version:02d}';review=ROOT/'art/reviews/production_wave_01'
    srcpath=review/'sources'/f'{stem}.png';calpath=review/'calibrations'/f'{stem}.json'
    dest=ROOT/'art/generated/candidates/production_wave_01'/tile/f'{stem}.png'
    recordpath=review/'compositions'/f'{stem}.json'
    mapfile=review/'provenance'/f'{stem}.npz'
    if any(p.exists() for p in (dest,recordpath,mapfile)) and not rebuild:raise FileExistsError(stem)
    calibration=json.loads(calpath.read_text())
    with Image.open(srcpath) as im: source=im.convert('RGB')
    out,masks,origins,sx,sy,changed=render(source,calibration,tile)
    result=validate(masks,metadata(tile));assert result['valid']
    if rebuild:
        stamp=datetime.now().strftime('%Y%m%d-%H%M%S')
        previous=[dest,recordpath,mapfile,*list((review/'masks'/stem).glob('*.png'))]
        for path in previous:
            if path.exists():shutil.copy2(path,str(path)+'.bak-'+stamp)
    for p in (dest,recordpath,mapfile):p.parent.mkdir(parents=True,exist_ok=True)
    maskdir=review/'masks'/stem;maskdir.mkdir(parents=True,exist_ok=True)
    for feature,mask in masks.items():mask.save(maskdir/(feature+'.png'))
    out.save(dest);np.savez_compressed(mapfile,source_x=sx,source_y=sy,owner=labels(masks))
    record={'status':'CANDIDATE — AWAITING HUMAN REVIEW','tile':tile,'version':version,
      'source':str(srcpath.relative_to(ROOT)),'source_sha256':digest(srcpath),
      'candidate':str(dest.relative_to(ROOT)),'candidate_sha256':digest(dest),
      'calibration':str(calpath.relative_to(ROOT)),'calibration_sha256':digest(calpath),
      'provenance':str(mapfile.relative_to(ROOT)),'provenance_sha256':digest(mapfile),
      'method':'native integer translation patches; no scale, warp, or interpolation',
      'repaired_pixels':int(changed.sum()),'original_pixels_retained':int((~changed).sum()),
      'topology':metadata(tile),'geometry_validation':result,'masks':str(maskdir.relative_to(ROOT)),
      'limitation':'Masks and trace provenance proven; source semantic tracing and patch artifacts require visual review.'}
    recordpath.write_text(json.dumps(record,indent=2)+'\n');print(stem,'PASS',record['repaired_pixels'],'repaired pixels')


def verify(path):
    r=json.loads(Path(path).read_text());src=ROOT/r['source'];cal=ROOT/r['calibration']
    dst=ROOT/r['candidate'];mp=ROOT/r['provenance']
    checks={name+'_hash':digest(ROOT/r[name])==r[name+'_sha256'] for name in ('source','candidate','calibration','provenance')}
    with Image.open(src) as im:source=im.convert('RGB')
    out,masks,origins,sx,sy,changed=render(source,json.loads(cal.read_text()),r['tile'])
    with Image.open(dst) as im:checks['exact_reconstruction']=im.convert('RGB').tobytes()==out.tobytes()
    with np.load(mp,allow_pickle=False) as p:
        checks['coordinate_map']=np.array_equal(p['source_x'],sx) and np.array_equal(p['source_y'],sy)
        checks['owner']=np.array_equal(p['owner'],labels(masks))
        checks['actual_donor_membership']=np.array_equal(labels(origins)[sy,sx],p['owner'])
    checks['saved_masks']=all(Image.open(ROOT/r['masks']/(name+'.png')).tobytes()==mask.tobytes() for name,mask in masks.items())
    checks['geometry']=validate(masks,r['topology'])['valid']
    checks['history_matches_geometry']=r['geometry_validation']==validate(masks,r['topology'])
    checks['retained_pixels']=r['original_pixels_retained']==int((~changed).sum())
    checks['source_unchanged']=digest(src)==r['source_sha256']
    pixels=np.asarray(out)
    for k in range(4):checks[f'rotation_{90*k}']=np.array_equal(np.rot90(np.rot90(pixels,k),-k),pixels)
    return {'record':str(path),'valid':all(checks.values()),'checks':checks}


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--tile',choices=TILES);p.add_argument('--version',type=int)
    p.add_argument('--verify',nargs='+');p.add_argument('--rebuild',action='store_true');a=p.parse_args()
    if a.verify:
        results=[verify(path) for path in a.verify]
        for r in results:print('PASS' if r['valid'] else 'FAIL',r['record'],sum(r['checks'].values()),'/',len(r['checks']))
        raise SystemExit(0 if all(r['valid'] for r in results) else 1)
    build(a.tile,a.version,a.rebuild)
