# Phase 0: Foundation and feasibility spike

PRD: `PRD.md` § P0. Goal: one gate, one preview, measured device limits, and an approved art style before any feature work.

**Pinned versions** (`npm view`, 2026-11-04): `brighterscript@0.73.8`, `@rokucommunity/bslint@0.8.47`, `brs-engine@2.6.2`, `brs-scenegraph@0.6.2` (peer `brs-engine ^2.6.2`), `brs-node@2.6.2` (`brs-cli`), `vite@8.3.5`, `@playwright/test@1.64.1`, `roku-deploy@3.18.4` (optional). Package manager: bun. Preview port: **8134** (record it in `~/.claude/used_ports.md` in P0.1).

**Device rule for every deploy step in every phase:** exit the screensaver on the TV first. Deploying under a running instance wedges it until a reboot.

## Tasks

### P0.1: Toolchain and Makefile gate skeleton
Add `package.json` (pinned versions above), `bsconfig.json` for bsc + bslint, and Makefile targets `build`, `lint`, `typecheck` (bsc validate), `test`, `checkall`, `checkall-ci` (alias), `dev`/`dev-start`/`dev-restart`/`dev-stop`, `deploy`, `art`. Add `CLAUDE.md` with the gate, the deploy-exit rule and the device table. Reserve port 8134.
- Verify: `make checkall` runs and is green on the existing test channel. `bsc` reports 0 errors.
- Depends on: none.

### P0.2: api-guard and zip-content legs
`tools/api_guard.sh` fails on OS 16.0-only APIs (`effect`, `shaderCompatible`, `Effect` node, and any other entries from the Roku 16.0 release notes, checked live) and on `Main`/`RunUserInterface` in the device sources. A zip-content leg asserts there is no `source/preview.brs`, `preview/` or `tests/` in `dist/*.zip`.
- Verify: a planted `shaderCompatible` line makes `make checkall` fail, and removing it makes it pass. `unzip -l` shows only manifest, source, components, images and config.
- Depends on: P0.1.

### P0.3: Browser preview harness
`preview/` Vite app on 8134 that loads the channel into brs-engine + brs-scenegraph. `source/preview.brs` holds a `Main(args)` that builds the same scene as `RunScreenSaver`. Confirm how launch params reach `Main`, and implement `?seed=`, `?time=HH:MM`, `?speed=Nx` and `?freeze=t` either directly or via `pkg:/config/preview.json` injection (PRD Q2).
- Verify: `make dev`, then the agentchrome screenshot shows the test-channel fish swimming. `?freeze=10` gives the identical frame on two reloads.
- Depends on: P0.1.

### P0.4: Node unit-test runner
A minimal BrightScript assert library plus a runner under `brs-cli` (`tests/unit/*.brs`) with a seeded-PRNG sample test (xorshift in `components/lib/prng.brs`). `make test` exits non-zero on failure.
- Verify: a failing assertion fails `make test` with file/line, and a fixed assertion passes.
- Depends on: P0.1.

### P0.5: Fidelity test scene (simulator vs device)
A `FidelityScene` exercising `blendColor` multiply, stacked opacity (group × poster), rotation and scale about `scaleRotateCenter`, negative `scale.x` mirror, nested-group rotation chains, `Vector2DFieldInterpolator` with `inOutCubic` and `linear`, and `ColorFieldInterpolator`, all frozen at known timestamps. Capture the simulator via Playwright and the device via TV photo or screen capture, then lay them side by side in `docs/fidelity/`.
- Verify: apply the pass rule from PRD P0 (positions within 2% of width, colors matched, every primitive renders). Record the verdict per primitive. **Any fail → stop and ask Paul for the fallback (O1 TS twin renderer, O2 device-only iteration).**
- Depends on: P0.3.

### P0.6: Perf and memory instrumentation (device)
Research live (developer.roku.com, port 8080 developer console `help`) what OS 15.3.4 exposes for fps, texture memory and app memory (`roAppMemoryMonitor`, console commands such as `chanperf`/`r2d2_bitmaps` if present). Build a `PerfProbe` scene that ramps N rigged fish (3 Posters + 2 Animations each) and N full-width layers, logging to telnet 8087.
- Verify: `docs/perf.md` records the method (verified commands, not recalled ones) and a table of N vs fps vs texture MB on the 4850X. It states the max fish count holding 60 fps and the texture ceiling.
- Depends on: P0.1.

### P0.7: Texture budget
From P0.6, set the resident-texture budget for the worst case: all decor layers + 8 species rigs + night overlays + caustic tiles + bubble/sparkle sprites, with 25% margin. Write per-asset pixel allowances into `docs/perf.md`, consumed by the art cards.
- Verify: the budget table sums to under the ceiling minus the margin. Paul reads it.
- Depends on: P0.6.

### P0.8 (art track): Style board
Using local moss-image (`generate_cutout_object` / `generate_image`), produce one fish (royal blue tang, side profile, facing right), one coral cutout and a 1920-wide backdrop strip in painterly realism. Store originals, prompts and seeds in `assets/source/style-board/` with `PROVENANCE.md`. Higgsfield only with Paul's per-batch approval.
- Verify: Paul approves the board in chat (record the date in PROVENANCE.md). The approved images become the style reference for every later art card.
- Depends on: none.

## Exit
`make checkall` is green with all five legs: api-guard, bsc/bslint, unit, zip-content, screenshots. The screenshot leg starts with a single frozen-frame baseline of the test channel. The fidelity verdict, perf doc and budget are written, and the style board is approved.
