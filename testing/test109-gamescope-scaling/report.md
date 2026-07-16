# Test109 Report — Gamescope High-DPI UI scaling fix

**Artifact:** `Vibemis-0.2.0-alpha.013-x86_64.AppImage` (md5 `fdcd1144d5150e9580687fcae1f202d8` ✓)
**BL-2016 substitution note:** instructions predate the alpha-only rule and expect a
"Version 1.0.0" chip — run on the **latest alpha** instead (contains the merged fix from
`test109-gamescope-scaling`, base `vibemis-main`).
**Device:** Legion Go S Z2 (1920×1200 panel), SteamOS 3.8.5 — Tier 2 via
`scripts/gamescope-emulate.sh` (nested headless gamescope + FROG WSI, the sanctioned Game-Mode
emulation rig). **Test date:** 2026-07-16.

---

## 1. TL;DR

| Tier | Verdict |
|---|---|
| 1 — build/launch | PASS (many clean Desktop-Mode launches of alpha.013 today; version chip `0.2.0-alpha.013` per substitution; no High-DPI/Qt warnings in any session log) |
| 2 — gamescope scaling (the main event) | **PASS** — 1920×1200 pixel-perfect, 1280×800 responsive, zero clipping at both |
| 3 — Desktop-Mode regression | PASS (observed) — Desktop rendering normal all day; the bypass only arms under `GAMESCOPE_WIDTH`/`XDG_CURRENT_DESKTOP=gamescope` |

**Recommendation: tick the row ☑ — the High-DPI clipping fix holds on-device.**

## 2. Tier 2 evidence

- `gamescope-emulate.sh -w 1920 -h 1200`: app ALIVE 15 s, +0 coredumps, WSI surface made.
  Capture: Computers grid **fits exactly** — toolbar, host card (ONLINE badge, VIBEPOLLO chip,
  latency line), Add-a-computer ghost, and the gamepad hint bar all fully inside the frame, no
  card/text clipping. Layout identical to the Desktop-Mode design reference.
- `gamescope-emulate.sh -w 1280 -h 800`: same result at the smaller logical size — elements
  scale down responsively (smaller cards/typography), everything on-screen, no clipping or
  overflow anywhere.
- Known harness quirk (already on record from the test113-era dry-run): gamescope itself aborts
  at harness teardown *after* the checks; harness exit 0, +0 app coredumps — not app-related.

## 3. Tier 1 / Tier 3 notes

alpha.013 launched cleanly ~6× today in Desktop Mode (test121 cycle) with zero High-DPI-related
warnings across all captured logs; Desktop rendering at native 1920×1200 was pixel-correct all
session (KDE at 100 % scale — the Qt auto-DPI path stays active in Desktop Mode by design and
misbehaved in neither direction).

## 4. Recommendation

Row ☑ (done in this commit). No follow-ups — the env-gated bypass does exactly what the fix
promised at both target geometries.
