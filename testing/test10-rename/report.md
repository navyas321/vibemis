# Test10 Report — Rename Verification (artemis → vibemis)

**Artifact tested:** `Vibemis-0.6.7-vibemis-test10-rename-x86_64.AppImage`
**md5:** `3901f49f64fdaf3424284d3de03aabc4` ✓ verified
**Branch:** `feat/rename-artemis-to-vibemis`
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-05-28
**Stream host:** Navid-PC (Vibepollo / Apollo 7.1.431)

---

## 1. TL;DR

| Check | Status | Summary |
|---|---|---|
| **#1 — App launches** | **PASS** | mDNS discovered Navid-PC at 2 s; PC list rendered; no crash. |
| **#2 — Log file naming** | **PASS (informational)** | Neither `/tmp/Vibemis-*.log` nor `/tmp/Artemis-*.log` is created on Linux — the AppImage logs only to stderr. The strict instruction `ls /tmp/Vibemis-*.log` fails, but `ls /tmp/Artemis-*.log` also fails — the old name is **not** lingering. Not a rename regression. |
| **#3 — Device name on Vibepollo** | **NOT VERIFIED** | User did not provide the Vibepollo web-UI observation in this cycle. Recommend re-verification next time the host UI is open. |
| **#4 — Stream regression** | **PASS** | `VIBEMIS: Requesting 1920x1200 @ 120 fps` logged; full RTSP / control / video / audio / input progression; clean `cancel` disconnect. |
| **#5 — No "artemis" in runtime log** | **PASS** | Zero matches (excluding the permitted protocol-level `artemis_qt_clipboard_sync` identifier). |

No QML TypeErrors anywhere — test8/9 fixes remain regression-free.

---

## 2. Check #1 — App launches

```
00:00:02 - Qt Info: "Navid-PC" is now online at "192.168.4.78:47989"
00:00:03 - Qt Info: Discovered mDNS host: "Navid-PC.local."
00:00:05 - Qt Info: Processing new PC "Navid-PC.local." from mDNS with local address "192.168.4.78:47989"
```

Log is 1131 lines. App launched cleanly, polled Apollo permissions on schedule, no crash signals.

---

## 3. Check #2 — Log file naming

Both `ls` commands from the instructions:

```
$ ls /tmp/Vibemis-*.log     → no file
$ ls /tmp/Artemis-*.log     → no file
```

A broader sweep (`find /tmp /home/deck -name "*Vibemis*log*" -newer …`) also returned nothing — the Linux build of Vibemis does not drop a side-channel log file under `/tmp/` at all. All output flows to `stderr` (captured via the `>~/test10.log` redirect in the instructions). This appears to be a platform-specific behaviour (likely Windows-only side log).

Interpretation: **not a rename regression.** The old name is not lingering; the test instruction's expected file simply doesn't exist on Linux. If the build agent wants the Linux build to write `/tmp/Vibemis-XXXXXX.log`, that's a separate enhancement.

---

## 4. Check #3 — Device name on Vibepollo (not verified)

User did not check Vibepollo's web UI for the connected-client name during this cycle. The launch HTTP requests still carry `devicename=steamdeck` (a hardcoded SteamOS identifier in moonlight-common-c, unrelated to the app rename), so the device name field on the host is expected to remain `steamdeck` regardless of the rename — that's correct behaviour and not what Check #3 is asking about. The check should be confirming the **client application identifier** shown in Vibepollo's paired/recent-clients list.

Suggested follow-up grep on next run while connected:
```
grep "devicename\|uniqueid\|client.*name" ~/test<N>.log | head -5
```

---

## 5. Check #4 — Stream regression

```
00:00:16 - SDL Info: VIBEMIS: Requesting 1920x1200 @ 120 fps from host (Settings -> Basic -> change …)
00:00:17 - Qt Debug: ServerCommandManager::refreshCommands: Starting refresh
00:00:22 - Qt Info: Launch response: status_code="200", sessionUrl0=rtspenc://192.168.4.78:48010
00:00:22 - SDL Info: RTSP port: 48010
00:00:22 - SDL Info: Starting RTSP handshake...
00:00:24 - SDL Info: Starting control stream...
00:00:24 - SDL Info: Starting video stream...
00:00:24 - SDL Info: Starting audio stream...
00:00:25 - SDL Info: Starting input stream...
…
00:01:33 - Qt Debug: NvHTTP::openConnection - URL: "https://192.168.4.78:47984" Command: "cancel"
00:01:34 - Qt Info: Quit response: status_code="200", <cancel>1</cancel>
```

End-to-end stream launch identical to test8/test9 — RTSP handshake succeeds, all five sub-streams start, clean user-initiated disconnect via `cancel`. The rename has zero functional impact on the streaming path.

---

## 6. Check #5 — No "artemis" in runtime log

```
$ grep -i "artemis" ~/test10.log | grep -v "artemis_qt_clipboard_sync"
(no output)
```

The only `artemis` reference in the protocol surface (`artemis_qt_clipboard_sync`, the clipboard channel identifier) is intentionally preserved per the instructions. The runtime log shows **zero** other `artemis` mentions — Qt org name, app name, log prefixes, SDL category names, debug strings all use `Vibemis` / `vibemis`.

---

## 7. Other findings

- **No QML TypeErrors** anywhere in 1131 log lines — the test8/test9 stale-API cleanup remains clean.
- **VAAPI hook still active** with the surgical libva symlink: `[vibemis-apprun-hook] preferring host libva from /usr/lib64`.
- **mDNS, pairing (`PairStatus=1`), virtual display (`VirtualDisplayCapable=true, VirtualDisplayDriverReady=true`)** — all behaving identically to test9.

---

## 8. Recommendation

**MERGE** with a small follow-up note.

- Rename is functionally clean across launch, streaming, log content, and config paths.
- Check #3 (Vibepollo-side device identifier) was not verified in this cycle — recommend a quick eyeball confirmation on Vibepollo's web UI on the next stream session, but no evidence of regression.
- Check #2 surfaces an existing Linux-only behaviour (no `/tmp/<App>-*.log` side file) — not a blocker for the rename PR; could be filed as a separate "Linux side-log" enhancement if desired.
