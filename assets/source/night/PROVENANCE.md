# Night and light-effect art provenance (P3.7, plus the procedural P4.6 tiles)

Status: **awaiting Paul's review**. See `docs/art/contact-night.png` and `docs/art/mockup-night.png`. Date: 2026-11-04.

None of this art used a generator, so it cost no credits. Everything is either procedural or derived from art that is already approved.

| Runtime file | How it is made |
|---|---|
| `images/fx/shaft_day_a.png`, `shaft_day_b.png` (256x1088) | `tools/art/reef_fx.py` draws a slanted soft beam: a parabolic cross profile with five streak sub-rays, fading in at the top and out over the lower half. White RGB, with the shape in alpha. Alpha is 0 on every border. Seeds 11 and 12 |
| `images/night/moon_shaft_a.png`, `moon_shaft_b.png` (256x1088) | The same generator, narrower and fainter. Seeds 21 and 22. They are white, so the cool moonlight tint comes from `blendColor` |
| `images/night/sparkle.png` (32x32) | A Gaussian core plus a soft halo. White, alpha 0 at the border |
| `images/fx/caustic_a.png`, `caustic_b.png` (512x512) | A Voronoi F2−F1 net with wrapped (toroidal) distances, over a domain warp built only from integer-frequency sinusoids, then an FFT blur, which wraps. The tile is periodic by construction, not by edge blending. Seeds 7301 and 9157, with different cell counts and warps so the two layers do not beat |
| `images/fx/ripple.png` (1920x128) | The same cellular net on a 1920x256 torus, rows 0–127. Bright at the surface, alpha 0 on the bottom row, periodic in x with period 1920 |
| `images/night/glow_*.png` | `tools/art/reef_decor.py` derives these from each shipped mid and front coral chunk and from `images/decor/reef_backdrop.png`, in five steps (below) |

The glow masks are built like this:

1. Select coral tissue that is bright (value ≥ 0.55) and saturated (saturation ≥ 0.45), excluding water blues (hue 0.53–0.66).
2. Recolour it to its own hue at saturation 0.7 and full value.
3. Downsample to half resolution and apply a 1.5 px blur.
4. Cut into 64-px column chunks, each cropped to its glow box.
5. Show each chunk at `scale` 2 over the sprite it came from.

With water excluded, only one small chunk of the backdrop glows, so the back reef stays dark at night.

## Tile seam proof (caustics and ripple)

`docs/art/caustic-wrap-test.png` shows each caustic tile rolled by (256, 256), which puts the original wrap edges across the middle of the panel, and a 2x2 tiling of each tile. No seam is visible.

The script also prints a seam ratio: the difference across the wrap edge divided by the mean difference between adjacent interior columns or rows. A ratio of 1.0 means the wrap edge looks like any other pair of neighbouring lines. A real seam would score well above 1.

| Tile | x | y |
|---|---|---|
| caustic_a | 0.870 | 0.595 |
| caustic_b | 0.863 | 1.138 |
| ripple (x only, since it scrolls horizontally) | 0.554 | not applicable |
