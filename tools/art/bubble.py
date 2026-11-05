# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0"]
# ///
"""Bubble sprite for the P1.3 bubble column: images/decor/bubble.png (32x32 RGBA).

Run from anywhere: ``uv run tools/art/bubble.py`` (``make ambient-art``). Drawn
procedurally at 8x and downsampled, so the output is byte-reproducible (seeded noise,
no PNG metadata). A nearly clear body, a thin edge ring brightest toward the window light
(upper left) and its mirror (lower right), a faint dark refraction fringe inside the ring,
a short window-reflection arc with a small specular dot on it, and a faint bounce arc on
the opposite side.
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
            ang = math.atan2(dy, dx)
            # Nearly clear body with a faint cool cast, a touch denser toward the edge.
            body = 0.025 + 0.05 * smooth(0.5, 0.9, d)
            # Thin edge ring (about 9% of the radius), brightest where the window light
            # (upper left) and its mirror (lower right) hit the sphere.
            ring = smooth(0.82, 0.93, d) * (1 - smooth(0.97, 1.0, d))
            lobe = max(0.0, math.cos(ang - math.radians(225))) ** 3 + 0.55 * max(0.0, math.cos(ang - math.radians(45))) ** 3
            edge = ring * (0.38 + 0.50 * min(1.0, lobe))
            # Thin dark fringe just inside the ring: the bubble refracts what is behind it.
            fringe = smooth(0.70, 0.86, d) * (1 - smooth(0.86, 0.92, d)) * 0.10
            # Crisp window reflection, a short bright arc hugging the upper-left edge.
            ra = math.radians(225)
            da = math.atan2(math.sin(ang - ra), math.cos(ang - ra))
            arc = max(0.0, 1 - abs(da) / 0.34) ** 1.6 * smooth(0.66, 0.74, d) * (1 - smooth(0.80, 0.88, d))
            # Small sharp specular dot inside it.
            sx, sy = dx + 0.53, dy + 0.53
            spec = max(0.0, 1 - math.hypot(sx, sy) / 0.11) ** 1.3
            # Faint secondary reflection (light passing through) on the opposite side.
            ba = math.radians(45)
            db = math.atan2(math.sin(ang - ba), math.cos(ang - ba))
            bounce = max(0.0, 1 - abs(db) / 0.55) ** 2 * smooth(0.66, 0.80, d) * (1 - smooth(0.84, 0.93, d))
            a = body + edge * 0.95 + arc * 0.6 + spec * 0.95 + bounce * 0.32 - fringe * 0.4
            a = min(1.0, max(0.0, a))
            a *= 0.96 + 0.04 * rng.random()
            white = min(1.0, edge * 1.4 + arc + spec + bounce)
            rr = int(190 + 65 * white)
            gg = int(225 + 30 * white)
            bb = 255
            px[x, y] = (rr, gg, bb, int(round(255 * a)))
    img = img.filter(ImageFilter.GaussianBlur(SS * 0.35))
    img = img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)} {img.size}")


if __name__ == "__main__":
    main()
