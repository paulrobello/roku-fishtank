# Yellow tang (Zebrasoma flavescens) provenance (card P2.8, batch A)

**Status: pending Paul approval.** Date: 2026-11-04.

- Tool: `higgsfield` CLI 1.2.2, model `gpt_image_2_5`, `--variant sunburst --quality xhigh --resolution 2k --aspect-ratio 4:3 --background transparent`.
- Style reference: `--image assets/source/style-board/higgsfield/tang_g25.png` (the approved style-board tang), passed as a painting-style reference only.
- Prompt: `prompt.txt` (the approved TANG pose wording and painterly-realism style suffix, plus the reference and transparency sentences). The exact submitted prompt is also in the job JSON.
- Seeds are not exposed by this model.
- Credits: 4.5 (one job, `higgsfield generate cost` quote 4.5; the job id and its 4.5 spend appear in `higgsfield generate list` and `account transactions`).

## Kept

| File | Job id | Size | Notes |
|---|---|---|---|
| `yellow_tang_a1.png` | `78c5f94e-bcf9-4028-a353-60a0474dca4e` (`jobs/yellow_tang_a1.json`) | 2336x1744 RGBA, 5.4 MB | Rig source. One attempt was enough |

Alpha check: mode RGBA, corners alpha 0 (one corner 1), border max 1, opaque body alpha 254 (no pixel reaches 255). Edge rim (8 < alpha < 250) is 1.8% of visible pixels, and a row through the snout ramps 247, 243, 206, 43, 3 over five pixels, the same profile as the style-board tang. Anatomy: exact side profile facing right, whole fish with complete tail, pectoral fin well forward of the tail, white scalpel spine on the stalk, dorsal and anal fins end at the stalk (stalk 149 px tall, single opaque run). Markings: uniform lemon yellow, correct for the species. The render reads slightly glossier and smoother than the style-board tang.
