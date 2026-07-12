# test77 — Quick Menu: gamepad close / return-to-game (fixes the test75 "frozen menu")

**Branch:** `test77-quickmenu-gamepad-close` · **Base:** `vibemis-main` · **Report:** `diagnostic/test77-quickmenu-gamepad-close-report`
**Artifact:** CI 🔬 alpha for this branch — `./testing/run-cycle.sh test77-quickmenu-gamepad-close` fetches + md5-verifies.
**Host:** the paired host PC (up). Streaming authorized. **Run under `scripts/gamescope-emulate.sh`** (standard Game Mode path) plus a Desktop-Mode pass if convenient.

## What changed (from your test75 findings — thank you, exact hit)

1. **Back/Select(View) and Start now close the Quick Menu** (mapped → Esc in the menu-open
   gamepad intercept). Previously they were swallowed unmapped — the "back does nothing" defect.
2. **Local `state->buttons` is cleared after every gamepad combo fires** (quit/stats/quickmenu).
   Fixes the host seeing stuck Select+L1+R1+Y re-sent by axis updates while the menu sat open.
3. **Discoverable exit hint:** the menu's bottom button now reads **"Resume Game (Ⓑ / Back / Esc)"**
   (main menu) / **"← Back (Ⓑ)"** (Server Commands submenu).
4. **Submenu escape behavior:** Esc/B/Back inside Server Commands returns to the main menu
   (matching the on-screen hint); from the main menu it closes and resumes the game.

## Tier 1 — stream + keyboard regression (gamescope emulation)

1. `run-cycle.sh test77-quickmenu-gamepad-close` (md5 + `selftest` PASS).
2. Stream Desktop inside `gamescope-emulate.sh` as you did for test75. `Ctrl+Alt+Shift+\` →
   EXPECT menu opens; bottom button text reads **"Resume Game (Ⓑ / Back / Esc)"** (screenshot).
3. Down ×2 → highlight moves; Esc → menu closes, stream resumes (same as test75 keyboard PASS).
4. Open again → Enter on **Server Commands** (if it opens the submenu) → Esc → EXPECT return to the
   **main menu** (not a full close); Esc again → EXPECT close/resume.

## Tier 2 — gamepad path (the fix target)

With a controller (physical, or Game Mode on-device later):
1. In-stream, hold **Select+L1+R1+Y** → menu opens. Release.
2. Press **Back(Select)** alone → EXPECT the menu **closes and the stream resumes**. Re-open.
3. Press **Start** → EXPECT close. Re-open. Press **B** → EXPECT close (unchanged).
4. D-pad Down/Up moves the highlight; A activates (unchanged from test75 keyboard-path parity).
5. **Stuck-buttons check:** while the menu is open, wiggle a stick, then close and watch the host —
   EXPECT no phantom Select/L1/R1/Y held in-game (previously the held combo was re-sent on axis
   updates). Check the log: exactly ONE `Detected quick menu toggle gamepad combo` per open.
If no controller is available this cycle, mark Tier 2 **N/A (needs controller)** and PASS/FAIL on
Tier 1 only — the code path is the same `injectKey` bridge your test75 keyboard run validated, but
say so explicitly in the report.

## Negative checks

- No stream regression: quit combo (Start+Select+L1+R1) still quits when the menu is CLOSED.
- Stats combo (Select+L1+R1+X) still toggles the perf overlay when the menu is closed.
- Keyboard toggle combo unchanged (`Ctrl+Alt+Shift+\`).

## Report

`testing/test77-quickmenu-gamepad-close/report.md` on `diagnostic/test77-quickmenu-gamepad-close-report`,
PR against `test77-quickmenu-gamepad-close`. Tick the checklist row in the same commit.
Bus announce START/DONE on the hub bus (`$HUB_BUS/api/coordination/announce`, ASCII; hostname known on-device).
