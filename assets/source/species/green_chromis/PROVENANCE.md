# Green Chromis (Chromis viridis) provenance (card P2.9, species art batch B)

Status: **approved by Paul on 2026-11-04** (8-species preview, BehaviorDemoScene seed 1). Date: 2026-11-04.

| Field | Value |
|---|---|
| File | `green_chromis_a1.png` (2048x1360 RGBA, 3,938,775 bytes) |
| Model | Higgsfield `gpt_image_2_5` (GPT Image 2.5), CLI 1.2.2 |
| Settings | `--variant sunburst --quality xhigh --resolution 2k --aspect-ratio 3:2 --background transparent` |
| Style reference | `--image-references assets/source/style-board/higgsfield/tang_g25.png` (the approved style board tang; the prompt says to take only its painting style) |
| Job id | `eb398ad2-4511-43f9-9c8c-1ca376ad7376` |
| Created | 2026-11-04T18:28:32.065259Z |
| Seed | not exposed by this model |
| Credits | 4.5 (quoted by `higgsfield generate cost`, matched by the 4.5 spend line in `higgsfield account transactions`) |
| Attempts | 1 of the allowed 2; the first result passed every check, so no second job was run |

The exact prompt is in `prompts.txt`; the full job object (params, ephemeral result URL) is in `jobs/green_chromis_a1.json`. The prompt reuses the approved tang prompt's pose wording and its painterly-realism style suffix verbatim.

## Checks

- Alpha: mode RGBA, corners 0/0/0/0, whole 1-px border max 1, 27,109 edge pixels with partial alpha (a real soft gradient, not a binary mask). The faint alpha 1-7 haze the model leaves around the subject is zeroed by `tools/art/rig.py` (`SOURCE_HAZE`). No background remover was used.
- Anatomy: Exact right-facing profile, whole fish, deeply forked tail complete. Pale apple-green back to aqua-blue belly with pearly scale sheen, translucent green fins, no markings. Body is a little deep for C. viridis but reads correctly at 80 px.

The rig parameters are in `config/species/green_chromis.json` and the rig check render is `docs/art/rig-check-green_chromis.png`.
