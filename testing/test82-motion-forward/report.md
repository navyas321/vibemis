# Test82 Report — controller motion forwarding (gyro/accel) — SOURCE-CONFIRMED (device-gated)

**Branch:** `test82-motion-forward` (PR #157) · **Report:** `diagnostic/test82-motion-forward-report`
**Device:** Legion Go S Z2, SteamOS 3.8.5, Qt 6.9.1 · **Test date:** 2026-07-12
**Nature:** **device-gated** — full runtime verification needs a **gyro/accel-capable controller in Game Mode** (Steam Input routes physical motion sensors). Not runtime-reproducible in headless gamescope without a controller. Verified at **source**; the injection path is the same one exercised by test77/test81.

---

## 1. TL;DR

| Item | Status |
|---|---|
| Setting `forwardMotionControls` exists + persists | ✅ source-confirmed |
| Sensor enablement gated on the setting | ✅ source-confirmed |
| Gyro/accel forwarded to host via moonlight-common | ✅ source-confirmed |
| Live gyro→host runtime | ⏭️ **N/A (needs motion controller in Game Mode)** — deferred to a controller pass |

**Verdict: MERGE-ready on source review** (wiring correct, default-off = no regression). Flag one on-device Game-Mode controller pass to runtime-confirm actual gyro/accel delivery.

## 2. Source evidence (`test82-motion-forward`)
- **Setting + persistence:** `app/gui/SettingsView.qml:1868` — `forwardMotionControls` checkbox; `app/settings/streamingpreferences.cpp:171,392` — reads/writes `SER_FORWARDMOTION`, **default `false`** (no behaviour change unless enabled → no regression).
- **Gated enablement:** `app/streaming/input/gamepad.cpp:673-675` — on controller add / when the host requests a report rate via `setMotionEventState()`, SDL sensors are enabled **only** `if (StreamingPreferences::get()->forwardMotionControls)` (checks `SDL_GameControllerHasSensor(GYRO/ACCEL)`).
- **Forwarding:** `app/streaming/input/gamepad.cpp:505-531` — `handleControllerSensorEvent()` maps `SDL_SENSOR_ACCEL → LiSendControllerMotionEvent(LI_MOTION_TYPE_ACCEL, …)` and `SDL_SENSOR_GYRO → LiSendControllerMotionEvent(LI_MOTION_TYPE_GYRO, …)` (with the report-rate throttle).

## 3. Recommendation
**MERGE** on source review; schedule a **Game-Mode controller pass** (physical gyro) to confirm live motion reaches the host and honours the report rate. Setting default-off means it's a safe opt-in.
