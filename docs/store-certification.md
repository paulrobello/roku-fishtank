# Store certification repair

## Requirements and implementation

- [Certification criterion 3.7](https://developer.roku.com/dev/docs/certification):
  app package must be at most 4 MB. The local guard uses a conservative decimal
  4,000,000-byte limit, including ZIP overhead.
- [Manifest requirements](https://developer.roku.com/dev/docs/channel-manifest):
  set `rsg_version=1.3` for current certification.
- [Screensaver input and settings](https://developer.roku.com/dev/docs/screensavers):
  the running screensaver takes no input; the separate `RunScreenSaverSettings`
  context remains available for user preferences.

The browser-only day/night handler is injected by Vite and excluded from the
production build. Settings use a native `LabelList`: Up/Down navigates and OK
cycles the selected value. Night mode, density and drift still save immediately
through the same registry helpers. No custom key handlers ship.

The approximately 19.47 MB package is reduced to about 3.93 MB without removing
scene content or changing image dimensions. The three opaque background/splash
plates use JPEG quality 80 with no chroma subsampling. Other textures use
libimagequant 128-color PNG palettes with alpha. This trades small color-encoding
error for size; it does **not** reduce decoded texture memory. Full-quality
masters remain under `assets/source/runtime-masters/`, outside the package.
`uv run tools/art/store_art.py` regenerates byte-identical encoded textures.

## Local verification

- The regular `make checkall-ci` and `make checkall` gates cover source validation,
  all 198 unit tests (including 23 memory-monitor mocks), package checks and the browser-rendered scenes.
- Guard regression fixtures reject a shipped key handler, missing `rsg_version`,
  and an oversized upload.
- Visual coverage includes drift edges, day/dusk/night, density, and the native
  settings list. Repeated OK presses must cycle through all night-mode values.
- Reviewed day/dusk images preserve composition, detail and alpha edges. Mean
  absolute RGB error compared with the previous day frame is 2.13–2.54/255;
  this is a color comparison, not evidence of identical pixels.
- Updated settings screenshots show Auto changing to Always day. All original
  image dimensions were checked against the preserved masters.

## Remaining release checks

Local success is not a Roku certification result. Before publication:

1. Install the verified ZIP on the authorized development device and smoke-test
   screensaver exit on a remote press, settings navigation/cycling/persistence,
   day/night appearance and loading of JPEG/paletted PNG textures.
2. Sign that exact build with the existing app signing key. Check the signed
   package size as well; do not ship an older previously signed artifact.
3. Upload the signed package and rerun Roku Static Analysis. The preceding build
   cleared the three original errors; verify they remain cleared. The new memory
   implementation must also be re-analyzed: local presence of required calls is
   not evidence that Roku has cleared its warnings. The App/Screensaver type
   mismatch needs console clarification; do not relabel the app as a Theme
   solely to silence a warning.
4. Complete any remaining listing/monetization decisions and obtain publication
   authorization separately. A local gate or a package upload is not publication.

## Memory monitoring

Both entry points share the same monitored screen loop. Subscription is set up
before allocating either the tank or settings scene, with interface checks,
independent getter guards and the documented `roDeviceInfo` fallback when
`EnableMemoryWarningEvent(true)` is unsupported or returns false. References
stay alive through the loop and subscriptions are disabled on exit.

The monitor records `GetMemoryLimitPercent`, `GetChannelAvailableMemory` (KB),
and `GetChannelMemoryLimit`. It only handles the event type associated with the
selected subscription. Unknown/malformed events are ignored. Usage at or above
90% (including above 100%) or a legacy `critical` level closes the screen and
returns to Roku, releasing this nonessential scene before an OS termination.
80–89% and legacy `low` warnings are logged; recovery notifications do not change
anything. Startup pressure is checked before allocating scene assets.

No density, drift, night-mode or registry values are changed. Settings already
save each user change immediately. There is no artificial real-device memory
stress test, and no automatic restart loop. A new platform invocation starts a
fresh monitored context.

Primary references:
- https://developer.roku.com/dev/docs/roappmemorymonitor
- https://developer.roku.com/dev/docs/ifappmemorymonitor
- https://developer.roku.com/dev/docs/roappmemorynotificationevent
- https://developer.roku.com/dev/docs/ifdeviceinfo

The documented October 2026 requirement applies to all apps; no screensaver
exemption is documented. Unsupported devices retain the legacy fallback, and
an unavailable fallback must not crash ordinary playback or settings.

### Real-device compatibility finding

On the Master Bedroom Ultra 4800X running Roku OS 16.0.4, the modern monitor
returns valid metrics but declines notifications in the screensaver context.
The legacy subscription succeeds. That device does not advertise
`ifSetMessagePort` on `roDeviceInfo` through `GetInterface`, despite supporting
its documented `SetMessagePort` method. The legacy path therefore checks
`ifDeviceInfo` and protects the port/subscription calls with `try/catch`, rather
than rejecting a working device based on the unadvertised port interface.
A mock regression covers this exact combination.
