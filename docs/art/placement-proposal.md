# Placement proposal: P1.7 decor, P3.7 night art, P4.6 reef extras

This proposal landed. P1.8 placed the decor into `config/scene.json` from this document, `tools/art/night_config.py` copies the glow overlays into `config/night.json`, and `components/Extras` reads the reef extras from `config/extras.json`; the extras and glow positions still come from `docs/art/placement-proposal.json`, which `tools/art/reef_decor.py` writes on every run. The tables below state what shipped; the few items that did not land are marked where they appear.

All coordinates are design pixels at 1920x1080 inside the camera Group, at camera offset 0. Every chunk of a group shares one layer and one parallax value, and sits at integer positions, so the joins between chunks are invisible.

## Ground line and drift

- **Ground line.** The sand band is 2560x128 at (-320, 952). Above y 1052 its top edge is bumpy and partly transparent. From y 1052 down, 99% of its columns are solid (alpha above 0.9 to the bottom). Everything with a flat bottom cut line (mid tiles, front clumps, rock pillar) ends at y = 1060 (`_ground_y` in the JSON), 8 px inside that solid sand.
- **Drift margin.** The strips are 2560 wide, with 320 px of margin on each side. The camera drift amplitude A must satisfy A × parallax ≤ 320 for each layer:

| Layer | Parallax | Maximum A |
|---|---|---|
| Foreground | 1.0 | 320 |
| Front coral | 0.8 | 400 |
| Mid coral | 0.6 | 533 |

  The backdrop (313 px margin, parallax 0.2) allows 1565. The binding limit is therefore **A ≤ 320 px**. The shipped drift runs at amplitude x 80 over a 90 s loop (`config/scene.json` `drift`), well inside the limit.
- **Chunks off the strip ends.** Some front clumps start outside the strip (`front_coral_a0` at x -250, `b0` at x 1960). Only the 2560 strip span matters for edge reveal.

## Day layers (back to front)

| Asset (files) | Layer (scene.json id) | Position / anchor | Drift | Day / night | Animation |
|---|---|---|---|---|---|
| `fx/shaft_day_a.png`, `shaft_day_b.png` 256x1088 | `lightShafts` | top at y -4, x 264 and 1064, drawn 448 wide from the 256 px art (`config/night.json` `dayShafts`) | parallax 0.25 | day. Crossfades with the moon shafts by phase opacity (day fades as 1 − 2 × blend), so the two pairs never stack | opacity breathe 0.36–0.54 / 0.32–0.50 over 9–11 s, out of phase, plus a shimmer loop: flicker to 0.8, sway up to 8 px at the bottom, width wobble 4% |
| `decor/mid_coral_0..9.png` (256 wide, 303–539 tall) | `midCoral` | strip origin (-320, 1060 - 539), each tile at its JSON x/y | 0.6 | both; the night `blendColor` multiply darkens it | none (static) |
| `decor/rock_pillar.png` 230x440 | `midCoral` | (1520, 616), base on the ground line | 0.6 | both | none. It is the tall back-lane occluder |
| `extras/sea_fan_seg0..2` 270 wide, 340 tall in total | `midCoral` | base pivot at (640 + 149, 960) = (789, 960) | 0.6 | both | 3-segment chain (P1.4 technique): rotation ±2°, ±3°, ±4° from base to tip, period 7 s, phase lag 0.4 s per segment, driven by the shared current (P4.2; `config/extras.json` `chains`) |
| `decor/front_coral_{a0,a1,a2,b0,b1}_N.png` (192-wide chunks, 362–474 tall) | `frontCoral` | clump x: a0 -250, a1 330, b1 760, a2 1460, b0 1960. Bottoms on the ground line (y 1060) | 0.8 | both | none |
| `extras/anemone_body.png` 315x240 | `frontLane` (so the hosted clownfish draw between the body and the tentacles) | (1080, 728), bottom at y 968 | 0.9 | both | none. The clownfish host point is (1238, 752), radius 28 (`config/extras.json` `anemone.host`) |
| `extras/anemone_tentacle_seg0..2` 17 wide, 72 tall per chain | `frontLane`, kept last in the lane so rebuilt fish still draw behind them | 7 chains across the crown, bases at y 774–800, x = 1152–1338 at ~30 px spacing, drawn after the body | 0.9 | both | 3-segment chain: ±6°, ±9°, ±12°, period 3.5 s (current period 7 x periodScale 0.5), random phase per chain. Clownfish swim between the body and the chains (P4.1) |
| `extras/soft_coral_seg0..2` 206 wide, 280 tall | `frontCoral` | base pivot at (1700 + 126, 960) = (1826, 960) | 0.8 | both | 3-segment chain: ±2°, ±3°, ±5°, period 7 s, from the shared current |
| `extras/shrimp_body_{r,l}` + antennae, leg and swimmeret art, 201x130 | `foreground`, inserted at index 1 (right after the sand lip, so the tufts drawn later cover it) | walks the sand between x 60 and 1300 at y 914 (top-left of the sprite, feet on the sand) | 1.0 | both | two leg sets rock ±6° in opposite phase, one swing per 12 px of travel, still while paused; the swimmerets paddle ±10° every 0.8 s. The antennae rotate ±6° about the body pivot (r: (169, 72), l: (32, 72) in sprite pixels) every 0.9 s. Turns like a fish: a group narrows while the pre-mirrored r and l art swap |
| `extras/crab_body.png` + `crab_legs_{l,r}` + `crab_claw_{l,r}` 150x82 | `frontLane`, at index 0 (behind the front fish; the sand lip edge and the foreground plants draw over it) | walks the sand between x 880 and 1560 at y 904 (top-left of the sprite, feet on the sand) | 0.9 | both | sideways walk: each leg pair rocks ±7° about its hip, one swing per 14 px of travel, with a 1 px bob and pauses; the claws sway ±5° every 2.8 s. No mirror needed |
| `extras/starfish.png` 112x110 | `frontLane` (draws in the anemone group, behind the fish) | on rock or the front glass, (1300, 866), creeping between x 1270 and 1340 | 0.9 | both | very slow translate (1.5 px/s) with long pauses, ±3° rotation drift over 40 s |
| `decor/sand_lip.png` 2560x128 | `foreground` | (-320, 952) | 1.0 | both | none |
| `decor/sand_tuft_0..22.png` (chunks up to 96 px wide) | `foreground` | strip origin (-320, 952 - 382), each at its JSON x/y | 1.0 | both | none (static algae). For movement later, sway whole chunks ±1.5° about their bottom centre — not implemented |
| `decor/plant_cluster.png` 264x360 | `foreground` | (-120, 690), left corner framing. A second copy at x ≈ 1800 remains free (same URI); none is placed | 1.0 | both | none. The proposed ±2° sway about the bottom centre (period 6 s) did not land; decor is static |
| `fx/caustic_a.png`, `caustic_b.png` 512x512 | caustics Group in `foreground`, inserted at index 1, right after the sand lip (so plants and critters draw over it) | tiled over the solid lower sand band only, clip (-320, 1016, 2560x64) in strip space — a taller clip would run the sand lip's ragged, partly transparent top as a line across the tiles | 1.0 | day at opacity 0.3 / 0.22, fading with the night level and hidden from nightLevel 0.9 up (`hideAt`; the fill-rate option below) | a translate loop of 512 px in different directions (a: +x+y over 40 s, b: −x+y over 55 s). Seamless, because the tiles are periodic |
| `fx/ripple.png` 1920x128 | `surfaceRipple` | **Not in the tank.** The ripple shipped with the P4.1–P4.5 reef extras and was removed on 2026-11-04 at Paul's request; `extrasBuildRipple` skips the absent `ripple` key in `config/extras.json`, the layer stays in `config/scene.json` empty, and the art remains in `images/fx/` | 0.3 | both (proposed). Day tint 0xE1F5FFFF opacity 0.6, night 0x7896C8FF opacity 0.35 | proposed: translate loop of 1920 px over 60 s, plus a ±4 px vertical bob. Periodic in x |

## Night overlays (P3.7)

| Asset | Layer | Position | Animation |
|---|---|---|---|
| `night/moon_shaft_a.png`, `moon_shaft_b.png` 256x1088 | `lightShafts` | top at y -4, x 424 and 1204, drawn 448 wide | `blendColor` 0xAAC8FFFF. Opacity follows the phase blend (max 0.15 / 0.12) with a slow breathe and the same shimmer loop as the day shafts, gentler (flicker 0.15, sway 6 px) |
| `night/glow_mid_coral_*`, `glow_front_coral_*`, `glow_backdrop_*` (half resolution) | the same layer as the sprite named in `over`, in a glow Group inserted right after it (decor drawn later in the layer stays in front) | the JSON x/y, with **`scale` 2** (`scaleRotateCenter` at 0,0). Only sprites whose id starts with a prefix in `glow.groups` are built — the front clumps by default; the mid and backdrop items sit in `config/night.json` unbuilt (fill-rate option 2 below) | alpha-over (no additive blending on the device). Opacity = phase blend × a breathe between 0.55 and 0.85 over 5–9 s. The colour is baked in, so `blendColor` stays white |
| `night/sparkle.png` 32x32 | `bubbles` | pool of ~30 (P3.6) | `blendColor` 0x96FFE6FF, scale 0.5–1.0, opacity twinkle, slow drift |

The stand-in coral this proposal replaced is gone: P1.8 removed `decor/coral_acropora.png`, its glow mask and the `coralAcropora` decor entry, and the mid strip took their place.

## Occluders for weaving (P1.8 input)

P1.8 shipped occluders measured from the sprites themselves (pixels at alpha ≥ 0.9) in `config/scene.json` `population.occluders`, not these hand estimates — the lists below were the placement input to that measurement, and `?debug=1` in the preview draws the shipped rects. Each opaque mass below is big enough to hide a 233x154 body at lane scale.

- **Back lane** (y 260–760), hidden by `midCoral`:
  - rock pillar, x 1540–1730, y 640–1060
  - mid tiles: the reef mass is solid over roughly y 660–1060, across x -320–2240
  - sea fan, x 650–900, y 640–900. It is lacy, so treat it as a partial occluder only
- **Mid lane** (y 220–840), hidden by `frontCoral`:
  - front clump a1, x 340–700, y 660–1060
  - b1, x 770–1490, y 620–1060
  - a2, x 1470–1800, y 620–1060
  - anemone body, x 1090–1380, y 740–960

## Fill rate (`tools/art/reef_review.py`, maps in `docs/art/overdraw-{day,night}.png`)

Proposal-time output of the review tool: the sum of on-screen Poster rectangles for this art, excluding the backdrop and the fish:

| Scene | Full-screen equivalents |
|---|---|
| Day | 1.81–1.88 |
| Night with caustics | 2.40–2.50 |
| Night with caustics hidden | about 2.15 |

The per-pixel worst case is 8 rectangles in the sand band at the bottom of the screen. That band holds the sand, two caustics, the bottoms of the mid and front tiles, and the plants. Elsewhere the reef area is 3–4, and the open water is 0–1.

The day total is just under the measured limit of two full-screen layers. **At night the proposed defaults do not meet the limit (2.45 against 2.0)**, mostly because of the glow masks (about 0.8 screens). The combination that gets under it is to hide the caustics at night and glow only the front clumps, which brings night to about 1.7. Options for the scene agents, ordered by gain:

1. Hide the caustics at night instead of dimming them (0.3).
2. Fade the glow masks only on the front clumps and skip the mid ones (0.45).
3. Drop the second caustic layer (0.15).

The shipped build took options 1 and 2 as defaults: the caustics hide at night (`hideAt` 0.9 in `config/extras.json`) and only the front clumps glow (`glow.groups` in `config/night.json`), which holds night near the day total. The P1/P3 device checks have since closed; `docs/perf.md` records the measured texture and fill-rate results.
