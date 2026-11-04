# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=10"]
# ///
"""Measures a FidelityScene capture against the analytic expectations.

Usage: uv run tools/fidelity/measure.py <capture.png|jpg>
Prints a markdown table. Works on any capture of the full 16:9 frame (the
simulator PNG or a device screenshot); coordinates scale by width/1920 and
height/1080. Not for TV photos (perspective): judge those by eye against the
ticks and reference strips drawn in the scene.

Pass rule (PRD P0): positions within 2% of screen width (38.4 px at 1920),
colors visually matched (here: every channel within 16 of expected).
"""

import math
import sys
from collections.abc import Callable

from PIL import Image

W, H = 1920, 1080
POS_TOL = 0.02 * W
COLOR_TOL = 16

Pixel = tuple[int, int, int]
Box = tuple[int, int, int, int]


def red(p: Pixel) -> bool:
    return p[0] > 200 and p[1] < 70 and p[2] < 70


def blue(p: Pixel) -> bool:
    return p[0] < 70 and p[1] < 70 and p[2] > 200


def green(p: Pixel) -> bool:
    return p[0] < 70 and p[1] > 200 and p[2] < 70


def yellow(p: Pixel) -> bool:
    return p[0] > 200 and p[1] > 200 and p[2] < 70


def cyan(p: Pixel) -> bool:
    return p[0] < 70 and p[1] > 200 and p[2] > 200


def magenta(p: Pixel) -> bool:
    return p[0] > 200 and p[1] < 70 and p[2] > 200


def white(p: Pixel) -> bool:
    return p[0] > 235 and p[1] > 235 and p[2] > 235


class Capture:
    def __init__(self, path: str) -> None:
        self.img = Image.open(path).convert("RGB")
        self.sx = self.img.width / W
        self.sy = self.img.height / H

    def centroid(self, box: Box, pred: Callable[[Pixel], bool]) -> tuple[float, float] | None:
        x0, y0, x1, y1 = (int(box[0] * self.sx), int(box[1] * self.sy), int(box[2] * self.sx), int(box[3] * self.sy))
        sx = sy = n = 0
        px = self.img.load()
        for y in range(y0, y1):
            for x in range(x0, x1):
                if pred(px[x, y]):
                    sx += x
                    sy += y
                    n += 1
        if n == 0:
            return None
        # +0.5: pixel centres; back to 1920x1080 scene coordinates.
        return ((sx / n + 0.5) / self.sx, (sy / n + 0.5) / self.sy)

    def mean(self, cx: float, cy: float, hw: int = 20, hh: int = 8) -> Pixel:
        crop = self.img.crop((int((cx - hw) * self.sx), int((cy - hh) * self.sy), int((cx + hw) * self.sx), int((cy + hh) * self.sy)))
        data = crop.tobytes()
        n = len(data) // 3
        return tuple(round(sum(data[i::3]) / n) for i in range(3))  # type: ignore[return-value]


def hexc(c: Pixel) -> str:
    return "0x%02X%02X%02X" % c


def color_row(cap: Capture, name: str, at: tuple[float, float], exp: Pixel, alt: str = "") -> str:
    got = cap.mean(*at)
    diff = max(abs(a - b) for a, b in zip(got, exp))
    verdict = "PASS" if diff <= COLOR_TOL else "FAIL"
    return f"| {name} | color | {hexc(exp)}{alt} | {hexc(got)} | max channel diff {diff} | {verdict} |"


def pos_row(cap: Capture, name: str, box: Box, pred: Callable[[Pixel], bool], exp: tuple[float, float]) -> str:
    got = cap.centroid(box, pred)
    if got is None:
        return f"| {name} | position | ({exp[0]:.1f}, {exp[1]:.1f}) | not found | - | FAIL |"
    err = math.dist(got, exp)
    verdict = "PASS" if err <= POS_TOL else "FAIL"
    return f"| {name} | position | ({exp[0]:.1f}, {exp[1]:.1f}) | ({got[0]:.1f}, {got[1]:.1f}) | {err:.1f} px ({100 * err / W:.2f}% W) | {verdict} |"


def main() -> None:
    cap = Capture(sys.argv[1])
    r45 = math.sqrt(0.5)
    rows = [
        "| Probe | Kind | Expected | Measured | Error | Verdict |",
        "|---|---|---|---|---|---|",
        color_row(cap, "1 blendColor white x 0x00FF00", (104, 264), (0, 255, 0)),
        color_row(cap, "1 blendColor grey x 0xFF8000", (280, 264), (128, 64, 0)),
        color_row(cap, "2 group 0.5 x poster 0.5", (496, 280), (64, 64, 64)),
        color_row(cap, "2 reference poster 0.25", (656, 280), (64, 64, 64)),
        pos_row(cap, "3 rotate+scale red corner", (770, 60, 1150, 520), red, (960 - 72 * 2 * r45, 300)),
        pos_row(cap, "3 rotate+scale blue corner", (770, 60, 1150, 520), blue, (960, 300 - 72 * 2 * r45)),
        pos_row(cap, "3 rotate+scale green bar", (770, 60, 1150, 520), green, (960 + 84 * r45, 300 + 84 * r45)),
        pos_row(cap, "4 reference red", (1160, 200, 1340, 400), red, (1208, 252)),
        # Device rule (F4): with rotation 0 the sign of scale.x is ignored, so no mirror.
        pos_row(cap, "4 scale -1 red (unmirrored)", (1350, 200, 1530, 400), red, (1384, 252)),
        pos_row(cap, "4 scale -1 blue (unmirrored)", (1350, 200, 1530, 400), blue, (1480, 252)),
        pos_row(cap, "5 pivot A (white)", (1540, 100, 1920, 520), white, (1616, 440)),
        pos_row(cap, "5 group B origin (yellow)", (1540, 100, 1920, 520), yellow, (1616 + 80 * math.cos(math.pi / 6), 440 - 80 * math.sin(math.pi / 6))),
        pos_row(cap, "5 group C origin (cyan)", (1540, 100, 1920, 520), cyan, (1616 + 80 * (math.cos(math.pi / 6) + math.cos(math.pi / 3)), 440 - 80 * (math.sin(math.pi / 6) + math.sin(math.pi / 3)))),
        pos_row(cap, "5 arm tip (magenta)", (1540, 100, 1920, 520), magenta, (1616 + 80 * (math.cos(math.pi / 6) + math.cos(math.pi / 3)), 440 - 80 * (math.sin(math.pi / 6) + math.sin(math.pi / 3) + 1))),
    ]

    def io(t: float) -> float:
        return 4 * t**3 if t < 0.5 else 4 * (t - 1) ** 3 + 1

    lanes = [("io16", 580, io(0.25)), ("io8", 640, io(0.5)), ("io5", 700, io(0.75)), ("li16", 780, 0.25), ("li8", 840, 0.5), ("li5", 900, 0.75)]
    for name, y, f in lanes:
        rows.append(pos_row(cap, f"6 lane {name} (nominal t=4 s)", (150, y - 2, 1450, y + 26), yellow, (200 + 1200 * f + 12, y + 12)))
    # Device rule (F5): hue lerped 0 -> 240 with no wrap: yellow, green, cyan.
    hsv = [(255, 255, 0), (0, 255, 0), (0, 255, 255)]
    short = ["0xFF0080", "0xFF00FF", "0x8000FF"]
    for i, (name, x) in enumerate([("c16 f=0.25", 300), ("c8 f=0.5", 600), ("c5 f=0.75", 900)]):
        rows.append(color_row(cap, f"7 swatch {name}", (x + 60, 990), hsv[i], f" (HSV no wrap; shortest hue path would be {short[i]})"))
    probe = cap.centroid((1450, 596, 1900, 628), white)
    rows.append(
        f"| fraction probe (unscored) | position | x 1662 if direct fraction drives, 1512 if ignored | "
        f"{'not found' if probe is None else f'x {probe[0]:.1f}'} | - | info |"
    )
    print("\n".join(rows))


if __name__ == "__main__":
    main()
