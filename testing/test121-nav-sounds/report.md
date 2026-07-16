# Test121 Report — controller-nav UI sounds (BL-1776)

**Artifact:** `Vibemis-0.2.0-alpha.013-x86_64.AppImage`
**md5:** `fdcd1144d5150e9580687fcae1f202d8` ✓ · **sha256:** `bb2928df…49e66e0d` ✓ (both exact)
**Branch:** `test121-nav-sounds` — **Device:** Legion Go S Z2, SteamOS 3.8.5, Desktop Mode
**Test date:** 2026-07-16 — maintainer present (listening verdicts); objective evidence via
sink-monitor recordings (`parec` on the speaker sink) with RMS event analysis.

---

## 1. TL;DR

| Tier | Verdict | One line |
|---|---|---|
| 0 — integrity | PASS | hashes exact, selftest PASS exit 0 |
| 1 — launcher sounds | **PASS** | objective: every input produced its sound (10 events / 10 inputs); maintainer: **"sounds nice"** |
| 2 — the pref | **PASS** | OFF = instant global silence (4 probes, zero events); ON-blip asymmetry works; persistence proven both ways incl. relaunch |
| 3 — in-stream + game-audio safety | **PASS (the review-flag check)** | 60 s continuous stream audio, **minimum 20 ms window at 82 % of median — zero dips, zero dropouts** across 2 Quick-Menu cycles + 10 ticks; 0 client audio errors; launcher sounds work after quit (clean device handoff) |

**Recommendation: MERGE.** Two polish notes + one repeat-offender UX bug below.

## 2. Tier 1 — launcher sounds (objective + subjective)

- Instrumented run (sink-monitor recording, presses timestamped): activate **blip** strong
  (rms ~1800–2100), focus-move **ticks** softer (~600–950 ≈ −30 dBFS at 70 % volume), RB/LB tick,
  Settings-open plays a distinct double-sound. 10 sound events for 10 inputs; one d-pad tick
  possibly coalesced (within timing fuzz — not reproducible as a miss).
- PcView edge behavior correct: on a 1-host grid all d-pad moves are edge no-ops → **silent**, per
  spec (the ghost card is deliberately not d-pad-reachable).
- **Maintainer verdict: "sounds nice"** — volume comfortable at 70 % device volume. (First
  listen attempt heard nothing — the sounds are easy to miss if not listening; see polish note 2.)

## 3. Tier 2 — the pref

Recorded protocol: baseline pair → **2 ticks** · toggle OFF → **4 d-pad probes, zero events**
(instant global silence) · toggle ON → **strong blip** (the expected asymmetry) · post pair →
**2 ticks**. Persistence: `uisounds=false` written on Settings exit, survives app quit;
relaunch-while-OFF is totally silent (max_rms = 0 incl. an activate); restored ON →
`uisounds=true` persisted.
**Polish note 1:** the turn-OFF tap itself emits a faint tick (rms ~487) — instructions expect
the turn-OFF to be silent; likely the row-tap feedback racing the pref write.

## 4. Tier 3 — in-stream + game-audio safety (review-flag: sdlaud asserts removal)

Host played a continuous tremolo chord (shallowed troughs ≈ 76 % level — a dropout would be
unmistakable). 60.1 s capture while streaming: opened/closed the Quick Menu twice, 10 tick
presses over the audio.

- **Continuity: median rms 1303, minimum 20 ms window 1075 (82 % of median), zero windows below
  25 % of median → game audio never even dipped.** The removed sole-ownership asserts caused no
  regression — the mini-player coexists with the stream audio device cleanly.
- `grep -iE "audio|sdlaud"` on the client log: **0 errors**.
- Post-quit: launcher ticks immediately work again (rms 937) — device handoff back is clean.
- **Polish note 2 (tick audibility):** in RMS terms the tick (~600–950) sits *below* a loud game
  audio bed (~1300) — ticks are subtle over loud content. Whether to boost tick gain while
  streaming is a maintainer taste call; flagging, not failing.

Coordination note: three capture attempts raced short host-audio windows (3-min/90-s auto-stops
vs bus latency); the pass came from a 5-minute window + an "AUDIO ROLLING" post that my watcher
fired on. For future audio cycles: long window + rolling-confirm handshake from the start.

## 5. Incidents (not test121 defects, but session findings)

- **ComboBox d-pad mutation strikes again:** during Tier-2 navigation a stray d-pad DOWN landed
  on the Accent-color combo and silently flipped Teal→Indigo (restored). Same class as the
  BL-1560-report finding and the UVD flip in test120 — the audit of arrow-key handling on
  ComboBox/VbToggleRow rows is becoming the top nav-UX debt.
- Sidebar-focus trap: taps on a sidebar item change the page but keyboard/gamepad focus stays on
  the sidebar — d-pad then walks categories, not content (operator hazard; relates to the same
  focus-model debt).

## 6. Teardown

Streams quit, host session cancelled (`<cancel>1`), host audio loop auto-stopped (build agent's),
app closed, rig stopped. Prefs restored/verified: `uisounds=true`, direct touch, overlay on,
scaling off, accent Teal.

## 7. Recommendation

**MERGE — close BL-1776.** Polish follow-ups: (1) silence the faint tick on the turn-OFF tap;
(2) consider a small tick-gain boost (or a "louder in stream" scale) since ticks are subtle over
loud game audio; (3) the ComboBox arrow-mutation audit (§5) keeps biting operators — raise its
priority.
