# Phase 5: Settings screen

PRD: `PRD.md` § P5. Depends on P2.7 (density config) and P3.2 (night override). Drift (P1.2) is already present.

## Tasks

### P5.1: Settings storage
`lib/settings.brs` reads and writes an `roRegistrySection("ReefTank")` with keys `nightMode` (auto|day|night), `density` (calm|normal|busy) and `drift` (on|off). Defaults are auto / normal / on, and invalid values fall back to the defaults.
- Verify: unit tests under `brs-cli` cover defaults on an empty registry and invalid-value fallback (if `brs-cli` registry support is missing, use an injected store).
- Depends on: P0.4.

### P5.2: RunScreenSaverSettings UI
`source/main.brs` `RunScreenSaverSettings()` shows a `ReefTankSettings` scene: a three-row option list with left/right to change values and a Back exit. It is styled to match the tank, with no Roku logos.
- Verify: on the device, open Settings > Theme > Screensavers > Reef Tank > change settings, change each value, exit and reopen, and the values persist.
- Depends on: P5.1.

### P5.3: Wire settings into the tank
The scene reads settings at launch to set population density, the night override and drift on/off. The preview supports `?density=`/`?night=`/`?drift=` overrides.
- Verify: each setting changes the next screensaver launch on the device. Preview screenshots cover Always night and Calm.
- Depends on: P5.1, P2.7, P3.2, P1.2.

## Exit
Settings are verified end to end on the Primary Roku, and `make checkall` is green.
