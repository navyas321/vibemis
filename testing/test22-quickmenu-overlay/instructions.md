# Test22 Instructions — Quick Menu renders + navigates in Game Mode

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Prior report:** `testing/test20-uniqueid-persist-quickmenu-click/` (last Quick Menu cycle)
**Goal:** Verify the Quick Menu now **appears as an in-stream overlay** in **Game Mode (Gamescope)** and can be **navigated with the gamepad**, via the new OverlayManager-surface architecture (P3.1).

---

## Background

The Quick Menu previously used a separate `QQuickView` OS window. Gamescope (Game Mode)
does not composite separate windows, so the menu was invisible in Game Mode — the core
P3.1 bug.

This build rearchitects it: the menu is rendered from QML **offscreen** into an OpenGL
framebuffer, read back to an RGBA surface, and published to the **OverlayManager** as a new
`OverlayQuickMenu` overlay type. Every video renderer composites OverlayManager surfaces into
the stream — the same path the performance-stats overlay already uses (which works in Game
Mode). So the menu should now appear **centered over the video**, in both Game Mode and
Desktop Mode, drawn inside the stream itself rather than as a window.

Gamepad/keyboard navigation is injected directly into the offscreen menu.

> **This test REQUIRES starting a stream** (the overlay only draws over live video). This
> overrides the standing "do not stream unless asked" rule **for this cycle only**. You need
> the Vibepollo host already paired and reachable. If the host is not paired/available, stop
> and report that as a blocker — do not attempt to pair.

---

## Artifact

**AppImage:** `testing/test22-quickmenu-overlay/Vibemis-0.6.7-vibemis-test22-quickmenu-overlay-x86_64.AppImage`
**md5:** `683719e1fdd5dba2716bf6c65cb64ded`

Verify before running:
```bash
md5sum testing/test22-quickmenu-overlay/*.AppImage
```

---

## Setup

```bash
cd ~/vibemis
git fetch origin test22-quickmenu-overlay
git checkout test22-quickmenu-overlay && git pull
chmod +x testing/test22-quickmenu-overlay/*.AppImage
```

The Quick Menu open combos:
- **Gamepad:** `Select + L1 + R1 + Y`
- **Keyboard:** `Ctrl + Alt + Shift + \`

Navigation once open:
- **Gamepad:** D-pad Up/Down to move, **A** to select, **B** to close
- **Keyboard:** Arrow Up/Down, **Enter** to select, **Esc** to close

---

## Tier 1 — Game Mode (PRIMARY — this is the test that matters)

Run from **Game Mode**. Add the AppImage as a non-Steam game if not already, OR launch it
via the Steam shortcut. Capture the log:

```bash
# From Game Mode, launch Vibemis. If you can pass args via the shortcut, add:
#   --appimage-extract-and-run
# Log to a file by launching from a terminal shortcut if possible:
SDL_DEBUG=1 ./testing/test22-quickmenu-overlay/*.AppImage --appimage-extract-and-run > ~/test22-gamemode.log 2>&1 &
```
(If Game Mode can't redirect output, run the stream and rely on the on-screen result; the log
checks below are best-effort.)

1. Connect to the paired Vibepollo host and **start a stream** (launch any app/desktop).
2. Once the stream is live, press **Select + L1 + R1 + Y** on the gamepad.
3. **Observe:** does a dark rounded menu titled **"Quick Menu"** appear **centered over the
   video**?
4. Press **D-pad Down** a few times — does the **highlighted row move** (cyan border/grey
   fill follows the selection)?
5. Navigate to **"Toggle Performance Stats"** and press **A** — does the perf stats overlay
   toggle on/off (visible effect confirms selection works)?
6. Re-open the menu, press **B** (or navigate to "Close") — does the menu close?
7. Note whether the video keeps playing normally underneath while the menu is open.

---

## Tier 2 — Desktop Mode (regression + keyboard nav)

Run from **Desktop Mode** (KDE), with a keyboard attached:

```bash
cd ~/vibemis
./testing/test22-quickmenu-overlay/*.AppImage --appimage-extract-and-run > ~/test22-desktop.log 2>&1 &
```

1. Start a stream to the paired host.
2. Press **Ctrl + Alt + Shift + \** — does the menu appear centered over the video?
3. Use **Arrow Up/Down** to move the highlight, **Enter** to select "Toggle Performance
   Stats", **Esc** to close. Do all three work?

---

## Tier 3 — Negative / input-leak check

With a stream live (either mode):

1. **Menu CLOSED:** move with the D-pad / left stick — the game should respond normally
   (character moves, cursor moves). Confirm input reaches the host.
2. **Menu OPEN:** press D-pad Up/Down — the **game underneath should NOT react** to those
   presses (they should drive only the menu). Confirm the menu consumes navigation input.
3. Close the menu — confirm game input returns to normal.

---

## What to check and report

| # | Check | How | Expected |
|---|-------|-----|----------|
| 1 | Menu visible in **Game Mode** | Tier 1 step 3 | Menu appears centered over video |
| 2 | Gamepad navigation | Tier 1 step 4 | Highlight moves with D-pad |
| 3 | Gamepad select works | Tier 1 step 5 | Perf stats toggles |
| 4 | Menu closes | Tier 1 step 6 | Menu disappears, stream continues |
| 5 | Desktop Mode still works | Tier 2 | Menu appears + keyboard nav works |
| 6 | No input leak when open | Tier 3 step 2 | Game ignores nav input while menu open |
| 7 | Init log line | `grep -i 'offscreen overlay renderer initialized' ~/test22-*.log` | Present (best-effort) |
| 8 | Any QML errors | `grep -iE 'QML error|qrc:/gui/QuickMenu' ~/test22-*.log` | None |

If the menu does **not** appear in Game Mode (check #1 fails), that is the critical result —
capture the full log (`~/test22-gamemode.log`) and note GPU/Mesa version. Also grep:
```bash
grep -iE 'overlay|quickmenu|EGLRenderer|Using .* renderer|FBO|framebuffer' ~/test22-gamemode.log | head -40
```

---

## Report format

Commit `testing/test22-quickmenu-overlay/report.md` on branch
`diagnostic/test22-quickmenu-overlay-report` and open a PR targeting `test22-quickmenu-overlay`.

Required: TL;DR table (checks 1–8), per-tier results, which renderer was active
(`grep 'Using .* renderer' log`), SteamOS + Mesa version, and a clear PASS/FAIL on
**check #1 (Game Mode visibility)** — that is the headline result for P3.1.

---

## Safety rules (standing, except the streaming exception noted above)
- No package installs, no `sudo` outside read-only inspection
- Do not modify the AppImage
- Streaming **is** authorized for this cycle; pairing is **not** — if the host isn't already
  paired, stop and report
- If a step needs a permission/capability outside these rules, stop and ask
