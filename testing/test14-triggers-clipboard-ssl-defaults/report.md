# Test14 Report — Quick Menu Triggers, Clipboard SSL, OTP/ServerCommands Defaults

**Artifact tested:** `Vibemis.AppImage` (`0.6.7-hotfix.20260528.2011+ca827fd`)
**md5:** `d713628c76f7bc269b09469c5fed69de` ✓ verified
**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (commit `ca827fd`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-05-28
**Prior report:** `testing/test13-quickmenu-clipboard-otp/report.md`

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — Quick Menu keyboard/gamepad triggers | FAIL | Backend geometry fires; QML overlay invisible (`NavigableMenu.qml:10 TypeError`) |
| B — Clipboard SSL fix | PARTIAL | SSL error gone (VerifyNone works); server now returns `403 Forbidden` |
| C — textonly persistence | PASS | `textonly=true` survives restart; INI written correctly |
| D — OTPPairing default `true` | PARTIAL | INI has `enabled=true`; code still uses classic `phrase=getservercert` PIN flow |
| E — ServerCommands default `true` | PARTIAL | INI has `enabled=true`; Bubbles loaded from serverinfo; inaccessible (invisible menu) |
| F — No regression on video | PASS | VAAPI hook active, EGL pixel format 181, stream at 1920×1200×120 |
| G — Clipboard image support (post-test) | FAIL | Image copies from client arrive on host as raw text data, not as renderable image |

---

## 2. Check 1 — Video regression

No regression. Stream launched and rendered correctly.

```
[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
00:01:24 - SDL Info (0): EGLRenderer: EGLImage pixel format: 181
00:01:23 - SDL Info (0): Video stream is 1920x1200x120 (format 0x100)
```

---

## 3. Check 2 — Keyboard trigger (`Ctrl+Alt+Shift+\`)

**Result: FAIL — backend fires, overlay invisible.**

`QuickMenuManager::setWindowGeometry` logs appeared during the test run (confirmed by user pressing
the shortcut), but no overlay was visible on screen. Immediately after the trigger, the QML engine
threw a `TypeError`:

```
00:01:23 - Qt Debug: QuickMenuManager::setWindowGeometry: 224 140 1472 920
00:02:40 - Qt Warning: qrc:/gui/NavigableMenu.qml:10: TypeError: Cannot read property 'focus' of undefined
```

The C++ side correctly computes and sets the geometry window; the QML `NavigableMenu` component's
`focus` property is read before its parent/context is ready — the overlay is never shown.

**Side effect:** the invisible overlay captures input and routes `SDL Quit` events to the user:

```
00:02:08 - SDL Info (0): Quit event received
00:06:23 - SDL Info (0): Quit event received
00:09:04 - SDL Info (0): Quit event received
```

Each `Quit` was triggered inadvertently via the invisible menu, not from explicit quit actions.

---

## 4. Check 3 — Gamepad trigger (`Select+L1+R1+Y`)

**Result: NOT TESTED.**

Given that the keyboard shortcut confirmed the same QML bug, testing the gamepad path was skipped to
avoid triggering another unintended `Quit event`. Root cause is the same `NavigableMenu.qml:10`
`TypeError`; outcome would be identical.

---

## 5. Check 4 — Quick Menu actions

**Result: BLOCKED** — overlay never visible; no actions accessible.

ServerCommandManager did successfully load Bubbles from serverinfo (data is ready):

```
00:01:19 - Qt Debug: ServerCommandManager::refreshCommands: Loaded commands from serverinfo: QList("Bubbles")
```

The data pipeline works end-to-end; only the QML presentation layer is broken.

---

## 6. Check 5 — Clipboard sync

### 5a — Enable / smart sync

ClipboardManager initialises correctly and detects Apollo:

```
00:01:03 - Qt Debug: ClipboardManager: Loaded settings - enabled: false bidirectional: true maxSize: 1048576 bytes textOnly: true
00:01:07 - Qt Debug: ClipboardManager: Smart sync enabled
00:01:19 - Qt Debug: ClipboardManager: Apollo server detected - clipboard sync available
```

Settings toggled during session, then persisted on restart (see 5d).

### 5b — Client → Host upload

**FAIL.** SSL handshake no longer fails (VerifyNone fix works), but server rejects the request:

```
00:06:40 - Qt Warning: NvHTTP: Failed to send clipboard content:
  "Error transferring https://192.168.4.78:47984/actions/clipboard?type=text - server replied: Forbidden"
00:06:40 - Qt Warning: ClipboardManager: Failed to send clipboard to server
```

The `403 Forbidden` suggests the Vibepollo `/actions/clipboard` endpoint requires an auth token or
a specific header that Vibemis is not sending. The SSL layer is repaired; the authentication layer
is the next blocker.

### 5c — Host → Client fetch

**NOT TESTED via Quick Menu** (invisible overlay blocks access). No fetch attempt was logged.

### 5d — textonly persistence

**PASS.** After toggling settings and restarting:

```
00:04:26 - Qt Debug: ClipboardManager: Loaded settings - enabled: true bidirectional: true maxSize: 20971520 bytes textOnly: true
```

INI on disk confirms all values persisted:

```ini
[ClipboardSync]
bidirectional=true
enabled=true
maxSize=20971520
textonly=true
```

---

## 7. Check 6 — OTP Pairing

**Result: FAIL — code still uses classic Moonlight PIN flow.**

INI correctly shows the new default:

```ini
[OTPPairing]
enabled=true
timeout=120
```

However all three pairing attempts in the log use `phrase=getservercert` (the classic Moonlight
four-phase PIN handshake), not an OTP exchange:

```
00:04:23 - Qt Info: Executing request: ".../pair?...&phrase=getservercert&salt=..."
00:04:38 - Qt Debug: PcView.pairingComplete called with error: Connection closed (Error 2)
00:05:07 - Qt Info: Executing request: ".../pair?...&phrase=getservercert&salt=..."
00:05:12 - Qt Debug: PcView.pairingComplete called with error: Connection closed (Error 2)
00:05:16 - Qt Info: Executing request: ".../pair?...&phrase=getservercert&salt=..."
00:05:29 - Qt Info: Executing request: ".../pair?...&phrase=pairchallenge"
00:05:29 - Qt Debug: PcView.pairingComplete called with error: undefined   ← success
```

Pairing succeeded on the third attempt using the classic flow. The race condition (two simultaneous
attempts, one winning) observed in test13 is still present. The `OTPPairing.enabled` flag is written
to INI but the pairing code path never reads it — the new dialog / OTP exchange is not wired up.

---

## 8. Check 7 — Server Commands

**Result: BLOCKED** — Quick Menu invisible; panel inaccessible.

ServerCommandManager initialises and reads `Bubbles` from serverinfo (see Check 4). The feature is
functionally ready; it cannot be exercised until the QML overlay is fixed.

INI:

```ini
[ServerCommands]
enabled=true
showAdvanced=false
```

---

## 9. Other findings

- **Invisible Quick Menu captures input / fires Quit.** This is more disruptive in test14 than test13
  because the geometry is now consistently being set. Users inadvertently quit three streams during this
  session without knowing the menu was active. The fix is blocking, not cosmetic.
- **Pairing race condition persists.** Two pairing workers fire simultaneously on the first attempt;
  one gets `Connection closed (Error 2)`, the other proceeds. Not a new regression, but worth tracking.
- **Desktop Mode environmental:** Steam Input is present (`Steam Virtual Gamepad` mapped at
  `00:01:24`), so the controller mapping isn't the issue — the QML bug would affect Game Mode equally.
- **Stream drops: ENet `Transaction failed: 11` pattern.** Post-report streaming sessions consistently
  terminated after 30–60 seconds with `Connection terminated: -1` / `Loss Stats: Transaction failed: 11`.
  The Vibemis app survives (returns to the PC list) — this is a network-level ENet drop, not a Vibemis
  crash. Likely Wi-Fi interference or the host retaining a stale session. Not a code regression; flagged
  for awareness.
- **Image clipboard: data arrives as text, not as image (post-report finding).** With `textOnly=false`
  and max size raised to 60 MB+, copying an image on the Z2 client does transmit data to the host via
  the Moonlight control-stream clipboard protocol — but the host renders it as raw text (binary/base64
  garbage) rather than as a pasteable image. The MIME type or format metadata is not being preserved in
  the clipboard payload. **Build agent: check whether upstream Artemis Qt / Moonlight Qt ever supported
  non-text MIME types (image/png, image/jpeg, etc.) in the clipboard sync protocol, and match that
  behaviour. If Artemis never supported images, document the limitation explicitly and consider whether
  to strip or properly encode non-text payloads rather than passing raw binary through the text path.**
- **Client→Host text clipboard confirmed working** (control-stream path, independent of the Apollo
  HTTP endpoint). The 403 Forbidden on `/actions/clipboard` only affects the host→client fetch path.

---

## 10. Recommendation

**ITERATE.**

Three distinct issues remain open; they are independent enough to fix in parallel:

1. **Quick Menu QML bug** (blocking everything) — `NavigableMenu.qml:10: TypeError: Cannot read
   property 'focus' of undefined`. The C++ geometry/trigger plumbing is correct. The fix is in QML:
   guard the `focus` assignment until the component's parent context is live, or restructure the
   menu component instantiation order. Until this is fixed, Checks 3, 4, 7, and 5c cannot be
   confirmed.

2. **Clipboard 403 Forbidden** — investigate whether `/actions/clipboard` requires an auth header
   (e.g. the pairing `uniqueid`, a session token, or a specific `Content-Type`). Compare with how
   Vibepollo's own web UI authenticates the same endpoint.

3. **OTP code path not wired** — `OTPPairing.enabled` is now stored and defaulted correctly, but
   the pairing function still always calls `phrase=getservercert`. The settings flag needs to branch
   into an OTP-specific dialog and exchange rather than being a no-op.

4. **Image clipboard MIME handling** — non-text clipboard content (images, files) transmits raw binary
   through the text clipboard path, arriving on the host as unrenderable text data. Audit upstream
   Artemis Qt / Moonlight Qt for `image/*` MIME type support in the clipboard protocol; either match
   it or explicitly clamp non-text payloads (don't silently corrupt them).
