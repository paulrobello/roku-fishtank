# Seaweed blade (P1.4)

- `blade_original.png` (464x832, magenta key) and `blade_rgba.png` (its transparent cutout):
  generated 2026-11-04 with the local MOSS-Image-SFT backend (`generate_cutout_object`,
  quality `standard`, aspect `9:16`, bg `magenta`, seed `1104`), output
  `moss_cutout_20261104_123707_c0e9a4`. No paid service, no reference image.
- Prompt: "a single tall straight vertical strip of green-olive kelp seaweed blade, one long
  narrow ribbon leaf standing upright, slightly wavy edges, translucent with a pale midrib,
  painterly hand-painted realistic aquarium illustration style, soft lighting, no stem
  holdfast, centered, full length visible".
- Runtime derivatives: `uv run tools/art/seaweed.py` (`make ambient-art`) crops the cutout to
  its alpha bounds, scales it to 47x400, and cuts seven 64x64 slices 56 px apart (8 px
  overlap) into `images/decor/seaweed_seg0.png` (base) .. `seaweed_seg6.png` (tip).
  Byte-reproducible. Texture cost 7 x 16,384 bytes.
- The scene darkens and cools the bright source green with a per-stalk `tint` multiply in
  `config/scene.json`.
