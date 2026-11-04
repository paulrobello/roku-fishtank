# Mandarin Dragonet (Synchiropus splendidus) provenance (card P2.9, species art batch B)

Status: **pending Paul approval**. Date: 2026-11-04.

| Field | Value |
|---|---|
| File | `mandarin_dragonet_a1.png` (2048x1360 RGBA, 3,747,543 bytes) |
| Model | Higgsfield `gpt_image_2_5` (GPT Image 2.5), CLI 1.2.2 |
| Settings | `--variant sunburst --quality xhigh --resolution 2k --aspect-ratio 3:2 --background transparent` |
| Style reference | `--image-references assets/source/style-board/higgsfield/tang_g25.png` (the approved style board tang; the prompt says to take only its painting style) |
| Job id | `6b0f3d15-4c44-4095-8a50-a84a208c0d31` |
| Created | 2026-11-04T18:28:34.077345Z |
| Seed | not exposed by this model |
| Credits | 4.5 (quoted by `higgsfield generate cost`, matched by the 4.5 spend line in `higgsfield account transactions`) |
| Attempts | 1 of the allowed 2; the first result passed every check, so no second job was run |

The exact prompt is in `prompts.txt`; the full job object (params, ephemeral result URL) is in `jobs/mandarin_dragonet_a1.json`. The prompt reuses the approved tang prompt's pose wording and its painterly-realism style suffix verbatim.

## Checks

- Alpha: mode RGBA, corners 1/0/0/0, whole 1-px border max 1, 16,914 edge pixels with partial alpha (a real soft gradient, not a binary mask). The faint alpha 1-7 haze the model leaves around the subject is zeroed by `tools/art/rig.py` (`SOURCE_HAZE`). No background remover was used.
- Anatomy: Exact right-facing profile, whole fish, rounded tail complete. Wavy orange and blue-green maze pattern outlined in dark blue, spotted cheek, low first dorsal fin, fan-shaped blue pectoral fin mid-flank, away from the tail.

The rig parameters are in `config/species/mandarin_dragonet.json` and the rig check render is `docs/art/rig-check-mandarin_dragonet.png`.
