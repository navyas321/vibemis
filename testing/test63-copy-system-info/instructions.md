# test63 — Copy system info to clipboard

**Feature:** A **"Copy to clipboard"** button in the System Information panel (added by test55) that
copies the version/platform/capability lines to the clipboard for bug reports. Button briefly shows
"Copied!" on click. Pure QML (hidden TextEdit + copy), no new preference.
**Branch:** `test63-copy-system-info` · **Base:** `test55-system-info` (stacks on test55) ·
**Artifact:** 🔬 alpha pre-release (tag contains `test63-copy-system-info`).

> Launcher-only. Stacks on test55 — verify test55 first if not already done.

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — copy works (Desktop Mode)
1. Settings → **System Information** panel → click **"Copy to clipboard"**.
2. Confirm the button briefly changes to **"Copied!"** then reverts.
3. Paste (Ctrl+V) into a text editor / Konsole.
   - ✅ PASS if the pasted text contains the Vibemis version, architecture, Steam Deck, display
     server, hardware decode, HDR support, and max resolution lines — matching the panel.

## Tier 2 — no regression
1. Confirm the System Information panel itself still renders all rows correctly (test55 behavior).
   - ✅ PASS if the panel + button coexist with clean layout.

## Report
Write `testing/test63-copy-system-info/report.md`, update the `test63` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test63-copy-system-info-report`,
open a PR targeting `test63-copy-system-info`.
