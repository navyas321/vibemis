# UI defect checklist — manual-testing cascade (2026-07-13)

Every UI defect the maintainer found during manual testing on the real Legion Go S Z2 that the
automated render harness + test agent missed. One beta ships all of these ("Make all the fixes in
one and ship I'll verify manually"). `[x]` = code fix written + compiles; **on-device verification by
the maintainer is the final gate** (code-exists ≠ done).

RCA on **why automated testing missed the text-cutoff class** is DONE (parallel agent) and is being
committed to memory. Summary: (1) the Xvfb/software-GL harness substitutes fallback fonts (Sora/
Manrope aren't installed) whose metrics are narrower than the device → pixel-tuned layouts fit in CI,
overflow on device; (2) it asserts only *page-level* horizontal overflow — a combo that collapses or
text clipped *inside* a control never widens the page, so the check passes; (3) it never fires
`onActivated`, the only thing that sized the combos; (4) the test agent verified *function*, not
*pixel-complete text*. Prevention captured in the memory note + `docs/UI_DEFECT_CHECKLIST.md`.

## Home / PcView
- [x] **CRITICAL freeze** — hovering "Add a computer" froze the app (focus war: a non-delegate
  focusable ghost vs the GridView FocusScope, 170% CPU, all input hijacked, home-page-only/touch-only).
  Fix: ghost is strictly non-focusable. `PcView.qml`
- [x] **Card cutoff** — "VIBEPOLLO" badge/meta rendered on the card bottom border with device fonts.
  Fix: badge/meta row anchored to card bottom + `bottomMargin:64`. `VbHostCard.qml` (BL-1661)

## Apps / AppView
- [x] **Squished tiles** — portrait 320×430 art rendered landscape. Fix: `width: height*(320/430)`.
  `AppView.qml` (BL-1663)

## Settings — pickers (text cutoff)  ← ROOT-CAUSE FIX, resolves 13 combos
- [x] **Combo text clipped** — "Teal (default)"→"Teal", "Select + L1 + R1 + Y (default)"→"Sele",
  "in fullscreen"→"in f". Root cause: `recalculateWidth()` ran only from `onActivated`; instances
  override `onActivated` (dropping it) and none recalc at init → `textWidth=0` → combo collapses to
  padding+arrow. Fix: `onCountChanged / Component.onCompleted: Qt.callLater(recalculateWidth)` in the
  base. `AutoResizingComboBox.qml` (BL-1664). **RCA audit confirms this one fix covers all 13
  AutoResizingComboBoxes** (accent, quick-menu, capture-keys, window-mode, video-scale, audio,
  language, ui-display-mode, decoder, codec, renderer-backend, perf-overlay size/position).

## Settings — navigation
- [x] **1-D nav / double selector** — RB switched category but focus stayed on the old row → TWO
  accent rings at once (one via RB, one via d-pad/stick); up/down didn't switch category. Root cause:
  `category` (selection) and `activeFocus` were independent. Fix: lock them together —
  `focusCategoryRow()` moves focus on LB/RB, `onActiveFocusChanged` makes selection follow focus, plus
  explicit up/down. Full 2-D now (up/down = category, right = enter pane, left = back). `SettingsView.qml` (BL-1667)

## Window / resolution
- [x] **Never fills 1920×1200 / apps squished** — launcher opened a 1280×720 window on the handheld
  panel. Root cause: default `uiDisplayMode=UI_WINDOWED` + `isSteamDeck` was *uninitialized* (its
  assignment was in reverted HDR WIP). Fix: init `isSteamDeck` from a new `isSteamDeckOrGamescope()`
  (gamescope env OR `/etc/os-release`=SteamOS — catches the Legion Go S in both Game & Desktop mode);
  maximize on handhelds in the default windowed path; bump min height 600→720. `main.qml` +
  `systemproperties.cpp` (BL-1668)

## Quick Menu
- [x] **No d-pad auto-scroll** — holding a direction injected the key once (SDL sends no gamepad
  key-repeat). Fix: nav auto-repeat timer (380ms delay → 90ms). `quickmenumanager.*` + `gamepad.cpp` (BL-1665)
- [x] **Left stick dead** — axis input was swallowed while the menu was open. Fix: translate the left
  stick to nav (edge-detected, dominant-axis, shares the repeat timer). `gamepad.cpp` (BL-1665)
- [x] **Selector too tight** — teal rectangle hugged the item text. Fix: row 60→70px. `QuickMenu.qml` (BL-1666)

## Help screen
- [x] **Unusable / not navigable / scaling off / cards cut off** — pure-presentation view with NO
  focusable element (focus stuck on the toolbar → only ☰ reachable, Ⓑ/Back dead); `Layout.preferredWidth:
  1.1/1.0` misused as a CSS flex ratio (they're ~1px absolute widths); content overflowed a small
  window with no scroll. Fix: grab focus on entry (Ⓑ/Esc pop); wrap body in a Flickable + ScrollBar;
  d-pad/stick/Tab/PageUp-Down scroll; real relative column widths. `VbHelpView.qml` (BL-1669)

## Verified by design (not a bug)
- [x] **"Quit" exits the whole app** — NOT a crash. `quit()` intentionally calls
  `setShouldExitAfterQuit()` + `http.quitApp()`: "Quit" = terminate the game on the host AND exit
  Vibemis (returns you to Steam/Game Mode). "Disconnect" = end the stream but stay in Vibemis at the
  grid (game keeps running on host). BL-1630 already hardened this path against the old quit-crash, so
  it exits cleanly. Optional: relabel "Quit" → "Quit game & exit Vibemis" for clarity (not done — ask).

## Answered (not a code change)
- In-app "update" (toolbar button) notifies + opens the GitHub Releases page in a browser; it is NOT
  an auto-installer. There is currently no non-GitHub update path — the maintainer downloads the new
  AppImage from GitHub Releases. (A true in-app auto-updater is a possible future feature.)

## Latent clip risks from the RCA audit (MED — follow-up, not in this beta)
resolution/fps display Text (fixed-width cards, elide) · VbHostSheet action-row labels · VbHintBar
labels · NavigableMessageDialog 400px height cap · ServerCommands buttons · ClipboardSettings
checkboxes · QuickMenu row description text. Each clips only with longer translations/values today.

## Durable prevention (from RCA — post-cascade)
- [ ] Install **Sora + Manrope** in CI so harness font metrics match the device; fail if they resolve
  to a fallback.
- [ ] Add per-control text-fit assertions (`contentWidth ≤ width`, not-`truncated`) on the static page;
  keep page-overflow but demote it. Enumerate combos, assert closed `displayText` fully fits.
- [ ] Render at 1280×800 (Game Mode) + a pseudo-localization (+40%) pass.
- [ ] Test-agent scorecard: add "read every visible control's COMPLETE text; confirm none clipped;
  for each ComboBox verify the closed value shows its full string — do NOT open the popup to judge."
