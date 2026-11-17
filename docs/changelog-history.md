# Settings changelog provenance

The Settings changelog is a short, offline **development build history**, not a
claim that these versions were published to the Roku Store. The repository has
no release tags as of November 17, 2026. Runtime content is `config/changelog.json`.

## Backfill evidence

- **Unreleased**: current uncommitted location picker, motion refinements, optional
  background clock, and changelog work. No new version number or store publication
  is inferred from installation on development TVs.
- **0.2.2 (manifest 0.2.0002), November 16**: `c308231` changes build_version from
  0001 to 0002 and adds local solar presets/custom coordinates and date/DST refresh.
- **0.2.1 (manifest 0.2.0001), November 4–15**: `9e625ac` changes the initial
  prototype to the Reef Tank shell; subsequent commits while that version remained
  in the manifest build out species/schooling, reef environment, automatic lighting,
  density/drift/night settings, smaller store packages (`e2652d5`), memory safeguards
  (`1e1fb24`), tail pacing (`34aa861`), critter placement (`337a62e`), drift recovery
  (`9bb9a03`), and policy/support pages (`70d8e24`). The UI groups these into a few
  meaningful themes rather than listing each fix.
- **0.1.1 (manifest 0.1.0001), November 4**: `cad7fe3` introduces the initial
  developer screensaver and feasibility work.

## UI and checks

The sixth Settings row opens a native StandardMessageDialog. Next entry cycles
through history and Back to newest wraps from the oldest entry. Close or the
remote Back key dismisses the dialog. Reading history does not write preferences.
Solar location stays at row index 3; Background clock is index 4; Changelog is 5.

Focused checks: `python3 tools/changelog/test_history.py`. They verify unreleased
labeling, actual version labels, concise content, and read-only handler structure.
Native UI navigation and readable layout require the scheduled visual/device check;
source/type checks alone do not establish them.
