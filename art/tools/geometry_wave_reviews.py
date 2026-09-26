"""Native seam reviews for full-edge families and heterogeneous Road examples."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from build_seam_sheet import preflight, rotated, save_new, sha

TILES = ('forest_edge', 'forest_belt', 'settlement_throughway', 'road_junction')
DECLARED = {
    'forest_edge': ('Forest', 'Field', 'Field', 'Field'),
    'forest_belt': ('Forest', 'Field', 'Forest', 'Field'),
    'settlement_throughway': ('Settlement', 'Field', 'Settlement', 'Field'),
    'road_junction': ('Road', 'Road', 'Road', 'Field'),
    'straight': ('Field', 'Road', 'Field', 'Road'),
    'bend': ('Road', 'Field', 'Field', 'Road'),
    'end': ('Field', 'Field', 'Road', 'Field'),
    'field': ('Field',) * 4,
}
FAMILIES = dict(forest_edge='full_edge_single', forest_belt='full_edge_opposite',
                settlement_throughway='full_edge_opposite', road_junction='road_three_way')


def rotated_edges(edge_types, degrees):
    if degrees not in (0, 90, 180, 270):
        raise ValueError('only exact clockwise quarter turns are supported')
    turns = degrees // 90
    return edge_types[-turns:] + edge_types[:-turns] if turns else edge_types


def check_placements(placements, declared_edges):
    """Check feature kinds, not legacy illustrations' uncertified socket pixels."""
    if not placements or not placements[0] or any(len(row) != len(placements[0]) for row in placements):
        raise ValueError('placements must be a nonempty rectangular grid')
    seams = []
    for row, cells in enumerate(placements):
        for col, cell in enumerate(cells):
            if cell is None:
                continue
            here = rotated_edges(declared_edges[cell[0]], cell[1])
            for dr, dc, side, opposite in ((0, 1, 1, 3), (1, 0, 2, 0)):
                nr, nc = row + dr, col + dc
                if nr >= len(placements) or nc >= len(cells) or placements[nr][nc] is None:
                    continue
                other = placements[nr][nc]
                there = rotated_edges(declared_edges[other[0]], other[1])
                if here[side] != there[opposite]:
                    raise ValueError(f'topology mismatch at {(row, col)} -> {(nr, nc)}')
                seams.append(dict(start=[row, col], end=[nr, nc], feature=here[side]))
    return seams


def compose_tiles(images, placements, declared_edges):
    """Paste exact rotated native pixels; None is transparent outside-board space."""
    check_placements(placements, declared_edges)
    used = [images[cell[0]] for row in placements for cell in row if cell is not None]
    if not used:
        raise ValueError('at least one occupied review cell is required')
    size = used[0].size
    if size[0] != size[1] or any(image.size != size for image in used):
        raise ValueError('all native tile dimensions must be the same square')
    canvas = Image.new('RGBA', (size[0] * len(placements[0]), size[1] * len(placements)))
    for row, cells in enumerate(placements):
        for col, cell in enumerate(cells):
            if cell is not None:
                canvas.paste(rotated(images[cell[0]].convert('RGBA'), cell[1]),
                             (col * size[0], row * size[1]))
    return canvas


def validate_pixels(sheet, images, placements):
    """Verify every occupied and empty cell, including all seam-edge pixels."""
    used = [images[cell[0]] for row in placements for cell in row if cell is not None]
    if not used:
        return False
    size = used[0].width
    if sheet.size != (len(placements[0]) * size, len(placements) * size):
        return False
    for row, cells in enumerate(placements):
        for col, cell in enumerate(cells):
            crop = sheet.crop((col * size, row * size, (col + 1) * size, (row + 1) * size))
            expected = (rotated(images[cell[0]].convert('RGBA'), cell[1]) if cell is not None
                        else Image.new('RGBA', (size, size)))
            if crop.convert('RGBA').tobytes() != expected.tobytes():
                return False
    return True


def layouts(tile):
    c = lambda angle: ('candidate', angle)
    if tile == 'forest_edge':
        return {'feature_pair': [[c(180)], [c(0)]], 'field_pair': [[c(0), c(0)]],
                'mixed_2x2': [[c(180), c(180)], [c(0), c(0)]],
                'rotated_feature_pair': [[c(90), c(270)]]}
    if tile in ('forest_belt', 'settlement_throughway'):
        return {'feature_strip': [[c(0)], [c(0)], [c(0)]],
                'field_pair': [[c(0), c(0)]],
                'mixed_2x2': [[c(0), c(0)], [c(0), c(0)]],
                'rotated_feature_strip': [[c(90), c(90), c(90)]]}
    if tile == 'road_junction':
        return {'straight_pair': [[c(0), ('straight', 0)]],
                'bend_pair': [[c(0), ('bend', 0)]],
                'end_pair': [[c(0), ('end', 90)]],
                'field_pair': [[('field', 0), c(0)]],
                'three_branch_3x3': [[None, ('straight', 90), None],
                                     [('field', 0), c(0), ('bend', 0)],
                                     [None, ('end', 180), None]]}
    raise ValueError(f'unknown tile: {tile}')


def _comparison(items, output):
    """Review thumbnails only; native seam PNGs are never resampled."""
    cell, caption, padding, columns = 420, 52, 18, 3
    rows = (len(items) + columns - 1) // columns
    sheet = Image.new('RGB', (columns * cell, rows * (cell + caption)), '#f4f0e7')
    draw, font = ImageDraw.Draw(sheet), ImageFont.load_default(size=18)
    records = []
    for index, (label, path) in enumerate(items):
        with Image.open(path) as opened:
            source = opened.convert('RGBA')
        preview = source.copy()
        preview.thumbnail((cell - 2 * padding, cell - 2 * padding), Image.Resampling.LANCZOS)
        col, row = index % columns, index // columns
        x = col * cell + (cell - preview.width) // 2
        y = row * (cell + caption) + caption + (cell - preview.height) // 2
        draw.text((col * cell + padding, row * (cell + caption) + 12), label, fill='#392c22', font=font)
        sheet.paste(preview, (x, y), preview)
        records.append(dict(label=label, source=str(path), sha256=sha(path),
                            native_size=list(source.size), review_size=list(preview.size),
                            review_position=[x, y]))
    save_new(sheet, output)
    output.with_suffix('.json').write_text(json.dumps(dict(
        status='CANDIDATE — AWAITING HUMAN REVIEW', labels='outside tile art',
        resampling='LANCZOS thumbnails in this comparison only; native seams are unchanged',
        items=records), indent=2) + '\n')


def build_all(root):
    art = root / 'art'
    destination = art / 'reviews/geometry_wave'
    candidates = {tile: [art / f'generated/candidates/geometry_wave/{tile}/{tile}_geo_v{version:02d}.png'
                         for version in (1, 2)] for tile in TILES}
    legacy = {key: art / 'references/approved_style' / filename for key, filename in {
        'straight': 'ref_05_straight_road.png', 'bend': 'ref_09_bending_road.png',
        'end': 'ref_01_road_end.png', 'field': 'ref_04_open_fields.png'}.items()}
    anchors = {tile: art / 'references/production_anchors' / (
        'settlement_corner_anchor.png' if tile == 'settlement_throughway' else 'forest_bend_anchor.png')
        for tile in TILES}
    anchors['road_junction'] = art / 'references/approved_style/ref_11_road_junction.png'
    masks = {tile: art / f'templates/production_geometry/{FAMILIES[tile]}.png' for tile in TILES}
    inputs = set(legacy.values()) | set(anchors.values()) | set(masks.values())
    inputs.update(path for values in candidates.values() for path in values)
    missing = [str(path) for path in inputs if not path.is_file()]
    if missing:
        raise FileNotFoundError('missing required review inputs: ' + ', '.join(sorted(missing)))
    hashes = {path: sha(path) for path in inputs}
    outputs = []
    for tile, paths in candidates.items():
        for candidate in paths:
            folder = destination / 'seams' / tile
            outputs.extend(folder / f'{candidate.stem}_{name}.png' for name in layouts(tile))
            outputs.append(folder / f'{candidate.stem}_seams.json')
        outputs.extend(destination / f'{tile}_comparison.{suffix}' for suffix in ('png', 'json'))
    preflight(outputs)
    for tile, paths in candidates.items():
        representative = []
        for candidate in paths:
            sources = dict(candidate=candidate)
            if tile == 'road_junction':
                sources.update(legacy)
            images = {}
            for key, path in sources.items():
                with Image.open(path) as opened:
                    images[key] = opened.convert('RGBA')
            declared = dict(DECLARED, candidate=DECLARED[tile])
            folder = destination / 'seams' / tile
            records = []
            for name, layout in layouts(tile).items():
                sheet = compose_tiles(images, layout, declared)
                if not validate_pixels(sheet, images, layout):
                    raise ValueError('native source-pixel preservation failed')
                output = folder / f'{candidate.stem}_{name}.png'
                save_new(sheet, output)
                placements = [dict(row=row, column=col, source=str(sources[value[0]]),
                                   sha256=hashes[sources[value[0]]], rotation_clockwise=value[1])
                              for row, values in enumerate(layout) for col, value in enumerate(values)
                              if value is not None]
                records.append(dict(path=str(output), size=list(sheet.size), sha256=sha(output),
                                    placements=placements, seams=check_placements(layout, declared),
                                    exact_native_pixels=True,
                                    outside_board_cells=[[r, c] for r, row in enumerate(layout)
                                                         for c, value in enumerate(row) if value is None]))
                if not representative or name in ('mixed_2x2', 'three_branch_3x3'):
                    if len(representative) < 2:
                        representative.append(output)
            report = dict(status='CANDIDATE — AWAITING HUMAN REVIEW', resampling='none',
                          topology='declared feature kinds only; inspect actual artwork',
                          legacy_socket_note='Legacy Road references are unchanged and NOT certified to the 126px socket.',
                          empty_cells='transparent outside-board space, not Field tiles', sheets=records)
            (folder / f'{candidate.stem}_seams.json').write_text(json.dumps(report, indent=2) + '\n')
        items = [('Production anchor / Road reference', anchors[tile]), ('Canonical family template', masks[tile]),
                 ('v01 actual ownership mask', destination / 'masks' / f'{tile}_geo_v01.png'),
                 ('v02 actual ownership mask', destination / 'masks' / f'{tile}_geo_v02.png'),
                 ('Candidate v01 — awaiting review', paths[0]), ('Candidate v02 — awaiting review', paths[1])]
        items.extend((f'Native seam preview {index + 1}', path) for index, path in enumerate(representative[:2]))
        _comparison(items, destination / f'{tile}_comparison.png')
    if any(sha(path) != digest for path, digest in hashes.items()):
        raise AssertionError('source changed during review generation')
    print(f'PASS: {len(outputs)} review files; all seam tiles preserve exact native pixels')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    build_all(args.root)


if __name__ == '__main__':
    main()
