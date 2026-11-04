# Emperor angelfish, adult (Pomacanthus imperator) provenance (card P2.8, batch A)

**Status: approved by Paul on 2026-11-04** (8-species preview, BehaviorDemoScene seed 1). Date: 2026-11-04.

- Tool: `higgsfield` CLI 1.2.2, model `gpt_image_2_5`, `--variant sunburst --quality xhigh --resolution 2k --aspect-ratio 3:2 --background transparent`.
- Style reference: `--image assets/source/style-board/higgsfield/tang_g25.png`, passed as a painting-style reference only.
- Prompt: `prompt.txt` is the attempt-2 prompt. Attempt 1 asked for "many slightly diagonal bright yellow and electric-blue horizontal stripes along the body"; attempt 2 replaced that with stripes "running diagonally from the lower front of the body up toward the rear of the dorsal fin". The exact submitted prompts are in `jobs/*.json`.
- Seeds are not exposed by this model.
- Credits: 9 (two jobs at 4.5 each; both job ids appear in `higgsfield generate list`).

## Kept

| File | Job id | Size | Notes |
|---|---|---|---|
| `emperor_angelfish_a2.png` | `ec70e206-3532-4a24-8de7-1a40a0592818` (`jobs/emperor_angelfish_a2.json`) | 2048x1360 RGBA, 4.3 MB | Rig source |

Alpha check: mode RGBA, corners 0, border max 1, opaque alpha 254. Edge rim (8 < alpha < 250) is 2.2% of visible pixels, and a row through the snout ramps 253, 230, 156, 54, 5. Anatomy: exact side profile facing right, complete rounded orange-yellow tail, pectoral fin well forward. The stalk is short and deep, and the soft dorsal and anal fin tips overhang it (with clear gaps) back to x=412-420, so the rig cut sits where the tail base begins to flare (see `config/species/emperor_angelfish.json`). Markings: diagonal yellow and blue stripes, black eye mask edged in blue, dark shoulder patch, pale blue mouth, blue anal fin with curved lines. The stripe count is higher and finer than on a real adult, and the mask shape is simplified.

## Rejected

- `emperor_angelfish_a1` (job `7c3564e9-8735-4585-b128-983949ac4cd1`, JSON kept, PNG deleted): good alpha and pose, but the stripes ran nearly horizontal and the tail colour was less accurate than attempt 2.
