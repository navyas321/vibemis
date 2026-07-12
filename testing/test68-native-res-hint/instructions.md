# test68 — Native-resolution recommendation hint

**Feature:** A grey hint at the top of **Basic Settings** showing the device's native resolution
(`💡 This device's native resolution is W×H — matching it gives the sharpest image…`), read from
`SystemProperties.maximumResolution`. Hidden if unavailable. Pure QML, no new preference.
**Branch:** `test68-native-res-hint` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha pre-release
(tag contains `test68-native-res-hint`). **Launcher-only / batchable.**

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — hint shows correct native resolution (Desktop Mode)
1. Settings → top of **Basic Settings**.
2. Confirm the 💡 hint shows a resolution (e.g. 1920×1200 for the Legion Go S panel).
   - ✅ PASS if it shows a plausible native resolution for this device and reads cleanly above
     "Resolution and FPS". Cross-check the W×H against the device's actual panel resolution.

## Tier 2 — Game Mode (optional)
1. If convenient, confirm it also renders in Game Mode Settings (screenshot with Super+S). N/A ok.

## Report
Write `testing/test68-native-res-hint/report.md`, update the `test68` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test68-native-res-hint-report`,
open a PR targeting `test68-native-res-hint`.
