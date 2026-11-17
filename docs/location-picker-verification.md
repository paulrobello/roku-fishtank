# Offline picker focused verification

November 17, 2026, physical Ultra 4800X, Roku OS 16.0.4.

A temporary foreground diagnostic package used the unchanged ReefTankSettings
scene so it could be launched remotely and captured by the developer screenshot
facility. It is not a release artifact. Restore the production screensaver ZIP
after device testing.

Found and fixed:
- United States was omitted by the generator; now 769 US cities are included.
- Dialog close code read `wasClosed` as a Boolean. On device that field was invalid
  during dialog replacement and crashed with runtime error &h18. Now only the
  dialog-presence check restores focus; no event-field Boolean read.
- Country list translation used unbracketed XML vector syntax and raised a runtime
  type mismatch. Corrected to `[60,200]`.
- Replaced legacy KeyboardDialog with StandardKeyboardDialog, per Roku guidance:
  https://developer.roku.com/dev/docs/keyboarddialog
  Standard message fields are arrays; ZIP uses numeric keyboardDomain.

Observed on physical device:
- Full native on-screen keyboard and explicit Save ZIP button rendered.
- Empty ZIP rejected; individual ECP keyboard characters for 95776 accepted;
  Save ZIP updated the settings location to its database coordinates.
- United States of America is selectable; its city list renders with state names.
- Selected a US city, opened custom coordinates, saved original Woodland coordinates,
  and verified the settings row returned to Woodland, CA.
- No runtime crash after fixes. Existing oversized-backdrop texture advisory
  remains (intentional scrolling artwork), not introduced by the picker.

Focused tests: location 6/6, settings filter 12/12, generated dataset 2/2;
format/lint/typecheck pass. Full GPU suite not run for this correction.
Phone QR entry was not tested and is not claimed fixed. Foreground harness tests
do not replace final validation through the real Screensaver Settings entry point.

## Lossless location/package space reduction

Current ZIP database uses ZP01 indexed128-record delta blocks in `us-zips.bin`.
All33,791 ZIP entries and original hundredth-degree coordinates are retained;
lookup scans at most128 records after binary-searching264 index entries. The
loader reads a115,575-byte byte array instead of a506,865-byte decimal string.
Leading zeros are validated as five characters before numeric lookup; unmatched
ZIPs remain unmatched. Malformed/truncated headers, offsets and varints fail closed.

City files retain228 per-country shards and7,342 names/locations. Coordinates are
now integer hundredths, converted only for the selected city. No merged all-city
parse, reduced precision, removed ZIPs, range interpolation, image re-encoding or
network lookup was introduced. Canonical old/new hashes and exhaustive Python
checks preserve coverage. The BrightScript integration test reads the shipped
binary and verifies528 first/last block-boundary samples against the old data.

Unsigned device ZIP output is losslessly repacked with DEFLATE level6 while
keeping images STORE-compressed, verifying all payloads before atomic replacement.
Current package:3,855,636 bytes versus3,996,343 previously (140,707 bytes saved;
144,364 bytes spare). Format/lint/typecheck/API/content/size guards and focused
location tests pass. GPU interaction and device installation verification are
still pending for this change; no push or publication is authorized.

Verification completed November 17 in the booked11:34 Pacific window. Initial
host load exceeded15, so the just-started browser was stopped before any result;
no other processes were interrupted. Tests resumed only once load fell to14.69.
Existing13 scoped settings/clock/preview cases passed without baseline changes.
The new native-keyboard ZIP test saved00601 as18.18,-66.75 (identical to the old
record), rejected00000 without changing the location, and retained the saved
location after reload. Its two new screenshots were reviewed; the complete new
case then passed two clean repetitions. Post-load was10.83. ANGLE Metal/M4 Max.
This is preview interaction validation, not a claim of exhaustive TV certification.

Per Paul's explicit instruction, the3,855,636-byte build was installed on all three development devices. Each was idle at Home with media closed;
screensaver exit was verified before upload. All three reported exact byte count
and Install Success, and post-install queries showed Home. Package SHA-256:
`dfef2db23168c388522e1f3950b5e38c9641de72fe6f25fbd3ac6c1fe8872c9d`.
Evidence is under `dist/location-compression/`. No push or publication occurred.
