# Vibemis design system

The single source of truth for Vibemis's visual language. Every new / restyled QML surface pulls
from **design tokens** instead of hardcoding values, so a change here propagates everywhere and a
future theme swap re-points tokens rather than rewriting pages.

## Design source & provenance

This system is the QML realisation of the maintainer's **Claude Design handoff** (P3.18) — a finished
gamepad-first prototype of the six launcher screens, source of truth for the visual language. The
handoff (`HANDOFF.md`, `CLAUDE_CODE_PROMPT.txt`, `tokens/vibemis-tokens.json`, `previews/`, the
`Vibemis Redesign.dc.html` canvas) lives at **`docs/design/redesign/`** in this repo (exported by the
maintainer, committed by the test agent). Its tokens were mapped 1:1 into `VbTokens.qml` in **test88**;
screens 1a–1f were then built as launcher-only `test<N>` PRs (test89–92, 94–96, 108, BL-1684).

> **Canonical token singleton: `app/gui/VbTokens.qml`** (`import Vibemis.Redesign 1.0` →
> `VbTokens.accent`, `VbTokens.surfaceRaised`, `VbTokens.space3`, …). This is the redesign token layer
> the live launcher screens consume (PcView, AppView, SettingsView, QuickMenu, Toast,
> ClipboardSettings, VbHostSheet, VbHelpView). `app/gui/Theme.qml` (`import Theme 1.0`) is a **legacy
> alias** kept for the Qt Quick Material bridge in `main.qml`; since BL-2077 its accent resolves
> through `VbTokens.accent`, so there is one source of truth for the brand accent. **New work targets
> `VbTokens`.** When a token changes, update this doc + `VbTokens.qml` in the same commit (P3.18 sync
> rule), and reconcile against `docs/design/redesign/tokens/vibemis-tokens.json`.

**Anchor:** the Vibemis teal **`#00CCCC`** (BL-2077, user-signed-off) is the single brand accent and
the anchor for all P3.17/P3.18 design work. It is one of four curated `accentOptions`; index 0 is the
default; everything else is designed against it.

> **⚠ Reconciliation flag (accent).** The design-time `HANDOFF.md` summarised the accent as
> **`#2FC6D0`** (with 3 alt accents). The in-repo canonical is **`#00CCCC`** — the BL-2077
> user-signed-off value, decided *after* the design export. `VbTokens.accent` = `#00CCCC` **wins**;
> `#2FC6D0` is treated as superseded. This is surfaced, not silently changed — if the full
> `vibemis-tokens.json` still carries `#2FC6D0`, keep `#00CCCC` and note the divergence rather than
> reverting the user's decision.

**Design principles**
1. **Handheld-first.** Primary target is the Legion Go S Z2 in **Game Mode (Gamescope)** held at
   arm's length. Type readable, touch/focus targets large (≥56px), contrast high (WCAG AA floor).
2. **Both modes.** Everything must work in Game Mode *and* Desktop Mode (KDE). Game Mode is the
   authoritative result.
3. **One accent, used sparingly.** Teal `#00CCCC` signals "interactive / Vibemis". Don't flood it —
   it marks focus, selection, key values and the primary action, nothing else.
4. **Dark-first, theme-ready.** The current theme is dark; all colors go through tokens so a light
   theme is a later token swap, not a rewrite.
5. **Tokens over literals, by ROLE.** No new hardcoded hex / size / spacing in QML. Prefer a
   **semantic** token (`surfaceRaised`, `textTertiary`, `statusWarning`) that names *what the element
   is* over a raw base token (`bgElev`, `#A9AFB6`, `#E0A030`).

---

## Token architecture — base layer + semantic layer

`VbTokens.qml` is organised in two tiers:

- **Base / primitive tokens** — the raw palette + scale values mapped from the handoff
  (`bgElev`, `accent`, `text`, `sizeBody`, `minHitTarget`, the focus-ring recipe). Physical values.
- **Semantic tokens** (BL-2107) — role-named aliases layered *over* the base tokens
  (`surfaceRaised → bgElev`, `textPrimary → text`, `statusSuccess → statusOnline`), plus a few new
  values where a role had no base token yet (`textTertiary`, `controlTrackOff`, `statusWarning`,
  `statusInfo`). Purely **additive**: pages that read base tokens directly are untouched, so the
  semantic layer introduces **zero visual regressions** to already-migrated screens (PcView, AppView,
  Toast, ClipboardSettings, QuickMenu, VbHostSheet, VbHelpView).

Reference the **semantic** name when one exists; reach for a base token only for frame-level
primitives with no semantic role (screen padding, header height, radii, motion).

> **Agent-derived semantic values to reconcile.** Four semantic values were derived from the current
> app's SettingsView literals + WCAG, not from the handoff summary: `textTertiary #A9AFB6`,
> `controlTrackOff #2A2F37`, `statusWarning #E0A030`, `statusInfo #80A0C0`. When the full
> `tokens/vibemis-tokens.json` lands, confirm these against it; keep the WCAG-passing value and flag
> any difference rather than silently changing.

---

## 1. Color

### 1.1 Surface / background scale (dark, sunken → raised)

| Semantic | → base | Value | Use |
|----------|--------|-------|-----|
| `surfaceSunken`  | `bgApp`    | `#08090B` | Behind the rounded window (outermost). |
| `surfaceBase`    | `bgWindow` | `#0E1013` | Screen background. |
| `surfaceRaised`  | `bgElev`   | `#15181D` | Cards, panels, dialogs, sidebar/list rows. **Most content sits here.** |
| `surfaceOverlay` | `bgElev2`  | `#1B1F26` | Focused/selected fill, chips, hover. |
| `surfaceFooter`  | `bgFooter` | `#0B0D10` | Bottom gamepad hint bar. |
| `divider`        | `stroke`   | white @ 8% | Default 1px card border. |
| `dividerSoft`    | `strokeSoft` | white @ 6% | Header/footer dividers. |

### 1.2 Text hierarchy

Contrast tags below are measured against `surfaceRaised` **`#15181D`** (where cards render); all also
pass against `surfaceBase`/`surfaceSunken` (darker → higher ratio). AA floor = 4.5:1 (normal text),
3:1 (large ≥18px / ≥14px-bold).

| Semantic | → base | Value | Contrast on `#15181D` | Use |
|----------|--------|-------|----------------------|-----|
| `textPrimary`   | `text`    | `#ECEEF1` | **15.3:1 AAA** | Headings, values, primary copy. |
| `textSecondary` | `textDim` | `#98A1AB` | **6.8:1 AA**   | Labels, secondary lines. |
| `textTertiary`  | *(new)*   | `#A9AFB6` | **8.0:1 AAA**  | Captions, hints, helper/description lines. |
| `textDisabled`  | *(new)*   | `#5A626C` | 2.9:1 (decorative/large only) | Disabled control text. |
| `textOnAccent`  | *base*    | `#08090B` | 9.97:1 on `#00CCCC` · 10.6:1 on `#3ED598` | Text/glyph on an accent or success fill. |

> `textTertiary #A9AFB6` is a **new value** replacing the ad-hoc warm-grey `#aaaaaa` used across
> SettingsView. It is hue-aligned to the cool text ramp (was a warm neutral that clashed) and keeps
> the same effective luminance, so captions stay legible at arm's length while joining the ramp — a
> *deliberate* small color delta in screenshot diffs.

### 1.3 Interactive states (normal / hover / focus / pressed / disabled)

| Semantic | → base | Value | State |
|----------|--------|-------|-------|
| *(normal)* accent | `accent` | `#00CCCC` | Idle accented control / selection. |
| `interactiveHover`  | `bgElev2`   | `#1B1F26` | Row / button / icon-button **hover** fill. |
| `interactiveFocus`  | `focusedFill` (`bgElev2`) | `#1B1F26` | **Focused** fill — pair with the focus ring (§4). |
| `accentPressed`     | *(new)* | `#00A3A3` | **Pressed** accented control. |
| `interactivePressed`| `bgElev` | `#15181D` | Pressed neutral fill (recedes under press). |
| `controlTrackOff`   | *(new)* | `#2A2F37` | Toggle / switch **OFF** track (6.7:1 vs the ON accent — clearly distinct). |
| `controlTrackOn`    | `accent` | `#00CCCC` | Toggle / switch **ON** track. |
| `disabledOpacity`   | *(new)* | `0.38` | Whole-control **disabled** dim (opacity multiplier). |

### 1.4 Status / feedback

One status system, used for actual result/advisory states only — never as decoration.

| Semantic | → base | Value | Contrast on `#15181D` | Use |
|----------|--------|-------|----------------------|-----|
| `statusSuccess` | `statusOnline` | `#3ED598` | **9.5:1 AAA** | Positive / recommended (✓), online dot, RESUME badge. |
| `statusWarning` | *(new)* | `#E0A030` | **7.8:1 AAA** | Advisory / caution (⚠). **The single amber.** |
| `statusDanger`  | *base* | `#F26D6D` | **6.1:1 AA**  | Destructive / error (Delete PC, failures). |
| `statusInfo`    | *(new)* | `#80A0C0` | **6.5:1 AA**  | Neutral informational note. |
| `statusOffline` | *base* | `#5A626C` | 2.9:1 (decorative) | Offline dot / greyed monitor — **never body text**. |

> `statusSuccess` unifies the two greens that existed (`#3ED598` brand green + the ad-hoc `#80C080`
> sage in SettingsView) onto the brand success green. The one ✓ advisory that used `#80C080` becomes
> brighter/on-brand — a *deliberate* screenshot diff.

**Color rules**
- Pick text by tier (`textPrimary`/`Secondary`/`Tertiary`), never invent a grey.
- One amber only (`statusWarning`). `statusSuccess`/`statusDanger` are reserved for real states.
- `statusOffline`/`textDisabled` fall below the AA text floor by design — use them for
  dots/decoration/disabled affordances, not for content the user must read.

## 2. Typography

Two families: **Sora** (`fontDisplay` — titles, card names, all-caps labels, wordmark; weights
700/800) and **Manrope** (`fontBody` — body + UI text; weights 400–800), both bundled in the build
(test94). A **6-step scale by role** (pixel sizes on the 1920×1200 redesign canvas; they scale with
the layout to 1280×800).

| Semantic | → base | px | Family / weight | Role |
|----------|--------|----|-----------------|------|
| `typeDisplay` | `sizeScreenTitle`  | 34 | Sora / Bold   | Screen titles, big empty-state headers. |
| `typeTitle`   | `sizeSectionTitle` | 28 | Sora / Semibold | Section titles, side-sheet name. |
| `typeHeading` | `sizeCardName`     | 27 | Sora / Semibold | Card / PC names (elide; never grow past this). |
| `typeBody`    | `sizeBody`         | 16 | Manrope / Regular | Body copy, control text. |
| `typeLabel`   | `sizeLabel`        | 14 | Manrope / Medium | Field labels, menu items. |
| `typeCaption` | `sizeBadge`        | 13 | Sora / Bold (tracked) | Captions, badges, status pills. |

Special: `sizeWordmark` 21 (the "Vibemis" wordmark, `wordmarkSpacing` 3.0). `badgeSpacing` 1.2 for
all-caps badges.

**Type rules**
- Card/PC names cap at `typeHeading` (27) and **elide** — never let a long name reflow the grid.
- `font.capitalization` stays **MixedCase** globally — no ALL-CAPS Material buttons (badges excepted).
- One weight axis per family. No per-instance ad-hoc sizes outside the scale.
- **Legacy pointSize surfaces** (`SettingsView.qml` uses Qt `pointSize` 9/11/…, a different unit than
  the redesign pixel scale). The BL-2107 pass migrated SettingsView's **colors** onto semantic tokens
  but left its type on `pointSize`; converting it to the pixel type scale is a tracked follow-up
  (`docs/design/specs/README.md`) so the size change is verified in isolation.

## 3. Spacing

4px base unit, 6-step scale, for intra-component spacing. Frame-level constants (`screenPadX` 56,
`screenPadY` 52, `headerH` 84, `footerH` 72, `cardGap` 32, `tileGap` 36) stay as their own tuned base
tokens — they are canvas geometry, not the component rhythm.

| Semantic | px | Use |
|----------|----|-----|
| `space1` | 4  | Tight: icon→text, label→helper line. |
| `space2` | 8  | Intra-component, list-row gaps. |
| `space3` | 12 | Default control spacing, group inner padding. |
| `space4` | 16 | Between form groups. |
| `space5` | 24 | Section separation. |
| `space6` | 32 | Major block separation (= `cardGap`). |

**Radius** (base tokens): `radiusWindow` 20 · `radiusDialog` 24 · `radiusCard` 16 · `radiusControl`
14 · `radiusIconButton` 14 · `radiusBadge` 7 · `radiusPill` 999.

## 4. Controller-focus ring

Focus must be unmistakable at arm's length under a controller/D-pad — the primary navigation model in
Game Mode (one focused element per screen). Base-token recipe (already in `VbTokens`, matches the
handoff exactly):

| Token | Value | Meaning |
|-------|-------|---------|
| `focusBorder`    | `2` px | Accent border on the focused element. |
| `focusGlow`      | `5` px | Accent glow radius outside the border. |
| `focusGlowAlpha` | `0.22` | Glow opacity. |
| `focusGlowColor` | `accent @ 22%` | The glow color (follows the active accent). |
| `focusedFill` / `interactiveFocus` | `bgElev2` `#1B1F26` | The focused element's fill. |

**Recipe:** focused element = `interactiveFocus` fill + `focusBorder` (2px `accent`) border +
`focusGlow` (5px `accent`@22%) glow + elevation. Implemented as the reusable `VbFocusRing.qml`. Focus
order must be controller-navigable (D-pad/stick) on every screen — preserve the existing `Navigable*`
/ `SdlGamepadKeyNavigation` behavior when restyling. A persistent, toggleable gamepad **hint bar**
(`VbHintBar.qml`, `Ⓐ/Ⓑ/Ⓧ/Ⓨ`, `LB/RB`, `☰`) sits at the bottom of every screen (`showHints`).

## 5. Minimum touch / focus targets (ergonomics)

Handheld-first sizing — a fingertip and a fast-moving focus cursor both need generous targets. Base
tokens.

| Token | px | Use |
|-------|----|-----|
| `minHitTarget` | **56** | Minimum interactive target (button, toggle, icon-button, list-row hit area) in **Game Mode**. |
| `listRowH`     | 66 | Settings/list row height (handoff action rows 66px). |
| `iconButton`   | 52 | Icon-button box (inside a ≥56 hit area). |
| `buttonGlyphD` | 30 | Gamepad glyph diameter in the hint bar. |

**Both modes:** the 56px floor holds in Game Mode (authoritative). Desktop Mode may render controls
visually tighter but must keep the same hit areas — never drop a target below the **44px** absolute
WCAG/pointer floor even with a mouse.

---

## 6. Rollout order & implementation status (one launcher-only `test<N>` PR each)

Per P3.17 step 3 / P3.19 waves. The six handoff screens are `1a`–`1f`.

| # | Screen (handoff id) | QML | Status |
|---|---------------------|-----|--------|
| 0 | **Token layer** (VbTokens + Vb* components) | `VbTokens.qml`, `VbFocusRing/Card/HintBar/HostCard/HostSheet/StatusPill/Badge` | ✅ base (test88); **semantic layer this PR (test130, BL-2107)** |
| 1a | **Computers** host list | `PcView.qml` + `VbHostCard.qml` | ✅ merged (test92) |
| 1b | **App grid** | `AppView.qml` | ✅ merged (test91) |
| 1c | **Add-PC dialog** | `PcView.qml` dialog | ✅ merged (test90) |
| 1d | **Host options side-sheet** | `VbHostSheet.qml` + `VbSheetIcon.qml` | ✅ implemented |
| 1e | **Settings** (sidebar categories) | `SettingsView.qml` | 🟡 structure + chip + LB/RB nav merged (test96/108); **colors on semantic tokens this PR (test130)**; type pass tracked |
| 1f | **Help** | `VbHelpView.qml` | ✅ merged (test89 / BL-1684) |
| — | **Onboarding / first-run** *(not a handoff screen)* | — | 📝 spec ready → `docs/design/specs/onboarding-first-run.md` |
| — | **In-stream Quick Menu overlay** *(not a handoff screen)* | `QuickMenu.qml` | 📝 spec ready → `docs/design/specs/quick-menu.md` |
| 5 | **Accessibility / ergonomics pass** | all | device sign-off (Game Mode) — deferred to on-device |

The six launcher screens (`1a`–`1f`) are implemented against the handoff; do **not** re-spec them.
The two surfaces the handoff does **not** cover (onboarding/first-run, Quick Menu overlay) have
agent-authored specs in `docs/design/specs/`, each concrete enough to become its own launcher-only
`test<N>` PR. See `docs/design/specs/README.md` for the consumer rules.

---

## Appendix — WCAG contrast (computed, sRGB relative luminance)

Ratios of each foreground against the four dark surfaces. AA = 4.5 (normal) / 3.0 (large);
AAA = 7.0 (normal) / 4.5 (large).

| Foreground | `surfaceSunken` #08090B | `surfaceBase` #0E1013 | `surfaceRaised` #15181D | `surfaceOverlay` #1B1F26 |
|-----------|------|------|------|------|
| `textPrimary` #ECEEF1   | 17.14 AAA | 16.39 AAA | 15.31 AAA | 14.22 AAA |
| `textSecondary` #98A1AB | 7.61 AAA  | 7.28 AAA  | 6.80 AA   | 6.31 AA   |
| `textTertiary` #A9AFB6  | 8.99 AAA  | 8.61 AAA  | 8.04 AAA  | 7.47 AAA  |
| `accent` #00CCCC        | 9.97 AAA  | 9.53 AAA  | 8.90 AAA  | 8.27 AAA  |
| `accentHi` #6ADDE7      | 12.43 AAA | 11.89 AAA | 11.11 AAA | 10.32 AAA |
| `statusSuccess` #3ED598 | 10.60 AAA | 10.14 AAA | 9.47 AAA  | 8.80 AAA  |
| `statusWarning` #E0A030 | 8.77 AAA  | 8.38 AAA  | 7.83 AAA  | 7.27 AAA  |
| `statusInfo` #80A0C0    | 7.31 AAA  | 6.99 AA   | 6.53 AA   | 6.07 AA   |
| `statusDanger` #F26D6D  | 6.81 AA   | 6.52 AA   | 6.09 AA   | 5.65 AA   |
| `statusOffline`/`textDisabled` #5A626C | 3.22 large | 3.08 large | 2.88 fail | 2.67 fail | *(decorative/disabled only)* |

Text-on-fill: `textOnAccent #08090B` on `accent #00CCCC` = **9.97 AAA**; on `statusSuccess #3ED598`
= **10.60 AAA**. Toggle track: `controlTrackOff #2A2F37` vs `controlTrackOn #00CCCC` = **6.74** (state
distinctness — the OFF/ON toggle is unmistakable).

**Every token used as text meets WCAG AA on the surface it renders on.** The two sub-AA values
(`statusOffline`, `textDisabled`) are deliberately reserved for dots / decoration / disabled
affordances, never for content the user must read.

---

## Audit baseline (what these tokens replace)
From the test-agent theme audit (`vibemis-agent-meta/testing/theme-review/THEME-AUDIT.md`, PR #147):
15+ ad-hoc hex colors, 11 unscaled font sizes, 6 ad-hoc spacing values, two accents
(`#00CCCC` vs HTML `skyblue`), Toast implemented twice, pages rendering via bare Qt Quick Material
defaults. P3.19 waves 1–2 migrated PcView/AppView/Toast/ClipboardSettings; BL-2107 (this pass) added
the semantic layer + migrated SettingsView's remaining 21 color literals onto it.
