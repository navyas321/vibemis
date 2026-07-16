# Test113 Report — Bubbles in-session server-command E2E (BL-1850)

**Artifact tested:** `Vibemis.AppImage` (= `Vibemis-0.2.0-beta.013-x86_64.AppImage`)
**md5:** `ee4874851d3c9644a355c3fa7be71028` ✓ verified (sha256 also matches release digest)
**Branch:** `test113-bubbles-e2e` (commit `5c36fa4`) — beta cycle, no branch AppImage by design
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0 (Desktop Mode, XWayland/xcb)
**Test date:** 2026-07-16
**Prior report:** N/A (BL-1811 host-side RCA/mitigations closed; this is the client-path residual)

All local timestamps EDT (UTC-4). Host-side timestamps from the build agent over the
coordination bus (messages of 2026-07-16 11:54 EDT).

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — Bubbles fired once from real client in live session | PASS | Trigger 15:52:27Z → `Bubbles.scr` pid 14468 up host-side +1.3 s |
| B — Bubbles self-terminates (BL-1821 teardown) | PASS | START 15:52:28.29Z → GONE 15:52:43.09Z = 14.8 s, zero manual input |
| C — Host display stays healthy (no re-armed idle) | PASS | `powercfg` DISPLAY: only sunshine.exe during stream; zero streaming-stack holders after |
| D — Clean client quit / no regression | PASS | All 4 streams stopped cleanly, no crash; host session quit (`cancel=1`) |

**Bonus finding (client bug, not a blocker):** the client toasts/logs the command as FAILED
(`result: 1`) even though it succeeded — an inverted success check. See §4.

---

## 2. Tier 0 — smoke (no host)

```
ee4874851d3c9644a355c3fa7be71028  /home/deck/Downloads/Vibemis.AppImage
{"checks":{...,"prefs-load":true,...},"failures":0,"result":"PASS"}
selftest exit=0
```

## 3. Tier 1 — pair + live stream

Host screen ON + sleep disabled confirmed by host operator on the bus at 11:43 EDT, before Tier 1.
Navid-PC already paired (`PairStatus=1`); serverinfo advertised `<ServerCommand>Bubbles</ServerCommand>`.
Session launched 11:51 EDT (log-relative `00:05:58`):

```
00:05:58 - SDL Info (0): Starting RTSP handshake...
00:05:59 - SDL Info (0): Starting control stream...
00:05:59 - SDL Info (0): Starting video stream...
00:05:59 - SDL Info (0): Starting audio stream...
00:05:59 - SDL Info (0): Starting input stream...
00:05:59 - SDL Info (0): EGLRenderer: EGLImage pixel format: 181
00:05:59 - FFmpeg: [hevc @ ...] Decode context initialised: 0x15/0x16.
```

EGLRenderer active, HEVC via VAAPI, live video confirmed on-device. Zero decode errors,
zero connection-terminated events for the whole session.

## 4. Tier 2 — Bubbles trigger + host display health

No physical keyboard on the device — all keys were injected via xdotool (XWayland);
the user only tapped Navid-PC → Desktop to start the stream.

- **11:52:03 EDT** — Quick Menu combo injected: `Detected quick menu toggle combo`; offscreen
  overlay renderer initialized (1177x736). Server-commands model: 1 command (`Bubbles`).
- **11:52:27 EDT (15:52:27Z)** — Bubbles selected, **exactly once**:

```
00:06:55 - Qt Debug: ServerCommandManager: Executing command: "Bubbles"
00:06:55 - Qt Debug: ServerCommandManager: Mapped command "Bubbles" to index 0
00:06:55 - Qt Debug: ServerCommandManager: Using ENet-based command execution
00:06:55 - Qt Warning: ServerCommandManager: Command execution failed: "Bubbles" with result: 1
```

- **Host truth (build agent, bus 11:54 EDT):** `Bubbles.scr` pid 14468 launched **15:52:28.29Z**
  (+1.3 s after trigger) → GONE **15:52:43.09Z** = **14.8 s, self-terminated** with no manual
  input (`Stop-Process -Name 'Bubbles*'` wrapper works). BL-1821 teardown satisfied.
- **Display health:** `powercfg /requests` after the trigger showed only `sunshine.exe`
  (the live stream itself — expected) and **no Bubbles / SudoVDA / display-helper holder**.
  After the stream ended (host check 15:59Z): **zero holders from the vibemis/Vibepollo
  stack** — no sunshine, no Bubbles, no SudoVDA. (The only DISPLAY entry was claude.exe,
  the host operator's own remote-session tooling, unrelated to the streaming stack.)
  The BL-1811 display bug does **not** return via the client path. Host verdict: PASS.

**Client bug found — inverted success polarity (cosmetic, but misleading):**
`LiSendExecServerCmd` (moonlight-common-c `ControlStream.c:2054`) returns the **bool** from
`sendMessageAndForget` (`ControlStream.c:844`), where **true (1) = message sent OK**.
`app/backend/servercommandmanager.cpp:317` treats `result == 0` as success — inverted.
So every *successful* send is logged as `Command execution failed ... result: 1` and the
user sees a "failed" toast while the command actually runs on the host. Conversely a real
send failure (result 0) would toast "executed successfully". Fix: treat nonzero as success
(one-line polarity flip). Not patched here per test-agent scope — build agent to pick up.

## 5. Clean quit + teardown status (BL-1821)

- **11:54:59 EDT** — quit combo injected:

```
00:09:27 - SDL Info (0): Detected quit key combo
00:09:27 - SDL Info (0): Stopping input stream...
00:09:27 - SDL Info (0): Stopping audio stream...
00:09:27 - SDL Info (0): Stopping video stream...
00:09:27 - SDL Info (0): Stopping control stream...
```

No crash, no coredump, no stuck input; app returned to the grid.
- Host session then quit via CLI (`Vibemis.AppImage quit "Navid-PC"`):
  `Quit response: ... <cancel>1</cancel>` (HTTP 200). Follow-up CLI `list` connected fine.
- **Nothing left running on the host that this cycle started:** Bubbles self-terminated
  (host-verified), streaming session cancelled, client closed.

## 6. Other findings

- The natural 900 s idle-sleep observation was **impossible in-window by design**: the host
  operator had display-sleep disabled as a test precondition. Mechanism-level evidence
  (zero streaming-stack `powercfg` holders post-stream) recorded per instructions; the 900 s natural
  sleep after a client-triggered Bubbles is flagged as a follow-up observation (host-side
  five consecutive 900 s cycles were already proven in BL-1811 closure).
- Desktop Mode note: Qt fell back from wayland to xcb (`Could not find the Qt platform
  plugin "wayland"`) — harmless, and it is what makes xdotool injection possible.

## 7. Recommendation

**MERGE-verdict: close BL-1850.** The one unverified link is now verified end-to-end on
device: real client, live stream, in-session trigger, host-side self-termination, display
healthy. Two follow-ups for the build agent:
1. **File + fix the `servercommandmanager.cpp:317` result-polarity bug** (client reports
   success as failure; wrong toast both ways). One-line fix + a success-toast retest.
2. Optional: observe one natural 900 s display-off on the host with sleep re-enabled after
   a client-triggered Bubbles, to convert the mechanism-level display pass into the
   strongest-form evidence.
