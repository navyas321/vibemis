# Test120 Report — d-pad double-step: THE BUG WAS MY RIG, not the app (BL-2013 correction)

**Artifact:** `Vibemis-0.2.0-alpha.012-x86_64.AppImage`
**md5:** `873d0ef14a3b181a69ec8fe07a897921` ✓ · **sha256:** `8f0f2631…ca0f4d0` ✓ (both exact)
**Branch:** `test120-dpad-dedupe` — **Device:** Legion Go S Z2, SteamOS 3.8.5, Desktop Mode
**Test date:** 2026-07-16

---

## 1. TL;DR — I owe this cycle an apology

| Item | Verdict |
|---|---|
| Tier 0 | PASS (hashes exact, selftest PASS) |
| **The +10 double-step** | **RIG ARTIFACT — the app NEVER double-stepped.** My BL-2013 "verdict B" was corrupted evidence; details in §2 |
| Slider with the fixed rig (alpha.012) | +5 / −5 exactly per press, every series; ceiling clamp at 200 correct |
| Keyboard arrow | +5 (no regression) |
| Tier 1.4 auto-repeat | **ABSENT on alpha.012 AND alpha.010** — 2 s hold = one step on both ⇒ repeat never existed; **the filter did NOT kill it** (explicit verdict as requested) |
| Hot-replug | PASS (device destroy/create mid-launcher ×several; fresh instance works immediately) |
| Tier 2 nav | LB/RB and A/B single-fire PASS; **two new findings** (§4) |

**Recommendation:** the alpha.012 edge-filter chases a bug that never existed. Revert it for
hygiene, or keep it as a zero-cost defensive guard (it provably does not break auto-repeat,
because there is none) — build agent's call. The rig is fixed in this PR.

## 2. The correction (BL-2013 post-mortem)

**What happened:** `testing/automation/vinput.py`'s gamepad daemon creates a companion
**keyboard** uinput device (`navfd`) and the `DPAD` FIFO command emitted the HAT event **plus a
keyboard-arrow tap** (`_dispatch`, ~line 313 — a crutch from the old headless-gamescope rig where
gamepad events didn't navigate). One `DPAD RIGHT` = gamepad step **and** keyboard step = the
"+10" I reported in test115 and then "confirmed, definitively" in the BL-2013 discriminator.
My "rig exonerated — emits ONE HAT engage+release" claim checked `pad_dpad` but missed the
dispatcher's tap. The app was innocent the whole time.

**The proof (alpha.012, same slider, same session):**
- daemon `DPAD RIGHT` → **+10**
- raw HAT engage/release, daemon bypassed, at 30 ms / 500 ms / 2000 ms press durations →
  **+5 exactly, every time**
- keyboard arrow → +5

**The rig fix (in this PR):** plain `DPAD` now emits only the HAT event; the dual-emit behavior
is preserved behind an explicit `DPADNAV` command for any harness that still wants it.
Post-fix daemon `DPAD`: +5/−5 per press across every series (§3).

**Process note:** this is the second rig-blames-app incident (see the vinput HAT/absmin RCA,
PR #186). Both lessons now say the same thing: verify the rig's *whole* emission path —
dispatcher and companion devices included — and cross-check anomalies with a raw-device bypass
before blaming the app. Also: `vpad.log` records only daemon readiness, no per-command lines —
adding command logging would have caught this in minutes (small follow-up).

## 3. Counts with the fixed rig (alpha.012)

- Single press: 180→185 (+5). Series: ×5 right from 185 → 200 (ceiling clamp — correct);
  ×2 left 200→190 (−5 each); ×3 left 190→175 (−5 each). Keyboard Right: +5.
- Auto-repeat (Tier 1.4, explicit): 2 s held d-pad = **one** step on **both** alpha.012 and
  pre-filter alpha.010 → auto-repeat is absent by design, **not** a filter casualty.
  If repeat-while-held is *wanted* for sliders, that's a feature request, not a regression.

## 4. Tier 2 — nav regressions: two new findings

1. **Focus escaped the slider during a left-press series** — after a clean 3×left run the next
   3 rights did nothing and focus was found back on the sidebar. The alpha.010 commit claimed
   Left no longer bubbles out mid-adjust; something still escapes under repeated lefts
   (un-instrumented; needs a targeted look).
2. **"Use Virtual Display" flipped OFF with no A press** during the stray navigation that
   followed — suspect `VbToggleRow` (or the row chain) treats a d-pad/arrow direction as a
   toggle. A stream-critical setting silently flipping on navigation is worth a quick audit.
   (Restored ON via touch; config on disk was never corrupted — apps were killed unsaved.)

LB/RB category flip and A/B single-fire showed no doubles across the whole session's heavy
gamepad use (dozens of presses; every A activation single-fired).

## 5. Teardown

Apps closed (unsaved kills — disk config never mutated except deliberate flags, all restored:
scaling off, factor 100, direct touch, overlay on, UVD on). Rig daemon stopped. No host
involvement this cycle.

## 6. Recommendation

1. **Revert or keep-as-defensive** the alpha.012 edge-filter (no observed cost either way;
   the bug it targets does not exist). If kept, rename the comment so future readers know the
   Legion +10 was a test-rig artifact, not a pad/driver behavior.
2. Merge the **vinput.py DPAD fix** (this PR) — and consider per-command daemon logging.
3. Small follow-ups: the slider left-escape (§4.1) and the VbToggleRow arrow-flip audit (§4.2).
4. Optional confirmation: one physical d-pad press by the maintainer (expect +5) closes the
   loop on real hardware; no longer blocking anything.
