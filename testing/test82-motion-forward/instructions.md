# test82 — Motion (gyro/accel) forwarding, slice 2: user-gated enablement (P3.22)

**Branch:** `test82-motion-forward` (auto-merges on green CI) · **Report:** `diagnostic/test82-motion-forward-report`
**Artifact:** merged beta or this branch's alpha. **Device-gated** — needs the Legion Go's built-in gyro + an Apollo host that requests motion.

## What changed
The forwarding path already existed (`handleControllerSensorEvent` → `LiSendControllerMotionEvent`)
but the host's `setMotionEventState()` request enabled the SDL sensors **regardless of the user's
`forwardMotionControls` setting** — the toggle was cosmetic. Now: when `forwardMotionControls` is
OFF, a host motion request is ignored (report rate forced to 0 → sensors stay disabled → no gyro/
accel captured or sent). When ON, sensors enable on the host's request and samples forward.
*(Takes effect at the next host request / next stream; toggling mid-stream isn't retroactive.)*

## Tier 1 — launcher (setting persists)
1. `run-cycle.sh test82-motion-forward`; `selftest` PASS.
2. Toggle motion forwarding, confirm `forwardmotioncontrols` persists in the conf across relaunch.
3. With it ON, connect a controller with a gyro → log shows
   `[motion] Controller '...' sensors: gyro=yes accel=yes (forwarding enabled; awaits host motion request)`.

## Tier 2 — device-gated (gyro → host), needs Apollo host requesting motion
1. Setting ON, stream a game/app that uses gyro (or an Apollo host that requests motion): move the
   handheld → EXPECT host receives DS4-style motion (gyro aim / cursor). Log: `SDL_SENSOR_GYRO`
   samples flowing; no error.
2. Setting OFF, same host: EXPECT NO sensor enable (`SDL_GameControllerSetSensorEnabled ... FALSE`
   or never called), no motion at the host. This is the gate under test.
If no motion-requesting host is available, mark Tier 2 **N/A (needs host motion request)** and pass
on Tier 1 + the log gate — say so.

## Report
`testing/test82-motion-forward/report.md` on `diagnostic/test82-motion-forward-report`; tick the row; bus announce.
