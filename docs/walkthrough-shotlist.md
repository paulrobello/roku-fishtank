# Install-to-screensaver walkthrough — shot list

The next demonstration video, per Reddit feedback: one uninterrupted take from enabling
developer mode to the tank running on the TV, so a non-developer can judge whether
installing is practical. Total target: 4–6 minutes. The only segments needing a human are
the two remote-on-TV steps (R1, R2) and the TV shots; the computer side can be captured
with a screen recorder (OBS/QuickTime) or scripted later.

## One-take order

| # | Where | Shot | What the viewer sees | Needs |
|---|---|---|---|---|
| 1 | TV | Title card (3–5 s) | "Replacing Roku's Aquatic Life — install walkthrough" | edit |
| R1 | TV + remote | **Enable developer mode** | Home x3, Up x2, Right, Left, Right, Left, Right on the physical remote; dev installer screen; enable + reboot; set the `rokudev` password; note the IP on screen | **Paul** |
| 2 | Computer | Get the channel | `git clone https://github.com/paulrobello/roku-fishtank && cd roku-fishtank && make install && make build` (terminal, real time or 4x speedup with a note) | scriptable |
| 3 | Computer | Sideload | `ROKU_HOST=<ip> ROKU_PASSWORD=<pw> make deploy` — show the "Install Success" response | scriptable |
| 4 | Computer (alt) | Browser fallback (optional) | `http://<ip>/plugin_install` upload of `dist/channel.zip`, same Install Success | scriptable |
| 5 | TV | **Enable the screensaver** | Settings > Theme > Screensavers → *Reef Tank* → set default, shorten the wait timer | **Paul** |
| 6 | TV | The payoff | TV idles, screensaver countdown, tank fades in; hold ~20 s; pan night mode by toggling it in the settings screen | **Paul** |
| 7 | TV | Exit demo | Any remote keypress exits cleanly back to normal TV | **Paul** |

## Filming notes

- **Uninterrupted rule:** no jump cuts inside one logical step; cuts only between steps.
  Keep the remote keypresses and the terminal in the same take where possible.
- TV capture: phone on a tripod, 1080p minimum, match the TV refresh by shooting at an
  angle if bands appear; or HDMI capture if available.
- Computer capture: screen recording at 1920x1080; zoom the terminal font to ≥16 pt so
  the key sequence and commands are readable on a phone.
- Overlay the current step name ("Step 2 of 4 — build") as a caption; each step's on-screen
  time matches the table.
- Alternative to shooting step R1 live: the same sequence as an animated diagram, with a
  note that it is a real Roku sequence.
- After filming, cut the walkthrough so that step 6 shows the dusk crossfade — that is the
  moment that sells the tank (already shown in the showcase video, reuse the crowd shot).

## Status / division of labor

- **Paul:** the two remote steps (R1, step 5) and any TV-frame shots (6, 7) — the remote
  steps cannot be scripted (ECP is Limited mode on this LAN; no virtual keypresses).
- **Agent-scriptable:** step 2 (build) and 3 (`make deploy` to the reference device) can
  be terminal-recorded; step 4 is a short browser session (`agentchrome` can capture it).
  A later session can produce these clips on request; deploying to the real TV needs the
  screensaver not running (the runner already handles that).
- The showcase video (https://youtu.be/KN0P7S0MsjQ) stays as the "why" video; this
  walkthrough is the "how" video. Link each from the other's description once both exist.
