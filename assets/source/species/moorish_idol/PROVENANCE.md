# Moorish idol (Zanclus cornutus) provenance (card P2.8, batch A)

**Status: approved by Paul on 2026-11-04** (8-species preview, BehaviorDemoScene seed 1). Date: 2026-11-04.

- Tool: `higgsfield` CLI 1.2.2, model `gpt_image_2_5`, `--variant sunburst --quality xhigh --resolution 2k --aspect-ratio 4:3 --background transparent`.
- Style reference: `--image assets/source/style-board/higgsfield/tang_g25.png`, passed as a painting-style reference only.
- Prompt: `prompt.txt` is the attempt-2 prompt. Attempt 1 asked for a streamer that "arcs back above the body and ends above the tail stalk without overlapping the tail fin"; attempt 2 asked for it to end "above the rear black band, well in front of the tail stalk". Both outputs still trail the streamer past the tail fin. The exact submitted prompts are in `jobs/*.json`.
- Seeds are not exposed by this model.
- Credits: 9 (two jobs at 4.5 each; both job ids appear in `higgsfield generate list`).

## Kept

| File | What it is |
|---|---|
| `moorish_idol_a2.png` | Untouched generator output, job `4f27dad0-ea2d-4fce-815b-19d030163185` (`jobs/moorish_idol_a2.json`), 2336x1744 RGBA, 5.3 MB |

The rig uses the original directly. The streamer trails back over the tail fin, so `config/species/moorish_idol.json` sets `tail.band_y_px` [560, 1420]: only the tail-fin rows (y 636-1359) go to the tail layer and the full streamer (y 55-268) stays in the body, so it does not swing with the tail. Paul chose the full streamer on 2026-11-04 over an earlier tapered rig source.

Alpha check (original): mode RGBA, corners 0, border max 1, opaque alpha 254. Edge rim (8 < alpha < 250) is 3.7% of visible pixels (the thin streamer and fin rays add rim), and a row through the snout ramps 243, 211, 76, 4. Anatomy: exact side profile facing right, complete black crescent tail with white edge, pectoral fin well forward, narrow yellow stalk (138 px). Markings: white body with two black bands, yellow rear wash, long snout with orange saddle, white streamer. The front black band carries an extra thin white bar between the eye and the band, which a real idol does not have.

## Rejected

- `moorish_idol_a1` (job `71516202-cb76-44f2-ace9-70b401d7cea3`, JSON kept, PNG deleted): accurate and clean, but the streamer also trailed past the tail fin. Attempt 2 has the stronger paint quality.
