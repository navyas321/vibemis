# test79 — Theme-token migration wave 1: PcView + AppView + Material bridge (P3.19)

**Branch:** `test79-theme-wave1` · **Base:** `vibemis-main` · **Report:** `diagnostic/test79-theme-wave1-report`
**Artifact:** CI 🔬 alpha — `./testing/run-cycle.sh test79-theme-wave1`. Launcher-only; no stream needed.
**This implements wave 1 of YOUR THEME-AUDIT.md** (merged PR #147).

## What changed
- `main.qml`: Material bridge — `Material.theme = Dark`, `Material.accent = Theme.accent`,
  background from `Theme.background` (all Material-styled pages now inherit the token accent).
- `PcView.qml`: 4 literals → `Theme.surface / Theme.accent ×2 / Theme.textTertiary`.
- `AppView.qml`: the two translucent `#D0808080` tile-chip backgrounds → token-derived
  `Qt.rgba(Theme.surfaceAlt, 0.82)`.
- Zero behavior change intended.

## Tier 1 — visual + regression (gamescope emulation)
1. `run-cycle.sh test79-theme-wave1` (md5 + selftest PASS).
2. Screenshot the Computers view and App grid; EXPECT: teal (#00CCCC) accent on Material controls
   (focus/selection), same layout as your audit shots otherwise. Diff against your audit zip set.
3. Open the Add-PC dialog (keyboard: navigate + Enter) — EXPECT teal accent on its controls.
4. OTP pairing dialog (if reachable without pairing): PIN box surface/accent unchanged visually
   (same colors, now token-sourced).
5. `selftest` PASS + no QML errors in the log (`grep -iE "qml|TypeError|ReferenceError"`).

## Report
`testing/test79-theme-wave1/report.md` on `diagnostic/test79-theme-wave1-report`; tick the checklist
row; bus announce as usual. Note: PR auto-merges on green CI (new policy) — your report is the
post-merge regression gate; a FAIL gets fixed forward immediately.
