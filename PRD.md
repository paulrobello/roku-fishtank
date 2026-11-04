# Reef Tank — Product Requirements

| Field | Value |
|---|---|
| Product | Reef Tank: a procedurally animated tropical-reef screensaver for Roku |
| Repo | `~/Repos/roku-fishtank` (local only, no remote) |
| Owner | Paul Robello |
| Status | Planned. Feasibility proven by the test channel (2026-11-04) |
| Date | 2026-11-04 |
| Ship target | v1 live on the Primary Roku before **2026-12-01** (Aquatic Life removal date). Scope checkpoint on **2026-11-24** |

## Overview

Roku is retiring its built-in "Aquatic Life" screensaver (`screensaver-ref.jpg` shows the retired tank: static photo-cutout reef, a few sliding fish, and a Roku logo rock). Reef Tank replaces it with a richer tank: painterly-realism art and fish that are procedurally animated. Each fish has an undulating body and tail. Fish cruise, dart, turn, school, hide and weave in front of and behind the rock and coral. Around them are bubbles, swaying seaweed, coral and anemones, invertebrates, a living water surface with caustics, and a slow parallax camera drift. After sunset the tank switches to a moonlit night mode with glowing coral and bioluminescent sparkles. The switch is computed from sunrise and sunset at Woodland, CA. There are no Roku logos anywhere.

The whole channel is one BrightScript/SceneGraph codebase. On the Mac it runs in a browser through the brs-engine simulator, so we can iterate without a TV. Deploying sideloads the same files to the Roku.

## Goals

1. G1: a tank that is visibly better than the retired one, judged by Paul side by side on the Primary TV.
2. G2: every listed behavior and effect is present (see the phases), with no Roku branding.
3. G3: 60 fps with no visible hitches on the weakest target (Roku Ultra 4800X), and no memory growth over an 8-hour soak.
4. G4: night mode follows real sunrise and sunset at Woodland, CA (38.68 N, 121.77 W) in device local time, with DST handled by the OS.
5. G5: a Mac browser preview of the real channel code, with `?time=`, `?speed=` and `?seed=` controls for fast iteration.
6. G6: an on-Roku settings screen for night mode, fish density and camera drift.
7. G7: installed on all three Rokus (Primary 4850X, Roku Ultra 4800X, Second 4800X).

## Non-Goals

- Store publishing, beta channels or certification. Sideloading is permanent for personal use (RESEARCH.md §3).
- Audio, video or any interactivity. All three are forbidden in screensavers, and any keypress exits.
- A clock or other on-screen text.
- Nocturnal fish behavior changes. Night mode changes lighting and effects, not the fish roster or behavior.
- 4K art. SceneGraph authors at 1080p (`ui_resolutions=hd,fhd`) and the TVs upscale.
- Custom shaders. The Effect node needs Roku OS 16.0 and all devices run 15.3.4.

## Platform limits (what a Roku screensaver can and cannot do)

Sources: RESEARCH.md, `~/.claude/guides/roku.md`, and live doc checks on 2026-11-04 (Poster and Effect node pages, brs-engine `docs/limitations.md`).

| Limit | Consequence for Reef Tank |
|---|---|
| Entry point `RunScreenSaver()` only; `Main`/`RunUserInterface` prohibited; optional `RunScreenSaverSettings()` | The device zip contains no `Main`. The preview has a separate `Main` shim that is excluded from the device build |
| No audio or video; any keypress exits; no deep links | Silent and pure graphics. A video-loop tank is impossible, so everything is procedural SceneGraph |
| Rendering primitives: `Poster` (PNG), `Rectangle`, `Group` (translation, rotation, scale, opacity), `Poster.blendColor` (**multiply** tint only) | **No additive blending and no blur.** Glow, light shafts and caustics are pre-baked alpha PNGs animated by opacity, translation and tint |
| Effect node and `shaderCompatible` require Roku OS 16.0 and a shader GPU; all three devices run **15.3.4** | No shader effects. A gate leg rejects 16.0-only APIs, because brs-engine simulates OS 16.0 and would accept them silently |
| No flipbook node; `Poster.uri` swaps reload the texture | Animation comes from transforms on layered sprites, not frame sequences. Caustics are two scrolling tiles, not a flipbook |
| `Animation` with Float, Vector2D and Color field interpolators runs on the render thread at display rate; `Timer` callbacks also run on the render thread | Fish "brains" tick at a low rate (~8 Hz) and hand short eased Animation segments to the render thread, which interpolates at 60 fps |
| Texture memory = width × height × 4 bytes uncompressed; the same URI is shared free; Roku warns against more than ~2 resident full-HD images | Day and night share textures. Night is a `blendColor` tint plus small overlays, so the dusk crossfade does not double memory. The P0 spike measures the real budget |
| The system falls back to the default screensaver if memory is short at launch | Keep the resident set under the measured budget with margin |
| `fieldToInterp` from BrightScript must be an roArray of path strings; Posters draw at natural size unless `width`/`height` are set; `Rectangle` has no `size` | Encoded in the scene builder (see the guide) |
| Deploying while the screensaver runs wedges the app until a reboot | **Every deploy step: exit the screensaver first** |
| ECP runs in Limited mode on this LAN (no launch or keypress) | Starting a preview and a soak run are physical-remote steps. Exiting is remote via `press k` on the 8080 developer console. Logs come from telnet 8087 |
| Only one sideloaded app per device, and dev mode is required | Reef Tank replaces the test channel. The 4800Xs need dev mode enabled in P6 |
| No geolocation | Lat/long is baked into config. Time zone and DST come from `roDateTime` local time (device: `America/Los_Angeles`, auto) |

## Reference Projects

| Repo / source | Reused for |
|---|---|
| `~/Repos/roku-fishtank` test channel | Manifest shape (`screensaver_title`, no `title`), the `make deploy` digest-auth upload, and the proven Poster, Animation and interpolator patterns |
| `~/.claude/guides/roku.md` and vault `Research/roku-screensaver-sideloading` | Device table, debug port 8087 attach loop, deploy-wedge and API gotchas |
| `lvcabral/brs-engine` + `brs-scenegraph` | Runs the real channel in the browser and Node for the preview, unit tests and screenshot gate |
| `the-cube` | Bun + Vite + Playwright gate layout, and the Makefile `checkall` pattern for the preview harness |
| `~/.claude/guides/game-assets.md` and the `create-game-key-art` / `validate-generated-assets` skills | Art approval gates, provenance records and source-versus-runtime separation |

## Architecture Direction

- **Toolchain** (pinned in `plans/phase-0-foundation.md`): BrighterScript `brighterscript@0.73.8` (`bsc` compile and validate), `@rokucommunity/bslint@0.8.47`, `brs-engine@2.6.2` + `brs-scenegraph@0.6.2` (browser preview), `brs-node@2.6.2` (`brs-cli` for Node unit tests and headless runs), `vite@8.3.5` (preview server on **port 8138**), `@playwright/test@1.64.1` (screenshot gate), and bun as the package manager. Deploys use the existing `curl --digest` Makefile target (`roku-deploy@3.18.4` only if packaging needs it).
- **Layout:**
  - `source/main.brs`: `RunScreenSaver`, `RunScreenSaverSettings`
  - `source/preview.brs`: `Main` shim, excluded from the device zip
  - `components/ReefTank/`: scene, layer groups and day/night controller
  - `components/Fish/`: rigged fish component
  - `components/lib/`: pure logic with no SceneGraph (PRNG, steering, schooling, solar math, day/night phase)
  - `config/scene.json`: decor placement, lanes, avoidance ellipses, species parameters, location
  - `preview/`: Vite page hosting brs-engine
  - `tests/`: BrightScript unit tests run under `brs-cli`, plus Playwright specs
  - `tools/art/`: Python pipeline that turns cutouts into rigged layers
  - `assets/source/`: originals, prompts, seeds and provenance, kept out of the zip
- **Scene stack (back to front)** inside a drifting camera Group:
  - Water gradient
  - Light shafts
  - Back rockwork
  - **Back lane**
  - Mid coral
  - **Mid lane**
  - Coral and anemone front layer
  - **Front lane**
  - Foreground plants and sand lip
  - Surface ripple
  - Bubbles and sparkles

  Each layer group gets its own parallax factor.
- **Fish rig:** a Group holding body, tail and pectoral-fin Posters with pivots from the species JSON. Tail and fin rotation interpolators loop at a rate tied to swim speed. A turn squashes `scale.x` from 1 to 0.05, swaps to the rig's pre-mirrored art and widens back to 1. The device ignores a negative `scale.x` (fidelity F4), so no scale is ever negative.
- **Fish brain:** every ~125 ms the brain steers each fish (wander, avoid ellipses, keep in its lane, schooling forces, darts, hide and graze states). It issues the next 0.5–1.5 s eased `Vector2DFieldInterpolator` segment, and a dart retargets mid-segment. All randomness comes from a seeded xorshift PRNG, and all time comes from an injectable clock. This determinism is what the screenshot gate and the `?seed`/`?time` controls depend on.
- **Weaving:** fish change lanes only while their bounding box is occluded by decor in the layer between the lanes. They then reparent to the target lane Group and scale and tint to that lane's depth.
- **Day/night:** solar elevation is computed on the device, using NOAA-style formulas in `lib/solar`, for the configured lat/long and the local date. The phase runs day → dusk (sunset to the end of civil twilight, ~45 min) → night → dawn (mirrored). Night is a `ColorFieldInterpolator` on each layer's `blendColor` (moonlight blue multiply) plus night-only overlays: glow-coral cutouts, moon shafts and sparkles, which fade in by opacity. No day and night texture pairs are needed.
- **Settings:** `RunScreenSaverSettings` presents a minimal SceneGraph list with three options: night mode Auto / Always day / Always night, fish density Calm / Normal / Busy, and camera drift On / Off. Values are stored in an `roRegistrySection` and default to Auto / Normal / On.
- **Gate:** `make checkall` = `checkall-ci` (no CI exists). Legs run in order:
  1. api-guard: grep that rejects `effect`, `shaderCompatible`, the `Effect` node and other 16.0-only APIs, plus a manifest check
  2. `bsc` validate and bslint
  3. Unit tests under `brs-cli`
  4. Device-zip build and content check (no `Main`, no preview files)
  5. Playwright screenshots of the preview at fixed seed and time (day, dusk, night)

## Phases

Each phase ends with gates green and something visible in **both** the Mac preview and on the Primary Roku. Art runs as a parallel track: each art card belongs to the first phase that shows it, and engine work uses placeholder art until approved art lands.

### P0: Foundation and feasibility spike
Scope: toolchain and Makefile gate, a preview harness running the existing test channel in the browser, a fidelity test scene, on-device perf and memory instrumentation, the texture budget, the api-guard leg, and the art style board.
Acceptance:
- `make dev` serves the preview on 8138 showing the channel, and `make checkall` is green with all legs present.
- The fidelity scene covers `blendColor` tint, stacked opacity, rotation and scale around `scaleRotateCenter`, negative `scale.x`, Animation easing and nested-group rotation. Simulator and device screenshots sit side by side in `docs/fidelity/`. **Pass rule:** positions within 2% of screen width, colors visually matched, and every primitive renders. Any failure stops the phase for Paul's fallback decision.
- The perf method is documented in `docs/perf.md`: how frame rate, texture memory and app memory are read on OS 15.3.4 (developer console port 8080 commands, `roAppMemoryMonitor`, telnet 8087 logging), verified live. It records the measured headroom for N fish Posters with Animations at 60 fps on the 4850X.
- The texture budget, measured and written down, sized for the worst case (all layers plus night overlays plus caustics resident).
- Paul has approved the style board: one fish, one coral and a backdrop strip in painterly realism, side profile, facing right.

### P1: Day tank
Scope: the Reef Tank channel replaces the test channel, with `screensaver_title=Reef Tank`. Real layered backdrop art in the full scene stack, parallax camera drift, a pooled bubble column, segmented seaweed sway, and placeholder fish cruising in their lanes. `config/scene.json` drives the layout. Includes the art rig pipeline and the decor art.
Acceptance: the day tank runs in the preview and on the device with no Roku branding. The drift loop is seamless. Bubbles rise with wobble and recycle. Seaweed sways from nested segment rotation. Texture use is within the P0 budget, and 60 fps holds on the 4850X.

### P2: Fish life
Scope: the brain/segment motion system, the rigged fish component, cruise/dart/turn, lane weaving with occlusion, avoidance, the green chromis school (boids), and bottom/hiding behaviors (gramma at caves, mandarin grazing, lionfish hover). All 8 species are rigged from approved art.
Acceptance:
- All 8 species and the school are on screen at Normal density (~15 fish + 10 chromis).
- Each behavior is observable within 5 minutes in the preview.
- Same seed means the same trajectory (unit test).
- 60 fps on the 4850X.

### P3: Night mode
Scope: `lib/solar`, the day/night phase machine, the moonlight `blendColor` crossfade, moon light shafts, glowing coral overlays, bioluminescent sparkles, and the preview `?time`/`?speed` controls.
Acceptance:
- Sunrise and sunset for Woodland match NOAA's calculator within 2 minutes on 4 test dates, including both DST transition days.
- The dusk crossfade is smooth with no texture spike above budget.
- Night look approved by Paul on the TV.

### P4: Reef life extras
Scope: invertebrates (cleaner shrimp, crab on sand, starfish), swaying soft coral and an anemone with a hosting clownfish pair, a surface ripple strip, and two scrolling caustic tiles on sand and rock.
Acceptance: each element is visible and animated. Clownfish stay within their anemone's radius. Caustics show no visible tiling seam. Budget and 60 fps hold.

### P5: Settings
Scope: `RunScreenSaverSettings` UI, registry persistence, and wiring into density, night mode and drift.
Acceptance: each option changes behavior on the next screensaver launch, and defaults apply on a clean registry. Verified on the device.

### P6: Ship
Scope: enable dev mode on both 4800Xs (Paul, physical remote), deploy to all three, 60 fps verification on a 4800X, an 8-hour soak, and README/PRD sync.
Acceptance:
- Reef Tank is selectable and running on all three Rokus.
- The 4800X shows no visible hitches, with measured fps recorded.
- The 8-hour soak shows flat memory (logged via 8087).
- Paul's side-by-side sign-off against the reference.

**Cut order if 2026-11-24 shows a slip** (cut from the top first): P6 4800X rollout, P5 settings, P4 invertebrates, P4 surface/caustics, P3 sparkles. The core tank, behaviors and night mode are never cut.

## Risks

- R1: brs-engine SceneGraph rendering diverges from the device (it is a simulator, implementing OS 16.0). Mitigated by the P0 fidelity pass/fail, the api-guard leg and device verification at every phase end. If it fails, Paul picks a fallback (TS twin renderer or device-only iteration).
- R2: 60 fps with ~25 rigged fish × 3 Posters each, plus layers, may exceed the 4800X. Mitigated by P0 headroom measurement, density settings, and fewer rig parts on background-lane fish.
- R3: AI art consistency across 8 species in one painterly style, and clean splitting at the tail. Mitigated by the style-board gate, per-species approval and pipeline pivot overrides.
- R4: Schedule. Everything by Dec 1 is 27 days. Mitigated by the parallel art track, the Nov 24 checkpoint and the cut order.
- R5: Deploy-wedge and Limited ECP slow the device loop. Mitigated by the exit-first rule and preview-first iteration.
- R6: Long-run leaks (node and BrightScript reference cycles). Mitigated by pooling (bubbles, sparkles), no per-segment node creation, and the soak.
- R7: The texture budget is unknown until measured. Mitigated by the P0 measurement before art sizes are fixed.

## Open Questions

- Q1: The exact texture-memory ceiling and fps instrumentation on OS 15.3.4. Answered by P0.
- Q2: Whether brs-engine can pass launch params to the preview `Main` (needed for `?seed`/`?time`). **Answered by P0.3 (2026-11-04): yes.** `brs.execute(path, zip, options, deepLink)` merges the deep-link Map into the `args` AA handed to `Main`, so no `pkg:/config/preview.json` injection is needed.
- Q3: Whether Rooibos is needed later for on-device tests. Default is no: pure logic is tested under `brs-cli`.

## Decisions log (from planning interview, 2026-11-04)

- Art: painterly realism, AI-generated. Local moss-image first; Higgsfield only per batch with Paul's approval.
- Preview: run the real channel in brs-engine. The fallback is decided at P0.
- Night: sunrise/sunset at Woodland, CA 95776. Moonlight + shafts, glowing coral, bioluminescent sparkles. No behavior change.
- Population: 8 species + a chromis school. Species: royal blue tang, yellow tang, ocellaris clownfish pair, emperor angelfish, Moorish idol, royal gramma, lionfish, mandarin dragonet.
- Settings screen: yes, with 3 options. No clock overlay.
- Name: "Reef Tank". All three Ultras; the 4800Xs join in P6.
- `screensaver-ref.jpg` is a third-party watermarked photo. Reference only, never committed.

## Decisions log (added during execution)

- 2026-11-04 (Paul, standing instruction): the whole project ships **today, 2026-11-04**. The Nov 24 scope checkpoint and the Dec 1 date are void; **no scope cuts** were taken. Work runs in parallel sub-agent waves instead of the phase schedule.
