# Install Reef Tank with your coding agent

Copy everything below the line into your coding agent (Claude Code, Cursor, Codex CLI, …)
as a single prompt. Your agent handles the computer-side work; you do the on-TV steps when
it asks. The agent should follow the steps in order and check in with you at each hand-off.

The illustrated version of the same steps is
[docs/install-guide.md](install-guide.md) — screenshots for every step.

---

You are helping a person install **Reef Tank**, a Roku screensaver channel
(github.com/paulrobello/roku-fishtank), on their Roku device. The person does the on-TV
steps; you do all computer-side work. Work through the steps in order. After each step,
say what changed and what the person must do next. Do not skip ahead while a person-side
hand-off is pending.

## Step 0 — Confirm prerequisites

Ask the person for (or check yourself):

1. Roku device model and OS version: on the TV, **Settings > System > About**. The tank is
   verified on Roku Ultra 4850X and 4800X running OS 15.3.4 at 60 fps; other models are
   untested but recent Roku players and TVs generally work.
2. The device's IP address from that same screen.
3. A computer with `git` and `bun` installed (`bun --version` must print a version).
   The toolchain is pinned in `package.json`; `bun install` installs it.

Done when: you have the device model/OS, the IP, and a working bun.

## Step 1 — Enable developer mode (person does this; you instruct)

Give the person these instructions verbatim, one at a time, and wait for confirmation:

1. On the physical Roku remote, press: **Home three times, Up twice, Right, Left, Right,
   Left, Right**. The developer setup screen opens.
2. Enable the **Development Application Installer**. The Roku reboots once.
3. When prompted, set the `rokudev` password and remember it — every sideload
   authenticates with it.
4. Note the device IP from the developer screen (or Settings > Network > About). The
   installer page is `http://<device-ip>/plugin_install`.

Developer mode survives reboots. It only turns off if disabled from that same screen or
after a factory reset.

Done when: the person confirms the installer is enabled and gives you the IP and the
`rokudev` password.

## Step 2 — Build the channel (you do this)

```bash
git clone https://github.com/paulrobello/roku-fishtank
cd roku-fishtank
make install    # bun install --frozen-lockfile
make build      # packages the device channel -> dist/channel.zip
```

`make build` failing with `command not found` or a missing module usually means bun
did not install the pinned toolchain — re-run `make install` before diagnosing further.

Done when: `dist/channel.zip` exists. Optionally run `make checkall` (the full gate:
lint, typecheck, tests, build, packaging checks) if you want maximum assurance before
touching the device.

## Step 3 — Sideload to the Roku (you do this)

**Before deploying, the person must exit any running screensaver** (press any key on the
remote). Deploying while the screensaver is running wedges the channel until a device
reboot — confirm this happened before you run the command.

```bash
ROKU_HOST=<device-ip> ROKU_PASSWORD=<rokudev-password> make deploy
```

`Install Success.` in the output is the confirmation. If deploy fails: a wrong
`rokudev` password and a running screensaver are the two causes — fix the cause, not the
symptom, and retry. Browser fallback: open `http://<device-ip>/plugin_install`,
authenticate with the `rokudev` password, and upload `dist/channel.zip`.

Never put the password in a committed file; inline env vars or a gitignored `.env` are
both fine.

Done when: output contains `Install Success.`

## Step 4 — Set Reef Tank as the screensaver (person does this; you instruct)

1. On the Roku: **Settings > Theme > Screensavers**, find the **dev** entry, open it, and
   choose **Set as screensaver**. Highlighting the entry is not enough — the old
   screensaver stays default until you confirm on the detail screen. (The "dev" label is
   the platform's placeholder name for sideloaded apps, not an error.)
2. Shorten the wait timer under **Settings > System > Power** so the tank appears sooner.

Done when: the person confirms the dev screensaver is set.

## Step 5 — Verify

Have the person leave the TV idle until the wait timer elapses; the tank should fade in.
Any remote keypress exits it. If the tank does not appear: the picker still has another
screensaver set (redo Step 4), or the timer is long. A blank preview pane in the picker is
cosmetic for sideloaded apps.

For debugging after install: the channel logs to telnet port **8087** while the
screensaver runs (`telnet <device-ip> 8087`).

Done when: the person confirms the tank plays on idle and exits on a keypress.

## Troubleshooting reference

- **`Install failed` on deploy** — wrong `rokudev` password, or the screensaver was
  running (exit it and retry; a wedged device needs a reboot).
- **Tank doesn't appear on idle** — another screensaver is still set, or the wait timer
  is long. Re-run Step 4 and shorten the timer.
- **Blank preview pane in the picker** — cosmetic; sideloads have no store artwork.
- **Deploy wedged the device** — reboot the Roku, exit the screensaver, retry Step 3.
- **Performance questions** — measured numbers per device model are in
  [docs/perf.md](perf.md); other Roku models are untested.
- **Updates** never need an uninstall — each deploy replaces the sideloaded package.
  To remove the tank entirely, disable developer mode from the Step-1 developer screen.
