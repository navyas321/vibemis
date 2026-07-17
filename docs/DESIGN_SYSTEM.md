# Vibemis design system

The single source of truth for Vibemis's visual language. Every new/restyled QML surface should
pull from these tokens instead of hardcoding values. Tokens are implemented as the `Theme` QML
singleton (`app/gui/Theme.qml`, `import Theme 1.0` → `Theme.accent`, `Theme.spacingM`, …) so a change
here propagates everywhere.

> **Why this exists:** the audit (see bottom) found 15+ ad-hoc hex colors, 11 unscaled font sizes,
> 6 ad-hoc spacing values, two accent colors (`#00CCCC` vs HTML `skyblue`), and duplicated component
> styling. This system replaces that with a small, named, handheld-first scale.

**Design principles**
1. **Handheld-first.** Primary target is the Legion Go S Z2 in **Game Mode (Gamescope)** held at
   arm's length. Type must be readable, touch/focus targets large, contrast high.
2. **Both modes.** Everything must work in Game Mode *and* Desktop Mode (KDE). Game Mode is the
   authoritative result.
3. **One accent, used sparingly.** Teal `#00CCCC` signals "interactive / Vibemis". Don't flood it.
4. **Dark-first, theme-ready.** Current theme is dark; all colors go through tokens so a light theme
   is a later token swap, not a rewrite.
5. **Tokens over literals.** No new hardcoded hex / size / spacing in QML — reference `Theme.*`.

---

## 1. Color

| Token | Value | Use |
|-------|-------|-----|
| `accent` | `#00CCCC` | Interactive emphasis, section titles, focus borders, key values. The Vibemis teal. **Replaces the HTML `skyblue` used in GroupBox titles.** |
| `accentPressed` | `#00A3A3` | Pressed/active state of accented controls. |
| `background` | `#303030` | App root background (Material.background). |
| `surface` | `#2D2D2D` | Raised surfaces: overlays, Quick Menu, cards. |
| `surfaceAlt` | `#424242` | Popups, combo dropdowns (contrast against `surface`). |
| `border` | `#444444` | Default 1px borders/dividers on dark surfaces. |
| `textPrimary` | `#FFFFFF` | Primary text. |
| `textSecondary` | `#CCCCCC` | Secondary text, descriptions. |
| `textTertiary` | `#AAAAAA` | Hints, captions, helper lines. |
| `textDisabled` | `#777777` | Disabled/very faint (replaces stray `#888888`). |
| `success` | `#4CAF50` | Success toast/state. |
| `warning` | `#E0A030` | Warnings/advisories (the **single** amber — retire `#FFC107`). |
| `error` | `#F44336` | Errors/failures. |
| `info` | `#80A0C0` | Neutral informational accent (e.g. version note). |
| `scrim` | `#D0000000` | Overlay scrim behind modals/Quick Menu. |

**Rules**
- Section/group titles use `accent` — not `skyblue`, not bold-white.
- Pick text color by tier (primary/secondary/tertiary), never a new grey.
- One amber only (`warning`). `success`/`error` are reserved for actual result states.

## 2. Typography

System font (no bundled family). A 6-step scale by **role**, not by pixel guesswork.

| Token | pt | Weight | Role |
|-------|----|--------|------|
| `fontDisplay` | 24 | Bold | Overlay/Quick Menu title, big empty-state headers. |
| `fontTitle` | 20 | Bold | Screen/toolbar titles, segue headers. |
| `fontHeading` | 14 | Bold | Card titles, menu item primary text. |
| `fontSection` | 12 | Bold | GroupBox section titles, form group labels. |
| `fontBody` | 11 | Normal | Standard control labels, body copy. |
| `fontCaption` | 9 | Normal | Hints, descriptions, helper lines, advisories. |

**Rules**
- PC-grid name was **36pt** — cap at `fontTitle` (20) and elide; 36 breaks narrow layouts.
- Use `pointSize` everywhere (retire the lone `pixelSize` in PcView).
- `font.capitalization` stays **MixedCase** globally — no ALL-CAPS Material buttons.
- One weight axis: Normal or Bold. No per-instance ad-hoc sizes outside the scale.

## 3. Spacing

4px base unit; a 5-step scale. Replaces the ad-hoc {5,8,10,12,15,20}.

| Token | px | Use |
|-------|----|-----|
| `spacingXS` | 4 | Tight gaps (label→helper line, icon→text). |
| `spacingS` | 8 | Intra-component spacing, list row gaps. |
| `spacingM` | 12 | Default control spacing, GroupBox inner padding. |
| `spacingL` | 16 | Between form groups. |
| `spacingXL` | 24 | Section separation, screen margins. |

`radius` = **10** (cards/overlays/toasts), `radiusS` = **5** (buttons/chips). `borderWidth` = **1**.

## 4. Components

- **Section title** — a reusable `SectionTitle` (text `accent`, `fontSection`) replaces the
  `<font color="skyblue">…</font>` HTML wrap in SettingsView/ServerCommands/ClipboardSettings.
- **Button** — Material base; hover = `surface` bg + `accent` 1px border; pressed = `#333`; radius
  `radiusS`. Min height **40**, min touch width **88** (handheld ergonomics). MixedCase label.
- **Label** — color by text tier; `wrapMode: Text.Wrap`; helper lines use `fontCaption`+`textTertiary`.
- **CheckBox / ComboBox / SpinBox** — Material defaults; combo popup bg `surfaceAlt`.
- **GroupBox** — inner padding `spacingM`; title via SectionTitle; no extra border.
- **Toast** — `surface` bg, `border` 1px, `radius`, opacity 0.92, `fontHeading` text. **One**
  implementation (`Toast.qml`); Quick Menu reuses it instead of an inline Rectangle.
- **Dialog** — `surface` bg, `radius`, scrim `scrim`; body `fontBody`, wrap on.

## 5. Layout / responsiveness
- Don't hardcode window-sized constants. Grid cells and the 2-column Settings should collapse to a
  single column below ~900px width so non-1280×600 displays (and Game Mode scaling) don't clip.
- Focus order must be controller-navigable (D-pad/stick) on every screen — preserve the existing
  `Navigable*` component behavior when restyling.

## 6. Rollout order (one launcher-only PR each)
0. **Theme singleton** (`Theme.qml` + registration) — infrastructure, no visual change.
1. **Settings** — largest surface: SectionTitle + token colors/spacing/type. *(do after the current
   SettingsView work settles, to avoid merge churn.)*
2. **Computers / Add-PC home** — grid card, name elide, empty state.
3. **Onboarding / first-run** — welcome + hint hierarchy.
4. **Quick Menu overlay** — token colors, reuse `Toast.qml`.
5. **Accessibility/ergonomics pass** — touch targets, focus order, arm's-length type — device sign-off.

---

## Audit baseline (what these tokens replace)
- **Colors:** `#00CCCC`/`skyblue` (two accents), greys `#FFFFFF`/`#cccccc`/`#aaaaaa`/`#888888` used
  interchangeably, ambers `#E0A030`+`#FFC107`, plus one-off `#1a1a2e`, `#D0808080`, `#80A0C0`.
- **Type:** sizes 8,9,10,11,12,14,20,22,24,36 with no semantic scale; PC name at 36pt; one `pixelSize`.
- **Spacing:** 5,8,10,12,15,20 ad-hoc; padding mostly inherited.
- **Components:** no shared Button/Label/GroupBox/SectionTitle; Toast implemented twice; Settings is
  a ~2000-line 2-column monolith.
