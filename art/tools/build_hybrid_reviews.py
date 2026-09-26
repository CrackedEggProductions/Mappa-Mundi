#!/usr/bin/env python3
"""Build native seam sheets and explicitly downsampled review-only comparisons."""
from pathlib import Path
import argparse
from PIL import Image, ImageDraw, ImageFont
from build_seam_sheet import seams, save_new
from hybrid_compositor import ROOT, SOURCES, json_new


def build():
    review=ROOT/'art/reviews/trial_03'
    for tile in SOURCES:
        items=[('Preferred wave-2 source',ROOT/'art/generated/candidates'/tile/SOURCES[tile])]
        for version in (1,2):
            stem=f'{tile}_hybrid_v{version:02d}'
            candidate=ROOT/'art/generated/candidates/hybrid_corrected'/tile/f'{stem}.png'
            seams(argparse.Namespace(candidate=candidate,output_dir=review/'seams'/tile,prefix=None))
            items.extend([(f'v{version:02d} hard feature mask',ROOT/'art/templates/hybrid_masks'/f'{stem}_feature.png'),
                          (f'v{version:02d} organic boundary',ROOT/'art/templates/hybrid_boundaries'/f'{stem}.png'),
                          (f'v{version:02d} hybrid CANDIDATE',candidate),
                          (f'v{version:02d} feature seams',review/'seams'/tile/f'{stem}_central_area_2x2.png'),
                          (f'v{version:02d} field seams',review/'seams'/tile/f'{stem}_central_field_2x2.png')])
        cell,caption,pad=420,45,12
        sheet=Image.new('RGB',(3*(cell+pad),4*(cell+caption+pad)),'#eee5d4')
        draw=ImageDraw.Draw(sheet); font=ImageFont.load_default(size=19)
        for i,(label,path) in enumerate(items):
            with Image.open(path) as opened: preview=opened.convert('RGB').resize((cell,cell),Image.Resampling.LANCZOS)
            x=(i%3)*(cell+pad);y=(i//3)*(cell+caption+pad)
            sheet.paste(preview,(x,y+caption));draw.text((x+4,y+8),label,fill='#412c21',font=font)
        save_new(sheet,review/f'{tile}_hybrid_comparison.png')
        json_new(review/f'{tile}_hybrid_comparison.json',{
            'status':'CANDIDATE — AWAITING HUMAN REVIEW',
            'review_only':'420px previews; native candidates and seams are unchanged',
            'items':[{'label':label,'source':str(path.relative_to(ROOT))} for label,path in items]})


if __name__=='__main__': build()
