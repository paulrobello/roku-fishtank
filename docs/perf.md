# Device performance limits (P0.6)

Measured 2026-11-04 on the Primary Roku Ultra 4850X (X000000000000, Roku OS 15.3.4.2402), 1920x1080 design resolution, with the `PerfProbe` screensaver (`probe/`).

## Result

The 4850X is **fill-rate bound, not node bound**.

- **Fish:** 140 rigged placeholder fish (3 Posters and 2 repeating Animations each, 700 nodes, 280 Animations) hold **60 fps** over a water Rectangle with no layers. No fish count tested lowers the frame rate.
- **Full-width translucent layers** (2400x1080 Posters at opacity 0.25, each drifting with its own Animation) over the full-screen water Rectangle:

| Layers | Fish | fps (median, min) |
|---|---|---|
| 0 | 0 | 60, 59 |
| 1 | 0 | 60, 60 |
| 2 | 0 | 60, 59 |
| 3 | 0 | 55, 50 |
| 4 | 0 | 40, 39 |
| 6 | 0 | 30, 29 |
| 8 | 0 | 30, 30 |
| 0 | 20 | 60, 59 |
| 0 | 40 | 60, 60 |
| 0 | 80 | 60, 60 |
| 0 | 140 | 60, 59 |

Run 1 ramped fish and layers together and agrees with this. 20 fish with 2 layers held 60 fps. 30 fish with 4 layers fell to 30 fps, and so did every heavier stage up to 140 fish with 8 layers. The one exception was 100 fish with 8 layers, which ran at 20 fps.

**Design limit for 60 fps:** at most the background plus **two more full-screen layers of overdraw** in any part of the screen. Three costs up to 10 fps. Fish, decor and particles that cover a small part of the screen are cheap. Large translucent overlays such as light shafts, caustics, surface ripple and full-width foreground cost about as much as one full-screen layer each, whatever their opacity. The P1 layer stack has to keep the full-screen ones to two.

## Texture memory

- The texture pool is **240,000,000 bytes**, shared with the Roku home UI and every other app (`r2d2_bitmaps` reports `max 240000000`).
- The Roku UI holds about 45 MB with the screensaver running.
- **Textures from an exited screensaver instance stay resident.** After four probe runs, the pool held two stale probe instances of 83.9 MB each next to the live one, and reported 223–230 MB used. No allocation failed. The resident sets look like a cache that is evicted under pressure, but eviction was not observed directly.
- The pool's `used` figure therefore says nothing about our scene. Sum our scene's own rows in the per-bitmap list instead: rows whose path is `/tmp/plugin/<id>/pkg:/images/...`, where `<id>` is the newest plugin.
- Cost per bitmap is 4 bytes per pixel after both dimensions are rounded up to a multiple of 32, even for 24-bit images. A 2400x1080 bitmap is stored as 2400x1088 (10,444,800 bytes), 1920x1080 as 1920x1088 (8,355,840), and 240x140 as 256x160 (163,840). Sizing art to multiples of 32 avoids the padding. The same URI is loaded once however many Posters use it.

**Budget:** keep the scene's own textures at or under **100 MB**. That leaves the 45 MB UI share and headroom for one stale instance. P0.7 turns this into per-asset numbers.

## Texture budget (P0.7)

The ceiling for our own resident textures is **100 MB**. Keeping 25% margin leaves **75 MB** to allocate. Sizes below are padded bytes (each dimension rounded up to 32, 4 bytes per pixel), so an allowance of 2560x1088 means up to 2546x1080 of art. The worst case counts every asset resident at once: day and night art together, both fish facings, and the launch splash.

| Asset group | Allowance (pixels) | MB | Now (2026-11-04) |
|---|---|---|---|
| Back reef: water, back rockwork | 1 x 2560x1088 | 11.1 | `reef_backdrop.png` 11.1 |
| Mid and front coral strips (P1.7 split) | 2560x608 + 2560x512 | 11.5 | `coral_acropora.png` 0.7 |
| Foreground sand lip and plants | 2560x320 | 3.3 | none |
| Seaweed, anemone, soft coral, invertebrates | 6 MB total, each sprite at most 512x512 | 6.0 | none |
| Fish rigs: 8 species plus chromis, right and left facing | 6 MB total, each layer at most 512x320 | 6.0 | 1.3 (right only) |
| Day light shafts | 2 x 512x1088 | 4.5 | none |
| Night: moon shafts, coral glow masks | 2 x 512x1088 + 6 MB of masks at half resolution | 10.5 | glow mask 0.7 |
| Caustic and ripple tiles | 2 x 512x512 + 1920x128 | 3.1 | none |
| Bubbles, sparkles | 0.5 MB total, each at most 64x64 | 0.5 | none |
| Settings screen panel | 1 x 1280x704 (backdrop shared) | 3.6 | none |
| Launch splash (resident at start) | 1920x1088 | 8.4 | `splash_fhd.png` 8.4 |
| **Total** | | **68.5** | **22.2** |

68.5 MB leaves 6.5 MB of the 75 MB unallocated. An art card that needs more takes it from that reserve or from another row, and records the move in this table.

The fill-rate limit is separate from the texture limit and is usually the one that binds. No point on screen may have more than two full-screen-sized translucent layers over the background (see Result). The shaft, caustic and ripple allowances are sized so they can each cover part of the screen. Caustics stay in the sand band, shafts are narrow, the ripple is a 128 px strip, and day and night shafts crossfade, so they never stack.

## How to measure

1. Put `ROKU_PASSWORD=<rokudev password>` in the repo `.env`. `ROKU_HOST` defaults to 192.168.1.10.
2. Run `make probe`. It builds `dist/probe.zip`, exits any running screensaver with `press k` on 8080, sideloads the probe, then waits up to `SCREENSAVER_WAIT` seconds (default 600) for the screensaver.
3. **Start the screensaver by hand:** on the TV, go to Settings > Theme > Screensavers > dev > Preview. A sideloaded screensaver does not start on install. Once ECP `query/active-app` lists `<screensaver id="dev">`, the runner captures the 8087 console for `PROBE_SECONDS` (default 140) and samples `r2d2_bitmaps` on 8080 every 2 s.
4. Results go to `docs/perf/raw/probe-<stamp>-console.log` (`PROBE stage= fish= layers= fps=` lines) and `-samples.log` (texture rows).

Notes:

- The probe counts rendered frames by observing a field that an interpolator changes every frame. The count rounds to the vsync divisors 60, 30 and 20.
- `chanperf` returns `mem and cpu data not available` for a screensaver, so CPU and RAM for the screensaver context cannot be read from 8080.
- Port 8087 can keep accepting connections after the screensaver exits, so a scripted readiness check must use ECP `active-app`, not the port.
- The console replays only its last ~200 lines on connect. Capture from the start of a run.

Raw data: `docs/perf/raw/probe-20261104-114800-*` (run 1, combined ramp) and `probe-20261104-115624-*` (run 2, separate ramps), plus `r2d2-140fish-8layers-1147.txt` (full bitmap list).
