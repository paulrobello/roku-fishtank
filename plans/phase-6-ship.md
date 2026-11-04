# Phase 6: Ship

PRD: `PRD.md` § P6. Depends on P1–P5 exits (or the cut decision from P6.0). Target: before 2026-12-01.

## Tasks

### P6.0: Scope checkpoint (2026-11-24)
Review phase status against the Dec 1 target. If a slip is projected, apply the PRD cut order (first P6 4800X rollout, then P5 settings, P4 invertebrates, P4 surface/caustics, P3 sparkles), with Paul's decision recorded in the PRD decisions log. Cut items become post-Dec-1 backlog cards.
- Verify: the PRD decisions log has a dated entry, and the board reflects the cuts.
- Depends on: none (date-gated).

### P6.1: Enable dev mode on both 4800Xs (Paul)
Physical remote on "Roku Ultra" (192.168.1.11) and "Roku Ultra Second" (192.168.1.12): Home ×3, Up ×2, Right, Left, Right, Left, Right. Enable the installer and set the `rokudev` password. Record the device IPs in the README (never the password).
- Verify: `curl -s http://<ip>:8060/query/device-info` shows `<developer-enabled>true` on both.
- Depends on: none (Paul, physical).

### P6.2: Deploy to all three and verify the picker
Make `make deploy` accept `ROKU_HOST` per device (exit the screensaver on each TV first). Select Reef Tank in Settings > Theme > Screensavers on each.
- Verify: Reef Tank runs on each TV after the idle timeout.
- Depends on: P6.1, P1–P5 exits.

### P6.3: 4800X performance verification
Measure fps and texture use on a 4800X at Normal and Busy using the `docs/perf.md` method. Tune the density caps if needed.
- Verify: 60 fps with no visible hitches at Normal, numbers recorded in `docs/perf.md`. Busy is capped if it misses 60 fps.
- Depends on: P6.2.

### P6.4: 8-hour soak
Start the screensaver (physical remote) on the Primary Roku and log app memory every 5 minutes via the 8087 console, using a bounded logger with a 9-hour deadline. Cover a dusk or dawn transition.
- Verify: memory is flat (no monotonic growth beyond noise) across 8 hours, the plot or table is in `docs/perf.md`, and nothing crashed or fell back to the default screensaver.
- Depends on: P6.2.

### P6.5: Docs sync and sign-off
Update the README (what it is, preview, deploy, devices, settings) and the PRD status. Paul does a side-by-side sign-off against `screensaver-ref.jpg`, which stays uncommitted.
- Verify: the README commands work verbatim, Paul's sign-off is recorded in the PRD, and `make checkall` is green.
- Depends on: P6.3, P6.4.
