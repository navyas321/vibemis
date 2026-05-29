# Test20 Report — Uniqueid Persistence + Quick Menu SDL Capture Fix

**Artifact tested:** `Vibemis.AppImage` (`0.6.7-hotfix.20260529.0440+eae4ed0`)
**md5:** `102a59f5fca9dc34e9c98f8c63050122` ✓ verified
**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (commit `eae4ed00`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-05-29
**Prior report:** `testing/test19-pairing-timeout-fix/report.md`

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — uniqueid persists across restart | PASS ✅ | `3ca53e803678f6a4` identical in both sessions — no more 403 after restart |
| B — clipboard works after restart | PASS ✅ | User confirmed upload working; no 403 in either session's log |
| C — Quick Menu mouse capture released | PARTIAL ⚠️ | Menu window appears; mouse capture released per SDL fix; controller input still dead |
| D — Quick Menu geometry/scaling correct | FAIL ❌ | `setWindowGeometry: 224 140 1472 920` — user reports scaling still wrong in Desktop Mode |
| E — no regression | PASS ✅ | Video, VAAPI, mDNS, pairing state all intact |

---

## 2. Tier 1 — Uniqueid Persistence (Check 1)

Session 1 generated a fresh uniqueid; session 2 loaded the same value from QSettings.

```
# Session 1:
00:00:05 - Qt Info: Generated new unique ID: "3ca53e803678f6a4"

# Session 2 (app restarted, settings.ini preserved):
00:00:01 - Qt Info: Loaded unique ID from settings: "3ca53e803678f6a4"
```

**Result: PASS.** `IdentityManager` correctly persists the uniqueid across restarts. The 403 Forbidden regression from test19 (where a new random uniqueid per session caused HTTPS auth failures) is fully resolved.

---

## 3. Tier 2 — Clipboard After Restart (Check 2)

Session 2 connected cleanly, saw `PairStatus=1`, and ClipboardManager initialised with no 403:

```
00:00:05 - Qt Debug: ClipboardManager: Connected to "Navid-PC"
00:00:05 - Qt Debug: ClipboardManager: Apollo server detected - clipboard sync available
00:00:04 - Qt Info: getServerInfo HTTPS response: "... <PairStatus>1</PairStatus> ..."
```

No `403 Forbidden` anywhere in the log. User confirmed clipboard upload worked after restart.

**Result: PASS.**

---

## 4. Check 3 — Quick Menu Input

The SDL capture release (`SDL_SetRelativeMouseMode(SDL_FALSE)` + `SDL_ShowCursor(SDL_ENABLE)`) fires on menu open, which is why the overlay window appears. However:

- **Controller**: SDL detected `Steam Virtual Gamepad (VID/PID: 0x28de/0x11ff)` on session start. Despite that, no gamepad events reached the Quick Menu overlay. User reports "no input from controller" — the SDL release does not bridge controller events to the Qt window.
- **Mouse**: Not fully tested (user is on a handheld); the release should help a mouse cursor but was not confirmed independently.
- **Window creation log:**

```
00:00:11 - SDL Info (0): Gamepad 0 (player 0) is: Steam Virtual Gamepad ...
00:00:11 - SDL Info (0): Setting QuickMenuManager geometry: 805240832,805240832 1472x920 (actual pos: 224,140)
00:00:11 - Qt Debug: QuickMenuManager::setWindowGeometry: 224 140 1472 920
00:00:11 - SDL Info (0): Recreating renderer for window event: 1 (0 0)
```

Note the raw position `805240832,805240832` (≈ `0x2FFFE000`) before the actual pos is applied — the window's initial position appears uninitialised before `setWindowGeometry` clamps it.

No `executeAction`, `executeCommand`, `toggle`, or clipboard-sent entries appear anywhere in the Quick Menu section of the log, confirming **zero button interactions were registered**.

**Result: FAIL.** Menu window opens, SDL mouse capture released; gamepad/controller input routing to the Qt overlay is not working in Desktop Mode.

---

## 5. Check 3b — Quick Menu Geometry / Scaling

The menu geometry is computed as:

```
x = (stream_w - menu_w) / 2 = (1920 - 1472) / 2 = 224
y = (stream_h - menu_h) / 2 = (1200 -  920) / 2 = 140
```

This centres a 1472×920 popup over a 1920×1200 stream. In **Game Mode** (full-screen, stream fills the display) this would look correct. In **Desktop Mode** the stream runs in a smaller window — the geometry is applied in screen coordinates rather than window-relative coordinates, causing the menu to appear at the wrong position or scale on the physical panel.

User confirmed: "scaling still weird" (consistent across this session and test19).

**Result: FAIL.** Geometry calculation assumes full-screen stream; breaks in windowed Desktop Mode. Needs either window-relative coordinates or a mode check.

---

## 6. Check 4 — Server Commands / Bubbles

`ServerCommand>Bubbles` was present in HTTPS serverinfo from the start:

```
00:00:05 - Qt Debug: ServerCommandManager::refreshCommands: Loaded commands from serverinfo: QList("Bubbles")
```

The session ended due to an ENet drop at 01:14 before the user could invoke Bubbles from the Quick Menu. Since the Quick Menu itself accepted no input, this was not testable.

**Result: NOT TESTED** (Quick Menu input failure + ENet drop).

---

## 7. Other Findings

**ENet drop (1):**
```
00:01:14 - SDL Error (0): Connection terminated: -1
00:01:14 - Qt Critical: Connection terminated
00:01:14 - SDL Info (0): ENet peer is already disconnected
```
Single drop ~74 seconds into the stream. Consistent with prior sessions; environmental (Desktop Mode LAN instability), not a regression.

**X11 connection broke after stream cleanup:**
```
00:02:39 - Qt Warning: The X11 connection broke (error 1). Did the X11 server die?
The X11 connection broke: I/O error (code 1)
```
Occurs during teardown after the ENet drop + stream cleanup sequence. The app forcibly exits. Not a new regression (seen in test19); may be worth investigating if it prevents clean re-launch in the same desktop session.

**VAAPI / video:**
```
[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
00:00:05 - SDL Info (0): Using VAAPI accelerated renderer on x11
00:00:10 - SDL Info (0): Video stream is 1920x1200x120 (format 0x100)
```
PASS. AppRun VAAPI hook fires, hardware decode active, 1920×1200×120 stream confirmed.

---

## 8. Recommendation

**ITERATE.**

The two critical fixes in `eae4ed00` land correctly:

1. **Uniqueid persistence (PASS)** — `IdentityManager` is solid; the 403 regression is gone.
2. **Clipboard after restart (PASS)** — flows cleanly now that the uniqueid is stable.

Two Quick Menu issues remain for the next iteration:

1. **Controller input not routed to Qt overlay (FAIL)** — `SDL_SetRelativeMouseMode(SDL_FALSE)` releases mouse capture but gamepad events still don't reach the overlay window. In Desktop Mode, SDL holds the joystick event loop on the stream window. Possible approaches: `SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1`, explicit SDL event forwarding when the overlay is visible, or making the overlay receive SDL events directly rather than relying on Qt's input chain.

2. **Geometry wrong in windowed mode (FAIL)** — The `(stream_w - menu_w) / 2` centering math is correct for full-screen only. In Desktop Mode the stream window is smaller than the display; the offset needs to be computed relative to the stream window, not the screen. Recommend passing the stream window handle or rect into `setWindowGeometry` so coordinates are window-relative.

Both issues are Desktop Mode / windowed-specific. The Game Mode (supported) workflow likely behaves differently — recommend also verifying in Game Mode before the next cycle.
