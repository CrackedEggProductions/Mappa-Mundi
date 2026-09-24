#!/usr/bin/env python3
"""Native-pixel art review: quarter-turn seam grids and labeled comparisons."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

LAYOUTS = {
    "central_area_2x2": [[90, 180], [0, 270]],
    "central_field_2x2": [[270, 0], [180, 90]],
    "alternating_3x3": [[90, 180, 90], [0, 270, 0], [90, 180, 90]],
}
EDGES = ("Area", "Area", "Field", "Field")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rotated(image, degrees):
    operations = {90: Image.Transpose.ROTATE_270, 180: Image.Transpose.ROTATE_180,
                  270: Image.Transpose.ROTATE_90}
    return image.copy() if degrees == 0 else image.transpose(operations[degrees])


def edges(degrees):
    turns = degrees // 90
    return EDGES[-turns:] + EDGES[:-turns] if turns else EDGES


def check_layout(layout):
    seams = []
    for row, values in enumerate(layout):
        for col, turn in enumerate(values):
            here = edges(turn)
            if col + 1 < len(values):
                neighbor = edges(values[col + 1])
                if here[1] != neighbor[3]:
                    raise ValueError("Horizontal topology mismatch")
                seams.append({"from": [row, col], "to": [row, col + 1], "edge": here[1]})
            if row + 1 < len(layout):
                neighbor = edges(layout[row + 1][col])
                if here[2] != neighbor[0]:
                    raise ValueError("Vertical topology mismatch")
                seams.append({"from": [row, col], "to": [row + 1, col], "edge": here[2]})
    return seams


def composite(image, layout):
    check_layout(layout)
    if image.width != image.height:
        raise ValueError("Seam candidates must be square; source will not be resized")
    canvas = Image.new("RGBA", (image.width * len(layout[0]), image.height * len(layout)))
    for row, values in enumerate(layout):
        for col, turn in enumerate(values):
            canvas.paste(rotated(image.convert("RGBA"), turn), (col * image.width, row * image.height))
    return canvas


def preflight(paths):
    if len(set(paths)) != len(paths) or any(path.exists() for path in paths):
        raise FileExistsError("Output exists or repeats; choose new names instead of overwriting")


def save_new(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as handle:
        image.save(handle, format="PNG")


def seams(args):
    source = args.candidate.resolve()
    original_hash = sha(source)
    with Image.open(source) as opened:
        image = opened.convert("RGBA")
    prefix = args.prefix or source.stem
    paths = {name: args.output_dir / f"{prefix}_{name}.png" for name in LAYOUTS}
    manifest = args.output_dir / f"{prefix}_seams.json"
    preflight(list(paths.values()) + [manifest])
    records = []
    for name, layout in LAYOUTS.items():
        sheet = composite(image, layout)
        save_new(sheet, paths[name])
        records.append({"file": paths[name].name, "size_px": list(sheet.size),
                        "rotations_clockwise": layout, "matching_seams": check_layout(layout)})
    assert sha(source) == original_hash, "Source changed during review generation"
    with manifest.open("x") as handle:
        json.dump({"source": str(source), "source_sha256": original_hash,
                   "source_size_px": list(image.size), "resampling": "none",
                   "edge_order": "North East South West", "unrotated_edges": EDGES,
                   "validation": "Layout topology only; actual artwork requires visual review",
                   "sheets": records}, handle, indent=2)
        handle.write("\n")
    print(f"Created {len(paths)} native-pixel seam sheets and {manifest}")


def comparison(args):
    sources = []
    for item in args.item:
        label, filename = item.split("=", 1)
        path = Path(filename).resolve()
        with Image.open(path) as opened:
            image = opened.convert("RGBA")
        sources.append((label, path, sha(path), image))
    manifest = args.output.with_suffix(".json")
    preflight([args.output, manifest])
    padding, caption = 24, 64
    cell_w = max(entry[3].width for entry in sources) + 2 * padding
    cell_h = max(entry[3].height for entry in sources) + 2 * padding + caption
    columns = min(args.columns, len(sources))
    if columns < 1:
        raise ValueError("Columns must be positive")
    rows = (len(sources) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * cell_w, rows * cell_h), "#f4f0e7")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=24)
    records = []
    for index, (label, path, digest, image) in enumerate(sources):
        col, row = index % columns, index // columns
        x, y = col * cell_w + (cell_w - image.width) // 2, row * cell_h + padding + caption
        draw.text((col * cell_w + padding, row * cell_h + padding), label, fill="#392c22", font=font)
        sheet.paste(image, (x, y))
        records.append({"label": label, "source": str(path), "sha256": digest,
                        "native_size_px": list(image.size), "image_top_left": [x, y]})
    save_new(sheet, args.output)
    assert all(sha(path) == digest for _, path, digest, _ in sources)
    with manifest.open("x") as handle:
        json.dump({"resampling": "none", "labels": "Outside asset pixels", "items": records}, handle, indent=2)
        handle.write("\n")
    print(f"Created comparison {args.output} and {manifest}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    seam = commands.add_parser("seams")
    seam.add_argument("--candidate", type=Path, required=True)
    seam.add_argument("--output-dir", type=Path, required=True)
    seam.add_argument("--prefix")
    seam.set_defaults(run=seams)
    compare = commands.add_parser("comparison")
    compare.add_argument("--item", action="append", required=True, help="Label=path (repeat)")
    compare.add_argument("--output", type=Path, required=True)
    compare.add_argument("--columns", type=int, default=3)
    compare.set_defaults(run=comparison)
    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
