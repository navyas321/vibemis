# Spec — Settings (1e): type & spacing pass

**Surface:** `app/gui/SettingsView.qml` · **Handoff:** `1e` Settings (sidebar categories) ·
**Follows:** test130 (BL-2107 color migration) · **Kind:** launcher-only `test<N>` PR

## Why

BL-2107 migrated SettingsView's 21 color literals onto semantic tokens (`VbTokens.textTertiary`,
`statusWarning`, `statusSuccess`, `statusInfo`, `controlTrackOff`, `textOnAccent`). It deliberately
**left type and spacing alone** so the color change could be verified in isolation. SettingsView still
sizes text with raw Qt `pointSize` (9 / 11 / …) and uses ad-hoc margins/padding — a different unit
system than the redesign pixel scale, and the last remaining bypass of the design system on this
screen.

## Scope

1. **Type → the 6-step scale.** Replace every `font.pointSize: N` with the role token:
   - section/group titles → `VbTokens.typeTitle` (28) or `typeHeading` (27), `font.family:
     VbTokens.fontDisplay`, bold.
   - control labels / field labels → `VbTokens.typeLabel` (14), `font.family: VbTokens.fontBody`.
   - body / dropdown text → `VbTokens.typeBody` (16).
   - helper / description / advisory lines (the `pointSize: 9` captions) → `VbTokens.typeCaption`
     (13), `font.family: VbTokens.fontBody`.
   Keep `font.capitalization: Font.MixedCase`. Do **not** change any string or control wiring.
2. **Spacing → the 4px scale.** Replace ad-hoc `spacing:` / `*Padding:` / `*Margin:` numbers with
   `VbTokens.space1..6`. Row height → `VbTokens.listRowH` (66). Group inner padding → `space3` (12);
   between groups → `space4` (16); section separation → `space5` (24).
3. **Touch targets.** Ensure every interactive control's hit area ≥ `VbTokens.minHitTarget` (56) in
   Game Mode; do not shrink below 44 in Desktop Mode.
4. No color changes (already done in test130). No behavior/preference changes.

## Acceptance (four-test scorecard)

- **Build:** `qmake6 && make release` 0 errors; `qmllint` clean on `SettingsView.qml`;
  `qmlcachegen` compiles it.
- **Smoke:** launcher opens Settings; all five categories (Video / Audio / Input / Streaming /
  Advanced) render; LB/RB switches categories; every control reachable by D-pad.
- **Regression:** no `font.pointSize` literals remain in `SettingsView.qml`
  (`grep -c 'pointSize' == 0`); no ad-hoc spacing literals outside `VbTokens.*`; screenshot-diff vs
  test130 shows **only** type/size/rhythm changes, no color or copy change.
- **Negative:** long labels/translations elide or wrap without clipping at 1280×800 and 1920×1200;
  a category with many rows scrolls (Flickable) without focus escaping the panel.

## Notes

Sizing shifts *will* move layout — expect a real screenshot diff; that is the intended change. Land it
as its own PR so the diff is attributable. Watch the two SettingsView-touching neighbors (the color
pass test130, and any in-flight Settings feature) for merge order.
