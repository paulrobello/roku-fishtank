# P0.5 fidelity: simulator vs device

`FidelityScene` (`components/Fidelity/`) draws every SceneGraph primitive the reef relies on in its own cell of a 1920x1080 grid. Both captures are judged against analytic expectations, not just against each other.

**Pass rule (PRD P0):** positions within 2% of screen width (38.4 px), colors visually matched (`tools/fidelity/measure.py` uses every channel within 16), and every primitive renders. Any fail stops the phase for Paul's fallback decision (O1 TS twin renderer, O2 device-only iteration).

## Files

| File | What |
|---|---|
| `simulator.png` | Playwright capture of `?scene=FidelityScene` (brs-engine 2.6.2 + brs-scenegraph 0.6.2), taken by `make fidelity-sim` |
| `simulator-console.txt` | the scene's `FIDELITY` read-back lines in the simulator |
| `simulator-measure.md` | `measure.py` output for `simulator.png` |
| `device.jpg` / `device-photo.jpg`, `device-console.txt` | written by `make fidelity-device` (or a TV photo), still to do |

## Cell layout

Row 1 (y 0-520) is static, five 384 px cells. Row 2 (y 530-1080) is animated.

| Cell | Region | Primitive | Content |
|---|---|---|---|
| 1 | x 0-384 | `blendColor` multiply | `white.png` x 0x00FF00 at (40,200); `grey.png` (0x808080) x 0xFF8000 at (216,200), both 128x128 |
| 2 | x 384-768 | stacked opacity | over a black backing: Group opacity 0.5 holding a white Poster at opacity 0.5 (432,216), beside a white Poster at opacity 0.25 (592,216) |
| 3 | x 768-1152 | rotation + scale about `scaleRotateCenter` | `marker.png` at (896,236), center (64,64), scale 1.5, rotation 0.785398 (45 deg, CCW) |
| 4 | x 1152-1536 | negative `scale.x` | `marker.png` reference at (1192,236); mirrored copy at (1368,236), center (64,64), scale [-1,1] |
| 5 | x 1536-1920 | nested Group rotation | Groups A > B > C, each rotated 30 deg, 80 px arms; pivot A at (1616,440); markers white (A), yellow (B), cyan (C), magenta (tip) |
| 6 | y 580-924 | `Vector2DFieldInterpolator` + easing | six yellow 24x24 markers moving x 200 -> 1400: lanes y 580/640/700 inOutCubic with durations 16/8/5.333 s, lanes y 780/840/900 linear with the same durations. Light tick = expected center at the nominal pause |
| 7 | y 960-1040 | `ColorFieldInterpolator` | red -> blue swatches (linear, 16/8/5.333 s) at x 300/600/900, red and blue references at x 140/1100, expected-color strip under each swatch |
| probe | (1500,600) | bare interpolator, unscored | `Vector2DFieldInterpolator` with no Animation and `fraction = 0.5` |

`marker.png` is white with a red square top-left, a blue square top-right and a green bar bottom-center, so rotation direction and mirroring are unambiguous. All test PNGs come from `tools/fidelity/make_images.py`.

## Determinism

A device cannot use the preview's `?freeze` shim, and a bare interpolator does not move in brs-scenegraph 0.6.2: it only interpolates inside `Animation.updateAnimation`. The probe confirms this, since the simulator leaves it at x 1500. Holding interpolators at fixed fractions is therefore not testable in the simulator.

The scene runs real Animations and pauses them all on a Timer at **4 s**. Durations are 4x, 2x and 4/3x the pause, so the nominal linear fractions are 0.25, 0.5 and 0.75. A frame of pause jitter moves a marker at most about 2.5 px, because the travel is slow (1200 px over 16, 8 or 5.3 s).

To remove the jitter from the verdict, the scene reads back each interpolator's `fraction` after the pause. It judges every position against the keyValue lerp at that fraction, and every inOutCubic lane against `inOutCubic(fraction of its linear partner)`. It prints `FIDELITY ...` lines on the console every 3 s (telnet 8087 on the device) and shows a summary in the on-screen report Label, so a TV photo documents itself.

Do not capture this scene with `?freeze`. The freeze shim in `source/preview.brs` interpolates colors in RGB, while both the Roku docs and brs-scenegraph use HSV.

## Expected values

Rotation is CCW-positive on screen (y down): a point (x, y) relative to the center maps to (x cos t + y sin t, -x sin t + y cos t).

| # | Probe | Expected (analytic) |
|---|---|---|
| 1 | white x 0x00FF00 | 0x00FF00 |
| 1 | grey x 0xFF8000 | 0x804000 (128*255/255, 128*128/255, 0) |
| 2 | group 0.5 x poster 0.5 over black | 0x404040 (255 x 0.25) |
| 2 | poster 0.25 reference | 0x404040 |
| 3 | red / blue / green centers | (858.2, 300.0) / (960.0, 198.2) / (1019.4, 359.4). Poster center stays at (960,300) |
| 4 | reference red | (1208, 252) |
| 4 | mirrored red / blue | (1480, 252) / (1384, 252), so the colors swap sides |
| 5 | A / B / C / tip | (1616, 440) / (1685.3, 400.0) / (1725.3, 330.7) / (1725.3, 250.7) |
| 6 | inOutCubic at t = 0.25/0.5/0.75 | fraction 0.0625/0.5/0.9375, marker center x 287/812/1337 |
| 6 | linear at t = 0.25/0.5/0.75 | fraction 0.25/0.5/0.75, marker center x 512/812/1112 |
| 7 | color at f = 0.25/0.5/0.75 | HSV shortest hue path (360 -> 240): 0xFF0080 / 0xFF00FF / 0x8000FF. An RGB lerp would give 0xBF0040 / 0x800080 / 0x4000BF |
| probe | bare interpolator, fraction 0.5 | x center 1662 if a direct `fraction` write drives the target, 1512 if it is ignored |

## Results

Positions are measured centroids at nominal t = 4 s from `simulator-measure.md`. Error is the distance to the expected value.

| # | Primitive | Simulator measured | Simulator verdict | Device measured | Device verdict |
|---|---|---|---|---|---|
| 1 | blendColor multiply | 0x00FF00 and 0x804000, exact | PASS | | |
| 2 | stacked opacity | 0x404040 and 0x404040, exact | PASS | | |
| 3 | rotation + scale about center | red (871.0, 268.0), blue (973.0, 166.0), green (1032.5, 327.5): all 34.5 px (1.80% W) off, the same shift (+13, -32) | PASS (marginal, simulator bug, see F1) | | |
| 4 | negative scale.x | red (1480, 252), blue (1384, 252), exact | PASS | | |
| 5 | nested rotation | within 0.2 px at every joint | PASS | | |
| 6 | Vector2D + inOutCubic / linear | read back at 4011 ms: io fractions 0.06235/0.49876/0.93703 vs inOutCubic(linear partner) 0.06235/0.49876/0.93704; x equals the keyValue lerp exactly; nominal-time error 0.0 to 1.5 px | PASS | | |
| 7 | ColorFieldInterpolator | 0xFF007F / 0xFF00FE / 0x8000FF at f 0.250/0.500/0.749, matching HSV (diff 1 or less) | PASS | | |
| probe | bare interpolator | x 1512: brs-scenegraph ignores a direct fraction write | info | | |

**Simulator overall: every primitive renders and every probe is within the pass rule.** Cell 3 passes only marginally because of F1.

## Findings

- **F1: brs-scenegraph 0.6.2 rotates scaled Posters about the wrong point.** `getTranslation` shifts the translation by `scaleRotateCenter * (scale - 1)`, then `doDrawRotatedBitmap` rotates the scaled bitmap about the *unscaled* center. With rotation and scale combined, the Poster drifts by `R(c * (s - 1)) - c * (s - 1)`: 34.5 px here (c = 64, s = 1.5, 45 deg). Rotation alone, scale alone and mirroring are exact. The error grows with the center offset and the scale, so large scaled and rotated Posters can exceed the 2% rule in the preview. If the device matches the analytic value, add a `simPatches` entry in `preview/vite.config.ts`.
- **F2: the `?freeze` shim interpolates colors in RGB** (`previewApplyInterpolator` in `source/preview.brs`), but the Roku `ColorFieldInterpolator` doc and brs-scenegraph both use HSV. A frozen color animation therefore shows a different color than the live one.
- **F3: direct `fraction` writes are a no-op in brs-scenegraph.** Whether they drive the target on OS 15.3.4 is unknown until the device run. The Roku doc lists `fraction` as writable but only describes the Animation setting it.

## Device run

Done by Paul, since agents do not contact the TV:

1. Put `ROKU_HOST=192.168.1.10` and `ROKU_PASSWORD=<dev password>` in the repo's gitignored `.env`.
2. `make fidelity-device`. It builds `dist/fidelity.zip`, exits any running screensaver (`press k` on 8080), sideloads it with digest auth, captures 10 s of console 8087 into `docs/fidelity/device-console.txt`, and tries a `plugin_inspect` screenshot into `docs/fidelity/device.jpg`.
3. If the script prints `SCREENSHOT FAILED`, photograph the TV head-on after the scene pauses (4 s, when the report Label fills in) and save it as `docs/fidelity/device-photo.jpg`.
4. With a screenshot, run `uv run tools/fidelity/measure.py docs/fidelity/device.jpg`. With a photo, judge it by eye against the ticks and reference strips, and use the console lines for the numbers. The console `x` vs `exp_x` comparison is authoritative only if the device writes interpolator `fraction`. If any read-back `frac` is 0 or never changes, judge each lane against the nominal ticks (or `measure.py`) instead, and record that OS 15.3.4 does not expose `fraction`.
5. Fill in the Device columns. Exit the screensaver on the TV, then restore the channel with `make deploy`.
