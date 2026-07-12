# test65 — AV1 codec guidance note (P3.6)

**Feature:** A contextual note appears under the **Video codec** dropdown only when **AV1** is
selected, explaining AV1 needs an AV1-capable host GPU and to use "Automatic" if streaming fails.
Pure QML, no new preference.
**Branch:** `test65-av1-codec-hint` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha pre-release
(tag contains `test65-av1-codec-hint`). **Launcher-only / batchable.**

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — note toggles with AV1 selection (Desktop Mode)
1. Settings → **Video codec** dropdown.
2. Select **AV1**.
   - ✅ A blue-ish note about AV1 host/GPU requirements appears under the dropdown.
3. Switch to **Automatic** (or H.264/HEVC).
   - ✅ The note disappears.

## Tier 2 — no regression
1. Confirm changing the codec still works (selection persists across a relaunch) and the surrounding
   settings (decoder, renderer backend) render normally.
   - ✅ PASS if codec selection + layout are unaffected.

## Report
Write `testing/test65-av1-codec-hint/report.md`, update the `test65` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test65-av1-codec-hint-report`,
open a PR targeting `test65-av1-codec-hint`.
