# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.2"]
# ///
"""Procedural Reef Tank effect sprites (cards P3.7 and P4.6).

Run from anywhere: ``uv run tools/art/reef_fx.py``. Fixed seeds, no PNG metadata, so
reruns are byte-identical.

Outputs (white RGB, the shape lives in alpha, so ``blendColor`` sets the tint):
  - images/fx/caustic_a.png, caustic_b.png  512x512, exactly periodic on the torus
  - images/fx/ripple.png                    1920x128, exactly periodic in x
  - images/fx/shaft_day_a.png, shaft_day_b.png      256x1088 light shafts
  - images/night/moon_shaft_a.png, moon_shaft_b.png 256x1088 narrower moon shafts
  - images/night/sparkle.png                32x32 bioluminescent sparkle
  - images/night/fish_organ_glow.png        64x64 flashlight fish light organ (colour baked in:
                                            whitish-cyan core, cyan halo; drawn untinted)
  - docs/art/caustic-wrap-test.png          offset-wrap proof for both caustic tiles

Caustics are a cellular (Voronoi F2-F1) net computed with wrapped distances on a
domain warp built only from integer-frequency sinusoids, so the tile is periodic by
construction rather than by edge blending. The script prints the wrap-seam metric:
the mean absolute difference across the wrap edge divided by the mean difference
between adjacent interior columns/rows. A seamless tile scores about 1.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from numpy.typing import NDArray
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
FX = ROOT / "images" / "fx"
NIGHT = ROOT / "images" / "night"
DOCS = ROOT / "docs" / "art"

Float = NDArray[np.float32]
TAU = 2.0 * np.pi


def save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=False, compress_level=9)


def white_alpha(alpha: Float) -> Image.Image:
    a = np.clip(np.rint(alpha * 255.0), 0, 255).astype(np.uint8)
    rgb = np.full(a.shape + (3,), 255, dtype=np.uint8)
    return Image.fromarray(np.dstack([rgb, a]))


def periodic_warp(
    rng: np.random.Generator, xs: Float, ys: Float, period_x: float, period_y: float, amp: float, terms: int
) -> tuple[Float, Float]:
    """Displacement field made of integer-frequency sinusoids: periodic in both axes."""
    dx = np.zeros_like(xs)
    dy = np.zeros_like(xs)
    for _ in range(terms):
        kx, ky = rng.integers(1, 4, size=2)
        ph1, ph2 = rng.uniform(0, TAU, size=2)
        a = amp / terms * rng.uniform(0.6, 1.4)
        dx += a * np.sin(TAU * (kx * xs / period_x + ky * ys / period_y) + ph1)
        dy += a * np.cos(TAU * (ky * xs / period_x - kx * ys / period_y) + ph2)
    return dx.astype(np.float32), dy.astype(np.float32)


def cellular_net(
    w: int, h: int, period_x: float, period_y: float, cells: int, seed: int, warp: float, line: float
) -> Float:
    """Bright caustic-like net: exp(-(F2 - F1) / line) of a wrapped, warped Voronoi."""
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = periodic_warp(rng, xs, ys, period_x, period_y, warp, 6)
    px = np.mod(xs + dx, period_x)
    py = np.mod(ys + dy, period_y)
    pts = rng.uniform(0, 1, size=(cells, 2)) * np.array([period_x, period_y])
    f1 = np.full((h, w), np.inf, dtype=np.float32)
    f2 = np.full((h, w), np.inf, dtype=np.float32)
    for cx, cy in pts:
        ddx = np.abs(px - cx)
        ddx = np.minimum(ddx, period_x - ddx)
        ddy = np.abs(py - cy)
        ddy = np.minimum(ddy, period_y - ddy)
        d = np.sqrt(ddx * ddx + ddy * ddy)
        f2 = np.where(d < f1, f1, np.minimum(f2, d))
        f1 = np.minimum(f1, d)
    return np.exp(-(f2 - f1) / line).astype(np.float32)


def periodic_blur(img: Float, sigma: float) -> Float:
    """Gaussian blur by FFT, which wraps at the borders and so keeps periodicity."""
    h, w = img.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    kernel = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(img) * kernel)).astype(np.float32)


def seam_ratio(a: Float, axis: int) -> float:
    """Wrap-edge difference / mean adjacent interior difference along one axis."""
    wrap = np.abs(np.take(a, 0, axis=axis) - np.take(a, -1, axis=axis)).mean()
    interior = np.abs(np.diff(a, axis=axis)).mean()
    return float(wrap / interior)


def caustic(seed: int, cells: int, warp: float, line: float) -> Float:
    net = cellular_net(512, 512, 512.0, 512.0, cells, seed, warp, line)
    net = periodic_blur(net, 1.2)
    net = np.clip((net - 0.08) / 0.92, 0.0, 1.0) ** 1.6
    return (0.85 * net).astype(np.float32)


def ripple() -> Float:
    w, h = 1920, 128
    # Cells are wide and flat (surface seen at a grazing angle): period 1920 in x.
    net = cellular_net(w, h, 1920.0, 128.0 * 2, 64, 4207, 18.0, 4.5)
    # Squash the net vertically toward the top by blending two rows of cells.
    net = periodic_blur(net, 1.0)
    ys = np.arange(h, dtype=np.float32)[:, None] / (h - 1)
    band = (1.0 - ys) ** 1.8  # bright at the surface (top), zero at the bottom row
    base = 0.18 * (1.0 - ys) ** 3  # soft glow of the surface itself
    alpha = np.clip(base + 0.75 * net * band, 0.0, 1.0)
    alpha[-1, :] = 0.0
    return alpha.astype(np.float32)


def shaft(w: int, h: int, seed: int, top_x: float, bottom_x: float, w_top: float, w_bot: float, peak: float) -> Float:
    """A slanted diffuse beam: gaussian across, gentle bands, fading out with depth.

    Soft on both edges (no visible outline) and strongest at the surface, tapering to
    nothing well before the bottom, like light scattering out of the water. Alpha is 0
    on every border.
    """
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    t = ys / (h - 1)
    cx = top_x + (bottom_x - top_x) * t
    half = 0.5 * (w_top + (w_bot - w_top) * t)
    u = (xs - cx) / half  # -1..1 across the nominal beam
    cross = np.exp(-((u / 0.62) ** 2))
    # Gentle bands: wide, low-contrast sub-rays fixed in beam coordinates.
    streak = np.ones_like(u)
    for _ in range(4):
        c0 = rng.uniform(-0.6, 0.6)
        wd = rng.uniform(0.25, 0.5)
        streak += rng.uniform(0.15, 0.35) * np.exp(-(((u - c0) / wd) ** 2))
    streak /= streak.max()
    fade_in = np.clip(t / 0.05, 0, 1)
    fade_in = fade_in * fade_in * (3.0 - 2.0 * fade_in)
    along = fade_in * np.exp(-2.4 * t) * np.clip(1.0 - t, 0.0, 1.0)
    alpha = peak * cross * (0.7 + 0.3 * streak) * along
    # Hard guarantee: zero border, eased so the sprite edge never shows.
    edge = np.clip(np.minimum(xs, w - 1 - xs) / 24.0, 0, 1)
    alpha *= edge * edge * (3.0 - 2.0 * edge)
    alpha[0, :] = alpha[-1, :] = 0.0
    alpha[:, 0] = alpha[:, -1] = 0.0
    return alpha.astype(np.float32)


def sparkle() -> Float:
    n = 32
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xs - (n - 1) / 2, ys - (n - 1) / 2)
    core = np.exp(-((r / 2.2) ** 2))
    halo = 0.45 * np.exp(-((r / 6.5) ** 2))
    alpha = np.clip(core + halo, 0, 1) * np.clip((15.5 - r) / 3.0, 0, 1)
    return alpha.astype(np.float32)


def organ_glow() -> Image.Image:
    """Flashlight fish organ: a bright, slightly wide kidney-ish core and a faint halo.

    The colour is baked in (core #E6FFF9 fading to halo #9FFFF0) because components/Fish
    leaves the Poster's blendColor white; Night skips its night* id, so it stays bright.
    """
    n = 64
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    cx = cy = (n - 1) / 2
    # Core ellipse about 9 x 7.5 px radius (the organ at 40 px display size), soft edge.
    rc = np.hypot((xs - cx) / 9.0, (ys - cy) / 7.5)
    core = np.clip((1.15 - rc) / 0.35, 0, 1)
    halo = 0.55 * np.exp(-((np.hypot((xs - cx) / 17.0, (ys - cy) / 14.5)) ** 2))
    edge = np.clip((31.5 - np.hypot(xs - cx, ys - cy)) / 4.0, 0, 1)
    alpha = np.clip(core + halo * (1 - core), 0, 1) * edge
    # Premultiplied mix of the two colours, so the core reads white-hot and the halo cyan.
    c_core = np.array([230, 255, 249], dtype=np.float32)
    c_halo = np.array([159, 255, 240], dtype=np.float32)
    w = np.where(alpha > 0, core / np.maximum(alpha, 1e-6), 0)[..., None]
    w = np.clip(w, 0, 1)
    rgb = c_core * w + c_halo * (1 - w)
    a = np.clip(np.rint(alpha * 255.0), 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([np.rint(rgb).astype(np.uint8), a]))


def checker(w: int, h: int, cell: int = 16) -> Image.Image:
    ys, xs = np.mgrid[0:h, 0:w]
    c = (((xs // cell) + (ys // cell)) % 2).astype(np.uint8)
    v = np.where(c == 0, 90, 60).astype(np.uint8)
    return Image.fromarray(np.dstack([v // 3, v // 2, v]))


def wrap_test(tiles: dict[str, Float]) -> None:
    """Each tile rolled by half its size in both axes (seam would cross the centre), plus 2x2 tiling."""
    panels: list[Image.Image] = []
    for name, a in tiles.items():
        rolled = np.roll(a, (256, 256), axis=(0, 1))
        for arr in (rolled, np.tile(a, (2, 2))):
            bg = Image.new("RGB", (arr.shape[1], arr.shape[0]), (12, 60, 96))
            bg.paste(white_alpha(arr), (0, 0), white_alpha(arr))
            panels.append(bg.resize((512, 512), Image.Resampling.LANCZOS) if arr.shape[0] > 512 else bg)
    sheet = Image.new("RGB", (512 * 4 + 5 * 16, 512 + 2 * 16 + 24), (20, 20, 24))
    draw = ImageDraw.Draw(sheet)
    labels = ["caustic_a rolled 256,256", "caustic_a 2x2 (scaled)", "caustic_b rolled 256,256", "caustic_b 2x2 (scaled)"]
    for i, (p, lab) in enumerate(zip(panels, labels, strict=True)):
        x = 16 + i * (512 + 16)
        sheet.paste(p, (x, 16 + 24))
        draw.text((x, 12), lab, fill=(230, 230, 230))
        # Mark where the wrap seam now runs on the rolled panels.
        if i % 2 == 0:
            draw.line([(x + 256, 40), (x + 256, 46)], fill=(255, 80, 80))
            draw.line([(x, 40 + 256), (x + 6, 40 + 256)], fill=(255, 80, 80))
    save_png(sheet, DOCS / "caustic-wrap-test.png")


def main() -> int:
    tiles = {
        "caustic_a": caustic(seed=7301, cells=22, warp=26.0, line=5.0),
        "caustic_b": caustic(seed=9157, cells=34, warp=18.0, line=3.8),
    }
    for name, a in tiles.items():
        save_png(white_alpha(a), FX / f"{name}.png")
        q = np.rint(a * 255.0)
        print(f"{name}: seam ratio x {seam_ratio(q, 1):.3f}, y {seam_ratio(q, 0):.3f} (1.0 = no seam)")
    wrap_test(tiles)

    rp = ripple()
    save_png(white_alpha(rp), FX / "ripple.png")
    print(f"ripple: seam ratio x {seam_ratio(np.rint(rp * 255.0), 1):.3f}")

    save_png(white_alpha(shaft(256, 1088, 11, 100, 150, 90, 236, 0.80)), FX / "shaft_day_a.png")
    save_png(white_alpha(shaft(256, 1088, 12, 150, 105, 80, 224, 0.72)), FX / "shaft_day_b.png")
    save_png(white_alpha(shaft(256, 1088, 21, 110, 150, 70, 200, 0.62)), NIGHT / "moon_shaft_a.png")
    save_png(white_alpha(shaft(256, 1088, 22, 150, 106, 60, 190, 0.56)), NIGHT / "moon_shaft_b.png")
    save_png(white_alpha(sparkle()), NIGHT / "sparkle.png")
    save_png(organ_glow(), NIGHT / "fish_organ_glow.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
