# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0"]
# ///
"""Reef Tank icon and splash art, derived from the approved backdrop and fish rigs.

Run from anywhere: ``uv run tools/art/key_art.py`` (``make key-art``). The output is
byte-reproducible (no randomness, no fonts, no PNG metadata).

Inputs (all already in the repo):
  - images/decor/reef_backdrop.png and the decor placements in config/scene.json
  - images/fish/<species>_{body,tail,fin}.png posed at rest from config/species/*.rig.json

Outputs (sizes from the Roku channel manifest spec, see RESEARCH.md §1):
  - images/splash_fhd.png 1920x1080: the scene's first frame (backdrop centred as in
    scene.json, decor placed as in scene.json) with two fish added.
  - images/splash_hd.png 1280x720: splash_fhd downsampled.
  - images/icon_fhd.png 540x405 (mm_icon_focus_fhd): a 4:3 crop of the backdrop
    around the rock arch with a yellow tang in front.
  - images/icon_hd.png 290x218 (mm_icon_focus_hd): icon_fhd downsampled.
No Roku branding and no text.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
IMAGES = ROOT / "images"


def pkg_path(uri: str) -> Path:
    assert uri.startswith("pkg:/"), uri
    return ROOT / uri[len("pkg:/") :]


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as img:
        return img.convert("RGBA")


def fish_at_rest(species: str) -> Image.Image:
    """Composite the rig layers in z order at their rest offsets (body-local pixels)."""
    rig = json.loads((ROOT / "config" / "species" / f"{species}.rig.json").read_text())
    b = rig["bounds"]
    canvas = Image.new("RGBA", (b["width"], b["height"]), (0, 0, 0, 0))
    for name in rig["z_order"]:
        layer = rig["layers"][name]
        part = load_rgba(pkg_path(layer["uri"]))
        if part.size != (layer["width"], layer["height"]):
            part = part.resize((layer["width"], layer["height"]), Image.Resampling.LANCZOS)
        ox, oy = layer["offset"]
        canvas.alpha_composite(part, (int(ox - b["x"]), int(oy - b["y"])))
    return canvas


def place(dst: Image.Image, sprite: Image.Image, x: float, y: float, scale: float = 1.0) -> None:
    if scale != 1.0:
        size = (round(sprite.width * scale), round(sprite.height * scale))
        sprite = sprite.resize(size, Image.Resampling.LANCZOS)
    dst.alpha_composite(sprite, (round(x), round(y)))


def scene_frame() -> Image.Image:
    """The ReefTank first frame at 1920x1080: decor placed exactly as scene.json says."""
    scene = json.loads((ROOT / "config" / "scene.json").read_text())
    w, h = scene["design"]["width"], scene["design"]["height"]
    frame = Image.new("RGBA", (w, h), (11, 47, 85, 255))
    order = [layer["id"] for layer in scene["layers"]]
    for d in sorted(scene["decor"], key=lambda d: order.index(d["layer"])):
        art = load_rgba(pkg_path(d["uri"]))
        if art.size != (d["width"], d["height"]):
            art = art.resize((d["width"], d["height"]), Image.Resampling.LANCZOS)
        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        layer.paste(art, (d["x"], d["y"]))
        frame.alpha_composite(layer)
    return frame


def save(img: Image.Image, name: str) -> None:
    img.convert("RGB").save(IMAGES / name, format="PNG", optimize=False, compress_level=9)
    print(f"wrote images/{name} {img.width}x{img.height}")


def main() -> int:
    tang = fish_at_rest("yellow_tang")
    blue = fish_at_rest("royal_blue_tang")

    splash = scene_frame()
    place(splash, blue, 1240, 300)
    place(splash, tang, 760, 470, 1.15)
    save(splash, "splash_fhd.png")
    save(splash.resize((1280, 720), Image.Resampling.LANCZOS), "splash_hd.png")

    # 4:3 crop around the rock arch (backdrop pixels 470..1190 x 160..700), then 540x405.
    backdrop = load_rgba(IMAGES / "decor" / "reef_backdrop.png")
    icon = backdrop.crop((470, 160, 1190, 700)).resize((540, 405), Image.Resampling.LANCZOS)
    place(icon, tang, 150, 110, 1.15)
    save(icon, "icon_fhd.png")
    save(icon.resize((290, 218), Image.Resampling.LANCZOS), "icon_hd.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
