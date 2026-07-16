# Test114 Report — server-command result check no longer inverted (BL-1990)

**Artifact tested:** `Vibemis-0.2.0-alpha.006-x86_64.AppImage` (CI alpha, newest `0.2.0-alpha.*`)
**md5:** `068e0ca62deda2076377e24d9c78df6c` ✓ (matches the build agent's bus-pinned value; 91404792 bytes)
**Branch:** `test114-servercmd-resultfix` (commit `8b7ad29`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0 (Desktop Mode)
**Test date:** 2026-07-16
**Prior report:** `testing/test113-bubbles-e2e/report.md` (PR #196 — flagged the polarity bug)

Local times EDT (UTC-4); host-side timestamps from the build agent on the coordination bus.

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — client logs SUCCESS, no false failure | PASS | `Command sent successfully: "Bubbles"` ×1; `execution failed .*result: 1` ×0 |
| B — no regression (host E2E still works) | PASS | Bubbles.scr ran 15.7 s and self-terminated; clean quit; host session ended |

**Recommendation: MERGE — close BL-1990.**

---

## 2. Tier 0 — smoke + selftest

- md5 recomputed after download: exact match (see header).
- `selftest --json` → `{"checks":{...},"failures":0,"result":"PASS"}`, exit 0.
  (Doc nit: instructions say expect `"ok": true`; the actual selftest schema is
  `"result": "PASS"` + `"failures": 0`. Same meaning — instructions template to update.)
- Bounded boot: version string `0.2.0-alpha.006`, VAAPI renderer up
  (`Using VAAPI accelerated renderer on x11`, PlVkRenderer HDR probe OK),
  **0** SEGV/critical/fatal lines, Navid-PC discovered via mDNS.

## 3. Tier 1 — pair + stream

Host screen ON + operator present confirmed on the bus (13:31 EDT) before starting.
Already paired. Stream to Navid-PC Desktop went live via the standard stack:
RTSP handshake → control/video/audio/input streams → `EGLRenderer: EGLImage pixel format: 181`.
Zero decode errors, zero connection-terminated events for the whole session.
Incidental: the stream ran at 2784×1740 (145 % resolution scaling left enabled from the
BL-1747 repro earlier today) — unrelated to this fix and worked fine throughout.

## 4. Tier 2 — single Bubbles trigger (the fix under test)

Quick Menu → Server Commands → **Bubbles, exactly once** at **13:45:04 EDT (17:45:04Z)**:

```
00:01:17 - Qt Debug: ServerCommandManager: Using ENet-based command execution
00:01:17 - Qt Debug: ServerCommandManager: Command sent successfully: "Bubbles"
```

Scorecard greps (per instructions §"What to check"):
```
grep -c "Command sent successfully"            → 1   (expect >= 1) ✓
grep -c "execution failed .*result: 1"         → 0   (expect 0)    ✓
```

**Host truth (build agent, bus 13:47 EDT):** `Bubbles.scr` pid 32612 START **17:45:05Z**
(+0.9 s after trigger) → GONE **17:45:20Z** = **15.7 s, self-terminated** clean.
Host-side teardown per BL-1821: nothing left running.

**Failure path intact (by inspection, `app/backend/servercommandmanager.cpp:321-326`):**
success branch is now `if (result != 0)`; the `result == 0` branch still emits
`commandFailed` and logs `execution failed with result: 0`. A genuine send failure
still surfaces. (Not forced on-device — control stream stayed healthy.)

## 5. Clean quit + teardown

Quit combo at 13:47:59 EDT — all four streams stopped, no crash. Host session ended:
subsequent serverinfo polls show `SUNSHINE_SERVER_FREE`, `currentgame 0`.

## 6. Recommendation

**MERGE — close BL-1990.** The one-line polarity flip does exactly what it claims:
successful sends now log success (client UX toast follows `commandExecuted`), the failure
branch is preserved, and the host-side E2E behavior is unchanged from test113's PASS.
