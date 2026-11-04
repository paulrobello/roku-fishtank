# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.2"]
# ///
"""Reef Tank art rig pipeline: approved cutouts -> Roku-ready layered sprites.

Run from anywhere: ``uv run tools/art/rig.py`` (``make art``).

Fish (``config/species/*.json``, generated ``*.rig.json`` skipped):
  1. Trim the source cutout to its alpha bbox.
  2. Split it at source resolution into three registered full-canvas layers:
     - tail: alpha ramps 1 -> 0 across [cut - feather/2, cut + feather/2].
     - body: starts ``overlap`` px on the tail side of the cut and ramps 0 -> 1
       over feather/2. The ramp ends before the tail ramp begins, so at rest
       (tail over body) the composite reproduces the source exactly, and when the
       tail rotates the body's stalk stays underneath to hide any gap.
     - fin: the pectoral-fin polygon (edge-feathered), drawn over the body. The
       fin pixels are removed from the body and the hole is filled by diffusion
       from the surrounding body pixels, so a flapping fin uncovers flank, not a
       ghost copy of itself.
  3. Scale every layer by the same factor (displayed length == display_length_px
     at 1080p) with premultiplied Lanczos, crop each tight, and bleed edge colour
     into fully transparent pixels so bilinear sampling on device has no dark rim.
  4. Write ``images/fish/<species>_{body,tail,fin}.png``,
     ``config/species/<species>.rig.json`` (offsets and pivots in the body
     Poster's local coordinates at display size) and the rig check render
     ``docs/art/rig-check-<species>.png``.

Optional species config keys (absent keys leave the output byte-identical):
  - ``fin.fill_axis: "vertical"``: rebuild the flank under the fin by
    interpolating down each column, which continues vertical bands (clownfish,
    lionfish) instead of smearing them.
  - ``fin.underlay_polygon``: for a fin that reaches past the body outline
    (lionfish pectoral fan). Inside the polygon the flank is rebuilt; elsewhere
    under the fin the body alpha is removed, so open water shows when it swings.
  - ``extra_fins``: list of additional swinging layers (lionfish dorsal spines),
    each ``{name, polygon, pivot, swing_deg, feather_px?, underlay_polygon?,
    fill_seed_min_value?, z_after?}``. Each is cut from the body the same way
    and written as ``images/fish/<species>_<name>.png``.

Rig JSON: ``layers.{body,tail,fin}``, ``z_order`` and the other existing fields
never change meaning. Species with ``extra_fins`` additionally get
``extra_layers`` (ordered list; each entry has the per-layer fields of
``layers`` plus ``name`` and ``z_after``, the layer it draws directly above)
and ``draw_order`` (the full back-to-front list including extras). A consumer
that ignores both still draws a correct rest pose minus the extra layers.

Decor (``config/decor/*.json``): ``backdrop`` layers are scaled to target_height;
``sprite`` layers are trimmed, scaled, and get an optional glow-mask stub.

Output is deterministic: fixed resampling filters, no PNG metadata chunks,
sorted JSON.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import numpy as np
from numpy.typing import NDArray
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SPECIES_DIR = ROOT / "config" / "species"
DECOR_DIR = ROOT / "config" / "decor"
FISH_OUT = ROOT / "images" / "fish"
DECOR_OUT = ROOT / "images" / "decor"
DOCS_OUT = ROOT / "docs" / "art"

ALPHA_DUST = 3  # alpha below this after resampling is zeroed (Lanczos ringing).
SOURCE_HAZE = 8  # source alpha below this is zeroed: the generators leave alpha-1 haze out to the border.
BLEED_PX = 4  # transparent-pixel colour bleed distance at display size.
CHECK_BG = (12, 32, 72, 255)  # dark blue, matches the style-board contact sheet.
CHECK_ZOOM = 3
CHECK_PAD = 24

Float = NDArray[np.float32]
Bool = NDArray[np.bool_]

cost_rows: list[tuple[str, int, int]] = []


def save_png(img: Image.Image, path: Path) -> None:
    """Save a PNG with no metadata so reruns are byte-identical."""
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=False, compress_level=9)


def record_cost(path: Path, img: Image.Image) -> None:
    cost_rows.append((str(path.relative_to(ROOT)), img.width, img.height))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def to_float(img: Image.Image) -> Float:
    return np.asarray(img.convert("RGBA"), dtype=np.float32) / 255.0


def load_cutout(path: Path) -> Float:
    """Load an RGBA cutout with sub-threshold alpha haze removed."""
    arr = to_float(Image.open(path))
    arr[arr[..., 3] < SOURCE_HAZE / 255.0] = 0.0
    return arr


def to_image(arr: Float) -> Image.Image:
    return Image.fromarray(np.clip(np.rint(arr * 255.0), 0, 255).astype(np.uint8))


def alpha_bbox(alpha: NDArray[Any], threshold: float = 0) -> tuple[int, int, int, int]:
    """Return (x0, y0, x1, y1), exclusive end, of pixels with alpha > threshold."""
    ys, xs = np.nonzero(alpha > threshold)
    if xs.size == 0:
        raise ValueError("image has no visible pixels")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def ramp(x: Float, x0: float, x1: float) -> Float:
    """Linear 0 -> 1 between x0 and x1."""
    return np.clip((x - x0) / (x1 - x0), 0.0, 1.0).astype(np.float32)


def resize_premultiplied(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Lanczos resize in premultiplied alpha so transparent RGB does not bleed in."""
    return img.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")


def neighbour_fill(rgb: Float, known: Bool, todo: Bool, max_iter: int) -> Float:
    """Onion-peel fill: each pass sets todo pixels touching known ones to their mean."""
    rgb = rgb.copy()
    known = known.copy()
    todo = todo & ~known
    h, w = known.shape
    for _ in range(max_iter):
        if not todo.any():
            break
        k = known.astype(np.float32)
        prgb = np.pad(rgb * k[..., None], ((1, 1), (1, 1), (0, 0)))
        pk = np.pad(k, 1)
        acc = np.zeros_like(rgb)
        cnt = np.zeros((h, w), dtype=np.float32)
        for dy in (0, 1, 2):
            for dx in (0, 1, 2):
                if dy == 1 and dx == 1:
                    continue
                acc += prgb[dy : dy + h, dx : dx + w]
                cnt += pk[dy : dy + h, dx : dx + w]
        new = todo & (cnt > 0)
        rgb[new] = acc[new] / cnt[new][:, None]
        known = known | new
        todo = todo & ~new
    return rgb


def smooth_region(rgb: Float, region: Bool, iterations: int) -> Float:
    """Jacobi relaxation inside ``region`` with the surroundings held fixed."""
    rgb = rgb.copy()
    h, w = region.shape
    for _ in range(iterations):
        p = np.pad(rgb, ((1, 1), (1, 1), (0, 0)), mode="edge")
        avg = (p[0:h, 1 : w + 1] + p[2 : h + 2, 1 : w + 1] + p[1 : h + 1, 0:w] + p[1 : h + 1, 2 : w + 2]) / 4.0
        rgb[region] = avg[region]
    return rgb


def column_fill(rgb: Float, seed: Bool, todo: Bool) -> Float:
    """Interpolate todo pixels down each column between the nearest seeds.

    Continues vertical stripes (lionfish bands) across a fin hole, where the
    isotropic diffusion fill would smear them into a flat patch. Columns with
    no seed keep the input fill.
    """
    rgb = rgb.copy()
    for x in range(rgb.shape[1]):
        ys = np.nonzero(seed[:, x])[0]
        rows = np.nonzero(todo[:, x])[0]
        if ys.size == 0 or rows.size == 0:
            continue
        for c in range(3):
            rgb[rows, x, c] = np.interp(rows, ys, rgb[ys, x, c])
    return rgb


def finish_sprite(arr: Float) -> tuple[Image.Image, tuple[int, int]]:
    """Zero alpha dust, crop tight, bleed colour into transparent pixels.

    Returns the cropped image and its (x, y) origin in the input canvas.
    """
    arr = arr.copy()
    arr[arr[..., 3] < ALPHA_DUST / 255.0] = 0.0
    x0, y0, x1, y1 = alpha_bbox(arr[..., 3])
    arr = arr[y0:y1, x0:x1]
    visible = arr[..., 3] > 0
    arr[..., :3] = neighbour_fill(arr[..., :3], visible, ~visible, BLEED_PX)
    return to_image(arr), (x0, y0)


# ---------------------------------------------------------------- fish rigs


def rig_species(cfg_path: Path) -> None:
    cfg: dict[str, Any] = json.loads(cfg_path.read_text(encoding="utf-8"))
    name: str = cfg["species"]
    if cfg.get("facing", "right") != "right":
        raise ValueError(f"{name}: only right-facing sources are supported")
    src_arr = load_cutout(ROOT / cfg["source"])

    bx0, by0, bx1, by1 = alpha_bbox(src_arr[..., 3])
    trim = src_arr[by0:by1, bx0:bx1]
    th, tw = trim.shape[:2]
    length = int(cfg["display_length_px"])
    scale = length / tw
    disp_size = (length, max(1, round(th * scale)))

    tail_cfg: dict[str, Any] = cfg["tail"]
    if "cut_x_px" in tail_cfg:
        cut = float(tail_cfg["cut_x_px"]) - bx0
    else:
        cut = float(tail_cfg["cut_x_frac"]) * tw
    feather = float(tail_cfg["feather_px"])
    overlap = float(tail_cfg["overlap_px"])
    if overlap < feather:
        raise ValueError(f"{name}: overlap_px must be >= feather_px so the seams do not cross")
    col = np.nonzero(trim[:, round(cut), 3] > 0.5)[0]
    pivot_y = float(tail_cfg.get("pivot_y_px", (col.min() + col.max() + 1) / 2.0 + by0)) - by0

    xs = np.arange(tw, dtype=np.float32)[None, :]
    tail_w = 1.0 - ramp(xs, cut - feather / 2, cut + feather / 2)
    body_w = ramp(xs, cut - overlap, cut - overlap + feather / 2)

    fin_cfg: dict[str, Any] = cfg["fin"]
    fin_mask_img = Image.new("L", (tw, th), 0)
    poly = [(float(x) - bx0, float(y) - by0) for x, y in fin_cfg["polygon"]]
    ImageDraw.Draw(fin_mask_img).polygon(poly, fill=255)
    fin_feather = float(fin_cfg.get("feather_px", 0))
    if fin_feather > 0:
        fin_mask_img = fin_mask_img.filter(ImageFilter.GaussianBlur(fin_feather / 2))
    fin_w = np.asarray(fin_mask_img, dtype=np.float32) / 255.0

    def layer(weight: Float) -> Image.Image:
        arr = trim.copy()
        arr[..., 3] *= np.broadcast_to(weight, arr.shape[:2])
        return resize_premultiplied(to_image(arr), disp_size)

    tail_d = to_float(layer(tail_w))
    body_d = to_float(layer(np.broadcast_to(body_w, (th, tw)).copy()))
    fin_d = to_float(layer(fin_w))

    # Remove the fin from the body: fill every pixel the fin touches from the
    # surrounding flank, then relax it so the patch has no streaks.
    fin_disp_mask = np.asarray(fin_mask_img.resize(disp_size, Image.Resampling.BILINEAR), dtype=np.float32) / 255.0
    hole = (fin_disp_mask > 0.02) & (body_d[..., 3] > 0)
    grown = np.asarray(Image.fromarray((hole * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)), dtype=np.uint8) > 0
    # Seed only from bright flank pixels so the black stripe and the fin's dark
    # outline do not bleed into the patch; everything else is filled and relaxed.
    seed_min = float(fin_cfg.get("fill_seed_min_value", 0.35))
    seed = (body_d[..., 3] > 0.99) & ~grown & (body_d[..., :3].max(axis=-1) > seed_min)
    todo = (body_d[..., 3] > 0) & ~seed
    fill = neighbour_fill(body_d[..., :3], seed, todo, 10_000)
    fill = smooth_region(fill, todo, 60)
    if fin_cfg.get("fill_axis") == "vertical":
        fill = column_fill(fill, seed, todo)
    # Blend the fill in by fin coverage so pixels the fin only grazes keep their
    # own colour: the rest pose stays faithful outside the fin.
    w = np.clip(fin_disp_mask * 2.0, 0.0, 1.0)[..., None]
    body_d[..., :3] = body_d[..., :3] * (1.0 - w) + fill * w

    def disp_mask(polygon: list[list[float]], feather_px: float) -> tuple[Float, Float]:
        """Rasterise a source-pixel polygon: (source-res weight, display-res weight)."""
        img = Image.new("L", (tw, th), 0)
        ImageDraw.Draw(img).polygon([(float(x) - bx0, float(y) - by0) for x, y in polygon], fill=255)
        if feather_px > 0:
            img = img.filter(ImageFilter.GaussianBlur(feather_px / 2))
        src_w = np.asarray(img, dtype=np.float32) / 255.0
        return src_w, np.asarray(img.resize(disp_size, Image.Resampling.BILINEAR), dtype=np.float32) / 255.0

    # Optional: a pectoral fin that extends past the body outline into open water
    # (lionfish fan) keeps body alpha only inside its underlay polygon.
    if "underlay_polygon" in fin_cfg:
        _, fin_under = disp_mask(fin_cfg["underlay_polygon"], fin_feather)
        body_d[..., 3] *= 1.0 - fin_disp_mask * (1.0 - fin_under)

    # Extra fin layers (optional, e.g. lionfish spines and pectoral fans). Each is
    # cut out of the body: inside its underlay polygon the flank is rebuilt by
    # diffusion (the fin lies over the body), elsewhere the body alpha is removed
    # (the fin sticks out into open water), so a swinging fin leaves no ghost.
    extra_cfgs: list[dict[str, Any]] = cfg.get("extra_fins", [])
    extra_d: dict[str, Float] = {}
    for ecfg in extra_cfgs:
        ename = str(ecfg["name"])
        if ename in ("body", "tail", "fin") or ename in extra_d:
            raise ValueError(f"{name}: duplicate layer name {ename!r}")
        e_src, e_disp = disp_mask(ecfg["polygon"], float(ecfg.get("feather_px", 0)))
        extra_d[ename] = to_float(layer(e_src))
        if "underlay_polygon" in ecfg:
            _, under = disp_mask(ecfg["underlay_polygon"], float(ecfg.get("feather_px", 0)))
        else:
            under = np.zeros_like(e_disp)
        e_hole = (e_disp > 0.02) & (body_d[..., 3] > 0)
        e_grown = np.asarray(Image.fromarray((e_hole * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)), dtype=np.uint8) > 0
        e_seed = (body_d[..., 3] > 0.99) & ~e_grown & (body_d[..., :3].max(axis=-1) > float(ecfg.get("fill_seed_min_value", seed_min)))
        e_todo = (body_d[..., 3] > 0) & ~e_seed
        e_fill = smooth_region(neighbour_fill(body_d[..., :3], e_seed, e_todo, 10_000), e_todo, 60)
        e_w = np.clip(e_disp * 2.0, 0.0, 1.0)
        keep = e_w * under
        body_d[..., :3] = body_d[..., :3] * (1.0 - keep[..., None]) + e_fill * keep[..., None]
        body_d[..., 3] *= 1.0 - e_disp * (1.0 - under)

    layers: dict[str, tuple[Image.Image, tuple[int, int]]] = {
        "body": finish_sprite(body_d),
        "tail": finish_sprite(tail_d),
        "fin": finish_sprite(fin_d),
    }
    for ename, arr in extra_d.items():
        layers[ename] = finish_sprite(arr)
    body_origin = layers["body"][1]

    pivots_disp = {
        "tail": (cut * scale, pivot_y * scale),
        "fin": ((float(fin_cfg["pivot"][0]) - bx0) * scale, (float(fin_cfg["pivot"][1]) - by0) * scale),
    }
    for ecfg in extra_cfgs:
        pivots_disp[str(ecfg["name"])] = ((float(ecfg["pivot"][0]) - bx0) * scale, (float(ecfg["pivot"][1]) - by0) * scale)
    swing_by_layer: dict[str, Any] = {"tail": tail_cfg["swing_deg"], "fin": fin_cfg["swing_deg"]}
    swing_by_layer.update({str(e["name"]): e["swing_deg"] for e in extra_cfgs})

    draw_order = ["body", "tail", "fin"]
    for ecfg in extra_cfgs:
        after = str(ecfg.get("z_after", draw_order[-1]))
        if after not in draw_order:
            raise ValueError(f"{name}: z_after {after!r} names no earlier layer")
        draw_order.insert(draw_order.index(after) + 1, str(ecfg["name"]))

    rig_layers: dict[str, Any] = {}
    extra_entries: list[dict[str, Any]] = []
    total = 0
    for key, (img, (ox, oy)) in layers.items():
        out = FISH_OUT / f"{name}_{key}.png"
        save_png(img, out)
        record_cost(out, img)
        total += img.width * img.height * 4
        entry: dict[str, Any] = {
            "uri": f"pkg:/images/fish/{name}_{key}.png",
            "width": img.width,
            "height": img.height,
            "offset": [ox - body_origin[0], oy - body_origin[1]],
        }
        if key in pivots_disp:
            px, py = pivots_disp[key]
            entry["pivot"] = [round(px - ox, 2), round(py - oy, 2)]
            entry["swing_deg"] = swing_by_layer[key]
        if key in extra_d:
            entry["name"] = key
            entry["z_after"] = draw_order[draw_order.index(key) - 1]
            extra_entries.append(entry)
        else:
            rig_layers[key] = entry

    every = [*rig_layers.values(), *extra_entries]
    min_x = min(e["offset"][0] for e in every)
    min_y = min(e["offset"][1] for e in every)
    max_x = max(e["offset"][0] + e["width"] for e in every)
    max_y = max(e["offset"][1] + e["height"] for e in every)
    rig: dict[str, Any] = {
        "_generated": "by tools/art/rig.py from " + str(cfg_path.relative_to(ROOT)) + "; do not edit",
        "species": name,
        "display_length_px": length,
        "scale": round(scale, 6),
        "coordinate_space": "body Poster local pixels at display size; offset = Poster translation, pivot = scaleRotateCenter",
        "z_order": ["body", "tail", "fin"],
        "bounds": {"x": min_x, "y": min_y, "width": max_x - min_x, "height": max_y - min_y},
        "mirror_center": [round((min_x + max_x) / 2, 2), round((min_y + max_y) / 2, 2)],
        "layers": rig_layers,
        "texture_bytes": total,
    }
    if extra_entries:
        rig["extra_layers"] = extra_entries
        rig["draw_order"] = draw_order
    write_json(SPECIES_DIR / f"{name}.rig.json", rig)

    reference = resize_premultiplied(to_image(trim), disp_size)
    render_rig_check(name, rig, layers, reference, draw_order)


def compose(
    layers: dict[str, tuple[Image.Image, tuple[int, int]]],
    pivots: dict[str, tuple[float, float]],
    angles: dict[str, float],
    canvas: tuple[int, int],
    pad: int,
    order: list[str],
) -> Image.Image:
    """Composite layers in draw order, rotating swinging layers about their pivots."""
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    for key in order:
        img, (ox, oy) = layers[key]
        sheet = Image.new("RGBA", canvas, (0, 0, 0, 0))
        sheet.paste(img, (ox + pad, oy + pad))
        angle = angles.get(key, 0.0)
        if angle:
            px, py = pivots[key]
            sheet = (
                sheet.convert("RGBa")
                .rotate(angle, resample=Image.Resampling.BICUBIC, center=(px + ox + pad, py + oy + pad))
                .convert("RGBA")
            )
        out.alpha_composite(sheet)
    return out


def render_rig_check(
    name: str,
    rig: dict[str, Any],
    layers: dict[str, tuple[Image.Image, tuple[int, int]]],
    reference: Image.Image,
    order: list[str],
) -> None:
    pad = CHECK_PAD
    canvas = (reference.width + 2 * pad, reference.height + 2 * pad)
    entries: dict[str, Any] = {**rig["layers"], **{e["name"]: e for e in rig.get("extra_layers", [])}}
    pivots = {k: (float(v["pivot"][0]), float(v["pivot"][1])) for k, v in entries.items() if "pivot" in v}
    tail_swing = float(rig["layers"]["tail"]["swing_deg"])
    fin_swing = float(rig["layers"]["fin"]["swing_deg"])
    # Extra layers swing in phase with the pectoral fin, each by its own limit.
    extra_swing = {e["name"]: float(e["swing_deg"]) for e in rig.get("extra_layers", [])}

    rest = compose(layers, pivots, {}, canvas, pad, order)
    ref_canvas = Image.new("RGBA", canvas, (0, 0, 0, 0))
    ref_canvas.paste(reference, (pad, pad))
    diff = np.abs(to_float(rest) - to_float(ref_canvas)) * to_float(ref_canvas)[..., 3:4]
    print(f"  {name}: rest pose vs source max|d|={diff.max() * 255:.1f}/255 mean={diff.mean() * 255:.3f}/255")

    # Row 1: source, then fin -swing; row 2: rig at rest, then fin +swing.
    tiles: list[tuple[str, Image.Image]] = []
    for fin_a, first in ((-fin_swing, ("source (scaled)", ref_canvas)), (fin_swing, ("rig at rest", rest))):
        tiles.append(first)
        for tail_a in (-tail_swing, 0.0, tail_swing):
            angles = {"tail": tail_a, "fin": fin_a, **{k: s * np.sign(fin_a) for k, s in extra_swing.items()}}
            tiles.append((f"tail {tail_a:+.0f}  fin {fin_a:+.0f}", compose(layers, pivots, angles, canvas, pad, order)))

    cols = 4
    tw, th = canvas[0] * CHECK_ZOOM, canvas[1] * CHECK_ZOOM
    label_h = 28
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * tw, rows * (th + label_h)), CHECK_BG)
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=20)
    for i, (label, tile) in enumerate(tiles):
        bg = Image.new("RGBA", canvas, CHECK_BG)
        bg.alpha_composite(tile)
        x, y = (i % cols) * tw, (i // cols) * (th + label_h)
        sheet.paste(bg.resize((tw, th), Image.Resampling.NEAREST), (x, y + label_h))
        draw.text((x + 8, y + 4), label, fill=(230, 230, 230, 255), font=font)
    out = DOCS_OUT / f"rig-check-{name}.png"
    save_png(sheet.convert("RGB"), out)
    print(f"  wrote {out.relative_to(ROOT)}")


# ---------------------------------------------------------------- decor


def smoothstep(x: Float, e0: float, e1: float) -> Float:
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return (t * t * (3.0 - 2.0 * t)).astype(np.float32)


def build_decor(cfg_path: Path) -> None:
    cfg: dict[str, Any] = json.loads(cfg_path.read_text(encoding="utf-8"))
    name: str = cfg["name"]
    kind: str = cfg["kind"]
    target_h = int(cfg["target_height"])
    src = Image.open(ROOT / cfg["source"])

    if kind == "backdrop":
        rgb = src.convert("RGB")
        size = (round(rgb.width * target_h / rgb.height), target_h)
        out_img = rgb.resize(size, Image.Resampling.LANCZOS)
        out = DECOR_OUT / f"{name}.png"
        save_png(out_img, out)
        record_cost(out, out_img)
        return
    if kind != "sprite":
        raise ValueError(f"{name}: unknown decor kind {kind!r}")

    arr = load_cutout(ROOT / cfg["source"])
    x0, y0, x1, y1 = alpha_bbox(arr[..., 3])
    trimmed = to_image(arr[y0:y1, x0:x1])
    size = (max(1, round(trimmed.width * target_h / trimmed.height)), target_h)
    scaled = to_float(resize_premultiplied(trimmed, size))
    sprite, origin = finish_sprite(scaled)
    out = DECOR_OUT / f"{name}.png"
    save_png(sprite, out)
    record_cost(out, sprite)

    glow_cfg: dict[str, Any] | None = cfg.get("glowmask")
    if glow_cfg:
        # Same crop as the sprite so the mask overlays it at the same translation.
        w, h = sprite.size
        crop = scaled[origin[1] : origin[1] + h, origin[0] : origin[0] + w]
        hsv = np.asarray(to_image(crop).convert("RGB").convert("HSV"), dtype=np.float32) / 255.0
        soft = float(glow_cfg["softness"])
        glow = (
            crop[..., 3]
            * smoothstep(hsv[..., 2], float(glow_cfg["min_value"]), float(glow_cfg["min_value"]) + soft)
            * smoothstep(hsv[..., 1], float(glow_cfg["min_saturation"]), float(glow_cfg["min_saturation"]) + soft)
        )
        mask = np.ones((h, w, 4), dtype=np.float32)
        mask[..., 3] = glow
        mask_img = to_image(mask)
        gout = DECOR_OUT / f"{name}_glowmask.png"
        save_png(mask_img, gout)
        record_cost(gout, mask_img)


# ---------------------------------------------------------------- main


def main() -> int:
    species = sorted(p for p in SPECIES_DIR.glob("*.json") if not p.name.endswith(".rig.json"))
    decor = sorted(DECOR_DIR.glob("*.json"))
    for p in species:
        print(f"rig {p.relative_to(ROOT)}")
        rig_species(p)
    for p in decor:
        print(f"decor {p.relative_to(ROOT)}")
        build_decor(p)

    print("\ntexture memory (w x h x 4 bytes):")
    total = 0
    for path, w, h in cost_rows:
        b = w * h * 4
        total += b
        print(f"  {path:<44} {w:>5} x {h:<5} {b:>11,} B  {b / 1048576:7.2f} MiB")
    print(f"  {'total':<44} {'':>13} {total:>11,} B  {total / 1048576:7.2f} MiB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
