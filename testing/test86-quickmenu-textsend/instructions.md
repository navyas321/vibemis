# test86 — Quick Menu on-screen text-send (P3.20)

**Branch:** `test86-quickmenu-textsend` · **Base:** `vibemis-main` · **Report:** `diagnostic/test86-quickmenu-textsend-report`
**Artifact:** CI 🔬 alpha via `run-cycle.sh test86-quickmenu-textsend`. Stacks on the merged Quick Menu.

## What shipped
A **"Type Text"** item in the Quick Menu opens a text-entry view (TextField + Send/Clear). Typed
characters route from `SDL_TEXTINPUT` → `QuickMenuManager::injectText` into the focused field;
**Send** (or Enter) ships the string to the host via `LiSendUtf8TextEvent`. Esc returns to the menu.
Fills the OSK gap on keyboard-less handhelds (works with a physical keyboard or the platform OSK).
- `app/backend/quickmenumanager.{h,cpp}` — `sendText()` / `injectText()` / `textInputActive`
- `app/streaming/input/keyboard.cpp` — text-mode branch + `handleTextInputEvent()`
- `app/streaming/session.cpp` — routes `SDL_TEXTINPUT`
- `app/gui/QuickMenu.qml` — Type Text item + text-send view

## Tier 1 — launcher (menu structure, no host)
1. `run-cycle.sh test86-quickmenu-textsend`; `selftest` PASS; no QML errors in the log.
2. Source-confirm the wiring is present (grep `LiSendUtf8TextEvent`, `injectText`, `type_text`,
   `SDL_TEXTINPUT`). Launcher can't open the in-stream menu, so this tier is build + source + selftest.

## Tier 2 — in-stream (needs host + keyboard; may be N/A while host is busy)
1. Stream, open Quick Menu (`Ctrl+Alt+Shift+\` or `Select+L1+R1+Y`), navigate to **Type Text**, Enter.
2. EXPECT the text-entry view: a focused field ("Send Text to Host" title). Type via a physical
   keyboard → characters appear in the field. Press **Enter** (or Send).
3. EXPECT the typed text appears on the **host** (focus a text box on the host first). Log:
   `Sent text to host`. No stuck keys; Esc from the field returns to the main menu.
4. Regression: while NOT in the text field, normal menu nav (arrows/A/B) unchanged; host keyboard
   passthrough (outside the menu) unaffected.
If no host/keyboard is available, mark Tier 2 **N/A** → Deferred verification ledger; pass on Tier 1.

## Report
`testing/test86-quickmenu-textsend/report.md` on `diagnostic/test86-quickmenu-textsend-report`; tick the row; bus announce.
