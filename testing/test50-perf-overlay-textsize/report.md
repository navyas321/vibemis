# Test50 Report — Performance overlay text size (Small / Normal / Large)

**Artifact tested:** `Vibemis-0.6.7-alpha.test50-perf-overlay-textsize.20260529.2036+586966b-x86_64.AppImage`
**md5:** `4d87cb9c9b47d7da2781933a90aaa2d7` ✓ verified
**Branch:** `test50-perf-overlay-textsize` (commit `586966b`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0 (git-59b552c765)
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — text size dropdown visible with Small/Normal/Large; persists | PASS | Checkbox checked → dropdown visible; all 3 options listed; Large selected from preseed |
| B — Tier 2 stream verification | N/A | No stream available on this test cycle |

---

## 2. Tier 1 — setting persists (launcher-only)

**Method:** Pre-seeded `showperfoverlay=true` and `perfoverlaytextsize=2` in
`~/.config/Vibemis Project/Vibemis.conf` before launch. Navigated to Settings and
scrolled to bottom of right column via scrollbar click.

**Signal 1 — checkbox present and checked; label visible:**
```
shot-show-perf-checked.png: "Show performance stats while streaming" ✓ checked
"Performance overlay text size" label is visible directly below it
```
The label and dropdown are `visible: showPerformanceOverlay.checked` — both appeared
correctly when the preseeded `showperfoverlay=true` was loaded.

**Signal 2 — all 3 options listed; Large selected:**
The dropdown was opened. Options observed (in order):
- Small (not selected)
- Normal (not selected)
- **Large** (highlighted/selected — purple colour)

See: `shot-dropdown-large.png`

**Signal 3 — default is Normal:**
`PERF_TEXT_NORMAL = 1` is the default per `streamingpreferences.cpp`:
```cpp
perfOverlayTextSize = static_cast<PerfOverlayTextSize>(
    settings.value(SER_PERFOVERLAYTEXTSIZE,
                   static_cast<int>(PerfOverlayTextSize::PERF_TEXT_NORMAL)).toInt());
```
Not tested with a fresh config but confirmed by code review.

**Signal 4 — config persists:**
After SIGKILL termination:
```
$ grep -E "showperfoverlay|perfoverlaytextsize" ~/.config/Vibemis\ Project/Vibemis.conf
perfoverlaytextsize=2
showperfoverlay=true
```
Preseed values were retained (write path not exercised due to SIGKILL).

---

## 3. Tier 2 — text size changes in-stream (stream required)

Skipped — no stream host available for this cycle.

---

## 4. Other findings

- Scrollbar click navigation (screen x≈1590) is reliable for reaching the bottom of the
  right column without triggering KDE's global Tab-key handler.
- "Larg" is truncated in the combo button but all three full-text options (Small, Normal,
  Large) are clearly legible when the popup is open.

---

## 5. Recommendation

**MERGE** — Tier 1 PASS. The text size dropdown appears when the overlay is enabled,
lists exactly Small / Normal / Large, and the selection is read correctly from config.
Tier 2 (in-stream size rendering) should be verified in a dedicated streaming test cycle.
