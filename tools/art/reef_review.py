# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.2"]
# ///
"""Review sheets, mockups, overdraw maps and the texture-budget sum for the P1.7, P3.7
and P4.6 art. Run after ``reef_fx.py`` and ``reef_decor.py``:
``uv run tools/art/reef_review.py``.

Mockups use only what the device can draw: alpha-over, a ``blendColor`` multiply and
opacity. Glow is a tinted alpha-over, never additive. Placements come from
``docs/art/placement-proposal.json`` (camera offset 0), fish from the species rigs.

Writes docs/art/contact-{decor,night,extras}.png, mockup-{day,night}.png and
overdraw-{day,night}.png, and prints padded texture MB per P0.7 budget group.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from key_art import fish_at_rest  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
IMG = ROOT / "images"
DOCS = ROOT / "docs" / "art"
W, H = 1920, 1080
NIGHT_TINT = (64, 86, 140)  # moonlight multiply applied to every day layer at night

P: dict[str, Any] = {k: v for k, v in json.loads((DOCS / "placement-proposal.json").read_text()).items() if isinstance(v, dict)}


def rgba(rel: str) -> Image.Image:
    with Image.open(ROOT / rel if rel.startswith("images/") else IMG / rel) as im:
        return im.convert("RGBA")


def tinted(img: Image.Image, tint: tuple[int, int, int] | None = None, opacity: float = 1.0) -> Image.Image:
    a = np.asarray(img, dtype=np.float32)
    if tint is not None:
        a[..., :3] *= np.array(tint, np.float32) / 255.0
    a[..., 3] *= opacity
    return Image.fromarray(np.clip(np.rint(a), 0, 255).astype(np.uint8))


def put(dst: Image.Image, img: Image.Image, x: float, y: float, scale: float = 1.0, **kw: Any) -> None:
    if scale != 1.0:
        img = img.resize((round(img.width * scale), round(img.height * scale)), Image.Resampling.BILINEAR)
    img = tinted(img, **kw) if kw else img
    layer = Image.new("RGBA", dst.size, (0, 0, 0, 0))
    layer.paste(img, (round(x), round(y)))
    dst.alpha_composite(layer)


def chain_at_rest(entry: dict[str, Any]) -> tuple[Image.Image, int]:
    """Stack sway segments at rest. Returns the image and the x of the base pivot."""
    segs = entry["segments"]
    w = max(s["width"] for s in segs)
    h = entry["height"] + 16
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    y_pivot = h
    for s in segs:
        im = rgba(s["file"])
        top = y_pivot - s["pivot"][1]
        canvas.alpha_composite(im, (0, top))
        y_pivot = top
    return canvas, segs[0]["pivot"][0]


def sprites_for(layer: str) -> list[tuple[str, dict[str, Any]]]:
    return [(k, v) for k, v in P.items() if v.get("layer") == layer and not k.startswith("glow_")]


def draw_layer(frame: Image.Image, layer: str, tint: tuple[int, int, int] | None) -> None:
    kw = {"tint": tint} if tint else {}
    for key, v in sprites_for(layer):
        if "segments" in v:
            img, _ = chain_at_rest(v)
            xs = [v["x"]]
            if key == "anemone_tentacle":
                continue
            for x in xs:
                put(frame, img, x, v["y"] + v["height"] - img.height + 16, **kw)
        elif key.startswith("shrimp_"):
            continue
        else:
            put(frame, rgba(v["file"]), v["x"], v["y"], **kw)


def anemone(frame: Image.Image, tint: tuple[int, int, int] | None) -> None:
    kw = {"tint": tint} if tint else {}
    body = P["anemone_body"]
    put(frame, rgba(body["file"]), body["x"], body["y"], **kw)
    tent, px = chain_at_rest(P["anemone_tentacle"])
    for i in range(6):
        x = body["x"] + 70 + i * 34
        put(frame, tent, x - px, body["y"] - tent.height + 60 + (i % 2) * 12, **kw)


def fish(frame: Image.Image, tint: tuple[int, int, int] | None, lane_tint: tuple[int, int, int], lane: list[tuple[str, int, int]], scale: float) -> None:
    t = lane_tint if tint is None else tuple(round(a * b / 255) for a, b in zip(lane_tint, tint, strict=True))
    for sp, x, y in lane:
        put(frame, fish_at_rest(sp), x, y, scale=scale, tint=t)  # type: ignore[arg-type]


def mockup(night: bool) -> Image.Image:
    tint = NIGHT_TINT if night else None
    kw = {"tint": tint} if tint else {}
    frame = Image.new("RGBA", (W, H), (11, 47, 85, 255))
    put(frame, rgba("decor/reef_backdrop.png"), -313, 0, **kw)
    if night:
        for key, v in P.items():
            if key.startswith("glow_backdrop_"):
                put(frame, rgba(v["file"]), v["x"], v["y"], scale=2.0, opacity=0.8)
        put(frame, rgba("night/moon_shaft_a.png"), 520, -4, tint=(170, 200, 255), opacity=0.55)
        put(frame, rgba("night/moon_shaft_b.png"), 1300, -4, tint=(170, 200, 255), opacity=0.45)
    else:
        put(frame, rgba("fx/shaft_day_a.png"), 360, -4, tint=(255, 238, 196), opacity=0.7)
        put(frame, rgba("fx/shaft_day_b.png"), 1160, -4, tint=(255, 238, 196), opacity=0.6)
    fish(frame, tint, (0x9F, 0xB8, 0xD2), [("royal_blue_tang", 330, 360), ("green_chromis", 1500, 300), ("green_chromis", 1560, 330)], 0.6)
    draw_layer(frame, "midCoral", tint)
    if night:
        for key, v in P.items():
            if key.startswith("glow_mid_coral_"):
                put(frame, rgba(v["file"]), v["x"], v["y"], scale=2.0, opacity=0.85)
    fish(frame, tint, (0xD2, 0xE0, 0xEE), [("moorish_idol", 1180, 360), ("royal_gramma", 260, 600)], 0.8)
    draw_layer(frame, "frontCoral", tint)
    anemone(frame, tint)
    if night:
        for key, v in P.items():
            if key.startswith("glow_front_coral_"):
                put(frame, rgba(v["file"]), v["x"], v["y"], scale=2.0, opacity=0.85)
    fish(frame, tint, (255, 255, 255), [("yellow_tang", 640, 430), ("ocellaris_clownfish", 1200, 600)], 1.0)
    s = P["shrimp_r"]
    put(frame, rgba(s["body"]), s["x"], s["y"], **kw)
    put(frame, rgba(s["antennae"]), s["x"], s["y"], **kw)
    for key in ("crab", "starfish"):
        v = P[key]
        put(frame, rgba(v["file"]), v["x"], v["y"], **kw)
    draw_layer(frame, "foreground", tint)
    # Caustics clipped to the sand band (a clippingRect Group on the device).
    band = Image.new("RGBA", (W, 160), (0, 0, 0, 0))
    for name, op, off in (("caustic_a", 0.30, 0), ("caustic_b", 0.22, 200)):
        c = tinted(rgba(f"fx/{name}.png"), opacity=op * (0.35 if night else 1.0))
        tiled = Image.new("RGBA", (W + 512, 512), (0, 0, 0, 0))
        for tx in range(0, W + 512, 512):
            tiled.alpha_composite(c, (tx, 0))
        band.alpha_composite(tiled.crop((off, off, off + W, off + 160)))
    frame.alpha_composite(band, (0, 920))
    rip = tinted(rgba("fx/ripple.png"), tint=(120, 150, 200) if night else (225, 245, 255), opacity=0.35 if night else 0.6)
    put(frame, rip, 0, 0)
    if night:
        sp = rgba("night/sparkle.png")
        rng = np.random.default_rng(23)
        for _ in range(30):
            x, y = rng.uniform(0, W), rng.uniform(80, 900)
            put(frame, sp, x, y, scale=float(rng.uniform(0.5, 1.0)), tint=(150, 255, 230), opacity=float(rng.uniform(0.4, 1.0)))
    return frame.convert("RGB")


# ---------------------------------------------------------------- contact sheets


def checker(w: int, h: int, cell: int = 12) -> Image.Image:
    ys, xs = np.mgrid[0:h, 0:w]
    v = np.where(((xs // cell) + (ys // cell)) % 2 == 0, 200, 150).astype(np.uint8)
    return Image.fromarray(np.dstack([v, v, v, np.full_like(v, 255)]))


def contact(items: list[tuple[str, Image.Image]], out: Path, title: str, night: bool = False) -> None:
    cw, ch = 340, 280
    per_row = 3
    rows = math.ceil(len(items) / per_row)
    sheet = Image.new("RGB", (per_row * (2 * cw + 30) + 20, rows * (ch + 30) + 50), (24, 24, 30))
    d = ImageDraw.Draw(sheet)
    d.text((20, 14), title, fill=(240, 240, 240))
    back = rgba("decor/reef_backdrop.png").crop((700, 300, 700 + 2 * cw, 300 + 2 * ch)).resize((cw, ch))
    if night:
        back = tinted(back, tint=NIGHT_TINT)
    for i, (label, img) in enumerate(items):
        x = 20 + (i % per_row) * (2 * cw + 30)
        y = 40 + (i // per_row) * (ch + 30)
        thumb = img.copy()
        thumb.thumbnail((cw - 8, ch - 8), Image.Resampling.LANCZOS)
        for j, bg in enumerate((checker(cw, ch), back.copy())):
            bg.alpha_composite(thumb, ((cw - thumb.width) // 2, (ch - thumb.height) // 2))
            sheet.paste(bg.convert("RGB"), (x + j * cw, y + 14))
        d.text((x, y), f"{label}  {img.width}x{img.height}", fill=(230, 230, 230))
    sheet.save(out, format="PNG", optimize=False, compress_level=9)


def assembled(card: str) -> list[tuple[str, Image.Image]]:
    """Chunked sprites reassembled per group (as they sit in the scene), others as is."""
    groups: dict[str, list[dict[str, Any]]] = {}
    for k, v in P.items():
        if v.get("card") != card or "file" not in v:
            continue
        g = v.get("group") or (k.rsplit("_", 1)[0] if k.startswith("glow_") else k)
        groups.setdefault(g, []).append(v)
    out = []
    for g, items in groups.items():
        x0 = min(v["x"] for v in items)
        y0 = min(v["y"] for v in items)
        sc = items[0].get("scale", 1.0)
        x1 = max(v["x"] + round(v["width"] * sc) for v in items)
        y1 = max(v["y"] + round(v["height"] * sc) for v in items)
        canvas = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
        for v in items:
            im = rgba(v["file"])
            if sc != 1.0:
                im = im.resize((round(im.width * sc), round(im.height * sc)), Image.Resampling.BILINEAR)
            canvas.alpha_composite(im, (v["x"] - x0, v["y"] - y0))
        label = g if len(items) == 1 else f"{g} ({len(items)} chunks)"
        out.append((label, canvas))
    return out


def sheets() -> None:
    decor = assembled("P1.7")
    contact(decor, DOCS / "contact-decor.png", "P1.7 decor (left: checkerboard, right: on the reef backdrop)")
    night = assembled("P3.7")
    night = [
        ("moon_shaft_a", tinted(rgba("night/moon_shaft_a.png"), tint=(170, 200, 255))),
        ("moon_shaft_b", tinted(rgba("night/moon_shaft_b.png"), tint=(170, 200, 255))),
        ("shaft_day_a", tinted(rgba("fx/shaft_day_a.png"), tint=(255, 238, 196))),
        ("shaft_day_b", tinted(rgba("fx/shaft_day_b.png"), tint=(255, 238, 196))),
        ("sparkle (x4)", rgba("night/sparkle.png").resize((128, 128), Image.Resampling.NEAREST)),
        *night,
    ]
    contact(night, DOCS / "contact-night.png", "P3.7 night art (shafts shown tinted as blendColor would; right: night-tinted backdrop)", night=True)
    extras: list[tuple[str, Image.Image]] = []
    for k, v in P.items():
        if v.get("card") != "P4.6":
            continue
        if "segments" in v:
            extras.append((f"{k} (segments at rest)", chain_at_rest(v)[0]))
            extras += [(Path(s["file"]).stem, rgba(s["file"])) for s in v["segments"]]
        elif k.startswith("shrimp_"):
            body, ant = rgba(v["body"]), rgba(v["antennae"])
            both = body.copy()
            both.alpha_composite(ant)
            extras += [(k, both), (f"{k} antennae layer", ant)]
        else:
            extras.append((k, rgba(v["file"])))
    extras += [
        ("caustic_a", rgba("fx/caustic_a.png")),
        ("caustic_b", rgba("fx/caustic_b.png")),
        ("ripple (left 640 px)", rgba("fx/ripple.png").crop((0, 0, 640, 128))),
    ]
    contact(extras, DOCS / "contact-extras.png", "P4.6 reef extras (left: checkerboard, right: on the reef backdrop)")


# ---------------------------------------------------------------- overdraw and budget


def rects(night: bool, dx: float, parallax: dict[str, float]) -> list[tuple[str, int, int, int, int]]:
    out = []
    for k, v in P.items():
        layer = v.get("layer")
        if layer in ("frontLane",):
            continue
        if k.startswith("glow_") and not night:
            continue
        off = dx * parallax.get(layer, 1.0)
        sc = v.get("scale", 1.0)
        if "segments" in v:
            out.append((k, round(v["x"] + off), v["y"], v["segments"][0]["width"], v["height"]))
        elif "width" in v:
            out.append((k, round(v["x"] + off), v["y"], round(v["width"] * sc), round(v["height"] * sc)))
    shafts = (("moon_a", 520, 256), ("moon_b", 1300, 256)) if night else (("day_a", 360, 256), ("day_b", 1160, 256))
    for name, x, w in shafts:
        out.append((name, round(x + dx * parallax["lightShafts"]), 0, w, 1088))
    out += [("caustic_a", 0, 920, W, 160), ("caustic_b", 0, 920, W, 160), ("ripple", 0, 0, W, 128)]
    return out


def overdraw() -> None:
    scene = json.loads((ROOT / "config" / "scene.json").read_text())
    par = {layer["id"]: layer["parallax"] for layer in scene["layers"]}
    for night in (False, True):
        worst = np.zeros((H, W), np.int32)
        eq = []
        for dx in (-320.0, 0.0, 320.0):
            cnt = np.zeros((H, W), np.int32)
            for _, x, y, w, h in rects(night, dx, par):
                x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
                if x1 > x0 and y1 > y0:
                    cnt[y0:y1, x0:x1] += 1
            worst = np.maximum(worst, cnt)
            eq.append(cnt.sum() / (W * H))
        label = "night" if night else "day"
        hist = {int(n): round(float((worst == n).mean()) * 100, 1) for n in np.unique(worst)}
        print(f"overdraw {label}: max {worst.max()} layers over the backdrop, full-screen equivalents per frame {', '.join(f'{e:.2f}' for e in eq)} (dx -320, 0, +320); % of screen by count {hist}")
        colors = np.array([[20, 20, 30], [40, 90, 160], [60, 170, 90], [230, 200, 50], [230, 110, 40], [220, 40, 40], [255, 0, 255]], np.uint8)
        img = Image.fromarray(colors[np.clip(worst, 0, 6)]).resize((960, 540), Image.Resampling.NEAREST)
        dr = ImageDraw.Draw(img)
        dr.text((8, 8), f"{label}: Poster rectangles per pixel over the backdrop, worst of drift -320/0/+320. 0 dark, 1 blue, 2 green, 3 yellow, 4 orange, 5 red", fill=(255, 255, 255))
        img.save(DOCS / f"overdraw-{label}.png", format="PNG", optimize=False, compress_level=9)


def padded_mb(path: Path) -> float:
    with Image.open(path) as im:
        w, h = im.size
    return math.ceil(w / 32) * 32 * math.ceil(h / 32) * 32 * 4 / 1e6


GROUPS: list[tuple[str, list[str], float]] = [
    ("Mid and front coral strips", ["decor/mid_coral_*.png", "decor/front_coral_*.png", "decor/rock_pillar.png", "decor/coral_acropora.png"], 11.5),
    ("Foreground sand lip and plants", ["decor/sand_lip.png", "decor/sand_tuft_*.png", "decor/plant_cluster.png"], 3.6),
    ("Anemone, soft coral, invertebrates (this batch)", ["extras/*.png"], 6.0),
    ("Day light shafts", ["fx/shaft_day_*.png"], 4.5),
    ("Night: moon shafts, coral glow masks", ["night/moon_shaft_*.png", "night/glow_*.png", "decor/coral_acropora_glowmask.png"], 10.5),
    ("Caustic and ripple tiles", ["fx/caustic_*.png", "fx/ripple.png"], 3.1),
    ("Sparkles (this batch)", ["night/sparkle.png"], 0.5),
]


def budget() -> None:
    total = 0.0
    for name, globs, allow in GROUPS:
        files = sorted({p for g in globs for p in IMG.glob(g)})
        mb = sum(padded_mb(p) for p in files)
        total += mb
        print(f"budget {name}: {mb:.2f} MB of {allow} ({len(files)} files)")
        for p in files:
            with Image.open(p) as im:
                print(f"    {p.relative_to(ROOT)} {im.width}x{im.height} {padded_mb(p):.3f}")
    print(f"budget total for these groups: {total:.2f} MB")


def main() -> int:
    budget()
    overdraw()
    sheets()
    mockup(False).save(DOCS / "mockup-day.png", format="PNG", optimize=False, compress_level=9)
    mockup(True).save(DOCS / "mockup-night.png", format="PNG", optimize=False, compress_level=9)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
