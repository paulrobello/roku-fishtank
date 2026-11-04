# Bubble sprite (P1.3)

- `images/decor/bubble.png` (32x32 RGBA) is drawn procedurally by `uv run tools/art/bubble.py`
  (`make ambient-art`): a faint cool body, a soft rim ring heavier toward the lower right,
  an upper-left highlight lobe and a small catchlight, rendered at 8x with seeded noise
  (`random.Random(1104)`), blurred and downsampled. Byte-reproducible. No generated or
  third-party source image. Texture cost 4,096 bytes, shared by all 40 bubble Posters.
