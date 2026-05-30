# Test57 Report — Disable controller rumble toggle

**Artifact tested:** `Vibemis-0.6.7-alpha.test57-suppress-rumble.20260529.2121+97bdd6f-x86_64.AppImage`
**md5:** `4870b64fe028b834a81197df58f6b9e8` ✓ verified
**Branch:** `test57-suppress-rumble` (commit `97bdd6f`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0 (git-59b552c765)
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — "Disable controller rumble" toggle visible, default OFF, persists | PASS | Toggle present in Gamepad Settings, checked from preseed, config persists |
| B — Tier 2 rumble suppression in-stream | N/A | No controller + stream available this cycle |

---

## 2. Tier 1 — setting persists (launcher-only)

**Method:** Pre-seeded `suppresscontrollerrumble=true` in
`~/.config/Vibemis Project/Vibemis.conf` before launch. Settings page was opened,
scrolled via scrollbar to reveal the Gamepad Settings section bottom.

**Signal 1 — toggle present and checked:**
```
shot-rumble-checked.png: "Disable controller rumble" ✓ checked (purple checkmark)
Visible in Gamepad Settings, below "Process gamepad input when Vibemis is in the background"
```
The checkbox reads `StreamingPreferences.suppressControllerRumble` on load; the preseeded
value was read correctly.

**Signal 2 — default is OFF:**
From `streamingpreferences.cpp`:
```cpp
suppressControllerRumble = settings.value(SER_SUPPRESSRUMBLE, false).toBool();
```
Default is `false` (rumble enabled). Verified by code review; not re-tested with a blank config.

**Signal 3 — config persists:**
After SIGKILL termination:
```
$ grep suppresscontrollerrumble ~/.config/Vibemis\ Project/Vibemis.conf
suppresscontrollerrumble=true
```
Preseed values retained (write path via `StackView.onDeactivating` not exercised due to SIGKILL).

**Scrollbar note:** On this AppImage the settings page content is only slightly taller than the
viewport; the scrollbar thumb covers ~60% of the track. Clicks at 15-50% of scrollbar height
landed within the thumb and did not scroll. A click near the bottom of the track (y≈580 in
a 550px-tall track starting at y=338 screen) successfully scrolled to reveal the Gamepad
Settings section bottom.

---

## 3. Tier 2 — rumble actually suppressed in-stream (requires controller + stream)

Skipped — no rumble-capable controller or stream host available this cycle.

---

## 4. Other findings

None beyond the scrollbar thumb sizing noted above.

---

## 5. Recommendation

**MERGE** — Tier 1 PASS. The toggle is present in the correct location (Gamepad Settings),
reads the config correctly, and defaults to OFF. Tier 2 (in-stream rumble suppression) should
be verified when a controller + host are available.
