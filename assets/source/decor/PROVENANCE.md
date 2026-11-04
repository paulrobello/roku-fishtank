# Decor provenance (card P1.7: mid and front coral strips, sand lip, plants)

Status: **awaiting Paul's review**. See the contact sheet `docs/art/contact-decor.png` and the mockups `docs/art/mockup-day.png` and `mockup-night.png`. Date: 2026-11-04.

| Field | Value |
|---|---|
| Model | Higgsfield `gpt_image_2_5` (GPT Image 2.5), CLI 1.2.2 |
| Settings | `--variant sunburst --quality xhigh --resolution 2k --background transparent`, aspect per file below |
| Style reference | `--image-references assets/source/style-board/higgsfield/coral_g25.png` (the prompt says to take only its painting style) |
| Seed | not exposed by this model |
| Credits | 4.5 per image (quoted by `higgsfield generate cost`). The whole P1.7 + P4.6 batch was 14 images = 63 credits: account balance 1049 before, 986 after |
| Attempts | 1 per file. Every first result passed the alpha check, so no retries were run |

The exact prompts are in `prompts.txt` (the subject, then the shared painterly-realism suffix from `style-board/higgsfield/prompts_style.txt`, then the reference note). The full job objects (params, ephemeral result URL) are in `jobs/<name>.json`.

| File | Size | Aspect | Job id | Created |
|---|---|---|---|---|
| `mid_coral_a.png` | 2688x1152 | 21:9 | `b291c575-100c-4b50-928d-231b9bd18b4f` | 2026-11-04T20:45:26Z |
| `mid_coral_b.png` | 2688x1152 | 21:9 | `be1c16a8-b8b7-4bbd-a6ce-50c55f5d437d` | 2026-11-04T20:45:47Z |
| `front_coral_a.png` | 2688x1152 | 21:9 | `c122639a-cee9-4655-93e7-bfdda8166114` | 2026-11-04T20:45:53Z |
| `front_coral_b.png` | 2688x1152 | 21:9 | `3a78b0d2-5f6f-4f91-b1bb-80f094bd3138` | 2026-11-04T20:45:58Z |
| `sand_lip.png` | 2688x1152 | 21:9 | `68c5fe5f-8bfa-48ae-83fe-edaec2d69371` | 2026-11-04T20:46:04Z |
| `plant_cluster.png` | 1744x2336 | 3:4 | `9dd0b1f2-d739-47fc-9132-c5f38def9f82` | 2026-11-04T20:46:10Z |
| `rock_pillar.png` | 1744x2336 | 3:4 | `310cb623-4c98-4322-929e-93a039f388be` | 2026-11-04T20:46:15Z |

## Checks

- Alpha: every file is native RGBA with all four corners at alpha 0 or 1. The 1-px border maximum is 1–7, which is the generator's faint haze. The pipeline zeroes alpha below 8, the same rule `rig.py` uses. No background remover was used.
- `plant_cluster.png`: the tallest blade reaches the top row (border max 12). The pipeline fades the top 3% of rows so no cut line shows.

## Runtime derivation

`uv run tools/art/reef_decor.py` turns these originals into `images/decor/`. The output is deterministic and carries no PNG metadata.

- **Mid strip.** `mid_coral_a` and `mid_coral_b` are placed side by side at one scale with a 96 px crossfade at the join, giving a strip 2560 wide. The strip is cut into ten 256-px column tiles (`mid_coral_0..9.png`), and each tile is cropped to its own alpha box. Per-tile cropping means the transparent water above low parts of the reef is never drawn, which saves fill rate.
- **Front clumps.** Each front frieze is split at the low points between its clumps: a has 3 clumps and b has 2. The cut edges are feathered over 48 source px. The clumps are scaled by 0.42 and then cut into 192-px column chunks (`front_coral_<clump>_<chunk>.png`).
- **Sand lip.** Source rows below 680 become the 2560x128 sand band (`sand_lip.png`). Rows above become 96-px column chunks of the algae tufts (`sand_tuft_*.png`), which sit exactly on the band.
- **Single sprites.** `rock_pillar.png` (440 tall) and `plant_cluster.png` (360 tall).

Placements, layers and animation are proposed in `docs/art/placement-proposal.md`.
