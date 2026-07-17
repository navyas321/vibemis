# vibemis 0.3.0 — The Redesign Release

This release is a ground-up refresh of the vibemis look and feel. Every user-facing
screen now draws its colors, typography, and spacing from a single shared design
language, so the app reads as one coherent product instead of a set of separately
styled panels. Alongside the redesign it carries a new first-run welcome experience,
sharper brand consistency, and a large behind-the-scenes cleanup.

## Highlights

- **A new semantic design system.** Colors, type, and spacing are now defined once
  and reused everywhere, giving the whole app a consistent, intentional look.
- **Restyled Settings.** The Settings screen was rebuilt on the new type scale,
  spacing rhythm, and tokenized color palette — cleaner hierarchy, better alignment,
  no more one-off hard-coded values.
- **New first-run welcome sheet.** First launch now greets you with a polished,
  fully themed welcome screen.
- **Quick Menu & Server Commands parity.** These surfaces were brought onto the same
  design language for a matching, consistent feel.
- **Unified brand accent.** The signature teal (`#00CCCC`) is now driven from one
  place, so the accent is identical across every screen.

## UI & UX Redesign

- Introduced a semantic design-token layer as the single source for the app's colors,
  typography, and spacing, backed by a documented design system and per-screen specs.
- Migrated the Settings screen's color values onto semantic tokens (21 previously
  hard-coded literals removed).
- Moved Settings' typography and spacing onto the shared design scale for consistent
  text sizing and layout rhythm.
- Added a new, fully token-styled first-run welcome sheet.
- Brought the Quick Menu and Server Commands surfaces onto the design tokens, with
  alias and visual-parity polish so they match the rest of the app.
- Migrated the Toast notifications and Clipboard settings onto the design tokens.

## Fixes

- The brand accent color is now sourced from a single source of truth, eliminating
  divergent teal values that could drift between screens.

## Under the Hood

- Refreshed the product screenshots used for store/listing pages, re-captured from
  real streaming sessions and with neutral host names for privacy.
- Added internal design documentation: the design system reference, a redesign
  handoff kit, and reconciliation notes for the semantic-token work.
- Large repository cleanup: removed leftover internal build/process files and stale
  references, tidied comments, and refreshed the README.
- Release changelog generation now strips internal tracking identifiers so published
  notes stay clean.

## Auto-updates

vibemis ships as a self-updating AppImage. If you already have an earlier build
installed (0.2.0 or older), the app will automatically detect 0.3.0, and offer to
download and install it — no manual reinstall needed.

Channel model: **stable** releases carry a bare version number (this one is `0.3.0`)
and are published as the **Latest** release, which is what the updater offers by
default. Pre-release builds carry an `-alpha.N` / `-beta.N` suffix, are marked as
pre-releases, and are only surfaced to users who opt into the pre-release channel.

## Versioning

vibemis follows **Semantic Versioning 2.0.0**. `0.3.0` is a **minor** release over
`0.2.0`: it adds new, backward-compatible functionality (the redesign and the new
welcome sheet) with no breaking changes to your existing configuration. Pre-release
builds use the standard SemVer pre-release suffix form (for example
`0.3.0-beta.8`). Released versions and their tags are permanent.
