#!/usr/bin/env python3
"""Build art-review geometry, never tile artwork; refuses existing outputs."""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "templates"
SIZE = 1254


def save_new(image, path):
    with path.open("xb") as handle:
        image.save(handle, format="PNG")


def main():
    outputs = [ROOT / "edge_grammar.json"]
    names = ["ne_full_area", "ne_ownership_guide"]
    names += [f"{feature}_{side}" for feature in ("road", "river")
              for side in ("north", "east", "south", "west")]
    outputs += [ROOT / "edge_masks" / f"{name}.{ext}"
                for name in names for ext in ("svg", "png")]
    if any(path.exists() for path in outputs):
        raise SystemExit("Refusing to overwrite existing templates.")
    (ROOT / "edge_masks").mkdir(parents=True, exist_ok=True)
    spec = {
        "purpose": "Art geometry diagrams, not generated tile assets",
        "master_size_px": [SIZE, SIZE], "design_units": [1000, 1000],
        "reference_sources": "Preserve 1254px reference images at original resolution",
        "axes": "x right, y down; North top; rotations clockwise",
        "road": {"width_fraction": 0.1, "width_px": 125.4,
                 "socket_limits_px": [564.3, 689.7]},
        "river": {"width_fraction": 0.2, "width_px": 250.8,
                  "socket_limits_px": [501.6, 752.4]},
        "socket_application": "Limits are x on N/S and y on E/W; center627px",
        "raster_convention": "Fractional pixel area coverage; exact continuous coordinates in SVG",
        "full_area_ne": {"edges": ["Area", "Area", "Field", "Field"],
                         "polygon": [[0, 0], [SIZE, 0], [SIZE, SIZE]],
                         "inside": "x >= y", "shared_corner": "NW/SE divider points, not extra exits"},
        "interior": "Diagonal is a topology guide; organic interior boundary permitted",
        "edge_requirement": "Full N/E side coverage, no area spill onto S/W beyond transition point",
        "approval": "Templates cannot certify the generated image; inspect actual pixels and seams"
    }
    with outputs[0].open("x") as handle:
        json.dump(spec, handle, indent=2)
        handle.write("\n")
    for name in names:
        svg_start = f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">'
        if name.startswith("ne_"):
            mask = Image.new("L", (SIZE, SIZE))
            pixels = mask.load()
            for y in range(SIZE):
                for x in range(y, SIZE):
                    pixels[x, y] = 128 if x == y else 255
            if name == "ne_ownership_guide":
                image = Image.composite(Image.new("RGB", mask.size, "#728565"),
                                        Image.new("RGB", mask.size, "#ede2be"), mask)
                shape = f'<rect width="{SIZE}" height="{SIZE}" fill="#ede2be"/><path d="M0 0H{SIZE}V{SIZE}Z" fill="#728565"/>'
            else:
                image = mask
                shape = f'<rect width="{SIZE}" height="{SIZE}" fill="black"/><path d="M0 0H{SIZE}V{SIZE}Z" fill="white"/>'
        else:
            feature, side = name.split("_")
            low, high = spec[feature]["socket_limits_px"]
            center = SIZE / 2
            # Diagram strip ends at center; this does not prescribe internal topology.
            rect = {"north": (low, 0, high, center), "east": (center, low, SIZE, high),
                    "south": (low, center, high, SIZE), "west": (0, low, center, high)}[side]
            left, top, right, bottom = rect
            image = Image.new("L", (SIZE, SIZE))
            pixels = image.load()
            for y in range(int(top), min(SIZE, int(bottom) + 1)):
                for x in range(int(left), min(SIZE, int(right) + 1)):
                    coverage = max(0, min(x + 1, right) - max(x, left)) * max(0, min(y + 1, bottom) - max(y, top))
                    pixels[x, y] = round(coverage * 255)
            shape = f'<rect width="{SIZE}" height="{SIZE}" fill="black"/><rect x="{left}" y="{top}" width="{right-left}" height="{bottom-top}" fill="white"/>'
        path = ROOT / "edge_masks" / name
        save_new(image, path.with_suffix(".png"))
        with path.with_suffix(".svg").open("x") as handle:
            handle.write(svg_start + shape + "</svg>\n")
    print(f"Created {len(outputs)} new template files at {ROOT}")


if __name__ == "__main__":
    main()
