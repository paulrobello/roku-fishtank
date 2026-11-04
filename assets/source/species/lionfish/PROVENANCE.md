# Lionfish (Pterois volitans) provenance (card P2.9, species art batch B)

Status: **approved by Paul on 2026-11-04** (8-species preview, BehaviorDemoScene seed 1). Date: 2026-11-04.

| Field | Value |
|---|---|
| File | `lionfish_a1.png` (2336x1744 RGBA, 6,900,967 bytes) |
| Model | Higgsfield `gpt_image_2_5` (GPT Image 2.5), CLI 1.2.2 |
| Settings | `--variant sunburst --quality xhigh --resolution 2k --aspect-ratio 4:3 --background transparent` |
| Style reference | `--image-references assets/source/style-board/higgsfield/tang_g25.png` (the approved style board tang; the prompt says to take only its painting style) |
| Job id | `8b33eee4-7382-4df7-8faf-bae4d38a9a15` |
| Created | 2026-11-04T18:28:33.226033Z |
| Seed | not exposed by this model |
| Credits | 4.5 (quoted by `higgsfield generate cost`, matched by the 4.5 spend line in `higgsfield account transactions`) |
| Attempts | 1 of the allowed 2; the first result passed every check, so no second job was run |

The exact prompt is in `prompts.txt`; the full job object (params, ephemeral result URL) is in `jobs/lionfish_a1.json`. The prompt reuses the approved tang prompt's pose wording and its painterly-realism style suffix verbatim.

## Checks

- Alpha: mode RGBA, corners 0/0/0/0, whole 1-px border max 1, 114,783 edge pixels with partial alpha (a real soft gradient, not a binary mask). The faint alpha 1-7 haze the model leaves around the subject is zeroed by `tools/art/rig.py` (`SOURCE_HAZE`). No background remover was used.
- Anatomy: Exact right-facing profile at 4:3 so the spines and fans fit (border alpha max 1, nothing clipped). Maroon and white vertical bands, separate striped dorsal spines, large striped pectoral fans spread below the body ending well before the tail stalk, spotted translucent rounded tail, supraorbital tentacles. Spiky barbels at the mouth are a little exaggerated.

The rig parameters are in `config/species/lionfish.json` and the rig check render is `docs/art/rig-check-lionfish.png`.
