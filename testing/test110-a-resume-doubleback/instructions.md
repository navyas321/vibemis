# test110 — double-Back navigation fix + A resumes a running session

**Branch:** `test110-a-resume-doubleback` · **Artifact:** `0.2.0-alpha.NNN` from the Alpha channel (or the CI run artifact for this branch)

## What changed

1. **BL-1745 bug fix:** activating a host card with gamepad **A** (or Enter) pushed **two**
   AppViews onto the navigation stack — Qt 6's `AbstractButton` natively emits `clicked()`
   on Return/Enter, and the Qt 5-era manual `Keys.onReturnPressed → clicked()` in
   `NavigableItemDelegate`/`PcView` fired a second time. Symptom: Back (B or the top-left
   arrow) had to be pressed **twice** to get from the app grid back to home.
2. **Feature:** in the app grid, pressing **A** on the app that owns the **running session
   (RESUME badge)** now resumes the stream directly. The app-options sheet is unchanged on
   **X**, press-and-hold, and right-click.

## Test tiers (Game Mode first, then Desktop Mode)

### Tier 1 — the bug fix (gamepad, Game Mode)
1. Launch Vibemis, focus the `Navid-PC` card, press **A**. → App grid opens.
2. Press **B** exactly **once**. → **EXPECT: home (PC grid) immediately.** FAIL if a second press is needed.
3. Re-enter the app grid with **A**, tap the **top-left back arrow** once (touch). → **EXPECT: home immediately.**
4. Regression: d-pad Right past the last PC card → ghost "Add PC" card selects; press **A**. → **EXPECT: Add-PC dialog opens, exactly one, and NO app grid opens behind it.** Cancel it → still on home.

### Tier 2 — the feature (gamepad, Game Mode)
5. Start a stream (e.g. Desktop), then Quick Menu → Disconnect (session keeps running on host) so the app shows the **RESUME** badge.
6. Focus the RESUME-badged app, press **A**. → **EXPECT: the stream resumes directly** (no options sheet).
7. Focus the RESUME-badged app, press **X**. → **EXPECT: the app-options sheet opens** (unchanged).
8. Focus a **different** (not running) app, press **A**. → **EXPECT: quit-first confirmation dialog** (unchanged semantics).
9. With **no** session running, press **A** on any app. → **EXPECT: it launches normally, once** (watch for double-launch).

### Tier 3 — Desktop Mode spot-check (touch/mouse)
10. Mouse-click a PC card → app grid; click back arrow **once** → home.
11. Tap the RESUME-badged app's box art. → **EXPECT: resume** (new behavior on touch as well; overlay Resume/Quit round buttons still work).

## Report
Commit `testing/test110-a-resume-doubleback/report.md` on `diagnostic/test110-a-resume-doubleback-report`, PASS/FAIL per numbered step, and open a PR.
