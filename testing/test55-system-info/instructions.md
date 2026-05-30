# test55 — System Information panel in Settings

**Feature:** A new read-only **"System Information"** group at the bottom of Settings showing:
Vibemis version, architecture, Steam Deck (Yes/No), display server (Wayland/XWayland/X11),
hardware decode availability, HDR support, and max resolution. Pure QML over the existing
`SystemProperties`. Helps with bug reports and mirrors what `vibemis selftest` reports headlessly.
**Branch:** `test55-system-info` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha pre-release
(tag contains `test55-system-info`).

> Fully **launcher-only** — no host/stream. Safe to run anytime.

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — panel renders with correct values (Desktop Mode)
1. Launch, open **Settings**, scroll to the bottom.
2. Confirm a **"System Information"** group appears with these rows populated (not blank):
   Vibemis version, Architecture, Steam Deck, Display server, Hardware decode, HDR support,
   Max resolution.
   - ✅ PASS if all rows show a value and none are empty/`undefined`.
3. Sanity-check a couple of values against reality on this device:
   - **Steam Deck** should read **Yes** (the Legion Go is detected as a Steam Deck-class device on
     SteamOS) — note the actual value either way.
   - **Architecture** should be an x86-64 string; **Max resolution** should match the panel.

## Tier 2 — Game Mode render (optional)
1. If convenient, open Settings in Game Mode and confirm the panel renders there too (it's a normal
   Settings group, so it should). Screenshot with **Super+S**. Mark N/A if not convenient.

## Tier 3 — cross-check against selftest (if test52/54 alpha available)
1. Run `Vibemis-x86_64.AppImage selftest --json` and eyeball that the environment is consistent
   (no contradiction with the panel). Informational only.

## Report
Write `testing/test55-system-info/report.md` (include a screenshot path + the displayed values),
update the `test55` row in `testing/TEST_CHECKLIST.md`, commit both on
`diagnostic/test55-system-info-report`, open a PR targeting `test55-system-info`.
