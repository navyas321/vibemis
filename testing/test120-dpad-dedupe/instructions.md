# Test120 Instructions — d-pad steps once: duplicate button-event edge filter (BL-2013)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** one physical d-pad press = exactly ONE step everywhere in the launcher (the
resolution-scale slider moves +5, not +10) — your fix-B verdict implemented.

## Background

Your discriminator proved the doubling happens with no Steam config in the path (fix A
dead). The fix edge-filters duplicate BUTTONDOWN/orphan BUTTONUP per controller instance
in SdlGamepadKeyNavigation before key translation; pressed-state clears on disable so
nothing leaks across enable cycles.

**Alpha:** `0.2.0-alpha.012` — asset `Vibemis-0.2.0-alpha.012-x86_64.AppImage`
**md5:** `873d0ef14a3b181a69ec8fe07a897921`
**sha256:** `8f0f26317a8713420a1f2a055562cdf847fe32687963b9350c5784250ca0f4d0`

## Test procedure

### Tier 0 — integrity + boot
md5/sha256 exact vs dispatch; `selftest --json` PASS exit 0.

### Tier 1 — the slider count (launcher only, no stream needed)
1. Settings → resolution-scale slider, note value.
2. ONE physical d-pad right press → value +5 exactly (was +10). Repeat x5 presses →
   +25 total. Left presses symmetric.
3. Keyboard arrow still +5 (no regression from the filter).
4. HOLD d-pad right ~2s → auto-repeat still works (multiple steps while held — the
   filter must not kill auto-repeat, which comes as real repeat DOWNs from SDL? If
   auto-repeat is dead, report it — the filter may need a repeat exemption).

### Tier 2 — navigation regressions (launcher)
1. d-pad list/grid navigation everywhere: one press = one focus move (PcView, AppView,
   Settings sidebar + rows, combo popups).
2. A/B/X/Y single-fire: A activates once (no double-activate), B backs one level.
3. LB/RB category flip: one per press.
4. Controller hot-replug: disconnect/reconnect the pad mid-launcher → buttons still work
   (per-instance state keyed by joystick id; a fresh id must start clean).

## What to check and report
Exact slider deltas per press; auto-repeat verdict (WORKS/DEAD); any nav double or
missed press; hot-replug result.

## Teardown
Nothing host-side. Restore slider to your preferred value.

## Report
`testing/test120-dpad-dedupe/report.md` on `diagnostic/test120-dpad-dedupe-report`,
PR targets `test120-dpad-dedupe`.

## Safety rules (standing)
No sudo/installs; don't modify the AppImage; no stream needed for this cycle.
