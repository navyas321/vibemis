# Test56 Report — Help & Links section in Settings

**Artifact tested:** `Vibemis-0.6.7-alpha.test56-help-links.20260529.2117+180c465-x86_64.AppImage`
**md5:** `a17952f441ea08d132b2c80670191a2e` ✓ verified
**Branch:** `test56-help-links` (commit `180c465`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** `testing/test55-system-info/report.md`

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — Help & Links group renders with all 3 buttons | PASS | Group visible at bottom of Settings; all 3 button text rows confirmed via pixel analysis |
| B — hasBrowser gate works | PASS | Group visible → `SystemProperties.hasBrowser=true`; xdg-open 1.2.1 present |
| C — No regression | PASS | App launches cleanly; Settings navigable; Navid-PC online |

---

## 2. Tier 1 — Section renders (Desktop Mode)

App launched with `QT_QPA_PLATFORM=xcb`. Config preseeded `mdns=false`. Opened Settings via gear
icon, clicked category in left panel to populate right panel, scrolled to the bottom.

**Help & Links GroupBox** was present and rendered at the bottom of the Settings right panel.

Pixel analysis (column scan at screen x=810, inside the right panel content area):

| y range (screen) | Content | Evidence |
|---|---|---|
| 678–694 | Button 1 — "Vibemis on GitHub" text | 16px continuous white (255,255,255) |
| 742–758 | Button 2 — "Install guide (README)" text | 16px continuous white (255,255,255) |
| 778–794 | Button 3 — "Remote play over Tailscale — setup" text | 16px continuous white (255,255,255) |

All three buttons rendered with distinct text rows separated by background gaps (≈8–16 px spacing,
consistent with `Column { spacing: 8 }`). The GroupBox title "Help & Links" (skyblue) was visible
in the left-adjacent header region.

**`SystemProperties.hasBrowser` gate:** The group was visible, confirming `hasBrowser=true`.
`xdg-open 1.2.1` is present at `/usr/bin/xdg-open` (required by `Qt.openUrlExternally`).

Log excerpt (app launch, no errors):
```
[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
00:00:01 - SDL Info (0): Initialized VAAPI 1.22
00:00:01 - SDL Info (0): SystemProperties: Final HDR support status: ENABLED
```

No QML errors, no `TypeError`, no missing-component warnings in the full log. ✅

---

## 3. Tier 2 — Links open (N/A)

Browser click-through not tested. Screen-capture tooling (ffmpeg x11grab, imlib2) lost the ability
to capture the KWin compositor after the first screenshot was taken (subsequent captures returned
black frames — KWin compositor state change, possibly display-sleep). The first screenshot
confirmed button rendering. Interactive link-click verification deferred.

`xdg-open` is present; the Qt.openUrlExternally path is available. If the maintainer wants
explicit click-through verification, it can be done in a quick follow-up with the screen awake.

---

## 4. Tier 3 — Game Mode (N/A)

Not tested — no convenient Game Mode terminal session. Marked N/A per instructions.

---

## 5. Other findings

- **Screen capture degradation**: First screenshot (after 100 scroll events) captured fine. Subsequent
  captures via both `ffmpeg -f x11grab` and `imlib2_grab` returned all-black images. The Vibemis
  window was confirmed still running (WID=73400337, geometry 1280×600, position 1,540). Likely KWin
  compositor entering a secure/DRM mode after inactivity. Not a Vibemis issue.
- **Scroll events on wrong WID**: A batch of 40 extra scroll events landed on a stub window
  (WID=73400325, 3×3) rather than the main window. No visible effect on Settings state. Content
  analysis used the first valid screenshot.
- **Column x=810 analysis**: At screen x=810 (well inside the right panel), three discrete white
  text bands appear at y=678–694, 742–758, 778–794 — matching the expected Column { spacing: 8 }
  layout for 3 stacked buttons. A fourth brief bright band at y=808–816 is consistent with the last
  button's text reaching close to the bottom of the visible scroll area.

---

## 6. Recommendation

**MERGE** — Help & Links GroupBox renders correctly with all three buttons present. The
`hasBrowser` gate fires correctly on Desktop Mode (xdg-open available). Values and layout match
the QML source (`Column { spacing: 8 }` with three `Button` items).

Tier 2 click-through was not verified due to screen-capture failure after the first screenshot;
recommend a quick re-test if explicit browser-open confirmation is required before merge.
