# test64 — Motion-control capability detection (P3.16, first slice)

**Feature:** New **"Forward motion controls (gyro) — experimental"** setting. When enabled, on each
gamepad connect Vibemis logs whether that controller exposes gyro/accelerometer sensors
(`[motion] Controller '<name>' sensors: gyro=… accel=…`). Observation-only first slice of P3.16;
actual sensor→host forwarding is `TODO(P3.16)`. Default off.
**Branch:** `test64-motion-capability` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha
pre-release (tag contains `test64-motion-capability`).

> Tier 1 launcher-only. Tier 2 needs a connected controller (the built-in Legion Go pads count).

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — setting persists (launcher)
1. Settings → gamepad section → find **"Forward motion controls (gyro) — experimental"** (default off).
2. Enable it, fully quit, relaunch, return to Settings.
   - ✅ PASS if still enabled.

## Tier 2 — capability logged on controller connect (needs a controller)
1. With the setting ON, run with logging and ensure a controller is connected (built-in pads ok):
   `Vibemis-x86_64.AppImage > /tmp/vibemis-test64.log 2>&1` (then connect/reconnect a controller).
2. `grep "\[motion\]" /tmp/vibemis-test64.log`
   - ✅ PASS if a `[motion] Controller '…' sensors: gyro=… accel=…` line appears (value yes/no is
     informational — the Legion Go pads may or may not expose a gyro to SDL). With the setting OFF,
     no `[motion]` line should appear.

## Tier 3 — no regression
1. Confirm controllers still work normally (navigation/input) with the setting on and off.
   - ✅ PASS if gamepad input is unaffected.

## Report
Write `testing/test64-motion-capability/report.md`, update the `test64` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test64-motion-capability-report`,
open a PR targeting `test64-motion-capability`.
