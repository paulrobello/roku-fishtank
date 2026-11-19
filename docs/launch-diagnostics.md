# Local launch diagnostics (pending device validation)

Only `RunScreenSaver` creates the stopwatch, immediately on entry. Settings and
ordinary browser previews never start the gate or overwrite its registry report. Explicit browser-only test fixtures may seed the simulated registry; they never ship to a device. Scene
construction and `screen.show()` precede the bounded startup monitor. It captures
nonempty Posters in initially visible, nonzero-opacity subtrees and waits for all
their `loadStatus` values to be `ready`. Failed assets or 60 seconds of pending
loading stop diagnostics without a success beacon. Incomplete scene construction or an empty required asset set cannot
report success. Animated objects and settings are never modified by this monitor.

After readiness is checked in a Timer callback, exactly one
`AppLaunchComplete` signal is sent. Roku records completion on the following
render pass. A Timer callback and loaded images are **not independent evidence
of physical frame presentation**; this is a readiness gate, not a synthetic
first-frame detector. Hidden initial assets and future animation states are not
certified by this gate. Native visual and beacon validation remains required.

The main-thread result measures app-entry to render-ready notification receipt,
including startup construction and message scheduling. It excludes Roku launch
work before `RunScreenSaver` (including compilation). It must not be compared to
the 15-second total-launch criterion as proof of compliance. Read the official
Roku console beacon metric for that purpose.

The latest successful report is saved in `ReefTankDiagnostics/lastLaunch`:
model, Roku OS version/build, app version plus diagnostic revision (`diag2`),
integer elapsed milliseconds, and `render-ready` status. There are no serials,
IP addresses, account IDs, location data or timestamps. No network transmission
or automatic sharing occurs. Failed/incomplete attempts leave the previous
successful result in place. Settings displays this local report using native
controls and translated text. A tester may voluntarily share it.

Before distributing: test native startup and Settings Back/accessibility on an
idle authorized device; compare console beacon output and actual rendered tank;
confirm no overwrite on Settings entry; verify one-shot and failure behavior.
Then test the exact release on both 3810X and 3921X with model/OS/package hash and
recorded total-launch beacon timing, repeated cold/warm starts and visual checks.
Neither current Ultra hardware nor browser snapshots substitutes for those tests.

Reference: https://developer.roku.com/dev/docs/measuring-channel-performance

## Volunteer prerelease checklist (draft, not yet distributed)

Use a maintainer-designated GitHub prerelease with the exact tested commit, an
attached `channel.zip`, checksum file, and test notes. CI artifacts expire after
2 days; a release asset is the proposed persistent download, not a change to CI
retention. Creating that prerelease and sharing it are separate approval steps.

1. Confirm the displayed model in Roku Settings > System > About. Tests on
   Streaming Stick+ 3810X and Premiere+ 3921X are specifically needed; other models
   provide useful regression feedback but do not substitute for them.
2. Install only the supplied `channel.zip` using Roku developer mode. This replaces
   any existing sideloaded development app. Exit an active screensaver first and
   never interrupt viewing. The signed Store `.pkg` is not the sideload ZIP.
3. Start Reef Tank using the normal screensaver preview/idle flow. Confirm the
   complete tank becomes visible and remains responsive. Exit normally, then open
   Reef Tank custom settings > Launch report.
4. Share the report voluntarily with the designated maintainer, along with whether
   the tank visibly rendered normally and which supplied build was tested. It
   contains no device serial/IP/location, but inspect any screenshot/background
   before sharing. No report is uploaded automatically.
5. A report is the latest successful readiness observation. A failed/newer launch
   can leave the old report. Its milliseconds exclude startup before app entry and
   must not be presented as the certified 15-second total-launch measurement.
6. For the required certification evidence, capture the actual Roku beacon timing
   and visible rendering on both target models. Standalone screensaver debugging
   uses port 8087; verify that the relevant beacon output is present on the real
   device rather than assuming another app's console port or a local stopwatch.

Do not ask volunteers to post serials, IP addresses, credentials or private home
network information. Native screen-reader, display-size and lifecycle tests are
separate from these software-rendered Settings checks.

## Native finding and pending correction (2026-11-18)

On the Living Room Ultra 4850X, the diag1 build launched and continued animating,
but port 8087 logged `roSGNode.signalBeacon: not reachable. AppLaunchComplete not
signalled`. No main-thread local-result marker was observed. This confirms beacon
rejection on that run, not its underlying firmware cause or certification timing.

The uninstalled diag2 correction registers the observer after screen.show(),
publishes local readiness before attempting the beacon, logs the native integer
return separately, and reads the outcome with a bounded 100 ms main-thread fallback
until completion (65-second limit). It checks registry flush and readback explicitly.
The local report does not assert beacon acceptance. Native retest is required;
do not distribute this as verified instrumentation yet.

### diag2 native observation

On the same Ultra 4850X, diag2 reported observer=true, received the launchOutcome
field event, measured 1,381 ms from app entry to readiness handling, and confirmed
registry write/flush/readback. This is not a total-launch or first-frame metric.
The native beacon still returned 2 with the same not-reachable warning. Although
the general API describes 2 as Invalid, the standard documented beacon string was
used; the standalone-context/firmware cause is unresolved. The Settings dialog and
reboot persistence were not independently inspected. No runtime crash was seen.
`roDeviceInfo.GetVersion` produced a deprecation warning while returning the OS
version; migration can be handled separately without changing this tested build.

## diag3 OS correction (0.2.0003)

Uses roDeviceInfo.GetOSVersion() documented major, minor, revision and build string fields, strictly validated as nonempty digits. Displays `major.minor.revision / build`; incomplete or malformed data is localized as unavailable, never inferred from the deprecated packed GetVersion string. Old reports without structured OS fields retain their timing/model but show OS unavailable until a fresh successful screensaver run. The existing diag2 ZIP and signed beta package are preserved.
