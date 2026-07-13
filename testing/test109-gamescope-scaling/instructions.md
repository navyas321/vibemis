# test109 — Gamescope High-DPI UI Scaling Fix

Fixes the UI scaling issue where the redesigned launcher layout overflows and clips on high-DPI panels (such as the Lenovo Legion Go's 1600p/1200p screen) when running under Gamescope (SteamOS Game Mode).

## Context
Qt's automatic high-DPI scaling detects the physical size of the Legion Go panel and applies a device-pixel-ratio (~1.5x) to logical pixels.
This forces the redesign's 1920x1200-absolute sizes to layout inside a smaller logical viewport (~1280x800 logical pixels), leading to UI clipping and overflow.

Since Gamescope already manages window scaling, client-side auto-scaling is redundant. We disable Qt High DPI scaling under Gamescope to maintain a 1:1 pixel-for-logical-pixel rendering layout at the actual window resolution (1920x1200), ensuring the UI matches the design specs perfectly.

## What changed (1 code file + cleanups)
- `app/main.cpp` — added detection for the Gamescope environment and set `QT_ENABLE_HIGHDPI_SCALING=0` to bypass automatic High-DPI scaling.
- `app/backend/systemproperties.h` — cleaned up unused declarations (`isSteamDeckOrGamescope`, `hasVulkanHdrSupport`, `isSteamDeck`, `hasVulkanHdr`) left behind by previous reverts to keep the code clean and prevent uninitialized member warnings.

---

## Tier 1 — Build / launch (must pass)

| # | Step | Expected |
|---|------|----------|
| 1 | Launch the test AppImage in Desktop Mode | App starts, reaches the Computers screen, no crash |
| 2 | Check version chip in Settings | Reads **`Version 1.0.0`** (or target 1.0.x build) |
| 3 | Run from a terminal, watch stdout/stderr | No crash or library-load warning related to Qt High-DPI scaling |

## Tier 2 — Core feature: Gamescope UI scaling (the main event)

Test under Gamescope (either SteamOS Game Mode or nested headless via `scripts/gamescope-emulate.sh`).

| # | Step | Expected |
|---|------|----------|
| 4 | Run under `scripts/gamescope-emulate.sh` at 1920x1200 (`scripts/gamescope-emulate.sh -w 1920 -h 1200 -s /tmp/gamescope-1920.png`) | Screen capture shows the Computers grid fits perfectly without any card or text clipping |
| 5 | Run at 1280x800 (`scripts/gamescope-emulate.sh -w 1280 -h 800 -s /tmp/gamescope-1280.png`) | Screen capture shows the grid elements scale down responsively and fit on screen without clipping |

## Tier 3 — Desktop Mode regression

| # | Step | Expected |
|---|------|----------|
| 6 | Run in normal Desktop Mode on a High-DPI screen (if available) | Confirm that standard Desktop Mode Qt high-DPI scaling still functions normally (the bypass is only active when `GAMESCOPE_WIDTH` or `XDG_CURRENT_DESKTOP=gamescope` is set) |
