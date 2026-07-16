# Test116 Report — touch pressure fix: client VERIFIED, e2e FAIL (defect moves host-side)

**Artifact tested:** `Vibemis-0.2.0-alpha.008-x86_64.AppImage`
**md5:** `87aacf52ceb28354624fea25ae270ef0` ✓ · **sha256:** `d0df7aab…39b7e0d4` ✓ (both exact)
**Branch:** `test116-touch-pressure` — **Device:** Legion Go S Z2, SteamOS 3.8.5, Desktop Mode
**Test date:** 2026-07-16 — **Prior evidence:** BL-1528 validation (bus, beta.013) → BL-2015

Client touch injection ran on the synthetic uinput touchscreen (real SDL finger events;
rig motion-delivery proven at compositor level during the BL-1528 run).

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — client sends correct touch (clamp + moves) | **PASS** | `pressure 1 err 0` on DOWNs; swipe `UP after 40 moves` |
| B — e2e: tap inks, swipe draws on host | **FAIL** | Canvas blank except touch-pointer dot — host injects hover regardless |
| C — Tier 2 negatives/regression | NOT RUN | Stop order at usage limit; touchpad-emu negative already proven in the BL-1528 run |

**Verdict (per build-agent rescope): keep the client fix — it is protocol-verified and necessary.
The residual defect is HOST-side (Vibepollo touch injection = hover/no-contact regardless of
pressure). BL-2015 rescoped host-side; e2e re-verification after the host fix.**

## 2. Tier 0 — integrity + boot

md5 and sha256 both exact (header). `selftest --json` →
`{"checks":{…},"failures":0,"result":"PASS"}`, exit 0.

## 3. Tier 1 — direct-touch tap + swipe (host operator on the bus)

Fresh maximized Paint confirmed host-side at 15:24:46 EDT (clean canvas, old instance killed).
Stream live in direct-touch mode (`abstouchmode=true`). Injections (synthetic touchscreen):
**TAP** (960,600) at 19:25:27.39Z; **SWIPE** (600,400)→(1300,800), 40 points, 19:25:31.95–34.46Z.

**Client checks (exact greps, all PASS) — the new instrumentation this alpha added:**
```
grep -c "Touch DOWN" /tmp/test116-t1.log      → 2      (expect >= 2) ✓
Touch DOWN id 101 norm 0.5 0.5 pressure 1 err 0
Touch UP id 101 after 0 moves, err 0
Touch DOWN id 102 norm 0.3125 0.333333 pressure 1 err 0
Touch UP id 102 after 40 moves, err 0          (expect N >= 15) ✓
```
Pressure clamped to 1 on every DOWN (the BL-2015 client fix), `err 0` throughout.

**Host truth (build agent, bus 16:06 EDT):** virtual touch device armed 15:25:28.570 (+1.2 s
after tap) — but the 15:26:40 screenshot shows **NO stroke; only the touch-pointer dot** at the
mapped point. Quote: *"your fix is PROTOCOL-VERIFIED: 40 moves sent, pressure 1, err 0 …
defect is now HOST-SIDE (Vibepollo touch injection = hover/no-contact regardless of pressure)."*

**Environmental note:** ~70 s after the swipe the host's network flapped (Tailscale down ~25 min,
LAN stayed up) — it killed the stream and delayed the host truth, but all evidence on both sides
was captured before the flap.

## 4. Tier 2 — negatives + regression: NOT RUN

Stopped on the build agent's checkpoint order (both agents at the usage limit). Mitigation:
the touchpad-emu negative was already proven in the same-day BL-1528 run (no virtual-touch
device created, no marks — beta.013; the finger branch is the only thing this alpha changes).
Keyboard/gamepad in-stream regression: implicitly exercised (gamepad navigation drove both
stream launches; injected quit combo worked) — flagging for a formal pass in the e2e re-verify.

## 5. Recommendation

1. **Merge the client fix** — correct and necessary (zero-pressure hover was real, the clamp
   works, and the new Touch DOWN/UP instrumentation closed the observability gap).
2. **BL-2015 continues host-side:** Vibepollo's Windows touch injection discards contact —
   suspect the injected `POINTER_TOUCH_INFO` never sets in-contact flags
   (`POINTER_FLAG_INRANGE|POINTER_FLAG_INCONTACT` on DOWN/UPDATE), which produces exactly
   "hover pointer moves, nothing inks" regardless of client pressure.
3. Re-run this cycle's Tier 1 + full Tier 2 as the e2e verification once the host fix ships.
4. Checklist: BL-1528/P3.23 row marked ✗ with details (this report).

Next per queue after reset: BL-1560 Vulkan/HDR pipeline checks on alpha.008 (criteria on bus 15:02).
