# Phase 3: Night mode

PRD: `PRD.md` § P3. Depends on `plans/phase-1-day-tank.md` exit. The solar and phase logic (P3.1, P3.2) can start right after P0.

Location: Woodland, CA 95776, 38.68 N, 121.77 W, stored in `scene.json`. Time zone and DST come from `roDateTime.ToLocalTime()` on the device (`America/Los_Angeles`, auto).

## Tasks

### P3.1: Solar calculator
`components/lib/solar.brs` implements NOAA sunrise/sunset/civil-twilight formulas for a lat/long and a local date, returning local minutes.
- Verify: unit tests match the NOAA Solar Calculator within 2 minutes for Woodland on 2026-03-08 (DST start), 2026-06-21, 2026-11-01 (DST end) and 2026-12-21. The reference values are recorded in the test file with their source.
- Depends on: P0.4.

### P3.2: Day/night phase machine
`lib/daynight.brs` maps local time to phase (day, dusk, night, dawn) and a 0..1 blend. Dusk runs from sunset to the end of civil twilight, and dawn mirrors it. It honors the settings override (Auto / Always day / Always night) and the preview `?time`/`?speed` clock.
- Verify: unit tests cover the boundaries, the override modes and midnight wrap.
- Depends on: P3.1.

### P3.3: Moonlight tint crossfade
A per-layer `blendColor` target (day white → moonlight blue, with per-layer values in scene.json) driven by the phase blend. A `ColorFieldInterpolator` handles the short visual easing, and a re-evaluation Timer runs each minute. Fish get the same tint by lane.
- Verify: preview screenshots at `?time=` sunset, +20 min, +45 min and 23:00 become Playwright baselines. The device shows no texture spike (per the `docs/perf.md` method).
- Depends on: P3.2, P1 exit.

### P3.4: Moon light shafts
2–3 pre-baked alpha shaft PNGs with slow opacity and sway animation, faded in by the phase blend. Day sun shafts use the same rig with warm art, if the budget allows.
- Verify: Paul reviews in the preview.
- Depends on: P3.3, P3.7.

### P3.5: Glowing coral overlays
Night-only alpha cutouts of the fluorescent coral regions in violet and teal, aligned over the darkened decor. Opacity follows the phase blend, with a slow breathing pulse.
- Verify: overlays stay aligned at all drift positions (debug screenshot). Paul reviews.
- Depends on: P3.3, P3.7.

### P3.6: Bioluminescent sparkles (pooled)
A pool of ~30 tiny sprites drifting slowly with an opacity twinkle. They are visible only at night, and the bubble column gets a faint glow tint.
- Verify: unit test confirms a constant pool. The preview at 23:00 shows the effect.
- Depends on: P3.3.

### P3.7 (art track): Night art
Shaft PNGs, glow-coral overlays (from the P1.6 mask stub plus generation), and the sparkle sprite. Sized to the P0.7 budget, with provenance.
- Verify: the texture total including night overlays stays within the budget (worst case resident). Paul approves.
- Depends on: P1.7.

## Exit
The night tank is live on the Primary Roku and switches at the real local sunset (observed once, or forced via a test build with a shifted clock). `make checkall` is green with dusk and night baselines, and Paul approves the night look on the TV.
