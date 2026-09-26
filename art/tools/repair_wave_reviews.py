"""Build native review sheets for the six source-first repair-wave candidates."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

from build_seam_sheet import preflight, save_new, sha
from production_wave_reviews import (
    EDGES, REFERENCE_EDGES, REFERENCE_PATHS, STATUS, _write_json, comparison,
    debug_overlay, layouts as previous_layouts, pair_layout, validate_template,
    write_seam,
)
from geometry_wave_reviews import rotated_edges

TILES = ('settlement_gate', 'riverside_hamlet', 'settlement_road_throughway')
VERSIONS = (3, 4)
ANCHORS = {
    'settlement_gate': ('settlement_corner', 'settlement_throughway', 'settlement_corner_gate'),
    'riverside_hamlet': ('settlement_corner', 'settlement_throughway'),
    'settlement_road_throughway': ('settlement_throughway', 'settlement_road_bend', 'road_junction'),
}
THROUGHWAY_EDGES = ('Settlement', 'Field', 'Settlement', 'Field')


def layouts(tile):
    """Retain all prior side checks and add the newly approved urban throughway."""
    if tile not in TILES:
        raise ValueError(f'outside repair wave: {tile}')
    result = previous_layouts(tile)
    side = EDGES[tile].index('Settlement')
    angle = next(angle for angle in (0, 90, 180, 270)
                 if rotated_edges(THROUGHWAY_EDGES, angle)[(side + 2) % 4] == 'Settlement')
    result['settlement_throughway_pair'] = pair_layout(side, ('throughway', angle))
    if tile == 'settlement_road_throughway':
        result['simultaneous_continuity_3x3'] = [[('candidate', 0)] * 3 for _ in range(3)]
    return result


def mask_paths(art, tile, candidate):
    """Require actual output masks; canonical templates are never a fallback."""
    folder = art / 'reviews/production_wave_02/masks' / candidate.stem
    paths = {feature: folder / f'{feature}.png' for feature in sorted(set(EDGES[tile]) | {'Field'})}
    missing = [str(path) for path in paths.values() if not path.is_file()]
    if missing:
        raise FileNotFoundError('missing actual repair candidate masks: ' + ', '.join(missing))
    return paths


def repair_overlay(candidate, masks, edges, repair, relationships):
    """Tint ownership, show exact boundaries, yellow contacts and magenta repairs."""
    if repair.size != candidate.size:
        raise ValueError('repair zone must match native candidate dimensions')
    repair = repair.convert('L')
    if any(count for value, count in enumerate(repair.histogram()) if value not in (0, 255)):
        raise ValueError('repair zone must be binary')
    result = debug_overlay(candidate, masks, edges)
    tint = Image.new('RGBA', result.size, '#ff00bf')
    tint.putalpha(repair.point(lambda value: 150 if value else 0))
    result = Image.alpha_composite(result, tint)
    for relationship in relationships:
        first, second = (masks[relationship[key]].convert('L') for key in ('first', 'second'))
        contact = ImageChops.multiply(first.filter(ImageFilter.MaxFilter(3)), second)
        contact = ImageChops.difference(contact.filter(ImageFilter.MaxFilter(3)),
                                       contact.filter(ImageFilter.MinFilter(3)))
        tint = Image.new('RGBA', result.size, '#ffea00')
        tint.putalpha(contact)
        result = Image.alpha_composite(result, tint)
    return result


def comparison_items(art, tile, paths, representative):
    items = [(name.replace('_', ' ').title() + ' anchor',
              art / f'references/production_anchors/{name}_anchor.png') for name in ANCHORS[tile]]
    items += [('Wave 01 v02 - visually rejected',
               art / f'generated/candidates/production_wave_01/{tile}/{tile}_v02.png'),
              ('Canonical layered topology', art / 'templates/production_wave_01' / tile / 'guide.png')]
    items += [(f'Candidate v{version:02d} - awaiting review', path)
              for version, path in zip(VERSIONS, paths)]
    items += [(f'v{version:02d} native seam preview', path)
              for version, path in zip(VERSIONS, representative)]
    return items


def build_all(root):
    root = root.resolve()
    art = root / 'art'
    destination = art / 'reviews/production_wave_02'
    references = {key: art / path for key, path in REFERENCE_PATHS.items()
                  if key != 'forest'}
    references['throughway'] = art / 'references/production_anchors/settlement_throughway_anchor.png'
    candidates = {tile: [art / f'generated/candidates/production_wave_02/{tile}/{tile}_v{v:02d}.png'
                         for v in VERSIONS] for tile in TILES}
    templates, masks_by_candidate, inputs, outputs = {}, {}, set(references.values()), []
    for tile, paths in candidates.items():
        folder = art / 'templates/production_wave_01' / tile
        record = json.loads((folder / 'topology.json').read_text())
        validate_template(tile, record)
        templates[tile] = record
        inputs.update(paths + [folder / 'topology.json'])
        inputs.update(path for _, path in comparison_items(art, tile, paths, []))
        for candidate in paths:
            masks_by_candidate[candidate] = mask_paths(art, tile, candidate)
            inputs.update(masks_by_candidate[candidate].values())
            inputs.add(destination / 'repair_zones' / f'{candidate.stem}.png')
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
            repair_path = destination / 'repair_zones' / f'{candidate.stem}.png'
            with Image.open(repair_path) as opened:
                repair = opened.convert('L')
            with Image.open(candidate) as opened:
                debug = repair_overlay(opened, masks, EDGES[tile], repair, templates[tile]['relationships'])
            save_new(debug, destination / 'debug' / f'{candidate.stem}.png')
            sources = dict(references, candidate=candidate)
            declarations = dict(REFERENCE_EDGES, throughway=THROUGHWAY_EDGES, candidate=EDGES[tile])
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
                repair_zone=dict(path=str(repair_path.relative_to(root)), sha256=hashes[repair_path],
                                 percent=100 * repair.histogram()[255] / (repair.width * repair.height)),
                debug_legend=dict(magenta='replaced/transported pixels', yellow='declared feature contacts'),
                note='Declared feature matching and exact pixel preservation; legacy Road/River '
                     'references retain their existing sockets and require visual seam review.', sheets=records))
        comparison(comparison_items(art, tile, paths, representative),
                   destination / f'{tile}_comparison.png', root)
    if any(sha(path) != digest for path, digest in hashes.items()):
        raise AssertionError('source changed during reviews')
    print(f'PASS: {len(outputs)} review files; native seam pixels preserved; inputs unchanged')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    build_all(parser.parse_args().root)
