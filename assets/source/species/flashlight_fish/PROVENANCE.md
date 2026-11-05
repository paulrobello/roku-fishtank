# Flashlight Fish (Anomalops katoptron) provenance (night-only bioluminescent species)

Status: **pending Paul's approval**. Date: 2026-11-04.

| Field | Value |
|---|---|
| File | `flashlight_fish_a1.png` (768x512 RGBA, 301,589 bytes, sha256 `ece181ab6ede1f00f4e230e6028c780700973e952c9d037ae4d428bbd8cdcbf7`), the transparent cutout |
| Keyed original | `flashlight_fish_a1_keyed.png` (768x512, on the magenta key, 519,779 bytes, sha256 `5be147459644311e3db5b4376ad22db9ed1270464a461c6dbf4fd086887d8b96`) |
| Model | Local MOSS-Image-SFT (5B, INT4) on this Mac, MCP tool `generate_cutout_object` (moss-image backend at 127.0.0.1:18765) |
| Settings | `aspect_ratio 3:2`, `quality standard`, `size balanced`, `bg_color magenta`, `tolerance 28`, `transparent true`, `use_layout_box true`, `upscale_2x false` |
| Seed | 4242 |
| Output names | `moss_cutout_20261104_163452_4af565.png` and `..._rgba.png` in `~/Repos/moss-image-app/outputs` |
| Cost | none (local generation) |
| Attempts | 1; the first result passed every check |

The exact prompt is in `prompts.txt`. It follows the other species' painterly-realism wording, without a style reference image (the local tool takes none).

## Checks

- Alpha: mode RGBA, corners 0, whole 1-px border 0, 5,848 partial-alpha edge pixels (a soft matte from the cutout tool's alpha matting, not a binary mask). One pixel of residual magenta spill; the fin edges carry a faint violet rim that is not visible at the 96 px display size.
- Anatomy: right-facing profile, whole fish, deeply forked tail complete. Charcoal body with a blue sheen, two dorsal fins, large eye, and a bright whitish-cyan kidney-shaped light organ under and behind the eye in two lobes, as in the real species.

The rig parameters are in `config/species/flashlight_fish.json` (its `night` block places the light organ) and the rig check render is `docs/art/rig-check-flashlight_fish.png`. `tools/art/rig.py` darkens the painted organ in the body layer, and the lit organ is the procedural `images/night/fish_organ_glow.png` from `tools/art/reef_fx.py`, blinked by `components/Fish`.
