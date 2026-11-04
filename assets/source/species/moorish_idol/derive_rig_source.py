# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.2"]
# ///
"""Derive the rig source for the Moorish idol: taper the dorsal streamer to a point.

``uv run assets/source/species/moorish_idol/derive_rig_source.py``

The generated streamer trails past the tail fin. tools/art/rig.py splits the tail
at one vertical column, so any streamer pixels left of the cut would rotate with
the tail and snap off at the seam. This narrows the streamer about its own
centre line from full width at STREAMER_TAPER_START to nothing at STREAMER_TIP_X,
which lies on the body side of the tail cut (cut_x_px 684, feather 20), so the
whole streamer stays in the body layer. Everything else is copied untouched.
"""

from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
SRC = HERE / "moorish_idol_a2.png"
OUT = HERE / "moorish_idol_a2_rig.png"
STREAMER_MAX_Y = 400  # left of x=1000 the only pixels above this row are the streamer.
STREAMER_MAX_X = 1000
STREAMER_TAPER_START = 960
STREAMER_TIP_X = 740


def main() -> None:
    arr = np.asarray(Image.open(SRC).convert("RGBA")).copy()
    alpha = arr[..., 3].astype(np.float32)
    ys = np.arange(STREAMER_MAX_Y, dtype=np.float32)
    for x in range(STREAMER_MAX_X):
        col = alpha[:STREAMER_MAX_Y, x]
        if x < STREAMER_TIP_X:
            col[:] = 0.0
            continue
        if x >= STREAMER_TAPER_START:
            continue
        solid = np.nonzero(col > 128)[0]
        if solid.size == 0:
            col[:] = 0.0
            continue
        centre = (solid.min() + solid.max() + 1) / 2.0
        half = (solid.max() + 1 - solid.min()) / 2.0 + 1.5  # keep the antialiased rim
        t = (x - STREAMER_TIP_X) / (STREAMER_TAPER_START - STREAMER_TIP_X)
        keep = np.clip(half * t - np.abs(ys - centre) + 0.5, 0.0, 1.0)
        col *= keep
    arr[..., 3] = np.clip(np.rint(alpha), 0, 255).astype(np.uint8)
    arr[arr[..., 3] == 0] = 0
    Image.fromarray(arr).save(OUT, format="PNG", optimize=False, compress_level=9)
    print(f"wrote {OUT.name}")


if __name__ == "__main__":
    main()
