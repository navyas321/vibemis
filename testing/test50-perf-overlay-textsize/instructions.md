# test50 — Performance overlay text size (Small / Normal / Large)

**Feature:** The in-stream performance overlay font size is now user-selectable
(Small ≈16pt, Normal ≈20pt = previous default, Large ≈28pt) so the stats HUD is legible
on the small handheld panel.
**Branch:** `test50-perf-overlay-textsize` · **Base:** `vibemis-main`
**Artifact:** download the 🔬 **alpha pre-release** for this branch from GitHub Releases
(tag contains `test50-perf-overlay-textsize`). Asset: `Vibemis-x86_64.AppImage`.

> Tier 1 is launcher-only. Tier 2 needs a stream (overlay only renders while streaming).
> If no host is available, do Tier 1 and mark Tier 2 N/A.

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum`.
2. Record SteamOS + Mesa/RADV versions.

## Tier 1 — setting persists (launcher, no stream)
1. Launch in Desktop Mode → Settings → enable **"Show performance stats while streaming"**.
2. A new **"Performance overlay text size"** dropdown appears below, options **Small / Normal /
   Large**, defaulting to **Normal**.
3. Set **Large**, fully quit, relaunch, return to Settings.
   - ✅ PASS if it still reads **Large**. Confirm unchecking the stats checkbox hides the dropdown.

## Tier 2 — text size changes in-stream (requires a stream)
1. With stats ON and size **Large**, start a stream. Confirm the yellow stats text is visibly
   larger than the stock build.
2. End the stream, set size **Small**, stream again — text is visibly smaller.
   - ✅ PASS if the overlay text size tracks the setting (applied at stream start) and remains
     readable / not clipped. Note the active renderer (`grep -i renderer /tmp/vibemis-test50.log`).

## Report
Write `testing/test50-perf-overlay-textsize/report.md`, update the `test50` row in
`testing/TEST_CHECKLIST.md` (☐→☑/✗ + report path), commit both on
`diagnostic/test50-perf-overlay-textsize-report`, open a PR targeting
`test50-perf-overlay-textsize`.
