#!/usr/bin/env python3
"""Create geometry-control diagrams only; never edit tile artwork."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SIZE = 1254

def build() -> None:
    guides = ROOT / 'art/templates/geometry_guides'
    masks = ROOT / 'art/templates/control_masks'
    guides.mkdir(parents=True, exist_ok=True)
    masks.mkdir(parents=True, exist_ok=True)
    names = ('settlement_corner', 'forest_bend')
    outputs = [guides / f'{n}_{suffix}.png' for n in names for suffix in ('guide', 'underlay')]
    outputs += [masks / f'{n}_ne_mask.png' for n in names]
    outputs += [guides / 'wave2_geometry.json']
    if any(p.exists() for p in outputs):
        raise FileExistsError('Wave-2 guides already exist; preserve them.')
    mask = Image.new('L', (SIZE, SIZE))
    mask.putdata([255 if x >= y else 0 for y in range(SIZE) for x in range(SIZE)])
    font = ImageFont.truetype('DejaVuSans.ttf', 26)
    title = ImageFont.truetype('DejaVuSans.ttf', 32)
    for name, area, color in [('settlement_corner', 'SETTLEMENT', '#c29a82'),
                              ('forest_bend', 'FOREST', '#7f9770')]:
        mask.save(masks / f'{name}_ne_mask.png')
        field = Image.new('RGB', mask.size, '#f1ecd8')
        underlay = Image.composite(Image.new('RGB', mask.size, color), field, mask)
        underlay.save(guides / f'{name}_underlay.png')
        guide = underlay.copy()
        d = ImageDraw.Draw(guide)
        d.rectangle((0, 0, SIZE - 1, SIZE - 1), outline='#262626', width=3)
        d.line((0, 0, SIZE - 1, SIZE - 1), fill='#b50051', width=3)
        def label(x: int, y: int, text: str, anchor: str = 'la') -> None:
            box = d.textbbox((x, y), text, font=font, anchor=anchor)
            d.rectangle((box[0]-4, box[1]-3, box[2]+4, box[3]+3), fill='white')
            d.text((x, y), text, font=font, fill='#202020', anchor=anchor)
        label(12, 12, 'NW (0,0): fixed transition')
        label(SIZE-12, 12, 'NE: all '+area, 'ra')
        label(12, SIZE-50, 'SW: all FIELD')
        label(SIZE-12, SIZE-50, 'SE (1254,1254): fixed transition', 'ra')
        label(SIZE//2, 80, 'NORTH: full '+area, 'ma')
        label(SIZE-18, SIZE//2, 'EAST: full '+area, 'ra')
        label(SIZE//2, SIZE-95, 'SOUTH: FIELD', 'ma')
        label(18, SIZE//2, 'WEST: FIELD')
        d.text((780, 300), area+' REGION', font=title, fill='#202020', anchor='ma')
        d.text((370, 890), 'FIELD REGION', font=title, fill='#202020', anchor='ma')
        label(SIZE//2, 620, 'Fixed NW-to-SE endpoints', 'ma')
        guide.save(guides / f'{name}_guide.png')
    metadata = {
        'purpose': 'Geometry control assets, not final art or style references',
        'size_px': [SIZE, SIZE], 'continuous_canvas': [0, 0, SIZE, SIZE],
        'raster_indices': [0, SIZE-1], 'mask_rule': 'white iff x >= y; black otherwise',
        'edges': {'North': 'feature', 'East': 'feature', 'South': 'Field', 'West': 'Field'},
        'transition_corners': {'NW': [0, 0], 'SE': [SIZE, SIZE]},
        'shared_feature_corner': 'NE', 'shared_field_corner': 'SW',
        'corner_convention': 'NW/SE are divider points, not extra Field-edge exits. Raster diagonal assigned to feature; no finite edge-length tolerance.',
        'interior': 'Organic wall/treeline allowed; exact outer endpoints and ownership mandatory.',
        'generation': 'Attach labeled guide plus clean underlay; do not reproduce labels, border, flat palette or magenta line in art.'
    }
    (guides / 'wave2_geometry.json').write_text(json.dumps(metadata, indent=2)+'\n')
    for name in names:
        m = Image.open(masks / f'{name}_ne_mask.png')
        assert all(m.getpixel((x, 0)) == 255 for x in range(SIZE))
        assert all(m.getpixel((SIZE-1, y)) == 255 for y in range(SIZE))
        assert all(m.getpixel((0, y)) == 0 for y in range(1, SIZE))
        assert all(m.getpixel((x, SIZE-1)) == 0 for x in range(SIZE-1))
    print('PASS: 2 labeled guides, 2 clean underlays, 2 binary masks and coordinate JSON; exact N/E and S/W ownership verified.')

if __name__ == '__main__':
    build()
