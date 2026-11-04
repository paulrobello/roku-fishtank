# roku-fishtank

**Reef Tank**, a custom Roku **screensaver** channel: a layered tropical reef tank built
to replace Roku's "Aquatic Life" screensaver (removed December 1, 2026). See
`RESEARCH.md` for the full feasibility research.

**Current state: Reef Tank channel shell (P1.1).** The channel scene is
`components/ReefTank/`. It reads `config/scene.json` and builds the PRD layer stack as
named Groups inside a `camera` Group, with the reef backdrop and one coral placed; fish,
drift, bubbles and seaweed land in later P1/P2 tasks. The earlier test channel proved a
sideloaded dev screensaver appears in Settings > Theme > Screensavers and runs. See
`PRD.md` for scope and phases and `plans/` for the per-phase task plans.

## Layout

```
manifest                 screensaver_title (no channel title — see RESEARCH.md §1)
source/main.brs          RunScreenSaver() entry point
components/ReefTank/     channel scene: camera Group + layer Groups built from config/scene.json
components/lib/          pure logic (PRNG, steering, brain, solar, day/night, scene config)
config/scene.json        location, layer stack (id, PRD name, parallax), lanes, decor placements
images/                  runtime art: decor/, fish/, icons and splashes (make key-art)
bsconfig.json            RokuCommunity BrightScript VS Code extension config
source/preview.brs       Main(args) shim for the browser preview (excluded from the device zip)
preview/                 Vite page that runs the channel in brs-engine + brs-scenegraph
tests/visual/            Playwright screenshot gate and its baseline
```

## Browser preview

`make dev` serves the preview at <http://localhost:8138/> (foreground; `make dev-stop`
frees the port, `make dev-restart` does both). The page runs the real channel code in
brs-engine with the SceneGraph extension on a 1920x1080 canvas scaled to the window.

- **Dev loop:** edit `source/`, `components/` or `images/`, then reload the page. Every
  load rebuilds `channel.zip` from the files on disk, so there is no build step and no
  stale package. Edits to `preview/` itself hot-reload through Vite.
- **Entry point:** brs-engine has no screensaver entry point, so `source/preview.brs`
  defines `Main(args)`, which builds the same scene as `RunScreenSaver` and runs the same
  message loop. `bsconfig.json` excludes it from the device build.
- **URL params** reach `Main(args)` as engine deep-link values and are exposed to the
  scene as `m.global` fields:

  | Param | Example | Global field | Status |
  |---|---|---|---|
  | `scene` | `?scene=FidelityScene` | scene component to create (default `ReefTank`) | used by `Main` only |
  | `seed` | `?seed=42` | `previewSeed` (integer) | plumbed and printed |
  | `time` | `?time=18:30` | `previewTime` (string) | plumbed and printed |
  | `speed` | `?speed=4x` | `previewSpeed` (float) | scales the FishBrain clock and its mover durations and the camera drift loop; Fish tail/turn animations run at 1x |
  | `freeze` | `?freeze=10` | `previewFreeze` (seconds) | pauses all Animations at T and snaps them to their value at T, so reloads give the same frame |
  | `species` | `?species=lionfish` | `previewSpecies` (string) | species shown by `FishDemoScene` (default `royal_blue_tang`) |

- **Console:** BrightScript `print` output goes to the browser console, and the page
  exposes `window.__preview` (`status`: loading, running, frozen or error, plus the log).
- **Simulator patches:** `preview/vite.config.ts` patches three brs-scenegraph 0.6.2 gaps
  so the channel runs unmodified. `fieldToInterp` accepts an roArray, as on the device.
  A Group's `scale` (including negative, mirroring) applies to its children, which
  brs-scenegraph otherwise ignores. The preview manifest lists `fhd` first, because
  brs-scenegraph takes the first `ui_resolutions` entry as the design resolution.
- **Fish rig demo:** `?scene=FishDemoScene` shows the royal blue tang rig
  (`components/Fish/`) at display scale and 2x, turning every 3 s. Its first turn starts
  with the scene, so `?freeze=0.15` and `0.35` land mid-turn, `1.25` and `1.75` land
  on the tail extremes, and `2.0` and `2.5` on the pectoral-fin extremes.
  `&species=lionfish` shows another species; rig `extra_layers` (the lionfish dorsal
  spines) swing in phase with the pectoral fin.
- **Fish brain demo:** `?scene=BrainDemoScene&seed=7` runs 25 tangs under `FishBrain`
  (`components/FishBrain/`, logic in `components/lib/brain.brs`, parameters in
  `config/brain.json`), with the lane rect and avoidance ellipses as faint dots. The
  console logs `BRAIN nodes=<n> t=<s>` every 60 s of scene time and `BRAIN dart ...`
  per dart. Under `?freeze=T` the brain runs its logic to T at once and poses the fish
  without starting movers, so the frame depends only on seed and T. The interpreter tops
  out near 5x scene time with 25 fish, so `?speed` above ~5 does not run faster.
  `bun tools/preview_capture.ts` captures the log or a frame sequence from a running
  `make dev`.
- **Chromis school demo:** `?scene=SchoolDemoScene&seed=3` runs 10 green chromis under
  `School` (`components/School/`, boids in `components/lib/school.brs`, parameters in
  `config/school.json`). The school follows a hidden wandering leader that detours around
  the ellipses, and a spacing guard keeps members at least `minDist` apart. `?freeze=T`
  poses the school from its logic like the brain demo.
- **Behaviour demo (P2.6):** `?scene=BehaviorDemoScene&seed=1` runs the
  `config/behavior.json` population (at least one of each rigged species) under
  `FishBrain` with its `behaviorUri` set. Each species maps to a kind with its own state
  machine: grazers (tangs, emperor angelfish, Moorish idol) cruise, approach a rock point
  and peck; the royal gramma hovers at a cave mouth and backs tail first into its den;
  the mandarin pauses and hops inside the rock/sand band; the lionfish drifts and hangs
  with no darts; clownfish cruise until P4. Cave mouths (yellow), dens (violet), rock
  graze points (green) and the band (sand) are drawn as markers, and every mode change
  logs `BEHAVIOR fish=<i> species=<s> <from>-><to> t=<s>`. `config/behavior.json`'s
  `_notes` documents the schema. Evidence: `docs/perf/behavior-seed1.log` and
  `docs/preview/behavior-*.png`.

- **Settings screen (P5.2):** `?scene=ReefTankSettings` shows the screen that
  `RunScreenSaverSettings()` opens on the device (Settings > Theme > Screensavers > Reef Tank).
  Arrow keys and Enter drive it in the browser (up/down/Enter move rows, left/right change
  the value). Values persist through `components/lib/settings.brs`; the preview saves to
  brs-engine's registry. Evidence: `docs/preview/settings-initial.png` and
  `settings-changed.png`.

`make test-visual` (part of `make checkall`) starts an isolated server on 8139, opens
`?freeze=3` (the Reef Tank), the camera drift at four loop phases (`tests/visual/drift.spec.ts`, `?speed=30&freeze=0.75..3`, asserts the frame edges never show the background) and `?scene=BrainDemoScene&seed=7&freeze=5`, and compares the
canvas to `tests/visual/__screenshots__/reeftank-t3.png` and `brain-seed7-t5.png`.
After an intended visual change, refresh the baseline with
`bunx playwright test --update-snapshots` and review the new PNG before committing.

### Fidelity scene (P0.5)

`components/Fidelity/FidelityScene` exercises each SceneGraph primitive in its own grid
cell. It is excluded from `dist/channel.zip` and ships only in `dist/fidelity.zip`
(`make fidelity-build`, a `checkall` leg). `make fidelity-sim` captures it from the
preview (`?scene=FidelityScene`) and `make fidelity-device` sideloads it to the TV.
Layout, expected values and verdicts are in `docs/fidelity/README.md`.

## Deploy

### Devices on this LAN (discovered 2026-11-04 via mDNS + ECP)

| IP | Name | Model | OS |
|---|---|---|---|
| 192.168.1.10 | **Primary** (target) | Ultra 4850X | 15.3.4 |
| 192.168.1.11 | Roku Ultra | — | — |
| 192.168.1.12 | Roku Ultra Second | — | — |

1. Enable dev mode on the Roku (once): **Home x3, Up x2, Right, Left, Right,
   Left, Right** on the remote, enable the Development Application Installer,
   set a `rokudev` password, note the device IP.
2. Command line: `ROKU_HOST=<ip> ROKU_PASSWORD=<pw> make deploy`
   (or VS Code: open this folder, set host+password per the extension's prompt, press the deploy/debug button).
3. Browser fallback: upload `dist/channel.zip` at `http://<ip>/plugin_install`.
4. On the Roku: **Settings > Theme > Screensavers** → select *Reef Tank*,
   shorten the wait timer, let it idle, confirm the tank appears.

Debug output (`REEFTANK ...` lines from `ReefTank.brs`, including any scene.json
validation errors) is on telnet port **8087**:
`telnet <ip> 8087`.
