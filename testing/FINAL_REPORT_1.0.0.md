# Vibemis 1.0.0 — Test-Agent Final Report

**Release:** `1.0.0` (stable, published 2026-07-12) · **Device:** Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0, Ryzen Z2 Go
**Installed build / Steam target:** `Vibemis.AppImage` md5 `5964d533` = tag `1.0.0`

## Arc — how 1.0.0 got here
1. **Redesign was shipped WRONG** (maintainer escalation): the Computers home screen was never converted — old Moonlight blue toolbar + vertical cards, while other screens had the redesign. Root-caused to `PcView` excluded from `redesignScreen` + old `NavigableItemDelegate`; the authoritative design = repo `previews/1a-1f` (== maintainer's photos, pixel-match).
2. **0.26.0 rebuilt 1a but BLACK-SCREENED** under gamescope WSI — caught it (md5 `85ccd4cf`, `swapchain (nil)`; glxgears control rendered → app-only regression). Isolated the trigger to a collapsed/0-height global toolbar. Build agent's fix: toolbar **always-present at 84px, IS the header** (reproduces the known-good render condition my data proved).
3. **0.26.2–0.26.5:** all 6 screens exact-matched, 3-way host badge fixed (VIBEPOLLO/APOLLO/SUNSHINE), 1c pill buttons, LB/RB Settings switch (test108), **test36 back-paddle Quick Menu**.

## What I verified on the final build (on-device, gamescope WSI)
| Item | Result |
|---|---|
| 1a Computers — render (not black) + exact-match | ✅ wordmark, near-black `#0E1013`, rich 430px cards |
| 3-way host badge | ✅ VIBEPOLLO (Navid-PC) vs SUNSHINE (steamdeck) correctly differentiated |
| **1e Settings — full nav + exact-match** | ✅ opened via gamepad; sidebar 5 categories, bitrate slider, LB/RB hint bar |
| Real-host stream path | ✅ Navid-PC Virtual Display → HEVC decode → EGLRenderer (validated 0.26.3) |
| test36 back-paddle bind | ✅ source-verified: Settings→`QMGC_PADDLE`→`PADDLE_FLAG`→exact-match `state->buttons == quickMenuComboMask()` |
| Black-screen blocker | ✅ CLEARED on 1.0.0 |

## Test-infrastructure fixes delivered (branch `diagnostic/selfhost-mock-hardening`)
- **RCA of the session-long "headless input dead":** inline `pkill -f`/`pgrep -f` self-matched their own `bash -c` command line and SIGKILLed the shell → every "exit 1/no-output". Fixed by `vinput.py` (PID-based, `.ready` sentinel, by-path invocation).
- **Autonomous headless UI testing SOLVED:** mouse/keyboard don't reach the app inside gamescope's nested seat, but **SDL reads gamepads from `/dev/input/js*` directly** — `vinput.py gamepad` drives the gamepad-first UI (proven: navigated into 1e Settings end-to-end). This is the tool for future full-UI + in-stream (test36 paddle) automation.
- `mock-vibepollo-smoke.sh` — automated full-fidelity streaming validation (3/3 decode signals) + `README.md` test-platform matrix.

## Honest caveats
- 1b/1c/1d/1f launcher-screen exact-match on 1.0.0 was verified by the **build agent's Xvfb** (I only drove 1a + 1e on-device before the release cut). The gamepad-nav method now makes full on-device coverage possible for the next cycle.
- test36 paddle runtime (in-stream press) is source-verified only; the `vinput.py` gamepad `PADDLE_BACK` path is ready to automate it.

## Recommendation
**1.0.0 SHIP CONFIRMED** from the test side. Follow-ups (non-blocking): land `vinput.py`/`mock-vibepollo-smoke.sh` as permanent test infra (PR from `diagnostic/selfhost-mock-hardening`); next cycle, full gamepad-driven 1a–1f on-device sweep + in-stream test36 paddle.
