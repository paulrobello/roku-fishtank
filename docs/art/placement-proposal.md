# Placement proposal: P1.7 decor, P3.7 night art, P4.6 reef extras

This document proposes placements only. `config/scene.json` and the ReefTank components are not changed. Exact per-file sizes, positions and rig pivots are in `docs/art/placement-proposal.json`, which `tools/art/reef_decor.py` writes on every run.

All coordinates are design pixels at 1920x1080 inside the camera Group, at camera offset 0. Every chunk of a group shares one layer and one parallax value, and sits at integer positions, so the joins between chunks are invisible.

## Ground line and drift

- **Ground line.** The sand band is 2560x128 at (-320, 952). Above y 1052 its top edge is bumpy and partly transparent. From y 1052 down, 99% of its columns are solid (alpha above 0.9 to the bottom). Everything with a flat bottom cut line (mid tiles, front clumps, rock pillar) ends at y = 1060 (`_ground_y` in the JSON), 8 px inside that solid sand.
- **Drift margin.** The strips are 2560 wide, with 320 px of margin on each side. The camera drift amplitude A must satisfy A × parallax ≤ 320 for each layer:

| Layer | Parallax | Maximum A |
|---|---|---|
| Foreground | 1.0 | 320 |
| Front coral | 0.8 | 400 |
| Mid coral | 0.6 | 533 |

  The backdrop (313 px margin, parallax 0.2) allows 1565. The binding limit is therefore **A ≤ 320 px**.
- **Chunks off the strip ends.** Some front clumps start outside the strip (`front_coral_a0` at x -250, `b0` at x 1960). Only the 2560 strip span matters for edge reveal.

## Day layers (back to front)

| Asset (files) | Layer (scene.json id) | Position / anchor | Drift | Day / night | Animation |
|---|---|---|---|---|---|
| `fx/shaft_day_a.png`, `shaft_day_b.png` 256x1088 | `lightShafts` | top at y -4, x 360 and 1160 | parallax 0.25 | day. Crossfade with the moon shafts by phase opacity, so the two pairs never stack | opacity breathe 0.5–0.8 over 7–11 s, out of phase. Optional ±4° sway (`scaleRotateCenter` at the top centre) |
| `decor/mid_coral_0..9.png` (256 wide, 303–539 tall) | `midCoral` | strip origin (-320, 1060 - 539), each tile at its JSON x/y | 0.6 | both; the night `blendColor` multiply darkens it | none (static) |
| `decor/rock_pillar.png` 230x440 | `midCoral` | (1520, 616), base on the ground line | 0.6 | both | none. It is the tall back-lane occluder |
| `extras/sea_fan_seg0..2` 270 wide, 340 tall in total | `midCoral` | base pivot at (640 + 149, 960) | 0.6 | both | 3-segment chain (P1.4 technique): rotation ±2°, ±3°, ±4° from base to tip, period 6–8 s, phase lag 0.4 s per segment, driven by the shared current value (P4.2) |
| `decor/front_coral_{a0,a1,a2,b0,b1}_N.png` (192-wide chunks, 362–474 tall) | `frontCoral` | clump x: a0 -250, a1 330, b1 760, a2 1460, b0 1960. Bottoms on the ground line (y 1060) | 0.8 | both | none |
| `extras/anemone_body.png` 315x240 | `frontCoral` | (1080, 728), bottom at y 968 | 0.8 | both | none. The clownfish host point is about (1238, 760) |
| `extras/anemone_tentacle_seg0..2` 17 wide, 72 tall per chain | `frontCoral` | 6 to 8 chains across the crown, bases at y ≈ 760–790, x = 1150–1340 at ~34 px spacing, drawn after the body | 0.8 | both | 3-segment chain: ±6°, ±9°, ±12°, period 3–4 s, random phase per chain. Clownfish swim between the body and the chains (P4.1) |
| `extras/soft_coral_seg0..2` 206 wide, 280 tall | `frontCoral` | base pivot at (1700 + 126, 960) | 0.8 | both | 3-segment chain: ±2°, ±3°, ±5°, period 7–9 s, from the shared current |
| `extras/shrimp_body_{r,l}` + `shrimp_antennae_{r,l}` 201x130 | front lane (P4.3) | walks on the sand or rock with its feet at y ≈ 990 | lane | both | translate along the ground. The antennae Poster rotates ±6° about its pivot (r: (169, 72), l: (32, 72) in sprite pixels) every 0.6–1.2 s. Swap the r and l files to turn |
| `extras/crab.png` 150x82 | front lane | on the sand, feet at y ≈ 1016 | lane | both | side-to-side scuttle (translate x) with pauses. No mirror needed |
| `extras/starfish.png` 112x110 | front lane | on rock or the front glass, (1300, 866) | lane | both | very slow translate, ±3° rotation drift |
| `decor/sand_lip.png` 2560x128 | `foreground` | (-320, 952) | 1.0 | both | none |
| `decor/sand_tuft_0..22.png` (96-wide chunks) | `foreground` | strip origin (-320, 952 - 382), each at its JSON x/y | 1.0 | both | none (static algae). For movement later, sway whole chunks ±1.5° about their bottom centre |
| `decor/plant_cluster.png` 264x360 | `foreground` | (-120, 690), left corner framing. A second copy can go at x ≈ 1800 for free, since it shares the same URI | 1.0 | both | ±2° sway about the bottom centre, period 6 s |
| `fx/caustic_a.png`, `caustic_b.png` 512x512 | new caustics Group in `foreground`, after the sand band | tiled across the sand band, in a Group with `clippingRect` (0, 952, 2560, 128) in strip space | 1.0 | day at opacity 0.3 / 0.22. Night: lower to about 0.1, or hide (see fill rate) | a translate loop of 512 px in different directions (a: +x+y over 40 s, b: −x+y over 55 s). Seamless, because the tiles are periodic |
| `fx/ripple.png` 1920x128 | `surfaceRipple` | two copies side by side at y 0 | 0.3 | both. Day tint 0xE1F5FFFF opacity 0.6, night 0x7896C8FF opacity 0.35 | translate loop of 1920 px over 60 s, plus a ±4 px vertical bob. Periodic in x |

## Night overlays (P3.7)

| Asset | Layer | Position | Animation |
|---|---|---|---|
| `night/moon_shaft_a.png`, `moon_shaft_b.png` 256x1088 | `lightShafts` | top at y -4, x 520 and 1300 | `blendColor` 0xAAC8FFFF. Opacity follows the phase blend (max 0.55 / 0.45) with a slow breathe |
| `night/glow_mid_coral_*`, `glow_front_coral_*`, `glow_backdrop_*` (half resolution) | the same layer as the sprite named in `over` | the JSON x/y, with **`scale` 2** (`scaleRotateCenter` at 0,0) | alpha-over (no additive blending on the device). Opacity = phase blend × (0.7 + 0.15 sin), breathing over 5–9 s. The colour is baked in, so `blendColor` stays white |
| `night/sparkle.png` 32x32 | `bubbles` | pool of ~30 (P3.6) | `blendColor` 0x96FFE6FF, scale 0.5–1.0, opacity twinkle, slow drift |

Two existing files are not used in this proposal: `decor/coral_acropora.png` and its glow mask. The mid strip replaces the stand-in coral. Both stay in the texture total until P1.8 removes them from `scene.json`.

## Occluders for weaving (P1.8 input)

Each opaque mass below is big enough to hide a 233x154 body at lane scale.

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

The sum of on-screen Poster rectangles for this art, excluding the backdrop and the fish:

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

This needs a device check (P1/P3 exit) before the art is called final.
