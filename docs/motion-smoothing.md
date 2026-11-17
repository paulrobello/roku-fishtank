# Motion smoothing and velocity-linked tails

## Changes

Fish already used native render-thread Animation interpolation; no per-frame
BrightScript loop or additional per-fish timer is added. The 8 Hz deterministic
steering simulation, species behavior, obstacle decisions and dart probability
remain unchanged.

Cruise paths now use monotone Hermite interpolation with four render samples per
steering interval. Original waypoint positions/times remain exact. Each generated
chord is checked against obstacle ellipses. If any chord is unsafe, that entire
span retains the original straight path. School paths additionally check relative
closest approach between every pair of fish across every rendered interval; if
rounding or handoff would violate minimum spacing, the school retains its original
paths for that segment. Darts retain their original path and outCubic timing.

At a new segment, the rendered path starts at the current displayed position,
then fades that offset over up to 350 ms when all corrected chords are obstacle-safe;
pitch starts at the currently displayed rotation. This avoids concentrating a
handoff correction into one short chord. Unsafe bridges fall back to the planned
path. This is not
a claim that every velocity derivative is continuous, especially at collision
fallbacks and deliberate dart launches.

Tail speed is separate from the original fin speed. The shared brain/school timer
evaluates velocity of the currently issued animation path, including its duration,
preview playback speed and dart easing derivative. It excludes camera drift and
lane transforms. An elapsed-time exponential filter uses 0.18 s attack and 0.45 s
decay. Tail frequency is `min(2.1, 0.12 + speed / 140)` Hz, with negative speed
clamped to zero. Examples: rest 8.33 s/beat, 10 px/s 5.22 s, 35 px/s 2.70 s,
60 px/s 1.82 s, 110 px/s 1.10 s. Hovering no longer inherits a minimum 15 px/s
speed bucket and a four-second maximum tail period.

Retiming occurs only for a period change of at least 10%. Elapsed-time phase and
rotated piecewise-sine knots preserve both tail rotation and foreshortening across
retiming. Pause time is excluded; resume is sent only on actual paused→running
transitions. Fins retain their existing cadence and are not restarted by tail
updates. Swim-speed changes do not reset an explicit tail clock.

## Verification and release status

Focused tests cover waypoints, straight-line uniform motion, bounds, obstacle
fallback, safe handoffs, seeded obstacle clearance, school closest approach,
dart derivative, stationary paths, elapsed-time invariance, tail frequency,
phase/curve continuity and pause transitions. Existing brain/school deterministic
and collision suites remain applicable.

## Scoped GPU verification (November 17, 2026)

On the development Mac, ANGLE Metal / Apple M4 Max:
- Three live-motion cases (BrainDemoScene, SchoolDemoScene, ReefTank) remained moving
  with no runtime errors. Full-resolution videos and eight sampled frames per case
  were retained under `dist/motion-current/`.
- Two frozen-frame differences were reviewed: expected tail-pose changes, with the
  scene composition/body positions intact. Those two baselines were refreshed.
- Scoped suite passed 7/7; the two frozen cases then passed three repetitions each
  (6/6), without further baseline updates.
- The unchanged main checkout passed the same three live cases and its footage is
  under `dist/motion-baseline/`. An eight-second, same-seed before/updated comparison
  is `dist/motion-comparison.mp4`; timing is approximate, not frame-synchronized.
- Pre/post loads remained below 15 (recorded one-minute values 7.65–11.66); no TV was
  contacted or installed during this verification.

An initial sandboxed browser launch failed before rendering; the approved local
execution retry ran successfully. Full gates, remaining affected scene baselines,
subjective motion review and physical-TV validation remain required before treating
this as release-ready. No push or publication has occurred.

After Paul explicitly requested installation on all TVs (lifting his earlier device hold), the 3,991,352-byte motion/picker ZIP was installed on all three
authorized devices. Each installer confirmed receipt size and Install Success;
post-install active-app state was Home. Idle screensavers were exited before
upload. The secondary device reported no active media playback. Physical playback/feel
validation after installation remains for Paul; installation is not certification.

## Follow-up: translation-only handoff correction

Paul reported that fish speed/movement improved and other motion was smooth, but
forward travel still had small hitches. A read-only console sample from the already
running development Roku confirmed nonzero displayed/planned handoff discrepancies.
The existing log records darts only, so it does not prove the source of every
visible cruise hitch. No keys, pause, install, or reboot was used for diagnosis.

Code review found a concrete translation artifact: the first implementation put
all handoff correction into the first interpolated chord (31.25 ms for cruises).
A one-pixel discrepancy could therefore add 32 px/s briefly. The correction now
fades over up to 350 ms with smoothstep, with exact displayed start and unchanged
final position/time. A regression fixture limits that same one-pixel correction
to less than 5 px/s extra. Dart correction uses inverse outCubic to respect actual
elapsed time rather than compressed path-key fractions. All modified chords and
school closest approach remain validated, with atomic fallback to approved paths.
Tail, fin, turn and camera code are unchanged by this follow-up.

This targeted correction passed scoped moving GPU verification (see below) and
awaits fresh installation approval; the earlier installed build does not include it.
Native segment restart
latency and obstacle-safety fallbacks can still cause residual hitches, so this is
not a claim that all stutter has been eliminated.

## Combined follow-up GPU verification (November 17, 16:00 UTC slot)

ANGLE Metal / Apple M4 Max: the combined scoped suite passed 18/18 across motion,
clock, changelog, settings and existing preview cases. Live BrainDemoScene, SchoolDemoScene
and ReefTank ran without runtime errors; footage and sampled frames are retained in
`dist/combined-verification/passing-results/`. An eight-second shareable tank clip is
`dist/combined-verification/reef-motion-followup.mp4`. This verifies execution and
ongoing motion, not absence of perceptual stutter on physical Roku hardware.

Initial snapshot failures were reviewed as intended new clock/history UI, the six-row
settings layout and previously unrefreshed tail poses in night/calm states. Body
positions and tank composition stayed unchanged in the latter diffs. Reviewed
baselines were refreshed; existing main tank/brain frozen baselines passed unchanged.
Clock day/night contrast and foreground overlap were reviewed, including a 720px
browser presentation (internally still 1080p, not native 720p certification).

Pre/post one-minute load samples stayed below 15 (5.60–9.78). No TV was contacted,
installed or interrupted; no commit, push or publication occurred. The latest rebuilt
package is 3,995,848 bytes, leaving 4,152 bytes below the unsigned-package cap.
Full release gates and real-device tests remain outstanding.
Clock day/night and 720px presentation baselines subsequently passed two repeats
each (6/6) without updates; final one-minute load was 6.21. GPU work stopped at
16:10 UTC so the remainder of the reserved slot can be released.

After Paul's subsequent explicit request to install on all TVs, the combined
3,995,848-byte ZIP was installed successfully on all three development devices. All three were at Home beneath the screensaver, with media state
closed. Each screensaver was exited and its absence confirmed before sideload.
Each installer reported the exact byte count and Install Success; each post-install
query showed Home. SHA-256:
`1131f1491d0824c513efe4d21393916a05ffaa132f0c9bfa36cf56f9c91a15ff`.
No push or publication occurred. The install does not validate actual playback;
clock and translation follow-up are now available for Paul's on-TV testing.

Paul subsequently reported that fish movement looks good on the installed build,
that the new clock works, and that his screen-reader test of Settings worked.
These are user observations of those tested paths, not exhaustive accessibility,
performance or Store certification. He requested a further artistic adjustment to
integrate the clock more deeply into the background; fish motion is unchanged.
