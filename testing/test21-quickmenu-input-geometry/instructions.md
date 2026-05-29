# Test21 Instructions — Quick Menu Input + Geometry

**Branch:** `fix/quickmenu-triggers-clipboard-ssl-defaults` (PR #36)
**Device:** Lenovo Legion Go S Z2, SteamOS **— test in Game Mode first, then Desktop Mode**
**Host:** Navid-PC running Vibepollo 7.1.431

> ⚠️ **Test in Game Mode (Gamescope) if possible.**
>
> Game Mode is the primary target. Gamescope is a separate micro-compositor — a
> `QQuickView` separate window will NOT appear in Game Mode (Gamescope owns all
> z-ordering). If the Quick Menu doesn't appear in Game Mode, that confirms the
> QQuickView architecture needs to move to SDL-internal overlay rendering (see CLAUDE.md).
> Desktop Mode results are secondary. Please note which mode you tested in.

## What changed since test20

| Fix | test20 result | Now |
|---|---|---|
| **Controller input dead in overlay** | SDL_SetRelativeMouseMode released mouse but gamepad events still went to host | D-pad/A/B intercepted in `handleControllerButtonEvent` while menu open; injected as Qt key events (Up/Down/Left/Right/Return/Escape) on Qt main thread |
| **Geometry wrong in windowed mode** | `(stream_w - menu_w)/2` used SDL coords which differ from Qt logical coords at non-100% DPI | Now centres using `QGuiApplication::primaryScreen()->geometry()` — always in Qt logical coordinates |
| **SDL_CaptureMouse missing** | Only `SDL_SetRelativeMouseMode` was called | Added `SDL_CaptureMouse(SDL_FALSE)` alongside the existing SDL release calls |

## Setup

```bash
pkill -f Vibemis || true
# settings.ini can stay — uniqueid already persists

wget -O ~/Vibemis-test21.AppImage \
  "$(curl -s https://api.github.com/repos/navyas321/vibemis/releases \
     | python3 -c "import sys,json; r=json.load(sys.stdin); \
       urls=[a['browser_download_url'] for x in r \
             for a in x['assets'] if 'AppImage' in a['name']]; \
       print(urls[0] if urls else '')")"
chmod +x ~/Vibemis-test21.AppImage
md5sum ~/Vibemis-test21.AppImage

~/Vibemis-test21.AppImage > ~/test21.log 2>&1 &
sleep 4
```

---

## Check 1 — Quick Menu: geometry centred correctly

Start a stream. Press `Ctrl + Alt + Shift + \`.

**Expected:** Dark menu rectangle appears **centred on the screen** (not offset to top-left or partially off-screen).

**test20:** Menu was offset (~224px right, ~140px down from top-left) due to SDL/Qt coordinate mismatch.

**Report:** Is the menu centred? Approximate screen position seen.

---

## Check 2 — Quick Menu: controller D-pad navigation

With Quick Menu open, use the **D-pad** to navigate:
- D-pad Up/Down → highlight moves through menu items
- **A button** (South face button) → activates the highlighted item
- **B button** (East face button) → dismisses the menu

**test20:** No controller input reached the overlay at all.

**Report:** D-pad navigation PASS/FAIL, A to confirm PASS/FAIL, B to dismiss PASS/FAIL.

---

## Check 3 — Quick Menu: Clipboard Upload via controller

Use D-pad to navigate to **Clipboard Upload**. Press A.

Copy text on Z2 before opening the menu. After pressing A on Clipboard Upload, paste on Navid-PC.

**Expected:** Text transferred, no 403 error.

```bash
grep -i "clipboard\|executeAction\|upload\|403" ~/test21.log | head -10
```

---

## Check 4 — Quick Menu: Server Commands / Bubbles via controller

Navigate to **Server Commands** → select **Bubbles** → press A.

**Expected:** Bubbles executes on Navid-PC.

```bash
grep -i "Bubbles\|servercommand\|executeCommand" ~/test21.log | head -5
```

---

## Check 5 — Video regression

```bash
grep -E "FORCE_VAAPI|video stream is|EGLRenderer" ~/test21.log | head -5
```

---

## Report

Create `testing/test21-quickmenu-input-geometry/report.md` on branch
`diagnostic/test21-quickmenu-input-geometry-report` with:

1. AppImage version + MD5
2. Check 1 — geometry centred: PASS/FAIL + position description
3. Check 2 — D-pad nav / A confirm / B dismiss: each PASS/FAIL
4. Check 3 — Clipboard Upload via controller: PASS/FAIL
5. Check 4 — Bubbles via controller: PASS/FAIL
6. Check 5 — video: PASS/FAIL

For any crash: `journalctl -b | grep -E "coredump|Vibemis|SIGABRT|SIGSEGV" | tail -10`
