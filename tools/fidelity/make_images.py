# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=10"]
# ///
"""Generates the flat test PNGs used by FidelityScene into images/fidelity/.

white.png   128x128 opaque white (blendColor multiply and opacity probes)
grey.png    128x128 opaque 0x808080 (blendColor multiply probe)
marker.png  128x128 white with a red 32x32 square top-left, a blue 32x32 square
            top-right and a green 32x16 bar bottom-centre, so rotation direction
            and mirroring are unambiguous.

Run: uv run tools/fidelity/make_images.py   (byte-reproducible)
"""

from pathlib import Path

from PIL import Image, ImageDraw

OUT: Path = Path(__file__).resolve().parents[2] / "images" / "fidelity"


def save(img: Image.Image, name: str) -> None:
    img.save(OUT / name, format="PNG", optimize=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    save(Image.new("RGBA", (128, 128), (255, 255, 255, 255)), "white.png")
    save(Image.new("RGBA", (128, 128), (128, 128, 128, 255)), "grey.png")

    marker = Image.new("RGBA", (128, 128), (255, 255, 255, 255))
    draw = ImageDraw.Draw(marker)
    draw.rectangle((0, 0, 31, 31), fill=(255, 0, 0, 255))
    draw.rectangle((96, 0, 127, 31), fill=(0, 0, 255, 255))
    draw.rectangle((48, 112, 79, 127), fill=(0, 255, 0, 255))
    save(marker, "marker.png")
    print(f"wrote {OUT}/white.png grey.png marker.png")


if __name__ == "__main__":
    main()
