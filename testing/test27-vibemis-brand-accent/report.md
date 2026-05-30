# Test27 Report — Vibemis brand accent (teal/cyan, P3.9 UI step 1)

**Artifact tested:** `Vibemis-0.6.7-vibemis-test27-vibemis-brand-accent-x86_64.AppImage`
**md5:** `ce732d9b21d51bab18e184afb42b6d63` ✓ verified (matches instructions.md)
**Branch:** `test27-vibemis-brand-accent` (commit `ad61b935`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5, Mesa 25.3.0
**Test date:** 2026-05-29
**Prior report:** N/A

---

## 1. TL;DR

| # | Check | Status | Summary |
|---|-------|--------|---------|
| 1 | Accent is teal/cyan (#00CCCC), not purple | PASS ✅ | Slider, checked toggle, accent text all teal; binary confirms `#00CCCC` |
| 2 | Theme still dark, text readable | PASS ✅ | Material Dark intact; all labels legible |
| 3 | Nav + focus highlight intact | PASS ✅ | PC list → Settings → controls all reachable, render correctly |
| 4 | No broken/missing controls (Settings/PC view) | PASS ✅ | Full Settings page renders; no blacked-out controls |

**Recommendation: MERGE.** Accent is conclusively Vibemis teal/cyan, the rest of the UI is unchanged.

---

## 2. Tier 1 — Accent colour

Two independent lines of evidence:

**(a) Rendered UI (Settings page).** The bitrate **slider** (filled track + handle), the **checked**
"Enable mouse control…" toggle (teal fill + white check), and accent text like the orange/teal
"#1" label all render **teal/cyan** — no purple anywhere. Main "Computers" screen and the in-app
toolbar use the Material **primary** (blue), which is unchanged and expected (the accent change
only affects accent-role controls: sliders, checked toggles, focus rings, accent text).

**(b) Binary ground truth.** The accent is applied via the documented env default:
```
$ strings -n5 usr/bin/vibemis | grep -iE "#00CCCC|MATERIAL_ACCENT"
#00CCCC
QT_QUICK_CONTROLS_MATERIAL_ACCENT          # set via qputenv() at startup
$ strings -n5 usr/bin/vibemis | grep -iE "#9c27b0|855dcd|7b1fa2|673ab7|purple"
(no matches)                                # zero purple/Material-purple remnants
```
Exactly one `#00CCCC` constant; it is the value pushed into `QT_QUICK_CONTROLS_MATERIAL_ACCENT`.
This matches the instructions ("one-line default, still overridable via that env var").

## 3. Tier 2 — No regressions

- **Dark theme + readability:** Material Dark unchanged; all section headers, labels, dropdown
  text (`Native (1920x1200)`, `120 FPS`, `Fullscreen (recommended)`) and checkbox labels are clearly readable.
- **Navigation:** PC list (Navid-PC tile) → gear → full **Settings** page opened and rendered;
  Basic/Display/Input/Gamepad sections all present with working dropdowns, sliders, checkboxes.
- **No broken controls:** Settings and PC view both render completely — no missing or blacked-out widgets.
- **Clean startup log** (no QML/JS errors):
```
Qt Info: "Navid-PC" is now online at "192.168.4.78:47989"
Qt Info: Discovered mDNS host: "Navid-PC.local."
Qt Info: getServerInfo HTTPS response: ... <PairStatus>1</PairStatus> ...
# grep -iE "qml|typeerror|referenceerror" → no matches
```
(The `SDL … VDPAU / Unable to load FFmpeg decoder` lines are the usual decoder probing at
launch — not relevant to this launcher-only UI check, no stream was started.)

## 4. Other findings

- **Toolbar is blue, not teal — expected.** That bar is `Material.primary`, a separate role from
  `Material.accent`; this cycle only changes the accent. Not a defect.
- **Screenshot capture note (environment, not a Vibemis issue):** on SteamOS KDE-Wayland the app
  runs under XWayland; from a headless agent shell, `spectacle` background mode must be kept alive
  for the portal handshake, and XWayland windows can't be raised above the (Wayland) console via
  `xdotool`. Working method: launch app (maps on top) → double-click the gear at its peeking edge
  (focus, then activate) → `spectacle -b -n -f` held open ~5 s. Captured both main + Settings.

## 5. Recommendation

**MERGE.** The accent is conclusively Vibemis teal/cyan (`#00CCCC`) on every accent-role control,
the Material Dark theme and full UI layout are unchanged, and all controls render with no
regressions. No code issues observed.
