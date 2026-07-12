# test100 — Host-options side-sheet (redesign 1d)

Replaces PcView's old right-click **NavigableMenu** with the redesign **1d** right-side action
sheet (`VbHostSheet.qml` + `VbSheetIcon.qml`). Same actions + visibility rules, presented
gamepad-first: a 560 px full-height sheet that slides in from the right over a 60 % scrim.

- Design ref: `docs/design/redesign/previews/1d-host-options-sheet.png`
- Opened by: **Ⓧ / menu button**, **long-press**, or **tapping an offline card** (unchanged triggers).
- Nav: **D-pad up/down** move the focused row (accent focus ring), **Ⓐ / Enter** selects,
  **Ⓑ / Esc / Back** closes, click-outside (scrim) closes.
- Rows (contextual visibility preserved from the old menu): *View all apps* (online+paired),
  *Wake PC* (offline+wakeable), *Pair* / *Pair using OTP* (online+unpaired; OTP Apollo-only),
  *Test network*, *Rename*, *View details & permissions*, divider, **Delete PC** (red).
- Header: monitor glyph + ONLINE/OFFLINE pill, host name (Sora), host-type badge
  (APOLLO/SUNSHINE) + access summary (e.g. "Full access").

## Scorecard

**Build** — CI alpha `0.23.0-alpha.test100-*` is green (this branch). Download that AppImage.

**Smoke (self-host is enough — no real stream needed):**
1. Launch, pair/connect the self-host so a PC card shows on the Computers screen.
2. Focus the card, press **Ⓧ** (or menu / long-press). → the sheet slides in from the right
   over a dimmed screen. Header shows the host name + ONLINE pill + badge.
3. D-pad down/up moves the focus ring through the rows; the focused row's icon turns accent and
   the label bolds. **Ⓐ** on *Test network* opens the network-test dialog.
4. Re-open the sheet, **Ⓑ** closes it and focus returns to the card grid (grid nav still works).
5. Re-open, arrow to **Delete PC** (red, below the divider) — confirm the row reads in danger red
   and that selecting it opens the existing delete-confirm dialog (do **not** confirm the delete).

**Regression:**
6. *View all apps* (online+paired host) still pushes the AppView with hidden games shown.
7. *Rename* opens the rename dialog; *View details & permissions* opens the details dialog.
8. On an **offline** card: tapping the card opens the sheet and shows *Wake PC* (if wakeable);
   online-only rows (View all apps / Pair) are absent.
9. Keyboard-only: the **menu key** opens the sheet; **Delete key** still opens delete-confirm directly.

**Negative / artifacts (the sweep the maintainer asked for):**
10. At **both 1920×1200 and 1280×800**: no text cutoff in the header (long host names elide with
    "…"), rows don't overlap, the sheet width stays ≤ 560 px and the scrim covers the full screen.
11. Icons render as crisp monochrome line glyphs (not boxes/tofu); the Delete icon + label are red.
12. No QML warnings referencing `VbHostSheet.qml` / `VbSheetIcon.qml` in the log.

Report PASS/FAIL per numbered step with a screenshot of the open sheet at both resolutions.
