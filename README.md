# roku-fishtank

A custom Roku **screensaver** channel — tropical fish over a pebble bottom, built to
replace Roku's "Aquatic Life" screensaver (removed December 1, 2026). See
`RESEARCH.md` for the full feasibility research.

**Current state: minimal test channel.** Its one job is to answer the open
question from the research — *does a sideloaded dev screensaver appear in
Settings > Theme > Screensavers?* It draws three placeholder fish (two PNG
sprites) swimming across a plain water background with a pebble strip, using one
repeating `Vector2DFieldInterpolator` per fish. No polish; the real tank
(parallax coral, tail wiggle, pan) comes after the pipeline is proven.

## Layout

```
manifest                 screensaver_title (no channel title — see RESEARCH.md §1)
source/main.brs          RunScreenSaver() entry point
components/FishtankTest* Scene: water rect + pebbles + N fish, animation built in init()
images/                  generated placeholder art (python3 tools/make_art.py)
bsconfig.json            RokuCommunity BrightScript VS Code extension config
```

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
3. Browser fallback: upload `dist/fishtank-test.zip` at `http://<ip>/plugin_install`.
4. On the Roku: **Settings > Theme > Screensavers** → select *Fishtank Test*,
   shorten the wait timer, let it idle, confirm the fish appear.

Debug output (the `print` in `FishtankTest.brs`) is on telnet port **8087**:
`telnet <ip> 8087`.
