"""Generate placeholder art for the Fishtank Test channel.

Run from the repo root: python3 tools/make_art.py
Outputs into images/. All art is programmatic placeholder quality — good enough
to prove the screensaver pipeline; the real build replaces these.
"""
import os
import random

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "images")
random.seed(42)

WATER = (6, 43, 69)
WATER_DEEP = (3, 25, 43)
SAND = (184, 155, 110)


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


def draw_pebbles(width=1280, height=160):
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, height - 70, width, height], fill=SAND + (255,))
    stones = [
        (120, 105, 92), (150, 130, 110), (96, 88, 82),
        (170, 150, 120), (88, 84, 80), (140, 118, 96),
    ]
    x = -20
    while x < width:
        w = random.randint(40, 90)
        h = random.randint(26, 52)
        y = height - 40 - h + random.randint(0, 18)
        c = random.choice(stones)
        d.ellipse([x, y, x + w, y + h], fill=c + (255,))
        # simple top highlight
        d.ellipse([x + 6, y + 4, x + w - 6, y + h // 2], fill=tuple(min(v + 18, 255) for v in c) + (160,))
        x += w - random.randint(4, 18)
    return img


def vertical_gradient(size, top, bottom):
    img = Image.new("RGB", size, top)
    d = ImageDraw.Draw(img)
    for y in range(size[1]):
        t = y / (size[1] - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (size[0], y)], fill=c)
    return img.convert("RGBA")


def compose_tank(size, fishes):
    """Water gradient + pebbles + centered fish — used by icons and splashes."""
    img = vertical_gradient(size, WATER, WATER_DEEP)
    peb = draw_pebbles(size[0], max(90, size[1] // 5))
    img.alpha_composite(peb, (0, size[1] - peb.height))
    for fish_img, cx, cy, scale in fishes:
        f = fish_img.resize(
            (int(fish_img.width * scale), int(fish_img.height * scale)),
            Image.Resampling.LANCZOS,
        )
        img.alpha_composite(f, (int(cx - f.width / 2), int(cy - f.height / 2)))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    orange = draw_fish((242, 130, 48), (250, 180, 60), (230, 110, 30))
    blue = draw_fish((64, 120, 216), (110, 160, 235), (48, 95, 190))
    orange.save(os.path.join(OUT, "fish_orange.png"))
    blue.save(os.path.join(OUT, "fish_blue.png"))
    draw_pebbles().save(os.path.join(OUT, "pebbles.png"))

    w, h = 1280, 720
    compose_tank(
        (w, h), [(orange, w * 0.35, h * 0.35, 0.9), (blue, w * 0.62, h * 0.55, 0.75)]
    ).save(os.path.join(OUT, "splash_hd.png"))
    compose_tank(
        (1920, 1080),
        [(orange, 670, 380, 1.35), (blue, 1190, 590, 1.1), (orange, 980, 250, 0.8)],
    ).save(os.path.join(OUT, "splash_fhd.png"))
    compose_tank((540, 405), [(orange, 270, 190, 0.75)]).save(
        os.path.join(OUT, "icon_fhd.png")
    )
    compose_tank((290, 218), [(orange, 145, 100, 0.42)]).save(
        os.path.join(OUT, "icon_hd.png")
    )
    print("art written to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
