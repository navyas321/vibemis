# test67 — Low-latency "competitive" preset button

**Feature:** An **"Apply low-latency preset"** button (near the V-Sync / Frame pacing controls) that
turns **V-Sync off** and **frame pacing off** in one tap, for lowest input latency. Button shows
"Applied — V-Sync & frame pacing off" briefly. Sets existing prefs; no new preference.
**Branch:** `test67-low-latency-preset` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha
pre-release (tag contains `test67-low-latency-preset`). **Launcher-only / batchable.**

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — preset applies (Desktop Mode)
1. Settings → ensure **V-Sync** is **on** and **Frame pacing** is **on** (toggle them on first).
2. Click **"Apply low-latency preset"**.
   - ✅ The button briefly reads "Applied — V-Sync & frame pacing off", and the **V-Sync** and
     **Frame pacing** checkboxes both become **unchecked**.
3. Fully quit, relaunch, return to Settings.
   - ✅ PASS if V-Sync and frame pacing are still off (the change persisted).

## Tier 2 — no regression
1. Re-enable V-Sync manually; confirm Frame pacing becomes enabled-and-toggleable again (it depends
   on V-Sync). Confirm the surrounding controls behave normally.
   - ✅ PASS if the V-Sync/frame-pacing controls work as before and the button doesn't break layout.

## Report
Write `testing/test67-low-latency-preset/report.md`, update the `test67` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test67-low-latency-preset-report`,
open a PR targeting `test67-low-latency-preset`.
