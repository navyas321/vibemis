# Test119 Report — touch passthrough INKS: dense pointer-id slots (BL-2015 / BL-1528)

**Artifact:** `Vibemis-0.2.0-alpha.011-x86_64.AppImage`
**md5:** `1b2f70c949f64ab5f4a01ed69d8634d3` ✓ · **sha256:** `e605943d…20bd132` ✓ (both exact)
**Branch:** `test119-pointer-slots` — **Device:** Legion Go S Z2, SteamOS 3.8.5, Desktop Mode
**Test date:** 2026-07-16 — maintainer physically present (real-finger + multi-finger evidence);
synthetic injections via the uinput touchscreen rig. Host operator live on the bus throughout.

---

## 1. TL;DR

| Tier | Verdict | One line |
|---|---|---|
| 0 — integrity + boot | PASS | hashes exact, selftest PASS exit 0 |
| 1 — THE INK TEST | **PASS (real-usage)** | tap INKS at exact point; **real-finger freehand strokes DRAW continuously** |
| 1b — MOVE-path forensics | done | residual bracketed: slow *synthetic* drags drop contact in Vibepollo forwarding — real fingers (60–120 Hz) unaffected |
| 2 — test118 Game-Mode deferrals | **DEFERRED** | needs physical Game Mode (session-ending switch) — scheduled with the maintainer |
| 3 — regressions | PASS | multi-finger dense slots 0/1 clean, no crash/stuck pointer; touchpad-emu negative holds |

**BL-2015 real-world: FIXED. BL-1528/P3.23 checklist row: ☑ PASS (ticked in this commit).**

## 2. Tier 0

md5 + sha256 exact vs dispatch. `selftest --json` → `"failures":0,"result":"PASS"`, exit 0.

## 3. Tier 1 — the ink test

Host confirmed fresh Paint maximized on the session's virtual display (sole screen, 1920×1200;
sequencing per the 17:35 topology tweak — stream first, Paint opened onto it).

- **TAP (960,600) @ 21:39:02.38Z — INKED.** Host truth: *"Real ink dot at exactly (960,600) with
  the cursor parked elsewhere = DOWN/UP contact CONFIRMED, pointer-id fix VALIDATED."* Client:
  `Touch DOWN id 0 … pressure 1 err 0` — **dense slot 0** where test116 sent raw ids. First
  client-injected ink in the project.
- **Synthetic 40-pt swipe — no stroke initially** → Tier1b forensics below.
- **REAL FINGER (the decisive test): the maintainer's slow freehand drag DREW CONTINUOUS
  loops/curves across the canvas.** Client: `Touch UP id 0 after 264 moves, err 0` over ~3 s
  (≈90 Hz — the genuine device input profile). Host truth: *"REAL FREEHAND STROKES visible …
  BL-2015 real-world = FIXED (taps click, real drags draw)."*

## 4. Tier 1b — MOVE-path forensics (residual bracketed)

| Probe | Duration / rate | Ink? |
|---|---|---|
| HOLD 2 s, no moves | — | ✅ dot |
| Slow 5-pt drag, 0.4 s/step | ~2 s | ❌ |
| Fast 6-pt flick, 5 ms/step | ~30 ms | ✅ full stroke |
| Fast twin of the 40-pt swipe, ~15 ms/step | ~600 ms | ❌ |
| Sweep A 10 pt (~150 ms) / B 15 pt (~230 ms) / C 25 pt (~380 ms) | — | A ✅ · B ❌ · C ✅ (non-monotonic) |
| Host-native 800 ms drag (control, mid-stream) | — | ✅ |
| **Real finger, ~90 Hz, ~3 s** | — | **✅ continuous** |

Reading: the drop is **not** a clean Windows contact-age cliff (host-native 800 ms drew; sweep
results non-monotonic) — it's a timing race in **Vibepollo's touch forwarding** for sparse or
irregular synthetic update streams. Real fingers emit dense 60–120 Hz updates and are unaffected.
**Documented as a non-blocking, Vibepollo-side (upstream) refresh note.**

## 5. Tier 3 — regressions

- **Multi-finger sanity (real two-finger tap + pinch):** two simultaneous contacts mapped to
  **dense slots id 0 and id 1**, full move streams each (65/66 and 73/77 moves), clean UP for
  both, zero crashes, no orphaned contact; host cursor sane after.
- **Touchpad-emu negative:** fresh session with `abstouchmode=false`, synthetic tap at
  21:54:06.43Z → **zero `Touch DOWN` lines** client-side (native path never engages; relative
  emulation only), no host touch-device line for the session.

## 6. Tier 2 — Game-Mode deferrals: DEFERRED

OSK visually rising + typed chars landing, the mid-gesture TOUCH-toggle guard, overlay ON/OFF
and Steam-absent negatives require **physical Game Mode**, and switching modes ends the desktop
test-agent session. Scheduled as a dedicated Game-Mode block with the maintainer (handoff
protocol: `~/HANDOFF-vibemis-next-session.md` + build agent owns the manual checklist).

## 7. Teardown

Streams quit, host session cancelled (`<cancel>1`), nothing launched host-side (Paint was the
build agent's), app closed, rigs stopped, prefs restored (`abstouchmode=true` direct touch).

## 8. Recommendation

**MERGE — close BL-2015 (real-world) and mark BL-1528/P3.23 ☑ PASS** (done in this commit).
File the slow-synthetic forwarding race as a small upstream/Vibepollo note (repro table in §4 —
non-monotonic, so suggest instrumenting the forwarder's contact-refresh path rather than tuning
a timeout). Schedule the Game-Mode block for the Tier 2 deferrals.
