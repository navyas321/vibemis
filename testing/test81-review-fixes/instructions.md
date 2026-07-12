# test81 — repo-review fix wave regression cycle (post-merge gate)

**Branch:** `test81-review-fixes` (auto-merges on green CI) · **Report:** `diagnostic/test81-review-fixes-report`
**Artifact:** the 0.9.1-beta cut by the merge (or this branch's alpha). Stream against the paired host.

## Tier 1 — the newly-UNBROKEN feature: Server Commands (was fully dead)
1. In-stream, open the Quick Menu → **Server Commands**. EXPECT: with an Apollo host that grants
   the permission, the submenu now lists commands and `executeAction` no longer instantly fails.
   Log: NO `Command not found` for restart/shutdown/sleep ids. (Do NOT actually run
   shutdown/restart against the maintainer's host — verify the list + permission path only, or
   use `lock` if present.)
2. Settings export: run an export from Settings, then
   `grep -cE "^(key|certificate|uniqueid)=" ~/vibemis-settings.ini` → EXPECT **0** (identity
   excluded; previously the TLS private key was in this file).

## Tier 2 — input correctness while the menu is open
1. Open menu via Select+L1+R1+Y, wiggle sticks/triggers → EXPECT the game does NOT move.
2. Close the menu with **Start** → EXPECT mouse-emulation mode does NOT toggle on release.
3. Hold an arrow key in-game, open the menu (keyboard combo), release the arrow → close menu →
   EXPECT no stuck key on the host.
4. Open/close the menu ~10× while toggling fullscreen (Ctrl+Alt+Shift+X) between → EXPECT no crash
   (renderer-swap race fix), 0 coredumps.
5. Multiple sessions: stream, quit, open Settings, stream again → EXPECT no crash on Settings
   (clipboard-singleton UAF fix).

## Report
`testing/test81-review-fixes/report.md` on `diagnostic/test81-review-fixes-report`; tick the row;
bus announce as usual.
