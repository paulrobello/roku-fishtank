# Royal Gramma (Gramma loreto) provenance (card P2.9, species art batch B)

Status: **approved by Paul on 2026-11-04** (8-species preview, BehaviorDemoScene seed 1). Date: 2026-11-04.

| Field | Value |
|---|---|
| File | `royal_gramma_a1.png` (2048x1360 RGBA, 3,410,937 bytes) |
| Model | Higgsfield `gpt_image_2_5` (GPT Image 2.5), CLI 1.2.2 |
| Settings | `--variant sunburst --quality xhigh --resolution 2k --aspect-ratio 3:2 --background transparent` |
| Style reference | `--image-references assets/source/style-board/higgsfield/tang_g25.png` (the approved style board tang; the prompt says to take only its painting style) |
| Job id | `5e5ef004-94bf-481d-a108-2aca577cafe4` |
| Created | 2026-11-04T18:28:33.589751Z |
| Seed | not exposed by this model |
| Credits | 4.5 (quoted by `higgsfield generate cost`, matched by the 4.5 spend line in `higgsfield account transactions`) |
| Attempts | 1 of the allowed 2; the first result passed every check, so no second job was run |

The exact prompt is in `prompts.txt`; the full job object (params, ephemeral result URL) is in `jobs/royal_gramma_a1.json`. The prompt reuses the approved tang prompt's pose wording and its painterly-realism style suffix verbatim.

## Checks

- Alpha: mode RGBA, corners 1/0/0/0, whole 1-px border max 1, 24,754 edge pixels with partial alpha (a real soft gradient, not a binary mask). The faint alpha 1-7 haze the model leaves around the subject is zeroed by `tools/art/rig.py` (`SOURCE_HAZE`). No background remover was used.
- Anatomy: Exact right-facing profile, whole fish, forked yellow tail complete. Violet-magenta front blending to golden-yellow rear, dark line through the eye, black spot at the front of the dorsal fin. The soft dorsal fin is yellow toward the rear, slightly more yellow than a typical wild fish.

The rig parameters are in `config/species/royal_gramma.json` and the rig check render is `docs/art/rig-check-royal_gramma.png`.
