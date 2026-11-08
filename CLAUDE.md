# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# roku-fishtank (Reef Tank)

A Roku screensaver channel written in BrightScript/SceneGraph. Scope and phases are in `PRD.md`, per-phase tasks in `plans/`, and device and platform research in `RESEARCH.md`. Cards are on the kanban board (project `roku-fishtank`).

## Architecture

- `source/main.brs` is the only device entry point file: `RunScreenSaver()` creates `ReefTank`, `RunScreenSaverSettings()` creates `ReefTankSettings`. `source/preview.brs` defines the `Main(args)` shim that mirrors this for brs-engine and is excluded from the device zip.
- `components/ReefTank/` builds the tank from `config/scene.json`: a `camera` Group (drift loop) whose children are named layer Groups with parallax factors (waterGradient, lightShafts, backRockwork, lanes, coral layers, surfaceRipple, bubbles), plus decor placements and the fish population. Subsystem components: `Fish/` (rig renderer), `FishBrain/` (per-species behavior state machines), `School/` (boids), `Bubbles/`, `Seaweed/`, `Arch/`, `Extras/`, `Night/`, `ReefTankSettings/`.
- `components/lib/` is pure BrightScript logic with no SceneGraph dependency (prng, steer, brain, school, solar, daynight, scenecfg, settings, tint, glow, bubbles, night, extras, arch, weave, host). It runs under brs-cli in `make test`; a new suite must be registered by name in `tests/run_tests.brs` `testSuites()` (BrightScript has no reflection). `make test FILTER=<substring>` runs only suites/tests whose `suite.test` name contains the substring (case-insensitive); a filter matching nothing fails the run.
- Behavior is config-driven end to end: `config/scene.json` (layers, lanes, decor, population), `behavior.json` (per-species kinds, `_notes` documents the schema), `brain.json`/`school.json` (steering params), `night.json`, `species/*.json` with generated `*.rig.json`. Changing feel usually means editing JSON, not code.
- Four bsc packages: `bsconfig.json` (device channel → `dist/channel.zip`), `bsconfig.fidelity.json` (FidelityScene → `dist/fidelity.zip`), `bsconfig.probe.json` (perf ramp probe), `bsconfig.check.json` (device-check, scene/density picked via `dist/devicecheck.json`).
- Preview demo scenes are the dev loop for each subsystem: `?scene=FishDemoScene|BrainDemoScene|SchoolDemoScene|BehaviorDemoScene|ReefTankSettings|FidelityScene`. URL params (`seed`, `time`, `speed`, `freeze`, `species`, `density`) reach the scene as `m.global` fields; `?freeze=T` produces deterministic frames, which is what the visual gate compares. Full param table: README "Browser preview".

## Gate

- `make checkall` (== `checkall-ci`; there is no CI). Legs run cheapest first: `api-guard` (`tools/api_guard.sh`: OS 16.0-only APIs, `Main`/`RunUserInterface`, manifest `title=`), `fmt-check` (bsfmt), `lint` (bslint), `typecheck` (bsc validate), `test`, `build` (bsc package to `dist/channel.zip`), `zip-check` (`tools/zip_check.sh`: zip holds only manifest, `source/`, `components/`, `images/`, `config/`), `fidelity-build` (bsc+bslint package of `FidelityScene` to `dist/fidelity.zip`, warnings fail, then zip-check), `test-visual` (Playwright screenshot of the brs-engine preview frozen at 3 s, compared to `tests/visual/__screenshots__/`). Any bsc or bslint **warning** fails the gate.
- After an intended visual change, refresh baselines with `bunx playwright test --update-snapshots` and review the new PNGs before committing.
- Preview: `make dev` on 8138 runs the channel in brs-engine via the `source/preview.brs` `Main` shim. See README "Browser preview" for params and the dev loop.
- Device perf: `make probe` (fish/layer ramp) and `make device-check SCENE=<scene> SECONDS=90 DENSITY=calm|normal|busy` log fps + texture use to `docs/perf/raw/`.
- Toolchain is pinned in `package.json`. Install with `bun install`. Never run `node` on project scripts; use bun.
- `make fmt` rewrites BrightScript formatting in place.

## Device rules

- **Exit the screensaver on the TV before `make deploy`.** Deploying under a running instance wedges it until a device reboot.
- Deploy: `ROKU_HOST=<ip> ROKU_PASSWORD=<pw> make deploy`. The installer uses digest auth.
- Debug console: telnet port **8087**, which only listens while the screensaver runs. Read runtime errors there before guessing.
- ECP is in Limited mode on this LAN, so launching and rebooting are physical-remote steps. Exiting is remote: `press k` on the port 8080 developer console (`tools/perf/run_probe.sh` does this before deploying). `http://<ip>:8060/query/active-app` shows whether the screensaver is running.
- Devices (full table in `~/.claude/guides/infrastructure.md`, each Roku is named after its room): Primary 192.168.1.10 (Ultra 4850X, dev mode on, primary target). Second 192.168.1.11 (dev mode on, Reef Tank installed 2026-11-04). Third 192.168.1.12 (dev mode off until P6). All run OS 15.3.4.

## Platform constraints

- Screensaver entry points `RunScreenSaver()` / `RunScreenSaverSettings()` only. Never `Main`/`RunUserInterface` in device sources. The preview's `Main` shim (`source/preview.brs`) is excluded from the device build.
- Target Roku OS 15.3.4: no `Effect` node and no `shaderCompatible`, which are OS 16.0+. brs-engine simulates OS 16, so the preview will accept them while the device does not.
- No additive blending. `Poster.blendColor` multiplies. Glow, light shafts and caustics are alpha PNGs animated by opacity, translation and tint.
- `fieldToInterp` from BrightScript takes an roArray of path strings. The target id is looked up in the subtree of the Animation's first non-Animation parent (brs-sg; device behaviour assumed the same), so an Animation in a sibling Group cannot reach a node outside that Group. Posters draw at natural size unless `width`/`height` are set. `Rectangle` has no `size`.
- Texture memory is width x height x 4 bytes per bitmap, and the same URI is shared for free. Stay within the budget in `docs/perf.md` (from P0.7).
- Preview dev server port: **8138** (8139 for the isolated screenshot-gate server) (reserved in `~/.claude/used_ports.md`).

## Art

AI-generated originals, prompts, seeds and provenance live in `assets/source/` and are never shipped. Runtime PNGs go in `images/`. Icons and splashes are derived from the backdrop, `config/scene.json` and the fish rigs by `make key-art` (`tools/art/key_art.py`). Local moss-image comes first. Higgsfield (paid) runs only per batch with Paul's approval. `screensaver-ref.jpg` is a third-party photo used as reference only. Never commit it.
