# Test-agent sweep instructions — beta 0.25.4 (the stable-1.0 gate)

**(The coord bus truncates at ~300 chars, so the authoritative list lives here. Pull vibemis-main + read this.)**

## Where we are
The redesign is COMPLETE and all three blockers you found are FIXED. Target the **latest beta 0.25.4**.

Fixed since your last sweep:
- **Black screen under gamescope** — the startup-screen toolbar collapse (which resized the window
  during swapchain creation) is gone; the toolbar stays on the home screens. **You already verified
  this renders clean on 0.25.1** ("Black blocker CLEARED"). ✅
- **1d Host-options side-sheet render collapse** — root-caused: `VbHostSheet.qml` imported
  `QtQuick.Controls 2.2`, where `Overlay.overlay` doesn't exist (needs 2.3+), so the Popup fell back
  to the ~300px host tile as parent → the 186px cluster you saw. Now imports 2.5 → full 560px
  right-anchored slide-in. (0.25.2+)
- **Double header on 1a/1b** — the per-screen header is hidden now that the global toolbar stays;
  single header + bottom hint bar. (0.25.3+)
- **1a hint-bar accuracy (BL-1594)** — removed the false "Ⓨ Add computer" (Y actually = Settings;
  add-PC has no gamepad shortcut — the `+` tile does it). Now: **Ⓐ Connect · Ⓧ Host options · ☰ Settings**. (0.25.4)

Already PASS from your earlier work: 1e Settings sidebar (verified), 1c/1f, mock M4 real-HEVC stream.

## Your remaining tasks (this is the stable-1.0 gate)
1. **Grab beta 0.25.4** (latest). Confirm the Steam target reads `0.25.4`.
2. **Render-confirm under gamescope** — the app is NOT black; the home screen draws (this is the
   critical WSI check your Xvfb can't do).
3. **Single header** on 1a/1b — one header (title + `N hosts · M online` + buttons) + bottom hint
   bar, **no double header**.
4. **1d side-sheet** — open a host tile → Ⓧ / Menu → the sheet slides in as the **full-height 560px
   right panel** (not collapsed on the tile), D-pad moves rows, Ⓐ selects, Ⓑ closes.
5. **FULL 6-screen sweep** (1a–1f) at **1920×1200 AND 1280×800** — text cutoff / artifacts /
   overlap / functional regressions. Report per screen.

If 2–5 are clean, that's the **stable-1.0 green light** and I tag v1.0.0 immediately.

## Reporting
Incrementally on the bus in SHORT (<250 char) messages, or append to
`testing/TEST_AGENT_FINDINGS.md` and commit. Don't batch-and-end — the build agent is live and
hot-fixes within ~60s. This sweep is the last gate before stable 1.0.
