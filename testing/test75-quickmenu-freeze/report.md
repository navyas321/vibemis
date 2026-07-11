# Test75 Report — Quick Menu: no gamepad way to close/quit & return to game

**Artifact tested:** `Vibemis-0.6.7-beta.20260711.0854+e7a2a4b-x86_64.AppImage` (released beta)
**md5:** `fc4daea2e1fe6c37c40d42941dfb5c12` ✓
**Branch:** `diagnostic/test75-quickmenu-freeze-report` (off `vibemis-main` @ `e7a2a4b`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0 (radeonsi, Ryzen Z2 Go), Qt 6.9.1
**Test date:** 2026-07-11 · **Cycle:** diagnostic-only (per BUILD_AGENT_INBOX 2026-07-11 ~19:25Z)
**Method:** live Desktop stream to Navid-PC **inside `scripts/gamescope-emulate.sh`** (nested headless gamescope + FROG WSI). `virtualDisplay=1` — input hit a **virtual** host monitor, not the maintainer's physical desktop.

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — reproduce "menu freezes" | **REFINED** | Menu does **not** globally freeze — via **keyboard** it opens, navigates, and closes fine in-stream (proven, screenshots). |
| B — find the real defect | **CONFIRMED** | **No gamepad way to close/quit the menu & return to the game.** The gamepad **Back(Select) button does nothing** — only `B` closes, and that's undiscoverable. |
| C — Game Mode via gamescope-emulate | **PASS (harness)** | Full stream established under emulation (VAAPI 1.22 / HEVC / WSI, **0 coredumps**); menu render + keyboard path verified live. |

**Maintainer's symptom ("back does nothing, can't quit & return to game") is CONFIRMED and root-caused** in `app/streaming/input/gamepad.cpp`: while the Quick Menu is open, the only gamepad key mapped to close is **B → Esc**. The **Back/Select/View button, Start, X, Y and shoulders are all swallowed with no action** (`return; // any other button: also swallow`). There is **no "Resume/Return to game" item** — only "Close (Esc)". So a user pressing "Back" to dismiss the menu is stuck.

---

## 2. What actually reproduced (runtime, gamescope emulation, in-stream)

Live Desktop stream established inside nested gamescope — log:
```
00:00:21 SDL Info: Video stream is 1920x1200x120 (format 0x100)
00:00:22 SDL Info: Setting QuickMenuManager geometry: ... 1536x960 (actual pos: 192,120)
00:00:30 SDL Info: Detected quick menu toggle combo
00:00:30 SDL Info: QuickMenuManager: offscreen overlay renderer initialized (500x400)
coredumps: +0
```
Driving the menu **by keyboard** (the toggle is `Ctrl+Alt+Shift+\`):
- **Open** → menu renders fully (`shots/21-menu-t0.jpg`) — Disconnect/Quit/Server Commands/Clipboard Upload/Fetch Clipboard + "Close (Esc)". Not a one-frame paint.
- **Down ×2** → highlight **moves** Disconnect → Server Commands (`shots/23-after-down.jpg`). Navigation works.
- **Esc** → menu **closes**, stream resumes (`shots/24-after-escape.jpg`). Close works.

➡️ The offscreen `QQuickWindow` render + `injectKey` (`Qt::QueuedConnection`) path **works during a live stream** for keyboard. (This **refutes** an early "Qt event loop is fully suspended mid-stream" hypothesis — the queued injections are clearly being delivered.)

## 3. The real defect — gamepad close/quit (source-confirmed)

`app/streaming/input/gamepad.cpp`, menu-open interception (runs when `QuickMenuManager::isVisible()`):
```cpp
case SDL_CONTROLLER_BUTTON_DPAD_UP:    qtKey = Qt::Key_Up;     break;
case SDL_CONTROLLER_BUTTON_DPAD_DOWN:  qtKey = Qt::Key_Down;   break;
case SDL_CONTROLLER_BUTTON_DPAD_LEFT:  qtKey = Qt::Key_Left;   break;
case SDL_CONTROLLER_BUTTON_DPAD_RIGHT: qtKey = Qt::Key_Right;  break;
case SDL_CONTROLLER_BUTTON_A:          qtKey = Qt::Key_Return; break;
case SDL_CONTROLLER_BUTTON_B:          qtKey = Qt::Key_Escape; break;
default: break;                        // Back/Select/View, Start, X, Y, LB/RB -> unmapped
}
...
return; // any other button: also swallow while menu is open
```
- **Back/Select(View) → nothing** (swallowed). This *is* "pressing back does nothing."
- Only **B** closes (→Esc→`closeMenu()` in `app/gui/QuickMenu.qml:36`). Undiscoverable; the on-screen hint says "Close (**Esc**)" (keyboard), not a gamepad glyph.
- **No "Resume/Return to game" menu item** (`QuickMenu.qml` items: Disconnect, Quit, Server Commands, Clipboard Upload, Fetch Clipboard). Dismiss == Esc/B only.

**Secondary (build-agent suspect #1, confirmed):** after the open-combo fires, local `state->buttons` is **not cleared** (`gamepad.cpp:446` clears only the host-bound state via `LiSendMultiControllerEvent(…0…)`). Consequences: (a) axis events re-send the held combo to the host (host sees stuck Select+L1+R1+Y); (b) while the menu is visible all button *presses* are swallowed before the combo check, so the **open-combo cannot re-close** the menu.

## 4. Fix direction (for build agent — I don't patch)
1. Map the gamepad **Back/Select(View)** button to `closeMenu()` while the menu is open (most users press "Back" to dismiss).
2. Optionally let the **open-combo (Select+L1+R1+Y) toggle closed** — clear `state->buttons` after it fires and/or evaluate the combo on release, so it isn't self-swallowed.
3. Add a visible **gamepad** close/return hint (e.g. "Ⓑ Close / Return to game") and/or an explicit "Resume" item.

## 5. Environment / harness notes
- Host **Navid-PC** up (Apollo 47984/47989/47990 open, paired). Apps: **Desktop / Steam / Virtual Desktop**. Stream: `virtualDisplay=1`, 1920x1200x120, HEVC/VAAPI.
- **CLI `stream "Navid-PC" "Desktop"` fails** — `Qt Critical: Failed to find application Desktop` — although the GUI lists & launches "Desktop". CLI app-name matching bug (separate, minor). GUI launch path works.
- **Live hub bus `:8766` (tailnet) is DOWN** — `curl` connection-timeout on both `100.127.67.80:8766` and `192.168.4.78:8766` (node pings ~4ms; only the HTTP service is unreachable). Used the file mailbox bus instead (`TEST_AGENT_OUTBOX.md`); build agent confirmed receipt on PR #141.
- **Could not inject a physical gamepad** remotely (no controller; uinput/virtual-pad needs privileges the test device forbids). Gamepad findings above are source-confirmed + match the maintainer's live report; a controller-equipped run or the build agent's host-side gamepad trace would add the final runtime confirmation.

## 6. Recommendation
**ITERATE** — apply fix #1 (map gamepad Back→close) at minimum; #2/#3 improve discoverability. Then re-run test75 with a controller (Game Mode) to confirm close/return-to-game. The keyboard path already passes.
