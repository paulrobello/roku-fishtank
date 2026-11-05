# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0"]
# ///
"""Arch overlay for the arch swimmer: images/decor/arch_overlay.png.

Run from anywhere: ``uv run tools/art/arch_overlay.py`` (``make arch-art``). The overlay is
a crop of images/decor/reef_backdrop.png around the little rock arch with the opening cut
out (alpha 0), so a fish drawn between the backdrop and this overlay shows only through
the opening. ArchSwimmer places it at the crop's design position in the waterGradient
layer, the backdrop's own layer, so it drifts with the backdrop and stays registered.

The opening is the 4-connected region, grown from a seed in open water, of pixels that
read as water or the far rock behind the arch (blue well above red), inside a hand-tuned
bounding polygon. A 5 px closing fills specks, a 1 px erosion keeps the fish inside the
rock edge, and a 0.8 px blur feathers the cut. The RGB under alpha 0 is the backdrop's
own. Byte-reproducible: no randomness, no PNG metadata.

The crop (OVERLAY_*) must match config/arch.json "overlay"; the design x of a backdrop
pixel is its image x + BACKDROP_X (scene.json decor reefBackdrop x).
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
BACKDROP = ROOT / "images" / "decor" / "reef_backdrop.png"
OUT = ROOT / "images" / "decor" / "arch_overlay.png"

BACKDROP_X = -313
# Design pixels; width and height are multiples of 32 so the texture is not padded.
OVERLAY_X = 240
OVERLAY_Y = 480
OVERLAY_W = 416
OVERLAY_H = 192

SEED = (500, 560)
# The opening's outer limit in design pixels. The bottom edge stays above the far rock
# and sea whip tips below the swim band, which the mid coral covers anyway.
BOUND = [
    (455, 498),
    (530, 498),
    (600, 520),
    (632, 560),
    (632, 625),
    (262, 625),
    (262, 585),
    (330, 540),
    (400, 515),
]


def is_opening(rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    return b - r >= 30 and b >= 60 and g >= r


def build() -> Image.Image:
    src = Image.open(BACKDROP).convert("RGB")
    left = OVERLAY_X - BACKDROP_X
    crop = src.crop((left, OVERLAY_Y, left + OVERLAY_W, OVERLAY_Y + OVERLAY_H))

    bound = Image.new("L", crop.size, 0)
    ImageDraw.Draw(bound).polygon([(x - OVERLAY_X, y - OVERLAY_Y) for x, y in BOUND], fill=255)

    px = crop.load()
    inside = bound.load()
    hole = Image.new("L", crop.size, 0)
    out = hole.load()
    start = (SEED[0] - OVERLAY_X, SEED[1] - OVERLAY_Y)
    todo: deque[tuple[int, int]] = deque([start])
    seen = {start}
    while todo:
        x, y = todo.popleft()
        if inside[x, y] == 0 or not is_opening(px[x, y]):
            continue
        out[x, y] = 255
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < OVERLAY_W and 0 <= ny < OVERLAY_H and (nx, ny) not in seen:
                seen.add((nx, ny))
                todo.append((nx, ny))

    hole = hole.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    hole = Image.composite(hole, bound, bound)  # the closing must not grow past the bound
    hole = hole.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    alpha = hole.point(lambda v: 255 - v)
    overlay = crop.convert("RGBA")
    overlay.putalpha(alpha)
    return overlay


def main() -> None:
    overlay = build()
    overlay.save(OUT, optimize=True)
    clear = sum(1 for a in overlay.getchannel("A").getdata() if a == 0)
    print(f"{OUT.relative_to(ROOT)} {overlay.size[0]}x{overlay.size[1]} clear={clear} px bytes={OUT.stat().st_size}")


if __name__ == "__main__":
    main()
