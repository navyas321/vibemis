# Vibemis Redesign — Runtime Screenshot Review (for Claude Design)

Live captures from the **0.18.0–0.22.0-beta** builds on the actual target device (Legion Go S Z2, 1920×1200), headless via gamescope emulation. Fonts are app-bundled (Sora display / Manrope body, test94). Accent = `#2FC6D0`.

Attach `redesign-screens.zip` to Claude Design, or view the loose PNGs in this directory.

| # | Screen | File | Runtime status | Design notes |
|---|--------|------|----------------|--------------|
| 1a | Computers (home) | `computers-1a-test92.png` | ✅ good | Status pill ("● ONLINE" / "OFFLINE" + warning glyph) and host-type badge ("APOLLO") read clearly. Tiles feel a bit sparse at the top-left on a wide panel — consider centering or a max-tile-width grid. |
| 1b | App grid | `appgrid-1b-test91.png` | ✅ good | RESUME badge (green pill + play/stop overlay) works and looks great. On the focused running-app tile the label ("VIRTUAL DESKTOP") sits *under* the play/stop overlay — legible but slightly busy; consider dimming the label or moving controls. |
| 1c | Add-PC dialog | `addpc-1c-test90.png` | ✅ good | Clean; accent-focus field + Tailscale hint (teal link). Minor: the IP placeholder text sits a few px high inside the field (vertical-centering). |
| 1f | Help | `help-1920x1200-shortcut-cards-collapsed.png` | ❌ **defect** | Hero "Quick Menu" + "Remote play" cards look excellent (accent gradient, key-caps). **BUT** the "Gamepad shortcuts" + "Keyboard shortcuts" cards collapse to ~0 height and pile title+rows on top of each other. Engineering root cause: those two `VbCard`s use `Layout.fillHeight` with no `preferredHeight` and `VbCard` has no `implicitHeight`. Filed as PR #173 (test89). **This is a code bug, not a design issue** — the design intent is fine. |

## Overall design impressions
- **Strong:** consistent accent usage, the status-pill / host-type-badge / RESUME-badge cue system (1a/1b), the hero-card treatment on Help, the token chip language.
- **To watch:** (1) sparse layouts on the 1920-wide panel (home + app grid have lots of empty right-side space); (2) focused-running-tile overlay legibility (1b); (3) small vertical-centering nits (Add-PC field). None are blockers.
- **One functional blocker (not design):** the Help shortcut-cards collapse (1f) — fix in flight.

*Captured by the clienttest agent. Cues verified on real host Navid-PC (paired, online). Settings 1e (version chip, test96) is source-confirmed but not shown — the Settings view is mouse-only (not keyboard-reachable) so it can't be captured headlessly yet.*
