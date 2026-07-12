# test61 — Virtual Display clarifying notes (P3.13)

**Feature:** Contextual explanatory notes under the **"Use Virtual Display"** checkbox:
- when **ON** → green note that Apollo creates a virtual display matching your selected
  resolution/refresh (recommended on a handheld; host's physical monitor untouched);
- when **OFF** → grey note that the host's current physical display resolution is used.
Pure QML, no new preference. Completes the P3.13 virtual-display resolution-match item.
**Branch:** `test61-virtual-display-hint` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha
pre-release (tag contains `test61-virtual-display-hint`).

> Launcher-only. No host/stream.

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — notes toggle with the checkbox (Desktop Mode)
1. Settings → find **"Use Virtual Display"** (in the Vibemis streaming-enhancements area).
2. With it **checked**, confirm the **green** note about Apollo creating a matching virtual display.
3. **Uncheck** it.
   - ✅ PASS if the green note disappears and the **grey** "host's physical display" note appears
     (exactly one note visible at a time, matching the checkbox state).

## Tier 2 — no layout breakage
1. Toggle a few times; confirm the surrounding controls (Resolution Scaling, Scale Factor) still
   lay out correctly and nothing overlaps.
   - ✅ PASS if layout is clean in both states.

## Report
Write `testing/test61-virtual-display-hint/report.md`, update the `test61` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test61-virtual-display-hint-report`,
open a PR targeting `test61-virtual-display-hint`.
