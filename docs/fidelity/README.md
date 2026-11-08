# P0.5 fidelity: simulator vs device

`FidelityScene` (`components/Fidelity/`) draws every SceneGraph primitive the reef relies on in its own cell of a 1920x1080 grid. Both captures are judged against analytic expectations, not just against each other.

**Pass rule (PRD P0):** positions within 2% of screen width (38.4 px), colors visually matched (`tools/fidelity/measure.py` uses every channel within 16), and every primitive renders. Any fail stops the phase for Paul's fallback decision (O1 TS twin renderer, O2 device-only iteration).

## Contents

- [Files](#files)
- [Cell layout](#cell-layout)
- [Determinism](#determinism)
- [Expected values](#expected-values)
- [Results](#results)
- [Findings](#findings)
- [Device run](#device-run)

## Files

| File | What |
|---|---|
| `simulator.png` | Playwright capture of `?scene=FidelityScene` (brs-engine 2.6.2 + brs-scenegraph 0.6.2 with the `preview/vite.config.ts` device patches), taken by `make fidelity-sim` (`PW_PORT=<port>` if 8139 is busy) |
| `simulator-console.txt` | the scene's `FIDELITY` read-back lines in the simulator |
| `simulator-measure.md` | `measure.py` output for `simulator.png` |
| `device.jpg`, `device-console.txt`, `device-measure.md` | `make fidelity-device` on the Primary 4850X (OS 15.3.4), 2026-11-04: `plugin_inspect` screenshot, console read-back, `measure.py` output |

## Cell layout

Row 1 (y 0-520) is static, five 384 px cells. Row 2 (y 530-1080) is animated.

| Cell | Region | Primitive | Content |
|---|---|---|---|
| 1 | x 0-384 | `blendColor` multiply | `white.png` x 0x00FF00 at (40,200); `grey.png` (0x808080) x 0xFF8000 at (216,200), both 128x128 |
| 2 | x 384-768 | stacked opacity | over a black backing: Group opacity 0.5 holding a white Poster at opacity 0.5 (432,216), beside a white Poster at opacity 0.25 (592,216) |
| 3 | x 768-1152 | rotation + scale about `scaleRotateCenter` | `marker.png` at (896,236), center (64,64), scale 1.5, rotation 0.785398 (45 deg, CCW) |
| 4 | x 1152-1536 | negative `scale.x` | `marker.png` reference at (1192,236); scale -1 copy at (1368,236), center (64,64), scale [-1,1] |
| 5 | x 1536-1920 | nested Group rotation | Groups A > B > C, each rotated 30 deg, 80 px arms; pivot A at (1616,440); markers white (A), yellow (B), cyan (C), magenta (tip) |
| 6 | y 580-924 | `Vector2DFieldInterpolator` + easing | six yellow 24x24 markers moving x 200 -> 1400: lanes y 580/640/700 inOutCubic with durations 16/8/5.333 s, lanes y 780/840/900 linear with the same durations. Light tick = expected center at the nominal pause |
| 7 | y 960-1040 | `ColorFieldInterpolator` | red -> blue swatches (linear, 16/8/5.333 s) at x 300/600/900, red and blue references at x 140/1100, expected-color strip under each swatch |
| probe | (1500,600) | bare interpolator, unscored | `Vector2DFieldInterpolator` with no Animation and `fraction = 0.5` |

`marker.png` is white with a red square top-left, a blue square top-right and a green bar bottom-center, so rotation direction and mirroring are unambiguous. All test PNGs come from `tools/fidelity/make_images.py`.

## Determinism

A device cannot use the preview's `?freeze` shim. Unpatched brs-scenegraph 0.6.2 only interpolates inside `Animation.updateAnimation`, so a bare interpolator did not move (probe x 1500). The device does move it (F3), and the preview now emulates that, so the probe sits at x 1650 in both. The scene still uses real Animations for the scored cells.

The scene runs real Animations and pauses them all on a Timer at **4 s**. Durations are 4x, 2x and 4/3x the pause, so the nominal linear fractions are 0.25, 0.5 and 0.75. A frame of pause jitter moves a marker at most about 2.5 px, because the travel is slow (1200 px over 16, 8 or 5.3 s).

To remove the jitter from the verdict, the scene reads back each interpolator's `fraction` after the pause. It judges every position against the keyValue lerp at that fraction, and every inOutCubic lane against `inOutCubic(fraction of its linear partner)`. It prints `FIDELITY ...` lines on the console every 3 s (telnet 8087 on the device) and shows a summary in the on-screen report Label, so a TV photo documents itself.

Capture the verdict run without `?freeze`. The scene pauses its own Animations at 4 s, and the freeze shim only snaps Animations that are still running, so `?freeze` at 4 s or later snaps nothing. A `?freeze` below 4 s snaps every cell to that time; the color swatches then match the patched preview's HSV interpolation exactly (the shim's color math is in `source/preview_color.brs`), but the strips under them and the `FIDELITY` lines still judge the 4 s pause, so they no longer line up. At `?freeze=2` the swatches now read 0xFF8000 / 0xFFFF00 / 0x80FF00 (f = 0.125 / 0.25 / 0.375, device hue rule). `freeze-hsv-swatches.png` predates F5 and shows the old shortest-path colours (0xFF0040 / 0xFF0080 / 0xFF00BF).

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
| 4 | scale -1 red / blue | (1384, 252) / (1480, 252): the device ignores the sign at rotation 0 (F4), so the copy is unmirrored. A true mirror would put red at 1480 and blue at 1384 |
| 5 | A / B / C / tip | (1616, 440) / (1685.3, 400.0) / (1725.3, 330.7) / (1725.3, 250.7) |
| 6 | inOutCubic at t = 0.25/0.5/0.75 | fraction 0.0625/0.5/0.9375, marker center x 287/812/1337 |
| 6 | linear at t = 0.25/0.5/0.75 | fraction 0.25/0.5/0.75, marker center x 512/812/1112 |
| 7 | color at f = 0.25/0.5/0.75 | device rule, hue lerped 0 -> 240 with no wrap (F5): 0xFFFF00 / 0x00FF00 / 0x00FFFF. The shortest hue path (360 -> 240) would give 0xFF0080 / 0xFF00FF / 0x8000FF, an RGB lerp 0xBF0040 / 0x800080 / 0x4000BF |
| probe | bare interpolator, fraction 0.5 | x center 1662 if a direct `fraction` write drives the target, 1512 if it is ignored |

## Results

Positions are measured centroids at nominal t = 4 s from `simulator-measure.md` and `device-measure.md`. Error is the distance to the expected value. Since 2026-11-04 the expected values for cells 4 and 7 are the device rules (F4, F5), and the simulator column is the preview with the device patches in `preview/vite.config.ts`. The unpatched simulator measured cell 3 at 34.5 px off (F1), cell 4 mirrored (red 1480, blue 1384), cell 7 at 0xFF007F / 0xFF00FF / 0x8000FF and the probe at x 1512.

| # | Primitive | Simulator measured (patched) | Simulator verdict | Device measured | Device verdict |
|---|---|---|---|---|---|
| 1 | blendColor multiply | 0x00FF00 and 0x804000, exact | PASS | 0x00FF01 and 0x804000 | PASS |
| 2 | stacked opacity | 0x404040 and 0x404040, exact | PASS | 0x3F3F3F and 0x3F3F3F | PASS |
| 3 | rotation + scale about center | red (858.0, 300.0), blue (960.0, 198.0), green (1019.5, 359.5), within 0.2 px | PASS (F1 patched) | red (858.5, 300.0), blue (960.0, 198.2), green (1019.3, 359.4), within 0.3 px | PASS |
| 4 | negative scale.x | red (1384, 252), blue (1480, 252): unmirrored, exact | PASS (F4 patched) | red (1384, 252), blue (1480, 252): unmirrored, within 0.1 px | PASS (device rule) |
| 5 | nested rotation | within 0.2 px at every joint | PASS | within 0.4 px at every joint | PASS |
| 6 | Vector2D + inOutCubic / linear | read back at 4014 ms: io fractions 0.06224/0.49803/0.93676 equal inOutCubic of their linear partners (0.06225/0.49803/0.93676); x equals the keyValue lerp; nominal-time error 0.5 to 2.5 px | PASS | read back at 4012 ms: io fractions 0.06288/0.50299/0.93865 equal inOutCubic of their linear partners; x equals the keyValue lerp; nominal-time error 0.0 to 3.0 px | PASS |
| 7 | ColorFieldInterpolator | 0xFFFF00 / 0x01FF00 / 0x00FFFE at f 0.250/0.499/0.749: yellow, green, cyan (diff 1 or less) | PASS (F5 patched) | 0xFEFF01 / 0x00FF01 / 0x00FEFF at f 0.251/0.501/0.752: yellow, green, cyan (diff 1 or less) | PASS (device rule) |
| probe | bare interpolator | x 1662: a direct fraction write drives the target | info (F3 patched) | x 1662: a direct fraction write drives the target | info |

**Patched simulator and device agree on every cell**, within 3 px and 1 colour level. Against the original expectations (a true mirror in cell 4, the shortest hue path in cell 7), the device failed cells 4 and 7, which per the pass rule went to Paul; F4 and F5 record the decisions (pre-mirrored art instead of negative scale, and match the preview to the device). The original `device-measure.md` with those FAILs is in git at f7dcefe. Judged by the device rules, the device passes every cell. The device behaviours behind cells 4 and 7 (no mirror through scale, long-way hue) remain constraints on the channel code, not preview bugs.

## Findings

- **F1: brs-scenegraph 0.6.2 rotates scaled Posters about the wrong point.** `getTranslation` shifts the translation by `scaleRotateCenter * (scale - 1)`, then `doDrawRotatedBitmap` rotates the scaled bitmap about the *unscaled* center. With rotation and scale combined, the Poster drifts by `R(c * (s - 1)) - c * (s - 1)`: 34.5 px here (c = 64, s = 1.5, 45 deg). Rotation alone, scale alone and mirroring are exact. The error grows with the center offset and the scale, so large scaled and rotated Posters can exceed the 2% rule in the preview. The device matches the analytic value. **Preview patched (2026-11-04):** the `drawImage` entry in `preview/vite.config.ts` `simPatches` draws the bitmap from `O = parentOrigin + R(P)(T + c - R(theta)(S c))`, so cell 3 now measures within 0.2 px.
- **F2 (fixed 2026-11-04): the `?freeze` shim interpolated colors in RGB** (`previewApplyInterpolator` in `source/preview.brs`), but the Roku `ColorFieldInterpolator` doc and brs-scenegraph both use HSV. The shim now calls `previewLerpColorHsv` (`source/preview_color.brs`), a line-for-line port of brs-scenegraph's `interpolateColor`, unit-tested against values from brs-scenegraph's own code. `freeze-hsv-swatches.png` shows `?freeze=2` before (RGB: 0xDF001F / 0xBF003F / 0x9F005F) and after (HSV: 0xFF0040 / 0xFF0080 / 0xFF00BF).
- **F3: direct `fraction` writes are a no-op in brs-scenegraph.** Whether they drive the target on OS 15.3.4 is unknown until the device run. The Roku doc lists `fraction` as writable but only describes the Animation setting it.

- **F3 answered:** on the device a direct `fraction` write moves the target (probe x 1662); brs-scenegraph ignores it (x 1512). **Preview patched:** the Interpolator `setValue` patch interpolates and writes the target when `fraction` is set on an interpolator whose parent is not an Animation (target found with Animation's own lookup from the interpolator's parent), so the preview probe is now x 1662 too.
- **F4: the device has no horizontal mirror through `scale`.** `make device-check SCENE=MirrorProbeScene` (`docs/perf/raw/check-MirrorProbeScene-20261104-122455-device.jpg`) tried every way. On a Poster or a Group with rotation 0, a negative `scale.x` is ignored and the bitmap draws like the reference. That holds when set in XML, from BrightScript, through a Vector2DFieldInterpolator, and at -0.999. With any rotation set (0.001 rad, 2 pi), the same negative `scale.x` renders as a 180-degree rotation (upside down, shifted up by about one height), not a mirror. On the device, BrainDemoScene's left-facing rigs therefore drew the body unflipped and the rotating tail upside down at the head. Unpatched brs-scenegraph mirrors in every case. **Fallback (recommended):** pre-mirrored left-facing art per species, and turns that squash `scale.x` to 0, swap art and expand, never using a negative scale. Fish bitmaps are small (`docs/perf.md`), so the extra textures cost about 0.2 to 0.6 MB per species. **Preview patched (2026-11-04)** to the device rule, as one model that fits all eight MirrorProbe cells: with accumulated rotation 0, `|scale|` is used everywhere (origin offset and draw); with rotation non-zero and a reflection (Poster `scale.x * scale.y < 0`, XOR the same on its immediate parent Group), the origin is computed with the signed scale and the bitmap drawn with `-|scale|`, a 180-degree turn. With `c` at the center that is upside down and one height up; whether the device shifts by `2 c.y` or by the height cannot be told apart from this probe (the model uses `2 c.y`). `?scene=MirrorProbeScene` runs in the preview (served from `tools/devicecheck/components`, never in the device build); tail centroids and blue bounding boxes match the device screenshot within 2 px in all eight cells. Unmeasured and only assumed: both axes negative, a negative-scale Group that is itself rotated, reflecting Groups more than one level above the Poster. **Adopted 2026-11-04:** `tools/art/rig.py` writes a `mirrored` layer set per rig and `components/Fish` swaps to it at the narrowest frame of the turn.
- **F5: the device's `ColorFieldInterpolator` lerps hue the long way.** Red to blue passes yellow (f 0.25), green (0.5) and cyan (0.75), so hue goes 0 to 240 degrees with no shortest-path wrap. brs-scenegraph wraps to 360 and passes magenta. Colour tweens must use keys whose hues are close, or add intermediate keys so the path is the same either way. **Preview patched (2026-11-04):** brs-sg's `interpolateColor` (served patch) and `previewLerpColorHsv` (`source/preview_color.brs`, the `?freeze` shim) lerp hue as `h1 + (h2 - h1) f` with no wrap. Saturation, value and alpha were constant in the sample, so they are unmeasured and kept as brs-sg lerps them. Only 0 -> 240 is measured. That any gap over 180 degrees also goes the long way (300 -> 60 passes 180, cyan) is an assumption, pinned in `tests/unit/preview_color_test.brs`.

## Device run

`make fidelity-device` deploys and waits up to `SCREENSAVER_WAIT` seconds (default 600) for the screensaver, which someone starts on the TV with Settings > Theme > Screensavers > dev > Preview (a sideloaded screensaver does not start on install):

1. Put `ROKU_HOST=192.168.1.10` and `ROKU_PASSWORD=<dev password>` in the repo's gitignored `.env`.
2. `make fidelity-device`. It builds `dist/fidelity.zip`, exits any running screensaver (`press k` on 8080), sideloads it with digest auth, captures 10 s of console 8087 into `docs/fidelity/device-console.txt`, and tries a `plugin_inspect` screenshot into `docs/fidelity/device.jpg`.
3. If the script prints `SCREENSHOT FAILED`, photograph the TV head-on after the scene pauses (4 s, when the report Label fills in) and save it as `docs/fidelity/device-photo.jpg`.
4. With a screenshot, run `uv run tools/fidelity/measure.py docs/fidelity/device.jpg`. With a photo, judge it by eye against the ticks and reference strips, and use the console lines for the numbers. The console `x` vs `exp_x` comparison is authoritative only if the device writes interpolator `fraction`. If any read-back `frac` is 0 or never changes, judge each lane against the nominal ticks (or `measure.py`) instead, and record that OS 15.3.4 does not expose `fraction`.
5. Fill in the Device columns. Exit the screensaver on the TV, then restore the channel with `make deploy`.
