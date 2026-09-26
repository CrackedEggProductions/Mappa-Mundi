#!/usr/bin/env python3
"""Region-aware interval transport and smooth Road socket collars.

Local source traces calibrate illustration interiors. Production masks determine
full-edge ownership; Road collars enforce canonical ports without replacing the
organic junction. All output files are new and source files are immutable.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from build_seam_sheet import save_new
from hybrid_compositor import ROOT, digest, json_new
from production_geometry import generate_mask, validate_mask, socket_bounds

FAMILIES={'forest_edge':'full_edge_single','forest_belt':'full_edge_opposite',
          'settlement_throughway':'full_edge_opposite','road_junction':'road_three_way'}


def interval_coordinates(length, source_lo, source_hi, target_lo, target_hi, band=30):
    """Monotone inverse map; preserve a narrow illustrated frontier strip."""
    last=length-1
    if not 0 <= source_lo <= source_hi <= last or not 0 <= target_lo <= target_hi <= last:
        raise ValueError('Interval outside source or target')
    knots={0:0.,last:float(last)}
    lowroom=min(band,source_lo,target_lo)
    room=min(band,(source_hi-source_lo)/3,(target_hi-target_lo)/3)
    highroom=min(band,last-source_hi,last-target_hi)
    knots.update({target_lo-lowroom:source_lo-lowroom,
                  target_lo:source_lo,target_lo+room:source_lo+room,
                  target_hi-room:source_hi-room,target_hi:source_hi,
                  target_hi+highroom:source_hi+highroom})
    xs=sorted(knots)
    return np.interp(np.arange(length),xs,[knots[x] for x in xs])


def sample_bilinear(source, xs, ys):
    pixels=np.asarray(source.convert('RGB'),dtype=float)
    h,w=pixels.shape[:2]
    xs,ys=np.clip(xs,0,w-1),np.clip(ys,0,h-1)
    x0,y0=np.floor(xs).astype(int),np.floor(ys).astype(int)
    x1,y1=np.minimum(x0+1,w-1),np.minimum(y0+1,h-1)
    fx,fy=(xs-x0)[...,None],(ys-y0)[...,None]
    result=(pixels[y0,x0]*(1-fx)+pixels[y0,x1]*fx)*(1-fy)+(pixels[y1,x0]*(1-fx)+pixels[y1,x1]*fx)*fy
    return Image.fromarray(np.rint(result).astype('uint8'))


def render_region(source, tile, calibration, seed=41):
    size=source.width
    if source.size!=(size,size):raise ValueError('Square source required')
    mask=generate_mask(FAMILIES[tile],size,seed,
                       inset_fraction=calibration.get('inset_fraction',0.24))
    target=np.asarray(mask)>0
    source_mask=np.zeros((size,size),dtype=np.uint8)
    rows=np.arange(size)
    xs,ys=np.meshgrid(rows.astype(float),rows.astype(float))
    if tile=='forest_edge':
        high=np.interp(rows,*zip(*calibration['frontier']))
        for x in range(size):
            hi=np.flatnonzero(target[:,x])[-1]
            ys[:,x]=interval_coordinates(size,0,high[x],0,hi)
            source_mask[:int(high[x])+1,x]=255
            # Sampling cannot cross the hard owner's source interval.
            ys[:,x]=np.where(target[:,x],np.minimum(ys[:,x],np.floor(high[x])),
                            np.maximum(ys[:,x],np.floor(high[x])+1))
    else:
        low=np.interp(rows,*zip(*calibration['left']))
        high=np.interp(rows,*zip(*calibration['right']))
        for y in range(size):
            occupied=np.flatnonzero(target[y]);lo,hi=occupied[0],occupied[-1]
            xs[y]=interval_coordinates(size,low[y],high[y],lo,hi)
            sl,sh=int(np.ceil(low[y])),int(np.floor(high[y]))
            source_mask[y,sl:sh+1]=255
            xs[y]=np.where(target[y],np.clip(xs[y],sl,sh),
                np.where(rows<lo,np.minimum(xs[y],sl-1),np.maximum(xs[y],sh+1)))
    xs,ys=np.clip(xs,0,size-1),np.clip(ys,0,size-1)
    # Nearest labels prove owner transport independently of output colors.
    owners=source_mask[np.rint(ys).astype(int),np.rint(xs).astype(int)]
    if not np.array_equal(owners,np.asarray(mask)):raise ValueError('Sampling ownership mismatch')
    return sample_bilinear(source,xs,ys),mask,Image.fromarray(source_mask),Image.fromarray(owners),xs,ys


def render_road(source, calibration, seed=41):
    size=source.width
    if source.size!=(size,size):raise ValueError('Square source required')
    rows=np.arange(size,dtype=float);xs,ys=np.meshgrid(rows,rows)
    collar=calibration.get('collar',240)
    lo,hi=socket_bounds(size,.10)
    for side in ('N','S','E'):
        sl,sh=calibration['ports'][side]
        # Map pixel-area boundaries, preserving symmetry and inclusive labels.
        mapped=np.interp(rows,[0,lo-.5,hi+.5,size-1],[0,sl-.5,sh+.5,size-1])
        if side in ('N','S'):
            distance=ys if side=='N' else size-1-ys
            t=np.clip(1-distance/collar,0,1)
            weight=t*t*(3-2*t)
            xs+=weight*(mapped[None,:]-rows[None,:])
        else:
            t=np.clip(1-(size-1-xs)/collar,0,1)
            weight=t*t*(3-2*t)
            ys+=weight*(mapped[:,None]-rows[:,None])
    sm=Image.new('L',(size,size));ImageDraw.Draw(sm).polygon(calibration['polygon'],fill=255)
    a=np.asarray(sm)
    owners=a[np.clip(np.rint(ys).astype(int),0,size-1),np.clip(np.rint(xs).astype(int),0,size-1)]
    mask=Image.fromarray(owners)
    result=validate_mask(mask,'road_three_way')
    if not result['valid']:raise ValueError('Road collar geometry failed: '+str(result))
    return sample_bilinear(source,xs,ys),mask,sm,Image.fromarray(owners),xs,ys


def render(source,tile,calibration,seed=41):
    return render_road(source,calibration,seed) if tile=='road_junction' else render_region(source,tile,calibration,seed)


def run(tile,version,seed=41):
    review=ROOT/'art/reviews/geometry_wave'; stem=f'{tile}_geo_v{version:02d}'
    source=review/'sources'/f'{tile}_source_v{version:02d}.png'
    calfile=review/'calibrations'/f'{tile}_v{version:02d}.json'
    calibration=json.loads(calfile.read_text())
    with Image.open(source) as im:image=im.convert('RGB')
    if image.size!=(1254,1254):raise ValueError('Keep source native; expected1254px')
    output,mask,source_mask,owners,xs,ys=render(image,tile,calibration,seed)
    validation=validate_mask(mask,FAMILIES[tile]);assert validation['valid']
    dest=ROOT/'art/generated/candidates/geometry_wave'/tile/f'{stem}.png'
    paths=[dest,review/'masks'/f'{stem}.png',review/'masks'/f'{stem}_source.png',
           review/'masks'/f'{stem}_provenance.png',review/'debug'/f'{stem}.png',review/f'{stem}_composition.json']
    if any(p.exists() for p in paths):raise FileExistsError('Choose unused candidate version')
    for image_out,path in zip([output,mask,source_mask,owners],paths[:4]):save_new(image_out,path)
    tint=Image.composite(Image.new('RGB',output.size,'#707b51'),Image.new('RGB',output.size,'#dcca97'),mask)
    debug=Image.blend(output,tint,.22)
    outline=mask.filter(ImageFilter.FIND_EDGES)
    debug.paste('#ca288c',mask=outline)
    d=ImageDraw.Draw(debug);d.rectangle((0,0,1253,1253),outline='#cb2580',width=2)
    if tile=='road_junction':
        l,h=socket_bounds(1254,.1)
        for p in [(l,0),(h,0),(l,1253),(h,1253),(1253,l),(1253,h)]:d.ellipse((p[0]-7,p[1]-7,p[0]+7,p[1]+7),fill='#18c6df')
    else:
        for x,y in [(0,0),(1253,0)]+([] if tile=='forest_edge' else [(0,1253),(1253,1253)]):d.ellipse((x-7,y-7,x+7,y+7),fill='#18c6df')
    save_new(debug,paths[4])
    json_new(paths[5],{'status':'CANDIDATE — AWAITING HUMAN REVIEW','tile':tile,'family':FAMILIES[tile],
        'seed':seed,'source':str(source.relative_to(ROOT)),'source_sha256':digest(source),
        'candidate':str(dest.relative_to(ROOT)),'candidate_sha256':digest(dest),
        'calibration':calibration,'calibration_file':str(calfile.relative_to(ROOT)),
        'mask':str(paths[1].relative_to(ROOT)),'source_mask':str(paths[2].relative_to(ROOT)),
        'provenance':str(paths[3].relative_to(ROOT)),
        'coordinates_sha256':hashlib.sha256(xs.tobytes()+ys.tobytes()).hexdigest(),
        'geometry_validation':validation,'size':[1254,1254],
        'mechanical_scope':'Mask and source-provenance proof; human checks source-trace semantics and visible artifacts',
        'method':'smooth socket collars' if tile=='road_junction' else 'source-aware interval transport'})
    print(stem,'PASS')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--tile',choices=FAMILIES,required=True)
    p.add_argument('--version',type=int,required=True);p.add_argument('--seed',type=int,default=41)
    a=p.parse_args();run(a.tile,a.version,a.seed)
