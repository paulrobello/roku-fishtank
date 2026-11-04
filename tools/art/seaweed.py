# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0"]
# ///
"""Seaweed segments for the P1.4 sway: images/decor/seaweed_seg<k>.png, k = 0 (base) .. 6 (tip).

Run from anywhere: ``uv run tools/art/seaweed.py`` (``make ambient-art``). Byte-reproducible.

Input: assets/source/seaweed/blade_rgba.png, the approved MOSS-Image cutout (provenance in
assets/source/seaweed/PROVENANCE.md). The blade is cropped to its alpha bounds, scaled to
SEGMENTS * STEP + OVERLAP px tall, centred in a SIZE-wide strip and cut into SEGMENTS
slices of SIZE x SIZE. Slice k starts k * STEP px above the base, so neighbouring slices
share OVERLAP rows: at rest the stacked slices reproduce the blade exactly, and when a
joint bends the lower slice's top rows cover the wedge that opens under the upper slice.
Each slice is one 64x64 tile (docs/perf.md: no padding), 16 KB of texture each.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "source" / "seaweed" / "blade_rgba.png"
OUT_DIR = ROOT / "images" / "decor"
SEGMENTS = 7
SIZE = 64
STEP = 56
OVERLAP = SIZE - STEP


def main() -> None:
    blade = Image.open(SRC).convert("RGBA")
    blade = blade.crop(blade.getchannel("A").getbbox())
    height = SEGMENTS * STEP + OVERLAP
    width = round(blade.width * height / blade.height)
    assert width <= SIZE, f"blade {width} px wide does not fit the {SIZE} px strip"
    blade = blade.resize((width, height), Image.Resampling.LANCZOS)
    strip = Image.new("RGBA", (SIZE, height), (0, 0, 0, 0))
    strip.paste(blade, ((SIZE - width) // 2, 0))
    for k in range(SEGMENTS):
        bottom = height - k * STEP
        piece = strip.crop((0, bottom - SIZE, SIZE, bottom))
        out = OUT_DIR / f"seaweed_seg{k}.png"
        piece.save(out, optimize=True)
        print(f"wrote {out.relative_to(ROOT)} {piece.size}")
    print(f"blade {width}x{height}, step {STEP}, overlap {OVERLAP}")


if __name__ == "__main__":
    main()
