# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.2"]
# ///
"""Reef Tank decor, night-glow and reef-extras sprites from the Higgsfield originals.

Run from anywhere: ``uv run tools/art/reef_decor.py`` (after ``tools/art/reef_fx.py``
if you also want the procedural sprites). Deterministic, no PNG metadata.

Inputs: ``assets/source/decor/*.png`` and ``assets/source/extras/*.png`` (native-alpha
gpt_image_2_5 cutouts, see the PROVENANCE.md next to them).

Outputs:
  images/decor/   P1.7: mid coral strip as column tiles, front coral clumps, sand lip band,
                  sand-lip plant tufts, plant cluster, rock pillar
  images/night/   P3.7: half-resolution coral glow masks (backdrop, mid tiles, front clumps)
  images/extras/  P4.6: anemone body and tentacle segments, sea fan and soft coral sway
                  segments, shrimp (body + antennae, right and pre-mirrored left), crab, starfish
  docs/art/placement-proposal.json  sprite sizes, design-space placements and rig pivots

Every placement is in design pixels (1920x1080) relative to the camera Group, with the
strips authored 2560 wide (x = -320) so the foreground can drift 320 px.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import numpy as np
from numpy.typing import NDArray
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "source"
IMG = ROOT / "images"
DOCS = ROOT / "docs" / "art"

Float = NDArray[np.float32]

SOURCE_HAZE = 8  # generator alpha haze below this is zeroed (same rule as rig.py)
ALPHA_DUST = 3  # after resampling, alpha below this is zeroed before the tight crop

STRIP_W = 2560
STRIP_X = -320
SAND_H = 128
SAND_TOP_Y = 1080 - SAND_H  # sand band: 2560x128 at the bottom of the screen
FRONT_SCALE = 0.42  # front clumps, source px -> design px
MID_SCALE_OVERLAP = 96  # px crossfade where the two mid friezes join

placements: dict[str, Any] = {}


# ---------------------------------------------------------------- helpers


def save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=False, compress_level=9)


def to_float(img: Image.Image) -> Float:
    return np.asarray(img.convert("RGBA"), dtype=np.float32) / 255.0


def to_image(arr: Float) -> Image.Image:
    return Image.fromarray(np.clip(np.rint(arr * 255.0), 0, 255).astype(np.uint8))


def load(rel: str) -> Float:
    arr = to_float(Image.open(SRC / rel))
    arr[arr[..., 3] < SOURCE_HAZE / 255.0] = 0.0
    return arr


def bbox(alpha: NDArray[Any], thr: float = 0.0) -> tuple[int, int, int, int]:
    ys, xs = np.nonzero(alpha > thr)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def trim(arr: Float) -> Float:
    x0, y0, x1, y1 = bbox(arr[..., 3])
    return arr[y0:y1, x0:x1]


def scale(arr: Float, size: tuple[int, int]) -> Float:
    """Lanczos resize in premultiplied alpha (no dark fringes)."""
    img = to_image(arr).convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")
    return to_float(img)


def scale_by(arr: Float, s: float) -> Float:
    h, w = arr.shape[:2]
    return scale(arr, (max(1, round(w * s)), max(1, round(h * s))))


def bleed(arr: Float) -> Float:
    """Fill transparent RGB with nearby visible colour so bilinear edges stay clean."""
    a = arr[..., 3:4]
    pre = to_image(np.dstack([arr[..., :3] * a, a])).convert("RGBA")
    blurred = to_float(pre.filter(ImageFilter.GaussianBlur(6)))
    ba = np.maximum(blurred[..., 3:4], 1e-4)
    fill = np.clip(blurred[..., :3] / ba, 0, 1)
    out = arr.copy()
    empty = arr[..., 3] <= 0
    out[empty, :3] = fill[empty]
    return out


def finish(arr: Float) -> tuple[Float, tuple[int, int]]:
    """Zero alpha dust, crop tight, bleed colour. Returns array and crop origin."""
    arr = arr.copy()
    arr[arr[..., 3] < ALPHA_DUST / 255.0] = 0.0
    x0, y0, x1, y1 = bbox(arr[..., 3])
    return bleed(arr[y0:y1, x0:x1]), (x0, y0)


def emit(arr: Float, rel: str) -> tuple[int, int]:
    img = to_image(arr)
    save_png(img, IMG / rel)
    return img.size


def ramp(x: Float, x0: float, x1: float) -> Float:
    return np.clip((x - x0) / (x1 - x0), 0.0, 1.0).astype(np.float32)


def place(key: str, rel: str, size: tuple[int, int], **info: Any) -> None:
    placements[key] = {"file": f"images/{rel}", "width": size[0], "height": size[1], **info}


# ---------------------------------------------------------------- P1.7 decor


def chunks(arr: Float, width: int) -> list[tuple[Float, int, int]]:
    """Cut into column chunks, each cropped to its own alpha bbox.

    Same layer, same parallax and integer positions, so the joins are invisible, while
    the transparent corners above low parts are never drawn (fill rate).
    Returns (pixels, x, y) relative to arr's origin.
    """
    out = []
    for x in range(0, arr.shape[1], width):
        col = arr[:, x : x + width].copy()
        col[col[..., 3] < ALPHA_DUST / 255.0] = 0.0
        if col[..., 3].max() < 0.1:
            continue
        x0, y0, x1, y1 = bbox(col[..., 3])
        out.append((bleed(col[y0:y1, x0:x1]), x + x0, y0))
    return out


def sand_band() -> tuple[Float, Float, int]:
    """Sand band (2560x128) and the tuft region above it, on one 2560-wide scale.

    Returns band, tufts, and the band row from which every column is opaque.
    """
    arr = load("decor/sand_lip.png")
    x0, y0, x1, _ = bbox(arr[..., 3])
    arr = arr[:, x0:x1]
    s = STRIP_W / arr.shape[1]
    cut_src = 680  # rows above this are plant tufts, below is the sand band
    band_src = arr[cut_src : cut_src + round(SAND_H / s) + 2]
    band = scale(band_src, (STRIP_W, round(band_src.shape[0] * s)))[:SAND_H]
    band = bleed(band)
    # Per column, the first row from which alpha stays above 0.9 down to the bottom.
    # The 99th percentile of those rows is where flat sprite bottoms can hide.
    solid = band[..., 3] > 0.9
    first = np.array([0 if solid[:, x].all() else int(np.nonzero(~solid[:, x])[0].max()) + 1 for x in range(band.shape[1])])
    opaque = int(np.ceil(np.percentile(first, 99)))
    assert 0 < opaque < SAND_H - 8, f"sand band has no usable opaque line ({opaque})"
    tufts_src = arr[y0:cut_src]
    tufts = scale(tufts_src, (STRIP_W, round(tufts_src.shape[0] * s)))
    return band, tufts, opaque


def mid_strip() -> tuple[Float, int]:
    """Two mid friezes side by side with a crossfade at the join, 2560 wide."""
    a = trim(load("decor/mid_coral_a.png"))
    b = trim(load("decor/mid_coral_b.png"))
    s = (STRIP_W + MID_SCALE_OVERLAP) / (a.shape[1] + b.shape[1])
    a_s = scale_by(a, s)
    b_s = scale_by(b, s)
    h = max(a_s.shape[0], b_s.shape[0])
    canvas_w = a_s.shape[1] + b_s.shape[1] - MID_SCALE_OVERLAP
    pa = np.zeros((h, canvas_w, 4), np.float32)
    pb = np.zeros((h, canvas_w, 4), np.float32)
    pa[h - a_s.shape[0] :, : a_s.shape[1]] = a_s
    xb = a_s.shape[1] - MID_SCALE_OVERLAP
    pb[h - b_s.shape[0] :, xb:] = b_s
    xs = np.arange(canvas_w, dtype=np.float32)[None, :]
    t = ramp(xs, xb, xb + MID_SCALE_OVERLAP)[..., None]
    pre = pa[..., :3] * pa[..., 3:] * (1 - t) + pb[..., :3] * pb[..., 3:] * t
    al = pa[..., 3:] * (1 - t) + pb[..., 3:] * t
    # Inside the join keep the union silhouette, so no ghosted half-alpha top appears.
    in_join = (t > 0) & (t < 1)
    al2 = np.where(in_join, np.maximum(pa[..., 3:], pb[..., 3:]), al)
    rgb = np.where(al > 1e-4, pre / np.maximum(al, 1e-4), 0)
    strip = np.dstack([rgb, al2]).astype(np.float32)
    if canvas_w >= STRIP_W:
        strip = strip[:, :STRIP_W]
    else:
        strip = np.pad(strip, ((0, 0), (0, STRIP_W - canvas_w), (0, 0)))
    return strip, h


def split_clumps(arr: Float, cuts: list[int], feather: int) -> list[Float]:
    """Cut a frieze at the given source columns, feathering alpha at each cut edge."""
    edges = [0, *cuts, arr.shape[1]]
    out = []
    for i in range(len(edges) - 1):
        lo, hi = edges[i], edges[i + 1]
        piece = arr[:, lo:hi].copy()
        xs = np.arange(hi - lo, dtype=np.float32)
        f = np.ones_like(xs)
        if i > 0:
            f *= ramp(xs, 0, feather)
        if i < len(edges) - 2:
            f *= ramp((hi - lo) - 1 - xs, 0, feather)
        piece[..., 3] *= f[None, :]
        out.append(piece)
    return out


def front_clumps() -> list[tuple[str, Float]]:
    res = []
    for name, cuts in (("front_coral_a", [915, 1830]), ("front_coral_b", [903])):
        arr = load(f"decor/{name}.png")
        for i, piece in enumerate(split_clumps(arr, cuts, 48)):
            fin, _ = finish(scale_by(trim(piece), FRONT_SCALE))
            res.append((f"{name[-1]}{i}", fin))
    return res


def emit_chunks(key: str, arr: Float, width: int, x: int, y: int, layer: str) -> None:
    for j, (fin, cx, cy) in enumerate(chunks(arr, width)):
        rel = f"decor/{key}_{j}.png"
        size = emit(fin, rel)
        place(f"{key}_{j}", rel, size, layer=layer, x=x + cx, y=y + cy, group=key, card="P1.7")


def build_decor() -> None:
    band, tufts, opaque = sand_band()
    # Everything that stands on the sand ends 8 px inside the band's fully opaque rows.
    ground = SAND_TOP_Y + opaque + 8
    placements["_ground_y"] = ground

    strip, h = mid_strip()
    emit_chunks("mid_coral", strip, 256, STRIP_X, ground - h, "midCoral")

    size = emit(band, "decor/sand_lip.png")
    place("sand_lip", "decor/sand_lip.png", size, layer="foreground", x=STRIP_X, y=SAND_TOP_Y, card="P1.7")
    emit_chunks("sand_tuft", tufts, 96, STRIP_X, SAND_TOP_Y - tufts.shape[0], "foreground")

    xs = [-250, 330, 1460, 1960, 760]
    for (stem, fin), x in zip(front_clumps(), xs, strict=True):
        emit_chunks(f"front_coral_{stem}", fin, 192, x, ground - fin.shape[0], "frontCoral")

    pillar, _ = finish(scale_by(trim(load("decor/rock_pillar.png")), 440 / 2310))
    size = emit(pillar, "decor/rock_pillar.png")
    place("rock_pillar", "decor/rock_pillar.png", size, layer="midCoral", x=1520, y=ground - 4 - size[1], card="P1.7")

    plants = trim(load("decor/plant_cluster.png"))
    # The tallest blades touch the frame top: fade the top 3% so no cut line shows.
    ph = plants.shape[0]
    plants[..., 3] *= ramp(np.arange(ph, dtype=np.float32), 0, 0.03 * ph)[:, None]
    pc, _ = finish(scale_by(plants, 360 / ph))
    size = emit(pc, "decor/plant_cluster.png")
    place("plant_cluster", "decor/plant_cluster.png", size, layer="foreground", x=-120, y=1080 - 30 - size[1], card="P1.7")


# ---------------------------------------------------------------- P3.7 glow masks


def hsv_to_rgb(h: Float, s: float, v: float) -> Float:
    """Vectorised HSV -> RGB for scalar saturation and value."""
    i = np.floor(h * 6.0).astype(np.int32) % 6
    f = (h * 6.0 - np.floor(h * 6.0)).astype(np.float32)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    vv = np.full_like(f, v)
    pp = np.full_like(f, p)
    r = np.choose(i, [vv, q, pp, pp, t, vv])
    g = np.choose(i, [t, vv, vv, q, pp, pp])
    b = np.choose(i, [pp, pp, t, vv, vv, q])
    return np.dstack([r, g, b]).astype(np.float32)


def glow_mask(arr: Float) -> Float:
    """Bright, saturated coral tissue -> fluorescent colour at full value, half resolution.

    Water blues (hue 0.53-0.66) are excluded so open water and haze never glow.
    """
    rgb_img = to_image(arr).convert("RGB")
    hsv = np.asarray(rgb_img.convert("HSV"), dtype=np.float32) / 255.0
    sat = ramp(hsv[..., 1], 0.45, 0.70)
    val = ramp(hsv[..., 2], 0.55, 0.85)
    hue = hsv[..., 0]
    not_water = 1.0 - ramp(hue, 0.51, 0.53) * (1.0 - ramp(hue, 0.66, 0.68))
    g = arr[..., 3] * sat * val * not_water
    col = hsv_to_rgb(hue, 0.70, 1.0)
    out = np.dstack([col, g]).astype(np.float32)
    h, w = arr.shape[:2]
    half = scale(out, (max(1, (w + 1) // 2), max(1, (h + 1) // 2)))
    return to_float(to_image(half).filter(ImageFilter.GaussianBlur(1.5)))


def glow_chunks(key: str, m: Float, width: int, x: int, y: int, layer: str, over: str) -> None:
    m[m[..., 3] < 12 / 255.0] = 0
    for j, (fin, cx, cy) in enumerate(chunks(m, width)):
        if fin[..., 3].sum() < 40:  # a few faint pixels are not worth a Poster
            continue
        rel = f"night/glow_{key}_{j}.png"
        size = emit(fin, rel)
        place(f"glow_{key}_{j}", rel, size, layer=layer, x=x + 2 * cx, y=y + 2 * cy, scale=2.0, over=over, card="P3.7")


def build_glow() -> None:
    for key in [k for k in list(placements) if k.startswith(("mid_coral_", "front_coral_"))]:
        p = placements[key]
        m = glow_mask(to_float(Image.open(ROOT / p["file"])))
        glow_chunks(key, m, 64, p["x"], p["y"], p["layer"], key)
    back = to_float(Image.open(IMG / "decor" / "reef_backdrop.png"))
    glow_chunks("backdrop", glow_mask(back), 96, -313, 0, "waterGradient", "reefBackdrop")


# ---------------------------------------------------------------- P4.6 extras


def segments(arr: Float, n: int, overlap: int, base_frac: float | None = None) -> list[tuple[Float, dict[str, Any]]]:
    """Split a sprite into n horizontal bands bottom to top for a sway chain.

    Each band k > 0 carries ``overlap`` extra rows below its boundary with alpha ramping
    in, so a rotated segment never opens a gap. Every band keeps the full sprite width so
    pivots share one x axis. The pivot is the bottom-centre of the band (on the boundary).
    """
    h, w = arr.shape[:2]
    bounds = [h]
    if base_frac is not None:
        bounds.append(round(h * (1 - base_frac)))
        rest = bounds[-1]
        for k in range(1, n - 1):
            bounds.append(round(rest * (1 - k / (n - 1))))
    else:
        for k in range(1, n):
            bounds.append(round(h * (1 - k / n)))
    bounds.append(0)
    a = arr[..., 3]
    out = []
    for k in range(n):
        y1, y0 = bounds[k], bounds[k + 1]
        lo = min(h, y1 + (overlap if k > 0 else 0))
        band = arr[y0:lo].copy()
        if k > 0:
            ys = np.arange(lo - y0, dtype=np.float32)
            band[..., 3] *= (1 - ramp(ys, y1 - y0, lo - y0))[:, None]
        row = a[min(y1, h - 1)] if k > 0 else a[h - 1]
        cx = float((row * np.arange(w)).sum() / max(row.sum(), 1e-6)) if row.sum() > 0 else w / 2
        band = bleed(band)
        top_row = a[y0]
        tx = float((top_row * np.arange(w)).sum() / max(top_row.sum(), 1e-6)) if top_row.sum() > 0 else cx
        out.append((band, {"pivot": [round(cx, 1), y1 - y0], "child_attach": [round(tx, 1), 0]}))
    return out


def build_extras() -> None:
    body, _ = finish(scale_by(trim(load("extras/anemone_body.png")), 240 / 1684))
    size = emit(body, "extras/anemone_body.png")
    place("anemone_body", "extras/anemone_body.png", size, layer="frontCoral", x=1080, y=SAND_TOP_Y + 16 - size[1], card="P4.6")

    def chain(name: str, src: str, height: int, n: int, overlap: int, base_frac: float | None, layer: str, x: int) -> None:
        arr = trim(load(src))
        arr = scale_by(arr, height / arr.shape[0])
        segs = []
        for k, (band, rig) in enumerate(segments(arr, n, overlap, base_frac)):
            rel = f"extras/{name}_seg{k}.png"
            size = emit(band, rel)
            segs.append({"file": f"images/{rel}", "width": size[0], "height": size[1], **rig})
        placements[name] = {
            "layer": layer, "x": x, "y": SAND_TOP_Y + 8 - height, "height": height, "segments": segs, "card": "P4.6",
        }

    chain("anemone_tentacle", "extras/anemone_tentacle.png", 72, 3, 4, None, "frontCoral", 1180)
    chain("sea_fan", "extras/sea_fan.png", 340, 3, 8, 0.22, "midCoral", 640)
    chain("soft_coral", "extras/soft_coral.png", 280, 3, 8, 0.25, "frontCoral", 1700)

    # Shrimp: body and antennae layers registered on one canvas, then mirrored.
    shrimp = load("extras/shrimp.png")
    hh, ww = shrimp.shape[:2]
    ys, xs = np.mgrid[0:hh, 0:ww]
    ant = (ys < 640) | ((xs > 1700) & (ys < 745)) | (xs > 1760)
    s = 200 / 1975
    full = scale_by(shrimp, s)
    antm = scale(np.dstack([np.ones((hh, ww, 3), np.float32), ant.astype(np.float32)]), full.shape[1::-1])[..., 3]
    x0, y0, x1, y1 = bbox(full[..., 3], ALPHA_DUST / 255.0)
    full = full[y0:y1, x0:x1]
    antm = antm[y0:y1, x0:x1]
    body_l = full.copy()
    body_l[..., 3] *= 1 - antm
    ant_l = full.copy()
    ant_l[..., 3] *= antm
    pivot = [round(1720 * s) - x0, round(745 * s) - y0]
    for facing, flip in (("r", False), ("l", True)):
        for part, arr in (("body", body_l), ("antennae", ant_l)):
            a2 = arr[:, ::-1] if flip else arr
            rel = f"extras/shrimp_{part}_{facing}.png"
            size = emit(bleed(a2), rel)
        px = (full.shape[1] - pivot[0]) if flip else pivot[0]
        placements[f"shrimp_{facing}"] = {
            "body": f"images/extras/shrimp_body_{facing}.png", "antennae": f"images/extras/shrimp_antennae_{facing}.png",
            "width": size[0], "height": size[1], "antenna_pivot": [px, pivot[1]], "layer": "frontLane",
            "x": 600, "y": SAND_TOP_Y + 40 - size[1], "card": "P4.6",
        }

    crab, _ = finish(scale_by(trim(load("extras/crab.png")), 150 / 1971))
    size = emit(crab, "extras/crab.png")
    place("crab", "extras/crab.png", size, layer="frontLane", x=900, y=SAND_TOP_Y + 64 - size[1], card="P4.6")
    crab_layers()
    star, _ = finish(scale_by(trim(load("extras/starfish.png")), 112 / 1971))
    size = emit(star, "extras/starfish.png")
    place("starfish", "extras/starfish.png", size, layer="frontLane", x=1300, y=SAND_TOP_Y + 24 - size[1], card="P4.6")


# Crab limbs, in source pixels of assets/source/extras/crab.png. The right side mirrors
# the left about CRAB_MID. Claws take precedence over legs; the body keeps the rest.
CRAB_MID = 2040
CRAB_CLAW = [(400, 420), (470, 372), (545, 395), (600, 460), (640, 540), (700, 590), (800, 640),
             (965, 720), (975, 925), (760, 930), (620, 890), (520, 830), (460, 770), (425, 700),
             (415, 620), (405, 540)]
CRAB_LEG_PIVOT = (520, 520)
CRAB_CLAW_PIVOT = (600, 470)


def crab_layers() -> None:
    """Body, legs and claws of the crab on one shared canvas (the crab.png crop)."""
    from PIL import ImageDraw

    src = load("extras/crab.png")
    hh, ww = src.shape[:2]
    tx0, ty0, tx1, ty1 = bbox(src[..., 3])

    def poly(points: list[tuple[int, int]]) -> NDArray[Any]:
        img = Image.new("L", (ww, hh), 0)
        ImageDraw.Draw(img).polygon(points, fill=255)
        return np.asarray(img) > 0

    ys, xs = np.mgrid[0:hh, 0:ww]
    claw_l = poly(CRAB_CLAW)
    claw_r = poly([(CRAB_MID - x, y) for x, y in CRAB_CLAW])
    legs_l = ((xs < 530) | (ys > 950)) & (xs < CRAB_MID / 2) & ~claw_l
    legs_r = ((xs > CRAB_MID - 530) | (ys > 950)) & (xs >= CRAB_MID / 2) & ~claw_r
    s = 150 / 1971
    full = scale_by(src[ty0:ty1, tx0:tx1], s)
    x0, y0, x1, y1 = bbox(full[..., 3], ALPHA_DUST / 255.0)
    full = full[y0:y1, x0:x1]

    def soft(mask: NDArray[Any]) -> Float:
        m = mask[ty0:ty1, tx0:tx1].astype(np.float32)
        h2, w2 = m.shape
        a = scale(np.dstack([np.ones((h2, w2, 3), np.float32), m]), (round(w2 * s), round(h2 * s)))[..., 3]
        return a[y0:y1, x0:x1]

    masks = {"legs_l": soft(legs_l), "legs_r": soft(legs_r), "claw_l": soft(claw_l), "claw_r": soft(claw_r)}
    masks["body"] = np.clip(1.0 - sum(masks.values()), 0.0, 1.0)

    def at(pt: tuple[int, int]) -> list[int]:
        return [round((pt[0] - tx0) * s) - x0, round((pt[1] - ty0) * s) - y0]

    for name, m in masks.items():
        part = full.copy()
        part[..., 3] *= m
        size = emit(bleed(part), f"extras/crab_{name}.png")
    mirror = (CRAB_MID - CRAB_LEG_PIVOT[0], CRAB_LEG_PIVOT[1])
    claw_mirror = (CRAB_MID - CRAB_CLAW_PIVOT[0], CRAB_CLAW_PIVOT[1])
    placements["crab_layers"] = {
        "width": size[0], "height": size[1],
        "leg_pivot_l": at(CRAB_LEG_PIVOT), "leg_pivot_r": at(mirror),
        "claw_pivot_l": at(CRAB_CLAW_PIVOT), "claw_pivot_r": at(claw_mirror),
    }
    print("crab layers", placements["crab_layers"])


OWNED = [
    "decor/mid_coral_*.png", "decor/front_coral_*.png", "decor/sand_*.png", "decor/rock_pillar.png",
    "decor/plant_cluster.png", "night/glow_*.png", "extras/*.png",
]


def main() -> int:
    for pattern in OWNED:  # stale outputs of an earlier layout must not linger
        for old in IMG.glob(pattern):
            old.unlink()
    build_decor()
    build_glow()
    build_extras()
    out = DOCS / "placement-proposal.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(placements, indent=2) + "\n", encoding="utf-8")
    for k, v in placements.items():
        if not isinstance(v, dict):
            print(k, v)
        elif "segments" in v:
            print(k, [(s["width"], s["height"]) for s in v["segments"]])
        else:
            print(k, v.get("width"), v.get("height"), "at", v.get("x"), v.get("y"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
