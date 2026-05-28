# Test12 Report — EGL Fix Verification + Apollo Feature Matrix

**Artifact tested:** `Vibemis.AppImage`  
**Release:** `0.6.7-alpha.vibemis-main.20260528.0903+c1bb68b`  
**md5:** `a6a7ec3c13c9de7b2d4b347abf26c2b6` ✓ verified  
**Branch:** `verify/test12-egl-fix-apollo-rerun` (commit `c1bb68b`)  
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0  
**Test date:** 2026-05-28  
**Prior report:** `testing/test11-apollo-features/report.md`

---

## 1. TL;DR

| Check | Status | Summary |
|---|---|---|
| 1 — EGL fix: visible video | PASS | VAAPI init confirmed, no shader errors, no recreate loop, video rendered |
| 2 — Quick Menu | FAIL | Keyboard shortcut silent; gamepad combo SIGSEGV crash |
| 3 — Clipboard sync | FAIL | Sync non-functional both directions; "text only" toggle-off SIGABRT crash |
| 4 — Server Commands | BLOCKED | Requires Quick Menu (Check 2 FAIL) |
| 5 — OTP Pairing | PARTIAL | Re-paired successfully via PIN; OTP dialog never appeared |
| 6 — Bitrate / Refresh | PASS | 1920×1200 @ 120 fps requested; 32 Mbps bitrate matches config |

---

## 2. Check 1 — EGL fix: visible video (PASS)

PRs #29 and #30 both confirmed active. No shader errors. No infinite recreate loop.

```
[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
00:00:57 - FFmpeg: VAAPI driver: Mesa Gallium driver 25.3.0 for AMD Ryzen Z2 Go
00:01:00 - SDL Info (0): EGLRenderer: EGLImage pixel format: 181
```

The single `Recreating renderer for window event: 1` at 00:01:00 is a normal window-resize event, not the infinite recreate loop from test11. Video was visible on screen, confirming the `egl.vert` shader fix in PR #30 resolves the black-screen bug.

---

## 3. Check 2 — Quick Menu (FAIL)

The Quick Menu manager initialises and connects correctly:
```
00:00:57 - ServerCommandManager and ClipboardManager initialized and connected to QuickMenuManager
00:00:59 - Setting QuickMenuManager geometry: 805240832,805240832 1472x920 (actual pos: 224,140)
00:00:59 - QuickMenuManager::setWindowGeometry: 224 140 1472 920
```

However:
- **Keyboard shortcut `Ctrl+Alt+Shift+\`**: pressed during active stream — no overlay appeared, no log entry.
- **Gamepad combo `Select+L1+R1+Y`**: pressing this combination **crashed the entire app** (SIGSEGV confirmed in coredump journal at 14:35 EDT and 14:38 EDT):

```
coredumpctl list:
14:35:05 EDT  23261  Vibemis  SIGSEGV  inaccessible
14:38:21 EDT  23524  Vibemis  SIGSEGV  inaccessible
```

Coredumps are inaccessible (AppImage mount gone by capture time — same limitation as test11). No backtrace available from coredumpctl.

**All sub-checks 2b–2e untestable.** The overlay never appeared by any trigger method.

---

## 4. Check 3 — Clipboard Sync (FAIL)

ClipboardManager initialised with sync **disabled by default** and connected to host:
```
00:00:56 - ClipboardManager: Loaded settings - enabled: false bidirectional: true maxSize: 1048576 bytes
00:00:57 - ClipboardManager: Connected to "Navid-PC"
00:00:57 - ClipboardManager: Apollo server detected - clipboard sync available
```

User enabled the setting in preferences. Results:
- **Client → Host (text-only mode ON)**: no text transferred; Navid-PC received nothing.
- **Host → Client (text-only mode ON)**: no text transferred; Z2 clipboard unchanged.
- **Disabling "text only contents" checkbox**: app crashed immediately — SIGABRT confirmed in coredump journal at 14:25:46 EDT:

```
coredumpctl list:
14:25:46 EDT  21851  Vibemis  SIGABRT  inaccessible
```

No clipboard-related log entries beyond initial init; no upload/fetch operations were recorded.

---

## 5. Check 4 — Server Commands (BLOCKED)

Quick Menu is required to reach the Server Commands panel mid-stream. Since Check 2 is FAIL, Server Commands could not be tested interactively.

However the server **does** have a command configured and permissions are granted:
```
00:00:57 - ServerCommandManager::refreshCommands: Server commands from computer: QList("Bubbles")
00:00:05 - Permission: 118693632  (0x7131F00 — Apollo full-permission bitmask)
```

Once Quick Menu is fixed, "Bubbles" should be executable. Command discovery and permission parsing both work correctly.

---

## 6. Check 5 — OTP Pairing (PARTIAL)

User unpairing confirmed in log (`PairStatus: 0` at 00:11:12 on HTTP response). Re-pair succeeded — `PairStatus: 1` confirmed on HTTPS response immediately after:

```
00:11:12 - getServerInfo response: ... <PairStatus>0</PairStatus> ...   ← unpaired (HTTP)
00:11:12 - getServerInfo HTTPS response: ... <PairStatus>1</PairStatus> ... ← paired (HTTPS)
```

**Issue:** No OTP dialog appeared. The user paired by manually entering a PIN on the host (classic Moonlight/GFE PIN flow), not via an OTP prompt. For an Apollo/Vibepollo server, the expected behaviour is an OTP dialog in the client where the host's web UI accepts the code. The PIN fallback worked, but OTP detection against a Vibepollo host is not triggering.

---

## 7. Check 6 — Bitrate / Refresh Rate (PASS)

```
00:00:57 - VIBEMIS: Requesting 1920x1200 @ 120 fps from host
00:00:57 - Video bitrate: 32000 kbps
```

Resolution (`1920×1200`) and refresh rate (`120 fps`) match the configured values in `Vibemis.conf`. Bitrate of `32000 kbps` (32 Mbps) matches `bitrate=32000` in config. The test was not re-run with a 50 Mbps override due to earlier crashes consuming the test window.

---

## 8. Crash summary

Four distinct crash events in the test12 window:

| Time (EDT) | Signal | Trigger | Coredump |
|---|---|---|---|
| 14:25:46 | SIGABRT | Clipboard "text only" toggle-off | inaccessible |
| 14:27:37 | SIGSEGV | Unknown (likely Quick Menu retry) | inaccessible |
| 14:29:19 | SIGSEGV | Unknown (Quick Menu retry) | inaccessible |
| 14:35:05 | SIGSEGV | Gamepad combo `Select+L1+R1+Y` | inaccessible |
| 14:38:21 | SIGSEGV | Gamepad combo retry | inaccessible |
| 14:46:13 | SIGSEGV | Unknown (final session) | inaccessible |

All coredumps are inaccessible (AppImage squashfs is unmounted by the time systemd-coredump captures). Backtraces are unavailable from coredumpctl. Build agent should instrument crashes via signal handler writing `/tmp/vibemis-crash-<pid>.bt` before exit if further diagnosis is needed.

---

## 9. Other findings

- **ClipboardManager `enabled: false` by default**: the setting needs manual enabling each session (or should default to `true` for Apollo servers).
- **Keyboard shortcut not responding**: `Ctrl+Alt+Shift+\` pressed during active stream — no visible response and no log entry. The shortcut handler may not be receiving the event in Desktop Mode (SDL window focus issue).
- **Server command "Bubbles"** is present and permission `0x7131F00` is granted — blocked only by Quick Menu crash, not by permission or discovery.

---

## 10. Recommendation

**ITERATE** — three blocking issues for the build agent:

1. **Quick Menu crash on gamepad combo `Select+L1+R1+Y`** (SIGSEGV): The gamepad input handler for the Quick Menu shortcut has an out-of-bounds or null-pointer access. The keyboard path also silently fails. Both need investigation in `QuickMenuManager` input handling.

2. **Clipboard crash on "text only" toggle** (SIGABRT): The `ClipboardManager` crashes when the "text only contents" option is toggled off in preferences during an active session. Likely an assertion or invalid state transition when switching content filter modes. Clipboard sync also non-functional even before the crash.

3. **OTP pairing not triggering for Apollo/Vibepollo**: Pairing falls back to classic PIN flow. The Apollo server detection works (Apollo-specific fields appear in serverinfo XML), but the OTP pairing dialog is not presented. Check the pairing code path's Apollo/OTP branch condition.

Check 6 (bitrate/refresh) and server command discovery are working correctly — no action needed there.
