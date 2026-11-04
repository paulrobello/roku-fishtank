# Moorish idol (Zanclus cornutus) provenance (card P2.8, batch A)

**Status: pending Paul approval.** Date: 2026-11-04.

- Tool: `higgsfield` CLI 1.2.2, model `gpt_image_2_5`, `--variant sunburst --quality xhigh --resolution 2k --aspect-ratio 4:3 --background transparent`.
- Style reference: `--image assets/source/style-board/higgsfield/tang_g25.png`, passed as a painting-style reference only.
- Prompt: `prompt.txt` is the attempt-2 prompt. Attempt 1 asked for a streamer that "arcs back above the body and ends above the tail stalk without overlapping the tail fin"; attempt 2 asked for it to end "above the rear black band, well in front of the tail stalk". Both outputs still trail the streamer past the tail fin. The exact submitted prompts are in `jobs/*.json`.
- Seeds are not exposed by this model.
- Credits: 9 (two jobs at 4.5 each; both job ids appear in `higgsfield generate list`).

## Kept

| File | What it is |
|---|---|
| `moorish_idol_a2.png` | Untouched generator output, job `4f27dad0-ea2d-4fce-815b-19d030163185` (`jobs/moorish_idol_a2.json`), 2336x1744 RGBA, 5.3 MB |
| `moorish_idol_a2_rig.png` | Rig source derived by `derive_rig_source.py` (`uv run assets/source/species/moorish_idol/derive_rig_source.py`) |

The derivation narrows the dorsal streamer about its own centre line from full width at x=960 to a point at x=740, which is on the body side of the tail cut (x=684). Without it the streamer pixels left of the cut would land in the tail layer and snap off at the seam whenever the tail swings. Nothing else is changed. The shipped fish therefore has a shorter streamer than the generated art.

Alpha check (original): mode RGBA, corners 0, border max 1, opaque alpha 254. Edge rim (8 < alpha < 250) is 3.7% of visible pixels (the thin streamer and fin rays add rim), and a row through the snout ramps 243, 211, 76, 4. Anatomy: exact side profile facing right, complete black crescent tail with white edge, pectoral fin well forward, narrow yellow stalk (138 px). Markings: white body with two black bands, yellow rear wash, long snout with orange saddle, white streamer. The front black band carries an extra thin white bar between the eye and the band, which a real idol does not have.

## Rejected

- `moorish_idol_a1` (job `71516202-cb76-44f2-ace9-70b401d7cea3`, JSON kept, PNG deleted): accurate and clean, but the streamer also trailed past the tail fin. Attempt 2 has the stronger paint quality and the same rig workaround applies to both.
