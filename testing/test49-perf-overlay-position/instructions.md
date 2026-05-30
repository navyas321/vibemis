# test49 — Performance overlay position (corner)

**Feature:** The in-stream performance overlay (stats HUD) can now be anchored to any of the
four screen corners via a new Settings dropdown, instead of always the top-left.
**Branch:** `test49-perf-overlay-position` · **Base:** `vibemis-main`
**Artifact:** download the 🔬 **alpha pre-release** for this branch from GitHub Releases
(tag contains `test49-perf-overlay-position`). Asset: `Vibemis-x86_64.AppImage`.

> This cycle **requires a stream** to a paired host (the overlay only renders while streaming).
> If no host is available, skip this row and pick the next launcher-only item in the checklist.

## Setup

1. Download the alpha AppImage to `~/Downloads`, `chmod +x` it.
2. Record its md5: `md5sum ~/Downloads/Vibemis-x86_64.AppImage` → paste in report.
3. Record environment: `cat /etc/os-release | grep VERSION=` and Mesa version
   (`glxinfo | grep "OpenGL version"` or `vulkaninfo | grep driverInfo`).

## Tier 1 — setting persists (launcher, no stream needed)

1. Launch the AppImage in **Desktop Mode**.
2. Settings → scroll to the existing **"Show performance stats while streaming"** checkbox.
   Enable it. A new **"Performance overlay position"** dropdown must appear directly below.
3. Confirm the dropdown lists exactly: **Top left, Top right, Bottom left, Bottom right**,
   and defaults to **Top left**.
4. Set it to **Bottom right**. Fully quit the app, relaunch, return to Settings.
   - ✅ PASS if the dropdown still reads **Bottom right** (persisted).
   - Also confirm: unchecking "Show performance stats" hides the dropdown.

## Tier 2 — overlay renders in the chosen corner (requires a stream)

> Only run if the instructions/host owner has OK'd a stream. Pair is assumed already done.

1. With "Show performance stats" ON and position = **Bottom right**, start a stream to the host.
2. Once video is up, confirm the yellow stats text block appears in the **bottom-right** corner
   (not top-left). Toggle the overlay off/on with **Ctrl+Alt+Shift+S** (keyboard) or
   **Select+L1+R1+X** (gamepad) to confirm it still honors the corner.
3. End the stream (Ctrl+Alt+Shift+Q / the configured quit combo).
4. Change position to **Top right**, stream again, confirm the stats block is now top-right.
   - ✅ PASS if the overlay anchors to the selected corner each time, text is fully on-screen
     (not clipped past the edge), and toggling preserves the corner.

## What to capture / report

- md5 + environment (SteamOS version, Mesa/RADV driver).
- Active renderer: in the stream log, `grep -i "renderer" /tmp/vibemis-test49.log` — note whether
  **EGLRenderer** (expected on the Legion Go S Z2 AMD APU) or another. The corner logic is
  per-renderer, so record which path was exercised.
- Run the stream with logging: `~/Downloads/Vibemis-x86_64.AppImage > /tmp/vibemis-test49.log 2>&1`
- A photo/description of the overlay corner for each tested position (bottom-right, top-right).
- Any clipping, mispositioning, or overlay-not-appearing.

## Report

Write `testing/test49-perf-overlay-position/report.md` (TL;DR table → per-tier → recommendation),
update the `test49` row in `testing/TEST_CHECKLIST.md` (☐→☑/✗ + report path), commit both on
`diagnostic/test49-perf-overlay-position-report`, and open a PR targeting
`test49-perf-overlay-position`.
