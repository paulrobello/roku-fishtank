# Phase 1: Day tank

PRD: `PRD.md` § P1. Depends on Phase 0 exit (`plans/phase-0-foundation.md`).

Every device step: exit the screensaver on the TV before `make deploy`.

## Tasks

### P1.1: Reef Tank channel shell
Replace the FishtankTest component with `components/ReefTank/ReefTank.xml/.brs`. Manifest `screensaver_title=Reef Tank`, still no `title`, with new icon and splash art (no Roku branding). Load `config/scene.json` via `ReadAsciiFile` + `ParseJson`. Build the layer stack from the PRD as named Groups inside a `camera` Group.
- Verify: `make checkall` is green. The preview shows the empty layered tank. On deploy, the device picker lists "Reef Tank".
- Depends on: P0 exit.

### P1.2: Parallax camera drift
A slow seamless loop (~90 s) on the camera translation. Each layer group gets a parallax factor from scene.json. Art is authored wider than 1920 by the drift margin.
- Verify: preview at `?speed=10x` shows no edge reveal across a full cycle (screenshot at 4 phases in the Playwright leg). On the device the motion is smooth.
- Depends on: P1.1.

### P1.3: Bubble column (pooled)
A pool of ~40 Posters sharing one bubble URI, created once. Each bubble has a rise Animation with horizontal wobble and a size and speed spread from the seeded PRNG, and recycles on completion. Source position comes from scene.json.
- Verify: unit test confirms the pool size stays constant over 10,000 simulated recycles. The preview shows a continuous column.
- Depends on: P1.1.

### P1.4: Segmented seaweed sway
Seaweed is a chain of nested Groups, each a short Poster segment with `scaleRotateCenter` at its base. Each segment rotates on a looping interpolator with phase offsets, so the curvature travels up the stalk. Count and placement come from scene.json.
- Verify: preview shows a travelling wave and no gaps between segments at max angle. Fidelity matches on the device.
- Depends on: P1.1, P1.6 (art).

### P1.5: Placeholder fish cruising in lanes
Reuse the test sprites, one per lane at lane scale and tint, crossing on simple loops so lanes and occlusion order are visible before P2.
- Verify: preview shows back-lane fish passing behind mid coral and front-lane fish in front of it.
- Depends on: P1.1.

### P1.6 (art track): Rig pipeline tool
`tools/art/` (Python, uv, Pillow) does the following:
- Trims a cutout and scales it to the budgeted size.
- Splits fish into body, tail and pectoral layers at a peduncle cut, with feathered seams.
- Writes pivots to `config/species/<name>.json` (manual overrides allowed).
- Splits decor into layer PNGs.
- Emits the night glow-overlay mask stub.

`make art` runs the pipeline reproducibly from `assets/source/`.
- Verify: running it twice gives byte-identical outputs. Rigging the style-board tang shows no seam at max tail rotation in the preview.
- Depends on: P0.8.

### P1.7 (art track): Decor and backdrop art
Generated in the approved style:
- Water gradient
- Back rockwork
- Mid coral layer
- Front coral/anemone layer
- Foreground plants and sand lip
- Seaweed segments
- Bubble sprite

Sizes come from the P0.7 budget and widths include the drift margin. Provenance goes in `assets/source/decor/`.
- Verify: Paul approves the composed day tank in the preview, and the texture total is within the budget (the script prints the sum).
- Depends on: P0.8, P0.7, P1.6.

### P1.8: Avoidance and occlusion data
Author `config/scene.json` avoidance ellipses and per-layer occluder rectangles for the P1.7 decor. A debug overlay toggles via `?debug=1`.
- Verify: the debug overlay aligns with the art in the preview screenshot.
- Depends on: P1.7.

## Exit
The day tank with real decor, drift, bubbles, seaweed and placeholder lane fish is green in `make checkall`, with new day screenshot baselines. It is deployed and observed on the Primary Roku at 60 fps and within the texture budget (per the `docs/perf.md` method).
