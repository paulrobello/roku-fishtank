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
