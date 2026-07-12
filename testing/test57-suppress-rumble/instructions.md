# test57 — Disable controller rumble (P3.13)

**Feature:** New Settings toggle **"Disable controller rumble"** (in the gamepad section). When ON,
Vibemis drops host-driven rumble/force-feedback entirely (`rumble()` + `rumbleTriggers()` early-return).
Useful to save handheld battery or for users who dislike rumble. Default OFF (rumble works as before).
**Branch:** `test57-suppress-rumble` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha pre-release
(tag contains `test57-suppress-rumble`).

> Tier 1 launcher-only. Tier 2 needs a controller + a stream to a host (mark N/A if unavailable).

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.
2. (Automation) `Vibemis-x86_64.AppImage selftest` should still print `SELFTEST RESULT: PASS`.

## Tier 1 — setting persists (launcher)
1. Settings → gamepad section → find **"Disable controller rumble"** (default unchecked).
2. Check it, fully quit, relaunch, return to Settings.
   - ✅ PASS if it's still checked.

## Tier 2 — rumble actually suppressed (needs controller + stream)
> Only if the instructions/host owner OK a stream and a rumble-capable controller is connected.
1. With the toggle **OFF**, stream a game/scene known to rumble → confirm the controller rumbles.
2. End stream, set toggle **ON**, stream the same → confirm **no** rumble occurs.
   - ✅ PASS if rumble is felt with OFF and absent with ON. Otherwise N/A.

## What to capture / report
- md5 + environment, controller model (built-in Legion Go pads vs external).
- For Tier 2, whether rumble was felt in each state.

## Report
Write `testing/test57-suppress-rumble/report.md`, update the `test57` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test57-suppress-rumble-report`,
open a PR targeting `test57-suppress-rumble`.
