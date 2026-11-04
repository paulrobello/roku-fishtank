# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0"]
# ///
"""Contact sheet of rigged species at display size, composed from the shipped layers.

``uv run tools/art/species_sheet.py <out.png> <species> [<species> ...]``

Each fish is the body, tail and fin PNGs from images/fish placed at rest with the
offsets in config/species/<species>.rig.json, so the sheet shows what ships, at
1:1 display pixels on the rig-check blue, bottoms aligned for size comparison.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
CHECK_BG = (12, 32, 72, 255)
PAD = 24
LABEL_H = 22


def compose(name: str) -> Image.Image:
    rig = json.loads((ROOT / "config" / "species" / f"{name}.rig.json").read_text(encoding="utf-8"))
    b = rig["bounds"]
    out = Image.new("RGBA", (b["width"], b["height"]), (0, 0, 0, 0))
    for key in rig["z_order"]:
        layer = rig["layers"][key]
        img = Image.open(ROOT / "images" / "fish" / f"{name}_{key}.png").convert("RGBA")
        out.alpha_composite(img, (layer["offset"][0] - b["x"], layer["offset"][1] - b["y"]))
    return out


def main() -> int:
    out_path = Path(sys.argv[1])
    names = sys.argv[2:]
    fish = [(n, compose(n)) for n in names]
    width = PAD + sum(img.width + PAD for _, img in fish)
    tallest = max(img.height for _, img in fish)
    sheet = Image.new("RGBA", (width, PAD + tallest + LABEL_H + PAD), CHECK_BG)
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=14)
    x = PAD
    for name, img in fish:
        sheet.alpha_composite(img, (x, PAD + tallest - img.height))
        draw.text((x, PAD + tallest + 4), f"{name} ({img.width} px)", fill=(230, 230, 230, 255), font=font)
        x += img.width + PAD
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(out_path, format="PNG", optimize=False, compress_level=9)
    print(f"wrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
