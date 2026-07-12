# test101 — Settings redesign 1e (sidebar categories)

Redesign screen **1e**: `SettingsView.qml` was restructured from a two-column scrolling
Flickable into the token-system **sidebar layout** — a fixed header (Back + "Settings" +
version chip), a 340 px left **category sidebar** (Video / Audio / Input & gamepad /
Streaming (Apollo) / Advanced), a right **Flickable panel** that shows only the selected
category's settings, and a bottom `VbHintBar`.

**IMPORTANT — this cycle also repairs two pre-existing syntax bugs** that were already on
`vibemis-main` (base `bf7b5bb5`, shipped in beta 0.22.3) and made the *entire* Settings
screen fail to parse/load. Both were merge-artifact "fused control" bugs (same class as
test97/test98):
1. `compactPerformanceOverlay` + `perfOverlayShowClock` CheckBoxes were fused (missing a
   closing brace, a `CheckBox {` opener, and a duplicated `ToolTip.text`).
2. `reduceBitrateOnBatteryCheck` CheckBox was missing its closing brace, absorbing the
   "Settings backup" `Label` and every control after it.

Because of these, **the base Settings screen would not open at all** — so a key regression
check here is simply that Settings now opens and every previously-existing control is present
and functional.

Only `app/gui/SettingsView.qml` changed (plus `app/version.txt` → 0.24.0). No C++, no other
QML, no `StreamingPreferences`/`ComputerManager`/`SystemProperties` binding was altered — the
GroupBox internals are byte-for-byte the same except the two brace fixes above and a
`visible:` line added to each GroupBox for category gating.

Test on the Legion Go S Z2, **both** Game Mode and Desktop Mode where noted, at **1920×1200
and 1280×800**.

---

## Tier 1 — Build / launch (must pass)

| # | Step | Expected |
|---|------|----------|
| 1 | Launch the test AppImage | App starts, reaches the Computers screen, no crash |
| 2 | Open **Settings** (gear / `☰`) | The redesigned Settings screen appears (dark, header + left sidebar + right panel + bottom hint bar). **It must open at all** — the base build could not. |
| 3 | Run `vibemis` from a terminal and watch stderr while opening Settings | No `qrc:/gui/SettingsView.qml:… Expected token` / `Unable to assign` / `Cannot assign` / `ReferenceError` / `TypeError` lines |

## Tier 2 — Smoke (redesign structure)

| # | Step | Expected |
|---|------|----------|
| 4 | Look at the header | Back `‹` button (left), **"Settings"** title (Sora), and a right-aligned **version chip** reading `Version 0.24.0`; a thin hairline under the header |
| 5 | Look at the sidebar | Exactly **5 rows**: Video, Audio, Input & gamepad, Streaming (Apollo), Advanced. **Video** is selected on entry (accent border/fill) |
| 6 | Look at the hint bar | Shows `Ⓐ Toggle / adjust` and `Ⓑ Back` |
| 7 | With Video selected | Panel shows the **Vibepollo Presets** + **Basic Settings** groups (resolution, frame rate, bitrate, live summary line, etc.) and nothing else |
| 8 | Select **Audio** | Panel shows **only** Audio Settings |
| 9 | Select **Input & gamepad** | Panel shows **only** Input Settings + Gamepad Settings |
| 10 | Select **Streaming (Apollo)** | Panel shows **only** Vibemis Streaming Enhancements + Host Settings + Vibemis Features |
| 11 | Select **Advanced** | Panel shows **only** UI Settings + Advanced Settings + System Information + About + Help & Links |

## Tier 3 — Gamepad / keyboard navigation

| # | Step | Expected |
|---|------|----------|
| 12 | With a gamepad connected, enter Settings | Focus lands on the **first sidebar row** (Video) with the accent focus ring |
| 13 | D-pad up/down (or Tab) over the sidebar | Focus moves row-to-row; each focused row shows the accent ring/glow |
| 14 | Press **Ⓐ** (or Return) on a sidebar row | That category becomes selected and the panel switches to it |
| 15 | Move focus into the panel and adjust a control with **Ⓐ**/D-pad | The control (combo/checkbox/slider) responds; the panel auto-scrolls to keep the focused control visible |
| 16 | Press **Ⓑ** / Esc | Returns to the previous screen (Computers) |

> Note: LB/RB shoulder-button category switching is **not** wired (the sidebar rows are
> focusable, which already makes every category gamepad-reachable). The hint bar intentionally
> does not advertise LB/RB. If shoulder switching is later desired, it can be added without
> touching the panel.

## Tier 4 — Regression (settings still work) + the two bug fixes

| # | Step | Expected |
|---|------|----------|
| 17 | In **Video**, change Resolution and Frame rate; note the live summary line | Summary updates live; values stick |
| 18 | In **Advanced → Advanced Settings**, confirm **both** "Compact performance overlay" **and** "Show clock in the performance overlay" checkboxes exist and toggle independently | Both present, both toggle (bug #1 fix) |
| 19 | In **Advanced → UI Settings**, confirm "Reduce bitrate when on battery" checkbox **and** the "Settings backup" label + Export/Import buttons **and** the language selector all exist | All present and interactive (bug #2 fix) |
| 20 | Change one setting in **each** category, close Settings, reopen | Every change persisted (StreamingPreferences.save on deactivate still fires) |
| 21 | Fully quit and relaunch | Changed settings are still applied (persisted to disk) |
| 22 | Export settings, then Import them back | Round-trips without error |

## Tier 5 — Negative / layout (both resolutions)

| # | Step | Expected |
|---|------|----------|
| 23 | At **1920×1200** | No text clipping in sidebar rows or panel; no overlap; version chip fully visible; hint bar not overlapped |
| 24 | At **1280×800** | Sidebar (340 px) + panel still fit; panel content wraps/scrolls; no horizontal scrollbar; no cut-off labels |
| 25 | Scroll a long category (Advanced) top-to-bottom | Smooth vertical scroll; scrollbar appears; last group (Help & Links) fully reachable |
| 26 | Toggle theme accent is N/A (dark only) — check for artifacts on focus | Focus ring/glow renders cleanly, no smearing on scroll |

---

### Report back
Fill each row PASS/FAIL with a one-line note (and a screenshot for Tier 2/5). Flag any control
that is missing, any QML console error, and any layout cut-off at either resolution. Commit the
report to `testing/test101-settings-sidebar/report.md` on a `diagnostic/test101-report` branch
and open a PR.
