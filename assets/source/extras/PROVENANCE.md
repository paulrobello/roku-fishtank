# Reef extras provenance (card P4.6: anemone, soft coral, sea fan, invertebrates)

Status: **awaiting Paul's review**. See `docs/art/contact-extras.png` and the mockups `docs/art/mockup-day.png` and `mockup-night.png`. Date: 2026-11-04. The procedural caustic and ripple tiles from P4.6 are recorded in `assets/source/night/PROVENANCE.md`.

| Field | Value |
|---|---|
| Model | Higgsfield `gpt_image_2_5` (GPT Image 2.5), CLI 1.2.2 |
| Settings | `--variant sunburst --quality xhigh --resolution 2k --background transparent`, aspect per file below |
| Style reference | `--image-references`: `assets/source/style-board/higgsfield/coral_g25.png` for the coral and anemone, `tang_g25.png` for the animals. The prompt says to take only the reference's painting style |
| Seed | not exposed by this model |
| Credits | 4.5 per image (quoted by `higgsfield generate cost`). The whole P1.7 + P4.6 batch was 14 images = 63 credits: account balance 1049 before, 986 after |
| Attempts | 1 per file. Every first result passed the alpha check |

The exact prompts are in `prompts.txt`. The full job objects are in `jobs/<name>.json`.

| File | Size | Aspect | Reference | Job id | Created |
|---|---|---|---|---|---|
| `anemone_body.png` | 2336x1744 | 4:3 | coral_g25 | `d4eb738a-cfda-406b-97fe-d30f6af37e4c` | 2026-11-04T20:46:22Z |
| `anemone_tentacle.png` | 1520x2688 | 9:16 | coral_g25 | `c496b1ee-7a0d-4644-acca-b2f3ecc72f12` | 2026-11-04T20:46:28Z |
| `sea_fan.png` | 1792x2240 | 4:5 | coral_g25 | `69076c3b-23ff-45db-b02e-3e4985c4d3bf` | 2026-11-04T20:46:35Z |
| `soft_coral.png` | 1744x2336 | 3:4 | coral_g25 | `d17a12e3-372f-44ad-958e-d8283303668f` | 2026-11-04T20:46:42Z |
| `shrimp.png` | 2048x1360 | 3:2 | tang_g25 | `b394d6b0-fd72-4878-972f-ed3a55226722` | 2026-11-04T20:46:49Z |
| `crab.png` | 2048x1360 | 3:2 | tang_g25 | `4c582077-1e8e-4b85-8b13-d6056c5c4f1c` | 2026-11-04T20:46:53Z |
| `starfish.png` | 2048x2048 | 1:1 | tang_g25 | `b1f97229-0898-46f6-87e0-8f764a050f31` | 2026-11-04T20:47:02Z |

## Checks

- Alpha: every file is native RGBA with corners at alpha 0 or 1 and a 1-px border maximum of 1–2. The pipeline zeroes alpha below 8.
- Anatomy: the shrimp is a Lysmata cleaner shrimp in exact right profile, with a red back stripe split by a white line and white antennae. The crab is drawn from the front so it can scuttle sideways without a mirrored copy. The starfish is seen from above.

## Runtime derivation

`uv run tools/art/reef_decor.py` writes `images/extras/`. The output is deterministic and carries no PNG metadata.

- **Sway chains** (anemone tentacle 72 px, sea fan 340 px, soft coral 280 px). The trimmed sprite is cut into 3 horizontal bands, base to tip. Every band above the base carries 4–8 extra rows below its boundary, with alpha ramping in, so a rotated segment never opens a gap. The pivots (bottom-centre of each band) and the attach point for the next segment are in `docs/art/placement-proposal.json`.
- **Shrimp.** One canvas is split into a body layer and an antennae layer. The antennae layer holds the pixels above the back line or in front of the head, so P4.3 can wiggle the antennae about their base pivot. The left-facing copies (`shrimp_*_l.png`) are pre-mirrored because the device ignores a negative `scale.x`.
- **Single sprites.** `anemone_body.png`, `crab.png`, `starfish.png`.
