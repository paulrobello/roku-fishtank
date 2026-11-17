# Optional background clock

Settings → Background clock is Off by default and stored locally. On shows a large,
muted clock in the deep-water layer, behind shafts, rocks and fish. It uses the
Roku's local time and 12/24-hour preference, not the selected sunrise/sunset city.
No time server, location request, image asset, or bundled font is added.

The text changes only when its displayed minute changes; a three-second timer
checks actual local time, including clock changes and daylight-saving transitions.
No blinking colon or seconds. The time uses 156px native type with a smaller
54px AM/PM suffix, right-aligned to keep a consistent gap. In 24-hour mode the
time is centered without a suffix gap. The group sits lower in the distant water
(base y240 at 1080p), below its original y170 placement. Water-blue tint changes
with day/night lighting independently of the backdrop; opacity remains 0.16 → 0.10.
Independent 14-minute drift works even with camera drift disabled. This reduces
static placement but does not guarantee protection against display burn-in.
The timer and drift animation stop while the clock is off.

Preview: `?clock=1` or `?clock=0` explicitly overrides the stored toggle. Omit it
to exercise Settings persistence. `time=2026-11-04T13:05` fixes the clock display;
`freeze=3` without a time uses noon. Frozen screenshots always use 12-hour format.

Focused pure tests: `make test FILTER=clock`, `FILTER=settings`, `FILTER=memory`.
GPU visual tests: `tests/visual/clock.spec.ts`, within a booked test window. Review
both day and night at HD/FHD and confirm on-device legibility, clock-format
preference, minute rollover, and off/on behavior before release. These device
checks are not implied by the pure helper tests.

Initial scoped Metal preview review (November 17, 2026) confirms day/night
placement behind fish and bubbles, subdued contrast, and default-off pixel identity.
Settings toggle and persistence passed, along with changelog navigation.
A 720px-sized browser viewport is a presentation-fit check only: the preview
internally renders at 1080p and does not replace native Roku 720p verification.

Final combined scoped GPU suite passed 18/18; day/night and 720px-viewport clock
snapshots then passed two repetitions each (6/6), with no further baseline updates.
Artifacts and logs are under `dist/combined-verification/`. Physical-device checks,
long-duration drift, minute rollover and 12/24-hour preference remain unverified.

Paul tested the installed original clock and reported it works, the fish look good,
and his screen-reader test of Settings worked. That is a limited user observation,
not exhaustive device certification. This depth refinement still needs fresh deployment approval and on-TV review.

Visual refinement review retained the lower blue typography and raised only the
night opacity from 0.08 to 0.10 to avoid losing legibility; day remains 0.16.

Depth-refinement verification (November 17, 17:25 UTC slot): visually reviewed day,
night and 720px-browser presentation. The lower composition, smaller period label
and water-blue hue read as deeper while staying behind fish/bubbles. Clock-only
checks passed 5/5; the final clean clock/preview/changelog suite passed 11/11 with
no snapshot updates. Existing tank/brain and Settings baselines stayed unchanged.
ANGLE Metal / Apple M4 Max; all pre/post one-minute loads were below15 (8.72–12.49).
Motion-source hashes match the previously installed build. Package: 3,996,343 bytes,
3,657 below the unsigned cap. Evidence: `dist/clock-refinement/`, including before
and after images. No TV was contacted or installed, and nothing was pushed or
published. The updated composition still needs Paul's on-TV readability review.

After Paul's explicit approval to install on all TVs, the refined 3,996,343-byte
build was successfully installed on all three development devices.
Each was at Home with closed media; screensavers were exited and confirmed absent
before upload. All three installers reported the exact size and Install Success,
then all three returned Home. SHA-256:
`f91e945c663d7c17ca9380faa84244d8ac330fc748a44b5630233bcb4d531356`.
No push or publication. On-TV artistic/readability assessment remains for Paul.
