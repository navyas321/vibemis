# Vibemis theme-consistency audit — hand-off to the build agent

**Filed by:** test agent (`clienttest`) · **Date:** 2026-07-11 · **Device:** Legion Go S Z2, SteamOS 3.8.5
**Build audited:** `0.6.7-alpha.test77-quickmenu-gamepad-close` (current on-device) @ QML `vibemis-main`
**Role note:** this is a *diagnosis + spec*. Per the test-agent charter I do not patch QML — **the redesign/migration is the build agent's job** (this continues P3.17, the design-system overhaul started in test73).

---

## Why pages look different (root cause)

test73 shipped **`app/gui/Theme.qml`** — a complete design-token singleton (colors, type scale, spacing, radius). **But the pages were never migrated to consume it.** Each page still defines its own colors independently, so they diverge:

| Page (QML) | `Theme.*` refs | Hardcoded colors | Material/palette | Effect |
|---|---|---|---|---|
| `main.qml` | 2 | 1 | 1 | root only |
| `PcView.qml` (Computers) | **0** | 4 | — | Material-ish gray tiles + blue header |
| `AppView.qml` (app grid) | **0** | 2 | **Material** | Material defaults |
| `SettingsView.qml` | **0** | **17** | — | bespoke palette, 17 literals |
| `QuickMenu.qml` | **0** | **12** | — | teal/dark rounded panel (its own look) |
| `ServerCommands.qml` | **0** | 8 | — | matches QuickMenu-ish |
| `ClipboardSettings.qml` | **0** | 4 | — | own colors |
| `Toast.qml` | **0** | 3 | — | own colors |

Net: the **Computers/App-grid pages render via Qt Quick Material defaults**, while the **Quick Menu / Server Commands** use a hand-rolled teal-on-dark palette, and **Settings** uses yet another set of 17 literals. No page (except `main.qml`) references `Theme`.

## The tokens already exist (`app/gui/Theme.qml`)
- **Color:** `accent #00CCCC`, `accentPressed`, `background #303030`, `surface #2D2D2D`, `surfaceAlt #424242`, `border #444444`, `textPrimary/Secondary/Tertiary/Disabled`, `success/warning/error/info`, `scrim`.
- **Type:** `fontDisplay 24 / fontTitle 20 / fontHeading 14 / fontSection 12 / fontBody 11 / fontCaption 9`.
- **Spacing:** `spacingXS…XL` (4px base). **Shape:** `radius 10 / radiusS 5 / borderWidth 1`. **Ergonomics:** `touchMinHeight 40 / touchMinWidth 88`.

## Proposed migration (build agent — one page at a time, no behavior change)
1. `import Theme 1.0` in each page and replace every hardcoded color/size with the matching token:
   - dark grays `#303030/#2D2D2D/#424242` → `Theme.background/surface/surfaceAlt`
   - teal `#00CCCC` (already in QuickMenu) → `Theme.accent`; borders → `Theme.border`
   - text whites/grays → `Theme.textPrimary/Secondary/Tertiary`
   - point sizes → `Theme.font*`; margins/spacing → `Theme.spacing*`; corner radii → `Theme.radius*`.
2. **PcView + AppView are the biggest divergence** — they inherit Qt Quick **Material**. Either set a Material theme derived from the tokens (accent = `Theme.accent`, background = `Theme.background`) in `main.qml`, or restyle the tile/header delegates to the tokens so the Computers/grid pages match the Quick Menu / Settings look.
3. Keep the `main.qml` window background as the single root; ensure headers/toolbars use `Theme.accent`/`Theme.surface` consistently.
4. Suggested order (highest visual payoff first): PcView → AppView → SettingsView → ClipboardSettings → Toast (QuickMenu/ServerCommands already close to the token palette; align their literals to `Theme.*` for the win).

## Verification (test agent, after the build agent migrates)
Re-screenshot every page under `scripts/gamescope-emulate.sh` and diff against the current set (attached zip) — confirm one consistent surface/accent/type system across Computers, App grid, Settings, Help, Add-PC, Quick Menu, Server Commands.

## Attached
`vibemis-pages-<date>.zip` — current-state screenshots of every launcher page (for Claude Design review).
