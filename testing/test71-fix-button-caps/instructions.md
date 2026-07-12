# test71 — Fix ALL-CAPS button labels (UI bug)

**Bug:** The Qt Material style rendered button text in ALL CAPS (e.g. the bitrate reset button showed
**"USE DEFAULT (30 MBPS)"**), which looks off.
**Fix:** Force mixed-case app-wide (`QFont::MixedCase` on the application font in `main.cpp`) plus a
belt-and-suspenders `font.capitalization: Font.MixedCase` on the bitrate reset button. Buttons now
read naturally (e.g. "Use Default (30 Mbps)").
**Branch:** `test71-fix-button-caps` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha pre-release
(tag contains `test71-fix-button-caps`). **Launcher-only / batchable.**

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — bitrate button reads mixed-case (Desktop Mode)
1. Settings → move the **Video bitrate** slider off its default so the reset button appears.
2. Confirm the button reads **"Use Default (… Mbps)"** in **normal case**, NOT "USE DEFAULT (… MBPS)".
   - ✅ PASS if it's mixed case.

## Tier 2 — other buttons no longer all-caps
1. Scan the Settings page and dialogs (e.g. any OK/Cancel, "Add PC", custom-resolution dialog
   buttons). Confirm button labels are **mixed case**, not ALL CAPS.
   - ✅ PASS if buttons across the UI render in normal case and nothing looks broken (text not
     clipped, controls still styled correctly).

## Tier 3 — no regression
1. Confirm the accent/theme still look right and the reset button still works (sets the default
   bitrate).
   - ✅ PASS if behavior + styling are otherwise unchanged.

## Report
Write `testing/test71-fix-button-caps/report.md`, update the `test71` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test71-fix-button-caps-report`,
open a PR targeting `test71-fix-button-caps`.
