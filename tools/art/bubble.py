# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0"]
# ///
"""Bubble sprite for the P1.3 bubble column: images/decor/bubble.png (32x32 RGBA).

Run from anywhere: ``uv run tools/art/bubble.py`` (``make ambient-art``). Drawn
procedurally at 8x and downsampled, so the output is byte-reproducible (seeded noise,
no PNG metadata). The body is a faint cool tint, the rim a soft bright ring that is
thicker on the lower right, plus a soft upper-left highlight and a small catchlight.
32x32 keeps the texture at one 32-pixel tile (docs/perf.md); Posters scale it to
8-26 px.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "images" / "decor" / "bubble.png"
SIZE = 32
SS = 8


def smooth(e0: float, e1: float, x: float) -> float:
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def main() -> None:
    n = SIZE * SS
    c = n / 2
    r = n / 2 - SS * 1.5
    rng = random.Random(1104)
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()
    for y in range(n):
        for x in range(n):
            dx = (x + 0.5 - c) / r
            dy = (y + 0.5 - c) / r
            d = math.hypot(dx, dy)
            if d > 1.0:
                continue
            # Rim: bright soft ring, heavier toward the lower right (light from upper left).
            bias = 0.5 + 0.5 * (dx * 0.7071 + dy * 0.7071)
            rim = smooth(0.62 - 0.12 * bias, 0.97, d) * (1 - smooth(0.97, 1.0, d))
            body = 0.10
            # Soft upper-left highlight lobe.
            hx, hy = dx + 0.38, dy + 0.40
            hl = max(0.0, 1 - math.hypot(hx * 1.3, hy * 1.6) / 0.42) ** 1.6
            # Tiny catchlight.
            cx, cy = dx + 0.30, dy + 0.46
            cl = max(0.0, 1 - math.hypot(cx, cy) / 0.13) ** 1.2
            a = min(1.0, body + rim * (0.55 + 0.35 * bias) + hl * 0.55 + cl * 0.9)
            a *= 0.94 + 0.06 * rng.random()
            # Cool tint in the body, whiter toward rim and highlights.
            white = min(1.0, rim * 0.7 + hl + cl)
            rr = int(170 + 85 * white)
            gg = int(215 + 40 * white)
            bb = 255
            px[x, y] = (rr, gg, bb, int(round(255 * a)))
    img = img.filter(ImageFilter.GaussianBlur(SS * 0.35))
    img = img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)} {img.size}")


if __name__ == "__main__":
    main()
