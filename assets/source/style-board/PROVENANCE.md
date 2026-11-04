# Style board provenance (card P0.8)

Art direction: painterly realism, side profile facing right, no logos, text or watermarks.

- Tool: moss-image MCP (local backend at `127.0.0.1:18765`), model **MOSS-Image-SFT** (`MOSS-Image-SFT-Q4_0.gguf`, 4-step turbo LoRA `moss_4step_f16`, text encoder `Qwen3.5-9B-Q4_K_M`, VAE `flux2_ae_small`, stable-diffusion.cpp, euler sampler, CFG 1.0, guidance 3.5).
- Quality: `standard` for every image. No Higgsfield or other paid provider was used.
- Date: 2026-11-04.
- Approval of this local pass: **superseded**. Paul judged it too flat/clip-art; the board continues with the Higgsfield pass below.

## Files

| File | What it is |
|---|---|
| `tang_v1.png`, `tang_v2.png` | Royal blue tang RGBA cutouts |
| `coral_v1.png`, `coral_v2.png`, `coral_v3.png` | Coral RGBA cutouts (acropora, bubble, brain) |
| `backdrop_v1.png` … `backdrop_v3.png` | Backdrop strips, RGB |
| `originals/*_keyed.png` | Untouched keyed generator outputs for each cutout. They carry the full generation metadata (seed, size, wrapped prompt) in the PNG `parameters` text chunk and can be re-matted later |
| `contact_sheet.png` | All kept variants on dark blue (#0C2048) with labels, built with Pillow |

The backdrops were generated with `upscale_2x`, which writes the PNG without the metadata chunk. The kept backdrop file is the generator output byte-for-byte, so no separate original is stored. Its seed is the explicit seed passed in the call.

## How cutouts are made

`generate_cutout_object` wraps the object prompt in a chroma-key layout caption: a studio isolation shot on a flat solid key colour, the object inside a centred layout box with a 10% margin, no shadows. The backend then keys out the background, removes enclosed holes, mattes the alpha and suppresses spill. Call parameters for every cutout: `tolerance=28`, `use_layout_box=true`, `transparent=true`, `upscale_2x=false`. The exact object prompt is below. The full wrapped caption is in each `originals/*_keyed.png`.

## Alpha check method

Pillow + numpy + scipy on the kept RGBA file:
- mode is RGBA, all four corners alpha 0, maximum alpha on the whole 1-px border 0;
- key spill: share of edge pixels (the 2-px rim of alpha > 16) tinted toward the key colour, compared with the interior (6 px inside the rim);
- enclosed transparent regions (holes inside the silhouette).

Tang tail separability: per-column count of opaque runs (alpha > 128) from the tail tip to past the narrowest point of the peduncle.

## Kept images

### tang_v1.png
- Source output: `moss_cutout_20261104_081336_2da03d` (`_rgba.png` → `tang_v1.png`, keyed → `originals/tang_v1_keyed.png`)
- Call: `generate_cutout_object`, aspect 16:9, size large, bg_color green, seed **424242** (embedded seed 424242, matches)
- Dimensions: 1024x576 RGBA
- Prompt: "Photorealistic painted illustration of one royal blue tang fish (Paracanthurus hepatus) seen exactly from the side, swimming to the right, the complete fish including the full forked yellow tail fin. Saturated royal-blue body, black palette-shaped band, yellow tail with black margins, a narrow tail stalk between body and tail. Long dorsal and anal fins hug the body outline and end well before the tail fin, so the tail fin stands alone with clear space around it. Small pectoral fin on the flank. Detailed scales, glistening wet skin, luminous colors, painterly realism, aquarium field-guide quality. No text, no logo, no watermark."
- Alpha check: PASS. Corners 0/0/0/0, border max 0, green tint on edge 0.0% (interior 0.0%), 0 enclosed holes.
- Tail: narrowest peduncle column x=266, 75 px tall (body max ~450 px), a single opaque run. The tail-fin region is one run except the two forked lobes at the tip. Dorsal and anal fin tips start right after the narrowest column (x≈267–271 show 2–3 runs) without touching the tail fin, so a vertical cut a few px tail-side of x=266 separates the tail cleanly.

### tang_v2.png
- Source output: `moss_cutout_20261104_080847_a24917`
- Call: `generate_cutout_object`, aspect 16:9, size large, bg_color green, seed **777001** (embedded 777001, matches)
- Dimensions: 1024x576 RGBA
- Prompt: "A single real royal blue tang reef fish (Paracanthurus hepatus), exact side profile facing right, whole fish visible from snout to the tips of the tail fin, nothing cropped. Deep electric-blue oval body with the true black palette marking from the eye sweeping back to the tail, bright lemon-yellow forked tail fin outlined in black, a short slender tail stalk clearly separating the body from the tail fin. Dorsal and anal fins run along the back and belly and stop before the tail stalk, translucent blue with fine black edges, small clear pectoral fin behind the gill. Near-photoreal painterly realism like a fine natural-history oil painting: subtle fine scale texture, wet glossy sheen, soft light from above, rich luminous color. No text, no logo, no watermark."
- Alpha check: PASS. Corners 0, border max 0, green edge tint 0.0% (interior 0.0%), 0 enclosed holes.
- Tail: narrowest peduncle column x=258, 69 px tall, a single run. Fin tips begin at x≈259, same layout as tang_v1.

### coral_v1.png (branching acropora)
- Source output: `moss_cutout_20261104_081004_64ef22`
- Call: `generate_cutout_object`, aspect 4:3, size large, bg_color green, seed **5150** (embedded 5150, matches)
- Dimensions: 880x656 RGBA
- Prompt: "One branching staghorn acropora coral colony, a complete freestanding coral head with many thick antler-like branches with rounded tips spreading up and outward from a short rocky base, side view. Warm living colors: soft mustard-tan branches with glowing lavender-blue growing tips, tiny polyp corallite texture over every branch. Near-photoreal painterly realism like a fine natural-history oil painting, luminous saturated color, soft light from above. The whole coral fully visible, nothing cropped. No text, no logo, no watermark."
- Alpha check: PASS. Corners 0, border max 0, green edge tint 0.0% (interior 0.0%). 7 enclosed transparent regions (4,368 px), which are the real gaps between branches.

### coral_v2.png (bubble coral)
- Source output: `moss_cutout_20261104_081025_a8d105`
- Call: `generate_cutout_object`, aspect 4:3, size large, bg_color green, seed **8086** (embedded 8086, matches)
- Dimensions: 880x656 RGBA
- Prompt: "One rounded bubble coral (Plerogyra) colony, a complete dome of plump translucent pearl-like bubbles in soft pink and lavender with pale highlights, sitting on a small rough rock base, side view. Each bubble glossy and slightly translucent with subtle veining. Near-photoreal painterly realism like a fine natural-history oil painting, luminous color, soft light from above. The whole coral fully visible, nothing cropped. No text, no logo, no watermark."
- Alpha check: PASS. Corners 0, border max 0, green edge tint 0.0% (interior 0.0%), 0 enclosed holes.

### coral_v3.png (brain coral)
- Source output: `moss_cutout_20261104_081249_6b944f`
- Call: `generate_cutout_object`, aspect 4:3, size large, bg_color **gray**, seed **6502** (embedded 6502, matches)
- Dimensions: 880x656 RGBA
- Prompt: "One large rounded brain coral colony (Lobophyllia / open brain coral), a complete dome covered in deep meandering fleshy ridges and valleys, rich emerald green ridges with glowing magenta and teal valleys, on a small rough rock base, side three-quarter view. Wet fleshy texture with subtle highlights. Near-photoreal painterly realism like a fine natural-history oil painting, luminous saturated color, soft light from above. The whole coral fully visible, nothing cropped. No text, no logo, no watermark."
- Alpha check: PASS with a minor note. Corners 0, border max 0, gray-key tint on edge 0.1% (interior 0.3%). About 50% of edge pixels are green, but that is the coral's own ridge colour, not spill. 13 pin-hole transparent specks totalling 14 px in dark valleys. They are invisible at display size and can be filled in the rig pipeline.

### backdrop_v1.png
- Source output: `moss_gen_20261104_081540_d3a764`
- Call: `generate_image`, width 1024, height 464, `upscale_2x=true` (Lanczos 2x), seed **4404** (not embedded, see Files)
- Dimensions: 2048x928 RGB (2.21:1). Native generation was 1024x464.
- Prompt: "Very wide, short panoramic strip of a tropical reef aquarium seen straight-on. Composition rule: the reef is a LOW band confined to the bottom 30 percent of the image only; all coral tops stay below the lower third line. Everything above that, the top 70 percent, is open clear empty water: a smooth soft gradient from luminous aqua-cyan at the top to rich sapphire blue just above the reef, gently lit from above, no visible water surface, no ripples, no light rays, no fish, no bubbles, no particles. The low reef band runs the full width: short mounds of porous grey-tan live rock with small dark caves, covered in low vivid corals (orange and lavender branching acropora, green brain coral domes, pink bubble coral, small purple sea fans, teal zoanthids, yellow leather coral), on a thin strip of pale sand at the very bottom. Near-photoreal painterly realism, rich luminous color. No text, no logo, no watermark, no frame."
- Reef line (first row where ≥15% of 16-px blocks are textured): y=592, 64% from top. The reef fills the bottom 36%.

### backdrop_v2.png
- Source output: `moss_gen_20261104_081143_698f0b`
- Call: `generate_image`, 1024x464, `upscale_2x=true`, seed **2202**
- Dimensions: 2048x928 RGB
- Prompt: "Wide panoramic straight-on view of a luminous tropical reef tank. Upper two thirds: completely clear open water, a smooth soft gradient from pale sunlit aqua at the top to rich ultramarine blue, with a few faint soft god-rays from above, absolutely empty, no fish, no bubbles, no particles. Lower third: a low, gently undulating ridge of porous live rock with dark caves and arches running the full width, crowned with lush corals in warm and cool colors: golden branching acropora, violet and orange sea fans, green brain coral domes, pink bubble coral, pale plate coral, teal zoanthid patches, and swaying soft corals, fading into misty blue depth behind. A thin band of fine pale sand along the very bottom edge. Near-photoreal painterly realism, rich vivid luminous color, clean and bright. No fish. No text, no logo, no watermark, no frame."
- Reef line: y=512, 55% from top. The reef fills the bottom 45%.

### backdrop_v3.png
- Source output: `moss_gen_20261104_081159_96cfb2`
- Call: `generate_image`, 1024x464, `upscale_2x=true`, seed **3303**
- Dimensions: 2048x928 RGB
- Prompt: "Panoramic side view of a bright, clean coral reef aquarium, camera level with the reef, wide format. The top sixty-five percent of the picture is open clear water only: soft bright cyan-blue light at the top deepening to royal blue, with gentle diffuse sunlight filtering from above, perfectly clean and empty, no fish and no bubbles. The bottom third holds the reef across the full width: layered grey and ochre rockwork with shadowy caves, topped with vivid healthy corals (orange and lavender branching corals, a purple gorgonian sea fan, green and pink brain corals, yellow toadstool leather coral, blue clams, red sponges), with paler blue-hazed coral silhouettes behind for depth, and white sand at the base. Near-photoreal painterly realism, luminous saturated colors, crisp detail. No fish. No text, no logo, no watermark, no frame."
- Reef line: y=432, 47% from top. The reef fills the bottom 53%, with hazy background coral rising higher at the sides.

## Rejected outputs (not kept)

- Tangs keyed on magenta (`..._080751_63b2a6` random seed 16051864, `..._080827_07a667` seed 20261104, `..._080908_7103e6` seed 424242 on magenta, `..._080944_df308d` seed 31337): 13–22% of edge pixels are violet while the interior has 0%. That is magenta spill showing as a violet halo on the blue fish. **Key blue subjects on green.**
- Brain coral keyed on magenta (`..._081056_b6b2c6`, seed 6502): the key cut 30 holes into the magenta valleys. It was regenerated on gray as coral_v3.
- Backdrop `moss_gen_20261104_081116_b3a3bb` (seed 1104): reef starts 45% from top, the highest of the set.

## Known limitations for later art cards

1. The backdrops are 2x Lanczos upscales of a 1024x464 generation. They meet the 1920-wide strip requirement, but detail is 1024-native. The PRD targets 4K-class art, so final backdrop layers need tiled or high-quality generation.
2. All backdrops have surface ripples and sunbeams baked into the top, even backdrop_v1 whose prompt asked for none. The PRD has a separate surface ripple strip and animated light shafts, so final backdrop art should leave the surface clean, or have it painted out.
3. The 4-step turbo output is a clean, glossy illustration rather than near-photoreal painting. Fish markings are slightly stylised: the palette band is simplified compared with a real Paracanthurus.


## Higgsfield pass (paid test batch, approved by Paul 2026-11-04)

Files in `higgsfield/`. Generated with the `higgsfield` CLI 1.2.2 (workspace "Private", plan plus). Exact prompts are in `higgsfield/prompts.txt` (the shared painterly-realism style suffix is in `prompts_style.txt`). Full job objects (id, job type, params, ephemeral result URL) are in `higgsfield/jobs/*.json`. Seeds are not exposed by these models.

**Picks: APPROVED by Paul 2026-11-04 as the Reef Tank style board.** Every later asset is generated against these three as the style reference.

| File | Model and settings | Size | Notes |
|---|---|---|---|
| `tang_g25.png` | `gpt_image_2_5` variant sunburst, quality xhigh, 2k, 3:2, `background transparent` | 2048x1360 RGBA | Native alpha. Border alpha max 1, corners 0, no light fringe on edge pixels. Tail stalk clearly narrowed for the body/tail split |
| `coral_g25.png` | `gpt_image_2_5` variant sunburst, quality xhigh, 2k, 4:3, `background transparent` | 2336x1744 RGBA | Native alpha. Border alpha max 1. 3.1% of edge pixels are light: the pale polyp tips, not a fringe |
| `back_nbp3.png` | `nano_banana_pro`, 4k, 21:9 | 6336x2688 RGB | Full-bleed reef: no tank frame, no water surface, no sun rays, upper two thirds open water, rock arch left of center |

**Rejected (job JSON kept, PNG deleted):**
- `tang_gpt`, `coral_gpt` (`gpt_image_2`, `background transparent`): the output was an opaque RGB PNG with a fake checkerboard painted in. gpt-image-2 does not deliver real transparency; use 2.5.
- `tang_nbp`, `coral_nbp` (`nano_banana_pro` on flat green or gray): strong painterly look, but no alpha. Background removal after the fact was ruled out in favour of native-alpha 2.5.
- `back_nbp1`, `back_nbp2` (`nano_banana_pro`, 4k 21:9): beautiful, but they render the aquarium glass frame and side walls.

Credits (from `higgsfield generate cost` quotes): nano_banana_pro 2k 2 each, 4k 4 each; gpt_image_2 high 2k 6.5 each; gpt_image_2_5 sunburst xhigh 2k 4.5 each. Batch total about 37 credits, plus two `image_background_remover` jobs that were started and then cancelled locally (their charge was not checked).

`contact_sheet_higgsfield.jpg` shows the three picks on dark blue.
