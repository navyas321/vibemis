# Test123 Instructions — UI polish pair: combo arrow guard + overlay hit-slop (BL-2021 / BL-2032)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** two small verified-independently fixes in one cycle (bundled deliberately — both
are ~15-line UI polish with disjoint check rows; per-fix verdicts below stay separable).

## Background

- **BL-2021**: closed ComboBoxes edited their value on keyboard arrow Up/Down during
  focus-walk. Now closed combos NAVIGATE on arrows; editing requires opening the popup
  (A/Enter) first. Gamepad d-pad in Settings was never affected (UiNavMode = Tab).
- **BL-2032** (your test118 finding): overlay buttons now accept taps 12 stream-px beyond
  their 64px visuals; the KBD/TOUCH gap splits at midpoint. Hit-test only.

**Alpha:** `0.2.0-alpha.015` — asset `Vibemis-0.2.0-alpha.015-x86_64.AppImage`
**md5:** `d2e1b5d13abf9b3f48393da4dedc3fdf`
**sha256:** `4bf28f4f7af8f7f5cec3a9e2e01e1f555b4ec3f5d68c7e8f3e242cd739aaa5b3`

## Test procedure

### Tier 0 — integrity + boot
md5/sha256 exact vs dispatch; `selftest --json` PASS exit 0.

### Tier 1 — BL-2021 combo guard (launcher, keyboard attached or synth kbd arrows OK)
1. Settings → focus a ComboBox (closed): keyboard Up/Down move FOCUS (value unchanged).
2. A/Enter opens the popup: arrows navigate options, A commits — value changes only here.
3. Esc from open popup: closes without committing the highlighted option (default QQC2).
4. Gamepad d-pad regression: Settings walk still Tab-navigates; LB/RB category flip OK.

### Tier 2 — BL-2032 hit-slop (stream, direct-touch)
1. Enable overlay; stream. Tap MENU deliberately ~10px OUTSIDE each edge of its visual:
   all four sides should now hit (was: 12px-off missed).
2. Same spot-checks on KBD (outer edge + above/below) and TOUCH (inner edge + above/below).
3. The 12px gap between KBD and TOUCH: tap dead-center of the gap → exactly ONE of the two
   fires (either is fine — midpoint split), never both, never a host tap.
4. Taps ~30px away from any button still pass through to the host (slop is bounded).

## What to check and report
Per-fix verdicts (BL-2021 rows 1-4; BL-2032 rows 1-4) — separable; any focus-chain oddity
from row 1 (wrong next control) is report-worthy.

## Teardown
Quit stream; restore prefs. Nothing host-side.

## Report
`testing/test123-ui-polish/report.md` on `diagnostic/test123-ui-polish-report`,
PR targets `test123-ui-polish`.

## Safety rules (standing)
No sudo/installs; don't modify the AppImage; streaming required for Tier 2.
