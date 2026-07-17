# Spec — Onboarding / first-run

**Surface:** new `app/gui/VbWelcomeSheet.qml` (replacing the stock welcome dialog in `main.qml`) ·
**Handoff:** none — the six handoff screens have no onboarding; this extends the established visual
language to a new surface · **Kind:** launcher-only `test<N>` PR

## Current state (what exists)

`main.qml` shows a one-time welcome via a stock `NavigableMessageDialog` (`id: welcomeDialog`), gated
by `StreamingPreferences.seenWelcomeHint` (persisted; shown exactly once). Its body is three plain
bullet lines (Quick Menu chord, add-to-Steam tip, Settings pointer). It works but is a bare Material
dialog — off the token visual language, no wordmark, no hint bar, no focus ring, emoji-free bullets.

## Goal

Elevate first-run into a **token-styled welcome screen** that matches the redesign, without changing
*when* it shows or the one-shot persistence. Keep it a single focused surface (gamepad-first) — not a
multi-step wizard (there is nothing to configure at first run; Settings owns configuration).

## Design

A centered modal card over the Computers screen (reuse the Add-PC dialog pattern): scrim
`VbTokens.dialogScrim`, card `VbTokens.bgElev`, `radius VbTokens.radiusDialog` (24),
`padding VbTokens.space6`-ish, max width ~720.

- **Header:** the Vibemis wordmark (`VbTokens.fontDisplay`, `sizeWordmark` 21, `wordmarkSpacing`) +
  "Welcome to Vibemis" title (`VbTokens.typeDisplay` 34, Sora bold, `textPrimary`).
- **Body:** three info rows, each `VbSheetIcon` glyph + two-line text (title `typeLabel`/`textPrimary`,
  sub `typeCaption`/`textTertiary`), `space3` gaps:
  1. **In-stream Quick Menu** — chord `Select + L1 + R1 + Ⓨ` (gamepad) / `Ctrl+Alt+Shift+\` (keyboard),
     rendered as key-cap chips like the Help screen.
  2. **Add to Steam** — "On Steam Deck / SteamOS, add Vibemis to Steam from Desktop Mode so it appears
     in Game Mode."
  3. **Settings** — "Set resolution, FPS, video scaling and more in Settings" — the ⚙ glyph.
- **Primary action:** a single accent pill **"Get started"** (`Ⓐ`), `accent` fill, `textOnAccent`
  label, ≥56 tall, focused by default with the focus ring. Dismiss also on `Ⓑ`/Esc.
- **Hint bar:** `VbHintBar` — `Ⓐ Get started` … `Ⓑ Skip`.

## Wiring (unchanged semantics)

- Gate on `StreamingPreferences.seenWelcomeHint`; on accept/dismiss call the existing `markSeen()`
  (`seenWelcomeHint = true; save()`). Show once. Keep the "never destroyed host component" pattern
  note from `main.qml` if the new sheet lives at the same scope.
- All copy stays `qsTr(...)` for i18n. No new preference keys.

## Acceptance (four-test scorecard)

- **Build:** `qmake6 && make release` 0 errors; `qmllint`/`qmlcachegen` clean on the new file + `main.qml`.
- **Smoke:** on a fresh profile (unset `seenWelcomeHint`) the welcome sheet appears once over
  Computers; "Get started" (Ⓐ) dismisses it; relaunch does **not** show it again.
- **Regression:** existing startup path unaffected (PC grid loads behind/after dismiss); the flag key
  `uishowhints`/`seenwelcomehint` semantics unchanged; no host/stream code touched.
- **Negative:** with `seenWelcomeHint` already true the sheet never opens; renders correctly at
  1280×800 and 1920×1200; focus cannot escape the modal while open.

## Reset for testing

Provide the test agent a one-liner to clear the flag (delete `seenwelcomehint` from the Vibemis
QSettings ini) so first-run can be re-triggered on the device.
