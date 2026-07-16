# Test115 Report — touch fixes: slider, mode-agnostic overlay taps, send-text borders (BL-1747/1748/2000)

**Artifact tested:** `Vibemis-0.2.0-alpha.007-x86_64.AppImage`
**md5:** `bfc99d7b9ee2fb3d876a93fbfc838cbb` ✓ (matches bus-pinned value)
**Branch:** `test115-touch-fixes` (commit `bbe5e62`) — no instructions.md; validated against the
build agent's bus READY spec (13:38 EDT) + the fix commit's own claims.
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5 (Desktop Mode). User present for real-finger checks;
remaining touch checks ran on a new synthetic-touchscreen rig (see §5).
**Test date:** 2026-07-16
**Prior evidence:** BL-1747/1748 repro posted on the bus 13:18 EDT (same session, beta.013)

---

## 1. TL;DR

| Claim | Status | Evidence |
|---|---|---|
| 1a — slider draggable, full-width track | PASS | Track spans the row; real-finger drag follows and landed at a clean 150% |
| 1b — one arrow/d-pad press = +5 | PARTIAL | Keyboard arrow = +5 exact ✓; **d-pad still +10** (bug is in the HAT→key layer, see §3) |
| 2 — MENU/KBD taps work in BOTH touch modes | PASS | Taps opened Quick Menu / text-send in absolute AND virtual-trackpad modes |
| 3 — send-text stays inside borders | PASS | 123-char string fully contained; no overflow |

**Recommendation: MERGE** — everything this commit touched works. Two follow-ups filed (§4):
the d-pad double-fire lives in `sdlgamepadkeynavigation.cpp` (untouched by this fix), and the
user filed new UX findings (tap-target size, OSK gap).

## 2. What passed

- **Tier 0:** selftest JSON PASS exit 0; clean boot (`0.2.0-alpha.007`, VAAPI renderer, 0 SEGV/critical).
- **Slider (BL-1747):** track now spans the row (matches the bitrate-slider recipe). The maintainer's
  real-finger drag tracked smoothly and values stayed clean integers (150%) — no decimal garbage,
  no wild jumps. Keyboard Right = exactly +5 per press (isolated with a single X key event: 155→160).
- **Overlay taps (BL-1748):** in **absolute** mode, MENU tap opened the Quick Menu
  (`QuickMenu: Refreshing server commands on open`) and KBD tap opened text-send
  (`Executing action: type_text`). Flipped `Use touchscreen as a virtual trackpad` ON
  (`abstouchmode=false` persisted), new stream: **both taps work identically** — the
  hit-test-before-mode-split fix does its job. Mouse clicks still pass through (by design).
- **Send-text borders (BL-2000):** typed a 123-char string; text stays inside the bordered
  field, clipped/scrolled correctly.
- Two full stream launch/quit cycles, zero decode errors, host session ended clean
  (`SUNSHINE_SERVER_FREE`), settings restored (`abstouchmode=true`).

## 3. Residual: d-pad step is still +10 (isolated, not this commit's code)

Reproduced 3×: 145 →(d-pad Right)→ 155 → 165-ish → 170 (+10 each). Control test: a single
keyboard Right on the same focused slider = +5. My rig emits ONE HAT engage+release per press.
Since the same Slider handler sees keyboard=+5 but d-pad=+10, the doubling happens in the
**gamepad→key translation** (`sdlgamepadkeynavigation.cpp` HAT/d-pad handling emits two key
presses per physical press), not in `SettingsView.qml`. Every d-pad-adjustable control likely
double-steps, not just this slider. Follow-up candidate: send one press+release pair per HAT edge.

## 4. New findings from the maintainer (hands-on, filed for follow-up)

1. **MENU/KBD tap targets too small** — the icons' touch hit areas need to be substantially
   larger for reliable finger use (maintainer feedback while testing on-device).
2. **KBD should summon an on-screen keyboard** — it opens "Send text to host" with a local
   TextField, but a keyboard-less handheld has no way to type into it; maintainer expects a
   virtual keyboard. (Standing gap from the 13:18 repro post; unchanged in alpha.007.)
3. Quick Menu / text-send item interaction is still gamepad/keyboard-only (not claimed by this
   fix) — a touch-only user can open but not operate/close them without a controller.
4. Cosmetic: the text-send placeholder ("Type text to send to the host…") renders on top of the
   field's top border; and the first typed character may be dropped if typing starts immediately
   after opening (focus-timer race — needs a targeted look).
5. Settings-page drag-scroll was NOT re-tested this cycle (not claimed by the fix); last known
   broken on beta.013 for both touch and pointer drags.

## 5. Test-infrastructure note — synthetic touch rig (new)

Real-touch automation now exists on the device: a one-shot **uinput touchscreen** (type-B
multitouch + `INPUT_PROP_DIRECT`, `tap`/`drag` commands). KWin/SDL deliver its events as genuine
finger input — it opened the overlay surfaces in-stream where synthetic mouse cannot. All
round-2 (trackpad-mode) taps and the settings toggling in this cycle ran user-free with it.
Happy to contribute it as a `touch` device type in `testing/automation/vinput.py` next cycle.

## 6. Recommendation

**MERGE** `test115-touch-fixes` (all of its own changes verified). File follow-ups:
(a) d-pad double-fire in `sdlgamepadkeynavigation.cpp` (§3); (b) enlarge MENU/KBD tap targets;
(c) OSK/virtual-keyboard story for text-send; (d) touch operability of the Quick Menu surfaces.
