"""Native hybrid-tile seam sheets, mask debug overlays and review comparisons."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

from build_seam_sheet import preflight, save_new, sha
from geometry_wave_reviews import (check_placements, compose_tiles, rotated_edges,
                                   validate_pixels)

STATUS = 'CANDIDATE — AWAITING HUMAN REVIEW'
EDGES = {
    'settlement_throughway': ('Settlement', 'Field', 'Settlement', 'Field'),
    'settlement_gate': ('Settlement', 'Road', 'Field', 'Field'),
    'riverside_hamlet': ('Settlement', 'River', 'Field', 'River'),
    'woodland_road': ('Forest', 'Forest', 'Road', 'Road'),
    'woodland_river': ('Forest', 'Forest', 'River', 'River'),
    'settlement_corner_gate': ('Settlement', 'Settlement', 'Road', 'Field'),
    'settlement_road_bend': ('Settlement', 'Settlement', 'Road', 'Road'),
    'settlement_road_throughway': ('Settlement', 'Road', 'Settlement', 'Road'),
}
REFERENCE_EDGES = {
    'forest': ('Forest', 'Forest', 'Field', 'Field'),
    'settlement': ('Settlement', 'Settlement', 'Field', 'Field'),
    'road': ('Field', 'Road', 'Field', 'Road'),
    'river': ('River', 'Field', 'River', 'Field'),
    'field': ('Field',) * 4,
    'road_bend': ('Road', 'Field', 'Field', 'Road'),
    'river_bend': ('River', 'River', 'Field', 'Field'),
}
REFERENCE_PATHS = {
    'forest': 'references/production_anchors/forest_bend_anchor.png',
    'settlement': 'references/production_anchors/settlement_corner_anchor.png',
    'road': 'references/approved_mechanical/ref_05_straight_road.png',
    'river': 'references/approved_style/ref_10_river_run.png',
    'field': 'references/approved_mechanical/ref_04_open_fields.png',
    'road_bend': 'references/approved_mechanical/ref_09_bending_road.png',
    'river_bend': 'references/approved_mechanical/ref_13_river_bend.png',
}
COLORS = dict(Forest='#28723e', Settlement='#c16435', Road='#bf9728',
              River='#337ecc', Field='#d6d58a')
SIDE_NAMES = ('north', 'east', 'south', 'west')


def matching_reference(feature, facing_side, *, bend=False):
    key = feature.lower() + ('_bend' if bend else '')
    for angle in (0, 90, 180, 270):
        if rotated_edges(REFERENCE_EDGES[key], angle)[facing_side] == feature:
            return key, angle
    raise ValueError(f'no matching {feature} reference side')


def pair_layout(side, neighbor):
    candidate = ('candidate', 0)
    return ([[neighbor], [candidate]], [[candidate, neighbor]],
            [[candidate], [neighbor]], [[neighbor, candidate]])[side]


def layouts(tile):
    """Four canonical side pairs, an orthogonal cross, and linear bend checks."""
    edges = EDGES[tile]
    neighbors = [matching_reference(feature, (side + 2) % 4)
                 for side, feature in enumerate(edges)]
    result = {f'{SIDE_NAMES[side]}_{feature.lower()}_pair': pair_layout(side, neighbors[side])
              for side, feature in enumerate(edges)}
    result['combined_3x3'] = [[None, neighbors[0], None],
                              [neighbors[3], ('candidate', 0), neighbors[1]],
                              [None, neighbors[2], None]]
    for feature in ('Road', 'River'):
        if feature in edges:
            side = edges.index(feature)
            result[f'{feature.lower()}_bend_pair'] = pair_layout(
                side, matching_reference(feature, (side + 2) % 4, bend=True))
    return result


def write_seam(output, sources, layout, declarations, root):
    """Save a lossless seam and return source/pixel provenance for every cell."""
    images, hashes = {}, {}
    for key in {cell[0] for row in layout for cell in row if cell is not None}:
        path = sources[key]
        hashes[key] = sha(path)
        with Image.open(path) as opened:
            images[key] = opened.convert('RGBA')
    sheet = compose_tiles(images, layout, declarations)
    if not validate_pixels(sheet, images, layout):
        raise AssertionError('native review pixels changed')
    save_new(sheet, output)
    with Image.open(output) as saved:
        if not validate_pixels(saved, images, layout):
            raise AssertionError('saved native review pixels changed')
    if any(sha(sources[key]) != digest for key, digest in hashes.items()):
        raise AssertionError('review input changed')
    return dict(path=str(output.relative_to(root)), sha256=sha(output), size=list(sheet.size),
                exact_native_pixels=True, rotation='clockwise exact PIL transpose',
                placements=[dict(row=r, column=c, source=str(sources[cell[0]].relative_to(root)),
                                 sha256=hashes[cell[0]], rotation_clockwise=cell[1])
                            for r, row in enumerate(layout) for c, cell in enumerate(row)
                            if cell is not None],
                outside_board_cells=[[r, c] for r, row in enumerate(layout)
                                     for c, cell in enumerate(row) if cell is None],
                seams=check_placements(layout, declarations))


def _write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x') as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write('\n')


def debug_overlay(candidate, masks, edges):
    """Separate diagnostic: ownership tint, boundary lines and edge-run endpoints."""
    if candidate.width != candidate.height or any(mask.size != candidate.size for mask in masks.values()):
        raise ValueError('candidate and masks must share native square dimensions')
    result = candidate.convert('RGBA')
    for feature, mask in masks.items():
        binary = mask.convert('L')
        tint = Image.new('RGBA', result.size, COLORS[feature])
        tint.putalpha(binary.point(lambda value: 42 if value else 0))
        result = Image.alpha_composite(result, tint)
        if feature != 'Field':
            outline = ImageChops.difference(binary.filter(ImageFilter.MaxFilter(3)),
                                           binary.filter(ImageFilter.MinFilter(3)))
            line = Image.new('RGBA', result.size, COLORS[feature])
            line.putalpha(outline)
            result = Image.alpha_composite(result, line)
    draw = ImageDraw.Draw(result)
    last = result.width - 1
    draw.rectangle((0, 0, last, last), outline='#673d25', width=2)
    for side, feature in enumerate(edges):
        pixels = masks[feature].convert('L')
        coords = [[(x, 0) for x in range(last + 1)], [(last, y) for y in range(last + 1)],
                  [(x, last) for x in range(last + 1)], [(0, y) for y in range(last + 1)]][side]
        occupied = [index for index, point in enumerate(coords) if pixels.getpixel(point)]
        if occupied:
            for index in (occupied[0], occupied[-1]):
                x, y = coords[index]
                draw.ellipse((x - 8, y - 8, x + 8, y + 8), fill=COLORS[feature], outline='white', width=2)
    return result


def comparison(items, output, root):
    """Scaled previews are confined to this sheet; labels remain outside tile art."""
    cell, caption, pad, columns = 420, 54, 18, 3
    rows = (len(items) + columns - 1) // columns
    result = Image.new('RGB', (columns * cell, rows * (cell + caption)), '#f4f0e7')
    draw, font = ImageDraw.Draw(result), ImageFont.load_default(size=17)
    records = []
    for index, (label, path) in enumerate(items):
        with Image.open(path) as image:
            preview, native_size = image.convert('RGBA'), image.size
        preview.thumbnail((cell - 2 * pad, cell - 2 * pad), Image.Resampling.LANCZOS)
        col, row = index % columns, index // columns
        origin = (col * cell + (cell - preview.width) // 2,
                  row * (cell + caption) + caption + (cell - preview.height) // 2)
        draw.text((col * cell + pad, row * (cell + caption) + 12), label, font=font, fill='#392c22')
        result.paste(preview, origin, preview)
        records.append(dict(label=label, source=str(path.relative_to(root)), sha256=sha(path),
                            native_size=list(native_size), review_size=list(preview.size)))
    save_new(result, output)
    _write_json(output.with_suffix('.json'), dict(status=STATUS, labels='outside artwork',
                resampling='LANCZOS thumbnails only; all separate seam PNGs remain native', items=records))


def validate_template(tile, record):
    actual = tuple(record['edges'][side] for side in ('N', 'E', 'S', 'W'))
    if actual != EDGES[tile]:
        raise ValueError(f'template disagrees with canonical brief: {tile}')


def mask_paths(art, tile, candidate):
    """Use an entire recorded candidate mask set, never mix partial overrides."""
    override = art / 'reviews/production_wave_01/masks' / candidate.stem
    folder = override if override.exists() else art / 'templates/production_wave_01' / tile
    paths = {feature: folder / f'{feature}.png' for feature in set(EDGES[tile]) | {'Field'}}
    missing = [str(path) for path in paths.values() if not path.is_file()]
    if missing:
        raise FileNotFoundError('incomplete authoritative mask set: ' + ', '.join(sorted(missing)))
    return paths


def build_all(root):
    root = root.resolve()
    art = root / 'art'
    destination = art / 'reviews/production_wave_01'
    references = {key: art / path for key, path in REFERENCE_PATHS.items()}
    candidates = {tile: [art / f'generated/candidates/production_wave_01/{tile}/{tile}_v{v:02d}.png'
                         for v in (1, 2)] for tile in EDGES}
    templates, masks_by_candidate, inputs, outputs = {}, {}, set(references.values()), []
    for tile, paths in candidates.items():
        folder = art / 'templates/production_wave_01' / tile
        record = json.loads((folder / 'topology.json').read_text())
        validate_template(tile, record)
        templates[tile] = record
        inputs.update(paths + [folder / 'topology.json', folder / 'guide.png'])
        for candidate in paths:
            masks_by_candidate[candidate] = mask_paths(art, tile, candidate)
            inputs.update(masks_by_candidate[candidate].values())
            outputs += [destination / 'seams' / tile / f'{candidate.stem}_{name}.png'
                        for name in layouts(tile)]
            outputs += [destination / 'seams' / tile / f'{candidate.stem}_seams.json',
                        destination / 'debug' / f'{candidate.stem}.png']
        outputs += [destination / f'{tile}_comparison.{extension}' for extension in ('png', 'json')]
    missing = [str(path) for path in inputs if not path.is_file()]
    if missing:
        raise FileNotFoundError('missing review inputs: ' + ', '.join(sorted(missing)))
    preflight(outputs)
    hashes = {path: sha(path) for path in inputs}
    for path in inputs:
        if path.suffix == '.png':
            with Image.open(path) as opened:
                if opened.size != (1254, 1254):
                    raise ValueError(f'expected native 1254 square: {path}')
    for tile, paths in candidates.items():
        representative = []
        folder = art / 'templates/production_wave_01' / tile
        for candidate in paths:
            masks = {}
            for feature, path in masks_by_candidate[candidate].items():
                with Image.open(path) as opened:
                    masks[feature] = opened.convert('L')
            with Image.open(candidate) as opened:
                debug = debug_overlay(opened, masks, EDGES[tile])
            save_new(debug, destination / 'debug' / f'{candidate.stem}.png')
            sources = dict(references, candidate=candidate)
            declarations = dict(REFERENCE_EDGES, candidate=EDGES[tile])
            records = []
            for name, layout in layouts(tile).items():
                output = destination / 'seams' / tile / f'{candidate.stem}_{name}.png'
                records.append(write_seam(output, sources, layout, declarations, root))
                if name == 'combined_3x3':
                    representative.append(output)
            _write_json(destination / 'seams' / tile / f'{candidate.stem}_seams.json', dict(
                status=STATUS, resampling='none', template_topology=templates[tile],
                template_sha256=hashes[folder / 'topology.json'],
                actual_masks={feature: dict(path=str(path.relative_to(root)), sha256=hashes[path])
                              for feature, path in masks_by_candidate[candidate].items()},
                note='Declared feature matching and exact pixel preservation; legacy Road/River '
                     'references are not certified to current sockets. Inspect visual seams.', sheets=records))
        primary = references['forest' if 'Forest' in EDGES[tile] else 'settlement']
        mechanical = references['river' if 'River' in EDGES[tile] else 'road'
                                if 'Road' in EDGES[tile] else 'field']
        items = [('Production anchor', primary), ('Mechanical / socket reference', mechanical),
                 ('Canonical layered topology', folder / 'guide.png'),
                 ('Candidate v01 - awaiting review', paths[0]), ('Candidate v02 - awaiting review', paths[1])]
        major_feature = 'Forest' if 'Forest' in EDGES[tile] else 'Settlement'
        items += [(f'v{index + 1:02d} actual {major_feature} mask',
                   masks_by_candidate[path][major_feature]) for index, path in enumerate(paths)]
        items += [(f'v{index + 1:02d} native seam preview', path)
                  for index, path in enumerate(representative)]
        comparison(items, destination / f'{tile}_comparison.png', root)
    if any(sha(path) != digest for path, digest in hashes.items()):
        raise AssertionError('source changed during reviews')
    print(f'PASS: {len(outputs)} review files; all native seam pixels preserved; inputs unchanged')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    build_all(parser.parse_args().root)
