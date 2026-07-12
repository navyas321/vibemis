# test66 — Live stream-config summary line

**Feature:** A bold teal one-line summary at the **top of Basic Settings** showing the effective
stream config — e.g. `▶ 1920×1080 @ 60 fps · 20 Mbps · HEVC · HDR` — that updates live as you change
resolution/fps/bitrate/codec/HDR. Pure QML, no new preference.
**Branch:** `test66-stream-summary` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha pre-release
(tag contains `test66-stream-summary`). **Launcher-only / batchable.**

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — summary shows and updates (Desktop Mode)
1. Settings → top of **Basic Settings**. Confirm the **▶ …** summary line shows current
   resolution, fps, Mbps, codec, and (if on) HDR.
2. Change the **bitrate** slider → the Mbps figure updates live.
3. Change the **resolution/fps** → those update.
4. Change the **Video codec** dropdown to AV1 / H.264 / HEVC / Automatic → the codec word updates
   (AV1 / H.264 / HEVC / "Auto codec").
5. Toggle **HDR** (if available) → " · HDR" appears/disappears.
   - ✅ PASS if every field reflects the current settings live and matches the individual controls.

## Tier 2 — no regression
1. Confirm the rest of Basic Settings (resolution combo, fps, bitrate slider) render and work
   normally below the summary.
   - ✅ PASS if layout is clean and controls unaffected.

## Report
Write `testing/test66-stream-summary/report.md`, update the `test66` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test66-stream-summary-report`,
open a PR targeting `test66-stream-summary`.
