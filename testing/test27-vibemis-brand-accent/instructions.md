# Test27 Instructions — Vibemis brand accent (P3.9 UI, step 1)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Confirm the app's UI accent colour is now Vibemis **teal/cyan (#00CCCC)** instead of
purple, and that the UI is otherwise unchanged and fully navigable.

---

## Background

First, safe step of the P3.9 UI-modernization phase: the app already uses the Material **Dark**
theme; this changes the **accent** from upstream's Purple to Vibemis teal/cyan (`#00CCCC`),
matching the in-stream Quick Menu accent for a consistent brand. It's a one-line default
(still overridable via `QT_QUICK_CONTROLS_MATERIAL_ACCENT`). No layout changes.

**No stream or host needed** — this is a pure launcher-UI check.

---

## Artifact

**AppImage:** `testing/test27-vibemis-brand-accent/Vibemis-0.6.7-vibemis-test27-vibemis-brand-accent-x86_64.AppImage`
**md5:** `ce732d9b21d51bab18e184afb42b6d63`

```bash
md5sum testing/test27-vibemis-brand-accent/*.AppImage
```

---

## Setup

```bash
cd ~/vibemis
git fetch origin test27-vibemis-brand-accent
git checkout test27-vibemis-brand-accent && git pull
chmod +x testing/test27-vibemis-brand-accent/*.AppImage
./testing/test27-vibemis-brand-accent/*.AppImage --appimage-extract-and-run &
```

---

## Tier 1 — Accent colour

1. On the main screen, look at accent-coloured elements (selection highlight on the
   PC tiles, focus rings, the settings toggles/sliders, buttons).
2. Confirm they are **teal/cyan**, not purple.

## Tier 2 — No regressions

1. Navigate the whole UI with the **gamepad/keyboard** (PC list → Settings → back). Confirm
   focus highlighting is visible and navigation works as before.
2. Open Settings and scroll — confirm controls render normally (no missing/blacked-out
   controls), just with the new accent.
3. Text remains readable (the theme is still Dark).

---

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | UI accent is teal/cyan (#00CCCC), not purple | Yes |
| 2 | Theme still dark, text readable | Yes |
| 3 | Controller/keyboard navigation + focus highlight intact | Yes |
| 4 | No broken/missing controls in Settings or PC view | Yes |

A screenshot of the main screen + Settings is ideal. Report SteamOS + Mesa version.

---

## Report format

Commit `testing/test27-vibemis-brand-accent/report.md` on
`diagnostic/test27-vibemis-brand-accent-report`; PR targets the test branch.

---

## Safety rules (standing)
- No package installs, no `sudo` outside read-only inspection; do not modify the AppImage
- No streaming/pairing needed for this cycle
