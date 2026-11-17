# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# roku-fishtank (Reef Tank)

A Roku screensaver channel written in BrightScript/SceneGraph. Scope and phases are in `PRD.md`, per-phase tasks in `plans/`, and device and platform research in `RESEARCH.md`. Cards are on the kanban board (project `roku-fishtank`).

## Architecture

- `source/main.brs` is the only device entry point file: `RunScreenSaver()` creates `ReefTank`, `RunScreenSaverSettings()` creates `ReefTankSettings`. `source/preview.brs` defines the `Main(args)` shim that mirrors this for brs-engine and is excluded from the device zip.
- `components/ReefTank/` builds the tank from `config/scene.json`: a `camera` Group (drift loop) whose children are named layer Groups with parallax factors (waterGradient, lightShafts, backRockwork, lanes, coral layers, foreground, surfaceRipple, bubbles), plus decor placements and the fish population. Subsystem components: `Fish/` (rig renderer), `FishBrain/` (per-species behavior state machines), `School/` (boids), `Bubbles/`, `Seaweed/`, `Arch/`, `Extras/`, `Night/`, `ReefTankSettings/`.
- `components/lib/` is pure BrightScript logic with no SceneGraph dependency (prng, steer, brain, school, solar, daynight, scenecfg, settings, tint, glow, bubbles, night, extras, arch, weave, host). It runs under brs-cli in `make test`; a new suite must be registered by name in `tests/run_tests.brs` `testSuites()` (BrightScript has no reflection). `make test FILTER=<substring>` runs only suites/tests whose `suite.test` name contains the substring (case-insensitive); a filter matching nothing fails the run.
- Behavior is config-driven end to end: `config/scene.json` (layers, lanes, decor, population), `behavior.json` (per-species kinds, `_notes` documents the schema), `brain.json`/`school.json` (steering params), `night.json`, `arch.json`/`extras.json`, `species/*.json` with generated `*.rig.json`. Changing feel usually means editing JSON, not code.
- Four bsc packages: `bsconfig.json` (device channel → `dist/channel.zip`), `bsconfig.fidelity.json` (FidelityScene → `dist/fidelity.zip`), `bsconfig.probe.json` (perf ramp probe), `bsconfig.check.json` (device-check, scene/density picked via `dist/devicecheck.json`).
- Preview demo scenes are the dev loop for each subsystem: `?scene=FishDemoScene|BrainDemoScene|SchoolDemoScene|BehaviorDemoScene|ReefTankSettings|FidelityScene`. URL params (`seed`, `time`, `speed`, `freeze`, `species`, `density`) reach the scene as `m.global` fields; `?freeze=T` produces deterministic frames, which is what the visual gate compares. Full param table: README "Browser preview".

## Gate

- `make checkall` is the local done gate; `make checkall-ci` runs the same non-browser checks as `.github/workflows/ci.yml` and excludes `test-visual`. Legs run cheapest first: `api-guard` (`tools/api_guard.sh`: OS 16.0-only APIs, `Main`/`RunUserInterface`, manifest `title=`), `fmt-check` (bsfmt), `lint` (bslint), `typecheck` (bsc validate), `test`, `build` (bsc package to `dist/channel.zip`), `zip-check` (`tools/zip_check.sh`: zip holds only manifest, `source/`, `components/`, `images/`, `config/`), `fidelity-build` (bsc+bslint package of `FidelityScene` to `dist/fidelity.zip`, warnings fail, then zip-check), `test-visual` (Playwright screenshot of the brs-engine preview frozen at 3 s, compared to `tests/visual/__screenshots__/`). Any bsc or bslint **warning** fails the gate.
- After an intended visual change, refresh baselines with `bunx playwright test --update-snapshots` and review the new PNGs before committing.
- Preview: `make dev` on 8138 runs the channel in brs-engine via the `source/preview.brs` `Main` shim. See README "Browser preview" for params and the dev loop.
- Device perf: `make probe` (fish/layer ramp) and `make device-check SCENE=<scene> SECONDS=90 DENSITY=calm|normal|busy` log fps + texture use to `docs/perf/raw/`.
- Toolchain is pinned in `package.json`. Install with `bun install`. Never run `node` on project scripts; use bun.
- `make fmt` rewrites BrightScript formatting in place.

## Device rules

- **Exit the screensaver on the TV before `make deploy`.** Deploying under a running instance wedges it until a device reboot.
- Deploy: `ROKU_HOST=<ip> ROKU_PASSWORD=<pw> make deploy`. The installer uses digest auth.
- Debug console: telnet port **8087**, which only listens while the screensaver runs. Read runtime errors there before guessing.
- ECP keypresses work on all three devices (Network access set to permissive; verified 2026-11-08): `curl -d '' http://<ip>:8060/keypress/Home` exits a running screensaver remotely. Starting one is still TV-side (Settings > Theme > Screensavers > dev > Preview, or the idle timer) — `/launch/dev` is refused (503; screensaver channels are not foreground-launchable), and there is no reboot endpoint. The telnet `press k` path on 8080 (`tools/perf/run_probe.sh`) still works. `http://<ip>:8060/query/active-app` shows whether the screensaver is running.
- Devices: three Roku Ultras on the home LAN, all OS 16.0.4 (verified 2026-11-16), all with dev mode on and ECP keypress permissive — a 4850X (primary target) and two 4800Xs (Reef Tank sideloaded 2026-11-04 on one of them). Performance is measured on the 4850X only. IPs, room names and dev-mode state live in the gitignored `devices.local.md` (and `~/.claude/guides/infrastructure.md`); they stay out of the public repo.

## Platform constraints

- Fish tails use independent `tailAnim` with phase-preserving retiming from current path velocity; fins keep original cadence. Cruise render smoothing checks obstacles and school spacing; steering decisions and dart easing remain unchanged. See `components/lib/motion.brs`, `components/lib/fishbeat.brs`, and `docs/motion-smoothing.md`. Pause/resume must not restart an already-running clock.

- Screensaver entry points `RunScreenSaver()` / `RunScreenSaverSettings()` only. Never `Main`/`RunUserInterface` in device sources. The preview's `Main` shim (`source/preview.brs`) is excluded from the device build.
- Target Roku OS 15.3.4: no `Effect` node and no `shaderCompatible`, which are OS 16.0+. brs-engine simulates OS 16, so the preview will accept them while the device does not.
- No additive blending. `Poster.blendColor` multiplies. Glow, light shafts and caustics are alpha PNGs animated by opacity, translation and tint.
- Official Roku docs specify a string for `fieldToInterp`; the emulator expects an roArray of path strings. The current array assignment was verified to read back as a string and drive drift on a physical Ultra 4800X OS16.0.4; do not infer failure solely from the representation. The target id is looked up in the subtree of the Animation's first non-Animation parent (brs-sg; verify target binding on device when changing scope), so an Animation in a sibling Group cannot reach a node outside that Group. Posters draw at natural size unless `width`/`height` are set. `Rectangle` has no `size`.
- Texture memory is width x height x 4 bytes per bitmap, and the same URI is shared for free. Stay within the budget in `docs/perf.md` (from P0.7).
- Preview dev server port: **8138** (8139 for the isolated screenshot-gate server) (reserved in `~/.claude/used_ports.md`).

## Art

AI-generated originals, prompts, seeds and provenance live in `assets/source/` and are never shipped. Runtime PNGs go in `images/`. Icons and splashes are derived from the backdrop, `config/scene.json` and the fish rigs by `make key-art` (`tools/art/key_art.py`). Local moss-image comes first. Higgsfield (paid) runs only per batch with Paul's approval.

## Store certification constraints

- Device manifest must declare `rsg_version=1.3`; `zip-check` caps the upload at
  4,000,000 bytes. Both are certification requirements, not optional optimizations.
- No `onKeyEvent` definitions in shipped code. The browser's day/night handler
  lives in `source/preview_keys.brs`, excluded by bsconfig and injected by Vite.
  Settings use native LabelList Up/Down + OK cycling, not a custom key handler.
- Full-resolution lossless runtime masters live in `assets/source/runtime-masters`.
  `uv run tools/art/store_art.py` writes JPEG opaque plates and alpha-paletted PNGs
  into `images/`; source art never ships. Update masters only with full-quality
  regenerated assets, never compressed runtime files. Preserve dimensions and
  validate alpha edges, day/night scenes and settings when changing encoding.

- Both production entry points use `reefRunScreen` and `source/memory_monitor.brs`.
  Retain monitor/device references for the full loop, guard interfaces and partial
  APIs, keep the legacy fallback, and never change persisted preferences in response
  to pressure. Close at >=90% app usage or legacy critical pressure instead.
  `make test FILTER=memory` covers the injected monitor/device/screen mocks.

- Camera drift remains the subtle 90-second ±80 design-pixel loop (backdrop parallax 0.2 means ±16px). Its 5-second watchdog samples animation fraction, not pixel displacement; three unchanged samples trigger recovery. Actual foreground movement also proves health if fraction readback is stale. Off, paused, accelerated-preview, and frozen-preview states must not be restarted. Never override stored preferences.
