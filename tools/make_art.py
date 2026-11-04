"""Generate the placeholder fish sprites images/fish_orange.png and fish_blue.png.

Run from the repo root: python3 tools/make_art.py (make art-placeholder)
Programmatic placeholder quality, from the original test channel. P1.5 reuses them
as lane fish until the rigged species arrive; icons and splashes come from
tools/art/key_art.py.
"""
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "images")


def draw_fish(body, fin, tail, eye=True):
    """240x140 fish facing right, transparent background."""
    img = Image.new("RGBA", (240, 140), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # tail
    d.polygon([(55, 70), (5, 38), (18, 70), (5, 102)], fill=tail)
    # body
    d.ellipse([(50, 34), (196, 106)], fill=body)
    # dorsal fin
    d.polygon([(95, 36), (130, 12), (150, 38)], fill=fin)
    # belly fin
    d.polygon([(105, 104), (120, 128), (140, 104)], fill=fin)
    if eye:
        d.ellipse([(168, 54), (186, 72)], fill=(240, 240, 240))
        d.ellipse([(174, 60), (184, 70)], fill=(10, 10, 10))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    orange = draw_fish((242, 130, 48), (250, 180, 60), (230, 110, 30))
    blue = draw_fish((64, 120, 216), (110, 160, 235), (48, 95, 190))
    orange.save(os.path.join(OUT, "fish_orange.png"))
    blue.save(os.path.join(OUT, "fish_blue.png"))
    print("art written to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
