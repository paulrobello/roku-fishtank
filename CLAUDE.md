# roku-fishtank (Reef Tank)

A Roku screensaver channel written in BrightScript/SceneGraph. Scope and phases are in `PRD.md`, per-phase tasks in `plans/`, and device and platform research in `RESEARCH.md`. Cards are on the kanban board (project `roku-fishtank`).

## Gate

- `make checkall` (== `checkall-ci`; there is no CI). Legs run cheapest first: `api-guard` (`tools/api_guard.sh`: OS 16.0-only APIs, `Main`/`RunUserInterface`, manifest `title=`), `fmt-check` (bsfmt), `lint` (bslint), `typecheck` (bsc validate), `test`, `build` (bsc package to `dist/channel.zip`), `zip-check` (`tools/zip_check.sh`: zip holds only manifest, `source/`, `components/`, `images/`, `config/`), `fidelity-build` (bsc+bslint package of `FidelityScene` to `dist/fidelity.zip`, warnings fail, then zip-check), `test-visual` (Playwright screenshot of the brs-engine preview frozen at 3 s, compared to `tests/visual/__screenshots__/`). Any bsc or bslint **warning** fails the gate.
- Preview: `make dev` on 8138 runs the channel in brs-engine via the `source/preview.brs` `Main` shim. See README "Browser preview" for params and the dev loop.
- Toolchain is pinned in `package.json`. Install with `bun install`. Never run `node` on project scripts; use bun.
- `make fmt` rewrites BrightScript formatting in place.

## Device rules

- **Exit the screensaver on the TV before `make deploy`.** Deploying under a running instance wedges it until a device reboot.
- Deploy: `ROKU_HOST=<ip> ROKU_PASSWORD=<pw> make deploy`. The installer uses digest auth.
- Debug console: telnet port **8087**, which only listens while the screensaver runs. Read runtime errors there before guessing.
- ECP is in Limited mode on this LAN, so launching and rebooting are physical-remote steps. Exiting is remote: `press k` on the port 8080 developer console (`tools/perf/run_probe.sh` does this before deploying). `http://<ip>:8060/query/active-app` shows whether the screensaver is running.
- Devices: Primary 192.168.1.10 (Ultra 4850X, dev mode on, primary target). Roku Ultra 192.168.1.11 and Second 192.168.1.12 (4800X, dev mode off until P6). All run OS 15.3.4.

## Platform constraints

- Screensaver entry point `RunScreenSaver()` only. Never `Main`/`RunUserInterface` in device sources. The preview's `Main` shim (`source/preview.brs`) is excluded from the device build.
- Target Roku OS 15.3.4: no `Effect` node and no `shaderCompatible`, which are OS 16.0+. brs-engine simulates OS 16, so the preview will accept them while the device does not.
- No additive blending. `Poster.blendColor` multiplies. Glow, light shafts and caustics are alpha PNGs animated by opacity, translation and tint.
- `fieldToInterp` from BrightScript takes an roArray of path strings. Posters draw at natural size unless `width`/`height` are set. `Rectangle` has no `size`.
- Texture memory is width x height x 4 bytes per bitmap, and the same URI is shared for free. Stay within the budget in `docs/perf.md` (from P0.7).
- Preview dev server port: **8138** (8139 for the isolated screenshot-gate server) (reserved in `~/.claude/used_ports.md`).

## Art

AI-generated originals, prompts, seeds and provenance live in `assets/source/` and are never shipped. Runtime PNGs go in `images/`. Local moss-image comes first. Higgsfield (paid) runs only per batch with Paul's approval. `screensaver-ref.jpg` is a third-party photo used as reference only. Never commit it.
