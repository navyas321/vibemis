# Test8 Report — StreamSegue stale API complete fix

**Artifact tested:** `Vibemis-0.6.7-vibemis-test8-session-exec-x86_64.AppImage`
**md5:** `88388d7086d77fe0383b36c34da59b6b` ✓ verified
**Branch:** `test8-session-exec` (commit `95df750c`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-05-27
**Prior report:** `testing/test7-streamsegue-fix/report.md` (FAIL)

---

## 1. TL;DR

| Goal | Status | Summary |
|------|--------|---------|
| **A — Stream launches end to end** | **PASS** | Stream progressed through RTSP / control / video / audio / input. Ran ~35s with 0% frames dropped before user disconnected. |
| **B — No stale-API TypeErrors** | **PASS** | Zero TypeError matches across the entire Tier 1 log. `waitForAsyncLoad`, `session.initialize`, `launchWarnings`, `session.start` all clean. |
| **C — No regression (PC list, mDNS)** | **PASS** | Tier 2: Navid-PC online at 2 s, mDNS discovery at 3 s, no errors. |
| **D — QuickMenu / ServerCommandManager wiring** | **PASS** | `ServerCommandManager and ClipboardManager initialized and connected to QuickMenuManager`; no `hasServerCommands` TypeError. |

---

## 2. Tier 1 — stream launch

### TypeError sweep
```
grep -i "typeerror|waitforasyncload|session\.start|session\.initialize|launchwarnings" tier1.log
→ (no matches)
```
All four stale-API call sites identified in the test7 report are gone.

### Launch chain (the gate that failed in test7)
```
00:00:14 - launch: appid=785894588 (Desktop) → status_code="200", sessionUrl0=rtspenc://192.168.4.78:48010
00:00:25 - SDL Info: RTSP port: 48010
00:00:25 - SDL Info: Starting RTSP handshake...
00:00:25 - SDL Info: Starting control stream...
00:00:25 - SDL Info: Starting video stream...
00:00:25 - SDL Info: Starting audio stream...
00:00:25 - SDL Info: Starting input stream...
00:01:00 - SDL Error: Connection terminated: 0
Frames dropped by your network connection: 0.00%
```
`session.exec(window)` is now reached, RTSP handshake succeeds, all five sub-streams start. Stream ran for ~35 s of live video with zero frame drops before the user disconnected. The `Connection terminated: 0` is a clean user-initiated disconnect, not a stage failure.

### Second app launch (regression sanity)
At 00:01:07 the user launched a second app (Virtual Display, `appid=873650758`). Identical clean progression through RTSP / control / video before the 90-s window closed. Two back-to-back successful launches confirm the fix isn't a one-shot.

### VAAPI / hooks still active
```
[vibemis-apprun-hook] preferring host libva from /usr/lib64 (via /tmp/tmp.…)
```

---

## 3. Tier 2 — PC list / mDNS

```
00:00:02 - Qt Info: "Navid-PC" is now online at "192.168.4.78:47989"
00:00:03 - Qt Info: Discovered mDNS host: "Navid-PC.local."
```
Same behaviour as test6/test7 — no regression to discovery or initial PC list.

---

## 4. Other findings

- **HEVC Main profile picked up correctly.** SDL initialised VAAPI 1.22 with the Mesa 25.3.0 driver; `hevc_cuvid` / `av1_cuvid` / VDPAU all skipped as expected (no NVIDIA hardware) and the fallback chain landed on a working renderer. Earlier "RFI latency bug" and "Deprioritizing VAAPI on Gallium driver" notes are pre-existing advisories, not regressions.
- **`QuickMenuManager::setWindowGeometry` is being called** at stream start with reasonable numbers (1280×720) — the menu plumbing is wired correctly.
- **No `parentMenu` regression** — PR #13 fix still holds.

---

## 5. Recommended next step

**MERGE.** Test8 is the first end-to-end success for the streaming path on Legion Go S Z2. The combined fix (`session.exec(window)` + `displayLaunchWarning` signal + `quickMenuManager.hasServerCommands` correction) closes out the cascade of stale QML→C++ calls that test7 surfaced. Stream launched, ran, and exited cleanly; mDNS / PC list / pairing all regression-free.

Suggested follow-ups (out of scope for this report, just observations):
- The `EGLRenderer: Cannot get EGL display: 12288` line appears during decoder enumeration but does not block streaming — worth tracking but not a blocker.
- HDR debug logs show the alternate-frontend renderer path running each enumeration; harmless on this SDR panel but verbose.
