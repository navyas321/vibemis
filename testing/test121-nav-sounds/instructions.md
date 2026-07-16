# Test121 Instructions — controller-nav UI sounds (BL-1776)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** soft tick on every focus move, brighter rising blip on activate — across the whole
launcher AND the in-stream Quick Menu — gated by the new `uiSounds` pref (default ON), with
game audio completely unaffected.

## Background

SDL2 mini-player (`UiSoundManager`): lazy device open per burst, idle-close 1.5s, silent
no-op if the device is busy; two tiny synthesized qrc WAVs (1234Hz/-22dBFS 30ms tick,
1050→1550Hz/-18.6dBFS 60ms blip). Zero new packaging deps (Qt Multimedia rejected on
evidence). REVIEW FLAG for this cycle: two debug-only sole-ownership SDL_asserts were
removed in sdlaud.cpp — the step-6 "game audio uninterrupted" check is the proof point.

**Alpha:** `0.2.0-alpha.013` — asset `Vibemis-0.2.0-alpha.013-x86_64.AppImage`
**md5:** `fdcd1144d5150e9580687fcae1f202d8`
**sha256:** `bb2928df863fba3157bdb49d8824346097836eddd3b2c2001cf7301849e66e0d`

## Test procedure

### Tier 0 — integrity + boot
md5/sha256 exact vs dispatch; `selftest --json` PASS exit 0. Device audio ON, volume
comfortable.

### Tier 1 — launcher sounds (listen: tick = focus move, blip = activate)
1. PcView: d-pad between host tiles → tick per move; no tick at grid edges; A → blip.
2. Toolbar: d-pad up from grid → tick; left/right → tick; A → blip + action.
3. AppView: as PcView; X context menu → ticks navigating, blip on select.
4. Settings: sidebar up/down → ticks; LB/RB category flip → tick; d-pad through content
   rows → tick; A on a toggle → blip; combo popup rows → tick each, A → blip.
5. Rapid navigation: hold d-pad through a long list — crisp retriggers, no crackle/stutter.

### Tier 2 — the pref
1. Settings → UI Settings card → "Play navigation sounds" OFF → instant global silence
   (the turn-OFF itself is silent; turning back ON blips — expected asymmetry).
2. Relaunch → state persists (both OFF and ON).

### Tier 3 — in-stream + game-audio safety (the review-flag check)
1. Stream Navid-PC Desktop with host audio playing (e.g. a YouTube video on the host).
2. Open Quick Menu → d-pad rows → ticks audible OVER the game audio; A → blip.
3. **Game audio must continue uninterrupted the whole session and after quit** — no
   dropouts at menu open/close or sound playback moments; no audio errors in the client
   log (`grep -iE "audio|sdlaud" /tmp/test121-t3.log`).
4. Quit stream cleanly; launcher sounds still work after (device handoff back).

## What to check and report
Per-tier verdicts; the Tier 3 game-audio-uninterrupted verdict EXPLICITLY; any missing
hook (a focus move that is silent when sounds are ON); subjective volume/annoyance note
for the maintainer (tick too loud?).

## Teardown
Nothing host-side (stop the host video). Restore your preferred uiSounds state.

## Report
`testing/test121-nav-sounds/report.md` on `diagnostic/test121-nav-sounds-report`,
PR targets `test121-nav-sounds`.

## Safety rules (standing)
No sudo/installs; don't modify the AppImage; streaming required for Tier 3 only.
