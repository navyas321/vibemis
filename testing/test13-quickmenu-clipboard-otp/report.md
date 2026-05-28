# Test13 Report — Quick Menu, Clipboard Sync, OTP Pairing

**Artifact tested:** `Vibemis.AppImage`  
**Release:** `0.6.7-hotfix.20260528.1926+371e87e`  
**md5:** `94efdf5978a010a8dfe0295eaa839e80` ✓ verified  
**Branch:** `verify/test13-quickmenu-clipboard-otp` (commit `371e87e`)  
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0  
**Test date:** 2026-05-28  
**Prior report:** `testing/test12-egl-fix-and-apollo/report.md`

---

## 1. TL;DR

| Check | Status | Summary |
|---|---|---|
| 1 — Video regression | PASS | EGL renders, VAAPI confirmed, no black screen |
| 2 — Quick Menu | PARTIAL | Quit/Disconnect actions work; keyboard & gamepad triggers non-functional |
| 3 — Clipboard sync | PARTIAL | No crash on text-only toggle (regression fixed); all transfers fail SSL; text-only setting doesn't persist |
| 4 — Server Commands | BLOCKED | Feature disabled by default in settings (`ServerCommands.enabled=false`) |
| 5 — OTP Pairing | BLOCKED | Feature disabled by default in settings (`OTPPairing.enabled=false`); PIN fallback used |
| 6 — Bitrate/Refresh | PASS | 1920×1200 @ 120 fps, settings file shows `customRefreshRate=60` persisted |

---

## 2. Check 1 — Video regression (PASS)

```
[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
00:00:26 - SDL Info (0): EGLRenderer: EGLImage pixel format: 181
```

FORCE_VAAPI=1 hook active, EGL rendering confirmed, no shader errors, no recreate loop.
Video visible on screen across multiple stream sessions.

---

## 3. Check 2 — Quick Menu (PARTIAL)

**QuickMenuManager confirmed initialising and opening** — geometry set on every stream attempt:
```
00:00:59 - Setting QuickMenuManager geometry: 805240832,805240832 1472x920 (actual pos: 224,140)
00:00:59 - QuickMenuManager::setWindowGeometry: 224 140 1472 920
```

**Sub-check results:**

| Sub-check | Result | Notes |
|---|---|---|
| 2a — Keyboard `Ctrl+Alt+Shift+\` | FAIL | User reports no response; no overlay triggered |
| 2b — Gamepad `Select+L1+R1+Y` | FAIL | User reports no response; no overlay triggered |
| 2c — Performance Stats toggle | NOT TESTED | Couldn't reliably navigate to it |
| 2d — Fullscreen toggle | NOT TESTED | Couldn't reliably navigate to it |
| 2e — Quit action | PASS | `Quit event received` in log each time; clean return to PC list |

Note: The Quick Menu opened during testing via an unconfirmed trigger (possibly an
on-screen element). Keyboard and gamepad shortcuts were tested but produced no visible
result and no log entries. A QML warning appeared on menu navigation:
```
qrc:/gui/NavigableMenu.qml:10: TypeError: Cannot read property 'focus' of undefined
```
This is non-fatal but may relate to focus handling in the menu.

---

## 4. Check 3 — Clipboard Sync (PARTIAL)

**Settings persistence check:**

`~/.config/Vibemis Project/Vibemis/vibemis-settings.ini` after session:
```ini
[ClipboardSync]
bidirectional=true
enabled=true
maxSize=10485760
```

`enabled`, `bidirectional`, and `maxSize` **persist correctly** across restarts. ✅

`textonly` key is **absent from the file** — text-only mode is not persisted; it resets
to default (true) on each app launch. Confirmed in log:
```
00:00:07 - ClipboardManager: Loaded settings - enabled: true bidirectional: true maxSize: 10485760 bytes
00:00:21 - ClipboardManager: Text-only mode changed to false
```
The `changed to false` line fires when the user unchecks it mid-session, but the INI
never gains a `textonly=false` entry.

**Text-only toggle crash (regression from test12): FIXED** ✅  
Unchecking "text only contents" no longer crashes. `Text-only mode changed to false`
logged cleanly with no SIGABRT.

**All clipboard transfers fail — SSL hostname mismatch:**
```
00:00:35 - NvHTTP: Sending clipboard content to server: "https://192.168.4.78:47984/actions/clipboard?type=text"
00:00:35 - NvHTTP: Failed to send clipboard content: "SSL handshake failed: The host name did not match any of the valid hosts for this certificate"
00:00:35 - ClipboardManager: Failed to send clipboard to server
```

Root cause: the clipboard endpoint connects by IP (`192.168.4.78`), but Vibepollo's
self-signed cert is issued to hostname `Navid-PC`. The IP is not in the cert's SAN.
Affects all directions and all content types (text and image).

**Additional clipboard bugs observed:**

1. **Polling fires outside of active stream** — ClipboardManager continues attempting
   sends while at the PC list (no stream active). Should be stream-scoped only.

2. **Accelerating retry loop** — after repeated SSL failures, retry interval collapses
   from ~10s to <2s, hammering the endpoint. No backoff is applied on persistent failure.

**Summary:**

| Sub-check | Result | Notes |
|---|---|---|
| 3a — Enable toggle | PASS | `enabled=true` persists in INI |
| 3b — Client→Host upload | FAIL | SSL hostname mismatch on HTTPS endpoint |
| 3c — Host→Client fetch | FAIL | SSL hostname mismatch on HTTPS endpoint |
| 3d — Text-only toggle (no crash) | PASS | Regression from test12 fixed ✅ |
| 3e — Image clipboard | FAIL | SSL hostname mismatch; `?type=text` used even for images |
| 3f — Settings persistence | PARTIAL | `enabled`/`bidirectional`/`maxSize` persist; `textonly` does not |

---

## 5. Check 4 — Server Commands (BLOCKED)

`vibemis-settings.ini` shows:
```ini
[ServerCommands]
enabled=false
showAdvanced=false
```

Server Commands is **disabled by default**. The Quick Menu Server Commands panel would
be inaccessible or greyed out without first enabling this in Settings.

Server command discovery works correctly — `"Bubbles"` was loaded on every stream:
```
00:00:54 - ServerCommandManager::refreshCommands: Loaded commands from serverinfo: QList("Bubbles")
```

**Action needed:** Enable `ServerCommands.enabled=true` in settings before this check
can be tested. This is a settings default issue, not a code bug.

---

## 6. Check 5 — OTP Pairing (BLOCKED / PARTIAL)

`vibemis-settings.ini` shows:
```ini
[OTPPairing]
enabled=false
timeout=120
```

OTP Pairing is **disabled by default**. With `enabled=false`, the client falls back to
classic Moonlight PIN pairing regardless of server type. Log confirms PIN flow was used:

```
00:00:06 - Qt Info: Pairing with server generation: 7
00:00:06 - NvHTTP: pair?devicename=roth&phrase=getservercert&salt=...
00:00:26 - Qt Debug: PcView.pairingComplete called with error: undefined
00:00:26 - Qt Debug: ComputerModel: Emitted pairingCompleted signal
```

Pairing completed successfully via PIN. Apollo server fields are present in serverinfo
(`ServerCommand`, `Permission`, `VirtualDisplayCapable`) confirming detection works.

**Action needed:** Enable `OTPPairing.enabled=true` in settings to test the OTP path.
Once enabled, the `isApolloServer()` detection should route to the OTP dialog.

---

## 7. Check 6 — Bitrate / Refresh Rate (PASS)

```
00:00:53 - VIBEMIS: Requesting 1920x1200 @ 120 fps from host
```

Settings file confirms `customRefreshRate=60` was saved from prior testing.
The 120 fps stream uses the basic `fps=120` from `Vibemis.conf` (General settings),
not the extended `customRefreshRate`. Both values persist correctly.

---

## 8. Other findings

- **`devicename=roth`** in pairing requests — this is the legacy Moonlight device
  identifier, not `steamdeck` or `vibemis`. Minor cosmetic issue.

- **`Permissions.showServerPermissions=true`** in settings — the permission UI is
  wired up but Server Commands is gated behind `ServerCommands.enabled`.

- **`InputOnly.enabled=false`** — InputOnly mode present in settings, not tested.

- **`ClientDisplay.virtualDisplayEnabled=false`** — virtual display not enabled in
  extended settings (the general `virtualdisplay=true` in `Vibemis.conf` may override).

---

## 9. Recommendation

**ITERATE** — two remaining code bugs plus two settings-default issues:

**Code bugs (build agent):**

1. **Quick Menu keyboard/gamepad triggers silent** — `Ctrl+Alt+Shift+\` and
   `Select+L1+R1+Y` produce no log entry and no overlay. The trigger registration or
   SDL event filter may not be active in this build/environment.

2. **Clipboard SSL hostname mismatch** — the clipboard HTTPS endpoint connects by IP
   (`192.168.4.78`) but the cert is for `Navid-PC`. Fix: use `QSslSocket::setPeerVerifyMode(QSslSocket::VerifyNone)` for the clipboard endpoint (peer is already trusted via pairing), OR connect by hostname instead of IP, OR add IP SAN to cert generation. Additionally: (a) scope clipboard polling to active stream only; (b) apply exponential backoff on SSL failure.

3. **`textonly` setting not persisted** — `ClipboardManager` saves `enabled`,
   `bidirectional`, and `maxSize` but not the text-only flag. Should write
   `textonly=<bool>` to `[ClipboardSync]` on change.

**Settings defaults (build agent):**

4. **`OTPPairing.enabled` defaults to `false`** — for Apollo/Vibepollo servers this
   should default to `true`, or at minimum the first-run experience should prompt the
   user. Currently OTP is dead-on-arrival without manual settings change.

5. **`ServerCommands.enabled` defaults to `false`** — same issue; default should be
   `true` for Apollo servers, or enable automatically when `isApolloServer()` is true.
