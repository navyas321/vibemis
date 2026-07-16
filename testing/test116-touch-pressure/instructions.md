# Test116 Instructions — touch passthrough pressure fix (taps click, drags draw)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Prior evidence:** BL-1528 validation run 2026-07-16 (bus thread + BL-2015) — direct-touch
armed the host pipeline (virtual-touch-device line) but taps never clicked and swipes never
drew; the host pointer only *relocated* (hover-only injection).
**Goal:** one sentence — with the pressure clamp, a client tap must CLICK (ink a dot) and a
client swipe must DRAW a continuous stroke in Paint on the host.

---

## Background

Root cause (BL-2015): the Legion Go touchscreen (like many capacitive panels) reports SDL
finger `pressure` as **0.0**; `abstouch.cpp` forwarded it verbatim and Apollo-lineage hosts
inject `pressure<=0` DOWN/MOVE as **hover** (in-range, no contact). Fingers can't hover, so
the fix clamps missing pressure to 1.0 on DOWN/MOVE in the touch branch only (pen path
untouched — pen hover is a real state; UP keeps 0.0 = contact release).

Also new (your ask from the BL-1528 close-out): the send path is now observable —
`Touch DOWN id .. norm .. pressure .. err ..` and `Touch UP id .. after N moves, err ..`
qDebug lines (MOVEs are counted, never logged per-event — BL-1619 lag-storm rule).

**Build tier: ALPHA (BL-2016 rule — you only ever test alphas.)**

---

## Artifact

**Alpha release:** `0.2.0-alpha.NNN` for branch `test116-touch-pressure` — take the newest
alpha on the Releases page whose body names this branch; verify the md5 the release body
lists (and the bus post from the build agent).

```bash
cd ~/vibemis
git fetch origin
git checkout test116-touch-pressure && git pull
./testing/run-cycle.sh test116-touch-pressure   # downloads + md5-verifies the alpha
```

---

## Test procedure

### Tier 0 — integrity + boot
```bash
md5sum <downloaded>.AppImage        # must match the release-body md5
./<AppImage> selftest --json        # expect overall PASS, exit 0
```

### Tier 1 — direct-touch: tap clicks, drag draws (host operator on the bus)
1. Post on the bus: `@host test116 Tier1 GO` — the build agent opens Paint maximized
   host-side and confirms (same flow as the BL-1528 run).
2. Stream to the Vibepollo host in **direct-touch mode** (`abstouchmode=true`), capture the
   client log: `./<AppImage> stream ... 2>&1 | tee /tmp/test116-t1.log`
3. Inject (or finger-tap) **one tap** at client-center-ish, post the timestamp.
4. Inject a **slow diagonal swipe** (≥2 s, ≥20 interpolated points), post the timestamp.
5. Quit the stream cleanly.

**Client checks (exact):**
```bash
grep -c "Touch DOWN" /tmp/test116-t1.log   # expect >= 2 (tap + swipe start)
grep "Touch UP" /tmp/test116-t1.log        # swipe UP line must show "after N moves" with N >= 15
grep "pressure" /tmp/test116-t1.log        # DOWN lines must show pressure 1 (clamped), err 0
```

**Host truth (build agent posts):** ink dot at the tap point, CONTINUOUS stroke for the
swipe (screenshot), plus the per-session `Creating virtual touch input device` line.

### Tier 2 — negatives + regressions
1. **Touchpad-emu negative:** flip to touchpad-emulation mode, reconnect, tap once, post
   timestamp. Expect: relative cursor behavior only; host posts NO new
   virtual-touch-device line for this session and NO new canvas marks at the mapped point.
2. **Input regression:** in the same session confirm keyboard typing and gamepad
   navigation still work in-stream (no change expected — the fix touches only the finger
   branch).

---

## What to check and report

1. Tier 0: md5 exact, selftest PASS (paste the JSON verdict line).
2. Tier 1 client: the three grep results above, verbatim.
3. Tier 1 host: quote the build agent's dot/stroke verdict post (timestamps).
4. Tier 2: touchpad-emu negative held (quote host post) + keyboard/gamepad OK.
5. Any `err` != 0 in Touch DOWN/UP lines — report the exact line if so.

## Teardown

This cycle launches **nothing on the host** (Paint is operated by the build agent, who
also closes it). Client-side: quit the stream, remove `/tmp/test116-*.log` after the
report excerpts are taken.

---

## Report format

Commit `testing/test116-touch-pressure/report.md` on branch
`diagnostic/test116-touch-pressure-report`, tick the BL-1528/P3.23 checklist row
(☑ if all tiers pass, ✗ with details otherwise), and open a PR **targeting
`test116-touch-pressure`** (stacked-report pattern, same as test114's #200).

Required sections: TL;DR table, per-tier results, recommendation.

---

## Safety rules (standing)
- No package installs, no sudo outside read-only inspection
- Do not modify the AppImage
- Pairing/streaming IS explicitly required for Tiers 1–2 of this cycle
- If a step needs a capability outside these rules, stop and report the blocker
