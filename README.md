# roku-fishtank

A custom Roku **screensaver** channel — tropical fish over a pebble bottom, built to
replace Roku's "Aquatic Life" screensaver (removed December 1, 2026). See
`RESEARCH.md` for the full feasibility research.

**Current state: test channel verified on device (2026-11-04).** The minimal
channel answered the research's open question — a sideloaded dev screensaver
appears in Settings > Theme > Screensavers (as "dev") and runs. It draws three
placeholder fish swimming across a full-width pebble bottom. Next up: **Reef
Tank**, the real screensaver. See `PRD.md` for scope and phases and `plans/` for
the per-phase task plans.

## Layout

```
manifest                 screensaver_title (no channel title — see RESEARCH.md §1)
source/main.brs          RunScreenSaver() entry point
components/FishtankTest* Scene: water rect + pebbles + N fish, animation built in init()
images/                  generated placeholder art (python3 tools/make_art.py)
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
  | `scene` | `?scene=FidelityScene` | scene component to create (default `FishtankTest`) | used by `Main` only |
  | `seed` | `?seed=42` | `previewSeed` (integer) | plumbed and printed |
  | `time` | `?time=18:30` | `previewTime` (string) | plumbed and printed |
  | `speed` | `?speed=4x` | `previewSpeed` (float) | plumbed and printed |
  | `freeze` | `?freeze=10` | `previewFreeze` (seconds) | pauses all Animations at T and snaps them to their value at T, so reloads give the same frame |

- **Console:** BrightScript `print` output goes to the browser console, and the page
  exposes `window.__preview` (`status`: loading, running, frozen or error, plus the log).
- **Simulator patches:** `preview/vite.config.ts` patches two brs-scenegraph 0.6.2 gaps
  so the channel runs unmodified. `fieldToInterp` accepts an roArray, as on the device,
  and the preview manifest lists `fhd` first, because brs-scenegraph takes the first
  `ui_resolutions` entry as the design resolution.

`make test-visual` (part of `make checkall`) starts an isolated server on 8139, opens
`?freeze=3` and compares the canvas to `tests/visual/__screenshots__/frozen-t3.png`.
After an intended visual change, refresh the baseline with
`bunx playwright test --update-snapshots` and review the new PNG before committing.

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
4. On the Roku: **Settings > Theme > Screensavers** → select *Fishtank Test*,
   shorten the wait timer, let it idle, confirm the fish appear.

Debug output (the `print` in `FishtankTest.brs`) is on telnet port **8087**:
`telnet <ip> 8087`.
