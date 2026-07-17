# Spec — In-stream Quick Menu overlay

**Surface:** `app/gui/QuickMenu.qml` (+ `ServerCommands.qml`) · **Handoff:** none — the Quick Menu is
an in-stream overlay, not one of the six launcher screens; it is aligned *to* the redesign language ·
**Kind:** launcher-only `test<N>` PR (renders offscreen; verify via the offscreen-render harness /
screenshot, no host needed to see the panel)

## Current state (what exists)

`QuickMenu.qml` is **already redesigned onto the token system** (per its header comment): dark
elevated panel (`VbTokens.bgElev`, `radiusWindow`), Sora/Manrope type, `VbSheetIcon` line glyphs
(not emoji), sheet-style rows, a hint-bar footer. It has **zero hardcoded hex literals** and ~40
`VbTokens.*` refs. The input model (d-pad auto-repeat, left stick, injected keys, offscreen render
into the stream) is unchanged and working. `ServerCommands.qml` (submenu) is the remaining sibling
that has **not** been migrated (0 `VbTokens` refs — still on ad-hoc colors).

So this is a **polish + parity** spec, not a redesign.

## Scope

1. **ServerCommands.qml migration.** Bring the Server Commands submenu onto tokens the same way
   QuickMenu was done: replace its ad-hoc colors/sizes with `VbTokens.*` (surface `bgElev`, text
   `text`/`textDim`, rows on `listRowH`, glyphs via `VbSheetIcon`, hint-bar footer). It is reachable
   only through the Quick Menu, so it must match visually.
2. **Semantic-alias adoption (optional, low-risk).** Where QuickMenu references base tokens directly
   (`bgElev`, `text`, `strokeSoft`), optionally switch to the semantic aliases (`surfaceRaised`,
   `textPrimary`, `dividerSoft`) for intent clarity. Pure rename, no visual change — verify identical
   screenshot.
3. **Focus-ring / hint-bar parity.** Confirm the focused row uses the standard recipe (2px accent +
   5px accent@22% glow + `interactiveFocus` fill) — reuse `VbFocusRing` if it isn't already — and the
   footer uses `VbHintBar` glyph conventions (`Ⓐ Select  Ⓑ Back/Resume`), matching the launcher
   screens. The offscreen engine sees the same qrc singletons, so components resolve.
4. **Touch/hit targets** ≥ `VbTokens.minHitTarget` (56) for every row.

## Acceptance (four-test scorecard)

- **Build:** `qmake6 && make release` 0 errors; `qmllint`/`qmlcachegen` clean on `QuickMenu.qml` +
  `ServerCommands.qml`.
- **Smoke:** offscreen render (or in-stream on device) shows the main menu and the Server Commands
  submenu with one consistent surface/accent/type system; d-pad navigates; `Ⓑ` returns submenu→main
  and main→resume.
- **Regression:** input model untouched (`injectKey`/auto-repeat/left-stick still work); `grep -c`
  for hardcoded hex in `ServerCommands.qml` == 0 after migration; QuickMenu screenshot identical if
  only aliases changed.
- **Negative:** menu still composites correctly over the stream via `OverlayManager` (EGL/SDL/VAAPI
  renderers); Apollo-only commands appear only on capable hosts.

## Note

Because the panel renders in a **separate offscreen QML engine**, keep everything it references inside
the process-global qrc singletons (`VbTokens`, `VbSheetIcon`, `VbFocusRing`) — do not introduce a
dependency on a launcher-only context. This constraint is why the Quick Menu was migrated after the
launcher screens.
