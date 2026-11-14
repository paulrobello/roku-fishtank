# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "imagequant==1.1.6"]
# ///
"""Encode full-resolution store artwork from preserved runtime masters.

Run ``uv run tools/art/store_art.py``. Masters in assets/source/runtime-masters
are not packaged. Regenerate upstream art into images/, copy the regenerated
PNGs to the corresponding master paths, then run this final encoding pass.
Never feed already-quantized output back into the masters.
"""

from pathlib import Path

from imagequant import quantize_pil_image
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MASTERS = ROOT / "assets/source/runtime-masters"
IMAGES = ROOT / "images"
JPEG_NAMES = {"reef_backdrop.png", "splash_fhd.png", "splash_hd.png"}


def main() -> None:
    """Keep dimensions and alpha; use JPEG only for the three opaque plates."""
    total = 0
    for source in sorted(MASTERS.rglob("*.png")):
        destination = IMAGES / source.relative_to(MASTERS)
        destination.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(source) as original:
            rgba = original.convert("RGBA")
            if source.name in JPEG_NAMES:
                if rgba.getchannel("A").getextrema() != (255, 255):
                    raise ValueError(f"JPEG source must be opaque: {source}")
                raw_runtime = destination
                if (
                    raw_runtime.exists()
                    and raw_runtime.read_bytes() != source.read_bytes()
                ):
                    raise ValueError(
                        f"Capture regenerated original into {source} before encoding {raw_runtime}"
                    )
                destination = destination.with_suffix(".jpg")
                rgba.convert("RGB").save(
                    destination, quality=80, optimize=True, subsampling=0
                )
                # The byte-identical master remains safely preserved outside the package.
                raw_runtime.unlink(missing_ok=True)
            else:
                quantize_pil_image(rgba, dithering_level=0.5, max_colors=128).save(
                    destination, optimize=True
                )
        total += destination.stat().st_size
    print(f"Encoded full-resolution store artwork: {total:,} bytes")


if __name__ == "__main__":
    main()
