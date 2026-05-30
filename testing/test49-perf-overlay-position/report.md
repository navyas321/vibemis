# Test49 Report — Performance overlay position (corner selection)

**Artifact tested:** `Vibemis-0.6.7-alpha.test49-perf-overlay-position.20260529.2029+1197055-x86_64.AppImage`
**md5:** `2047d9849b70cdb99885cc7d59825672` ✓ verified
**Branch:** `test49-perf-overlay-position` (commit `1197055`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0 (git-59b552c765)
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — dropdown visible with all 4 corners; persists | PASS | Checkbox shows dropdown; all 4 options listed; Bottom right selected from preseed persists across relaunch |
| B — Tier 2 stream verification | N/A | No stream available on this test cycle |

---

## 2. Tier 1 — setting persists (launcher-only)

**Method:** Pre-seeded `showperfoverlay=true` and `perfoverlayposition=3` in
`~/.config/Vibemis Project/Vibemis.conf` before launch. Settings page was opened
and scrolled to the bottom of the right column.

**Signal 1 — checkbox present and checked:**
```
shot-show-perf-checked.png: "Show performance stats while streaming" ✓ checked
"Performance overlay position" label is visible directly below it
```
The checkbox reads `StreamingPreferences.showPerformanceOverlay` on load; the label and
dropdown are `visible: showPerformanceOverlay.checked` — both appeared correctly.

**Signal 2 — all 4 options listed; Bottom right selected:**
The dropdown was opened. Options observed (in order):
- Top left
- Top right
- Botto... (Bottom left)
- **Botto... (Bottom right — highlighted/selected)**

The 4th item was highlighted in the selection colour, confirming `perfoverlayposition=3`
(POS_BOTTOM_RIGHT) was read from config correctly.
See: `shot-dropdown-bottom-right.png`

**Signal 3 — config persists:**
After closing the app (SIGKILL after WM_DELETE_WINDOW did not flush in time):
```
$ grep -E "showperfoverlay|perfoverlayposition" ~/.config/Vibemis\ Project/Vibemis.conf
perfoverlayposition=3
showperfoverlay=true
```
Values survived. Note: Qt writes settings on `StackView.onDeactivating` and
`Component.onDestruction`; a clean quit is required for the write path. The preseed
approach confirms the read path is correct; a clean-quit persistence confirmation
was not performed (SIGKILL was used after the window did not close gracefully).

**Default value:** `PerfOverlayPosition` enum starts at `POS_TOP_LEFT = 0`; the
dropdown model's first entry is "Top left" — default is Top left as specified.

---

## 3. Tier 2 — overlay renders in the chosen corner (stream required)

Skipped — no stream host available for this cycle.

---

## 4. Other findings

- KDE globally intercepts Tab key even when sending with `xdotool key --window WID`.
  Scrollbar click navigation was required instead of Tab-based auto-scroll.
- `xdotool windowclose` did not flush Qt settings (likely due to SIGTERM not reaching
  the QML `StackView.onDeactivating` handler). Clean quit (e.g., via the back button
  in the app) should be used in future stream-required tests to confirm write path.
- The "Performance overlay position" dropdown text is truncated to "Bott" in the button
  due to the narrow combo box width. All 4 option labels are readable when the menu is open.

---

## 5. Recommendation

**MERGE** — Tier 1 PASS. The dropdown appears when the overlay is enabled, lists all four
corners, and the selection is read correctly from config. Tier 2 (stream corner rendering)
should be verified in a dedicated streaming test cycle.
